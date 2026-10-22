extends Node
## Live cloud-sync test: sign in to the backend, upload a save, wipe local, pull
## it back from the cloud, confirm it restored, then issue and redeem a link code.
## Opt-in (hits the network), gated on BEDROCK_BACKEND_URL + BEDROCK_BACKEND_LIVE=1;
## skips and passes otherwise.

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

	var account = Platform.get_backend(Platform.ACCOUNT)
	_check(account != null, "account backend bound when BEDROCK_BACKEND_URL is set")
	var save = Platform.get_backend(Platform.SAVE)
	await _sign_in(account, save)
	_check(save.cloud_enabled(), "got a backend session from /api/auth")
	if not save.cloud_enabled():
		_finish()
		return

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

	# Pulling the same content again is a no-op, not a conflict.
	var again := await _await_sync(func(): Save.pull(7))
	_check(again, "second pull of identical content completes")

	# Link codes: issue one and redeem it on the same account (a no-op merge).
	var code: String = await Identity.begin_link_code()
	_check(code.length() == 8, "issued a link code")
	_check(await Identity.redeem_link_code(code), "redeemed the link code")
	_check(not await Identity.redeem_link_code(code), "a used link code is refused")

	Save.delete(7)
	_finish()


## With GD-EOS: a real device-id login, and the account bridge exchanges the EOS id
## token for a session on its own. Without it: a bare device token, which only a
## Worker with ALLOW_UNVERIFIED_DEVICE_TOKENS=1 accepts.
func _sign_in(account, save) -> void:
	if Engine.has_singleton("EOSConnect"):
		Identity.login()
		var frames := 0
		while not save.cloud_enabled() and frames < 1200:
			await get_tree().process_frame
			frames += 1
		return
	# Lambdas capture locals by value, so share state through a Dictionary (a
	# reference) the callback can mutate.
	var st := {"done": false, "session": ""}
	account.authenticate("device", "cloud-sync-test-device", func(s): st.session = s; st.done = true)
	var frames := 0
	while not st.done and frames < 600:
		await get_tree().process_frame
		frames += 1
	if st.session != "":
		save.set_session(st.session)


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
