class_name ArtMarket
extends RefCounted

## The gallery checks paper coverage and drawing time before pricing visible shapes.
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const Drawing = preload("res://scripts/core/drawing_document.gd")
const MAX_SALES: int = 512
const GRID: Vector2i = Vector2i(48, 30)
const SAMPLE_COUNT: int = 1440
const EMPTY: String = "___"
const MIN_VISIBLE_SAMPLES: int = 3
const LEGACY_MIN_SHAPES: int = 5
const LEGACY_MIN_COVERAGE: float = 0.08
const RECEIPT_VERSION: int = 4
const PRIOR_SALE_SHAPES: int = 6
const PRIOR_SALE_FAMILIES: int = 3
const PRIOR_SALE_COVERAGE: float = 0.12
const MIN_SALE_COVERAGE: float = 0.4
# Keep the earlier minimum palette allowance in the base amount.
const BASE_PRICE: int = 700000
const MAX_PRICE: int = 8000000
const MAX_TITLE_LENGTH: int = 80


## New sale input is validated separately from historical receipt loading.
## This preserves the existing nine-field receipt and earlier saved titles.
static func valid_title(value: Variant) -> bool:
	if not value is String: return false
	var title: String = str(value).strip_edges()
	if title.is_empty() or title.length() > MAX_TITLE_LENGTH: return false
	for index: int in range(str(value).length()):
		var codepoint: int = str(value).unicode_at(index)
		if codepoint < 32 or (codepoint >= 127 and codepoint <= 159): return false
	return true


static func quote(document: DrawingDocument, sold: Array[Dictionary] = []) -> Dictionary:
	var result: Dictionary = {"can_sell": false, "price": 0, "reason": "", "fingerprint": "", "signature": "", "visible_shapes": 0, "families": 0, "colors": 0, "coverage": 0.0, "checks": []}
	if document == null:
		result.reason = "먼저 사각형으로 그림을 그려 주세요."
		return result
	var checked: DrawingDocument = Drawing.new()
	if not checked.restore(document.serialize()):
		result.reason = "그림의 도형을 확인하지 못했어요. 현재 그림은 그대로 두었어요."
		return result
	var parts: Array[Dictionary] = checked.ordered_shapes()
	var raster: Dictionary = _rasterize(parts)
	var coverage: float = float(raster.covered) / float(SAMPLE_COUNT)
	result.signature = str(raster.signature)
	result.coverage = coverage
	var families: Dictionary = {}
	var visible_shapes: int = 0
	for index: int in range(parts.size()):
		if int(raster.visible.get(index, 0)) < MIN_VISIBLE_SAMPLES: continue
		visible_shapes += 1
		families[_specific_family(parts[index].vertices)] = true
	var family_count: int = families.size()
	result.visible_shapes = visible_shapes
	result.families = family_count
	result.colors = int(raster.colors)
	# Keep obscured geometry in this order-independent identity: changing layers
	# alone must not create another sale. The visible signature catches hidden additions.
	result.fingerprint = _fingerprint(parts)
	var enough_coverage: bool = coverage >= MIN_SALE_COVERAGE
	var required_percent: int = roundi(MIN_SALE_COVERAGE * 100.0)
	var enough_work: bool = checked.work_msec >= Drawing.REQUIRED_WORK_MSEC
	var work_seconds: int = floori(float(checked.work_msec) / 1000.0)
	var checks: Array[Dictionary] = [
		{"id": "coverage", "label": "도화지의 %d%% 이상 채우기" % required_percent, "met": enough_coverage, "detail": "현재 %.1f%%" % (floorf(coverage * 1000.0) / 10.0)},
		{"id": "time", "label": "직접 그리거나 편집한 시간 5분 이상", "met": enough_work, "detail": "%d분 %02d초" % [floori(float(work_seconds) / 60.0), work_seconds % 60]}
	]
	result.checks = checks
	if visible_shapes == 0:
		result.reason = "도화지에 잘 보이는 사각형을 하나 이상 그려 주세요."
	elif sold.size() >= MAX_SALES:
		result.reason = "작품 판매 기록이 가득 찼어요. 집 짓기로 우주선 제작비를 더 모을 수 있어요."
	elif is_duplicate(result, sold):
		result.reason = "이미 판매한 작품과 같거나 아주 비슷해요. 새 구도나 도형으로 다른 작품을 만들어 주세요."
	elif not enough_coverage:
		result.reason = "사각형으로 도화지의 %d%% 이상을 채워 주세요." % required_percent
	elif not enough_work:
		result.reason = "도형을 직접 그리고 다듬어 작업 시간 5분을 채워 주세요."
	else:
		result.can_sell = true
		result.price = _current_price(visible_shapes, family_count)
	return result


static func receipt_from_quote(offer: Dictionary, title: String = "") -> Dictionary:
	if not bool(offer.get("can_sell", false)): return {}
	var result: Dictionary = {"version": RECEIPT_VERSION, "title": title.strip_edges().left(MAX_TITLE_LENGTH)}
	if str(result.title).is_empty(): result.title = "나의 사각형 작품"
	for key: String in ["fingerprint", "signature", "price", "visible_shapes", "families", "colors", "coverage"]:
		if not offer.has(key): return {}
		result[key] = offer[key]
	return result if validate_receipt(result) else {}


static func validate_receipt(receipt: Dictionary) -> bool:
	if receipt.size() != 9 or not receipt.has_all(["version", "title", "fingerprint", "signature", "price", "visible_shapes", "families", "colors", "coverage"]): return false
	# Nine fields are used; allow no unrecognized values or hidden nested payloads.
	return _validate_receipt_fields(receipt)


static func _validate_receipt_fields(receipt: Dictionary) -> bool:
	if not _integer(receipt.version, 1, RECEIPT_VERSION) or not receipt.title is String or str(receipt.title).length() > MAX_TITLE_LENGTH or str(receipt.title).strip_edges().is_empty(): return false
	if not receipt.fingerprint is String or str(receipt.fingerprint).length() != 64 or not _is_hex(str(receipt.fingerprint)): return false
	if not receipt.signature is String or str(receipt.signature).length() != SAMPLE_COUNT * 3: return false
	var version: int = int(receipt.version)
	var legacy: bool = version == 1
	var minimum_shapes: int = 1
	var minimum_families: int = 1
	var minimum_coverage: float = 0.0
	if legacy:
		minimum_shapes = LEGACY_MIN_SHAPES
		minimum_coverage = LEGACY_MIN_COVERAGE
	elif version == 2:
		minimum_shapes = PRIOR_SALE_SHAPES
		minimum_families = PRIOR_SALE_FAMILIES
		minimum_coverage = PRIOR_SALE_COVERAGE
	elif version == RECEIPT_VERSION:
		minimum_coverage = MIN_SALE_COVERAGE
	if not _integer(receipt.visible_shapes, minimum_shapes, 128): return false
	if not _integer(receipt.families, minimum_families, 5): return false
	if int(receipt.families) > int(receipt.visible_shapes) or not _integer(receipt.colors, 2 if legacy else 1, 128): return false
	if not receipt.coverage is float and not receipt.coverage is int: return false
	var coverage: float = float(receipt.coverage)
	if not is_finite(coverage) or coverage < minimum_coverage or coverage > 1.0: return false
	var signature: String = str(receipt.signature)
	var occupied: int = 0
	var colors: Dictionary = {}
	for index: int in range(SAMPLE_COUNT):
		var token: String = signature.substr(index * 3, 3)
		if token == EMPTY: continue
		if not _is_hex(token): return false
		occupied += 1
		colors[token] = true
	var measured_coverage: float = float(occupied) / float(SAMPLE_COUNT)
	if colors.size() != int(receipt.colors) or absf(coverage - measured_coverage) > 0.0000001: return false
	var shapes: int = int(receipt.visible_shapes)
	var families: int = int(receipt.families)
	if occupied < shapes * MIN_VISIBLE_SAMPLES: return false
	var expected_price: int
	if version <= 2:
		var base_price: int = 500000 + mini(int(receipt.colors), 8) * 100000 if legacy else BASE_PRICE
		expected_price = _price(shapes, families, coverage, base_price)
	elif version == 3:
		expected_price = _discounted_price(_full_price(shapes, families, measured_coverage), _completion_ratio(shapes, families, measured_coverage))
	else:
		if measured_coverage < MIN_SALE_COVERAGE: return false
		expected_price = _current_price(shapes, families)
	return _integer(receipt.price, 100, MAX_PRICE) and int(receipt.price) == expected_price


static func income(records: Array[Dictionary]) -> int:
	if records.size() > MAX_SALES: return -1
	var total: int = 0
	var fingerprints: Dictionary = {}
	var signatures: Dictionary = {}
	for receipt: Dictionary in records:
		if not validate_receipt(receipt): return -1
		if fingerprints.has(str(receipt.fingerprint)) or signatures.has(str(receipt.signature)): return -1
		fingerprints[str(receipt.fingerprint)] = true
		signatures[str(receipt.signature)] = true
		total += int(receipt.price)
	return total


static func is_duplicate(offer: Dictionary, sold: Array[Dictionary]) -> bool:
	var fingerprint: String = str(offer.get("fingerprint", ""))
	var signature: String = str(offer.get("signature", ""))
	if signature.length() != SAMPLE_COUNT * 3 or fingerprint.is_empty(): return false
	for receipt: Dictionary in sold:
		if fingerprint == str(receipt.get("fingerprint", "")): return true
		if _similar(signature, str(receipt.get("signature", ""))): return true
	return false


static func _price(shapes: int, families: int, coverage: float, base_price: int = BASE_PRICE) -> int:
	var amount: int = base_price + mini(shapes, 24) * 150000 + mini(families, 5) * 450000 + int(coverage * 1000000.0)
	return mini(MAX_PRICE, int(float(amount) / 100.0) * 100)

static func _current_price(shapes: int, families: int) -> int:
	return 200000 + mini(shapes, 12) * 200000 + maxi(shapes - 12, 0) * 42000 + (families - 1) * 2000

static func _completion_ratio(shapes: int, families: int, coverage: float) -> float:
	var shape_ratio: float = minf(float(shapes) / PRIOR_SALE_SHAPES, 1.0)
	var family_ratio: float = minf(float(families) / PRIOR_SALE_FAMILIES, 1.0)
	var area_ratio: float = minf(coverage / PRIOR_SALE_COVERAGE, 1.0)
	return (shape_ratio + family_ratio + area_ratio) / 3.0


static func _full_price(shapes: int, families: int, coverage: float) -> int:
	# Quote the value with each goal filled before applying the buyer's discount.
	return _price(maxi(shapes, PRIOR_SALE_SHAPES), maxi(families, PRIOR_SALE_FAMILIES), maxf(coverage, PRIOR_SALE_COVERAGE))


static func _discounted_price(full_price: int, completion_ratio: float) -> int:
	# Neutralize floating-point noise at an exact 100-won boundary.
	return floori(float(full_price) * completion_ratio / 100.0 + 0.00000001) * 100


static func _rasterize(parts: Array[Dictionary]) -> Dictionary:
	var tokens: PackedStringArray = PackedStringArray()
	tokens.resize(SAMPLE_COUNT)
	tokens.fill(EMPTY)
	var visible: Dictionary = {}
	var colors: Dictionary = {}
	var covered: int = 0
	var cell: Vector2 = Drawing.ARTBOARD.size / Vector2(GRID)
	for index: int in range(parts.size() - 1, -1, -1):
		var part: Dictionary = parts[index]
		var color: Color = part.color
		if color.a < 0.5: continue
		var vertices: PackedVector2Array = part.vertices
		var position: Vector2 = part.position
		var bounds: Rect2 = Math.bounds(vertices)
		bounds.position += position
		var first: Vector2i = Vector2i(((bounds.position - Drawing.ARTBOARD.position) / cell).floor())
		var last: Vector2i = Vector2i(((bounds.end - Drawing.ARTBOARD.position) / cell).ceil())
		var token: String = _color_token(color)
		for row: int in range(clampi(first.y, 0, GRID.y), clampi(last.y, 0, GRID.y)):
			for column: int in range(clampi(first.x, 0, GRID.x), clampi(last.x, 0, GRID.x)):
				var sample: int = row * GRID.x + column
				if tokens[sample] != EMPTY: continue
				var point: Vector2 = Drawing.ARTBOARD.position + (Vector2(column, row) + Vector2(0.5, 0.5)) * cell
				if not Math.contains_point(vertices, point - position): continue
				tokens[sample] = token
				visible[index] = int(visible.get(index, 0)) + 1
				colors[token] = true
				covered += 1
	return {"signature": "".join(tokens), "visible": visible, "covered": covered, "colors": colors.size()}


static func _fingerprint(parts: Array[Dictionary]) -> String:
	var anchor: Vector2 = Vector2.INF
	for part: Dictionary in parts:
		if Color(part.color).a < 0.5: continue
		for point: Vector2 in part.vertices:
			var world_point: Vector2 = point + Vector2(part.position)
			anchor = anchor.min(world_point)
	var entries: PackedStringArray = PackedStringArray()
	for part: Dictionary in parts:
		if Color(part.color).a < 0.5: continue
		var points: PackedStringArray = PackedStringArray()
		for point: Vector2 in part.vertices:
			var world_point: Vector2 = point + Vector2(part.position) - anchor
			points.append("%d,%d" % [roundi(world_point.x / 8.0), roundi(world_point.y / 8.0)])
		points.sort()
		var entry: String = _color_token(part.color) + ":" + ";".join(points)
		if not entries.has(entry): entries.append(entry)
	entries.sort()
	return "|".join(entries).sha256_text()


static func _specific_family(vertices: PackedVector2Array) -> String:
	var properties: Dictionary = Math.classification(vertices)
	for kind: String in ["square", "rectangle", "rhombus", "parallelogram", "trapezoid"]:
		if bool(properties.get(kind, false)): return kind
	return ""


static func _color_token(color: Color) -> String:
	return "%x%x%x" % [clampi(roundi(color.r * 15.0), 0, 15), clampi(roundi(color.g * 15.0), 0, 15), clampi(roundi(color.b * 15.0), 0, 15)]


static func _similar(left: String, right: String) -> bool:
	if right.length() != SAMPLE_COUNT * 3: return false
	var occupied: int = 0
	var different: int = 0
	for index: int in range(SAMPLE_COUNT):
		var a: String = left.substr(index * 3, 3)
		var b: String = right.substr(index * 3, 3)
		if a == EMPTY and b == EMPTY: continue
		occupied += 1
		if a != b: different += 1
	return occupied > 0 and float(different) / float(occupied) <= 0.03


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _is_hex(value: String) -> bool:
	for character: String in value:
		if not "0123456789abcdef".contains(character): return false
	return not value.is_empty()
