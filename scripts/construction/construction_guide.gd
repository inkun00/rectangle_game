class_name ConstructionGuide
extends RefCounted

## Optional first-house example. This does not score, purchase, or alter a design.
## The caller decides whether to show the guide for the current commission.
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const MATCH_TOLERANCE: float = 0.01

static func plan() -> Array[Dictionary]:
	var steps: Array[Dictionary] = [
		_step("door", Vector2(500, 500), "먼저 문을 바닥에 놓아요. 드나들 자리를 비워 두어요."),
		_step("window", Vector2(340, 480), "정사각형 창문의 자리를 잡아요. 이 안에는 벽돌을 놓지 않아요.")
	]
	for x: float in [240.0, 600.0]:
		steps.append(_step("wall", Vector2(x, 530), "양옆 벽의 첫 묶음을 땅에 닿게 놓아요."))
	for x: float in [320.0, 360.0, 400.0, 440.0]:
		steps.append(_step("brick", Vector2(x, 550), "바닥부터 벽돌을 쌓아 창문과 가운데 벽을 받쳐요."))
	for x: float in [320.0, 360.0, 400.0, 440.0]:
		steps.append(_step("brick", Vector2(x, 530), "아래 벽돌 위에 한 장을 더 올려 빈틈을 채워요."))
	for x: float in [400.0, 440.0]:
		steps.append(_step("brick", Vector2(x, 510), "창문과 문 사이의 벽을 밑에서부터 올려요."))
	for x: float in [240.0, 600.0]:
		steps.append(_step("wall", Vector2(x, 470), "양옆 벽을 한 묶음 더 높여요. 아래 벽에 맞닿게 놓아요."))
	for y: float in [490.0, 470.0, 450.0]:
		for x: float in [400.0, 440.0]:
			steps.append(_step("brick", Vector2(x, y), "문과 창문 옆을 채워 위에 올릴 보를 받쳐요."))
	for x: float in [240.0, 360.0, 480.0, 600.0]:
		steps.append(_step("lintel", Vector2(x, 430), "벽 위에 받침보를 빈틈없이 이어요. 문과 창 위를 지나 양쪽 처마 아래까지 채워요."))
	steps.append(_step("roof_flat_wide", Vector2(420, 400), "마지막으로 넓고 평평한 직사각형 지붕을 올려요. 이제 안전 검사로 확인해요."))
	return steps

## A feasible study for each offer, made only from purchased catalog parts.
## Extra shapes decorate solid wall surfaces; a flat main roof shelters every
## opening, so learning a new family never requires a sloping roof solution.
static func example_for_contract(offer: Dictionary) -> Array[Dictionary]:
	var stage: int = int(offer.get("stage", 1))
	var windows: int = 1 if stage == 1 else (3 if stage >= 5 else 2)
	var openings: int = windows + 1
	var width: float = 120.0 * openings + 120.0
	var left: float = 500.0 - width * 0.5
	var items: Array[Dictionary] = []
	var apertures: Array[Rect2] = []
	for column: int in range(openings):
		var x: float = left + 120.0 + 120.0 * column
		var door: bool = column == 1
		items.append(_step("door" if door else "window", Vector2(x, 500 if door else 480), "문과 창문의 빈자리를 잡아요."))
		apertures.append(Rect2(x - 40.0, 440.0, 80.0, 120.0 if door else 80.0))
	for row: int in range(6):
		for column: int in range(roundi(width / 40.0)):
			var point: Vector2 = Vector2(left + 20.0 + column * 40.0, 450.0 + row * 20.0)
			var reserved: bool = false
			for aperture: Rect2 in apertures:
				if aperture.has_point(point): reserved = true
			if not reserved: items.append(_step("brick", point, "빈자리를 남기고 벽을 쌓아요."))
	for column: int in range(roundi(width / 120.0)):
		items.append(_step("lintel", Vector2(left + 60.0 + column * 120.0, 430), "벽 위를 길쭉한 나무로 이어요."))
	if width <= 520.0:
		items.append(_step("roof_flat_wide", Vector2(500, 400), "평평한 지붕으로 집 앞면 전체를 덮어요."))
	else:
		for column: int in range(3): items.append(_step("roof_flat", Vector2(left + 100.0 + column * 200.0, 400), "평평한 지붕을 이어 넓은 집을 덮어요."))
	var preferred: String = str(offer.get("preferred_roof_kind", "rectangle"))
	if preferred == "square": items.append(_step("roof_square", Vector2(500, 340), "정사각형 지붕판을 위에 더해요."))
	elif preferred == "trapezoid": items.append(_step("roof", Vector2(500, 350), "사다리꼴 지붕으로 위쪽을 꾸며요."))
	elif preferred == "parallelogram": items.append(_step("roof_parallelogram", Vector2(500, 350), "평행사변형 지붕으로 위쪽을 꾸며요."))
	if stage >= 2: items.append(_step("panel_trapezoid", Vector2(left + 40.0, 480), "벽에 사다리꼴 꾸밈판을 붙여요."))
	if stage >= 3: items.append(_step("panel", Vector2(left + 40.0, 540), "벽 아래에 평행사변형 꾸밈판을 붙여요."))
	if stage >= 4: items.append(_step("ornament", Vector2(left + width - 40.0, 480), "반대편 벽에 마름모 꾸밈을 붙여요."))
	return items

static func next_step(document: ConstructionDocument) -> Dictionary:
	if document == null:
		return {}
	var steps: Array[Dictionary] = plan()
	for index: int in range(steps.size()):
		var step: Dictionary = steps[index]
		var material: Dictionary = Catalog.material(str(step.material_id))
		var vertices: PackedVector2Array = Math.create_vertices(str(material.kind), Vector2(material.dimensions))
		var found: bool = false
		for part: Dictionary in document.parts:
			if str(part.material_id) != str(step.material_id):
				continue
			if Vector2(part.position).distance_to(Vector2(step.position)) > MATCH_TOLERANCE:
				continue
			if _same_outline(part.vertices, vertices):
				found = true
				break
		if not found:
			var result: Dictionary = step.duplicate(true)
			result.index = index
			result.total = steps.size()
			result.kind = str(material.kind)
			result.vertices = vertices
			return result
	return {}

static func _step(material_id: String, position: Vector2, description: String) -> Dictionary:
	return {"material_id": material_id, "position": position, "description": description}

static func _same_outline(actual: PackedVector2Array, expected: PackedVector2Array) -> bool:
	if actual.size() != 4 or expected.size() != 4:
		return false
	# A quarter-turn of a square has the same outline; a turned rectangle does not.
	# Compare actual vertices, allowing only a cyclic change of the starting vertex.
	for offset: int in range(4):
		var matches: bool = true
		for index: int in range(4):
			if actual[(index + offset) % 4].distance_to(expected[index]) > MATCH_TOLERANCE:
				matches = false
				break
		if matches:
			return true
	return false
