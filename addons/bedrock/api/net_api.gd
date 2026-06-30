extends Node
## Net — public multiplayer facade.
##
## ENet for local/LAN play, EOS P2P for online, behind the net backend. The
## authority model (P2P host-authoritative or dedicated) is the game's choice;
## netcode prediction (rollback or snapshot) stays in the game, not here. Peer
## connect/disconnect arrives on CoreEvents.peer_joined / peer_left.

var _backend


func host(max_players: int = 4, port: int = 7777) -> bool:
	var b = _resolve()
	return b.host(max_players, port) if b else _no_backend()


func join(address: String = "127.0.0.1", port: int = 7777) -> bool:
	var b = _resolve()
	return b.join(address, port) if b else _no_backend()


func host_online(socket_id: String = "bedrock") -> bool:
	var b = _resolve()
	return b.host_online(socket_id) if b else _no_backend()


## host_user_id is an EOS ProductUserId, usually a lobby member's id.
func join_online(host_user_id, socket_id: String = "bedrock") -> bool:
	var b = _resolve()
	return b.join_online(host_user_id, socket_id) if b else _no_backend()


func leave() -> void:
	var b = _resolve()
	if b:
		b.leave()


# --- Lobbies (EOS, needs an Identity login first) ---

func create_lobby(max_members: int = 8, enable_voice: bool = true) -> bool:
	var b = _resolve()
	return b.create_lobby(max_members, enable_voice) if b else _no_backend()


func leave_lobby() -> void:
	var b = _resolve()
	if b:
		b.leave_lobby()


func current_lobby_id() -> String:
	var b = _resolve()
	return b.current_lobby_id() if b else ""


func is_host() -> bool:
	var b = _resolve()
	return b.is_host() if b else false


func peer_id() -> int:
	var b = _resolve()
	return b.peer_id() if b else 0


func _resolve():
	if _backend == null and Platform.has_backend(Platform.NET):
		_backend = Platform.get_backend(Platform.NET)
	return _backend


func _no_backend() -> bool:
	push_warning("[Net] no backend bound (is enable_multiplayer on?)")
	return false
