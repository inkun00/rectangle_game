class_name TutorialProgress
extends RefCounted

## Device-local onboarding preferences; never part of artwork or world saves.
const Catalog: GDScript = preload("res://scripts/tutorial/tutorial_catalog.gd")
const SAVE_PATH: String = "user://quadrilateral_tutorial_v1.json"
const VERSION: int = 1
const MAX_BYTES: int = 4096
const VALID_STATUSES: Array[String] = ["completed", "skipped"]

signal changed

var statuses: Dictionary = {}

func should_offer(mode: String) -> bool:
	return Catalog.MODE_IDS.has(mode) and not statuses.has(mode)

func mark(mode: String, status: String) -> bool:
	if not Catalog.MODE_IDS.has(mode) or not VALID_STATUSES.has(status): return false
	if statuses.get(mode, "") == status: return true
	statuses[mode] = status
	changed.emit()
	return true

func serialize() -> Dictionary:
	return {"version": VERSION, "statuses": statuses.duplicate(true)}

func restore(data: Dictionary) -> bool:
	if not _valid_data(data): return false
	var restored: Dictionary = (data["statuses"] as Dictionary).duplicate(true)
	if statuses != restored:
		statuses = restored
		changed.emit()
	return true

func save_file(path: String = SAVE_PATH) -> Error:
	var snapshot: Dictionary = serialize()
	if not _valid_data(snapshot): return ERR_INVALID_DATA
	var content: String = JSON.stringify(snapshot)
	if content.to_utf8_buffer().size() > MAX_BYTES: return ERR_OUT_OF_MEMORY
	var temporary: String = path + ".tmp"
	var backup: String = path + ".bak"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return write_error
	var existed: bool = FileAccess.file_exists(path)
	if existed:
		if FileAccess.file_exists(backup):
			var remove_error: Error = DirAccess.remove_absolute(backup)
			if remove_error != OK:
				DirAccess.remove_absolute(temporary)
				return remove_error
		var backup_error: Error = DirAccess.rename_absolute(path, backup)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary)
			return backup_error
	var publish_error: Error = DirAccess.rename_absolute(temporary, path)
	if publish_error != OK:
		if existed: DirAccess.rename_absolute(backup, path)
		DirAccess.remove_absolute(temporary)
	return publish_error

func load_file(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path): return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	if file.get_length() > MAX_BYTES:
		file.close()
		return false
	var content: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	if parser.parse(content) != OK: return false
	var data: Variant = parser.data
	return restore(data) if data is Dictionary else false

static func _valid_data(data: Dictionary) -> bool:
	if data.size() != 2 or not data.has("version") or not data.has("statuses"): return false
	var version: Variant = data["version"]
	if not (version is int or version is float): return false
	if not is_finite(float(version)) or float(version) != float(VERSION): return false
	var stored: Variant = data["statuses"]
	if not stored is Dictionary: return false
	for mode: Variant in stored:
		if not mode is String or not Catalog.MODE_IDS.has(mode): return false
		var status: Variant = stored[mode]
		if not status is String or not VALID_STATUSES.has(status): return false
	return true
