extends RefCounted

const Facade = preload("res://scripts/construction/construction_facade.gd")
const Document = preload("res://scripts/construction/construction_document.gd")
const Guide = preload("res://scripts/construction/construction_guide.gd")

static func run(t: Node) -> void:
	var closed: Document = Document.new()
	var items: Array[Dictionary] = _closed_house()
	t.assert_true(closed.replace_parts(items), "Facade fixture uses real purchased quadrilaterals and reserved openings")
	var report: Dictionary = Facade.inspect(closed.parts)
	t.assert_true(bool(report.complete), "Continuous eaves and real framed openings form a complete house front")
	t.assert_true(report.gaps.is_empty(), "A complete house front has no facade diagnostics")
	var before: Dictionary = closed.serialize()
	Facade.inspect(closed.parts)
	t.assert_eq(closed.serialize(), before, "Facade inspection does not modify the player's geometry")
	var open_eaves: Array[Dictionary] = items.duplicate(true)
	for index: int in range(open_eaves.size() - 1, -1, -1):
		if str(open_eaves[index].material_id) == "lintel" and Vector2(open_eaves[index].position).x in [240.0, 600.0]: open_eaves.remove_at(index)
	_check_invalid(t, open_eaves, "Exposed outer wall shoulders below eaves are incomplete even when gravity is stable")
	var missing_base: Array[Dictionary] = items.duplicate(true)
	for index: int in range(missing_base.size() - 1, -1, -1):
		if str(missing_base[index].material_id) == "wall" and Vector2(missing_base[index].position).y == 530.0: missing_base.remove_at(index)
	_check_invalid(t, missing_base, "Bonded cantilevers cannot hide missing ground-level facade walls")
	var separated: Array[Dictionary] = [
		_item("wall", Vector2(200, 530)), _item("roof", Vector2(200, 470)),
		_item("wall", Vector2(600, 530)), _item("roof", Vector2(600, 470))
	]
	_check_invalid(t, separated, "Separate stable towers are not one enclosed house facade")
	var narrow_roof: Array[Dictionary] = [_item("wall", Vector2(400, 530)), _item("roof_trapezoid_small", Vector2(420, 480))]
	_check_invalid(t, narrow_roof, "A roof that covers only part of the wall footprint leaves an exposed facade")
	var small_closed: Array[Dictionary] = [_item("wall", Vector2(400, 530)), _item("roof_trapezoid_small", Vector2(400, 480))]
	var small_document: Document = Document.new()
	t.assert_true(small_document.replace_parts(small_closed), "Small sloped roof has a real matching wall contact")
	t.assert_true(bool(Facade.inspect(small_document.parts).complete), "Small trapezoid roofs can close an entire narrow facade")
	var sloped: Array[Dictionary] = [_item("wall", Vector2(400, 530)), _item("roof_parallelogram", Vector2(410, 470))]
	var sloped_document: Document = Document.new()
	t.assert_true(sloped_document.replace_parts(sloped), "A parallelogram roof meets the wall using its actual horizontal base")
	t.assert_true(bool(Facade.inspect(sloped_document.parts).complete), "Sloping exterior roof edges and eaves are allowed")
	var sloped_gap: Array[Dictionary] = [_item("wall", Vector2(400, 530)), _item("roof_parallelogram", Vector2(400, 470))]
	_check_invalid(t, sloped_gap, "A five-pixel wedge below a sloping roof is caught even though its bounding box covers the wall")
	var thin_gap: Document = Document.new()
	thin_gap.replace_parts([_item("wall", Vector2(400, 530)), _item("roof", Vector2(400, 470))])
	thin_gap.parts[1].position.y -= 1.0
	t.assert_true(not bool(Facade.inspect(thin_gap.parts).complete), "A one-pixel wall-to-roof gap cannot disappear between grid samples")
	var rotated_gap: Array[Dictionary] = closed.parts.duplicate(true)
	for part: Dictionary in rotated_gap:
		if str(part.material_id) in ["roof_wide", "roof_flat_wide"]:
			part.vertices = QuadrilateralMath.rotate_vertices(part.vertices, 0.5)
	t.assert_true(not bool(Facade.inspect(rotated_gap).complete), "An almost horizontal rotated roof cannot conceal the narrow wedge under one eave")
	var decorative: Array[Dictionary] = closed.parts.duplicate(true)
	var stray: Dictionary = closed.parts[0].duplicate(true)
	stray.material_id = "ornament"
	stray.position = Vector2(950, 80)
	decorative.append(stray)
	t.assert_true(bool(Facade.inspect(decorative).complete), "Decorative silhouettes do not enlarge the structural facade footprint")
	t.assert_true(not bool(Facade.inspect([]).complete), "An empty board is not a completed facade")

static func _closed_house() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for step: Dictionary in Guide.plan():
		if str(step.material_id) == "lintel" or Vector2(step.position).y == 430.0: continue
		result.append(_item(str(step.material_id), Vector2(step.position)))
	for x: float in [240.0, 360.0, 480.0, 600.0]: result.append(_item("lintel", Vector2(x, 430)))
	return result

static func _check_invalid(t: Node, items: Array[Dictionary], message: String) -> void:
	var document: Document = Document.new()
	t.assert_true(document.replace_parts(items), "Incomplete facade fixture remains legal editable geometry")
	var report: Dictionary = Facade.inspect(document.parts)
	t.assert_true(not bool(report.complete), message)
	t.assert_true(not report.gaps.is_empty(), "An incomplete facade reports visible gap rectangles")

static func _item(material_id: String, position: Vector2) -> Dictionary:
	return {"material_id": material_id, "position": position}
