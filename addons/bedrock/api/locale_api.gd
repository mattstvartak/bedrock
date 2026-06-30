extends Node
## Locale — thin wrapper over TranslationServer for switching language and
## looking up strings. CSV translations are imported by Godot at build time and
## listed in project settings; this drives them at runtime and lets a game add
## more (DLC/mod languages) on the fly.

signal locale_changed(code: String)


func set_locale(code: String) -> void:
	TranslationServer.set_locale(code)
	locale_changed.emit(code)


func get_locale() -> String:
	return TranslationServer.get_locale()


func available() -> PackedStringArray:
	return TranslationServer.get_loaded_locales()


func t(key: StringName) -> String:
	return TranslationServer.translate(key)


func add_translation(path: String) -> void:
	var res = load(path)
	if res is Translation:
		TranslationServer.add_translation(res)
	else:
		push_error("[Locale] %s is not a Translation resource" % path)
