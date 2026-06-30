extends Control
## Tiny example "game" that composes the Bedrock public API the way a real game
## would: the UI kit menus, a Settings panel, a save slot, identity login, and
## hosting a local session. It only ever touches the public surface
## (Save / Settings / Net / Identity + api/ui), never the _internal modules.
##
## Run it: godot --path . res://examples/demo.tscn

const SLOT := 0

var _progress := DemoProgress.new()
var _menu: BedrockMainMenu
var _settings: BedrockSettingsPanel
var _status: Label


class DemoProgress extends ISaveable:
	var plays := 0
	func save_id() -> String: return "demo_progress"
	func capture() -> Dictionary: return {"version": 1, "plays": plays}
	func restore(data: Dictionary) -> void: plays = int(data.get("plays", 0))


func _ready() -> void:
	Save.register(_progress)
	if Save.has_slot(SLOT):
		Save.read(SLOT)
	# Silent login if EOS is available (no-op otherwise).
	Identity.login()
	_status = Label.new()
	_status.position = Vector2(20, 20)
	add_child(_status)
	show_menu()


func show_menu() -> void:
	_clear()
	_menu = BedrockMainMenu.new()
	_menu.play_pressed.connect(start_play)
	_menu.settings_pressed.connect(open_settings)
	_menu.quit_pressed.connect(func(): get_tree().quit())
	add_child(_menu)
	_set_status("plays: %d" % _progress.plays)


func open_settings() -> void:
	_clear()
	_settings = BedrockSettingsPanel.new()
	_settings.closed.connect(show_menu)
	add_child(_settings)


## Bump progress, persist it, and host a local session.
func start_play() -> void:
	_progress.plays += 1
	Save.write(SLOT)
	Net.host(4)
	_set_status("hosting (host=%s peer=%d) plays=%d" % [Net.is_host(), Net.peer_id(), _progress.plays])


func plays() -> int:
	return _progress.plays


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func _clear() -> void:
	for node in [_menu, _settings]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_menu = null
	_settings = null
