class_name IVoice
extends RefCounted
## Implemented by the BASE. EOS Voice (RTC) on desktop, tied to lobby/session
## membership; console native voice swaps in behind the same seam.

func join_room(_room_id: String) -> void:
	pass


func leave_room() -> void:
	pass


func set_muted(_muted: bool) -> void:
	pass


func set_player_volume(_peer_id: int, _volume: float) -> void:
	pass
