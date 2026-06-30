class_name ISaveable
extends RefCounted
## Implemented by the GAME. The base captures and restores through this and
## never parses the contents. The game owns its own versioned schema and any
## migrations inside restore().

## Stable id for this saveable within a slot (e.g. "player_progress").
func save_id() -> String:
	push_error("ISaveable.save_id() not implemented")
	return ""


## Return a plain Dictionary snapshot. Include a version field you control.
func capture() -> Dictionary:
	push_error("ISaveable.capture() not implemented")
	return {}


## Restore from a snapshot. Migrate older schema versions here.
func restore(_data: Dictionary) -> void:
	push_error("ISaveable.restore() not implemented")
