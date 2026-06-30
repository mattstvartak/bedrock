class_name IStore
extends RefCounted
## Deferred for v1: interface only, no implementation built. Games can compile
## against it now; EOS Ecom / platform stores get wired when a title needs to
## sell something.

func list_offers() -> Array:
	return []


func owned() -> Array:
	return []


func purchase(_offer_id: String) -> void:
	push_error("IStore is stubbed in v1 (no store module built yet)")
