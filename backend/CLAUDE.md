# Bedrock backend — guide for Claude sessions

The canonical-account + cross-platform-save service. SSO-only: a player signs in
with a platform token (Steam/console/Device ID), the backend mints-or-fetches one
canonical account and returns a session JWT. Saves are metadata in Neon with
blobs in a private Vercel Blob store, keyed by canonical account id.

Vercel functions (`api/*.ts`) over Neon Postgres + Vercel Blob. Deployed live at
**https://bedrock-backend-onenomad.vercel.app** (Vercel project
`onenomad/bedrock-backend`).

## Gotchas (these cost real time — heed them)

- **ESM, not CJS.** Vercel runs the functions as ES modules. That means
  `package.json` has `"type": "module"`, `tsconfig` is `module`/
  `moduleResolution: "NodeNext"`, and **every relative import needs a `.js`
  extension** (`import { sql } from "../lib/db.js"`). Without all three you get
  `FUNCTION_INVOCATION_FAILED` at module load. The error only shows in runtime
  logs (`vercel logs <deployment-url>`), not the build.
- **The blob store is private.** `put(...)` must use `access: "private"`
  (public errors). To download, the function fetches the blob URL server-side
  with `Authorization: Bearer ${BLOB_READ_WRITE_TOKEN}` and returns the bytes —
  the client never hits the blob URL directly.
- **No psql here.** Apply `sql/0001_init.sql` with a tiny Node migrator using
  `@neondatabase/serverless`. Its `neon()` HTTP client is template-only (no
  `.query`); run a raw statement with `sql(Object.assign([stmt], { raw: [stmt] }))`.
- **Deployment protection** (Vercel Authentication / `ssoProtection`) must be OFF
  for this project or every request 302-redirects to an SSO page. A public game
  API can't pass Vercel SSO; our own JWT is the auth.

## Env

Managed in Doppler (`bedrock`) and on the Vercel project. Required:
`DATABASE_URL` (Neon, connected via the Vercel integration), `JWT_SIGNING_KEY`,
`BLOB_READ_WRITE_TOKEN` (from the connected Blob store). Optional: `STEAM_*`.
Push a value from Doppler to Vercel without printing it:
`doppler secrets get KEY --plain --config prd | vercel env add KEY production`.

## Endpoints

- `POST /api/auth` `{ platform, token }` -> `{ session, account_id }`
- `GET  /api/save?slot=N` -> `{ exists, schema_version, checksum, updated_unix, blob_url, blob_base64 }`
- `PUT  /api/save?slot=N` `{ schema_version, checksum, updated_unix, blob_base64 }` -> `{ ok, blob_url }`
- `POST /api/link` `{ action: "issue" | "redeem", code? }` — cross-platform merge

`/api/save` and `/api/link` need `Authorization: Bearer <session>`.

## Deploy / verify

`npm install && npm run typecheck`, then `vercel deploy --prod --yes`. Verify
live with `scripts/test-backend-live.sh` from the repo root (the game-side
round-trip) or curl `/api/auth` with a device token.

## Game side

`addons/bedrock/_internal/backend/backend_session.gd` exchanges the player's
token for a session on login and calls the Save backend's `set_session()`, which
turns on cloud sync. `BEDROCK_BACKEND_URL` (in Doppler) points the game at this
service.
