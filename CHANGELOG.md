# Changelog

All notable changes to Bedrock are recorded here. The public API in
`addons/bedrock/api/` follows semver: breaking changes to it are a major bump;
internals under `_internal/` can change in any patch.

## [0.1.1] - 2026-06-30

First game integration (Devil's Bank) shook out a UI bug and some doc gaps.

### Fixed
- `BedrockSettingsPanel` centers its content properly instead of pinning it to
  the middle and overflowing. It was relying on `set_anchors_preset(PRESET_CENTER)`,
  whose default `keep_offsets=true` only moves the top-left to center; now it
  fills the host area and centers via a `CenterContainer`.

### Docs
- README rewritten as a usage guide for games consuming the base.
- Added `CLAUDE.md` and `backend/CLAUDE.md` for future sessions.

## [0.1.0] - 2026-06-30

First feature-complete pass. Autoloads: `CoreEvents`, `Platform`, `Save`, `Net`,
`Identity`, `Audio`, `Settings`, `Scenes`, `Controls`, `Locale`, `Achievements`,
`Social`.

### Foundation
- Addon scaffold with the public-API / `_internal` boundary; `CoreEvents` signal
  bus; `Platform` service locator (build-target detection + per-interface
  backend binding); `GameConfig` toggles; interfaces and DTOs.

### Save
- Local-first disk backend (atomic writes, type-preserving, sha256 checksum);
  `CloudSaveBackend` that syncs to the canonical cloud when configured, local
  otherwise.

### Online (EOS, via GD-EOS, optional dependency)
- Identity: anonymous Device ID login through EOS Connect (verified live).
- NetworkManager: ENet local + EOS P2P transport behind the `Net` facade.
- Lobbies: create/leave + invites over EOS Connect (no Epic account).
- Voice: EOS RTC mic mute + per-player volume on the lobby room.
- Achievements / stats / leaderboards via EOS.
- Social: lobby invites + an `ISocial` seam (friends come from platform/backend,
  not EOS).

### Shared services
- Audio (buses, music crossfade, pooled SFX), Settings (ConfigFile, drives the
  audio buses), Scenes (async load + overlay stack), Controls (rebind + per-
  platform glyphs), Locale (TranslationServer wrapper).

### UI
- Shared theme, settings panel (wired to Settings/Audio), main + pause menus.

### Tooling
- Doppler-injected secrets; `scripts/` (check, test, dev, ci, fetch-eos,
  test-eos-live); GitHub Actions CI (boundary guard + import + tests); example
  game under `examples/`.

### Backend (`backend/`, not deployed)
- Canonical-account service (Vercel + Neon + R2): platform-token SSO -> session
  JWT, save metadata + R2 signed URLs, cross-platform link codes. Typechecks
  clean; deploy steps in `backend/README`.
