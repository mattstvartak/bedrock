class_name AccountInfo
extends Resource
## Plain transport DTO for the signed-in account. Keyed by the canonical uuid
## from our own auth backend; linked_platforms lists the credentials merged onto
## it (steam, psn, xbox, switch, device).

@export var canonical_uuid: String = ""
@export var display_name: String = ""
@export var linked_platforms: Array[String] = []
@export var is_anonymous: bool = false
