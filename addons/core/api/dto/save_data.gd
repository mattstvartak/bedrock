class_name SaveData
extends Resource
## Plain transport DTO for one save slot. The base treats `blob` as opaque and
## carries the metadata it needs for sync and conflict resolution.

@export var slot: int = 0
@export var schema_version: int = 1
@export var updated_unix: int = 0
@export var checksum: String = ""
@export var blob: Dictionary = {}
