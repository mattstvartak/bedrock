extends IAchievements
## EOS achievements + stats. References the EOSAchievements / EOSStats /
## EOSConnect singletons, so Platform load()s it only when GD-EOS is present and
## achievements are enabled. Needs an Identity login (the local user is the PUID).
##
## Writes (unlock / ingest stat) are the common path. Reads (is_unlocked /
## get_stat) need an async query + local cache, wired when a game needs them.

func unlock(id: String) -> void:
	var uid = _local_user()
	if uid == null:
		return
	EOSAchievements.unlock_achievements(uid, PackedStringArray([id]), Callable())


## EOS stats accumulate by an integer amount; this ingests `value` as the amount.
func set_stat(id: String, value: float) -> void:
	var uid = _local_user()
	if uid == null:
		return
	var data := EOSStats_IngestData.new()
	data.stat_name = id
	data.ingest_amount = int(value)
	var opts := EOSStats_IngestStatOptions.new()
	opts.local_user_id = uid
	opts.target_user_id = uid
	opts.stats = [data]
	EOSStats.ingest_stat(opts, Callable())


## EOS leaderboards are backed by stats, so a submission ingests the stat that
## feeds the leaderboard definition.
func submit_leaderboard(id: String, score: int) -> void:
	set_stat(id, float(score))


func _local_user():
	if EOSConnect.get_logged_in_users_count() > 0:
		return EOSConnect.get_logged_in_user_by_index(0)
	return null
