class_name WorldSaveStore
extends RefCounted
const SAVE_PATH: String = "user://quadrilateral_world_v1.json"
const VERSION: int = 1

static func save_game(editor: Dictionary, journal: Dictionary, world: Dictionary, path: String = SAVE_PATH, adventure: Dictionary = {}) -> Error:
	var data: Dictionary = {"version": VERSION, "editor": editor, "journal": journal, "world": world}
	if not adventure.is_empty(): data["adventure"] = adventure
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	var backup: String = path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup): DirAccess.remove_absolute(backup)
		var backup_error: Error = DirAccess.rename_absolute(path, backup)
		if backup_error != OK: return backup_error
	var result: Error = DirAccess.rename_absolute(temp, path)
	if result != OK and FileAccess.file_exists(backup): DirAccess.rename_absolute(backup, path)
	return result

static func load_game(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 2000000: return {}
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK: return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary: return {}
	var data: Dictionary = parsed
	# JSON numbers decode as floats. Check the type before converting: objects,
	# arrays and null must be ordinary rejected saves, never script errors.
	var version: Variant = data.get("version", null)
	if not (version is int or version is float): return {}
	if not is_finite(float(version)) or float(version) != float(VERSION): return {}
	for field: String in ["editor", "journal", "world"]:
		if not data.get(field) is Dictionary: return {}
	if data.has("adventure") and not data["adventure"] is Dictionary: return {}
	return data
