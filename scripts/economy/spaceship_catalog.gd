class_name SpaceshipCatalog
extends RefCounted

const Math: GDScript = preload("res://scripts/core/quadrilateral_math.gd")
const PART_COUNT: int = 12

## Each purchased item is exactly one four-vertex component. Catalog results are
## fresh copies; the launch renderer only transforms copies of these vertices.
static func all_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append(_part("hull", "귀향선 몸체", "기본 뼈대와 생활 공간을 지켜 주는 몸체예요.", "rectangle", Vector2(140, 210), Vector2.ZERO, "f6e8c5", 20000000, 4))
	result.append(_part("nose", "사다리꼴 기수", "평행한 두 변이 있는 기수로 우주선 앞을 완성해요.", "trapezoid", Vector2(140, 80), Vector2(0, -145), "ed9b66", 30000000, 3))
	result.append(_part("window", "별빛 조종석", "네 각이 직각인 창으로 별빛 항로를 살펴봐요.", "rectangle", Vector2(92, 70), Vector2(0, -42), "6bddcf", 40000000, 8))
	result.append(_part("left_wing", "왼쪽 균형 날개", "마주 보는 두 쌍의 변이 평행한 날개예요.", "parallelogram", Vector2(92, 140), Vector2(-107, 58), "4598b6", 50000000, 0, -18.0))
	result.append(_part("right_wing", "오른쪽 균형 날개", "반대쪽 날개와 힘을 맞춰 안정되게 날아가요.", "parallelogram", Vector2(92, 140), Vector2(107, 58), "55b8b2", 60000000, 0, 18.0))
	result.append(_part("left_tank", "왼쪽 연료통", "먼 우주까지 갈 연료를 담는 직사각형 통이에요.", "rectangle", Vector2(44, 126), Vector2(-99, -42), "849bbd", 70000000, 2))
	result.append(_part("right_tank", "오른쪽 연료통", "고향까지 돌아갈 에너지를 넉넉하게 실어요.", "rectangle", Vector2(44, 126), Vector2(99, -42), "849bbd", 90000000, 2))
	result.append(_part("engine", "정사각형 추진기", "네 변이 같고 네 각이 직각인 강력한 추진기예요.", "square", Vector2(88, 88), Vector2(0, 147), "e3a14c", 110000000, 5))
	result.append(_part("nozzle", "주 추진 분사구", "우주선을 밀어 올릴 힘이 나오는 직사각형 부품이에요.", "rectangle", Vector2(108, 38), Vector2(0, 205), "ab7358", 130000000, 6))
	result.append(_part("core", "마름모 에너지 핵", "네 변의 길이가 같은 마름모에 희망의 에너지를 모아요.", "rhombus", Vector2(44, 62), Vector2(0, 51), "ffd279", 160000000, 9))
	result.append(_part("navigation", "고향 항법 장치", "작은 정사각형 장치가 사각형 행성으로 가는 길을 찾아요.", "square", Vector2(38, 38), Vector2(0, -139), "a7f0df", 200000000, 10))
	result.append(_part("shield", "귀향 보호 장치", "마지막 직사각형 부품! 소중한 우주선을 안전하게 지켜요.", "rectangle", Vector2(134, 22), Vector2(0, 96), "d88a72", 240000000, 11))
	return result

static func part(id: String) -> Dictionary:
	for item: Dictionary in all_parts():
		if str(item.id) == id: return item
	return {}

static func total_price() -> int:
	var total: int = 0
	for item: Dictionary in all_parts(): total += int(item.price)
	return total

static func _part(id: String, label: String, description: String, kind: String, dimensions: Vector2, position: Vector2, color: String, price: int, layer: int, angle: float = 0.0) -> Dictionary:
	var vertices: PackedVector2Array = Math.create_vertices(kind, dimensions)
	if angle != 0.0: vertices = Math.rotate_vertices(vertices, angle)
	return {"id": id, "name": label, "description": description, "kind": kind, "vertices": vertices, "position": position, "color": Color(color), "price": price, "layer": layer}
