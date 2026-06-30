extends RefCounted
## EOS lobby helper. References EOSLobby (a singleton), so the net backend
## load()s it only when GD-EOS is present. Requires an Identity login first (the
## local user id is the logged-in PUID). Lobby/member changes are reported on
## CoreEvents.lobby_updated; the lobby's RTC room is what the voice module joins.

const _DEFAULT_BUCKET := "bedrock"

var _lobby_id := ""


func _init() -> void:
	# Member/lobby change notifications -> the signal bus.
	EOSLobby.on_create_lobby.connect(_on_create_lobby)
	EOSLobby.on_join_lobby.connect(_on_join_lobby)
	EOSLobby.lobby_update_received.connect(func(_d): _emit_update())
	EOSLobby.lobby_member_update_received.connect(func(_d): _emit_update())
	EOSLobby.lobby_member_status_received.connect(func(_d): _emit_update())


func create(max_members: int, enable_voice: bool, bucket_id: String = _DEFAULT_BUCKET) -> bool:
	var uid = _local_user()
	if uid == null:
		return false
	var opts := EOSLobby_CreateLobbyOptions.new()
	opts.local_user_id = uid
	opts.max_lobby_members = max_members
	opts.bucket_id = bucket_id
	opts.presence_enabled = true
	opts.allow_invites = true
	opts.enable_rtc_room = enable_voice
	EOSLobby.create_lobby(opts)
	return true


func leave() -> void:
	if _lobby_id == "":
		return
	var uid = _local_user()
	if uid != null:
		EOSLobby.leave_lobby(uid, _lobby_id)
	_lobby_id = ""


func current_lobby_id() -> String:
	return _lobby_id


func _local_user():
	if EOSConnect.get_logged_in_users_count() > 0:
		return EOSConnect.get_logged_in_user_by_index(0)
	return null


func _on_create_lobby(info) -> void:
	if int(info.result_code) == 0:
		_lobby_id = str(info.lobby_id)
	_emit_update()


func _on_join_lobby(info) -> void:
	if int(info.result_code) == 0:
		_lobby_id = str(info.lobby_id)
	_emit_update()


func _emit_update() -> void:
	var lobby := LobbyInfo.new()
	lobby.id = _lobby_id
	CoreEvents.lobby_updated.emit(lobby)
