extends IIdentityProvider
## IIdentityProvider backed by EOS Connect, via the EOS gateway.
##
## Default credential is anonymous Device ID. Steam / console credential
## providers layer on later by handing a different external token to the gateway.
## The canonical-account backend (Neon) maps the EOS PUID to a stable account id;
## until that's wired, the PUID stands in as the account id.

var _gateway
var _account: AccountInfo = null
var _logged_in := false


func _init(gateway: Node) -> void:
	_gateway = gateway
	_gateway.login_completed.connect(_on_login_completed)


func is_logged_in() -> bool:
	return _logged_in


func current_account():
	return _account


func login() -> void:
	if _gateway == null:
		return
	_gateway.login_device_id("Player")


func logout() -> void:
	_logged_in = false
	_account = null
	CoreEvents.identity_changed.emit(null)


func _on_login_completed(ok: bool, puid: String) -> void:
	_logged_in = ok
	if ok:
		_account = AccountInfo.new()
		_account.canonical_uuid = puid  # placeholder until the canonical backend maps it
		_account.is_anonymous = true
		CoreEvents.identity_changed.emit(_account)
	else:
		_account = null
		CoreEvents.identity_changed.emit(null)
