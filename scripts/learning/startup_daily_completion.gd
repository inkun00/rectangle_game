extends RefCounted

const SAVE_PATH: String = "user://quadrilateral_startup_completion_v1.txt"
const WEB_KEY: String = "quadrilateral_world.startup_completion.v1"
const KOREA_UTC_OFFSET: int = 9 * 3600

static func korean_date(unix_time: int = -1) -> String:
	var seconds: int = int(Time.get_unix_time_from_system()) if unix_time == -1 else unix_time
	return Time.get_date_string_from_unix_time(seconds + KOREA_UTC_OFFSET)

static func completed_today(path: String = SAVE_PATH, unix_time: int = -1) -> bool:
	var today: String = korean_date(unix_time)
	if OS.has_feature("web") and path == SAVE_PATH:
		var saved: Variant = JavaScriptBridge.eval(
			"(() => { try { return localStorage.getItem(%s); } catch { return null; } })()" % JSON.stringify(WEB_KEY), true)
		if saved is String and saved == today: return true
	if not FileAccess.file_exists(path): return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != today.length(): return false
	return file.get_as_text() == today

static func mark_completed(path: String = SAVE_PATH, unix_time: int = -1) -> bool:
	var today: String = korean_date(unix_time)
	var saved_in_browser: bool = false
	if OS.has_feature("web") and path == SAVE_PATH:
		# An immediate reload can happen before Godot finishes flushing IndexedDB.
		var result: Variant = JavaScriptBridge.eval(
			"(() => { try { localStorage.setItem(%s, %s); return true; } catch { return false; } })()" % [JSON.stringify(WEB_KEY), JSON.stringify(today)], true)
		saved_in_browser = result is bool and result
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return saved_in_browser
	var written: bool = file.store_string(today)
	file.flush()
	var saved_in_file: bool = written and file.get_error() == OK
	file.close()
	if saved_in_file and OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()
		saved_in_file = OS.is_userfs_persistent()
	return saved_in_file or saved_in_browser
