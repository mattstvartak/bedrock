import type { VercelRequest, VercelResponse } from "@vercel/node";
import { put } from "@vercel/blob";
import { sql } from "../lib/db.js";
import { accountFromAuthHeader } from "../lib/auth.js";

// Save metadata in Neon, blob in Vercel Blob, keyed by account + slot. The client
// is local-first: it writes disk first, then PUTs the (small, base64) blob here in
// one request. GET returns the metadata + the blob URL.
//
//   GET  /api/save?slot=0  -> { exists, schema_version, checksum, updated_unix, blob_url }
//   PUT  /api/save?slot=0  { schema_version, checksum, updated_unix, blob_base64 } -> { ok, blob_url }
export default async function handler(req: VercelRequest, res: VercelResponse) {
  const accountId = await accountFromAuthHeader(req.headers.authorization);
  if (!accountId) return res.status(401).json({ error: "unauthorized" });

  const slot = parseInt(String(req.query.slot ?? "0"), 10);

  if (req.method === "GET") {
    const rows = await sql`
      select schema_version, checksum, updated_unix, blob_url
      from save_objects where account_id=${accountId} and slot=${slot}
    `;
    if (!rows.length) return res.json({ exists: false });
    // The blob is private, so fetch its bytes server-side (auth-gated) and hand
    // them back base64. Saves are small, so proxying through the function is fine.
    const meta = rows[0];
    let blob_base64 = "";
    const fetched = await fetch(meta.blob_url, {
      headers: { authorization: `Bearer ${process.env.BLOB_READ_WRITE_TOKEN}` },
    });
    if (fetched.ok) {
      blob_base64 = Buffer.from(await fetched.arrayBuffer()).toString("base64");
    }
    return res.json({ exists: true, ...meta, blob_base64 });
  }

  if (req.method === "PUT") {
    const {
      schema_version = 1,
      checksum = "",
      updated_unix = 0,
      blob_base64 = "",
    } = (req.body ?? {}) as {
      schema_version?: number;
      checksum?: string;
      updated_unix?: number;
      blob_base64?: string;
    };

    const bytes = Buffer.from(blob_base64, "base64");
    const blob = await put(`${accountId}/slot_${slot}.save`, bytes, {
      access: "private", // saves stay auth-gated; the store is a private blob store
      addRandomSuffix: false,
      allowOverwrite: true,
    });

    await sql`
      insert into save_objects (account_id, slot, schema_version, checksum, updated_unix, blob_url)
      values (${accountId}, ${slot}, ${schema_version}, ${checksum}, ${updated_unix}, ${blob.url})
      on conflict (account_id, slot) do update set
        schema_version = excluded.schema_version,
        checksum       = excluded.checksum,
        updated_unix   = excluded.updated_unix,
        blob_url       = excluded.blob_url
    `;
    return res.json({ ok: true, blob_url: blob.url });
  }

  return res.status(405).end();
}
