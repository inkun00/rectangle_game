class_name SpaceshipCatalog
extends RefCounted

const Math: GDScript = preload("res://scripts/core/quadrilateral_math.gd")
const PART_COUNT: int = 12
const VARIANT_COUNT: int = 3
const MIN_TOTAL_PRICE: int = 1200000000
const MAX_TOTAL_PRICE: int = 1800000000
const TIER_NAMES: Array[String] = ["기본형", "강화형", "최고급형"]
const _SUFFIXES: Array[String] = ["", "_advanced", "_elite"]
const _PALETTES: Array[String] = ["dce3e8", "58bbd1", "ebb374"]
const _PRICE_PERCENT: Array[int] = [100, 120, 150]

## Trapezoid profiles are the short-to-long base ratio and signed offset.
const _TRAPEZOID_PROFILES: Dictionary = {
	"hull_elite": Vector2(0.68, 0.22),
	"nose": Vector2(0.55, 0.0), "nose_advanced": Vector2(0.36, -0.36),
	"window_advanced": Vector2(0.83, 1.0),
	"left_wing_advanced": Vector2(0.54, -0.58), "right_wing_advanced": Vector2(0.54, 0.58),
	"left_tank_elite": Vector2(0.63, -0.75), "right_tank_elite": Vector2(0.63, 0.75),
	"engine_elite": Vector2(0.71, 0.0), "nozzle_advanced": Vector2(0.49, -0.66),
	"shield_elite": Vector2(0.38, 0.45),
}
const _PARALLELOGRAM_LEANS: Dictionary = {
	"left_wing": -0.23, "right_wing": 0.23,
	"left_wing_elite": -0.35, "right_wing_elite": 0.35,
	"left_tank_advanced": -0.18, "right_tank_advanced": 0.18,
	"shield_advanced": 0.12,
}
const _ANGLES: Dictionary = {
	"window": -4.0, "window_advanced": 6.0, "window_elite": -8.0,
	"left_wing": -14.0, "right_wing": 14.0,
	"left_wing_advanced": -76.0, "right_wing_advanced": 76.0,
	"left_wing_elite": -24.0, "right_wing_elite": 24.0,
	"left_tank_advanced": -8.0, "right_tank_advanced": 8.0,
	"left_tank_elite": 172.0, "right_tank_elite": 188.0,
	"engine_elite": 180.0, "nozzle_advanced": 180.0,
	"core_advanced": 18.0, "core_elite": -14.0,
	"navigation_advanced": 22.0, "navigation_elite": -16.0,
	"shield_advanced": -6.0, "shield_elite": 90.0,
}

## Atlas order is row-major, four columns by three rows. All variants share
## their slot's mount so they can be combined with any tier from another slot.
const _SLOTS: Array[Dictionary] = [
	{
		"id": "hull", "name": "몸체", "description": "탑승 공간과 우주선의 뼈대를 지켜요.",
		"price": 20000000, "position": Vector2(0, 0), "layer": 4,
		"names": ["은빛 선체", "청옥 광폭 선체", "황금 장갑 선체"],
		"kinds": ["rectangle", "rectangle", "trapezoid"], "sizes": [Vector2(150, 224), Vector2(168, 235), Vector2(194, 248)],
	},
	{
		"id": "nose", "name": "기수", "description": "앞쪽에서 우주 먼지를 가르고 길을 열어요.",
		"price": 30000000, "position": Vector2(0, -130), "layer": 3,
		"names": ["유선형 기수", "푸른 쐐기 기수", "황금 다이아 기수"],
		"kinds": ["trapezoid", "trapezoid", "rhombus"], "sizes": [Vector2(150, 90), Vector2(176, 106), Vector2(188, 144)],
	},
	{
		"id": "window", "name": "조종석", "description": "별빛 항로를 살피는 창이에요.",
		"price": 40000000, "position": Vector2(0, -39), "layer": 8,
		"names": ["기본 유리 조종석", "광각 청록 조종석", "다이아 전망 조종석"],
		"kinds": ["rectangle", "trapezoid", "rhombus"], "sizes": [Vector2(86, 62), Vector2(105, 76), Vector2(130, 97)],
	},
	{
		"id": "left_wing", "name": "왼쪽 날개", "description": "왼쪽으로 기울어질 때 균형을 잡아요.",
		"price": 50000000, "position": Vector2(-92, 53), "layer": 0,
		"names": ["왼쪽 은빛 균형 날개", "왼쪽 해류 날개", "왼쪽 황금 대형 날개"],
		"kinds": ["parallelogram", "trapezoid", "parallelogram"], "sizes": [Vector2(110, 148), Vector2(168, 140), Vector2(168, 184)],
	},
	{
		"id": "right_wing", "name": "오른쪽 날개", "description": "오른쪽으로 기울어질 때 균형을 잡아요.",
		"price": 60000000, "position": Vector2(92, 53), "layer": 1,
		"names": ["오른쪽 은빛 균형 날개", "오른쪽 해류 날개", "오른쪽 황금 대형 날개"],
		"kinds": ["parallelogram", "trapezoid", "parallelogram"], "sizes": [Vector2(110, 148), Vector2(168, 140), Vector2(168, 184)],
	},
	{
		"id": "left_tank", "name": "왼쪽 연료통", "description": "멀리 날아갈 연료를 왼쪽에 보관해요.",
		"price": 70000000, "position": Vector2(-81, -37), "layer": 2,
		"names": ["왼쪽 은빛 연료통", "왼쪽 청록 고압통", "왼쪽 황금 대용량통"],
		"kinds": ["rectangle", "parallelogram", "trapezoid"], "sizes": [Vector2(50, 128), Vector2(65, 150), Vector2(83, 171)],
	},
	{
		"id": "right_tank", "name": "오른쪽 연료통", "description": "멀리 날아갈 연료를 오른쪽에 보관해요.",
		"price": 90000000, "position": Vector2(81, -37), "layer": 2,
		"names": ["오른쪽 은빛 연료통", "오른쪽 청록 고압통", "오른쪽 황금 대용량통"],
		"kinds": ["rectangle", "parallelogram", "trapezoid"], "sizes": [Vector2(50, 128), Vector2(65, 150), Vector2(83, 171)],
	},
	{
		"id": "engine", "name": "추진기", "description": "연료의 힘으로 우주선을 앞으로 움직여요.",
		"price": 110000000, "position": Vector2(0, 133), "layer": 5,
		"names": ["정사각 추진기", "청옥 강력 추진기", "황금 대형 추진기"],
		"kinds": ["square", "rectangle", "trapezoid"], "sizes": [Vector2(92, 92), Vector2(124, 103), Vector2(150, 121)],
	},
	{
		"id": "nozzle", "name": "분사구", "description": "추진기에서 나온 기체를 뒤로 내보내요.",
		"price": 130000000, "position": Vector2(0, 184), "layer": 6,
		"names": ["은빛 분사구", "청옥 확장 분사구", "황금 고출력 분사구"],
		"kinds": ["rectangle", "trapezoid", "rectangle"], "sizes": [Vector2(104, 39), Vector2(128, 52), Vector2(151, 59)],
	},
	{
		"id": "core", "name": "에너지 핵", "description": "조종 장치가 쓸 에너지를 모아 둬요.",
		"price": 160000000, "position": Vector2(0, 45), "layer": 9,
		"names": ["마름모 에너지 핵", "청옥 사각 에너지 핵", "황금 대용량 에너지 핵"],
		"kinds": ["rhombus", "square", "rhombus"], "sizes": [Vector2(42, 57), Vector2(56, 56), Vector2(73, 82)],
	},
	{
		"id": "navigation", "name": "항법 장치", "description": "사각성으로 가는 길을 찾아요.",
		"price": 200000000, "position": Vector2(0, -123), "layer": 10,
		"names": ["기본 사각성 항법 장치", "청옥 별지도 장치", "황금 정밀 항법 장치"],
		"kinds": ["square", "rhombus", "square"], "sizes": [Vector2(32, 32), Vector2(42, 49), Vector2(48, 48)],
	},
	{
		"id": "shield", "name": "보호 장치", "description": "작은 운석과 우주 먼지로부터 우주선을 지켜요.",
		"price": 240000000, "position": Vector2(0, 93), "layer": 11,
		"names": ["은빛 보호판", "청옥 충격 흡수판", "황금 장갑 보호판"],
		"kinds": ["rectangle", "parallelogram", "trapezoid"], "sizes": [Vector2(128, 24), Vector2(152, 29), Vector2(37, 176)],
	},
]

static var _parts: Dictionary = {}

## The base product IDs are also the required slot IDs. Keeping them stable
## preserves all previously paid purchases and their exact prices.
static func all_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: Dictionary in _SLOTS:
		result.append(part(str(slot.id)))
	return result

static func part(id: String) -> Dictionary:
	_ensure_parts()
	var item: Dictionary = _parts.get(id, {})
	return item.duplicate(true)

static func variants(slot_id: String) -> Array[Dictionary]:
	if part(slot_id).get("tier", -1) != 0: return []
	var result: Array[Dictionary] = []
	for suffix: String in _SUFFIXES:
		result.append(part(slot_id + suffix))
	return result

static func installed_parts(owned_ids: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in owned_ids:
		var item: Dictionary = part(id)
		if not item.is_empty(): result.append(item)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.layer) < int(b.layer))
	return result

static func _ensure_parts() -> void:
	if not _parts.is_empty(): return
	for slot_index: int in range(_SLOTS.size()):
		var slot: Dictionary = _SLOTS[slot_index]
		var slot_id: String = str(slot.id)
		for tier: int in range(VARIANT_COUNT):
			var id: String = slot_id + _SUFFIXES[tier]
			var kind: String = str(slot.kinds[tier])
			var dimensions: Vector2 = slot.sizes[tier]
			var angle: float = float(_ANGLES.get(id, 0.0))
			var vertices: PackedVector2Array
			if kind == "trapezoid":
				var profile: Vector2 = _TRAPEZOID_PROFILES[id]
				vertices = Math.create_trapezoid_vertices(dimensions, profile.x, profile.y)
			elif kind == "parallelogram":
				vertices = Math.create_parallelogram_vertices(dimensions, float(_PARALLELOGRAM_LEANS[id]))
			else:
				vertices = Math.create_vertices(kind, dimensions)
			if not is_zero_approx(angle): vertices = Math.rotate_vertices(vertices, angle)
			var price: int = roundi(int(slot.price) * _PRICE_PERCENT[tier] / 100.0)
			_parts[id] = {
				"id": id, "slot_id": slot_id, "slot_index": slot_index, "slot_name": slot.name,
				"tier": tier, "name": slot.names[tier], "description": slot.description,
				"kind": kind, "vertices": vertices, "position": slot.position,
				"dimensions": dimensions, "angle": angle, "layer": slot.layer,
				"price": price, "performance": tier + 1, "color": Color(_PALETTES[tier]),
			}

static func _valid_legacy_selection(kind: Variant, color: Variant) -> bool:
	if not kind is String or not Math.KINDS.has(kind) or not color is String or color.length() != 6:
		return false
	for character: String in color:
		if not "0123456789abcdef".contains(character): return false
	return true

static func validate_design(design: Variant, owned: Array[String]) -> bool:
	if not design is Dictionary or design.size() > PART_COUNT: return false
	for id: Variant in design:
		if not id is String or not owned.has(id) or part(id).get("tier") != 0: return false
		var selection: Variant = design[id]
		if not selection is Dictionary or selection.size() != 2 or not _valid_legacy_selection(selection.get("kind"), selection.get("color")):
			return false
	return true

static func total_price() -> int:
	return MIN_TOTAL_PRICE
