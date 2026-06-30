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


func write(slot: int = 0) -> void:
	var backend = _resolve()
	if backend == null:
		push_warning("[Save] no backend bound; write skipped.")
		return
	backend.write(slot, _capture())
	CoreEvents.save_written.emit(slot)


func read(slot: int = 0) -> void:
	var backend = _resolve()
	if backend == null:
		push_warning("[Save] no backend bound; read skipped.")
		return
	_restore(backend.read(slot))
	CoreEvents.save_loaded.emit(slot)


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
