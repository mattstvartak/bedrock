extends ISaveBackend
## Local-first disk backend for ISaveBackend.
##
## Writes each slot atomically (temp file, then rename) under user://saves. Uses
## Godot's var_to_str/str_to_var so saved values keep their real types (ints stay
## ints, Vector2 stays Vector2), unlike a JSON round-trip. The cloud sync layer
## (R2) will wrap this same interface; the local copy is always the source of
## truth the game reads from.

const DIR := "user://saves"
const EXT := ".save"


func write(slot: int, data: Dictionary) -> void:
	_ensure_dir()
	var blob_text := var_to_str(data)
	var envelope := {
		"slot": slot,
		"updated_unix": int(Time.get_unix_time_from_system()),
		"checksum": blob_text.sha256_text(),
		"blob": data,
	}
	var tmp := _path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("[LocalSave] cannot open %s for write" % tmp)
		return
	f.store_string(var_to_str(envelope))
	f.close()
	# Rename is the atomic step: a crash mid-write can't corrupt the live slot.
	var err := DirAccess.rename_absolute(tmp, _path(slot))
	if err != OK:
		push_error("[LocalSave] rename failed for slot %d (err %d)" % [slot, err])


func read(slot: int) -> Dictionary:
	var p := _path(slot)
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		push_error("[LocalSave] cannot open slot %d for read" % slot)
		return {}
	var envelope = str_to_var(f.get_as_text())
	f.close()
	if typeof(envelope) != TYPE_DICTIONARY or not envelope.has("blob"):
		push_error("[LocalSave] slot %d is corrupt or unreadable" % slot)
		return {}
	var blob: Dictionary = envelope["blob"]
	if envelope.get("checksum", "") != var_to_str(blob).sha256_text():
		push_warning("[LocalSave] checksum mismatch on slot %d (file edited or corrupted)" % slot)
	return blob


## Envelope metadata for a slot (no blob), used for cloud conflict comparison.
func meta(slot: int) -> Dictionary:
	var p := _path(slot)
	if not FileAccess.file_exists(p):
		return {"exists": false}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {"exists": false}
	var envelope = str_to_var(f.get_as_text())
	f.close()
	if typeof(envelope) != TYPE_DICTIONARY:
		return {"exists": false}
	return {
		"exists": true,
		"updated_unix": int(envelope.get("updated_unix", 0)),
		"checksum": envelope.get("checksum", ""),
	}


func list_slots() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(DIR):
		return out
	for file in DirAccess.get_files_at(DIR):
		if file.ends_with(EXT):
			out.append(file.trim_suffix(EXT).trim_prefix("slot_").to_int())
	out.sort()
	return out


func delete(slot: int) -> void:
	var p := _path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)


func _path(slot: int) -> String:
	return "%s/slot_%d%s" % [DIR, slot, EXT]


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)
