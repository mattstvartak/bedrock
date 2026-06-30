extends Node
## Bridges identity to the canonical backend. When the player logs in, it
## exchanges their platform token for a backend session (POST /api/auth) and
## hands that session to the Save backend, which turns on cloud sync. Inert
## unless BEDROCK_BACKEND_URL is set, so single-player and offline are unaffected.

var _base_url := ""
var _http: HTTPRequest
var _session := ""


func _init() -> void:
	_base_url = OS.get_environment("BEDROCK_BACKEND_URL")


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	CoreEvents.identity_changed.connect(_on_identity_changed)


func enabled() -> bool:
	return _base_url != ""


func session() -> String:
	return _session


func _on_identity_changed(account) -> void:
	if account == null or not enabled():
		return
	# Exchange the player's id for a backend session. The platform tag refines as
	# real credentials land (steam/console); device covers the anonymous/EOS case.
	var platform := "epic" if not account.is_anonymous else "device"
	authenticate(platform, str(account.canonical_uuid), func(token): _apply_session(token))


## POST /api/auth, return the session via on_done(session) ("" on failure).
func authenticate(platform: String, token: String, on_done: Callable) -> void:
	if not enabled():
		on_done.call("")
		return
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"platform": platform, "token": token})
	if _http.request(_base_url + "/api/auth", headers, HTTPClient.METHOD_POST, body) != OK:
		on_done.call("")
		return
	var result = await _http.request_completed
	if int(result[1]) != 200:
		on_done.call("")
		return
	var data = JSON.parse_string(result[3].get_string_from_utf8())
	on_done.call(data.get("session", "") if typeof(data) == TYPE_DICTIONARY else "")


func _apply_session(token: String) -> void:
	_session = token
	if token == "":
		return
	var save = Platform.get_backend(Platform.SAVE)
	if save != null and save.has_method("set_session"):
		save.set_session(token)
