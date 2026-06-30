extends Node
## Controls + Locale test. Run via scripts/test.sh. Exits nonzero on failure.

var _fails: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


func _ready() -> void:
	print("== input + locale test ==")

	# --- Controls: rebind, glyphs, persistence ---
	InputMap.add_action("test_jump")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	Controls.rebind("test_jump", space)

	var evs := Controls.events_for("test_jump")
	_check(evs.size() == 1 and evs[0] is InputEventKey, "rebind set one key event")
	_check(Controls.glyph_id(space) == "key_space", "keyboard glyph id is key_space")

	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	_check(Controls.glyph_id(pad, Controls.Family.PLAYSTATION) == "ps_cross", "playstation glyph id")
	_check(Controls.glyph_id(pad, Controls.Family.XBOX) == "xbox_a", "xbox glyph id")
	_check(Controls.glyph_id(pad, Controls.Family.NINTENDO) == "nx_b", "nintendo glyph id (a/b swap)")

	# Clear, then restore from persisted settings.
	InputMap.action_erase_events("test_jump")
	Controls.load_bindings()
	_check(Controls.events_for("test_jump").size() == 1, "binding restored from settings")

	# --- Locale ---
	var before := Locale.get_locale()
	Locale.set_locale("es")
	_check(Locale.get_locale() == "es", "locale switched to es")
	Locale.set_locale(before)

	if _fails.is_empty():
		print("== ALL PASS ==")
		get_tree().quit(0)
	else:
		print("== FAILURES: %s ==" % ", ".join(_fails))
		get_tree().quit(1)
