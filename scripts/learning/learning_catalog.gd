class_name LearningCatalog
extends RefCounted

## Original activities aligned to Han Daehee 4-2, unit 4, pp. 198-251.
## Teacher background about inclusion is not a pupil memorisation objective.
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const IDS: Array[String] = ["perpendicular", "parallel", "distance", "trapezoid", "parallelogram", "rhombus", "rectangle", "square"]

static func lesson(id: String) -> Dictionary:
	var entries: Dictionary = {
		"perpendicular": {"title": "수직과 수선", "pages": "216~219", "goal": "주어진 직선에 수직인 선을 그어요.", "task": "파란 점을 움직여 두 직선이 직각으로 만나게 해 보세요.", "reason": "두 직선이 만나 이루는 각이 직각이에요.", "wrong": ["두 선의 길이가 같아요.", "한 선이 꼭 가로로 놓여 있어요."], "hint": "길이나 방향보다 만나는 각을 살펴봐요. 직각은 90°예요."},
		"parallel": {"title": "평행과 평행선", "pages": "220~223", "goal": "주어진 직선과 평행한 선을 그어요.", "task": "파란 점을 움직여 두 직선이 같은 방향으로 나아가게 해 보세요.", "reason": "같은 평면에서 두 직선이 아무리 늘어나도 만나지 않아요.", "wrong": ["화면 안에서만 만나지 않으면 돼요.", "보이는 두 선의 길이가 같아야 해요."], "hint": "보이는 선의 길이가 달라도 괜찮아요. 같은 수선과 만나는 두 각이 모두 직각인지 확인해요."},
		"distance": {"title": "평행선 사이의 거리", "pages": "224~227", "goal": "수직인 선분으로 평행선 사이의 거리를 재어요.", "task": "파란 점을 옮겨 여러 선분을 비교하고 가장 짧은 선분을 찾아보세요.", "reason": "두 평행선에 수직인 선분의 길이로 재어요.", "wrong": ["비스듬한 선분이 더 길어서 거리예요.", "선분 두 개의 길이를 더해요."], "hint": "수직인 선분과 비스듬한 선분의 길이를 비교해요. 수직으로 재면 위치가 달라도 거리는 같아요."},
		"trapezoid": {"title": "사다리꼴 찾기", "pages": "228~231", "goal": "평행한 변이 있는 사각형을 찾아요.", "task": "평행한 변이 있는 사각형을 모두 골라 보세요.", "reason": "평행한 변이 있는 사각형이에요.", "wrong": ["평행한 변은 꼭 한 쌍만 있어야 해요.", "위쪽 변이 짧아 보이면 언제나 맞아요."], "hint": "마주 보는 변을 확인해요. 평행한 변이 한 쌍이든 두 쌍이든 조건에 맞아요."},
		"parallelogram": {"title": "평행사변형 찾기", "pages": "232~235", "goal": "마주 보는 두 쌍의 변이 평행한지 확인해요.", "task": "마주 보는 두 쌍의 변이 평행한 사각형을 모두 골라요.", "reason": "마주 보는 두 쌍의 변이 서로 평행해요.", "wrong": ["평행한 변이 한 쌍만 있으면 돼요.", "기울어진 모양이면 언제나 맞아요."], "hint": "한 쌍을 찾은 뒤 다른 한 쌍도 확인해요. 기울어진 정도로 판단하지 않아요."},
		"rhombus": {"title": "마름모 찾기", "pages": "236~239", "goal": "네 변의 길이를 재고 같은지 확인해요.", "task": "네 변의 길이가 모두 같은 사각형을 모두 골라요.", "reason": "네 변의 길이가 모두 같아요.", "wrong": ["꼭짓점 하나가 위를 향하면 돼요.", "마주 보는 두 변만 같으면 돼요."], "hint": "다이아몬드처럼 보이는지보다 네 변의 길이를 비교해요. 네 변을 모두 확인해야 해요."},
		"rectangle": {"title": "직사각형 찾기", "pages": "240~243", "goal": "네 각이 모두 직각인지 확인해요.", "task": "네 각이 모두 직각인 사각형을 모두 골라요.", "reason": "네 각이 모두 직각이에요.", "wrong": ["반드시 가로로 길쭉해야 해요.", "네 변의 길이만 같으면 돼요."], "hint": "돌려 놓은 도형도 각을 확인해요. 길쭉한 정도는 조건이 아니에요."},
		"square": {"title": "정사각형 찾기", "pages": "240~243", "goal": "같은 네 변과 네 직각을 함께 확인해요.", "task": "네 변의 길이가 같고 네 각이 모두 직각인 사각형을 모두 골라요.", "reason": "네 변의 길이가 같고 네 각이 모두 직각이에요.", "wrong": ["네 변의 길이만 같으면 돼요.", "네 각이 직각이기만 하면 돼요."], "hint": "변의 길이와 각의 크기, 두 가지를 함께 확인해요. 돌려도 이 성질은 그대로예요."}
	}
	var result: Dictionary = entries.get(id, {}).duplicate(true)
	if not result.is_empty(): result.id = id
	return result

static func figures(id: String) -> Array[PackedVector2Array]:
	var general: PackedVector2Array = PackedVector2Array([Vector2(-70, -48), Vector2(48, -62), Vector2(83, 46), Vector2(-56, 65)])
	var right_trapezoid: PackedVector2Array = PackedVector2Array([Vector2(-75, -48), Vector2(30, -48), Vector2(75, 48), Vector2(-75, 48)])
	var rectangle: PackedVector2Array = Math.rotate_vertices(Math.create_vertices("rectangle", Vector2(130, 76)), 26.0)
	var square: PackedVector2Array = Math.rotate_vertices(Math.create_vertices("square", Vector2(100, 100)), 32.0)
	var rhombus: PackedVector2Array = Math.rotate_vertices(Math.create_vertices("rhombus", Vector2(145, 85)), -18.0)
	var parallelogram: PackedVector2Array = Math.rotate_vertices(Math.create_vertices("parallelogram", Vector2(140, 85)), -14.0)
	match id:
		"trapezoid": return [right_trapezoid, general, rectangle, parallelogram]
		"parallelogram": return [parallelogram, right_trapezoid, rectangle, general]
		"rhombus": return [rhombus, square, rectangle, general]
		"rectangle": return [rectangle, rhombus, square, parallelogram]
		_: return [Math.create_vertices("square", Vector2(100, 100)), square, rectangle, rhombus]

static func correct_choices(id: String) -> Array[int]:
	var result: Array[int] = []
	var examples: Array[PackedVector2Array] = figures(id)
	for index: int in range(examples.size()):
		if Math.matches_kind(examples[index], id): result.append(index)
	return result

static func options(id: String) -> Array[String]:
	var entry: Dictionary = lesson(id)
	return [str(entry.reason), str(entry.wrong[0]), str(entry.wrong[1])]

static func quest_topic(id: String) -> String:
	return str({"rhombus_chocolates": "rhombus", "square_puppy": "square", "trapezoid_roofs": "trapezoid", "parallelogram_bridge": "parallelogram", "rectangle_library": "rectangle", "parallel_rails": "distance", "right_angle_sign": "perpendicular", "square_festival": "square", "harbor_sails": "trapezoid", "harbor_crates": "rectangle", "snow_lanterns": "rhombus", "snow_tracks": "distance", "snow_windows": "square", "citadel_banners": "parallelogram", "citadel_seals": "rectangle", "starlight_core": "square"}.get(id, "square"))
