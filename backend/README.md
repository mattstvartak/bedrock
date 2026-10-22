# Bedrock backend

The canonical-account + cross-platform-save service for Bedrock. SSO-only (no
passwords): a player signs in with the platform token they already have
(Steam/console/Device ID), the backend mints-or-fetches their one canonical
account and returns a session JWT. Save metadata lives in D1, blobs in a private
R2 bucket, keyed by canonical account id, so a save follows the player across
platforms.

One Cloudflare Worker (`bedrock-backend`) over D1 and R2. The game never talks to
D1 or R2 directly, only to these endpoints.

## Who can sign in

`POST /api/auth` takes a `platform` and a `token` the Worker can check itself:

- `eos`: the player's EOS Connect id token. The Worker verifies the RS256
  signature against Epic's JWKS, the issuer, the audience (`EOS_CLIENT_ID`) and,
  when `EOS_DEPLOYMENT_ID` is set, the deployment. The account is keyed by the
  PUID in `sub`. This is what the game sends after any EOS login, Device ID or Steam.
- `steam`: a Steam session ticket, checked with the Steam Web API.
- `device`: the bare string the client sent, trusted as-is. Only honoured when the
  secret `ALLOW_UNVERIFIED_DEVICE_TOKENS` is `1`. Set it in `.dev.vars` and the test
  config, never on a deployed Worker, or anyone can mint a session for any account.

Slots run 0 to 99 and a blob is at most 1 MiB, so one account cannot fill the bucket.

## Endpoints

- `POST /api/auth` `{ platform, token }` -> `{ session, account_id }`
- `GET  /api/save?slot=N` -> `{ exists, schema_version, checksum, updated_unix, blob_url, blob_base64 }`
- `PUT  /api/save?slot=N` `{ schema_version, checksum, updated_unix, blob_base64 }` -> `{ ok, blob_url }`
- `POST /api/link` `{ action: "issue" }` -> `{ code }`
- `POST /api/link` `{ action: "redeem", code }` -> `{ account_id, session }` (merges accounts)

A link code lasts ten minutes. Redeeming it moves the redeeming account's platform
identities onto the issuing account, drops the redeeming account's saves, deletes it
and returns a session for the merged account. Old sessions of the deleted account
stop working at once.

`/api/save` and `/api/link` require `Authorization: Bearer <session>`. `blob_url`
is the R2 object key, informational only; the game reads `blob_base64`.

## Deploy

1. Create the D1 database and R2 bucket for each env, and put the real ids in
   `wrangler.jsonc` (the `TODO` placeholders).
2. Apply the schema: `npx wrangler d1 migrations apply DB --env production --remote`.
3. Secrets, from Doppler without printing them:
   `doppler secrets get JWT_SIGNING_KEY --plain --config prd | npx wrangler secret put JWT_SIGNING_KEY --env production`
   and the same for `EOS_CLIENT_ID` and `EOS_DEPLOYMENT_ID` (required for EOS sign-in) and
   `STEAM_WEB_API_KEY` if using Steam login. `STEAM_APP_ID` is a var in `wrangler.jsonc`.
4. `npx wrangler deploy --env production`. Production answers at
   https://saves.onenomad.studio, dev at https://bedrock-backend-dev.wandering-darkness-dd7b.workers.dev.
   `BEDROCK_BACKEND_URL` in Doppler points the game at them.

Local: `npm install`, copy `.dev.vars.example` to `.dev.vars`, `npm run dev`.
Checks: `npm run typecheck && npm test`.
