class_name ConstructionAwards
extends RefCounted
## A transparent game rubric, not an AI opinion about architectural beauty.
## Every measurement comes from the actual ordered quadrilateral vertices.

const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Document = preload("res://scripts/construction/construction_document.gd")
const Facade = preload("res://scripts/construction/construction_facade.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const VERSION: int = 1
const MINIMUM_STAGE: int = 3
const THRESHOLDS: Array[int] = [60, 70, 80, 90, 97]
const TITLES: Array[String] = ["좋은 설계상", "빛나는 설계상", "훌륭한 건축상", "명예 건축가상", "최고 건축 대상"]
const BADGE_ROOT: String = "res://assets/generated/construction-game/"

static func assess(parts: Array[Dictionary], evaluation: Dictionary, contract: Dictionary) -> Dictionary:
	var result: Dictionary = {"version": VERSION, "eligible": false, "score": 0, "tier": 0, "title": "", "breakdown": []}
	if parts.is_empty() or not Document._valid_parts(parts):
		return result
	var facade: Dictionary = Facade.inspect(parts)
	var body: Rect2 = facade.body_bounds
	if not body.has_area():
		return result
	var rows: Array[Dictionary] = []
	var aspect: float = body.size.x / body.size.y
	var proportion: float = minf(aspect / 1.2, 3.6 / aspect)
	rows.append(_row("proportion", "집의 비례", roundi(20.0 * clampf(proportion, 0.0, 1.0)), "외벽 가로÷세로 %.2f · 1.2~3.6이면 20점" % aspect))
	var aperture_area: float = 0.0
	var aperture_center_x: float = 0.0
	var families: Dictionary = {}
	var surfaces: Dictionary = {}
	var roof_bounds: Rect2 = Rect2()
	var has_roof: bool = false
	for part: Dictionary in parts:
		var material: Dictionary = Catalog.material(str(part.material_id))
		var area: float = absf(Math.signed_area(part.vertices))
		families[str(part.kind)] = true
		# Repeated bricks/modules and repeated colors never add variety points.
		var surface: String = "brick" if int(material.get("brick_count", 0)) > 0 else str(material.get("texture_key", material.role))
		if surface.is_empty():
			surface = str(material.role)
		surfaces[surface] = true
		if bool(material.opening):
			aperture_area += area
			aperture_center_x += _centroid_x(Document.world_vertices(part)) * area
		if str(material.role) == "roof":
			var bounds: Rect2 = Math.bounds(Document.world_vertices(part))
			# A spare roof on the ground is not part of the house's eaves.
			if bounds.end.y <= body.position.y + 20.1 and bounds.end.x >= body.position.x and bounds.position.x <= body.end.x:
				roof_bounds = roof_bounds.merge(bounds) if has_roof else bounds
				has_roof = true
	var opening_ratio: float = aperture_area / body.get_area()
	var opening_quality: float = minf(opening_ratio / 0.12, 0.45 / maxf(opening_ratio, 0.0001))
	rows.append(_row("openings", "문과 창의 비율", roundi(20.0 * clampf(opening_quality, 0.0, 1.0)), "문·창 실제 넓이 %.1f%% · 외벽의 12~45%%이면 20점" % (opening_ratio * 100.0)))
	var offset: float = absf(aperture_center_x / aperture_area - body.get_center().x) / body.size.x if aperture_area > 0.0 else 1.0
	var balance: int = roundi(20.0 * clampf(1.0 - maxf(0.0, offset - 0.025) / 0.225, 0.0, 1.0))
	rows.append(_row("balance", "문과 창의 좌우 배치", balance, "문·창 넓이 중심의 치우침 %.1f%% · 가로의 2.5%% 이내이면 20점" % (offset * 100.0)))
	var variety: int = mini(families.size(), 4) * 3 + mini(surfaces.size(), 4) * 2
	rows.append(_row("variety", "도형과 재료의 조합", variety, "고른 도형 %d종 × 3점, 재료 표면 %d종 × 2점 · 각각 최대 4종" % [families.size(), surfaces.size()]))
	var roof_score: int = 0
	var roof_detail: String = "집 위를 덮는 지붕이 필요해요."
	if has_roof:
		var left_eave: float = body.position.x - roof_bounds.position.x
		var right_eave: float = roof_bounds.end.x - body.end.x
		var roof_offset: float = absf(roof_bounds.get_center().x - body.get_center().x)
		var centered: int = roundi(8.0 * clampf(1.0 - roof_offset / maxf(body.size.x * 0.1, 1.0), 0.0, 1.0))
		var eave_quality: float = minf(left_eave, right_eave) / 10.0
		if maxf(left_eave, right_eave) > 80.0:
			eave_quality *= 80.0 / maxf(left_eave, right_eave)
		var eaves: int = roundi(8.0 * clampf(eave_quality, 0.0, 1.0))
		var depth: int = roundi(4.0 * clampf(roof_bounds.size.y / 20.0, 0.0, 1.0))
		roof_score = centered + eaves + depth
		roof_detail = "지붕 중심 8점 · 양쪽 처마 10~80단위 8점 · 지붕 높이 20단위 이상 4점 (평지붕도 가능)"
	rows.append(_row("roof", "지붕과 처마의 마감", roof_score, roof_detail))
	var total: int = 0
	for row: Dictionary in rows:
		total += int(row.score)
	var eligible: bool = Document._integer(contract.get("stage", 0), MINIMUM_STAGE, Catalog.stages().size()) and evaluation.get("can_submit", false) is bool and bool(evaluation.get("can_submit", false)) and bool(facade.complete)
	var tier: int = tier_for_score(total) if eligible else 0
	result.eligible = eligible
	result.score = total
	result.tier = tier
	result.title = title_for_tier(tier)
	result.breakdown = rows
	return result

static func tier_for_score(score: int) -> int:
	var tier: int = 0
	for threshold: int in THRESHOLDS:
		if score >= threshold:
			tier += 1
	return tier

static func title_for_tier(tier: int) -> String:
	return TITLES[tier - 1] if tier >= 1 and tier <= TITLES.size() else ""

static func badge_path(tier: int) -> String:
	return BADGE_ROOT + "badge-%d.png" % tier if tier >= 1 and tier <= 5 else ""

static func is_awarded(award: Dictionary) -> bool:
	if not Document._integer(award.get("version", 0), VERSION, VERSION) or not award.get("eligible", false) is bool or not bool(award.get("eligible", false)):
		return false
	if not Document._integer(award.get("score", -1), 0, 100) or not Document._integer(award.get("tier", 0), 1, 5):
		return false
	var tier: int = int(award.tier)
	return tier_for_score(int(award.score)) == tier and award.get("title", "") == title_for_tier(tier)

static func matches(raw: Variant, parts: Array[Dictionary], evaluation: Dictionary, contract: Dictionary) -> bool:
	if not raw is Dictionary:
		return false
	if raw.size() != 6 or not raw.has_all(["version", "eligible", "score", "tier", "title", "breakdown"]):
		return false
	if not Document._integer(raw.version, VERSION, VERSION) or not raw.eligible is bool or not Document._integer(raw.score, 0, 100) or not Document._integer(raw.tier, 0, 5) or not raw.title is String or not raw.breakdown is Array or raw.breakdown.size() > 5:
		return false
	# JSON numbers restore as floats. Normalize only checked integer fields; do
	# not loosen exact text, boolean, criterion, key or geometry comparisons.
	var checked: Dictionary = raw.duplicate(true)
	checked.version = int(raw.version)
	checked.score = int(raw.score)
	checked.tier = int(raw.tier)
	for index: int in range(raw.breakdown.size()):
		var row: Variant = raw.breakdown[index]
		if not row is Dictionary or row.size() != 5 or not row.has_all(["id", "label", "score", "maximum", "detail"]):
			return false
		if not row.id is String or not row.label is String or not row.detail is String or not Document._integer(row.score, 0, 20) or not Document._integer(row.maximum, 20, 20):
			return false
		checked.breakdown[index].score = int(row.score)
		checked.breakdown[index].maximum = int(row.maximum)
	return checked == assess(parts, evaluation, contract)

static func _row(id: String, label: String, score: int, detail: String) -> Dictionary:
	return {"id": id, "label": label, "score": clampi(score, 0, 20), "maximum": 20, "detail": detail}

static func _centroid_x(vertices: PackedVector2Array) -> float:
	var cross_sum: float = 0.0
	var weighted_x: float = 0.0
	for index: int in range(4):
		var first: Vector2 = vertices[index]
		var second: Vector2 = vertices[(index + 1) % 4]
		var cross: float = first.cross(second)
		cross_sum += cross
		weighted_x += (first.x + second.x) * cross
	return weighted_x / (3.0 * cross_sum) if absf(cross_sum) > 0.0001 else Math.bounds(vertices).get_center().x
