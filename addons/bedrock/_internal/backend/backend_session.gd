extends Node
## Bridges identity to the canonical backend. When the player logs in, it
## exchanges their platform credential for a backend session (POST /api/auth)
## and hands that session to the Save backend, which turns on cloud sync. It
## also carries the link-code merge (POST /api/link). Inert unless
## BEDROCK_BACKEND_URL is set, so single-player and offline are unaffected.

var _base_url := ""
var _session := ""


func _init() -> void:
	_base_url = OS.get_environment("BEDROCK_BACKEND_URL")


func _ready() -> void:
	CoreEvents.identity_changed.connect(_on_identity_changed)


func enabled() -> bool:
	return _base_url != ""


func session() -> String:
	return _session


func _on_identity_changed(account) -> void:
	if account == null or not enabled():
		return
	var provider = Platform.get_backend(Platform.IDENTITY)
	var cred: Dictionary = provider.platform_token() if provider != null else {}
	if cred.get("token", "") == "":
		return
	authenticate(cred["platform"], cred["token"], func(token): _apply_session(token))


## POST /api/auth, return the session via on_done(session) ("" on failure).
func authenticate(platform: String, token: String, on_done: Callable) -> void:
	if not enabled():
		on_done.call("")
		return
	var data = await _post("/api/auth", {"platform": platform, "token": token})
	on_done.call(str(data.get("session", "")))


## Issue a link code for this account, or "" on failure.
func begin_link_code() -> String:
	if _session == "":
		return ""
	var data = await _post("/api/link", {"action": "issue"})
	return str(data.get("code", ""))


## Merge this account into the one that issued `code`. On success the new
## session replaces the current one and cloud sync follows the merged account.
func redeem_link_code(code: String) -> bool:
	if _session == "" or code == "":
		return false
	var data = await _post("/api/link", {"action": "redeem", "code": code})
	var token := str(data.get("session", ""))
	if token == "":
		return false
	_apply_session(token)
	return true


## The JSON object from a 200 response, or {} on any failure. One HTTPRequest per
## call, so overlapping requests don't trip over each other.
func _post(path: String, body: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if _session != "":
		headers.append("Authorization: Bearer " + _session)
	var out := {}
	if http.request(_base_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body)) == OK:
		var result = await http.request_completed
		if int(result[1]) == 200:
			var data = JSON.parse_string(result[3].get_string_from_utf8())
			if typeof(data) == TYPE_DICTIONARY:
				out = data
	http.queue_free()
	return out


func _apply_session(token: String) -> void:
	_session = token
	if token == "":
		return
	var save = Platform.get_backend(Platform.SAVE)
	if save != null and save.has_method("set_session"):
		save.set_session(token)
