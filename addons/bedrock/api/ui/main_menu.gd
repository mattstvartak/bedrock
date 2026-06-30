class_name BedrockMainMenu
extends BedrockMenu
## Play / Settings / Quit. The game listens to the signals (or replaces this
## scene entirely); the kit just provides a wired default.

signal play_pressed
signal settings_pressed
signal quit_pressed


func _ready() -> void:
	build([
		{"text": "Play", "pressed": func(): play_pressed.emit()},
		{"text": "Settings", "pressed": func(): settings_pressed.emit()},
		{"text": "Quit", "pressed": func(): quit_pressed.emit()},
	])
