extends Node
## Save safety test. A save file must never run code when it is loaded, and old
## text-format saves are refused, never parsed.
## Run: godot --headless --path . res://tests/save_safety_test.tscn
## Exits 0 on pass, 1 on any failure (so CI can gate on it).

const SLOT := 9
const PLANT := "user://planted_script.gd"
const LocalSave := preload("res://addons/bedrock/_internal/save/local_save_backend.gd")
const SaveCodec := preload("res://addons/bedrock/_internal/save/save_codec.gd")
const CloudSave := preload("res://addons/bedrock/_internal/save/cloud_save_backend.gd")

var _fails: Array[String] = []
var _local := LocalSave.new()
var _events: Array[String] = []
var _state := {"level": 0}


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
		'{"blob":{"x":Object;\n(RefCounted,"script":Resource;\n("%s"))}}' % PLANT,
		'{"blob":{"x":Object\u0001(RefCounted,"script":Resource\u0001("%s"))}}'% PLANT,
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

	# Old text saves are refused even when they hold only plain data.
	var old_blob := {"level": 3, "gold": 40}
	_put_text(var_to_str({
		"slot": SLOT, "updated_unix": 1, "checksum": var_to_str(old_blob).sha256_text(), "blob": old_blob,
	}))
	_check(_local.read(SLOT).is_empty(), "legacy text save is refused")

	_test_recovery()
	_test_object_write()
	_test_fallback_order()
	_test_cloud_decode()
	_test_facade()

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


func _test_object_write() -> void:
	var good := {"level": 1}
	var bad := {"level": 2, "thing": RefCounted.new()}
	var p := _slot_path()
	_local.delete(SLOT)
	_local.write(SLOT, good)
	_check(not _local.write_checked(SLOT, bad), "write holding an Object reports failure")
	_check(not _local.write_checked(SLOT, bad), "second Object write also reports failure")
	_check(not FileAccess.file_exists(p + ".tmp"), "Object write cleans up temp")
	_check(_local.read_checked(SLOT) == good, "good save survives Object writes")
	if FileAccess.file_exists(p + ".bak"):
		_check(_local.read_checked(SLOT) == good, "bak never holds a bad slot")
	_local.delete(SLOT)


func _raw_save(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(SaveCodec.encode({
		"slot": SLOT, "updated_unix": 1, "checksum": var_to_str(data).sha256_text(), "blob": data,
	}))
	f.close()


func _test_fallback_order() -> void:
	var p := _slot_path()
	_local.delete(SLOT)
	DirAccess.make_dir_recursive_absolute("user://saves")
	_raw_save(p + ".tmp", {"level": 2})
	_raw_save(p + ".bak", {"level": 1})
	_check(_local.read(SLOT) == {"level": 2}, "missing slot with valid .tmp and older .bak restores .tmp")
	_check(_local.last_source == "tmp", "tmp fallback reports its source")

	_local.delete(SLOT)
	_raw_save(p + ".bak", {"level": 1})
	_check(_local.read(SLOT) == {"level": 1} and _local.last_source == "bak", "bak fallback reports its source")

	# Checksum mismatch counts as corrupt for that file, so the next copy is tried.
	_local.delete(SLOT)
	var bad := FileAccess.open(p, FileAccess.WRITE)
	bad.store_buffer(SaveCodec.encode({"slot": SLOT, "checksum": "nope", "blob": {"level": 99}}))
	bad.close()
	_raw_save(p + ".bak", {"level": 1})
	_check(_local.read(SLOT) == {"level": 1}, "checksum mismatch falls through to the next copy")
	var only_bad := FileAccess.open(p + ".bak", FileAccess.WRITE)
	only_bad.store_buffer(SaveCodec.encode({"slot": SLOT, "checksum": "nope", "blob": {"level": 99}}))
	only_bad.close()
	_check(_local.read_checked(SLOT) == null, "all copies failing checksum reads as null")

	_local.delete(SLOT)
	_local.write(SLOT, {"level": 4})
	_check(_local.read(SLOT) == {"level": 4} and _local.last_source == "", "primary read reports no fallback")

	# Facade: a fallback read still restores and returns true, plus save_recovered.
	var probe := Probe.new()
	probe.state = _state
	var old_backend = Save._backend
	Save._backend = _local
	Save.register(probe)
	var got: Array = []
	var on_rec := func(s, src): got.append([s, src])
	CoreEvents.save_recovered.connect(on_rec)
	_local.delete(SLOT)
	_raw_save(p + ".bak", {"probe": {"level": 8}})
	var ok: bool = Save.read(SLOT)
	_check(ok and _state["level"] == 8 and got == [[SLOT, "bak"]], "facade fallback read restores and emits save_recovered")
	got.clear()
	_local.write(SLOT, {"level": 9})
	_check(Save.read(SLOT) and got.is_empty(), "facade primary read emits no save_recovered")
	CoreEvents.save_recovered.disconnect(on_rec)
	Save.unregister("probe")
	Save._backend = old_backend
	_local.delete(SLOT)


func _test_cloud_decode() -> void:
	var cloud := CloudSave.new()
	_check(cloud._decode("") == null, "cloud decode of empty blob is a failure")
	_check(cloud._decode(Marshalls.raw_to_base64("junk".to_utf8_buffer())) == null, "cloud decode of junk is a failure")
	var good := {"level": 5}
	_check(cloud._decode(Marshalls.raw_to_base64(SaveCodec.encode(good))) == good, "cloud decode of a good blob")
	var evil := '{"x":Object;\n(RefCounted,"script":Resource;\n("%s"))}' % PLANT
	_check(cloud._decode(Marshalls.raw_to_base64(evil.to_utf8_buffer())) == null, "cloud decode refuses planted blob")
	cloud.free()


class Probe extends ISaveable:
	var state: Dictionary

	func save_id() -> String:
		return "probe"

	func capture() -> Dictionary:
		return {"level": state["level"]}

	func restore(data: Dictionary) -> void:
		state["level"] = data["level"]


func _test_facade() -> void:
	var probe := Probe.new()
	probe.state = _state
	var old_backend = Save._backend
	Save._backend = _local
	Save.register(probe)
	var on_written := func(_s): _events.append("written")
	var on_loaded := func(_s): _events.append("loaded")
	var on_failed := func(_s, _r): _events.append("failed")
	CoreEvents.save_written.connect(on_written)
	CoreEvents.save_loaded.connect(on_loaded)
	CoreEvents.save_failed.connect(on_failed)
	var p := _slot_path()
	_local.delete(SLOT)

	_state["level"] = 5
	_events.clear()
	_check(Save.write(SLOT) and _events == ["written"], "facade write ok emits save_written")
	_state["level"] = 0
	_events.clear()
	_check(Save.read(SLOT) and _events == ["loaded"] and _state["level"] == 5, "facade read ok restores and emits save_loaded")

	_local._test_short_write = true
	_events.clear()
	_check(not Save.write(SLOT) and _events == ["failed"], "facade failed write emits save_failed only")
	_local._test_short_write = false

	probe.state = {"level": RefCounted.new()}
	_events.clear()
	_check(not Save.write(SLOT) and _events == ["failed"], "facade Object write emits save_failed only")
	probe.state = _state

	_local.delete(SLOT)
	_state["level"] = 3
	_events.clear()
	_check(not Save.read(SLOT) and _events.is_empty() and _state["level"] == 3, "facade read of empty slot is false, silent")

	for ext in ["", ".bak", ".tmp"]:
		var g := FileAccess.open(p + ext, FileAccess.WRITE)
		g.store_string("junk")
		g.close()
	_events.clear()
	_check(not Save.read(SLOT) and _events == ["failed"] and _state["level"] == 3, "facade read of corrupt slot fails, restores nothing")

	CoreEvents.save_written.disconnect(on_written)
	CoreEvents.save_loaded.disconnect(on_loaded)
	CoreEvents.save_failed.disconnect(on_failed)
	Save.unregister("probe")
	Save._backend = old_backend
	_local.delete(SLOT)
