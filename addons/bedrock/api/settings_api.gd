extends Node
## Settings — persisted user settings (video, audio, gameplay, input), stored as
## plain JSON at user://settings.json (bool, int, float, string, and arrays or
## dictionaries of those).
## Audio and video values are applied on load and on change, so the saved state
## takes effect at boot. An old user://settings.cfg is never read.

signal changed(section: String, key: String, value)

const PATH := "user://settings.json"

# Default bus volumes (linear 0..1), used until the player changes them.
const _AUDIO_DEFAULTS := {"Master": 1.0, "Music": 1.0, "SFX": 1.0}

var path := PATH
var _data := {}


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	_data = {}
	var parsed = _read_dict(path)
	if parsed == null:
		parsed = _read_dict(path + ".tmp")
		if parsed == null and FileAccess.file_exists(path):
			DirAccess.copy_absolute(path, path + ".corrupt")
			push_warning("Settings: %s is unreadable, copied to %s.corrupt and using defaults" % [path, path])
	if parsed != null:
		_data = _clean(parsed)
	_apply_all()


func _read_dict(file: String):
	if not FileAccess.file_exists(file):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(file))
	return parsed if parsed is Dictionary else null


func save_settings() -> bool:
	var ok := _write_atomic(path, JSON.stringify(_data, "\t"))
	if not ok:
		push_warning("Settings: could not save %s, keeping the old file" % path)
	return ok


func get_value(section: String, key: String, default = null):
	return _data.get(section, {}).get(key, default)


## Set a value, apply it (audio, video), notify, and leave it to the caller to
## save_settings() when they're done batching changes.
func set_value(section: String, key: String, value) -> void:
	if not _plain(value):
		push_warning("Settings: %s/%s must be plain data (bool, int, float, string, array, dictionary)" % [section, key])
		return
	if not _data.has(section):
		_data[section] = {}
	_data[section][key] = value
	_apply(section)
	changed.emit(section, key, value)


# Write to a temp file next to the target, then rename over it, so a failed
# write leaves the old file alone.
func _write_atomic(target: String, text: String) -> bool:
	var tmp := target + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	var wrote := f.get_error() == OK
	f.close()
	if wrote and DirAccess.rename_absolute(tmp, target) == OK:
		return true
	DirAccess.remove_absolute(tmp)
	return false


func _plain(v) -> bool:
	if v is Array:
		return v.all(_plain)
	if v is Dictionary:
		return v.keys().all(func(k): return k is String) and v.values().all(_plain)
	return v is bool or v is int or v is float or v is String


# Keep only section -> key -> plain value entries from whatever the file held.
func _clean(raw: Dictionary) -> Dictionary:
	var out := {}
	for section in raw:
		if not (section is String and raw[section] is Dictionary):
			continue
		out[section] = {}
		for key in raw[section]:
			if key is String and _plain(raw[section][key]):
				out[section][key] = raw[section][key]
	return out


func _apply_all() -> void:
	_apply("audio")
	_apply("video")


func _apply(section: String) -> void:
	match section:
		"audio": _apply_audio()
		"video": _apply_video()


func _apply_audio() -> void:
	for bus in _AUDIO_DEFAULTS:
		var linear = get_value("audio", bus, _AUDIO_DEFAULTS[bus])
		if not (linear is float or linear is int):
			linear = _AUDIO_DEFAULTS[bus]
		var idx := AudioServer.get_bus_index(bus)
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func _apply_video() -> void:
	var on = get_value("video", "fullscreen", false) == true
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	)
