extends Node
## Voice structural test. Real voice needs a lobby with peers and audio, so this
## checks the facade is wired and degrades gracefully (no lobby / no GD-EOS
## returns false instead of crashing).

var _fails: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


func _ready() -> void:
	print("== voice test ==")

	# No lobby -> no RTC room -> graceful false, not a crash.
	_check(Net.set_muted(true) == false, "set_muted is graceful with no lobby")
	_check(Net.set_player_volume("someone", 0.5) == false, "set_player_volume is graceful with no lobby")

	if _fails.is_empty():
		print("== ALL PASS ==")
		get_tree().quit(0)
	else:
		print("== FAILURES: %s ==" % ", ".join(_fails))
		get_tree().quit(1)
