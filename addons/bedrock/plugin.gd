@tool
extends EditorPlugin
## Registers Bedrock's public autoloads when a game enables this plugin.
## Order matters: CoreEvents and Platform come up before the facades that lean
## on them. Dictionary insertion order is preserved, so this order is the boot
## order in the consuming project.

const AUTOLOADS := {
	"CoreEvents": "res://addons/bedrock/api/event_bus.gd",
	"Platform": "res://addons/bedrock/api/platform_services.gd",
	"Audio": "res://addons/bedrock/api/audio_api.gd",
	"Settings": "res://addons/bedrock/api/settings_api.gd",
	"Scenes": "res://addons/bedrock/api/scene_api.gd",
	"Controls": "res://addons/bedrock/api/input_api.gd",
	"Locale": "res://addons/bedrock/api/locale_api.gd",
	"Identity": "res://addons/bedrock/api/identity_api.gd",
	"Save": "res://addons/bedrock/api/save_api.gd",
	"Net": "res://addons/bedrock/api/net_api.gd",
	"Achievements": "res://addons/bedrock/api/achievements_api.gd",
	"Social": "res://addons/bedrock/api/social_api.gd",
}


func _enter_tree() -> void:
	# Idempotent: a game's project (or this dev project) may already declare them.
	for singleton in AUTOLOADS:
		if not ProjectSettings.has_setting("autoload/" + singleton):
			add_autoload_singleton(singleton, AUTOLOADS[singleton])


func _exit_tree() -> void:
	var names := AUTOLOADS.keys()
	names.reverse()
	for singleton in names:
		remove_autoload_singleton(singleton)
