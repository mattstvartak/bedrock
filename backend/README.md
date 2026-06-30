# Bedrock backend

The canonical-account + cross-platform-save service for Bedrock. SSO-only (no
passwords): a player signs in with the platform token they already have
(Steam/console/Device ID), the backend mints-or-fetches their one canonical
account and returns a session JWT. Saves are metadata in Neon with blobs in R2,
keyed by canonical account id, so a save follows the player across platforms.

Runs as Vercel functions over Neon Postgres + Cloudflare R2. The game never
talks to Neon/R2 directly, only to these endpoints.

## Endpoints

- `POST /api/auth` `{ platform, token }` -> `{ session, account_id }`
- `GET  /api/save?slot=N` -> `{ exists, schema_version, checksum, updated_unix, download_url }`
- `PUT  /api/save?slot=N` `{ schema_version, checksum, updated_unix }` -> `{ upload_url }`
- `POST /api/link` `{ action: "issue" }` -> `{ code }`
- `POST /api/link` `{ action: "redeem", code }` -> `{ account_id, session }` (merges accounts)

`/api/save` and `/api/link` require `Authorization: Bearer <session>`.

## Deploy

1. **Neon**: create a project, run `sql/0001_init.sql`, copy the connection string.
2. **R2**: create a bucket, an API token (access key id + secret), note the endpoint.
3. **Doppler**: put `DATABASE_URL`, `JWT_SIGNING_KEY`, the `R2_*`, and `STEAM_*`
   values in the `bedrock` project (see `.env.example`), and add the Doppler ->
   Vercel sync integration.
4. **Vercel**: import `backend/` as a project; env comes from the Doppler sync.
   `vercel deploy --prod`.

Local: `npm install && npm run typecheck`, then `doppler run -- vercel dev`.

## Status

Code complete, not yet deployed (needs the Neon/R2/Vercel accounts above). Pairs
with the game-side `CloudSaveBackend` (local-first disk, async sync through these
endpoints).
