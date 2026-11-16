class_name LearningQuestionBank
extends RefCounted

const Catalog = preload("res://scripts/learning/learning_catalog.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const TYPES: Array[String] = ["lines", "distance", "parallel_sides", "equal_sides", "right_angles"]
const PER_TYPE: int = 20
const GRID_SIZE: Vector2i = Vector2i(10, 6)
const FIGURE_SETS: Dictionary = {
	"trapezoid": [["trapezoid", "general", "rectangle", "parallelogram"], ["general", "trapezoid", "general", "rhombus"], ["square", "rhombus", "general", "trapezoid"], ["general", "rectangle", "general", "general"]],
	"parallelogram": [["parallelogram", "trapezoid", "rectangle", "general"], ["square", "general", "rhombus", "trapezoid"], ["trapezoid", "general", "parallelogram", "trapezoid"], ["rectangle", "square", "trapezoid", "parallelogram"]],
	"rhombus": [["rhombus", "square", "rectangle", "general"], ["trapezoid", "parallelogram", "square", "rectangle"], ["rhombus", "rectangle", "rhombus", "square"], ["general", "rhombus", "parallelogram", "trapezoid"]],
	"rectangle": [["rectangle", "rhombus", "square", "parallelogram"], ["general", "trapezoid", "square", "rhombus"], ["rectangle", "square", "trapezoid", "rectangle"], ["trapezoid", "rectangle", "general", "rhombus"]],
	"square": [["square", "rectangle", "rhombus", "square"], ["general", "trapezoid", "square", "rectangle"], ["square", "rhombus", "square", "parallelogram"], ["rectangle", "square", "rhombus", "trapezoid"]],
}

static func next_index(index: int) -> int:
	return posmod(index + 1, PER_TYPE)

static func question(type_id: String, index: int) -> Dictionary:
	if not TYPES.has(type_id) or index < 0 or index >= PER_TYPE: return {}
	var result: Dictionary = {"id": "%s_%02d" % [type_id, index + 1], "type_id": type_id, "index": index}
	match type_id:
		"lines": return _line_question(result, "perpendicular" if index % 2 == 0 else "parallel", index)
		"distance":
			if index < 12: return _line_question(result, "distance", index)
			return _distance_question(result, index - 12)
		"parallel_sides": return _shape_question(result, "trapezoid" if index % 2 == 0 else "parallelogram", index)
		"equal_sides":
			if index >= 8 and index < 12: return _rhombus_measurement(result, index - 8)
			return _shape_question(result, "rhombus", index)
		_: return _shape_question(result, "rectangle" if index % 2 == 0 else "square", index)

static func _base(result: Dictionary, lesson_id: String, mode: String, prompt: String) -> void:
	var lesson: Dictionary = Catalog.lesson(lesson_id)
	result.merge({"lesson_id": lesson_id, "mode": mode, "title": str(lesson.title), "prompt": prompt, "hint": str(lesson.hint), "rotation": 0.0, "start_value": 0.0})

static func _line_question(result: Dictionary, lesson_id: String, index: int) -> Dictionary:
	var lesson: Dictionary = Catalog.lesson(lesson_id)
	var prompts: Dictionary = {
		"perpendicular": [str(lesson.task), "직각자로 확인할 수 있게 초록 선을 돌려, 검은 선에 대한 수선을 만들어 보세요."],
		"parallel": [str(lesson.task), "짧은 선을 길게 이어도 검은 선과 만나지 않도록 방향을 맞춰 보세요."],
		"distance": [str(lesson.task), "파란 점을 옮겨 두 선 사이의 거리를 바르게 나타내는 선분을 만들어 보세요."],
	}
	var wording: Array = prompts[lesson_id]
	_base(result, lesson_id, "line", str(wording[int(float(index) / 2.0) % wording.size()]))
	result.rotation = float(posmod(index * 11, 31) - 15)
	if lesson_id == "distance":
		result["gap"] = float(60 + 20 * (index % 5))
		result.start_value = float((30 + 10 * (index % 7)) * (1 if index % 2 == 0 else -1))
	else:
		const ANGLES: Array[float] = [35.0, 120.0, 60.0, 145.0, 15.0, 110.0, 155.0, 55.0, 105.0, 40.0]
		result.start_value = ANGLES[int(float(index) / 2.0)]
	return result

static func _distance_question(result: Dictionary, index: int) -> Dictionary:
	const GAPS: Array[int] = [3, 4, 5, 7, 6, 8, 4, 6]
	const OFFSETS: Array[int] = [80, -60, 90, -80, 60, -70, 90, -80]
	var distance_cm: int = GAPS[index]
	var prompt: String = "두 평행선 사이의 거리는 몇 cm인가요?" if index % 2 == 0 else "나란한 두 길의 사이를 가장 짧게 잰 길이를 골라요."
	_base(result, "distance", "measure", prompt)
	result["gap"] = float(distance_cm * 20)
	result.rotation = float(posmod(index * 7, 21) - 10)
	result.start_value = float(OFFSETS[index])
	var slanted: String = Math.measurement_label(Vector2(result.start_value, result.gap).length() / 20.0) + " cm"
	var values: Array[String] = ["%d cm" % distance_cm, slanted]
	for distractor: int in [distance_cm - 1, distance_cm + 1, distance_cm + 2]:
		var label: String = "%d cm" % distractor
		if values.size() < 4 and not values.has(label): values.append(label)
	return _with_choices(result, values, index)

static func _rhombus_measurement(result: Dictionary, index: int) -> Dictionary:
	const SIDES: Array[int] = [4, 7, 5, 6]
	var figure: PackedVector2Array = Math.create_vertices("rhombus", Vector2(130.0 + index * 7.0, 88.0 - index * 4.0))
	var side_cm: int = SIDES[index]
	var scale: float = float(side_cm * 20) / Math.side_lengths(figure)[0]
	var prompt: String = "재어 보기로 확인한 마름모의 한 변은 몇 cm인가요?" if index % 2 == 0 else "마름모의 네 변의 길이를 모두 더하면 몇 cm인가요?"
	_base(result, "rhombus", "measure", prompt)
	result.title = "마름모의 변의 길이"
	result["vertices"] = Math.scale_vertices(figure, scale)
	result.rotation = float(index * 13 - 15)
	var choices: Array[String] = []
	var numbers: Array[int] = []
	if index % 2 == 0: numbers.assign([side_cm, side_cm - 1, side_cm + 1, side_cm * 2])
	else: numbers.assign([side_cm * 4, side_cm * 2, side_cm * 3, side_cm + 4])
	for length: int in numbers: choices.append("%d cm" % length)
	return _with_choices(result, choices, index)

static func _with_choices(result: Dictionary, ordered: Array[String], index: int) -> Dictionary:
	var choices: Array[String] = []
	var offset: int = posmod(index * 3 + 1, ordered.size())
	for slot: int in range(ordered.size()): choices.append(ordered[posmod(slot - offset, ordered.size())])
	result["choices"] = choices
	result["answer_index"] = offset
	return result

static func _shape_question(result: Dictionary, kind: String, index: int) -> Dictionary:
	if index >= 12: return _draw_question(result, kind, index - 12)
	var lesson: Dictionary = Catalog.lesson(kind)
	var prompt: String = str(lesson.task) if index % 3 != 2 else "네 사각형 중 %s인 것을 모두 골라요. 돌려 놓은 도형도 성질을 살펴봐요." % Math.kind_name(kind)
	_base(result, kind, "select", prompt)
	var sets: Array = FIGURE_SETS[kind]
	var set_index: int = int(float(index) / 2.0) + index % 3
	var kinds: Array = sets[set_index % sets.size()]
	var figures: Array[PackedVector2Array] = []
	var correct: Array[int] = []
	var offset: int = posmod(index * 3 + TYPES.find(str(result.type_id)), 4)
	for slot: int in range(4):
		var vertices: PackedVector2Array = _figure(str(kinds[(slot + offset) % 4]), index * 7 + slot * 9)
		figures.append(vertices)
		if Math.matches_kind(vertices, kind): correct.append(slot)
	result["figures"] = figures
	result["correct_choices"] = correct
	return result

static func _figure(kind: String, variant: int) -> PackedVector2Array:
	var width: float = float(100 + variant % 39)
	var height: float = float(59 + variant % 19)
	var vertices: PackedVector2Array
	match kind:
		"general":
			vertices = PackedVector2Array([Vector2(-48, -27), Vector2(48, -44), Vector2(62, 28), Vector2(-35, 46)])
			for index: int in range(vertices.size()):
				vertices[index] *= Vector2(width / 112.0, height / 80.0)
			vertices[1].y -= float(variant % 7)
		"trapezoid": vertices = Math.create_trapezoid_vertices(Vector2(width, height), 0.45 + 0.04 * float(variant % 6), float(variant % 5 - 2) * 0.5)
		"parallelogram": vertices = Math.create_parallelogram_vertices(Vector2(width, height), float(2 + variant % 4) * (0.1 if variant % 2 == 0 else -0.1))
		"square": vertices = Math.create_vertices(kind, Vector2.ONE * float(68 + variant % 24))
		_: vertices = Math.create_vertices(kind, Vector2(width, height))
	return Math.rotate_vertices(vertices, float(posmod(variant * 7, 71) - 35))

static func _draw_question(result: Dictionary, kind: String, index: int) -> Dictionary:
	const VERTEX_COUNTS: Array[int] = [0, 0, 2, 2, 3, 3, 2, 3]
	var count: int = 2 if kind == "rhombus" and index == 1 else VERTEX_COUNTS[index]
	var kind_name: String = Math.kind_name(kind)
	var prompt: String = "격자점 네 곳을 차례로 찍어 %s 모양을 그려요." % kind_name
	if count > 0: prompt = "주어진 선분에 이어 %s 모양을 완성해요." % kind_name
	_base(result, kind, "draw", prompt)
	result.title = "%s 그리기" % kind_name
	result["grid_size"] = GRID_SIZE
	var solution: Array[Vector2i] = _grid_example(kind, index)
	var given: Array[Vector2i] = []
	for vertex: int in range(count): given.append(solution[vertex])
	result["given"] = given
	result["draw_solution"] = solution
	return result

static func _grid_example(kind: String, index: int) -> Array[Vector2i]:
	var width: int = 4 + index % 3
	var height: int = 2 + index % 2
	var points: Array[Vector2i] = [Vector2i.ZERO, Vector2i(width, 0), Vector2i(width, height), Vector2i(0, height)]
	match kind:
		"trapezoid": points[2].x -= 1 + index % 2
		"parallelogram":
			points[2].x += 1 + index % 2
			points[3].x += 1 + index % 2
		"rhombus":
			var half_width: int = 2 + int(index in [1, 3, 6, 7])
			var half_height: int = 1 + (index + 1) % 2
			if half_height == half_width: half_height = 1
			points = [Vector2i(0, half_height), Vector2i(half_width, 0), Vector2i(half_width * 2, half_height), Vector2i(half_width, half_height * 2)]
		"square":
			var side: int = 2 + index % 2
			points = [Vector2i.ZERO, Vector2i(side, 0), Vector2i(side, side), Vector2i(0, side)]
			if index % 4 == 3: points = [Vector2i(0, 2), Vector2i(2, 0), Vector2i(4, 2), Vector2i(2, 4)]
	var solution: Array[Vector2i] = []
	for slot: int in range(4):
		var point: Vector2i = points[(slot + index) % 4] + Vector2i(1 + index % 2, 1 + int(float(index) / 2.0) % 2)
		if index % 2 == 1: point.x = GRID_SIZE.x - point.x
		solution.append(point)
	return solution
