import { verifySession } from "./jwt";

// Validate a platform token and return a stable platform id, or null.
export async function validatePlatformToken(env: Env, platform: string, token: string): Promise<string | null> {
	switch (platform) {
		case "steam":
			return validateSteam(env, token);
		case "device":
		case "epic":
			// Device ID / EOS PUID. For the MVP the client sends its own id; harden
			// by verifying the EOS id token server-side before trusting it in prod.
			return token || null;
		default:
			// psn / xbox / switch: validate against the platform's token service.
			return null;
	}
}

async function validateSteam(env: Env, ticket: string): Promise<string | null> {
	if (!env.STEAM_WEB_API_KEY || !env.STEAM_APP_ID) return null;
	const url =
		`https://api.steampowered.com/ISteamUserAuth/AuthenticateUserTicket/v1/` +
		`?key=${env.STEAM_WEB_API_KEY}&appid=${env.STEAM_APP_ID}&ticket=${encodeURIComponent(ticket)}`;
	const json = (await (await fetch(url)).json()) as { response?: { params?: { result?: string; steamid?: string } } };
	const params = json.response?.params;
	return params?.result === "OK" ? (params.steamid ?? null) : null;
}

// Resolve the account id from an Authorization: Bearer <session> header.
export async function accountFromRequest(env: Env, req: Request): Promise<string | null> {
	const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
	return token ? verifySession(env.JWT_SIGNING_KEY, token) : null;
}

// Mint-or-fetch the canonical account for a platform identity.
export async function upsertAccount(db: D1Database, platform: string, platformId: string): Promise<string> {
	const find = () =>
		db.prepare("select account_id from platform_links where platform=? and platform_id=?").bind(platform, platformId).first<string>("account_id");
	const existing = await find();
	if (existing) return existing;

	const id = crypto.randomUUID();
	// the link insert is ignored if a concurrent sign-in won the race
	await db.batch([
		db.prepare("insert into accounts (id) values (?)").bind(id),
		db.prepare("insert or ignore into platform_links (platform, platform_id, account_id) values (?,?,?)").bind(platform, platformId, id),
	]);
	const winner = (await find())!;
	if (winner !== id) await db.prepare("delete from accounts where id=?").bind(id).run();
	return winner;
}
