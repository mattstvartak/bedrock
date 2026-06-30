extends Node
## UI kit test. Exercises the SettingsPanel logic (sliders drive Settings + the
## Audio buses) and checks the menu components instance and expose their signals.

var _fails: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


func _ready() -> void:
	print("== ui kit test ==")

	# Theme builds.
	_check(BedrockTheme.make() is Theme, "BedrockTheme.make returns a Theme")

	# Settings panel: moving a slider updates Settings and the audio bus.
	var panel := BedrockSettingsPanel.new()
	add_child(panel)
	panel.set_volume("Music", 0.3)
	_check(absf(float(Settings.get_value("audio", "Music", -1.0)) - 0.3) < 0.001,
		"settings slider writes to Settings")
	_check(absf(Audio.get_bus_volume("Music") - 0.3) < 0.02,
		"settings slider drives the Music audio bus")

	# Menu components instance and expose their signals.
	var main := BedrockMainMenu.new()
	add_child(main)
	_check(main.has_signal("play_pressed") and main.has_signal("quit_pressed"), "main menu signals")

	var pause := BedrockPauseMenu.new()
	add_child(pause)
	_check(pause.has_signal("resume_pressed"), "pause menu resume signal")
	_check(not pause.visible, "pause menu starts hidden")

	if _fails.is_empty():
		print("== ALL PASS ==")
		get_tree().quit(0)
	else:
		print("== FAILURES: %s ==" % ", ".join(_fails))
		get_tree().quit(1)
