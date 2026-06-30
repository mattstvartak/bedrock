extends Node
## Net backend bound to Platform.NET.
##
## ENet for local/LAN play (always available); EOS P2P + lobbies for online play
## when the GD-EOS addon is present. The EOS helpers are loaded lazily on first
## online use, so single-player and local sessions never touch the EOS SDK. Peer
## connect/disconnect is forwarded to CoreEvents; netcode prediction and the
## authority model are the game's choice on top of this.

const _EOS_NET_PATH := "res://addons/bedrock/_internal/net/eos_net.gd"
const _EOS_LOBBY_PATH := "res://addons/bedrock/_internal/net/eos_lobby.gd"
const _DEFAULT_PORT := 7777

var _eos_net = null
var _eos_lobby = null
var _is_host := false
var _active := false  # a real session is up (Godot keeps an offline peer otherwise)


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id): CoreEvents.peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id): CoreEvents.peer_left.emit(id))


# --- Local (ENet) ---

func host(max_players: int = 4, port: int = _DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, max_players) != OK:
		CoreEvents.net_error.emit("ENet host failed on port %d" % port)
		return false
	multiplayer.multiplayer_peer = peer
	_is_host = true
	_active = true
	return true


func join(address: String = "127.0.0.1", port: int = _DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, port) != OK:
		CoreEvents.net_error.emit("ENet join failed to %s:%d" % [address, port])
		return false
	multiplayer.multiplayer_peer = peer
	_is_host = false
	_active = true
	return true


# --- Online (EOS P2P) ---

func host_online(socket_id: String = "bedrock") -> bool:
	var net = _ensure_eos_net()
	if net == null:
		CoreEvents.net_error.emit("EOS not available (run scripts/fetch-eos.sh)")
		return false
	var peer = net.create_server(socket_id)
	if peer == null:
		return false
	multiplayer.multiplayer_peer = peer
	_is_host = true
	_active = true
	return true


## host_user_id is an EOSProductUserId, typically taken from a lobby member.
func join_online(host_user_id, socket_id: String = "bedrock") -> bool:
	var net = _ensure_eos_net()
	if net == null:
		return false
	var peer = net.create_client(socket_id, host_user_id)
	if peer == null:
		return false
	multiplayer.multiplayer_peer = peer
	_is_host = false
	_active = true
	return true


# --- Lobbies (EOS) ---

func create_lobby(max_members: int = 8, enable_voice: bool = true) -> bool:
	var lobby = _ensure_eos_lobby()
	if lobby == null:
		CoreEvents.net_error.emit("EOS lobbies unavailable (run scripts/fetch-eos.sh and log in)")
		return false
	return lobby.create(max_members, enable_voice)


func leave_lobby() -> void:
	if _eos_lobby != null:
		_eos_lobby.leave()


func current_lobby_id() -> String:
	return _eos_lobby.current_lobby_id() if _eos_lobby != null else ""


# --- Shared ---

func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		if multiplayer.multiplayer_peer.has_method("close"):
			multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_is_host = false
	_active = false


func is_host() -> bool:
	return _is_host


func peer_id() -> int:
	return multiplayer.get_unique_id() if _active else 0


func _ensure_eos_net():
	if _eos_net == null and ClassDB.class_exists("EOSMultiplayerPeer"):
		_eos_net = load(_EOS_NET_PATH).new()
	return _eos_net


func _ensure_eos_lobby():
	if _eos_lobby == null and ClassDB.class_exists("EOSLobby"):
		_eos_lobby = load(_EOS_LOBBY_PATH).new()
	return _eos_lobby
