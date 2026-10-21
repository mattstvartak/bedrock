import { accountFromRequest, upsertAccount, validatePlatformToken } from "./auth";
import { mintSession } from "./jwt";

const json = (body: unknown, status = 200) => Response.json(body, { status });
const keyFor = (accountId: string, slot: number) => `${accountId}/slot_${slot}.save`;

const toBase64 = (b: ArrayBuffer) => {
	let s = "";
	for (const byte of new Uint8Array(b)) s += String.fromCharCode(byte);
	return btoa(s);
};
const fromBase64 = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));

// POST /api/auth  { platform, token }  -> { session, account_id }
async function auth(req: Request, env: Env) {
	if (req.method !== "POST") return new Response(null, { status: 405 });
	const { platform, token } = ((await req.json().catch(() => null)) ?? {}) as { platform?: string; token?: string };
	if (!platform || !token) return json({ error: "platform and token required" }, 400);

	const platformId = await validatePlatformToken(env, platform, token);
	if (!platformId) return json({ error: "invalid platform token" }, 401);

	const accountId = await upsertAccount(env.DB, platform, platformId);
	return json({ session: await mintSession(env.JWT_SIGNING_KEY, accountId), account_id: accountId });
}

//   GET  /api/save?slot=0  -> { exists, schema_version, checksum, updated_unix, blob_url, blob_base64 }
//   PUT  /api/save?slot=0  { schema_version, checksum, updated_unix, blob_base64 } -> { ok, blob_url }
async function save(req: Request, env: Env, accountId: string, url: URL) {
	const slot = parseInt(url.searchParams.get("slot") ?? "0", 10);
	if (!Number.isInteger(slot)) return json({ error: "bad slot" }, 400);

	if (req.method === "GET") {
		const meta = await env.DB.prepare(
			"select schema_version, checksum, updated_unix, blob_key as blob_url from save_objects where account_id=? and slot=?",
		).bind(accountId, slot).first<{ blob_url: string }>();
		if (!meta) return json({ exists: false });
		const obj = await env.SAVES.get(meta.blob_url);
		return json({ exists: true, ...meta, blob_base64: obj ? toBase64(await obj.arrayBuffer()) : "" });
	}

	if (req.method === "PUT") {
		const { schema_version = 1, checksum = "", updated_unix = 0, blob_base64 = "" } = ((await req.json().catch(() => null)) ?? {}) as {
			schema_version?: number;
			checksum?: string;
			updated_unix?: number;
			blob_base64?: string;
		};
		let bytes: Uint8Array;
		try {
			bytes = fromBase64(blob_base64);
		} catch {
			return json({ error: "blob_base64 is not valid base64" }, 400);
		}
		const key = keyFor(accountId, slot);
		await env.SAVES.put(key, bytes);
		await env.DB.prepare(
			`insert into save_objects (account_id, slot, schema_version, checksum, updated_unix, blob_key)
			 values (?,?,?,?,?,?)
			 on conflict (account_id, slot) do update set
			   schema_version = excluded.schema_version,
			   checksum       = excluded.checksum,
			   updated_unix   = excluded.updated_unix,
			   blob_key       = excluded.blob_key`,
		).bind(accountId, slot, schema_version, checksum, updated_unix, key).run();
		return json({ ok: true, blob_url: key });
	}

	return new Response(null, { status: 405 });
}

// Opt-in cross-platform account merge via a short code. Device A issues a code;
// device B redeems it, merging B's platform links into A's account.
//   POST /api/link  { action: "issue" }         -> { code }
//   POST /api/link  { action: "redeem", code }  -> { account_id, session }
async function link(req: Request, env: Env, accountId: string) {
	if (req.method !== "POST") return new Response(null, { status: 405 });
	const { action, code } = ((await req.json().catch(() => null)) ?? {}) as { action?: string; code?: string };

	if (action === "issue") {
		const c = [...crypto.getRandomValues(new Uint8Array(4))].map((b) => b.toString(16).padStart(2, "0")).join("").toUpperCase();
		await env.DB.prepare("insert into link_codes (code, account_id, expires_at) values (?,?,unixepoch()+600)").bind(c, accountId).run();
		return json({ code: c });
	}

	if (action === "redeem") {
		if (!code) return json({ error: "code required" }, 400);
		const target = await env.DB.prepare("select account_id from link_codes where code=? and expires_at > unixepoch()").bind(code).first<string>("account_id");
		if (!target) return json({ error: "invalid or expired code" }, 400);

		if (target !== accountId) {
			// Move this account's platform links to the target, keep the target's
			// saves (drop this account's), then delete it.
			const mine = await env.DB.prepare("select blob_key from save_objects where account_id=?").bind(accountId).all<{ blob_key: string }>();
			await env.DB.batch([
				env.DB.prepare("update platform_links set account_id=? where account_id=?").bind(target, accountId),
				env.DB.prepare("delete from save_objects where account_id=?").bind(accountId),
				env.DB.prepare("delete from accounts where id=?").bind(accountId),
				env.DB.prepare("delete from link_codes where code=?").bind(code),
			]);
			await env.SAVES.delete(mine.results.map((r) => r.blob_key));
		}
		return json({ account_id: target, session: await mintSession(env.JWT_SIGNING_KEY, target) });
	}

	return json({ error: "unknown action" }, 400);
}

export default {
	async fetch(req: Request, env: Env): Promise<Response> {
		const url = new URL(req.url);
		if (url.pathname === "/api/auth") return auth(req, env);
		if (url.pathname !== "/api/save" && url.pathname !== "/api/link") return new Response(null, { status: 404 });

		const accountId = await accountFromRequest(env, req);
		if (!accountId) return json({ error: "unauthorized" }, 401);
		return url.pathname === "/api/save" ? save(req, env, accountId, url) : link(req, env, accountId);
	},
} satisfies ExportedHandler<Env>;
