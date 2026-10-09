extends Node
## Save safety test. A save file must never run code when it is loaded, and old
## text-format saves of plain data must still load.
## Run: godot --headless --path . res://tests/save_safety_test.tscn
## Exits 0 on pass, 1 on any failure (so CI can gate on it).

const SLOT := 9
const PLANT := "user://planted_script.gd"
const LocalSave := preload("res://addons/bedrock/_internal/save/local_save_backend.gd")
const SaveCodec := preload("res://addons/bedrock/_internal/save/save_codec.gd")

var _fails: Array[String] = []
var _local := LocalSave.new()


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


func _slot_path() -> String:
	return "user://saves/slot_%d.save" % SLOT


func _put_text(text: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open(_slot_path(), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _ready() -> void:
	print("== save safety test ==")
	_local.delete(SLOT)
	Engine.set_meta("save_plant_ran", false)

	var src := FileAccess.open(PLANT, FileAccess.WRITE)
	src.store_string("extends RefCounted\nfunc _init():\n\tEngine.set_meta(\"save_plant_ran\", true)\n")
	src.close()

	# Planted script in the old text format, as an Object and as a Resource.
	for payload in [
		'{"slot": 9, "blob": Object(RefCounted,"script":Resource("%s"))}' % PLANT,
		'{"slot": 9, "blob": Resource("%s")}' % PLANT,
	]:
		_put_text(payload)
		var got: Dictionary = _local.read(SLOT)
		var env = SaveCodec.decode(FileAccess.get_file_as_bytes(_slot_path()))
		_check(env == null, "planted save is refused")
		_check(not Engine.get_meta("save_plant_ran"), "planted script did not run")
		_check(got.is_empty(), "refused save reads as empty")

	# Normal round trip through the real backend.
	var data := {"level": 7, "pos": Vector2(1, 2), "name": "hero"}
	_local.write(SLOT, data)
	var back: Dictionary = _local.read(SLOT)
	_check(back == data and typeof(back["level"]) == TYPE_INT, "round trip keeps values and types")
	_check(FileAccess.get_file_as_bytes(_slot_path())[0] != 0x7b, "new saves are binary")

	# Old plain-data text save still loads.
	var old_blob := {"level": 3, "gold": 40}
	_put_text(var_to_str({
		"slot": SLOT, "updated_unix": 1, "checksum": var_to_str(old_blob).sha256_text(), "blob": old_blob,
	}))
	_check(_local.read(SLOT) == old_blob, "legacy text save of plain data loads")

	_local.delete(SLOT)
	DirAccess.remove_absolute(PLANT)

	if _fails.is_empty():
		print("== ALL PASS ==")
		get_tree().quit(0)
	else:
		print("== FAILURES: %s ==" % ", ".join(_fails))
		get_tree().quit(1)
