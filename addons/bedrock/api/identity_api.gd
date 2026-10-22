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


## Opt-in cross-platform merge. On the device that keeps its saves, `await` a
## code (good for ten minutes) and show it to the player. On the other device,
## `await redeem_link_code(code)`: that device's platform identity moves onto the
## first account and its own cloud saves are dropped. Both return "" / false when
## no backend is configured or the player is not signed in to it.
func begin_link_code() -> String:
	var a = _account()
	return await a.begin_link_code() if a else ""


func redeem_link_code(code: String) -> bool:
	var a = _account()
	return await a.redeem_link_code(code) if a else false


func _resolve():
	if _provider == null and Platform.has_backend(Platform.IDENTITY):
		_provider = Platform.get_backend(Platform.IDENTITY)
	return _provider


func _account():
	return Platform.get_backend(Platform.ACCOUNT)
