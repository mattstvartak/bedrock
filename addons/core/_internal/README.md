# `_internal/` — do not touch from game code

Everything under this folder is implementation: EOS plumbing, transports,
storage backends, the auth client, platform glue. It can change in any patch
release.

**Game code must never `preload()` or reference anything in here.** Use the
public API in `addons/core/api/` only: the autoload facades (`Save`, `Net`,
`Identity`), the `class_name`'d interfaces, the DTOs, and the `CoreEvents`
signal bus. A CI grep guard will enforce this.

Planned layout as modules land:

- `identity/` — EOS Connect provider, credential providers, canonical-account client
- `save/` — local-first writer, R2 cloud sync, conflict resolution
- `net/` — ENet + EOS transports, authority models, lobbies, voice
- `platform/` — per-platform backend wiring bound through `Platform`
