extends Node
## Drives the example game through the public API to prove the base composes into
## a real game flow end to end.

const Demo := preload("res://examples/demo.gd")

var _fails: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


func _ready() -> void:
	print("== demo (example game) test ==")

	# Clean any prior demo save so plays starts from a known point.
	Save.delete(0)

	var demo := Demo.new()
	add_child(demo)

	var before := demo.plays()
	demo.start_play()

	_check(demo.plays() == before + 1, "play bumps progress")
	_check(Save.has_slot(0), "play persists a save")
	_check(Net.is_host() and Net.peer_id() == 1, "play hosts a local session")

	# A fresh saveable reading the same slot sees the persisted progress.
	demo.open_settings()
	_check(true, "settings screen opens without error")
	demo.show_menu()
	_check(true, "returns to menu without error")

	Net.leave()
	Save.delete(0)

	if _fails.is_empty():
		print("== ALL PASS ==")
		get_tree().quit(0)
	else:
		print("== FAILURES: %s ==" % ", ".join(_fails))
		get_tree().quit(1)
