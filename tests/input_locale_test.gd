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

	# Every event type survives a save + reload; pad events answer all devices.
	InputMap.add_action("test_multi")
	var ka := InputEventKey.new()
	ka.physical_keycode = KEY_A
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = -1.0
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	var pad_btn := InputEventJoypadButton.new()
	pad_btn.button_index = JOY_BUTTON_X
	pad_btn.device = 0
	for e in [ka, stick, mouse, pad_btn]:
		InputMap.action_add_event("test_multi", e)
	Controls.save_bindings()
	var saved: Dictionary = Settings.get_value("input", "bindings", {})
	for d in saved["test_multi"]:
		d.erase("dev") # older saves had no device field
	saved["test_multi"] += ["junk", {"t": "bogus"}]
	Settings.set_value("input", "bindings", saved)
	InputMap.action_erase_events("test_multi")
	Controls.load_bindings()
	var kinds := {}
	for e in Controls.events_for("test_multi"):
		kinds[e.get_class()] = e
	_check(kinds.has("InputEventKey") and (kinds["InputEventKey"] as InputEventKey).physical_keycode == KEY_A, "key restored")
	_check(kinds.has("InputEventJoypadMotion") and (kinds["InputEventJoypadMotion"] as InputEventJoypadMotion).axis_value == -1.0, "stick restored with sign")
	_check(kinds.has("InputEventMouseButton") and (kinds["InputEventMouseButton"] as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT, "mouse button restored")
	_check(kinds.has("InputEventJoypadButton"), "pad button restored")
	_check((kinds["InputEventJoypadMotion"] as InputEvent).device == -1, "stick restored on all devices when none was saved")
	_check(Controls.events_for("test_multi").size() == 4, "unknown and malformed entries skipped")

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
