extends RefCounted

const SAVE_PATH: String = "user://quadrilateral_startup_completion_v1.txt"
const KOREA_UTC_OFFSET: int = 9 * 3600
const MAX_PROGRESS_BYTES: int = 1024

static func korean_date(unix_time: int = -1) -> String:
	var seconds: int = int(Time.get_unix_time_from_system()) if unix_time == -1 else unix_time
	return Time.get_date_string_from_unix_time(seconds + KOREA_UTC_OFFSET)

static func completed_today(path: String = SAVE_PATH, unix_time: int = -1) -> bool:
	var today: String = korean_date(unix_time)
	var browser: JavaScriptObject = _browser_storage(path)
	if browser != null and browser.completedToday(today) == true: return true
	if not FileAccess.file_exists(path): return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != today.length(): return false
	if file.get_as_text() != today: return false
	# Migrate a valid file-only completion from earlier web builds.
	if browser != null: browser.markCompleted(today)
	return true

static func mark_completed(path: String = SAVE_PATH, unix_time: int = -1) -> bool:
	var today: String = korean_date(unix_time)
	var browser: JavaScriptObject = _browser_storage(path)
	# Persist synchronously before returning to the game, including on immediate reload.
	var saved_in_browser: bool = browser != null and browser.markCompleted(today) == true
	var saved_in_file: bool = _write_text(path, today)
	if (saved_in_file or saved_in_browser) and not _file_progress(path, today).is_empty():
		DirAccess.remove_absolute(path + ".progress.json")
		if OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	return saved_in_file or saved_in_browser

static func load_progress(path: String = SAVE_PATH, unix_time: int = -1) -> Dictionary:
	var today: String = korean_date(unix_time)
	var disk: Dictionary = _file_progress(path, today)
	var browser: JavaScriptObject = _browser_storage(path)
	if browser == null: return disk
	var saved: Dictionary = _decode_progress(browser.readProgress(today), today)
	if not disk.is_empty() and (saved.is_empty() or disk.index > saved.index):
		browser.saveProgress(today, JSON.stringify(disk))
		return disk
	return saved

static func save_progress(index: int, variants: Array[int], path: String = SAVE_PATH, unix_time: int = -1) -> bool:
	var today: String = korean_date(unix_time)
	if not _index_in_range(index, LearningQuestionBank.TYPES.size()) or variants.size() != LearningQuestionBank.TYPES.size(): return false
	for variant: int in variants:
		if not _index_in_range(variant, LearningQuestionBank.PER_TYPE): return false
	var raw: String = JSON.stringify({"version": 1, "date": today, "index": index, "variants": variants})
	var browser: JavaScriptObject = _browser_storage(path)
	var saved_in_browser: bool = browser != null and browser.saveProgress(today, raw) == true
	var disk: Dictionary = _file_progress(path, today)
	if not disk.is_empty() and disk.index > index: return true
	return _write_text(path + ".progress.json", raw) or saved_in_browser

static func _file_progress(path: String, today: String) -> Dictionary:
	var filename: String = path + ".progress.json"
	if not FileAccess.file_exists(filename): return {}
	var file: FileAccess = FileAccess.open(filename, FileAccess.READ)
	if file == null or file.get_length() > MAX_PROGRESS_BYTES: return {}
	return _decode_progress(file.get_as_text(), today)

static func _decode_progress(raw: Variant, today: String) -> Dictionary:
	if not raw is String or raw.is_empty() or raw.length() > MAX_PROGRESS_BYTES: return {}
	var parser: JSON = JSON.new()
	if parser.parse(raw) != OK: return {}
	var data: Variant = parser.data
	var count: int = LearningQuestionBank.TYPES.size()
	if not data is Dictionary: return {}
	var date: Variant = data.get("date")
	var version: Variant = data.get("version")
	if not date is String or date != today: return {}
	if not (version is int or version is float) or version != 1: return {}
	if not _index_in_range(data.get("index"), count): return {}
	var stored_variants: Variant = data.get("variants")
	if not stored_variants is Array or stored_variants.size() != count: return {}
	var variants: Array[int] = []
	for value: Variant in stored_variants:
		if not _index_in_range(value, LearningQuestionBank.PER_TYPE): return {}
		variants.append(int(value))
	return {"version": 1, "date": today, "index": int(data.index), "variants": variants}

static func _index_in_range(value: Variant, size: int) -> bool:
	return (value is int or value is float) and value >= 0 and value < size and floorf(value) == value

static func _write_text(path: String, contents: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	var written: bool = file.store_string(contents)
	file.flush()
	var success: bool = written and file.get_error() == OK
	file.close()
	if success and OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()
		return OS.is_userfs_persistent()
	return success

static func _browser_storage(path: String) -> JavaScriptObject:
	if path != SAVE_PATH or not OS.has_feature("web"): return null
	return JavaScriptBridge.get_interface("QuadDailyQuiz")
