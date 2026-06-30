# Changelog

All notable changes to the base are recorded here. The public API in
`addons/core/api/` follows semver: breaking changes to it are a major bump;
internals under `_internal/` can change in any patch.

## [0.1.0] - 2026-06-30

### Added
- Addon scaffold (`addons/core`) with the public-API / `_internal` boundary.
- `CoreEvents` global signal bus.
- `Platform` service locator with desktop build-target detection and per-
  interface backend binding (console targets stubbed).
- Facade autoloads: `Save`, `Net`, `Identity` (lazy backend resolution; warn
  cleanly when no backend is bound yet).
- Interface stubs: `ISaveable`, `ISaveBackend`, `IIdentityProvider`,
  `IAchievements`, `IStore`, `IVoice`.
- DTOs: `SaveData`, `LobbyInfo`, `AccountInfo`.
- `GameConfig` resource for per-game module toggles and settings.
