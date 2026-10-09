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

	_test_recovery()

	_local.delete(SLOT)
	DirAccess.remove_absolute(PLANT)

	if _fails.is_empty():
		print("== ALL PASS ==")
		get_tree().quit(0)
	else:
		print("== FAILURES: %s ==" % ", ".join(_fails))
		get_tree().quit(1)


func _test_recovery() -> void:
	var v1 := {"level": 1}
	var v2 := {"level": 2}
	var p := _slot_path()
	_local.delete(SLOT)
	_local.write(SLOT, v1)

	_local._test_short_write = true
	_check(not _local.write_checked(SLOT, v2), "short write reports failure")
	_local._test_short_write = false
	_check(_local.read(SLOT) == v1, "failed write keeps previous save")
	_check(not FileAccess.file_exists(p + ".tmp"), "failed write cleans up temp")

	_check(_local.write_checked(SLOT, v2) and FileAccess.file_exists(p + ".bak"), "good write keeps a .bak")
	_check(_local.read(SLOT) == v2, "good write replaces slot")

	var full := FileAccess.get_file_as_bytes(p)
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_buffer(full.slice(0, full.size() / 2))
	f.close()
	_check(_local.read(SLOT) == v1, "truncated slot falls back to .bak")

	_local.delete(SLOT)
	_check(_local.read_checked(SLOT) is Dictionary and _local.read_checked(SLOT).is_empty(), "empty slot reads as {}")
	_local.write(SLOT, v1)
	DirAccess.rename_absolute(p, p + ".tmp")
	_check(_local.read(SLOT) == v1, "valid .tmp with missing slot is recovered")
	_check(_local.list_slots().has(SLOT), "recoverable slot is listed once")

	for ext in ["", ".bak", ".tmp"]:
		var g := FileAccess.open(p + ext, FileAccess.WRITE)
		g.store_string("junk")
		g.close()
	_check(_local.read_checked(SLOT) == null, "all copies corrupt reads as null")
	_check(_local.read(SLOT).is_empty(), "read() maps corrupt to {}")

	_local.delete(SLOT)
	_check(not FileAccess.file_exists(p) and not FileAccess.file_exists(p + ".bak") and not FileAccess.file_exists(p + ".tmp"), "delete removes slot, .bak and .tmp")
