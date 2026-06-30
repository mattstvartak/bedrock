@tool
extends EditorPlugin
## Registers the base's public autoloads when a game enables this plugin.
## Order matters: CoreEvents and Platform come up before the facades that lean
## on them. Dictionary insertion order is preserved, so this order is the boot
## order in the consuming project.

const AUTOLOADS := {
	"CoreEvents": "res://addons/core/api/event_bus.gd",
	"Platform": "res://addons/core/api/platform_services.gd",
	"Identity": "res://addons/core/api/identity_api.gd",
	"Save": "res://addons/core/api/save_api.gd",
	"Net": "res://addons/core/api/net_api.gd",
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
