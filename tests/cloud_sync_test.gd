extends Node
## Live cloud-sync test: authenticate, upload a save, wipe local, pull it back
## from the cloud, and confirm it restored. Opt-in (hits the network), gated on
## BEDROCK_BACKEND_URL + BEDROCK_BACKEND_LIVE=1; skips and passes otherwise.

const BridgeScript := preload("res://addons/bedrock/_internal/backend/backend_session.gd")

class CloudProgress extends ISaveable:
	var score := 0
	func save_id() -> String: return "cloud_progress"
	func capture() -> Dictionary: return {"version": 1, "score": score}
	func restore(data: Dictionary) -> void: score = int(data.get("score", 0))

var _fails: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


func _finish() -> void:
	if _fails.is_empty():
		print("== ALL PASS ==")
		get_tree().quit(0)
	else:
		print("== FAILURES: %s ==" % ", ".join(_fails))
		get_tree().quit(1)


func _ready() -> void:
	print("== cloud sync test ==")
	if OS.get_environment("BEDROCK_BACKEND_URL") == "" or OS.get_environment("BEDROCK_BACKEND_LIVE") != "1":
		print("  [SKIP] set BEDROCK_BACKEND_LIVE=1 (see scripts/test-backend-live.sh) to run")
		_finish()
		return

	var bridge := BridgeScript.new()
	add_child(bridge)
	var session := await _authenticate(bridge)
	_check(session != "", "got a backend session from /api/auth")
	var save = Platform.get_backend(Platform.SAVE)
	save.set_session(session)

	var progress := CloudProgress.new()
	progress.score = 4242
	Save.register(progress)
	Save.delete(7)

	var uploaded := await _await_sync(func(): Save.write(7))
	_check(uploaded, "save uploaded to the cloud (sync_completed)")

	# Wipe local, clear memory, pull from the cloud, read it back.
	Save.delete(7)
	progress.score = 0
	await Save.pull(7)
	Save.read(7)
	_check(progress.score == 4242, "pull restored the save from the cloud")

	Save.delete(7)
	_finish()


func _authenticate(bridge) -> String:
	# Lambdas capture locals by value, so share state through a Dictionary (a
	# reference) the callback can mutate.
	var st := {"done": false, "session": ""}
	bridge.authenticate("device", "cloud-sync-test-device", func(s): st.session = s; st.done = true)
	var frames := 0
	while not st.done and frames < 600:
		await get_tree().process_frame
		frames += 1
	return st.session


func _await_sync(action: Callable) -> bool:
	var st := {"done": false, "ok": false}
	var c1 := func(_slot): st.ok = true; st.done = true
	var c2 := func(_slot, _reason): st.done = true
	CoreEvents.sync_completed.connect(c1)
	CoreEvents.sync_failed.connect(c2)
	action.call()
	var frames := 0
	while not st.done and frames < 600:
		await get_tree().process_frame
		frames += 1
	CoreEvents.sync_completed.disconnect(c1)
	CoreEvents.sync_failed.disconnect(c2)
	return st.ok
