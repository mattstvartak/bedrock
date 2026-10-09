extends RefCounted
## Encode and decode save payloads without ever building an Object.
##
## New saves are var_to_bytes. Older saves are var_to_str text; those are only
## parsed after rejecting any mention of a token that can construct an Object or
## load a Resource (a whole-word match, since Godot lets whitespace, control chars
## and comments sit before the bracket), since str_to_var would otherwise run an attacker's script on load.
## A rejected or unparseable payload decodes to null and counts as corrupt.

# '{' opens every legacy text envelope. A binary dictionary starts with type id 27.
const _TEXT_START := 0x7b
const _OBJECT_TOKEN := "\\b(Object|Resource|ExtResource|SubResource)\\b"


static func encode(value: Variant) -> PackedByteArray:
	return var_to_bytes(value)


static func decode(bytes: PackedByteArray) -> Variant:
	if bytes.is_empty():
		return null
	if bytes[0] != _TEXT_START:
		return bytes_to_var(bytes)
	var text := bytes.get_string_from_utf8()
	var re := RegEx.create_from_string(_OBJECT_TOKEN)
	if re.search(text) != null:
		push_error("[SaveCodec] refused legacy save containing an object token")
		return null
	return str_to_var(text)
