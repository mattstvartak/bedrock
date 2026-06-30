extends RefCounted
## EOS RTC voice control for the current lobby's RTC room. References the
## EOSRTCAudio / EOSLobby / EOSConnect singletons, so it's load()ed only when
## GD-EOS is present. Voice connects automatically when a lobby is created with
## enable_rtc_room; this just exposes mic mute and per-participant volume.

# EOSRTCAudio.RTCAudioStatus: ENABLED = 1, DISABLED = 2.
const _RTC_ENABLED := 1
const _RTC_DISABLED := 2


func set_muted(lobby_id: String, muted: bool) -> bool:
	var uid = _local_user()
	if uid == null or lobby_id == "":
		return false
	var room := EOSLobby.get_rtc_room_name(lobby_id, uid)
	EOSRTCAudio.update_sending(uid, room, _RTC_DISABLED if muted else _RTC_ENABLED, Callable())
	return true


func set_participant_volume(lobby_id: String, participant_id, volume: float) -> bool:
	var uid = _local_user()
	if uid == null or lobby_id == "":
		return false
	var opts := EOSRTCAudio_UpdateParticipantVolumeOptions.new()
	opts.local_user_id = uid
	opts.room_name = EOSLobby.get_rtc_room_name(lobby_id, uid)
	opts.participant_id = participant_id
	opts.volume = volume
	EOSRTCAudio.update_participant_volume(opts, Callable())
	return true


func _local_user():
	if EOSConnect.get_logged_in_users_count() > 0:
		return EOSConnect.get_logged_in_user_by_index(0)
	return null
