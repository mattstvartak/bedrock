extends Node
## Lobby structural test. Live lobby ops need an EOS login plus a second client,
## so this checks the facade is wired and degrades gracefully (no login / no
## GD-EOS returns false instead of crashing). Real lobby flow is verified live
## via the EOS checks once two clients exist.

var _fails: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


func _ready() -> void:
	print("== lobby test ==")

	_check(Net.current_lobby_id() == "", "no lobby before create")

	# Without a login (no PUID) this must return false, not crash. With GD-EOS
	# absent it also returns false. Either way: graceful.
	var created := Net.create_lobby(4, false)
	_check(created == false, "create_lobby is graceful without a login")
	_check(Net.current_lobby_id() == "", "still no lobby after a failed create")

	Net.leave_lobby()  # must be a no-op, not a crash
	_check(true, "leave_lobby is a safe no-op when not in a lobby")

	if _fails.is_empty():
		print("== ALL PASS ==")
		get_tree().quit(0)
	else:
		print("== FAILURES: %s ==" % ", ".join(_fails))
		get_tree().quit(1)
