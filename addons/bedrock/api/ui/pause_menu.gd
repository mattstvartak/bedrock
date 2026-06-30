class_name BedrockPauseMenu
extends BedrockMenu
## Resume / Settings / Quit to menu. Toggle it with open()/close(); opening pauses
## the tree, closing unpauses, so it works as a drop-in pause overlay.

signal resume_pressed
signal settings_pressed
signal quit_pressed


func _ready() -> void:
	build([
		{"text": "Resume", "pressed": _resume},
		{"text": "Settings", "pressed": func(): settings_pressed.emit()},
		{"text": "Quit to Menu", "pressed": func(): quit_pressed.emit()},
	])
	process_mode = Node.PROCESS_MODE_ALWAYS  # stays responsive while paused
	hide()


func open() -> void:
	show()
	get_tree().paused = true


func close() -> void:
	hide()
	get_tree().paused = false


func _resume() -> void:
	close()
	resume_pressed.emit()
