extends ISaveBackend
## Local-first disk backend for ISaveBackend.
##
## Writes each slot atomically (temp file, then rename) under user://saves. Uses
## Godot's binary variant encoding (via SaveCodec) so saved values keep their real
## types (ints stay ints, Vector2 stays Vector2), unlike a JSON round-trip, and
## loading a save can never construct an Object. The cloud sync layer
## (R2) will wrap this same interface; the local copy is always the source of
## truth the game reads from.

const SaveCodec := preload("res://addons/bedrock/_internal/save/save_codec.gd")

const DIR := "user://saves"
const EXT := ".save"
const BAK := ".bak"
const TMP := ".tmp"

# Test hook: truncate the temp write to simulate a short write.
var _test_short_write := false


## write() never throws; write_checked() returns true only when the new data is on disk and decodes back. On false the
## previous save is untouched. The last good slot is kept as <slot>.bak.
func write(slot: int, data: Dictionary) -> void:
	write_checked(slot, data)


## Same as write() but reports the outcome, for callers that surface errors.
func write_checked(slot: int, data: Dictionary) -> bool:
	_ensure_dir()
	var blob_text := var_to_str(data)
	var envelope := {
		"slot": slot,
		"updated_unix": int(Time.get_unix_time_from_system()),
		"checksum": blob_text.sha256_text(),
		"blob": data,
	}
	var p := _path(slot)
	var tmp := p + TMP
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("[LocalSave] cannot open %s for write" % tmp)
		return false
	var bytes := SaveCodec.encode(envelope)
	if _test_short_write:
		bytes = bytes.slice(0, bytes.size() / 2)
	var stored := f.store_buffer(bytes)
	var file_err := f.get_error()
	f.close()
	if not stored or file_err != OK or _load(tmp) == null:
		push_error("[LocalSave] write to %s failed verification, slot %d left as is" % [tmp, slot])
		DirAccess.remove_absolute(tmp)
		return false
	if _load(p) != null:
		DirAccess.copy_absolute(p, p + BAK)
	# Rename is the atomic step: a crash mid-write can't corrupt the live slot. If it
	# fails (or Windows drops the target first), read() recovers from .bak or .tmp.
	var err := DirAccess.rename_absolute(tmp, p)
	if err != OK:
		push_error("[LocalSave] rename failed for slot %d (err %d)" % [slot, err])
		return false
	return true


## Slot data, or {} when the slot is empty or unreadable. Use read_checked() to tell
## those two apart.
func read(slot: int) -> Dictionary:
	var got = read_checked(slot)
	return {} if got == null else got


## Slot data, {} when no slot, .bak or .tmp file exists, and null when files exist but
## none decodes. Tries the slot, then .bak, then a leftover .tmp.
func read_checked(slot: int) -> Variant:
	var found := false
	for p in [_path(slot), _path(slot) + BAK, _path(slot) + TMP]:
		if not FileAccess.file_exists(p):
			continue
		found = true
		var envelope = _load(p)
		if envelope == null:
			push_error("[LocalSave] %s is corrupt or unreadable" % p)
			continue
		var blob: Dictionary = envelope["blob"]
		if envelope.get("checksum", "") != var_to_str(blob).sha256_text():
			push_warning("[LocalSave] checksum mismatch in %s (file edited or corrupted)" % p)
		return blob
	return null if found else {}


## The decoded envelope at a path, or null when it is missing, undecodable or has no blob.
func _load(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var envelope = SaveCodec.decode(FileAccess.get_file_as_bytes(path))
	if typeof(envelope) != TYPE_DICTIONARY or not envelope.has("blob") or typeof(envelope["blob"]) != TYPE_DICTIONARY:
		return null
	return envelope


## Envelope metadata for a slot (no blob), used for cloud conflict comparison.
func meta(slot: int) -> Dictionary:
	var p := _path(slot)
	if not FileAccess.file_exists(p):
		return {"exists": false}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {"exists": false}
	var envelope = SaveCodec.decode(f.get_buffer(f.get_length()))
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
		var base := file.trim_suffix(BAK).trim_suffix(TMP)
		if base.ends_with(EXT):
			var n := base.trim_suffix(EXT).trim_prefix("slot_").to_int()
			if not out.has(n):
				out.append(n)
	out.sort()
	return out


func delete(slot: int) -> void:
	for p in [_path(slot), _path(slot) + BAK, _path(slot) + TMP]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _path(slot: int) -> String:
	return "%s/slot_%d%s" % [DIR, slot, EXT]


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)
