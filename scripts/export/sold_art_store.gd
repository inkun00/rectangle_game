class_name SoldArtStore
extends RefCounted

const MAX_TITLE_LENGTH: int = 80
const MAX_STEM_BYTES: int = 180
const PNG_HEADER: Array[int] = [137, 80, 78, 71, 13, 10, 26, 10]

static func default_directory() -> String:
	if OS.has_feature("web"): return "user://sold_artworks"
	var pictures: String = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures.is_empty() or not DirAccess.dir_exists_absolute(pictures):
		return "user://sold_artworks"
	return pictures.path_join("사각형 월드").path_join("판매한 그림")

## Empty directory selects the platform default. GDScript default arguments
## cannot call default_directory(), so resolve it inside the function.
static func save_png(bytes: PackedByteArray, title: String, directory: String = "") -> Dictionary:
	var clean_title: String = title.strip_edges()
	if clean_title.is_empty() or clean_title.length() > MAX_TITLE_LENGTH:
		return _failure("그림 제목을 1자부터 80자까지 적어 주세요.")
	if not _valid_png(bytes):
		return _failure("그림 PNG를 확인하지 못했어요. 그림은 그대로 두었어요.")
	var destination: String = default_directory() if directory.is_empty() else directory
	if FileAccess.file_exists(destination): return _failure("그림 저장 폴더를 만들 수 없어요.")
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(destination)
	if directory_error != OK: return _failure("그림 저장 폴더를 만들 수 없어요. 저장 위치를 확인해 주세요.")
	var stem: String = _safe_stem(clean_title)
	var timestamp: String = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "_")
	var cryptography: Crypto = Crypto.new()
	for _attempt: int in range(8):
		var random_bytes: PackedByteArray = cryptography.generate_random_bytes(16)
		if random_bytes.size() != 16: return _failure("그림 파일 이름을 만들지 못했어요. 다시 시도해 주세요.")
		var filename: String = "%s_%s_%s.png" % [stem, timestamp, random_bytes.hex_encode()]
		var path: String = destination.path_join(filename)
		var temporary: String = destination.path_join("." + filename + ".tmp")
		# A fresh random name keeps different app sessions independent. Explicit
		# existence checks also preserve any file or directory already at a name.
		if _exists(path) or _exists(temporary): continue
		var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
		if file == null: return _failure("그림을 저장하지 못했어요. 저장 위치와 남은 공간을 확인해 주세요.")
		file.store_buffer(bytes)
		file.flush()
		var write_error: Error = file.get_error()
		var written: int = file.get_length()
		file.close()
		if write_error != OK or written != bytes.size():
			DirAccess.remove_absolute(temporary)
			return _failure("그림을 끝까지 저장하지 못했어요. 남은 공간을 확인해 주세요.")
		if _exists(path):
			DirAccess.remove_absolute(temporary)
			continue
		var publish_error: Error = DirAccess.rename_absolute(temporary, path)
		if publish_error != OK:
			DirAccess.remove_absolute(temporary)
			return _failure("그림 파일을 완성하지 못했어요. 저장 위치를 확인해 주세요.")
		return {"ok": true, "error": "", "path": path, "filename": filename}
	return _failure("기존 그림과 다른 파일 이름을 만들지 못했어요. 다시 시도해 주세요.")

static func _safe_stem(title: String) -> String:
	var result: String = ""
	for character: String in title:
		var code: int = character.unicode_at(0)
		if code < 32 or (code >= 127 and code <= 159) or '<>:"/\\|?*'.contains(character): continue
		result += character
	result = result.strip_edges()
	while result.ends_with(".") or result.ends_with(" "): result = result.left(-1)
	if result.is_empty(): result = "그림"
	var device: String = result.get_slice(".", 0).strip_edges().to_upper()
	var reserved: bool = device in ["CON", "PRN", "AUX", "NUL", "CLOCK$", "CONIN$", "CONOUT$"]
	if device.length() == 4 and (device.begins_with("COM") or device.begins_with("LPT")):
		reserved = reserved or "123456789¹²³".contains(device.right(1))
	if reserved: result = "그림_" + result
	while result.to_utf8_buffer().size() > MAX_STEM_BYTES: result = result.left(-1)
	while result.ends_with(".") or result.ends_with(" "): result = result.left(-1)
	return result

static func _valid_png(bytes: PackedByteArray) -> bool:
	if bytes.size() < 33: return false
	for index: int in range(PNG_HEADER.size()):
		if bytes[index] != PNG_HEADER[index]: return false
	# Bad user input should return a useful error instead of logging an engine
	# failure. Decoding is synchronous; restore the previous logging preference.
	var previous_errors: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var image: Image = Image.new()
	var decode_error: Error = image.load_png_from_buffer(bytes)
	Engine.print_error_messages = previous_errors
	return decode_error == OK and not image.is_empty()

static func _exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "path": "", "filename": ""}
