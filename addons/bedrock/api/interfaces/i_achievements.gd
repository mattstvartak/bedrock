class_name IAchievements
extends RefCounted
## Implemented by the BASE. EOS on desktop; maps to native trophies/achievements
## on console. Unlocks are abstract ids the platform layer translates.

func unlock(_id: String) -> void:
	pass


func is_unlocked(_id: String) -> bool:
	return false


func set_stat(_id: String, _value: float) -> void:
	pass


func get_stat(_id: String) -> float:
	return 0.0


func submit_leaderboard(_id: String, _score: int) -> void:
	pass
