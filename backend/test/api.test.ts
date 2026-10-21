import { env, exports } from "cloudflare:workers";
import { beforeAll, expect, it } from "vitest";
import migration from "../migrations/0001_init.sql?raw";


beforeAll(async () => {
	const stmts = migration.replace(/--.*$/gm, "").split(";").map((s) => s.trim()).filter(Boolean);
	await env.DB.batch(stmts.map((s) => env.DB.prepare(s)));
});

const call = (method: string, path: string, body?: unknown, session?: string) =>
	exports.default.fetch(`http://bedrock.test${path}`, {
		method,
		headers: { ...(session ? { Authorization: `Bearer ${session}` } : {}), ...(body ? { "Content-Type": "application/json" } : {}) },
		body: body ? JSON.stringify(body) : undefined,
	});

const b64url = (b: Uint8Array) => btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const enc = (o: unknown) => b64url(new TextEncoder().encode(JSON.stringify(o)));

// An EOS Connect ID token for sub, signed with the test key unless key says otherwise.
async function eosToken(sub: string, claims: Record<string, unknown> = {}, kid = "test-key", key?: CryptoKey) {
	const jwk = JSON.parse((env as unknown as { TEST_EOS_PRIVATE_JWK: string }).TEST_EOS_PRIVATE_JWK);
	const signer = key ?? (await crypto.subtle.importKey("jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]));
	const now = Math.floor(Date.now() / 1000);
	const body = { iss: "https://api.epicgames.dev/auth/v1/oauth", aud: "test-client", pfpid: "test-product", sub, iat: now, exp: now + 3600, ...claims };
	const unsigned = `${enc({ alg: "RS256", typ: "JWT", kid })}.${enc(body)}`;
	const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", signer, new TextEncoder().encode(unsigned));
	return `${unsigned}.${b64url(new Uint8Array(sig))}`;
}

const auth = async (token: string) => call("POST", "/api/auth", { platform: "device", token });

const signIn = async (puid: string) => {
	const res = await auth(await eosToken(puid));
	expect(res.status).toBe(200);
	return (await res.json()) as { session: string; account_id: string };
};

it("mints an account on first sign-in and reuses it after", async () => {
	const a = await signIn("dev-reuse");
	const b = await signIn("dev-reuse");
	expect(b.account_id).toBe(a.account_id);
	expect((await signIn("dev-other")).account_id).not.toBe(a.account_id);
});

it("takes the PUID from a signed EOS ID token and refuses anything else", async () => {
	expect((await auth("dev-plain-puid")).status).toBe(401);
	expect((await auth(await eosToken("p", { aud: "someone-else" }))).status).toBe(401);
	expect((await auth(await eosToken("p", { pfpid: "other-product" }))).status).toBe(401);
	expect((await auth(await eosToken("p", { iss: "https://evil.example" }))).status).toBe(401);
	expect((await auth(await eosToken("p", { exp: Math.floor(Date.now() / 1000) - 10 }))).status).toBe(401);
	const other = await crypto.subtle.generateKey({ name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, false, ["sign", "verify"]);
	expect((await auth(await eosToken("p", {}, "test-key", (other as CryptoKeyPair).privateKey))).status).toBe(401);
	expect((await auth(await eosToken("p", {}, "unknown-kid"))).status).toBe(401);
	const good = await eosToken("puid-from-token");
	const [h, , sig] = good.split(".");
	expect((await auth(`${h}.${enc({ sub: "someone-else", aud: "test-client" })}.${sig}`)).status).toBe(401);
	expect((await auth(good)).status).toBe(200);
});

it("rejects a bad platform token and missing fields", async () => {
	expect((await call("POST", "/api/auth", { platform: "psn", token: "x" })).status).toBe(401);
	expect((await call("POST", "/api/auth", { platform: "device" })).status).toBe(400);
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
});

it("401s without a valid session", async () => {
	expect((await call("GET", "/api/save?slot=0")).status).toBe(401);
	expect((await call("GET", "/api/save?slot=0", undefined, "not.a.jwt")).status).toBe(401);
	expect((await call("POST", "/api/link", { action: "issue" })).status).toBe(401);
});
