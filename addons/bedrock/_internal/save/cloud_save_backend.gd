extends Node
## Local-first cloud save. Implements the ISaveBackend method set (it's a Node so
## it can host an HTTPRequest, so it can't `extends ISaveBackend`, but it honors
## the same contract).
##
## Disk is always the source of truth the game reads. When a backend URL and a
## canonical session are configured, writes also sync to the cloud (Neon metadata
## + R2 blob) asynchronously; conflicts surface on CoreEvents.sync_conflict. With
## nothing configured it behaves exactly like the local disk backend, so single-
## player and offline play are unaffected.
##
## Wired against backend/ (see backend/README). The identity layer calls
## set_session() once the player has a canonical session from POST /api/auth.

const _LocalSaveBackend := preload("res://addons/bedrock/_internal/save/local_save_backend.gd")

var _local
var _http: HTTPRequest
var _base_url := ""
var _session := ""


func _init() -> void:
	_local = _LocalSaveBackend.new()
	_base_url = OS.get_environment("BEDROCK_BACKEND_URL")


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)


# --- ISaveBackend contract (delegates to local, then syncs) ---

func write(slot: int, data: Dictionary) -> void:
	_local.write(slot, data)
	if cloud_enabled():
		_sync_up(slot, data)


func read(slot: int) -> Dictionary:
	return _local.read(slot)


func list_slots() -> Array:
	return _local.list_slots()


func delete(slot: int) -> void:
	_local.delete(slot)


# --- Cloud ---

## Set the canonical-account session (JWT from the backend) to enable sync.
func set_session(token: String) -> void:
	_session = token


func cloud_enabled() -> bool:
	return _base_url != "" and _session != ""


func _sync_up(slot: int, data: Dictionary) -> void:
	CoreEvents.sync_started.emit(slot)
	var headers := PackedStringArray([
		"Authorization: Bearer " + _session,
		"Content-Type: application/json",
	])
	var meta := {
		"schema_version": int(data.get("__schema_version", 1)),
		"checksum": var_to_str(data).sha256_text(),
		"updated_unix": int(Time.get_unix_time_from_system()),
	}
	# 1. PUT metadata -> { upload_url }
	var err := _http.request(
		"%s/api/save?slot=%d" % [_base_url, slot],
		headers, HTTPClient.METHOD_PUT, JSON.stringify(meta)
	)
	if err != OK:
		CoreEvents.sync_failed.emit(slot, "request failed (%d)" % err)
		return
	var result = await _http.request_completed
	var code: int = result[1]
	if code != 200:
		CoreEvents.sync_failed.emit(slot, "metadata PUT got HTTP %d" % code)
		return
	var body = JSON.parse_string(result[3].get_string_from_utf8())
	if typeof(body) != TYPE_DICTIONARY or not body.has("upload_url"):
		CoreEvents.sync_failed.emit(slot, "no upload_url in response")
		return
	# 2. PUT the blob bytes to the R2 signed URL.
	var blob := var_to_str(data).to_utf8_buffer()
	var up_err := _http.request_raw(body["upload_url"], PackedStringArray(), HTTPClient.METHOD_PUT, blob)
	if up_err != OK:
		CoreEvents.sync_failed.emit(slot, "blob upload failed (%d)" % up_err)
		return
	var up_result = await _http.request_completed
	if int(up_result[1]) >= 300:
		CoreEvents.sync_failed.emit(slot, "blob upload HTTP %d" % up_result[1])
		return
	CoreEvents.sync_completed.emit(slot)
