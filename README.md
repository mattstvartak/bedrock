# Bedrock

A reusable, modular base for building multiple Godot games. It carries the
shared systems (universal save, online multiplayer, identity, and common
services) so each game starts from a real foundation instead of an empty
project. Built in GDScript for Godot 4.7, desktop-first (Steam / Epic /
standalone) with a clean path to console later.

The full design lives in przm-docs (project "Godot Universal Base"). This repo
is the implementation.

## Consuming it in a game

Bedrock ships as the `addons/bedrock` addon, consumed as a git submodule:

```
git submodule add <this-repo-url> addons/bedrock_src
# point addons/bedrock at addons/bedrock_src/addons/bedrock, or vendor addons/bedrock directly
```

Then enable the **Bedrock** plugin in Project Settings → Plugins. Enabling it
registers the public autoloads (`CoreEvents`, `Platform`, `Identity`, `Save`,
`Net`).

## The boundary (important)

Game code touches the **public API only**:

- Autoload facades: `Save`, `Net`, `Identity`
- The service locator: `Platform`
- The signal bus: `CoreEvents`
- `class_name`'d interfaces in `addons/bedrock/api/interfaces/`
- DTOs in `addons/bedrock/api/dto/`
- `GameConfig` to toggle modules

Game code must **never** reference `addons/bedrock/_internal/`. That folder is
implementation and changes freely between releases. This separation is what
lets Bedrock be maintained independently and versioned with semver.

## Development

Secrets live in Doppler (project `bedrock`), never in a committed file. The
repo is bound to the `bedrock/dev` config via `doppler.yaml`, so commands pull
config at runtime:

```
scripts/check.sh   # headless import, catches parse errors (CI gate)
scripts/test.sh    # headless test suite, secrets injected via doppler run
scripts/dev.sh     # open the editor with secrets injected
```

First time on a new machine: `doppler login` then `doppler setup`.

## Status

`0.1.0` — scaffold. Public surface and the locator are in place; the modules
behind the interfaces (identity, save, net, lobbies, voice, ...) are tracked on
the "Core Build" board.

## Author

Matt Stvartak
