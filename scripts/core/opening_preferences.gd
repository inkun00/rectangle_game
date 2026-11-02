class_name OpeningPreferences
extends RefCounted

## Device-local viewing preference, independent of artwork and adventure saves.
const SAVE_PATH: String = "user://quadrilateral_opening_v1.cfg"
const VERSION: int = 1
const MAX_BYTES: int = 4096

var seen: bool = false


func should_offer(testing: bool, arguments: PackedStringArray) -> bool:
	if testing or seen: return false
	for argument: String in arguments:
		if argument.begins_with("--quad-preview-"): return false
	return true


func load_file(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path): return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var length: int = file.get_length()
	file.close()
	if length > MAX_BYTES: return false
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK: return false
	var version: Variant = config.get_value("opening", "version", null)
	var stored_seen: Variant = config.get_value("opening", "seen", null)
	if not version is int or version != VERSION or not stored_seen is bool: return false
	seen = stored_seen
	return true


func save_file(path: String = SAVE_PATH) -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("opening", "version", VERSION)
	config.set_value("opening", "seen", seen)
	return config.save(path)
