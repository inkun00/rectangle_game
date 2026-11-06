class_name ArtMarket
extends RefCounted

## A deterministic offer for a player's visible quadrilateral composition.
## The market rewards composition variety, not a subjective artistic grade.
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const Drawing = preload("res://scripts/core/drawing_document.gd")
const Composition = preload("res://scripts/economy/art_composition.gd")
const MAX_SALES: int = 512
const GRID: Vector2i = Vector2i(48, 30)
const SAMPLE_COUNT: int = 1440
const EMPTY: String = "___"
const MIN_VISIBLE_SAMPLES: int = 3
const MIN_SHAPES: int = 5
const MIN_COVERAGE: float = 0.08
# Historical receipts retain the original five-piece/8% price and validation
# rules. These stricter requirements apply only when offering a new painting.
const MIN_SALE_SHAPES: int = 6
const MIN_SALE_COVERAGE: float = 0.12
const MIN_COLOR_SHARE: float = 0.03
const MIN_COLOR_DISTANCE: float = 0.18
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
	var result: Dictionary = {"can_sell": false, "price": 0, "reason": "", "fingerprint": "", "signature": "", "visible_shapes": 0, "families": 0, "colors": 0, "coverage": 0.0, "subject": "", "checks": []}
	if document == null:
		result.reason = "먼저 사각형으로 그림을 그려 주세요."
		return result
	var checked: DrawingDocument = Drawing.new()
	if not checked.restore(document.serialize()):
		result.reason = "그림의 도형을 확인하지 못했어요. 현재 그림은 그대로 두었어요."
		return result
	var parts: Array[Dictionary] = checked.ordered_shapes()
	var raster: Dictionary = _rasterize(parts)
	result.signature = str(raster.signature)
	result.coverage = float(raster.covered) / float(SAMPLE_COUNT)
	var families: Dictionary = {}
	var visible: Array[Dictionary] = []
	for index: int in range(parts.size()):
		if int(raster.visible.get(index, 0)) < MIN_VISIBLE_SAMPLES: continue
		visible.append(parts[index])
		families[_specific_family(parts[index].vertices)] = true
	result.visible_shapes = visible.size()
	result.families = families.size()
	result.colors = int(raster.colors)
	# Keep obscured geometry in this order-independent identity: changing layers
	# alone must not create another sale. The visible signature catches hidden additions.
	result.fingerprint = _fingerprint(parts)
	result.price = _price(int(result.visible_shapes), int(result.families), int(result.colors), float(result.coverage))
	var palette_ok: bool = _has_meaningful_colors(raster.color_samples, int(raster.covered))
	var form: Dictionary = Composition.assess(parts, raster.visible)
	result.subject = str(form.get("subject", ""))
	var checks: Array[Dictionary] = [
		{"id": "pieces", "label": "눈에 보이는 도형 6개 이상", "met": visible.size() >= MIN_SALE_SHAPES, "detail": "%d / 6개" % visible.size()},
		{"id": "palette", "label": "구별되는 색 2가지 이상", "met": palette_ok, "detail": "작은 점을 제외하고 두 색이 각각 3% 이상 보여야 해요."},
		{"id": "coverage", "label": "종이의 12% 이상 그리기", "met": float(result.coverage) >= MIN_SALE_COVERAGE, "detail": "현재 %.1f%%" % (float(result.coverage) * 100.0)}
	]
	for check: Dictionary in form.get("criteria", []): checks.append(check)
	result.checks = checks
	if visible.size() < MIN_SALE_SHAPES:
		result.reason = "눈에 보이는 사각형을 6개 이상 조합해 주세요. 아주 작거나 완전히 가려진 도형은 세지 않아요."
	elif not palette_ok:
		result.reason = "잘 구별되는 두 색으로 큰 부분과 세부를 꾸며 주세요. 아주 작은 색 점은 조건에 세지 않아요."
	elif float(result.coverage) < MIN_SALE_COVERAGE:
		result.reason = "그림을 조금 더 크게 그려 주세요. 종이의 12% 이상을 직접 그린 사각형으로 채워 주세요."
	elif not bool(form.get("has_form", false)):
		result.reason = str(form.get("reason", "사각형을 조합해 사물의 몸체와 세부 또는 정렬된 기하 구성을 만들어 주세요."))
	elif sold.size() >= MAX_SALES:
		result.reason = "작품 판매 기록이 가득 찼어요. 집 짓기로 우주선 제작비를 더 모을 수 있어요."
	elif is_duplicate(result, sold):
		result.reason = "이미 판매한 작품과 같거나 아주 비슷해요. 새 구도나 도형으로 다른 작품을 만들어 주세요."
	else:
		result.can_sell = true
		result.reason = "%s 구성 기준을 갖췄어요. 마을 화랑에서 이 가격에 작품을 구매해요." % str(result.subject)
	return result


static func receipt_from_quote(offer: Dictionary, title: String = "") -> Dictionary:
	if not bool(offer.get("can_sell", false)): return {}
	var result: Dictionary = {"version": 1, "title": title.strip_edges().left(80)}
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
	if not _integer(receipt.version, 1, 1) or not receipt.title is String or str(receipt.title).length() > 80 or str(receipt.title).strip_edges().is_empty(): return false
	if not receipt.fingerprint is String or str(receipt.fingerprint).length() != 64 or not _is_hex(str(receipt.fingerprint)): return false
	if not receipt.signature is String or str(receipt.signature).length() != SAMPLE_COUNT * 3: return false
	if not _integer(receipt.visible_shapes, MIN_SHAPES, 128) or not _integer(receipt.families, 1, 5): return false
	if int(receipt.families) > int(receipt.visible_shapes) or not _integer(receipt.colors, 2, 128): return false
	if not receipt.coverage is float and not receipt.coverage is int: return false
	var coverage: float = float(receipt.coverage)
	if not is_finite(coverage) or coverage < MIN_COVERAGE or coverage > 1.0: return false
	var signature: String = str(receipt.signature)
	var occupied: int = 0
	var colors: Dictionary = {}
	for index: int in range(SAMPLE_COUNT):
		var token: String = signature.substr(index * 3, 3)
		if token == EMPTY: continue
		if not _is_hex(token): return false
		occupied += 1
		colors[token] = true
	if colors.size() != int(receipt.colors) or absf(coverage - float(occupied) / float(SAMPLE_COUNT)) > 0.0000001: return false
	if occupied < int(receipt.visible_shapes) * MIN_VISIBLE_SAMPLES: return false
	return _integer(receipt.price, 100, MAX_PRICE) and int(receipt.price) == _price(int(receipt.visible_shapes), int(receipt.families), int(receipt.colors), coverage)


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


static func _price(shapes: int, families: int, colors: int, coverage: float) -> int:
	if shapes < MIN_SHAPES or colors < 2 or coverage < MIN_COVERAGE: return 0
	var amount: int = 500000 + mini(shapes, 24) * 150000 + mini(families, 5) * 450000 + mini(colors, 8) * 100000 + int(coverage * 1000000.0)
	return mini(MAX_PRICE, int(float(amount) / 100.0) * 100)


static func _has_meaningful_colors(samples: Dictionary, covered: int) -> bool:
	if covered <= 0: return false
	var colors: Array[Color] = []
	var digits: String = "0123456789abcdef"
	for token: String in samples:
		if float(samples[token]) / float(covered) < MIN_COLOR_SHARE: continue
		colors.append(Color(float(digits.find(token[0])) / 15.0, float(digits.find(token[1])) / 15.0, float(digits.find(token[2])) / 15.0))
	for left: int in range(colors.size()):
		for right: int in range(left + 1, colors.size()):
			var difference: Vector3 = Vector3(colors[left].r - colors[right].r, colors[left].g - colors[right].g, colors[left].b - colors[right].b)
			if difference.length() >= MIN_COLOR_DISTANCE: return true
	return false


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
				colors[token] = int(colors.get(token, 0)) + 1
				covered += 1
	return {"signature": "".join(tokens), "visible": visible, "covered": covered, "colors": colors.size(), "color_samples": colors}


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
