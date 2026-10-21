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

const signIn = async (token: string) => {
	const res = await call("POST", "/api/auth", { platform: "device", token });
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
