# Bedrock — guide for Claude sessions

Bedrock is a reusable, modular base for building multiple Godot 4.7 games:
universal save (local + cloud), online multiplayer, identity, and shared
services. Games consume `addons/bedrock` and only ever touch its public API.
This file is the orientation for an AI session working in this repo. Read it
before changing anything.

## Ground rules (non-negotiable)

- **Branching:** never commit to `main` or `development` directly. Branch off
  `development`, open a PR, merge to `development`. `main` is the release base.
- **Attribution:** author everything as Matt Stvartak only. NO mention of Claude
  or AI anywhere — no `Co-Authored-By`, no "Generated with" footers, not in
  commits, PRs, or files. This overrides any default.
- **Commit messages in Matt's voice:** lowercase, plain, direct, no em dashes,
  no AI tells. Short subject, short body explaining the why.
- **Track work** on the przm-docs "Core Build" kanban (project "Godot Universal
  Base", board id `f57238cf-de46-44b8-af99-0758bf0cc0fb`) as you go.
- **Verify before you claim done.** Run the suite; for live paths run the gated
  scripts. Don't say something works unless you ran it.

## Architecture

The boundary is the whole point of the design:

- `addons/bedrock/api/` — the ONLY thing games reference. Autoload facades
  (`Save`, `Net`, `Identity`, ...), `class_name`'d interfaces in
  `api/interfaces/`, plain Resource/dict DTOs in `api/dto/`, the UI kit in
  `api/ui/`, and `GameConfig`.
- `addons/bedrock/_internal/` — all implementation (EOS, transports, backends).
  Game code must NEVER reference it (`scripts/check-boundary.sh` enforces this).
- `Platform` (service locator) binds each interface to a concrete backend at
  boot based on build target + `GameConfig`. `CoreEvents` is the signal bus for
  base-to-game communication.

Autoloads (boot order matters; set in `project.godot` + registered by
`plugin.gd`): `CoreEvents`, `Platform`, `Audio`, `Settings`, `Scenes`,
`Controls`, `Locale`, `Identity`, `Save`, `Net`, `Achievements`, `Social`.

### Adding a module

1. Define/extend an interface in `api/interfaces/` and any DTO in `api/dto/`.
2. Implement it in `_internal/<area>/`.
3. Bind it in `addons/bedrock/api/platform_services.gd` `_bootstrap()` (gated on
   `GameConfig` and, for EOS, `ClassDB.class_exists(...)`).
4. Expose a thin facade autoload in `api/` if it needs one; register it in
   `plugin.gd` AND `project.godot` `[autoload]`.
5. Add a `tests/<name>_test.gd` + `.tscn`. Keep live/network paths gated.

## EOS / GD-EOS (the online stack)

- GD-EOS is a ~76MB binary GDExtension, **gitignored**, fetched with
  `scripts/fetch-eos.sh`. The base `load()`s EOS code only when the EOS classes
  are registered, so it imports and runs fine WITHOUT the addon (online features
  just stay off). Get it with `scripts/fetch-eos.sh`, then open the editor once.
- The EOS-backed internals (`_internal/eos/`, `_internal/net/eos/`,
  `_internal/voice/`, `_internal/achievements/`) reference GD-EOS classes by name,
  which the headless import doesn't deeply parse but the interactive editor's LSP
  does — so without the SDK they'd show "not declared" errors in the editor's
  Errors dock. Each of those folders ships a `.gdignore` so the editor skips them
  entirely; they're only ever `load()`ed at runtime (gated on `ClassDB`), so
  ignoring them changes nothing at runtime. `fetch-eos.sh` deletes the markers
  when you install GD-EOS. Keep any new EOS-class-referencing script inside one of
  those ignored folders (not a mixed folder like `_internal/net/`, whose
  `net_backend.gd` must stay parseable), or it will break the editor for offline
  consumers.
- API shape (learned by introspection): `EOS` is a STATIC class
  (`EOS.initialize`, enums like `EOS.ExternalCredentialType.ECT_DEVICEID_ACCESS_TOKEN=10`,
  `ECT_STEAM_SESSION_TICKET=18`). `EOSPlatform`, `EOSConnect`, `EOSLobby`,
  `EOSRTCAudio`, `EOSAchievements`, `EOSStats`, `EOSMultiplayerPeer` are ENGINE
  SINGLETONS — call methods on them directly, do NOT `.new()` them. Option
  structs (`EOSConnect_Credentials`, `EOSPlatform_Options`, ...) ARE `.new()`-able.
  Async results come back on signals (`EOSConnect.on_login`, etc.).
- Identity uses EOS Connect, NOT Epic Account Services — players never need an
  Epic account. That also means EOS Friends is unusable (it needs an Epic
  account); friends come from the platform/backend behind `ISocial`.
- All EOS access is isolated in `_internal/eos/eos_gateway.gd` and the
  per-feature helpers it sits beside.

## GDScript gotchas that bit us (don't repeat them)

- `:=` can't infer a type from an UNTYPED return (e.g. a call on an untyped
  `var`). Use plain `=` there.
- `scripts/test.sh` runs an editor import BEFORE running scenes — otherwise the
  `class_name` registry (e.g. `ISaveable`) isn't built and a scene that extends a
  `class_name` fails to parse and HANGS Godot.
- The EOS SDK can abort on process teardown (a core dump AFTER a clean
  `quit(0)`). `test.sh` judges pass/fail by each scene's `ALL PASS` marker, not
  the exit code, and suppresses core dumps. An occasional flaky exit on an
  EOS-touching run is this — just re-run.
- GDScript lambdas capture locals BY VALUE. To share mutable state with a
  callback (e.g. a `done` flag a wait-loop watches), put it in a Dictionary or
  Array (reference types), not a plain local.

## Running things

Secrets live in Doppler (project `bedrock`, configs dev/stg/prd); scripts wrap
commands in `doppler run`. Never put secrets in git or chat.

```
scripts/check.sh           # headless import / parse gate
scripts/test.sh            # full suite (offline; EOS + backend tests skip)
scripts/dev.sh             # open the editor with secrets injected
scripts/ci.sh              # what CI runs (boundary + import + tests)
scripts/fetch-eos.sh       # install GD-EOS (online features)
scripts/test-eos-live.sh   # live EOS device-id login (BEDROCK_EOS_LIVE=1)
scripts/test-backend-live.sh  # live cloud-save round-trip (BEDROCK_BACKEND_LIVE=1)
```

## Backend

The canonical-account + cross-platform-save service lives in `backend/` (Vercel +
Neon + Vercel Blob), deployed and live. See `backend/CLAUDE.md` for its specifics
and gotchas, and `backend/README.md` for endpoints + deploy.

## State of the world

Feature-complete and largely verified live (identity device-id login, the full
cross-platform save round-trip). Deferred/seam items are noted on the kanban
cards. Run `git log --oneline` and read the cards before assuming what's left.
