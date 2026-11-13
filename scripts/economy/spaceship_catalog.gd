class_name SpaceshipCatalog
extends RefCounted

const Math: GDScript = preload("res://scripts/core/quadrilateral_math.gd")
const PART_COUNT: int = 12

## Each purchased item is exactly one four-vertex component. Catalog results are
## fresh copies; the launch renderer only transforms copies of these vertices.
static func all_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append(_part("hull", "귀향선 몸체", "기본 뼈대와 생활 공간을 지켜 주는 몸체예요.", "rectangle", Vector2(140, 210), Vector2.ZERO, "f6e8c5", 20000000, 4))
	result.append(_part("nose", "귀향선 기수", "우주선의 앞모양을 만드는 부품이에요.", "trapezoid", Vector2(140, 80), Vector2(0, -145), "ed9b66", 30000000, 3))
	result.append(_part("window", "별빛 조종석", "창을 통해 별빛 항로를 살펴봐요.", "rectangle", Vector2(92, 70), Vector2(0, -42), "6bddcf", 40000000, 8))
	result.append(_part("left_wing", "왼쪽 균형 날개", "왼쪽 날개의 모양과 색을 골라 보세요.", "parallelogram", Vector2(92, 140), Vector2(-107, 58), "4598b6", 50000000, 0, -18.0))
	result.append(_part("right_wing", "오른쪽 균형 날개", "반대쪽 날개와 힘을 맞춰 안정되게 날아가요.", "parallelogram", Vector2(92, 140), Vector2(107, 58), "55b8b2", 60000000, 0, 18.0))
	result.append(_part("left_tank", "왼쪽 연료통", "먼 우주까지 갈 연료를 담는 통이에요.", "rectangle", Vector2(44, 126), Vector2(-99, -42), "849bbd", 70000000, 2))
	result.append(_part("right_tank", "오른쪽 연료통", "고향까지 돌아갈 에너지를 넉넉하게 실어요.", "rectangle", Vector2(44, 126), Vector2(99, -42), "849bbd", 90000000, 2))
	result.append(_part("engine", "별빛 추진기", "별 사이를 날아갈 힘을 내는 부품이에요.", "square", Vector2(88, 88), Vector2(0, 147), "e3a14c", 110000000, 5))
	result.append(_part("nozzle", "주 추진 분사구", "우주선을 밀어 올릴 힘이 나오는 부품이에요.", "rectangle", Vector2(108, 38), Vector2(0, 205), "ab7358", 130000000, 6))
	result.append(_part("core", "희망의 에너지 핵", "희망의 에너지를 모으는 부품이에요.", "rhombus", Vector2(44, 62), Vector2(0, 51), "ffd279", 160000000, 9))
	result.append(_part("navigation", "고향 항법 장치", "사각형 행성으로 가는 길을 찾는 장치예요.", "square", Vector2(38, 38), Vector2(0, -139), "a7f0df", 200000000, 10))
	result.append(_part("shield", "귀향 보호 장치", "소중한 우주선을 안전하게 지켜 주는 장치예요.", "rectangle", Vector2(134, 22), Vector2(0, 96), "d88a72", 240000000, 11))
	return result

static func part(id: String) -> Dictionary:
	for item: Dictionary in all_parts():
		if str(item.id) == id: return item
	return {}

static func valid_selection(kind: Variant, color: Variant) -> bool:
	if not kind is String or not Math.KINDS.has(kind) or not color is String or color.length() != 6:
		return false
	for character: String in color:
		if not "0123456789abcdef".contains(character): return false
	return true

static func validate_design(design: Variant, owned: Array[String]) -> bool:
	if not design is Dictionary or design.size() > PART_COUNT: return false
	for id: Variant in design:
		if not id is String or not owned.has(id) or part(id).is_empty(): return false
		var selection: Variant = design[id]
		if not selection is Dictionary or selection.size() != 2 or not valid_selection(selection.get("kind"), selection.get("color")):
			return false
	return true

## Shape choices are catalog recipes. Only the resulting four vertices and
## the catalog position determine what the renderer draws.
static func configured_parts(design: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = all_parts()
	for item: Dictionary in result:
		var selection: Dictionary = design.get(item.id, {})
		if selection.is_empty(): continue
		var kind: String = str(selection.kind)
		item.color = Color(str(selection.color))
		if kind == item.kind: continue
		var dimensions: Vector2 = item.dimensions
		if kind == "square":
			# The hull and tanks retain their height when switched to squares.
			var side: float = maxf(dimensions.x, dimensions.y) if item.id in ["hull", "left_tank", "right_tank"] else minf(dimensions.x, dimensions.y)
			dimensions = Vector2(side, side)
		elif kind == "rectangle" and is_equal_approx(dimensions.x, dimensions.y):
			dimensions.x *= 0.72
		var vertices: PackedVector2Array = Math.create_vertices(kind, dimensions)
		item.kind = kind
		item.vertices = Math.rotate_vertices(vertices, float(item.angle)) if not is_zero_approx(float(item.angle)) else vertices
	return result

static func total_price() -> int:
	var total: int = 0
	for item: Dictionary in all_parts(): total += int(item.price)
	return total

static func _part(id: String, label: String, description: String, kind: String, dimensions: Vector2, position: Vector2, color: String, price: int, layer: int, angle: float = 0.0) -> Dictionary:
	var vertices: PackedVector2Array = Math.create_vertices(kind, dimensions)
	if angle != 0.0: vertices = Math.rotate_vertices(vertices, angle)
	return {"id": id, "name": label, "description": description, "kind": kind, "vertices": vertices, "position": position, "color": Color(color), "price": price, "layer": layer, "dimensions": dimensions, "angle": angle}
