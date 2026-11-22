class_name CustomMaterialCatalog
extends RefCounted

## Versioned recipes are pure values. No registration or mutable catalog state
## is needed to reconstruct a material used by an older completed house.
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const PREFIX: String = "custom_v1"
const MAX_REGISTERED: int = 64
const GRID_AREA: float = 400.0
const SURFACE_IDS: Array[String] = [
	"wood", "brick", "stone", "concrete", "metal",
	"bamboo", "cork", "sandstone", "basalt", "birch", "jade_tile", "terracotta", "reed_thatch",
	"patina_copper", "solar_cell", "sea_glass", "stained_glass", "paper_lattice", "walnut", "shell_mosaic", "rattan"
]
const PATTERN_IDS: Array[String] = ["plain", "bands", "checks", "diamond"]
const ROLE_IDS: Array[String] = ["wall", "roof", "beam", "decor"]
const SURFACES: Dictionary = {
	"wood": {"label": "나무", "texture_key": "cedar", "rate": 2200, "density": 0.8},
	"brick": {"label": "벽돌", "texture_key": "brick", "rate": 1600, "density": 1.3},
	"stone": {"label": "돌", "texture_key": "stone", "rate": 2800, "density": 1.8},
	"concrete": {"label": "콘크리트", "texture_key": "concrete", "rate": 2000, "density": 1.6},
	"metal": {"label": "금속", "texture_key": "metal_roof", "rate": 3600, "density": 1.2},
	"bamboo": {"label": "대나무", "texture_key": "bamboo", "rate": 1800, "density": 0.65},
	"cork": {"label": "코르크", "texture_key": "cork", "rate": 1400, "density": 0.45},
	"sandstone": {"label": "모래돌", "texture_key": "sandstone", "rate": 2300, "density": 1.5},
	"basalt": {"label": "현무암", "texture_key": "basalt", "rate": 3200, "density": 1.9},
	"birch": {"label": "자작나무", "texture_key": "birch", "rate": 2400, "density": 0.75},
	"jade_tile": {"label": "청자 타일", "texture_key": "jade_tile", "rate": 3300, "density": 1.25},
	"terracotta": {"label": "황토 기와", "texture_key": "terracotta", "rate": 1900, "density": 1.15},
	"reed_thatch": {"label": "갈대 이엉", "texture_key": "reed_thatch", "rate": 1200, "density": 0.4},
	"patina_copper": {"label": "녹청 구리", "texture_key": "patina_copper", "rate": 4000, "density": 1.4},
	"solar_cell": {"label": "태양 전지판", "texture_key": "solar_cell", "rate": 4600, "density": 1.1},
	"sea_glass": {"label": "바다 유리", "texture_key": "sea_glass", "rate": 2900, "density": 1.15},
	"stained_glass": {"label": "색유리", "texture_key": "stained_glass", "rate": 3800, "density": 1.2},
	"paper_lattice": {"label": "한지 창살", "texture_key": "paper_lattice", "rate": 1600, "density": 0.5},
	"walnut": {"label": "호두나무", "texture_key": "walnut", "rate": 2700, "density": 0.9},
	"shell_mosaic": {"label": "자개", "texture_key": "shell_mosaic", "rate": 4200, "density": 1.1},
	"rattan": {"label": "등나무 짜임", "texture_key": "rattan", "rate": 1700, "density": 0.6}
}
const PATTERNS: Dictionary = {
	"plain": {"label": "민무늬", "percent": 0},
	"bands": {"label": "줄무늬", "percent": 5},
	"checks": {"label": "격자무늬", "percent": 10},
	"diamond": {"label": "마름모 무늬", "percent": 15}
}
const ROLES: Dictionary = {"wall": "벽체", "roof": "지붕", "beam": "받침보", "decor": "꾸밈판"}
const SHAPE_PERCENT: Dictionary = {"square": 0, "rectangle": 0, "trapezoid": 10, "parallelogram": 10, "rhombus": 15}
const ROLE_PERCENT: Dictionary = {"wall": 0, "roof": 8, "beam": 5, "decor": 12}

static func surface_label(id: String) -> String:
	return str(SURFACES.get(id, {}).get("label", id))

static func pattern_label(id: String) -> String:
	return str(PATTERNS.get(id, {}).get("label", id))

static func role_label(id: String) -> String:
	return str(ROLES.get(id, id))

static func is_custom_id(id: String) -> bool:
	return id.begins_with("custom_")

static func make_id(kind: String, dimensions: Vector2, surface: String, pattern: String, role: String, trapezoid_variant: String = "symmetric") -> String:
	if not Math.KINDS.has(kind) or not SURFACE_IDS.has(surface) or not PATTERN_IDS.has(pattern) or not ROLE_IDS.has(role): return ""
	if not dimensions.is_finite() or dimensions.x < 10.0 or dimensions.x > 600.0 or dimensions.y < 10.0 or dimensions.y > 400.0: return ""
	if dimensions.x != snappedf(dimensions.x, 10.0) or dimensions.y != snappedf(dimensions.y, 10.0): return ""
	if kind == "square" and dimensions.x != dimensions.y: return ""
	if not Math.TRAPEZOID_VARIANTS.has(trapezoid_variant) or (kind != "trapezoid" and trapezoid_variant != "symmetric"): return ""
	var vertices: PackedVector2Array = Math.create_vertices(kind, dimensions, trapezoid_variant)
	if not Math.matches_kind(vertices, kind): return ""
	return "%s:%s:%d:%d:%s:%s:%s:%s" % [PREFIX, kind, int(dimensions.x), int(dimensions.y), surface, pattern, role, trapezoid_variant]

static func _decode(id: String) -> Dictionary:
	if id.length() > 140: return {}
	var fields: PackedStringArray = id.split(":", true)
	if fields.size() != 8 or fields[0] != PREFIX: return {}
	if not fields[2].is_valid_int() or not fields[3].is_valid_int(): return {}
	var width: int = int(fields[2])
	var height: int = int(fields[3])
	if str(width) != fields[2] or str(height) != fields[3]: return {}
	var dimensions: Vector2 = Vector2(width, height)
	if make_id(fields[1], dimensions, fields[4], fields[5], fields[6], fields[7]) != id: return {}
	return {"id": id, "kind": fields[1], "dimensions": dimensions, "surface": fields[4], "pattern": fields[5], "role": fields[6], "trapezoid_variant": fields[7]}

static func _rounded_cost(amount: float) -> int:
	return maxi(0, roundi(amount / 100.0) * 100)

static func _quote(recipe: Dictionary) -> Dictionary:
	var vertices: PackedVector2Array = Math.create_vertices(str(recipe.kind), Vector2(recipe.dimensions), str(recipe.trapezoid_variant))
	var area_cells: float = absf(Math.signed_area(vertices)) / GRID_AREA
	var unit_rate: int = int(SURFACES[str(recipe.surface)].rate)
	var base_cost: int = maxi(100, _rounded_cost(area_cells * float(unit_rate)))
	var shape_fee: int = _rounded_cost(float(base_cost) * float(SHAPE_PERCENT[str(recipe.kind)]) / 100.0)
	var pattern_fee: int = _rounded_cost(float(base_cost) * float(PATTERNS[str(recipe.pattern)].percent) / 100.0)
	var role_fee: int = _rounded_cost(float(base_cost) * float(ROLE_PERCENT[str(recipe.role)]) / 100.0)
	return {"area_cells": area_cells, "unit_rate": unit_rate, "base_cost": base_cost, "shape_fee": shape_fee, "pattern_fee": pattern_fee, "role_fee": role_fee, "total": base_cost + shape_fee + pattern_fee + role_fee}

static func quote(id: String) -> Dictionary:
	var recipe: Dictionary = _decode(id)
	return {} if recipe.is_empty() else _quote(recipe)

static func material(id: String) -> Dictionary:
	var recipe: Dictionary = _decode(id)
	if recipe.is_empty(): return {}
	var estimate: Dictionary = _quote(recipe)
	var surface: Dictionary = SURFACES[str(recipe.surface)]
	var family: String = str(recipe.kind)
	var role: String = str(recipe.role)
	var kinds: Array[String] = [family]
	var shape_label: String = Math.kind_name(family)
	if family == "trapezoid" and str(recipe.trapezoid_variant) != "symmetric":
		shape_label = ("왼쪽 직각 " if str(recipe.trapezoid_variant) == "right_left" else "오른쪽 직각 ") + shape_label
	var label: String = "%s %s %s" % [surface_label(str(recipe.surface)), shape_label, role_label(role)]
	return {
		"id": id, "label": label, "kind": family, "kinds": kinds, "dimensions": Vector2(recipe.dimensions),
		"role": role, "structural": role != "decor", "opening": false, "brick_count": 0,
		"price": int(estimate.total), "mass": float(estimate.area_cells) * float(surface.density),
		"custom": true, "surface_id": str(recipe.surface), "pattern_id": str(recipe.pattern), "texture_key": str(surface.texture_key),
		"trapezoid_variant": str(recipe.trapezoid_variant), "color": Color("d5b889"), "unit": "맞춤 재료 1개",
		"description": "%s · %s. 가로·세로는 그림 속 칸으로 재어요. 등록은 무료이며 배치한 개수만큼 재료비를 계산해요." % [label, pattern_label(str(recipe.pattern))],
		"source_url": "", "source_note": "게임용 가상 단가에 실제 도형 넓이와 모양 가공·무늬·용도 비용을 더한 추정가예요. 각 항목은 100원 단위로 반올림하며 실제 판매가가 아니에요."
	}

static func short_label(id: String) -> String:
	var item: Dictionary = material(id)
	return str(item.get("label", ""))
