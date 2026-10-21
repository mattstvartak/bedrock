extends Node
## Live EOS P2P check between two processes: one hosts, one joins by the host's
## PUID, they swap a message each way. Run it through scripts/test-eos-p2p-live.sh,
## which starts the client with its own HOME so it gets a second device id.
## BEDROCK_P2P_ROLE is host or client; the host writes its PUID to BEDROCK_P2P_OUT,
## the client reads it from BEDROCK_P2P_HOST.

const SOCKET := "bedrockp2ptest"  ## EOS socket names are 1 to 32 letters and digits

var _fails: Array[String] = []
var _account = null
var _got: Variant = null
var _from := 0


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


func _finish() -> void:
	print("== ALL PASS ==" if _fails.is_empty() else "== FAILURES: %s ==" % ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _wait(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not cond.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	return cond.call()


func _ready() -> void:
	var role := OS.get_environment("BEDROCK_P2P_ROLE")
	print("== eos p2p live test (%s) ==" % role)
	if not Engine.has_singleton("EOSConnect"):
		print("  [SKIP] GD-EOS not installed")
		_finish()
		return
	CoreEvents.identity_changed.connect(func(a) -> void: _account = a)
	CoreEvents.net_message.connect(func(from, data) -> void:
		_from = from
		_got = data)
	Identity.login()
	_check(await _wait(func() -> bool: return _account != null, 30.0), "device id login")
	if _account == null:
		_finish()
		return
	var puid: String = _account.canonical_uuid
	_check(puid.length() == 32 and not puid.begins_with("<"), "the PUID is Epic's id string: %s" % puid)
	if role == "host":
		await _host(puid)
	else:
		await _client(puid)
	_finish()


func _host(puid: String) -> void:
	_check(Net.host_online(SOCKET), "host_online")
	var f := FileAccess.open(OS.get_environment("BEDROCK_P2P_OUT"), FileAccess.WRITE)
	f.store_string(puid)
	f.close()
	_check(await _wait(func() -> bool: return _got != null, 90.0), "a message arrives from the client")
	_check(_got is Dictionary and _got.get("ping") == "from client", "it is the client's ping: %s" % [_got])
	Net.send({"pong": "from host"}, _from)
	await get_tree().create_timer(5.0).timeout


func _client(puid: String) -> void:
	var host := OS.get_environment("BEDROCK_P2P_HOST")
	_check(host != puid, "the client has its own PUID")
	var joined := [false]
	multiplayer.connected_to_server.connect(func() -> void: joined[0] = true)
	_check(Net.join_online(EOSProductUserId.from_string(host), SOCKET), "join_online by the host's PUID")
	_check(await _wait(func() -> bool: return joined[0], 60.0), "connected to the host")
	Net.send({"ping": "from client"}, 1)
	_check(await _wait(func() -> bool: return _got != null, 30.0), "the host's reply arrives")
	_check(_got is Dictionary and _got.get("pong") == "from host", "it is the host's pong: %s" % [_got])
