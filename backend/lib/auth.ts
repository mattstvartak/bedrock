import { sql } from "./db.js";
import { verifySession } from "./jwt.js";

// Validate a platform token and return a stable platform id, or null.
export async function validatePlatformToken(
  platform: string,
  token: string,
): Promise<string | null> {
  switch (platform) {
    case "steam":
      return validateSteam(token);
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

async function validateSteam(ticket: string): Promise<string | null> {
  const key = process.env.STEAM_WEB_API_KEY;
  const appid = process.env.STEAM_APP_ID;
  if (!key || !appid) return null;
  const url =
    `https://api.steampowered.com/ISteamUserAuth/AuthenticateUserTicket/v1/` +
    `?key=${key}&appid=${appid}&ticket=${ticket}`;
  const res = await fetch(url);
  const json = (await res.json()) as {
    response?: { params?: { result?: string; steamid?: string } };
  };
  const params = json.response?.params;
  return params?.result === "OK" ? params.steamid ?? null : null;
}

// Resolve the account id from an Authorization: Bearer <session> header.
export async function accountFromAuthHeader(header?: string): Promise<string | null> {
  const token = header?.replace(/^Bearer\s+/i, "");
  return token ? verifySession(token) : null;
}

// Mint-or-fetch the canonical account for a platform identity.
export async function upsertAccount(platform: string, platformId: string): Promise<string> {
  const existing = await sql`
    select account_id from platform_links where platform=${platform} and platform_id=${platformId}
  `;
  if (existing.length) return existing[0].account_id as string;

  const created = await sql`insert into accounts default values returning id`;
  const accountId = created[0].id as string;
  await sql`
    insert into platform_links (platform, platform_id, account_id)
    values (${platform}, ${platformId}, ${accountId})
  `;
  return accountId;
}
