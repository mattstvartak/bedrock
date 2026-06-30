extends Node
## Identity — public identity facade.
##
## Games call Identity.login() and friends. They never see the provider
## (EOS Connect / canonical account / console). Resolution is lazy so a backend
## can be bound after this autoload's _ready.

var _provider  ## IIdentityProvider


func is_logged_in() -> bool:
	var p = _resolve()
	return p != null and p.is_logged_in()


## -> AccountInfo, or null when unauthenticated / no provider.
func current_account():
	var p = _resolve()
	return p.current_account() if p else null


func login() -> void:
	var p = _resolve()
	if p == null:
		push_warning("[Identity] no provider bound; running unauthenticated.")
		return
	p.login()


## Steam login with a Steam session ticket (from GodotSteam). No-op if the
## provider doesn't support it.
func login_steam(ticket: String) -> void:
	var p = _resolve()
	if p != null and p.has_method("login_steam"):
		p.login_steam(ticket)


func logout() -> void:
	var p = _resolve()
	if p:
		p.logout()


## Opt-in cross-platform: start a link on this device, returns a short code the
## player enters on the other platform to merge accounts.
func begin_link_code() -> String:
	var p = _resolve()
	return p.begin_link_code() if p else ""


func redeem_link_code(code: String) -> void:
	var p = _resolve()
	if p:
		p.redeem_link_code(code)


func _resolve():
	if _provider == null and Platform.has_backend(Platform.IDENTITY):
		_provider = Platform.get_backend(Platform.IDENTITY)
	return _provider
