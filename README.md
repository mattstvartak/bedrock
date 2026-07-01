# Bedrock

A reusable, modular base for building Godot games. Drop it into a project and you
get a universal save system (local + cloud), online multiplayer, identity, and
the shared services every game needs (audio, settings, scenes, input, locale),
plus a small UI kit. GDScript, Godot 4.7, desktop-first with a clean path to
console.

You build your game on the public API and never touch the internals, so the base
can be updated under you without breaking your game.

---

## Requirements

- **Godot 4.7**
- For the **online features** (identity, multiplayer, lobbies, voice,
  achievements), the GD-EOS extension. Single-player games don't need it.

## Install

Add Bedrock to your game and make the addon available at `addons/bedrock`:

```bash
# from your game project root
git submodule add https://github.com/mattstvartak/bedrock.git vendor/bedrock
cp -r vendor/bedrock/addons/bedrock addons/bedrock     # or symlink it
```

Then enable the **Bedrock** plugin in `Project Settings → Plugins`. Enabling it
registers the autoloads you'll use: `CoreEvents`, `Platform`, `Save`, `Net`,
`Identity`, `Audio`, `Settings`, `Scenes`, `Controls`, `Locale`, `Achievements`,
`Social`.

For online, install the GD-EOS extension so `addons/gd-eos` sits alongside
`addons/bedrock` in your project (it's a ~76MB binary, gitignored). The bedrock
checkout's `scripts/fetch-eos.sh` downloads it; copy the resulting
`addons/gd-eos` into your project, then open the editor once so Godot registers
the extension.

Single-player games can skip GD-EOS entirely: the EOS-backed internals ship
`.gdignore`'d, so the editor opens clean without the SDK and the online code is
only loaded at runtime when it's actually present. `fetch-eos.sh` removes those
markers when you install GD-EOS.

## The one rule

Use the **public API only** (everything under `addons/bedrock/api/`): the
autoloads above, the `class_name`'d interfaces in `api/interfaces/`, the DTOs in
`api/dto/`, the UI in `api/ui/`, and `GameConfig`.

**Never reference `addons/bedrock/_internal/`.** That's implementation and it
changes between releases. Touching it is the one thing that will break your game
on an update.

## Configure what you need

Ship a `GameConfig` resource to turn modules on or off. Save it as
`res://game_config.tres` and Bedrock picks it up at boot.

```gdscript
# create a GameConfig resource (Inspector) or in code:
var cfg := GameConfig.new()
cfg.enable_multiplayer = false   # single-player title
cfg.enable_voice = false
cfg.conflict_policy = "last_write_wins"   # or "keep_highest_progress"
cfg.authority_model = "p2p_host"          # or "dedicated_server"
```

---

## Saving

Implement `ISaveable` on anything you want persisted, register it, then read and
write by slot. Save data is yours; Bedrock never parses it. Include your own
version field and migrate in `restore()`.

```gdscript
class_name PlayerProgress extends ISaveable

var level := 1
var gold := 0

func save_id() -> String: return "player_progress"
func capture() -> Dictionary: return {"version": 1, "level": level, "gold": gold}
func restore(data: Dictionary) -> void:
	level = data.get("level", 1)
	gold = data.get("gold", 0)
```

```gdscript
var progress := PlayerProgress.new()
Save.register(progress)

if Save.has_slot(0):
	Save.read(0)          # loads disk into your saveables

Save.write(0)            # writes disk; syncs to the cloud if signed in + configured
await Save.pull(0)       # pull the cloud copy down, then Save.read(0)
```

Writes are **local-first**: disk first, cloud async. Cloud sync turns on
automatically once the player is signed in and a backend is configured (see
Online below). Conflicts arrive on `CoreEvents.sync_conflict(slot, local, cloud)`.

## Shared services

```gdscript
# Audio (Master / Music / SFX buses, crossfade, pooled sfx)
Audio.play_music(my_track, 1.0)
Audio.play_sfx(my_sound)

# Settings (persisted; audio settings drive the buses)
Settings.set_value("audio", "Music", 0.5)
Settings.save_settings()

# Scenes (async loading + overlay stack for pause/dialog)
await Scenes.change_scene_async("res://levels/level_2.tscn")
Scenes.push_overlay("res://ui/pause.tscn")

# Controls (rebinding + per-platform button glyphs)
Controls.rebind("jump", event)
var glyph := Controls.glyph_id(event, Controls.detect_family())  # e.g. "ps_cross"

# Locale
Locale.set_locale("es")
```

## UI kit

Instance the prefabs, connect their signals, restyle with your own `Theme`.

```gdscript
var menu := BedrockMainMenu.new()
menu.play_pressed.connect(_start_game)
menu.settings_pressed.connect(func(): add_child(BedrockSettingsPanel.new()))
add_child(menu)
```

`BedrockSettingsPanel` (audio sliders + fullscreen, wired to Settings/Audio),
`BedrockMainMenu`, `BedrockPauseMenu`, and `BedrockTheme.make()` are included.

---

## Online (optional)

Online uses Epic Online Services through GD-EOS. Players sign in with the
identity they already have (Steam, console, or an anonymous Device ID) — **no
Epic account required**. You provide your EOS product config via environment
variables at build/run time: `EOS_PRODUCT_ID`, `EOS_SANDBOX_ID`,
`EOS_DEPLOYMENT_ID`, `EOS_CLIENT_ID`, `EOS_CLIENT_SECRET`.

```gdscript
Identity.login()                 # anonymous Device ID
Identity.login_steam(ticket)     # Steam session ticket (from GodotSteam)

CoreEvents.identity_changed.connect(func(account):
	if account: print("signed in: ", account.canonical_uuid))
```

### Multiplayer

```gdscript
# local / LAN
Net.host(4)                      # ENet server, you're peer 1
Net.join("127.0.0.1")

# online (EOS P2P)
Net.create_lobby(8, true)        # max players, voice on
Net.host_online()                # host the session
Net.join_online(host_puid)       # a client joins by the host's id
Net.invite_to_lobby(target_puid)

# voice (on the lobby's RTC room)
Net.set_muted(true)
```

Peer changes arrive on `CoreEvents.peer_joined / peer_left`; lobby changes on
`CoreEvents.lobby_updated`. Netcode prediction (rollback or snapshot) is yours to
add on top; Bedrock provides the transport, lobbies, and voice.

### Achievements

```gdscript
Achievements.unlock("first_win")
Achievements.set_stat("kills", 10)
Achievements.submit_leaderboard("high_score", 9000)
```

### Cloud save + cross-platform accounts

Cloud save and cross-platform continuity run through a small backend (Vercel +
Neon + Vercel Blob, in `backend/`). Deploy your own (see `backend/README.md`) and
point the game at it with `BEDROCK_BACKEND_URL`. Once that's set and the player is
signed in, `Save.write()` syncs to the cloud and `Save.pull()` brings it back,
keyed to the player's canonical account so the save follows them across platforms.

---

## Example + reference

- `examples/demo.tscn` is a runnable game built only on the public API. Read it
  for a working end-to-end example. Run it with
  `godot --path . res://examples/demo.tscn`.
- `CLAUDE.md` (and `backend/CLAUDE.md`) document the architecture and gotchas in
  depth, useful whether you're a person or an agent extending the base.
- `CHANGELOG.md` tracks releases. The public API in `api/` follows semver.

## Status

`0.1.0`, feature-complete and verified live (identity login and the full
cross-platform save round-trip). A few refinements (achievement reads, lobby
browser, console backends) are mapped but not yet built. See the changelog.

## Author

Matt Stvartak
