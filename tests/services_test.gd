extends Node
## Shared-services test: Settings, Audio, Scenes.
## Run via scripts/test.sh (it globs tests/*_test.tscn). Exits nonzero on failure.

var _fails: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


func _ready() -> void:
	print("== shared services test ==")

	# Audio set up its buses at boot.
	_check(AudioServer.get_bus_index("Music") != -1, "Music bus created")
	_check(AudioServer.get_bus_index("SFX") != -1, "SFX bus created")

	# Bus volume round-trips through linear<->dB.
	Audio.set_bus_volume("SFX", 0.5)
	_check(absf(Audio.get_bus_volume("SFX") - 0.5) < 0.02, "SFX bus volume set/get ~0.5")

	# Settings persist to disk and drive the audio buses.
	Settings.set_value("audio", "Music", 0.25)
	Settings.save_settings()
	var reloaded := ConfigFile.new()
	reloaded.load(Settings.PATH)
	_check(reloaded.get_value("audio", "Music", -1.0) == 0.25, "settings persisted to disk")
	_check(absf(Audio.get_bus_volume("Music") - 0.25) < 0.02, "Music bus volume applied from settings")

	# Scenes overlay stack, fileless via a runtime-built PackedScene.
	var packed := PackedScene.new()
	packed.pack(Control.new())
	Scenes.push_overlay_packed(packed)
	_check(Scenes.overlay_depth() == 1, "overlay pushed")
	Scenes.pop_overlay()
	_check(Scenes.overlay_depth() == 0, "overlay popped")

	if _fails.is_empty():
		print("== ALL PASS ==")
		get_tree().quit(0)
	else:
		print("== FAILURES: %s ==" % ", ".join(_fails))
		get_tree().quit(1)
