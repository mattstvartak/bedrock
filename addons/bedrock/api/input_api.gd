extends Node
## Controls — input rebinding over Godot's InputMap, persisted via Settings, plus
## per-platform button-glyph ids so a game shows the right prompt on each device.
##
## The base returns glyph *ids* (e.g. "ps_cross"); the game maps those to its own
## glyph art. Built-in ui_* actions are left at their defaults and not persisted.

signal rebound(action: StringName, event: InputEvent)

enum Family { KEYBOARD, XBOX, PLAYSTATION, NINTENDO, GENERIC }

const _SECTION := "input"


func _ready() -> void:
	load_bindings()


## Replace the action's event of the same device class (keyboard vs joypad) with
## `event`, keeping the other class so a player keeps both a key and a pad binding.
func rebind(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	for e in InputMap.action_get_events(action):
		var e_pad := e is InputEventJoypadButton or e is InputEventJoypadMotion
		if e_pad == is_pad:
			InputMap.action_erase_event(action, e)
	InputMap.action_add_event(action, event)
	rebound.emit(action, event)
	save_bindings()


func reset_all() -> void:
	InputMap.load_from_project_settings()
	Settings.set_value(_SECTION, "bindings", {})
	Settings.save_settings()


func events_for(action: StringName) -> Array[InputEvent]:
	return InputMap.action_get_events(action) if InputMap.has_action(action) else [] as Array[InputEvent]


## A stable glyph id for an event, e.g. "key_space", "xbox_a", "ps_cross". The
## game maps these ids to its own glyph textures.
func glyph_id(event: InputEvent, family := Family.GENERIC) -> String:
	if event is InputEventKey:
		return "key_" + OS.get_keycode_string((event as InputEventKey).physical_keycode).to_lower()
	if event is InputEventJoypadButton:
		return _pad_glyph((event as InputEventJoypadButton).button_index, family)
	return "unknown"


## Best-effort controller family from the first connected pad, else keyboard.
func detect_family() -> Family:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return Family.KEYBOARD
	var jname := Input.get_joy_name(pads[0]).to_lower()
	if "xbox" in jname or "xinput" in jname:
		return Family.XBOX
	if "dualsense" in jname or "dualshock" in jname or "sony" in jname or "ps4" in jname or "ps5" in jname:
		return Family.PLAYSTATION
	if "nintendo" in jname or "switch" in jname or "joy-con" in jname or "pro controller" in jname:
		return Family.NINTENDO
	return Family.GENERIC


func save_bindings() -> void:
	var data: Dictionary = {}
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		var evs: Array = []
		for e in InputMap.action_get_events(action):
			var d := _event_to_dict(e)
			if not d.is_empty():
				evs.append(d)
		if not evs.is_empty():
			data[String(action)] = evs
	Settings.set_value(_SECTION, "bindings", data)
	Settings.save_settings()


func load_bindings() -> void:
	var data: Variant = Settings.get_value(_SECTION, "bindings", {})
	if not data is Dictionary:
		return
	for action_str in data:
		var action := StringName(action_str)
		if not InputMap.has_action(action) or not data[action_str] is Array:
			continue
		var events: Array[InputEvent] = []
		for d in data[action_str]:
			var e := _dict_to_event(d) if d is Dictionary else null
			if e != null:
				events.append(e)
		# Keep the project defaults if nothing in the saved entry was usable.
		if events.is_empty():
			continue
		InputMap.action_erase_events(action)
		for e in events:
			InputMap.action_add_event(action, e)


func _event_to_dict(e: InputEvent) -> Dictionary:
	var d := {"dev": e.device}
	if e is InputEventKey:
		var k := e as InputEventKey
		d.merge({"t": "key", "phys": k.physical_keycode, "code": k.keycode})
	elif e is InputEventJoypadButton:
		d.merge({"t": "pad", "btn": (e as InputEventJoypadButton).button_index})
	elif e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		d.merge({"t": "axis", "axis": m.axis, "val": m.axis_value})
	elif e is InputEventMouseButton:
		d.merge({"t": "mouse", "btn": (e as InputEventMouseButton).button_index})
	else:
		return {}
	return d


func _dict_to_event(d: Dictionary) -> InputEvent:
	var e: InputEvent = null
	match d.get("t", ""):
		"key":
			var k := InputEventKey.new()
			# Older saves only stored "code", which was the physical keycode.
			k.physical_keycode = int(d.get("phys", d.get("code", 0)))
			k.keycode = int(d.get("code", 0)) if d.has("phys") else 0
			e = k
		"pad":
			var b := InputEventJoypadButton.new()
			b.button_index = int(d.get("btn", 0))
			e = b
		"axis":
			var m := InputEventJoypadMotion.new()
			m.axis = int(d.get("axis", 0))
			m.axis_value = signf(float(d.get("val", 1.0)))
			e = m
		"mouse":
			var mb := InputEventMouseButton.new()
			mb.button_index = int(d.get("btn", 1))
			e = mb
		_:
			return null
	e.device = int(d.get("dev", -1))
	return e


func _pad_glyph(btn: int, family: Family) -> String:
	# Face buttons by JoyButton index: 0=A/Cross, 1=B/Circle, 2=X/Square, 3=Y/Triangle.
	match family:
		Family.PLAYSTATION:
			return {0: "ps_cross", 1: "ps_circle", 2: "ps_square", 3: "ps_triangle"}.get(btn, "ps_btn_%d" % btn)
		Family.NINTENDO:
			# Nintendo's physical layout swaps A/B and X/Y vs Xbox.
			return {0: "nx_b", 1: "nx_a", 2: "nx_y", 3: "nx_x"}.get(btn, "nx_btn_%d" % btn)
		_:
			return {0: "xbox_a", 1: "xbox_b", 2: "xbox_x", 3: "xbox_y"}.get(btn, "xbox_btn_%d" % btn)
