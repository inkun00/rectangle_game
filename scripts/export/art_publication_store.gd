class_name ArtPublicationStore
extends RefCounted

## A legacy drawing sale needs a matching receipt. Standalone exhibitions
## can be uploaded as soon as their PNG and metadata have been saved.
const DEFAULT_PATH: String = "user://art_publications_v1.json"
const MAX_RECORDS: int = 512
const ENDING_KINDS: Dictionary = {"earth": "earth_house", "space": "spaceship"}
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
	var endings: Dictionary = {}
	for record: Variant in records:
		if not record is Dictionary or not _valid_entry(record): return _failure("패들릿 등록 기록이 올바르지 않아요.")
		if identifiers.has(record.id) or fingerprints.has(record.fingerprint): return _failure("패들릿 등록 기록이 중복됐어요.")
		var kind: String = str(record.get("kind", ""))
		if kind in ENDING_KINDS.values():
			if endings.has(kind): return _failure("엔딩 등록 기록이 중복됐어요.")
			endings[kind] = true
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
	var wall: bool = offer.get("kind") == "wall"
	var ship: bool = offer.get("kind") == "ship_exhibit"
	var work: String = "담장" if wall else ("우주선" if ship else "그림")
	var exhibition: bool = wall or ship or offer.get("kind") == "drawing"
	var error: String = ArtSubmissionMetadata.validation_error(metadata.get("author"), metadata.get("title"), metadata.get("description"), offer.has("kind") and not exhibition)
	if not error.is_empty(): return _failure(error.replace("그림", work))
	if exhibition and not _integer_in_range(offer.get("price"), 0, 0): return _failure("전시할 작품 정보를 다시 확인해 주세요.")
	if wall or ship:
		var expected: String = wall_fingerprint(bytes) if wall else ship_fingerprint(bytes)
		if not _exhibition_png_size_valid(bytes) or offer.get("fingerprint") != expected:
			return _failure("전시할 %s의 PNG를 다시 확인해 주세요." % work)
		if ship and not find_ship_image(bytes).is_empty():
			return _failure("이미 전시를 신청한 우주선이에요. 등록 상태를 확인해 주세요.")
	for branch: String in ENDING_KINDS:
		if offer.get("kind") == ENDING_KINDS[branch] and not ending_entry(branch).is_empty():
			return _failure("이미 이 엔딩의 작품을 저장했어요. 등록 상태를 확인해 주세요.")
	var index: int = -1
	for cursor: int in range(entries.size()):
		if str(entries[cursor].fingerprint) == str(offer.get("fingerprint", "")): index = cursor
	if index >= 0 and (wall or entries[index].get("kind") == "wall"):
		return _failure("이미 전시를 신청한 담장이에요. 등록 상태를 확인해 주세요.")
	if index >= 0 and entries[index].get("kind") == "ship_exhibit":
		return _failure("이미 전시를 신청한 우주선이에요. 등록 상태를 확인해 주세요.")
	if index >= 0 and (exhibition or entries[index].get("kind") == "drawing"):
		return _failure("이미 전시를 신청한 그림이에요. 등록 상태를 확인해 주세요.")
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
	if offer.get("kind") == "spaceship": record["gallery"] = "ship"
	if offer.get("kind") == "spaceship" and offer.has("performance"):
		record["performance"] = offer.performance
	if offer.get("kind") == "spaceship" and offer.has("ports"):
		if not valid_ship_ports(offer.ports): return _failure("우주선의 분사구 위치를 확인하지 못했어요.")
		record["ports"] = offer.ports.duplicate(true)
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

func ending_entry(branch: String) -> Dictionary:
	var kind: String = str(ENDING_KINDS.get(branch, ""))
	if kind.is_empty(): return {}
	for entry: Dictionary in entries:
		if entry.get("kind") == kind: return entry.duplicate(true)
	return {}

func find_ship_image(bytes: PackedByteArray) -> Dictionary:
	var digest: String = _digest(bytes)
	for entry: Dictionary in entries:
		if (entry.get("kind") == "ship_exhibit" or entry.get("gallery") == "ship") and entry.png_sha256 == digest:
			return entry.duplicate(true)
	return {}

func pending(receipts: Array[Dictionary], buildings: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var kind: String = str(entry.get("kind", ""))
		if str(entry.status) != "pending" or kind in ["wall", "ship_exhibit"] or kind in ENDING_KINDS.values(): continue
		if buildings != (kind in ["commission", "my_house"]): continue
		if buildings or kind == "drawing":
			result.append(entry.duplicate(true))
			continue
		for receipt: Dictionary in receipts:
			if entry.fingerprint == receipt.get("fingerprint") and entry.title == receipt.get("title") and int(entry.price) == int(receipt.get("price", 0)):
				result.append(entry.duplicate(true))
				break
	return result

func pending_walls() -> Array[Dictionary]:
	return _pending_kind("wall")

func pending_ships() -> Array[Dictionary]:
	return _pending_kind("ship_exhibit")

func _pending_kind(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if entry.get("kind") == kind and entry.status == "pending": result.append(entry.duplicate(true))
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
	var typed_entry: bool = entry.has("kind")
	var rated: bool = entry.has("performance")
	var has_ports: bool = entry.has("ports")
	var has_gallery: bool = entry.has("gallery")
	var expected_size: int = 11 + int(typed_entry) + int(rated) + int(has_ports) + int(has_gallery)
	if entry.size() != expected_size or not entry.has_all(["id", "fingerprint", "author", "title", "description", "price", "png_path", "filename", "png_sha256", "status", "post_url"]): return false
	if typed_entry and entry.kind not in ["drawing", "wall", "ship_exhibit", "commission", "my_house", "earth_house", "spaceship"]: return false
	for key: String in entry:
		if key not in ["price", "performance", "ports"] and not entry[key] is String: return false
	if rated and (entry.get("kind") != "spaceship" or not _integer_in_range(entry.performance, 12, 36)): return false
	if has_ports and (entry.get("kind") != "spaceship" or not valid_ship_ports(entry.ports)): return false
	if has_gallery and (entry.get("kind") != "spaceship" or entry.gallery != "ship"): return false
	if not _hex(entry.id, 32) or not _hex(entry.fingerprint, 64) or not _hex(entry.png_sha256, 64): return false
	if entry.get("kind") in ["wall", "ship_exhibit"] and entry.fingerprint != (str(entry.kind) + ":" + str(entry.png_sha256)).sha256_text(): return false
	if not ArtSubmissionMetadata.validation_error(entry.author, entry.title, entry.description, typed_entry and entry.kind != "drawing").is_empty(): return false
	if not entry.price is int and not entry.price is float: return false
	var price: float = float(entry.price)
	var min_price: int = 100
	var max_price: int = ArtMarket.MAX_PRICE
	match entry.get("kind", ""):
		"drawing", "wall", "ship_exhibit":
			min_price = 0
			max_price = 0
		"commission":
			min_price = 100000000
			max_price = 260000000
		"my_house", "earth_house": max_price = 1250000000
		"spaceship":
			min_price = SpaceshipCatalog.MIN_TOTAL_PRICE
			max_price = SpaceshipCatalog.MAX_TOTAL_PRICE
	if not is_finite(price) or floorf(price) != price or price < min_price or price > max_price: return false
	var filename: String = str(entry.filename)
	if filename.is_empty() or filename != filename.get_file() or not filename.ends_with(".png"): return false
	if str(entry.png_path).length() > 2048 or str(entry.png_path).is_empty(): return false
	return (entry.status == "pending" and entry.post_url == "") or (entry.status == "published" and _valid_post_url(entry.post_url))

static func valid_ship_ports(value: Variant) -> bool:
	if not value is Array or value.is_empty() or value.size() > 3: return false
	for port: Variant in value:
		if not port is Dictionary or port.size() != 3 or not port.has_all(["x", "y", "width"]): return false
		for key: String in ["x", "y", "width"]:
			var coord: Variant = port[key]
			if not coord is float and not coord is int: return false
			if not is_finite(float(coord)) or float(coord) < (0.01 if key == "width" else 0.0) or float(coord) > 1.0: return false
	return true

static func _integer_in_range(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is int and not value is float: return false
	var number: float = float(value)
	return is_finite(number) and floorf(number) == number and number >= minimum and number <= maximum

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

static func wall_fingerprint(bytes: PackedByteArray) -> String:
	return ("wall:" + _digest(bytes)).sha256_text()

static func ship_fingerprint(bytes: PackedByteArray) -> String:
	return ("ship_exhibit:" + _digest(bytes)).sha256_text()

static func _exhibition_png_size_valid(bytes: PackedByteArray) -> bool:
	if bytes.size() < 33 or bytes.size() > 2400000 or bytes.slice(0, 8) != PackedByteArray(SoldArtStore.PNG_HEADER): return false
	# IHDR stores the width and height as unsigned big-endian integers.
	var header: StreamPeerBuffer = StreamPeerBuffer.new()
	header.big_endian = true
	header.data_array = bytes.slice(0, 24)
	header.seek(16)
	return header.get_u32() == 960 and header.get_u32() == 600

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
