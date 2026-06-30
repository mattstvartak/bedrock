extends Node
## Settings — persisted user settings (video, audio, gameplay, input), backed by
## a ConfigFile at user://settings.cfg. Audio-section values are pushed to the
## AudioServer buses on load and on change, so Audio and Settings stay in sync.

signal changed(section: String, key: String, value)

const PATH := "user://settings.cfg"

# Default bus volumes (linear 0..1), used until the player changes them.
const _AUDIO_DEFAULTS := {"Master": 1.0, "Music": 1.0, "SFX": 1.0}

var _cfg := ConfigFile.new()


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	_cfg.load(PATH)  # a missing file is fine; we fall back to defaults
	_apply_audio()


func save_settings() -> void:
	_cfg.save(PATH)


func get_value(section: String, key: String, default = null):
	return _cfg.get_value(section, key, default)


## Set a value, apply it (audio), notify, and leave it to the caller to
## save_settings() when they're done batching changes.
func set_value(section: String, key: String, value) -> void:
	_cfg.set_value(section, key, value)
	if section == "audio":
		_apply_audio()
	changed.emit(section, key, value)


func _apply_audio() -> void:
	for bus in _AUDIO_DEFAULTS:
		var linear: float = _cfg.get_value("audio", bus, _AUDIO_DEFAULTS[bus])
		var idx := AudioServer.get_bus_index(bus)
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
