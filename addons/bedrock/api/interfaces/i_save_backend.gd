class_name ISaveBackend
extends RefCounted
## Implemented by the BASE, one per platform: own-cloud + local on desktop,
## native save block on console. Local-first: write disk first (atomically),
## then sync the cloud async. A game never sees which backend is in use.

func write(_slot: int, _data: Dictionary) -> void:
	push_error("ISaveBackend.write() not implemented")


func read(_slot: int) -> Dictionary:
	push_error("ISaveBackend.read() not implemented")
	return {}


## Same as write() but reports whether the data reached disk. Override it to report real
## failures; the default assumes write() worked.
func write_checked(slot: int, data: Dictionary) -> bool:
	write(slot, data)
	return true


## Slot data, {} when the slot is empty, null when it exists but cannot be read.
func read_checked(slot: int) -> Variant:
	return read(slot)


func list_slots() -> Array:
	return []


func delete(_slot: int) -> void:
	push_error("ISaveBackend.delete() not implemented")
