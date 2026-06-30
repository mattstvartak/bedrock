extends Node
## Live cloud-sync test: authenticate to the backend, set the session on the Save
## backend, write a save, and confirm it syncs to the cloud. Opt-in (hits the
## network), gated on BEDROCK_BACKEND_URL + BEDROCK_BACKEND_LIVE=1; skips and
## passes otherwise so the default suite stays offline.

const BridgeScript := preload("res://addons/bedrock/_internal/backend/backend_session.gd")

class CloudProgress extends ISaveable:
	var score := 4242
	func save_id() -> String: return "cloud_progress"
	func capture() -> Dictionary: return {"version": 1, "score": score}
	func restore(data: Dictionary) -> void: score = int(data.get("score", 0))

var _fails: Array[String] = []
var _done := false
var _ok := false


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

	CoreEvents.sync_completed.connect(func(_slot): _ok = true; _done = true)
	CoreEvents.sync_failed.connect(func(_slot, reason): printerr("  sync_failed: ", reason); _done = true)

	var bridge := BridgeScript.new()
	add_child(bridge)
	bridge.authenticate("device", "cloud-sync-test-device", func(token):
		_check(token != "", "got a backend session from /api/auth")
		var save = Platform.get_backend(Platform.SAVE)
		save.set_session(token)
		Save.register(CloudProgress.new())
		Save.write(7))

	var frames := 0
	while not _done and frames < 900:
		await get_tree().process_frame
		frames += 1
	_check(_ok, "save synced to the cloud (sync_completed)")
	_finish()
