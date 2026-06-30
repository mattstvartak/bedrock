extends Node
## Audio — bus setup, music crossfade, and pooled SFX.
##
## Volumes are owned by Settings; this just provides the Music/SFX buses and the
## playback. A game calls Audio.play_music / play_sfx and never touches the
## AudioServer directly.

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const _SFX_VOICES := 16
const _SILENT_DB := -60.0

var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_next := 0


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	for _i in 2:
		_music.append(_make_player(MUSIC_BUS))
	for _i in _SFX_VOICES:
		_sfx.append(_make_player(SFX_BUS))


## Crossfade to a new track over `fade` seconds.
func play_music(stream: AudioStream, fade := 1.0) -> void:
	if stream == null:
		return
	var incoming := _music[1 - _active]
	var outgoing := _music[_active]
	incoming.stream = stream
	incoming.volume_db = _SILENT_DB
	incoming.play()
	_active = 1 - _active
	var tw := create_tween().set_parallel(true)
	tw.tween_property(incoming, "volume_db", 0.0, fade)
	if outgoing.playing:
		tw.tween_property(outgoing, "volume_db", _SILENT_DB, fade)
		tw.chain().tween_callback(outgoing.stop)


func stop_music(fade := 1.0) -> void:
	var p := _music[_active]
	if not p.playing:
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", _SILENT_DB, fade)
	tw.tween_callback(p.stop)


## Fire a one-shot sound through the SFX voice pool (round-robin).
func play_sfx(stream: AudioStream, pitch := 1.0) -> void:
	if stream == null:
		return
	var p := _sfx[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _SFX_VOICES
	p.stream = stream
	p.pitch_scale = pitch
	p.play()


func set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func get_bus_volume(bus: String) -> float:
	var idx := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(idx)) if idx != -1 else 0.0


func _ensure_bus(bus: String) -> void:
	if AudioServer.get_bus_index(bus) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus)
	AudioServer.set_bus_send(idx, "Master")


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p
