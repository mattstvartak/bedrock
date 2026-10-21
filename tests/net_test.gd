extends Node
## NetworkManager test. Exercises the ENet local transport through the Net facade
## (the EOS online path needs two peers + a lobby, covered by the lobby module
## and the live EOS checks). Exits nonzero on failure.

var _fails: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


# A second SceneMultiplayer in this process plays the client; it is polled by hand.
func _messaging() -> void:
	var client := SceneMultiplayer.new()
	client.root_path = NodePath("/root")
	var cpeer := ENetMultiplayerPeer.new()
	cpeer.create_client("127.0.0.1", 7912)
	client.multiplayer_peer = cpeer
	var joined := false
	CoreEvents.peer_joined.connect(func(_id): joined = true, CONNECT_ONE_SHOT)
	var got_client := []
	client.peer_packet.connect(func(from, pkt): got_client.append([from, bytes_to_var(pkt)]))
	var got_host := []
	CoreEvents.net_message.connect(func(from, data): got_host.append([from, data]))

	for i in 100:
		client.poll()
		await get_tree().process_frame
		if Net.is_host() and client.get_peers().size() > 0 and Net.is_host() and 1 in client.get_peers() and joined:
			break
	var cid := client.get_unique_id()
	_check(cid > 1, "client connected to the host")

	_check(client.send_bytes(var_to_bytes({"a": 1}), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE) == OK, "client sent")
	client.send_bytes(PackedByteArray([255, 255, 255, 255, 9]), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	_check(Net.send("hi", cid), "host send() returned true")
	for i in 60:
		client.poll()
		await get_tree().process_frame
	_check(got_host == [[cid, {"a": 1}]], "host got the message and ignored the garbage packet")
	_check(got_client == [[1, "hi"]], "client got the host's message")
	cpeer.close()


func _ready() -> void:
	print("== net test ==")

	_check(Platform.has_backend(Platform.NET), "net backend bound when multiplayer enabled")
	_check(not Net.is_host(), "not hosting before host()")
	_check(Net.peer_id() == 0, "no peer id before host()")

	var ok := Net.host(8, 7912)
	_check(ok, "host() created an ENet server")
	_check(Net.is_host(), "is_host() true after host()")
	_check(Net.peer_id() == 1, "server has unique peer id 1")

	_check(not Net.online_available(), "online_available() false without EOS set up")
	await _messaging()

	Net.leave()
	_check(not Net.is_host(), "is_host() false after leave()")
	_check(Net.peer_id() == 0, "peer id 0 after leave()")
	_check(not Net.send("x"), "send() false with no session")

	var failed := []
	CoreEvents.join_failed.connect(func(r): failed.append(r))
	Net.join("127.0.0.1", 7913)  # nothing listening
	for i in 1200:
		await get_tree().create_timer(0.05).timeout
		if not failed.is_empty():
			break
	_check(failed.size() == 1 and failed[0] != "", "join to a closed port emits join_failed")

	if _fails.is_empty():
		print("== ALL PASS ==")
		get_tree().quit(0)
	else:
		print("== FAILURES: %s ==" % ", ".join(_fails))
		get_tree().quit(1)
