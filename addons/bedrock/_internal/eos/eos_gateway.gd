extends Node
## EOS gateway — the one file in Bedrock that touches GD-EOS directly.
##
## It references the EOS classes (EOS, EOSPlatform, EOSConnect, the option
## structs), so it requires the GD-EOS addon (scripts/fetch-eos.sh). Platform
## load()s it only when the EOS classes are registered, so the rest of the base
## runs fine without the addon installed.
##
## EOS config comes from the environment (doppler injects EOS_* at build/run).
## Init is lazy: nothing touches the network until the first login is requested.

signal login_completed(ok: bool, puid: String)

var _initialized := false


## True when GD-EOS is present. Platform gates EOS binding on this.
static func is_available() -> bool:
	return ClassDB.class_exists("EOSConnect") and ClassDB.class_exists("EOSPlatform")


func _process(_delta: float) -> void:
	if _initialized:
		EOSPlatform.tick()


## Initialize EOS + create the platform from env config. Idempotent.
func init_from_env() -> bool:
	if _initialized:
		return true
	if not is_available():
		return false

	var init_opts := EOSInitializeOptions.new()
	init_opts.product_name = "Bedrock"
	init_opts.product_version = "0.1.0"
	EOS.initialize(init_opts)  # AlreadyConfigured on re-init is harmless

	var creds := EOSPlatform_ClientCredentials.new()
	creds.client_id = OS.get_environment("EOS_CLIENT_ID")
	creds.client_secret = OS.get_environment("EOS_CLIENT_SECRET")
	var opts := EOSPlatform_Options.new()
	opts.product_id = OS.get_environment("EOS_PRODUCT_ID")
	opts.sandbox_id = OS.get_environment("EOS_SANDBOX_ID")
	opts.deployment_id = OS.get_environment("EOS_DEPLOYMENT_ID")
	opts.client_credentials = creds
	opts.is_server = false
	EOSPlatform.platform_create(opts)

	if not EOSConnect.on_login.is_connected(_on_login):
		EOSConnect.on_login.connect(_on_login)
	_initialized = true
	return true


## Anonymous Device ID login. Result arrives on login_completed(ok, puid).
func login_device_id(display_name: String) -> void:
	if not init_from_env():
		login_completed.emit(false, "")
		return
	# Ensure a device id exists, then log in. Creating one that already exists
	# just returns a duplicate result; we proceed to login either way.
	EOSConnect.on_create_device_id.connect(
		func(_result_code): _do_login(display_name), CONNECT_ONE_SHOT
	)
	EOSConnect.create_device_id(OS.get_name(), Callable())


## Steam login: the game gets a Steam session ticket (via GodotSteam) and passes
## it here; EOS Connect maps it to the same canonical PUID space. No Epic account.
func login_steam(ticket: String, display_name := "Player") -> void:
	if not init_from_env():
		login_completed.emit(false, "")
		return
	_login_external(EOS.ExternalCredentialType.ECT_STEAM_SESSION_TICKET, ticket, display_name)


func _do_login(display_name: String) -> void:
	_login_external(EOS.ExternalCredentialType.ECT_DEVICEID_ACCESS_TOKEN, "", display_name)


func _login_external(cred_type: int, token: String, display_name: String) -> void:
	var creds := EOSConnect_Credentials.new()
	creds.type = cred_type
	creds.token = token
	var info := EOSConnect_UserLoginInfo.new()
	info.display_name = display_name
	EOSConnect.login(creds, info, Callable())


func _on_login(callback_info) -> void:
	var ok := int(callback_info.result_code) == 0  # EOS_Success
	var puid := ""
	if ok and callback_info.local_user_id != null:
		puid = str(callback_info.local_user_id)
	login_completed.emit(ok, puid)
