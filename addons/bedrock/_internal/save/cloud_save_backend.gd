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


## Pull the cloud save for a slot into local disk (so the next read() sees it).
## Resolves divergence by the configured policy; emits sync_conflict when the game
## must decide. After pull, the game reads the slot as usual.
func pull(slot: int) -> void:
	if not cloud_enabled():
		return
	CoreEvents.sync_started.emit(slot)
	var headers := PackedStringArray(["Authorization: Bearer " + _session])
	if _http.request("%s/api/save?slot=%d" % [_base_url, slot], headers, HTTPClient.METHOD_GET) != OK:
		CoreEvents.sync_failed.emit(slot, "pull request failed")
		return
	var result = await _http.request_completed
	if int(result[1]) != 200:
		CoreEvents.sync_failed.emit(slot, "pull got HTTP %d" % result[1])
		return
	var data = JSON.parse_string(result[3].get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.get("exists", false):
		CoreEvents.sync_completed.emit(slot)  # nothing in the cloud yet
		return

	var cloud_unix := int(data.get("updated_unix", 0))
	var cloud_blob := _decode(data.get("blob_base64", ""))
	var local = _local.meta(slot)

	if not local.get("exists", false) or cloud_unix > int(local.get("updated_unix", 0)):
		_local.write(slot, cloud_blob)  # cloud wins (or no local yet)
		CoreEvents.sync_completed.emit(slot)
	elif cloud_unix == int(local.get("updated_unix", 0)):
		CoreEvents.sync_completed.emit(slot)  # already in sync
	else:
		# Local is newer than the cloud copy. Last-write-wins keeps local; any
		# other policy hands both to the game to resolve.
		if _conflict_policy() == "last_write_wins":
			CoreEvents.sync_completed.emit(slot)
		else:
			CoreEvents.sync_conflict.emit(slot, _local.read(slot), cloud_blob)


func _decode(b64: String) -> Dictionary:
	if b64 == "":
		return {}
	var parsed = str_to_var(Marshalls.base64_to_raw(b64).get_string_from_utf8())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _conflict_policy() -> String:
	if Platform.config != null:
		return Platform.config.conflict_policy
	return "last_write_wins"


func _sync_up(slot: int, data: Dictionary) -> void:
	# One request: metadata + the (small, base64) blob go to the backend, which
	# stores the blob in Vercel Blob and the metadata in Neon.
	CoreEvents.sync_started.emit(slot)
	var serialized := var_to_str(data)
	var payload := {
		"schema_version": int(data.get("__schema_version", 1)),
		"checksum": serialized.sha256_text(),
		"updated_unix": int(Time.get_unix_time_from_system()),
		"blob_base64": Marshalls.raw_to_base64(serialized.to_utf8_buffer()),
	}
	var headers := PackedStringArray([
		"Authorization: Bearer " + _session,
		"Content-Type: application/json",
	])
	var err := _http.request(
		"%s/api/save?slot=%d" % [_base_url, slot],
		headers, HTTPClient.METHOD_PUT, JSON.stringify(payload)
	)
	if err != OK:
		CoreEvents.sync_failed.emit(slot, "request failed (%d)" % err)
		return
	var result = await _http.request_completed
	if int(result[1]) >= 300:
		CoreEvents.sync_failed.emit(slot, "save sync got HTTP %d" % result[1])
		return
	CoreEvents.sync_completed.emit(slot)
