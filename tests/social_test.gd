extends Node
## Social structural test. Lobby invites need a live lobby + peer; the friends
## list needs a platform/backend provider (EOS Friends is not used, by design).
## This checks the facade is wired and degrades gracefully.

var _fails: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


func _ready() -> void:
	print("== social test ==")

	_check(Social.friends() == [], "friends() empty with no platform/backend provider")
	_check(Social.presence("someone") == "", "presence() empty with no provider")
	_check(Social.invite_to_lobby("someone") == false, "invite_to_lobby graceful with no lobby")

	if _fails.is_empty():
		print("== ALL PASS ==")
		get_tree().quit(0)
	else:
		print("== FAILURES: %s ==" % ", ".join(_fails))
		get_tree().quit(1)
