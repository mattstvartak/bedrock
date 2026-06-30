class_name BedrockMenu
extends Control
## A tiny vertical button menu with controller focus, used by the main and pause
## menus. Build it with rows of {text, callback}; the first button grabs focus.

func build(rows: Array) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	add_child(vbox)
	var first: Button = null
	for row in rows:
		var b := Button.new()
		b.text = row.get("text", "")
		b.custom_minimum_size.x = 220
		var cb: Callable = row.get("pressed", Callable())
		if cb.is_valid():
			b.pressed.connect(cb)
		vbox.add_child(b)
		if first == null:
			first = b
	if first != null:
		first.grab_focus()
