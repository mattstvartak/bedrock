extends Node
## Achievements — public facade for achievements, stats, and leaderboards. Backed
## by EOS on desktop (behind IAchievements), mapped to platform trophies on
## console later. No-ops gracefully when the module is off or no provider is
## bound, so games can call it unconditionally.

var _backend


func unlock(id: String) -> void:
	var p = _resolve()
	if p:
		p.unlock(id)


func is_unlocked(id: String) -> bool:
	var p = _resolve()
	return p.is_unlocked(id) if p else false


func set_stat(id: String, value: float) -> void:
	var p = _resolve()
	if p:
		p.set_stat(id, value)


func get_stat(id: String) -> float:
	var p = _resolve()
	return p.get_stat(id) if p else 0.0


func submit_leaderboard(id: String, score: int) -> void:
	var p = _resolve()
	if p:
		p.submit_leaderboard(id, score)


func _resolve():
	if _backend == null and Platform.has_backend(Platform.ACHIEVEMENTS):
		_backend = Platform.get_backend(Platform.ACHIEVEMENTS)
	return _backend
