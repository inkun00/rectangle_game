class_name ArtPublicationStore
extends RefCounted

## Drawing entries become eligible when their sale is committed. Building
## entries are queued after the completed design and PNG have been checked.
const DEFAULT_PATH: String = "user://art_publications_v1.json"
const MAX_RECORDS: int = 512
var path: String = DEFAULT_PATH
var entries: Array[Dictionary] = []
var loaded: bool = false

func load_file() -> Dictionary:
	var source: String = path
	if not FileAccess.file_exists(source) and FileAccess.file_exists(path + ".bak"):
		source = path + ".bak"
	if not FileAccess.file_exists(source):
		entries.clear()
		loaded = true
		return {"ok": true}
	var file: FileAccess = FileAccess.open(source, FileAccess.READ)
	if file == null or file.get_length() > 4000000: return _failure("패들릿 등록 기록을 읽지 못했어요.")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("entries") is Array:
		return _failure("패들릿 등록 기록을 확인해 주세요. 기존 기록은 그대로 두었어요.")
	var records: Array = parsed.entries
	if records.size() > MAX_RECORDS: return _failure("패들릿 등록 기록이 너무 많아요.")
	var candidate: Array[Dictionary] = []
	var identifiers: Dictionary = {}
	var fingerprints: Dictionary = {}
	for record: Variant in records:
		if not record is Dictionary or not _valid_entry(record): return _failure("패들릿 등록 기록이 올바르지 않아요.")
		if identifiers.has(record.id) or fingerprints.has(record.fingerprint): return _failure("패들릿 등록 기록이 중복됐어요.")
		identifiers[record.id] = true
		fingerprints[record.fingerprint] = true
		candidate.append(record.duplicate(true))
	entries = candidate
	loaded = true
	return {"ok": true}

func prepare(metadata: Dictionary, offer: Dictionary, saved: Dictionary, bytes: PackedByteArray) -> Dictionary:
	if not loaded:
		var restored: Dictionary = load_file()
		if not bool(restored.ok): return restored
	var error: String = ArtSubmissionMetadata.validation_error(metadata.get("author"), metadata.get("title"), metadata.get("description"), offer.has("kind"))
	if not error.is_empty(): return _failure(error)
	var index: int = -1
	for cursor: int in range(entries.size()):
		if str(entries[cursor].fingerprint) == str(offer.get("fingerprint", "")): index = cursor
	if index >= 0 and offer.has("kind"): return _failure("이미 패들릿에 보낸 건물이에요. 등록 상태를 확인해 주세요.")
	if index >= 0 and str(entries[index].status) == "published": return _failure("이미 패들릿에 등록한 그림이에요.")
	if index < 0 and entries.size() >= MAX_RECORDS: return _failure("패들릿 등록 기록이 가득 찼어요.")
	var identifier: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var record: Dictionary = {
		"id": identifier, "fingerprint": str(offer.get("fingerprint", "")),
		"author": str(metadata.author).strip_edges(), "title": str(metadata.title).strip_edges(),
		"description": str(metadata.description).strip_edges(), "price": int(offer.get("price", 0)),
		"png_path": str(saved.get("path", "")), "filename": str(saved.get("filename", "")),
		"png_sha256": _digest(bytes), "status": "pending", "post_url": ""
	}
	if offer.has("kind"): record["kind"] = offer.kind
	if not _valid_entry(record): return _failure("패들릿에 보낼 그림 정보를 확인하지 못했어요.")
	var candidate: Array[Dictionary] = entries.duplicate(true)
	if index >= 0: candidate[index] = record
	else: candidate.append(record)
	var result: Dictionary = _save(candidate)
	if bool(result.ok): result["entry"] = record.duplicate(true)
	return result

func find_entry(fingerprint: String) -> Dictionary:
	for entry: Dictionary in entries:
		if entry.fingerprint == fingerprint: return entry.duplicate(true)
	return {}

func pending(receipts: Array[Dictionary], buildings: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if str(entry.status) != "pending" or entry.has("kind") != buildings: continue
		if buildings:
			result.append(entry.duplicate(true))
			continue
		for receipt: Dictionary in receipts:
			if entry.fingerprint == receipt.get("fingerprint") and entry.title == receipt.get("title") and int(entry.price) == int(receipt.get("price", 0)):
				result.append(entry.duplicate(true))
				break
	return result

func mark_published(identifier: String, post_url: String) -> Dictionary:
	if not _valid_post_url(post_url): return _failure("패들릿 등록 주소를 확인하지 못했어요.")
	var candidate: Array[Dictionary] = entries.duplicate(true)
	for entry: Dictionary in candidate:
		if str(entry.id) == identifier:
			entry.status = "published"
			entry.post_url = post_url
			return _save(candidate)
	return _failure("패들릿 등록 기록을 찾지 못했어요.")

func read_png(entry: Dictionary, directory: String = "") -> PackedByteArray:
	var destination: String = SoldArtStore.default_directory() if directory.is_empty() else directory
	var expected: String = destination.path_join(str(entry.get("filename", ""))).simplify_path()
	if str(entry.get("png_path", "")).simplify_path() != expected: return PackedByteArray()
	if not FileAccess.file_exists(expected): return PackedByteArray()
	var file: FileAccess = FileAccess.open(expected, FileAccess.READ)
	if file == null or file.get_length() > 2400000: return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	if _digest(bytes) != str(entry.png_sha256): return PackedByteArray()
	return bytes

func last_author() -> String:
	return "" if entries.is_empty() else str(entries.back().author)

func _save(candidate: Array[Dictionary]) -> Dictionary:
	var temporary: String = path + ".tmp"
	var backup: String = path + ".bak"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _failure("패들릿 등록 정보를 저장하지 못했어요. 그림은 그대로 두었어요.")
	file.store_string(JSON.stringify({"version": 1, "entries": candidate}))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK: return _failure("패들릿 등록 정보를 끝까지 저장하지 못했어요.")
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK: return _failure("패들릿 등록 기록을 보존하지 못했어요.")
		if DirAccess.rename_absolute(path, backup) != OK: return _failure("패들릿 등록 기록을 보존하지 못했어요.")
	if DirAccess.rename_absolute(temporary, path) != OK:
		if FileAccess.file_exists(backup): DirAccess.rename_absolute(backup, path)
		return _failure("패들릿 등록 정보를 저장하지 못했어요.")
	entries = candidate
	loaded = true
	if OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	return {"ok": true}

static func _valid_entry(entry: Dictionary) -> bool:
	var building: bool = entry.has("kind")
	if entry.size() != (12 if building else 11) or not entry.has_all(["id", "fingerprint", "author", "title", "description", "price", "png_path", "filename", "png_sha256", "status", "post_url"]): return false
	if building and entry.kind not in ["commission", "my_house"]: return false
	for key: String in entry:
		if key != "price" and not entry[key] is String: return false
	if not _hex(entry.id, 32) or not _hex(entry.fingerprint, 64) or not _hex(entry.png_sha256, 64): return false
	if not ArtSubmissionMetadata.validation_error(entry.author, entry.title, entry.description, building).is_empty(): return false
	if not entry.price is int and not entry.price is float: return false
	var price: float = float(entry.price)
	var min_price: int = 100
	var max_price: int = ArtMarket.MAX_PRICE
	match entry.get("kind", ""):
		"commission":
			min_price = 100000000
			max_price = 260000000
		"my_house": max_price = 1250000000
	if not is_finite(price) or floorf(price) != price or price < min_price or price > max_price: return false
	var filename: String = str(entry.filename)
	if filename.is_empty() or filename != filename.get_file() or not filename.ends_with(".png"): return false
	if str(entry.png_path).length() > 2048 or str(entry.png_path).is_empty(): return false
	return (entry.status == "pending" and entry.post_url == "") or (entry.status == "published" and _valid_post_url(entry.post_url))

static func _valid_post_url(url: String) -> bool:
	return url.begins_with("https://padlet.com/") and url.length() <= 2048 and not url.contains("\n") and not url.contains("\r")

static func _hex(value: String, length: int) -> bool:
	if value.length() != length: return false
	for character: String in value:
		if not "0123456789abcdef".contains(character): return false
	return true

static func _digest(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
