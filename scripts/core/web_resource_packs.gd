class_name WebResourcePacks
extends Node
## Web-only delivery. Desktop/editor exports retain their complete offline PCK.

signal request_finished(feature: String, success: bool)

const FEATURES: Array[String] = ["drawing", "construction", "adventure", "space", "opening"]
const CACHE_DIRECTORY: String = "user://web-resource-packs"
static var _service: WebResourcePacks
static var _manifest_cache: Dictionary = {}
var _ready_features: Dictionary = {}
var _pending: Dictionary = {}
var _next_token: int = 0


static func _manifest() -> Dictionary:
	if not OS.has_feature("web"): return {}
	if not _manifest_cache.is_empty(): return _manifest_cache
	var encoded: Variant = JavaScriptBridge.eval("JSON.stringify(window.QUAD_RESOURCE_PACKS || null)", true)
	if not encoded is String: return {}
	var parsed: Variant = JSON.parse_string(encoded)
	if not parsed is Dictionary or parsed.get("version", 0) != 1 or not parsed.get("packs", null) is Dictionary: return {}
	_manifest_cache = parsed
	return _manifest_cache


static func is_web_delivery() -> bool:
	return not _manifest().is_empty()


static func unlock_audio() -> void:
	if not OS.has_feature("web"): return
	var bridge: JavaScriptObject = JavaScriptBridge.get_interface("QuadResourcePacks")
	if bridge != null: bridge.unlockAudio()


static func ensure(feature: String) -> bool:
	if not is_web_delivery(): return true
	if not FEATURES.has(feature): return false
	if not is_instance_valid(_service):
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree == null: return false
		_service = WebResourcePacks.new()
		_service.name = "WebResourcePacks"
		tree.root.add_child(_service)
	return await _service._ensure_feature(feature)


static func cancel(feature: String) -> void:
	if not is_instance_valid(_service) or not _service._pending.has(feature): return
	var token: int = int(_service._pending[feature].token)
	var bridge: JavaScriptObject = JavaScriptBridge.get_interface("QuadResourcePacks")
	if bridge != null: bridge.cancel(feature)
	# A missing bridge must also release callers waiting for cancellation.
	_service._finish(feature, token, false)


static func valid_entry(feature: String, entry: Dictionary) -> bool:
	if not FEATURES.has(feature): return false
	var digest: String = str(entry.get("sha256", ""))
	if digest.length() != 64 or digest != digest.to_lower() or not digest.is_valid_hex_number(false): return false
	var size: Variant = entry.get("bytes", 0)
	if not (size is int or size is float) or size <= 0 or size > 100_000_000 or float(size) != floorf(float(size)): return false
	return str(entry.get("url", "")) == "feature-%s-%s.pck" % [feature, digest.left(12)]


static func _digest(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func valid_bytes(bytes: PackedByteArray, entry: Dictionary) -> bool:
	return bytes.size() == int(entry.get("bytes", -1)) and _digest(bytes) == str(entry.get("sha256", ""))


func _ensure_feature(feature: String) -> bool:
	if _ready_features.get(feature, false): return true
	if not _pending.has(feature):
		var packs: Dictionary = _manifest().get("packs", {})
		var entry: Dictionary = packs.get(feature, {})
		if not valid_entry(feature, entry): return false
		var cache_path: String = "%s/%s-%s.pck" % [CACHE_DIRECTORY, feature, str(entry.sha256)]
		if FileAccess.file_exists(cache_path):
			var cached: PackedByteArray = FileAccess.get_file_as_bytes(cache_path)
			if valid_bytes(cached, entry) and ProjectSettings.load_resource_pack(cache_path, false):
				_ready_features[feature] = true
				return true
		var bridge: JavaScriptObject = JavaScriptBridge.get_interface("QuadResourcePacks")
		if bridge == null: return false
		_next_token += 1
		var token: int = _next_token
		var callback: JavaScriptObject = JavaScriptBridge.create_callback(_download_finished.bind(feature, token))
		_pending[feature] = {"token": token, "callback": callback, "entry": entry, "path": cache_path}
		bridge.download(feature, callback)
	# The bridge may reject a malformed manifest synchronously.
	while _pending.has(feature):
		var result: Array = await request_finished
		if str(result[0]) == feature: return bool(result[1])
	return bool(_ready_features.get(feature, false))


func _download_finished(arguments: Array, feature: String, token: int) -> void:
	if not _pending.has(feature) or int(_pending[feature].token) != token: return
	if arguments.size() < 2 or not bool(arguments[0]) or not arguments[1] is JavaScriptObject:
		_finish(feature, token, false)
		return
	var bytes: PackedByteArray = JavaScriptBridge.js_buffer_to_packed_byte_array(arguments[1])
	var entry: Dictionary = _pending[feature].entry
	if not valid_bytes(bytes, entry):
		_finish(feature, token, false)
		return
	var path: String = str(_pending[feature].path)
	if DirAccess.make_dir_recursive_absolute(CACHE_DIRECTORY) != OK:
		_finish(feature, token, false)
		return
	var temporary_path: String = path + ".download"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		_finish(feature, token, false)
		return
	file.store_buffer(bytes)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		_finish(feature, token, false)
		return
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	if DirAccess.rename_absolute(temporary_path, path) != OK or not ProjectSettings.load_resource_pack(path, false):
		_finish(feature, token, false)
		return
	JavaScriptBridge.force_fs_sync()
	_finish(feature, token, true)


func _finish(feature: String, token: int, success: bool) -> void:
	if not _pending.has(feature) or int(_pending[feature].token) != token: return
	_pending.erase(feature)
	if success: _ready_features[feature] = true
	request_finished.emit(feature, success)
