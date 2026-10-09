extends Node
## Save — public save facade.
##
## A game registers ISaveable objects, then calls write/read by slot. Storage
## (local-first disk plus cloud) lives behind ISaveBackend; the game never sees
## where the bytes go. The game owns its own versioned schema and migrations;
## the base treats each saveable's payload as opaque.

var _backend  ## ISaveBackend
var _saveables: Dictionary = {}  ## String save_id -> ISaveable


func register(saveable) -> void:
	_saveables[saveable.save_id()] = saveable


func unregister(save_id: String) -> void:
	_saveables.erase(save_id)


## True when the slot reached disk. Emits save_written on success, save_failed otherwise.
func write(slot: int = 0) -> bool:
	var backend = _resolve()
	if backend == null:
		push_warning("[Save] no backend bound; write skipped.")
		CoreEvents.save_failed.emit(slot, "no backend")
		return false
	if not backend.write_checked(slot, _capture()):
		CoreEvents.save_failed.emit(slot, "write failed")
		return false
	CoreEvents.save_written.emit(slot)
	return true


## True when a slot was restored. A corrupt slot restores nothing and emits save_failed;
## an empty or missing slot returns false quietly.
func read(slot: int = 0) -> bool:
	var backend = _resolve()
	if backend == null:
		push_warning("[Save] no backend bound; read skipped.")
		return false
	var data = backend.read_checked(slot)
	if data == null:
		CoreEvents.save_failed.emit(slot, "slot is corrupt")
		return false
	if data.is_empty():
		return false
	_restore(data)
	CoreEvents.save_loaded.emit(slot)
	var source = backend.get("last_source")
	if source != null and source != "":
		CoreEvents.save_recovered.emit(slot, source)
	return true


func has_slot(slot: int = 0) -> bool:
	return slot in list_slots()


func list_slots() -> Array:
	var backend = _resolve()
	return backend.list_slots() if backend else []


func delete(slot: int = 0) -> void:
	var backend = _resolve()
	if backend:
		backend.delete(slot)


## Pull the cloud copy into local disk, then call read() to load it. No-op for
## local-only backends. Conflicts arrive on CoreEvents (sync_* signals).
func pull(slot: int = 0) -> void:
	var backend = _resolve()
	if backend != null and backend.has_method("pull"):
		await backend.pull(slot)


func _capture() -> Dictionary:
	var out: Dictionary = {}
	for id in _saveables:
		out[id] = _saveables[id].capture()
	return out


func _restore(data: Dictionary) -> void:
	for id in _saveables:
		if data.has(id):
			_saveables[id].restore(data[id])


func _resolve():
	if _backend == null and Platform.has_backend(Platform.SAVE):
		_backend = Platform.get_backend(Platform.SAVE)
	return _backend
