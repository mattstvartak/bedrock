extends Node
## Net — public multiplayer facade.
##
## Transport (ENet local / EOS online), lobbies, and voice sit behind this.
## Authority model (P2P host-authoritative or dedicated server-authoritative) is
## chosen per game via GameConfig; netcode prediction (rollback or snapshot)
## stays in the game, not here.

var _backend  ## internal net backend


func host(max_players: int = 4) -> void:
	var b = _resolve()
	if b == null:
		push_warning("[Net] no backend bound; host skipped.")
		return
	b.host(max_players)


func join(lobby_id: String) -> void:
	var b = _resolve()
	if b:
		b.join(lobby_id)


func leave() -> void:
	var b = _resolve()
	if b:
		b.leave()


func _resolve():
	if _backend == null and Platform.has_backend(Platform.NET):
		_backend = Platform.get_backend(Platform.NET)
	return _backend
