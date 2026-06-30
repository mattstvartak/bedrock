extends Node
## EOS identity test. With GD-EOS installed it does a real anonymous Device ID
## login (creds injected by doppler run) and checks a PUID comes back. Without
## GD-EOS it skips and passes, so CI without the addon stays green.

var _fails: Array[String] = []
var _done := false
var _account = null


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
	print("== eos identity test ==")
	if not Engine.has_singleton("EOSConnect"):
		print("  [SKIP] GD-EOS not installed; run scripts/fetch-eos.sh to exercise this")
		_finish()
		return

	_check(Platform.has_backend(Platform.IDENTITY), "identity provider bound when EOS present")
	_check(not Identity.is_logged_in(), "starts logged out")

	# The live login hits Epic's servers and keeps the EOS SDK alive, which is
	# slow and can stall headless exit, so it's opt-in. Run it with
	# BEDROCK_EOS_LIVE=1 (see scripts/test-eos-live.sh).
	if OS.get_environment("BEDROCK_EOS_LIVE") != "1":
		print("  [SKIP] live device-id login (set BEDROCK_EOS_LIVE=1 to run)")
		_finish()
		return

	CoreEvents.identity_changed.connect(_on_identity)
	Identity.login()

	# Pump frames (which also ticks the EOS platform) until login resolves.
	var frames := 0
	while not _done and frames < 1200:
		await get_tree().process_frame
		frames += 1

	_check(_done, "login resolved within timeout")
	_check(Identity.is_logged_in(), "logged in after device-id login")
	var acct = Identity.current_account()
	_check(acct != null and acct.canonical_uuid != "", "account carries a PUID")
	if acct != null:
		print("  PUID=", acct.canonical_uuid)
	_finish()


func _on_identity(account) -> void:
	_account = account
	_done = true
