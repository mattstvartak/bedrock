class_name BedrockSettingsPanel
extends Control
## Reusable settings panel: audio volume sliders (Master/Music/SFX) and a
## fullscreen toggle, wired to Settings (which drives the Audio buses). Built in
## code so it works with no scene file; games can instance it, restyle it with a
## Theme, and add their own rows. Emits `closed` when the Back button is pressed.

signal closed

const _BUSES := ["Master", "Music", "SFX"]

var _sliders: Dictionary = {}


func _ready() -> void:
	# Fill the host area and center the content in it. A CenterContainer does the
	# centering reliably; set_anchors_preset(PRESET_CENTER) alone keeps the default
	# offsets and just pins the content's top-left to the middle, which overflows.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vbox := VBoxContainer.new()
	center.add_child(vbox)

	for bus in _BUSES:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = bus
		label.custom_minimum_size.x = 110
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.custom_minimum_size.x = 220
		slider.value = float(Settings.get_value("audio", bus, 1.0))
		slider.value_changed.connect(_on_volume.bind(bus))
		slider.drag_ended.connect(_on_drag_ended)
		row.add_child(label)
		row.add_child(slider)
		vbox.add_child(row)
		_sliders[bus] = slider

	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = bool(Settings.get_value("video", "fullscreen", false))
	fullscreen.toggled.connect(_on_fullscreen)
	vbox.add_child(fullscreen)

	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func():
		Settings.save_settings()
		closed.emit())
	vbox.add_child(back)

	# Controller/keyboard focus starts on the first slider.
	if not _BUSES.is_empty():
		_sliders[_BUSES[0]].grab_focus()


## Programmatic setter (also fires the value_changed wiring).
func set_volume(bus: String, value: float) -> void:
	if _sliders.has(bus):
		_sliders[bus].value = value


func _on_volume(value: float, bus: String) -> void:
	Settings.set_value("audio", bus, value)  # Settings applies it to the Audio bus


# Save once the slider is let go, not on every step.
func _on_drag_ended(_changed: bool) -> void:
	Settings.save_settings()


func _exit_tree() -> void:
	Settings.save_settings()


func _on_fullscreen(on: bool) -> void:
	Settings.set_value("video", "fullscreen", on)
	Settings.save_settings()
