# Bedrock backend

The canonical-account + cross-platform-save service for Bedrock. SSO-only (no
passwords): a player signs in with the platform token they already have
(Steam/console/Device ID), the backend mints-or-fetches their one canonical
account and returns a session JWT. Save metadata lives in D1, blobs in a private
R2 bucket, keyed by canonical account id, so a save follows the player across
platforms.

One Cloudflare Worker (`bedrock-backend`) over D1 and R2. The game never talks to
D1 or R2 directly, only to these endpoints.

## Endpoints

- `POST /api/auth` `{ platform, token }` -> `{ session, account_id }`
- `GET  /api/save?slot=N` -> `{ exists, schema_version, checksum, updated_unix, blob_url, blob_base64 }`
- `PUT  /api/save?slot=N` `{ schema_version, checksum, updated_unix, blob_base64 }` -> `{ ok, blob_url }`
- `POST /api/link` `{ action: "issue" }` -> `{ code }`
- `POST /api/link` `{ action: "redeem", code }` -> `{ account_id, session }` (merges accounts)

`/api/save` and `/api/link` require `Authorization: Bearer <session>`. `blob_url`
is the R2 object key, informational only; the game reads `blob_base64`.

## Deploy

1. Create the D1 database and R2 bucket for each env, and put the real ids in
   `wrangler.jsonc` (the `TODO` placeholders).
2. Apply the schema: `npx wrangler d1 migrations apply DB --env production --remote`.
3. Secrets, from Doppler without printing them:
   `doppler secrets get JWT_SIGNING_KEY --plain --config prd | npx wrangler secret put JWT_SIGNING_KEY --env production`
   and the same for `STEAM_WEB_API_KEY` if using Steam login. `STEAM_APP_ID` is a var in `wrangler.jsonc`.
4. `npx wrangler deploy --env production`. Production answers at
   https://saves.onenomad.studio, dev at https://bedrock-backend-dev.wandering-darkness-dd7b.workers.dev.
   `BEDROCK_BACKEND_URL` in Doppler points the game at them.

Local: `npm install`, copy `.dev.vars.example` to `.dev.vars`, `npm run dev`.
Checks: `npm run typecheck && npm test`.
