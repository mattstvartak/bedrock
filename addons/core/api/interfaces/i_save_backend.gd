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


func list_slots() -> Array:
	return []


func delete(_slot: int) -> void:
	push_error("ISaveBackend.delete() not implemented")
