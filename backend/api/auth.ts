import type { VercelRequest, VercelResponse } from "@vercel/node";
import { validatePlatformToken, upsertAccount } from "../lib/auth";
import { mintSession } from "../lib/jwt";

// POST /api/auth  { platform, token }  -> { session, account_id }
// Silent platform SSO: validate the token, mint-or-fetch the canonical account,
// return a session JWT. No passwords, no email.
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== "POST") return res.status(405).end();

  const { platform, token } = (req.body ?? {}) as { platform?: string; token?: string };
  if (!platform || !token) {
    return res.status(400).json({ error: "platform and token required" });
  }

  const platformId = await validatePlatformToken(platform, token);
  if (!platformId) return res.status(401).json({ error: "invalid platform token" });

  const accountId = await upsertAccount(platform, platformId);
  return res.json({ session: mintSession(accountId), account_id: accountId });
}
