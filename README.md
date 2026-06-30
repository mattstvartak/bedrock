# Godot Universal Base

A reusable, modular base for building multiple Godot games. It carries the
shared systems (universal save, online multiplayer, identity, and common
services) so each game starts from a real foundation instead of an empty
project. Built in GDScript for Godot 4.7, desktop-first (Steam / Epic /
standalone) with a clean path to console later.

The full design lives in przm-docs (project "Godot Universal Base"). This repo
is the implementation.

## Consuming it in a game

The base ships as the `addons/core` addon, consumed as a git submodule:

```
git submodule add <this-repo-url> addons/core_src
# point addons/core at addons/core_src/addons/core, or vendor addons/core directly
```

Then enable the **Core** plugin in Project Settings → Plugins. Enabling it
registers the public autoloads (`CoreEvents`, `Platform`, `Identity`, `Save`,
`Net`).

## The boundary (important)

Game code touches the **public API only**:

- Autoload facades: `Save`, `Net`, `Identity`
- The service locator: `Platform`
- The signal bus: `CoreEvents`
- `class_name`'d interfaces in `addons/core/api/interfaces/`
- DTOs in `addons/core/api/dto/`
- `GameConfig` to toggle modules

Game code must **never** reference `addons/core/_internal/`. That folder is
implementation and changes freely between releases. This separation is what
lets the base be maintained independently and versioned with semver.

## Status

`0.1.0` — scaffold. Public surface and the locator are in place; the modules
behind the interfaces (identity, save, net, lobbies, voice, ...) are tracked on
the "Core Build" board.

## Author

Matt Stvartak
