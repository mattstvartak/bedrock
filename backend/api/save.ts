import type { VercelRequest, VercelResponse } from "@vercel/node";
import { sql } from "../lib/db";
import { accountFromAuthHeader } from "../lib/auth";
import { uploadUrl, downloadUrl } from "../lib/r2";

// Save metadata in Neon, blob in R2 keyed by account + slot. The client is
// local-first: it writes disk first, then PUTs metadata here and uploads the
// blob to the returned signed URL. GET returns metadata + a download URL.
//
//   GET  /api/save?slot=0   -> { exists, schema_version, checksum, updated_unix, download_url }
//   PUT  /api/save?slot=0   { schema_version, checksum, updated_unix } -> { upload_url }
export default async function handler(req: VercelRequest, res: VercelResponse) {
  const accountId = await accountFromAuthHeader(req.headers.authorization);
  if (!accountId) return res.status(401).json({ error: "unauthorized" });

  const slot = parseInt(String(req.query.slot ?? "0"), 10);
  const key = `${accountId}/slot_${slot}.save`;

  if (req.method === "GET") {
    const rows = await sql`
      select schema_version, checksum, updated_unix
      from save_objects where account_id=${accountId} and slot=${slot}
    `;
    if (!rows.length) return res.json({ exists: false });
    return res.json({ exists: true, ...rows[0], download_url: await downloadUrl(key) });
  }

  if (req.method === "PUT") {
    const { schema_version = 1, checksum = "", updated_unix = 0 } = (req.body ?? {}) as {
      schema_version?: number;
      checksum?: string;
      updated_unix?: number;
    };
    await sql`
      insert into save_objects (account_id, slot, schema_version, checksum, updated_unix, object_key)
      values (${accountId}, ${slot}, ${schema_version}, ${checksum}, ${updated_unix}, ${key})
      on conflict (account_id, slot) do update set
        schema_version = excluded.schema_version,
        checksum       = excluded.checksum,
        updated_unix   = excluded.updated_unix,
        object_key     = excluded.object_key
    `;
    return res.json({ upload_url: await uploadUrl(key) });
  }

  return res.status(405).end();
}
