import type { VercelRequest, VercelResponse } from "@vercel/node";
import { randomBytes } from "crypto";
import { sql } from "../lib/db";
import { accountFromAuthHeader } from "../lib/auth";
import { mintSession } from "../lib/jwt";

// Opt-in cross-platform account merge via a short code (Helldivers/Fortnite
// style). Device A issues a code; device B redeems it, merging B's platform
// links into A's account so both platforms resolve to one canonical account.
//
//   POST /api/link  { action: "issue" }            -> { code }
//   POST /api/link  { action: "redeem", code }     -> { account_id, session }
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== "POST") return res.status(405).end();

  const accountId = await accountFromAuthHeader(req.headers.authorization);
  if (!accountId) return res.status(401).json({ error: "unauthorized" });

  const { action, code } = (req.body ?? {}) as { action?: string; code?: string };

  if (action === "issue") {
    const c = randomBytes(4).toString("hex").toUpperCase();
    await sql`
      insert into link_codes (code, account_id, expires_at)
      values (${c}, ${accountId}, now() + interval '10 minutes')
    `;
    return res.json({ code: c });
  }

  if (action === "redeem") {
    if (!code) return res.status(400).json({ error: "code required" });
    const rows = await sql`
      select account_id from link_codes where code=${code} and expires_at > now()
    `;
    if (!rows.length) return res.status(400).json({ error: "invalid or expired code" });

    const target = rows[0].account_id as string;
    if (target === accountId) return res.json({ account_id: target, session: mintSession(target) });

    // Merge this account into the target: move platform links, keep the target's
    // saves (drop this account's), then delete it.
    await sql`update platform_links set account_id=${target} where account_id=${accountId}`;
    await sql`delete from save_objects where account_id=${accountId}`;
    await sql`delete from accounts where id=${accountId}`;
    await sql`delete from link_codes where code=${code}`;
    return res.json({ account_id: target, session: mintSession(target) });
  }

  return res.status(400).json({ error: "unknown action" });
}
