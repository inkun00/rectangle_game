class_name LearningProgress
extends RefCounted

## Anonymous local practice history, separate from RPG XP and construction money.
const Catalog = preload("res://scripts/learning/learning_catalog.gd")
const SAVE_PATH: String = "user://quadrilateral_learning_v1.json"
signal changed
var completed: Dictionary = {}
var attempts: Dictionary = {}
var peaceful: bool = false
var touch_controls: bool = false

func record_attempt(id: String, correct: bool) -> void:
	if not Catalog.IDS.has(id): return
	attempts[id] = mini(int(attempts.get(id, 0)) + 1, 100000)
	if correct: completed[id] = true
	changed.emit()

func next_lesson() -> String:
	for id: String in Catalog.IDS:
		if not completed.has(id): return id
	return Catalog.IDS[0]

func serialize() -> Dictionary:
	return {"version": 1, "completed": completed.duplicate(), "attempts": attempts.duplicate(), "peaceful": peaceful, "touch_controls": touch_controls}

func restore(data: Dictionary) -> bool:
	var version: Variant = data.get("version")
	if not (version is int or version is float) or not is_finite(float(version)) or float(version) != 1.0: return false
	if not data.get("completed") is Dictionary or not data.get("attempts") is Dictionary: return false
	if not data.get("peaceful", false) is bool or not data.get("touch_controls", false) is bool: return false
	for id: Variant in data.completed:
		if not id is String or not Catalog.IDS.has(id) or not data.completed[id] is bool or not data.completed[id]: return false
	for id: Variant in data.attempts:
		var value: Variant = data.attempts[id]
		if not id is String or not Catalog.IDS.has(id) or not (value is int or value is float): return false
		if not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < 1.0 or float(value) > 100000.0: return false
	for id: String in data.completed:
		if not data.attempts.has(id): return false
	completed = data.completed.duplicate()
	attempts = {}
	for id: String in data.attempts: attempts[id] = int(data.attempts[id])
	peaceful = bool(data.get("peaceful", false))
	touch_controls = bool(data.get("touch_controls", false))
	changed.emit()
	return true

func save_file(path: String = SAVE_PATH) -> Error:
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(serialize()))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK: return error
	var backup: String = path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup):
			var remove_error: Error = DirAccess.remove_absolute(backup)
			if remove_error != OK: return remove_error
		var backup_error: Error = DirAccess.rename_absolute(path, backup)
		if backup_error != OK: return backup_error
	var result: Error = DirAccess.rename_absolute(temp, path)
	if result != OK and FileAccess.file_exists(backup): DirAccess.rename_absolute(backup, path)
	return result

func load_file(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path): return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16000: return false
	var parser: JSON = JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	file.close()
	if error != OK: return false
	var data: Variant = parser.data
	return restore(data) if data is Dictionary else false
