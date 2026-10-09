extends RefCounted
## Encode and decode save payloads without ever building an Object.
##
## Saves are var_to_bytes, read back with bytes_to_var, which refuses objects.
## The old var_to_str text format is never parsed: str_to_var builds live
## objects, so a planted text save could run a script. A text or unparseable
## payload decodes to null and counts as corrupt.

# '{' opens every old text envelope. A binary dictionary starts with type id 27.
const _TEXT_START := 0x7b


static func encode(value: Variant) -> PackedByteArray:
	return var_to_bytes(value)


static func decode(bytes: PackedByteArray) -> Variant:
	if bytes.is_empty():
		return null
	if bytes[0] == _TEXT_START:
		push_error("[SaveCodec] refused an old text-format save")
		return null
	return bytes_to_var(bytes)
