extends Node
## Achievements structural test. Real unlocks/stats need an EOS login and a
## configured product, so this checks the facade is wired and no-ops gracefully
## when the module is off / no provider is bound (the default).

var _fails: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


func _ready() -> void:
	print("== achievements test ==")

	# enable_achievements defaults off, so no provider is bound: every call must
	# be a safe no-op, never a crash.
	Achievements.unlock("first_win")
	_check(true, "unlock is a safe no-op with no provider")
	Achievements.set_stat("kills", 5.0)
	_check(true, "set_stat is a safe no-op with no provider")
	Achievements.submit_leaderboard("high_score", 9000)
	_check(true, "submit_leaderboard is a safe no-op with no provider")
	_check(Achievements.is_unlocked("first_win") == false, "is_unlocked returns false with no provider")
	_check(Achievements.get_stat("kills") == 0.0, "get_stat returns 0 with no provider")

	if _fails.is_empty():
		print("== ALL PASS ==")
		get_tree().quit(0)
	else:
		print("== FAILURES: %s ==" % ", ".join(_fails))
		get_tree().quit(1)
