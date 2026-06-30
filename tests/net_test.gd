extends Node
## NetworkManager test. Exercises the ENet local transport through the Net facade
## (the EOS online path needs two peers + a lobby, covered by the lobby module
## and the live EOS checks). Exits nonzero on failure.

var _fails: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


func _ready() -> void:
	print("== net test ==")

	_check(Platform.has_backend(Platform.NET), "net backend bound when multiplayer enabled")
	_check(not Net.is_host(), "not hosting before host()")
	_check(Net.peer_id() == 0, "no peer id before host()")

	var ok := Net.host(8, 7912)
	_check(ok, "host() created an ENet server")
	_check(Net.is_host(), "is_host() true after host()")
	_check(Net.peer_id() == 1, "server has unique peer id 1")

	Net.leave()
	_check(not Net.is_host(), "is_host() false after leave()")
	_check(Net.peer_id() == 0, "peer id 0 after leave()")

	if _fails.is_empty():
		print("== ALL PASS ==")
		get_tree().quit(0)
	else:
		print("== FAILURES: %s ==" % ", ".join(_fails))
		get_tree().quit(1)
