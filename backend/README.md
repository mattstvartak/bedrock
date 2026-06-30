# Bedrock backend

The canonical-account + cross-platform-save service for Bedrock. SSO-only (no
passwords): a player signs in with the platform token they already have
(Steam/console/Device ID), the backend mints-or-fetches their one canonical
account and returns a session JWT. Saves are metadata in Neon with blobs in
Vercel Blob, keyed by canonical account id, so a save follows the player across
platforms.

Runs as Vercel functions over Neon Postgres + Vercel Blob. The game never talks
to Neon/Blob directly, only to these endpoints.

## Endpoints

- `POST /api/auth` `{ platform, token }` -> `{ session, account_id }`
- `GET  /api/save?slot=N` -> `{ exists, schema_version, checksum, updated_unix, blob_url }`
- `PUT  /api/save?slot=N` `{ schema_version, checksum, updated_unix, blob_base64 }` -> `{ ok, blob_url }`
- `POST /api/link` `{ action: "issue" }` -> `{ code }`
- `POST /api/link` `{ action: "redeem", code }` -> `{ account_id, session }` (merges accounts)

`/api/save` and `/api/link` require `Authorization: Bearer <session>`.

## Deploy

1. **Neon**: create a project, run `sql/0001_init.sql`, copy the connection string
   into Doppler as `DATABASE_URL`. (Neon Auth is not needed.)
2. **Vercel Blob**: connect a Blob store to this project (`vercel blob store add`
   or Storage in the dashboard). Vercel auto-injects `BLOB_READ_WRITE_TOKEN`.
3. **Doppler**: put `DATABASE_URL`, `JWT_SIGNING_KEY` (and `STEAM_*` if using Steam
   login) in the `bedrock` project (see `.env.example`); sync to Vercel.
4. **Vercel**: `vercel deploy --prod`. Then point the game's `BEDROCK_BACKEND_URL`
   at the deployment.

Local: `npm install && npm run typecheck`, then `doppler run -- vercel dev`.

## Status

Code complete, typechecks clean. Deploy needs a Neon project and a Vercel Blob
store on this project. Pairs with the game-side `CloudSaveBackend` (local-first
disk, async one-request sync through these endpoints).
