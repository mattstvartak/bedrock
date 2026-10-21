# Bedrock backend — guide for Claude sessions

The canonical-account + cross-platform-save service. SSO-only: a player signs in
with a platform token (Steam/console/Device ID), the backend mints-or-fetches one
canonical account and returns a session JWT. Saves are metadata in D1 with
blobs in a private R2 bucket, keyed by canonical account id.

One Cloudflare Worker (`src/index.ts`) over D1 and a private R2 bucket
(`bedrock-backend`, envs `dev` and `production` in `wrangler.jsonc`).

## Gotchas

- **The bucket is private.** `GET /api/save` reads the object through the
  Worker binding and returns the bytes as `blob_base64`; the client never hits
  R2 directly. `blob_url` is just the object key (`<account>/slot_<n>.save`).
- **Secrets are not in `worker-configuration.d.ts`.** `JWT_SIGNING_KEY` and
  `STEAM_WEB_API_KEY` are typed by hand in `src/secrets.d.ts`. Rerun
  `npm run types` after changing `wrangler.jsonc`.
- **JWT is HS256 via Web Crypto** (`src/jwt.ts`), no library. Sessions last 30 days.
- **Tests apply `migrations/0001_init.sql`** themselves (`test/api.test.ts`); D1
  state is per test file.

## Env

Doppler project `bedrock` is the source. Set on the Worker with
`doppler secrets get KEY --plain --config prd | npx wrangler secret put KEY --env production`
(never echo the value). Required: `JWT_SIGNING_KEY`. Optional: `STEAM_WEB_API_KEY`
(`STEAM_APP_ID` is a var in `wrangler.jsonc`).

## Endpoints

- `POST /api/auth` `{ platform, token }` -> `{ session, account_id }`
- `GET  /api/save?slot=N` -> `{ exists, schema_version, checksum, updated_unix, blob_url, blob_base64 }`
- `PUT  /api/save?slot=N` `{ schema_version, checksum, updated_unix, blob_base64 }` -> `{ ok, blob_url }`
- `POST /api/link` `{ action: "issue" | "redeem", code? }` — cross-platform merge

`/api/save` and `/api/link` need `Authorization: Bearer <session>`.

## Deploy / verify

`npm install && npm run typecheck && npm test`, apply migrations with
`npx wrangler d1 migrations apply DB --env production --remote`, then
`npx wrangler deploy --env production`. Verify live with
`scripts/test-backend-live.sh` from the repo root or curl `/api/auth` with a
device token.

## Game side

`addons/bedrock/_internal/backend/backend_session.gd` exchanges the player's
token for a session on login and calls the Save backend's `set_session()`, which
turns on cloud sync. `BEDROCK_BACKEND_URL` (in Doppler) points the game at this
service.
