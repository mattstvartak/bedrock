class_name GameConfig
extends Resource
## A game ships one GameConfig to declare which modules are on and to feed them
## settings. The base reads it at boot. Toggling lets each game pull in only
## what it needs without forking the base.

@export_group("Modules")
@export var enable_save: bool = true
@export var enable_identity: bool = true
@export var enable_multiplayer: bool = true
@export var enable_lobbies: bool = true
@export var enable_voice: bool = true
@export var enable_achievements: bool = false
@export var enable_social: bool = false
@export var enable_localization: bool = true

@export_group("Identity")
## Allow a no-login anonymous Device ID as a fallback credential.
@export var allow_anonymous_device_id: bool = true

@export_group("Save")
@export_enum("last_write_wins", "keep_highest_progress")
var conflict_policy: String = "last_write_wins"

@export_group("Net")
@export_enum("p2p_host", "dedicated_server")
var authority_model: String = "p2p_host"
