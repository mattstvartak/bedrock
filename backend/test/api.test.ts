import { env as workerEnv, exports } from "cloudflare:workers";
import { beforeAll, expect, it } from "vitest";
import migration from "../migrations/0001_init.sql?raw";
import { validatePlatformToken } from "../src/auth";

const env = workerEnv as Env;

const b64url = (b: ArrayBuffer | Uint8Array | string) => {
	const bytes = typeof b === "string" ? new TextEncoder().encode(b) : new Uint8Array(b);
	return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};
const RSA = { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" };
let eosKey: CryptoKeyPair;
let otherKey: CryptoKeyPair;

// A token shaped like Epic's: RS256, kid in the header, Connect claims in the body.
async function eosToken(claims: Record<string, unknown>, key = eosKey, header: Record<string, unknown> = { alg: "RS256", kid: "test-kid" }) {
	const now = Math.floor(Date.now() / 1000);
	const body = { iss: "https://api.epicgames.dev/auth/v1/oauth", aud: "test-eos-client", pfdid: "test-deployment", iat: now, exp: now + 3600, ...claims };
	const signing = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(body))}`;
	const sig = await crypto.subtle.sign(RSA.name, key.privateKey, new TextEncoder().encode(signing));
	return `${signing}.${b64url(sig)}`;
}

beforeAll(async () => {
	const stmts = migration.replace(/--.*$/gm, "").split(";").map((s) => s.trim()).filter(Boolean);
	await env.DB.batch(stmts.map((s) => env.DB.prepare(s)));

	const gen = () => crypto.subtle.generateKey({ ...RSA, modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]) }, true, ["sign", "verify"]) as Promise<CryptoKeyPair>;
	eosKey = await gen();
	otherKey = await gen();
	const { kty, n, e } = (await crypto.subtle.exportKey("jwk", eosKey.publicKey)) as JsonWebKey;
	// Serve the test key as Epic's JWKS; anything else off the box is a test bug.
	globalThis.fetch = async (input: RequestInfo | URL) => {
		const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
		if (url === "https://api.epicgames.dev/auth/v1/oauth/jwks") return Response.json({ keys: [{ kty, n, e, use: "sig", kid: "test-kid" }] });
		throw new Error(`unexpected fetch ${url}`);
	};
});

const call = (method: string, path: string, body?: unknown, session?: string) =>
	exports.default.fetch(`http://bedrock.test${path}`, {
		method,
		headers: { ...(session ? { Authorization: `Bearer ${session}` } : {}), ...(body ? { "Content-Type": "application/json" } : {}) },
		body: body ? JSON.stringify(body) : undefined,
	});

const signIn = async (token: string, platform = "device") => {
	const res = await call("POST", "/api/auth", { platform, token });
	expect(res.status).toBe(200);
	return (await res.json()) as { session: string; account_id: string };
};

it("mints an account on first sign-in and reuses it after", async () => {
	const a = await signIn("dev-reuse");
	const b = await signIn("dev-reuse");
	expect(b.account_id).toBe(a.account_id);
	expect((await signIn("dev-other")).account_id).not.toBe(a.account_id);
});

it("rejects a bad platform token and missing fields", async () => {
	expect((await call("POST", "/api/auth", { platform: "psn", token: "x" })).status).toBe(401);
	expect((await call("POST", "/api/auth", { platform: "device" })).status).toBe(400);
});

it("only takes unverified device tokens when the dev flag is set", async () => {
	expect(await validatePlatformToken(env, "device", "x")).toBe("x");
	expect(await validatePlatformToken({ ...env, ALLOW_UNVERIFIED_DEVICE_TOKENS: undefined }, "device", "x")).toBeNull();
	expect(await validatePlatformToken(env, "epic", "x")).toBeNull();
});

it("signs in with a verified EOS id token and keys the account by PUID", async () => {
	const a = await signIn(await eosToken({ sub: "puid-1" }), "eos");
	const b = await signIn(await eosToken({ sub: "puid-1" }), "eos");
	expect(b.account_id).toBe(a.account_id);
	expect((await signIn(await eosToken({ sub: "puid-2" }), "eos")).account_id).not.toBe(a.account_id);
});

it("refuses EOS tokens that fail any check", async () => {
	const bad = [
		await eosToken({ sub: "puid-1" }, otherKey),
		await eosToken({ sub: "puid-1", aud: "someone-else" }),
		await eosToken({ sub: "puid-1", iss: "https://evil.example" }),
		await eosToken({ sub: "puid-1", exp: Math.floor(Date.now() / 1000) - 10 }),
		await eosToken({ sub: "puid-1", pfdid: "other-deployment" }),
		await eosToken({}),
		await eosToken({ sub: "puid-1" }, eosKey, { alg: "none", kid: "test-kid" }),
		await eosToken({ sub: "puid-1" }, eosKey, { alg: "RS256", kid: "unknown-kid" }),
		"puid-1",
	];
	for (const token of bad) expect((await call("POST", "/api/auth", { platform: "eos", token })).status, token.slice(0, 40)).toBe(401);
});

it("round-trips a save", async () => {
	const { session } = await signIn("dev-save");
	expect(await (await call("GET", "/api/save?slot=2", undefined, session)).json()).toEqual({ exists: false });

	const blob_base64 = btoa("hello save");
	const put = await call("PUT", "/api/save?slot=2", { schema_version: 3, checksum: "abc", updated_unix: 99, blob_base64 }, session);
	expect(put.status).toBe(200);
	expect(((await put.json()) as { ok: boolean }).ok).toBe(true);

	const got = (await (await call("GET", "/api/save?slot=2", undefined, session)).json()) as Record<string, unknown>;
	expect(got).toMatchObject({ exists: true, schema_version: 3, checksum: "abc", updated_unix: 99, blob_base64 });
});

it("caps slots and blob size", async () => {
	const { session } = await signIn("dev-caps");
	expect((await call("GET", "/api/save?slot=100", undefined, session)).status).toBe(400);
	expect((await call("GET", "/api/save?slot=-1", undefined, session)).status).toBe(400);
	expect((await call("PUT", "/api/save?slot=0", { blob_base64: "" }, session)).status).toBe(400);
	expect((await call("PUT", "/api/save?slot=0", { blob_base64: 42 }, session)).status).toBe(400);
	expect((await call("PUT", "/api/save?slot=0", { blob_base64: "A".repeat(1024 * 1024 * 2) }, session)).status).toBe(413);
	expect((await call("PUT", "/api/save?slot=99", { blob_base64: btoa("ok") }, session)).status).toBe(200);
});

it("merges accounts through a link code", async () => {
	const a = await signIn("dev-link-a");
	const b = await signIn("dev-link-b");
	await call("PUT", "/api/save?slot=0", { blob_base64: btoa("b-save") }, b.session);

	const { code } = (await (await call("POST", "/api/link", { action: "issue" }, a.session)).json()) as { code: string };
	const res = await call("POST", "/api/link", { action: "redeem", code }, b.session);
	expect(res.status).toBe(200);
	const merged = (await res.json()) as { account_id: string; session: string };
	expect(merged.account_id).toBe(a.account_id);

	expect((await signIn("dev-link-b")).account_id).toBe(a.account_id);
	expect((await call("POST", "/api/link", { action: "redeem", code }, merged.session)).status).toBe(400);
	// the merged-away account's old session is dead
	expect((await call("GET", "/api/save?slot=0", undefined, b.session)).status).toBe(401);
});

it("redeeming your own code just spends it", async () => {
	const a = await signIn("dev-self-link");
	const { code } = (await (await call("POST", "/api/link", { action: "issue" }, a.session)).json()) as { code: string };
	expect((await call("POST", "/api/link", { action: "redeem", code }, a.session)).status).toBe(200);
	expect((await call("POST", "/api/link", { action: "redeem", code }, a.session)).status).toBe(400);
});

it("401s without a valid session", async () => {
	expect((await call("GET", "/api/save?slot=0")).status).toBe(401);
	expect((await call("GET", "/api/save?slot=0", undefined, "not.a.jwt")).status).toBe(401);
	expect((await call("POST", "/api/link", { action: "issue" })).status).toBe(401);
});
