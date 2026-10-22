class_name IIdentityProvider
extends RefCounted
## Implemented by the BASE. EOS Connect + a per-platform credential provider
## (Steam ticket, console token, anonymous Device ID) live behind this. Silent
## SSO is the default path. The canonical-account backend takes platform_token()
## to mint a session; link codes (the opt-in cross-platform merge) live there.

func is_logged_in() -> bool:
	return false


## -> AccountInfo, or null when unauthenticated.
func current_account():
	return null


func login() -> void:
	push_error("IIdentityProvider.login() not implemented")


func logout() -> void:
	pass


## A credential the canonical-account backend can verify for the signed-in
## player: {"platform": String, "token": String}. {} when logged out.
func platform_token() -> Dictionary:
	return {}
