extends Node
## Save module test. Exercises the real local backend on disk through the public
## Save facade. Run: godot --headless --path . res://tests/save_test.tscn
## Exits 0 on pass, 1 on any failure (so CI can gate on it).

class Progress extends ISaveable:
	var level := 1
	var gold := 0
	var who := "hero"
	func save_id() -> String: return "progress"
	func capture() -> Dictionary: return {"version": 1, "level": level, "gold": gold, "who": who}
	func restore(data: Dictionary) -> void:
		level = data.get("level", 0)
		gold = data.get("gold", 0)
		who = data.get("who", "")

var _fails: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


func _ready() -> void:
	print("== save module test ==")

	_check(Platform.has_backend(Platform.SAVE), "local save backend bound at boot")

	var p := Progress.new()
	p.level = 7
	p.gold = 250
	p.who = "wanderer"
	Save.register(p)
	Save.delete(3)  # start from a clean slot

	Save.write(3)
	_check(Save.has_slot(3), "slot 3 exists after write")

	# Clobber in memory, then read back from disk.
	p.level = 0
	p.gold = 0
	p.who = ""
	Save.read(3)
	_check(p.level == 7 and p.gold == 250 and p.who == "wanderer",
		"values restored from disk with types preserved (int stays int)")
	_check(typeof(p.level) == TYPE_INT, "restored level is an int, not a float")

	_check(Save.list_slots().has(3), "list_slots reports slot 3")

	Save.delete(3)
	_check(not Save.has_slot(3), "slot 3 gone after delete")

	if _fails.is_empty():
		print("== ALL PASS ==")
		get_tree().quit(0)
	else:
		print("== FAILURES: %s ==" % ", ".join(_fails))
		get_tree().quit(1)
