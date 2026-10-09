extends Node
## Settings test. Runs against a scratch file under user://, never the real one.
## Run: godot --headless --path . res://tests/settings_test.tscn
## Exits 0 on pass, 1 on any failure (so CI can gate on it).

const TMP := "user://settings_test.json"

var _fails: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails.append(label)
	print("  [%s] %s" % ["PASS" if cond else "FAIL", label])


func _write(text: String) -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _ready() -> void:
	print("== settings test ==")
	var real_path: String = Settings.path
	Settings.path = TMP
	DirAccess.remove_absolute(TMP)

	# defaults when nothing is saved
	Settings.load_settings()
	_check(Settings.get_value("audio", "Music", 1.0) == 1.0, "defaults with no file")

	# round trip
	Settings.set_value("audio", "Music", 0.25)
	Settings.set_value("video", "fullscreen", true)
	Settings.set_value("gameplay", "name", "mara")
	_check(Settings.save_settings(), "save returns true")
	Settings.load_settings()
	_check(is_equal_approx(float(Settings.get_value("audio", "Music")), 0.25), "float round trips")
	_check(Settings.get_value("gameplay", "name") == "mara", "string round trips")

	# fullscreen persists across a reload and is applied at boot
	_check(Settings.get_value("video", "fullscreen") == true, "fullscreen persists across reload")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	Settings.load_settings()
	var mode := DisplayServer.window_get_mode()
	_check(
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.get_name() == "headless",
		"saved fullscreen applied at load"
	)

	# object-looking payloads and non-plain values never come back as objects
	_write('{"audio": {"Music": {"__type": "Object", "script": "res://evil.gd"}}, "x": 3, "video": {"fullscreen": true}}')
	Settings.load_settings()
	var planted = Settings.get_value("audio", "Music")
	_check(planted is Dictionary and not planted is Object, "object payload is inert data")
	_check(Settings.get_value("x", "y", "dflt") == "dflt", "non-section top level dropped")
	_check(Settings.get_value("video", "fullscreen") == true, "plain values kept beside it")
	_write("Object(Resource,\"script\":null)")
	Settings.load_settings()
	_check(Settings.get_value("video", "fullscreen", false) == false, "garbage file gives defaults")

	# crash between remove and rename leaves only the tmp file
	DirAccess.remove_absolute(TMP)
	DirAccess.remove_absolute(TMP + ".corrupt")
	var t := FileAccess.open(TMP + ".tmp", FileAccess.WRITE)
	t.store_string('{"audio": {"Music": 0.4}}')
	t.close()
	Settings.load_settings()
	_check(is_equal_approx(float(Settings.get_value("audio", "Music", 1.0)), 0.4), "missing json loads the tmp")
	_check(Settings.save_settings(), "save after tmp recovery")
	_check(FileAccess.file_exists(TMP), "recovered values written back to json")
	DirAccess.remove_absolute(TMP + ".tmp")

	# corrupt json with no tmp is kept as .corrupt before a save overwrites it
	_write("{not json")
	Settings.load_settings()
	_check(FileAccess.get_file_as_string(TMP + ".corrupt") == "{not json", "corrupt json copied aside")
	Settings.save_settings()
	_check(FileAccess.get_file_as_string(TMP + ".corrupt") == "{not json", ".corrupt survives the next save")

	# corrupt json with a good tmp uses the tmp
	_write("{not json")
	t = FileAccess.open(TMP + ".tmp", FileAccess.WRITE)
	t.store_string('{"audio": {"Music": 0.7}}')
	t.close()
	Settings.load_settings()
	_check(is_equal_approx(float(Settings.get_value("audio", "Music", 1.0)), 0.7), "corrupt json falls back to tmp")
	DirAccess.remove_absolute(TMP + ".tmp")
	DirAccess.remove_absolute(TMP + ".corrupt")

	# old settings.cfg is ignored and left alone
	var cfg_path := real_path.get_base_dir() + "/settings_test_old.cfg"
	var cfg := FileAccess.open(cfg_path, FileAccess.WRITE)
	cfg.store_string("[audio]\nMusic=0.1\n")
	cfg.close()
	DirAccess.remove_absolute(TMP)
	Settings.load_settings()
	_check(Settings.get_value("audio", "Music", 1.0) == 1.0, "cfg not parsed")
	_check(FileAccess.file_exists(cfg_path), "cfg left on disk")
	DirAccess.remove_absolute(cfg_path)

	# failed write keeps the old file
	Settings.set_value("audio", "Music", 0.5)
	Settings.save_settings()
	var before := FileAccess.get_file_as_string(TMP)
	_check(not Settings._write_atomic("user://no_such_dir/settings.json", "{}"), "write to bad dir fails")
	Settings.path = "user://no_such_dir/settings.json"
	_check(not Settings.save_settings(), "save reports failure")
	Settings.path = TMP
	_check(FileAccess.get_file_as_string(TMP) == before, "old file untouched after failed write")
	_check(not FileAccess.file_exists(TMP + ".tmp"), "no temp file left behind")

	DirAccess.remove_absolute(TMP)
	DirAccess.remove_absolute(TMP + ".corrupt")
	Settings.path = real_path
	Settings.load_settings()
	print("ALL PASS" if _fails.is_empty() else "FAILURES: %s" % ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)
