class_name IIdentityProvider
extends RefCounted
## Implemented by the BASE. EOS Connect + a per-platform credential provider
## (Steam ticket, console token, anonymous Device ID) plus the canonical account
## backend live behind this. Silent SSO is the default path; link codes are the
## opt-in cross-platform merge.

func is_logged_in() -> bool:
	return false


## -> AccountInfo, or null when unauthenticated.
func current_account():
	return null


func login() -> void:
	push_error("IIdentityProvider.login() not implemented")


func logout() -> void:
	pass


func begin_link_code() -> String:
	return ""


func redeem_link_code(_code: String) -> void:
	pass
