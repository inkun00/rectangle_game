class_name ConstructionSaveStore
extends RefCounted

const State = preload("res://scripts/construction/construction_state.gd")
const SAVE_PATH: String = "user://quadrilateral_construction_v1.json"
const MAX_BYTES: int = 8388608

static func save(path: String, state: State) -> Dictionary:
	var content: String = JSON.stringify(state.serialize())
	if content.to_utf8_buffer().size() > MAX_BYTES:
		return {"ok": false, "error": "저장할 건축 기록이 너무 커요."}
	var temporary: String = path + ".tmp"
	var backup: String = path + ".bak"
	var previous: String = backup
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return {"ok": false, "error": "건축 기록을 저장할 수 없어요."}
	file.store_string(content)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return {"ok": false, "error": "저장 공간을 확인해 주세요."}
	var existed: bool = FileAccess.file_exists(path)
	if existed:
		# Do not replace a good recovery copy with a damaged primary file.
		# Keep that damaged file separately until a new primary is published.
		if not _valid_save(path): previous = path + ".invalid"
		if FileAccess.file_exists(previous) and DirAccess.remove_absolute(previous) != OK:
			DirAccess.remove_absolute(temporary)
			return {"ok": false, "error": "이전 저장 기록을 보관하지 못했어요."}
		if DirAccess.rename_absolute(path, previous) != OK:
			DirAccess.remove_absolute(temporary)
			return {"ok": false, "error": "이전 저장 기록을 보관하지 못했어요."}
	if DirAccess.rename_absolute(temporary, path) != OK:
		if existed: DirAccess.rename_absolute(previous, path)
		DirAccess.remove_absolute(temporary)
		return {"ok": false, "error": "새 저장 기록으로 바꾸지 못했어요."}
	return {"ok": true, "error": ""}

static func load_into(path: String, state: State) -> Dictionary:
	if not has_save(path): return {"ok": false, "error": "아직 저장한 건축 기록이 없어요.", "recovered": false, "message": ""}
	# A complete primary always wins. If publishing was interrupted after the
	# old primary was moved away, the fully validated temporary is the newest
	# intended save. When a primary is present but damaged, prefer its backup.
	var candidates: Array[String] = [path, path + ".bak", path + ".tmp"]
	if not FileAccess.file_exists(path): candidates.assign([path + ".tmp", path + ".bak"])
	for candidate: String in candidates:
		var data: Dictionary = _read_data(candidate)
		if data.is_empty() or not state.restore(data): continue
		var recovered: bool = candidate != path
		return {"ok": true, "error": "", "recovered": recovered, "source": candidate, "message": "저장이 중단되어 남아 있던 건축 기록을 복구했어요." if recovered else ""}
	return {"ok": false, "error": "건축 기록을 확인하지 못했어요. 지금 작업은 그대로 유지돼요.", "recovered": false, "message": ""}

static func has_save(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".tmp") or FileAccess.file_exists(path + ".bak")

static func _valid_save(path: String) -> bool:
	var data: Dictionary = _read_data(path)
	if data.is_empty(): return false
	var candidate: State = State.new()
	return candidate.restore(data)

static func _read_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	if file.get_length() > MAX_BYTES:
		file.close()
		return {}
	var content: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(content) != OK or not json.data is Dictionary: return {}
	return json.data
