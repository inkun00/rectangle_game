class_name TestConstructionPhysics
extends RefCounted

const Model = preload("res://scripts/construction/construction_document.gd")
const Canvas = preload("res://scenes/construction/construction_canvas.gd")
const Simulation = preload("res://scenes/construction/construction_physics.gd")
const State = preload("res://scripts/construction/construction_state.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")

static func run(t: Node) -> void:
	_test_actual_frame_contacts(t)
	_test_diagnostic_directions(t)
	await _test_real_gravity_and_balance(t)
	await _test_opening_frames(t)
	await _test_canvas_interaction(t)
	await _test_architectural_presentation(t)
	await _test_maximum_masonry(t)
	await _test_all_contracts(t)
	await _test_variant_opening_frames(t)
	await _test_balanced_structural_materials(t)
	await _test_rhombus_opening_frames(t)
	await _test_balanced_decorations(t)
	await _test_unsupported_balanced_structures(t)

static func _test_balanced_structural_materials(t: Node) -> void:
	var material_ids: Array[String] = [
		"wall_square_large", "roof_square", "roof_trapezoid_small",
		"roof_trapezoid_metal", "beam_trapezoid", "roof_parallelogram",
		"roof_parallelogram_long", "beam_parallelogram", "wall_parallelogram"
	]
	var simulation: Simulation = Simulation.new()
	t.add_child(simulation)
	for batch: int in range(3):
		var document: Model = Model.new()
		var items: Array[Dictionary] = []
		for column: int in range(3):
			var material_id: String = material_ids[batch * 3 + column]
			var material: Dictionary = Catalog.material(material_id)
			var vertices: PackedVector2Array = QuadrilateralMath.create_vertices(str(material.kind), material.dimensions)
			var bottom: float = QuadrilateralMath.bounds(vertices).end.y
			var x: float = 160.0 + column * 340.0
			items.append({"material_id": "wall", "position": Vector2(x, 530)})
			items.append({"material_id": material_id, "position": Vector2(x, 500.0 - bottom)})
		t.assert_true(document.replace_parts(items), "New square, trapezoid and parallelogram structure sizes fit above their real wall supports")
		var before: Dictionary = document.serialize()
		simulation.start(document.parts, document.revision)
		await _finish_simulation(t, simulation)
		t.assert_true(bool(simulation.report.stable), "Every supported new roof, beam and wall in batch %d stays stable under real gravity" % batch)
		for part: Dictionary in document.parts:
			t.assert_true(simulation.report.stable_ids.has(int(part.id)), "The actual polygon of %s remains supported" % str(part.material_id))
		t.assert_eq(document.serialize(), before, "Inspection preserves the purchased dimensions and prices of new structural materials")
		simulation.stop()
	simulation.free()
	await t.get_tree().process_frame

static func _rhombus_frame(window_id: String, wall_id: String, center: Vector2) -> Array[Dictionary]:
	var dimensions: Vector2 = Catalog.material(window_id).dimensions
	var half: Vector2 = dimensions * 0.5
	var items: Array[Dictionary] = [{"material_id": window_id, "position": center}]
	# Matching diamonds form a bonded arch around the actual empty aperture.
	# Two lower vertices contact the ground; the glass supplies no collision.
	for offset: Vector2 in [
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(-half.x, half.y), Vector2(half.x, half.y),
		Vector2(-dimensions.x, 0), Vector2(dimensions.x, 0), Vector2(0, -dimensions.y)
	]:
		items.append({"material_id": wall_id, "position": center + offset})
	return items

static func _test_rhombus_opening_frames(t: Node) -> void:
	var document: Model = Model.new()
	var items: Array[Dictionary] = _rhombus_frame("window_rhombus", "wall_rhombus", Vector2(300, 440))
	items.append_array(_rhombus_frame("window_rhombus_small", "wall_rhombus_small", Vector2(740, 500)))
	t.assert_true(document.replace_parts(items), "Large and small rhombus windows reserve valid empty spaces inside matching diamond masonry")
	var openings: Array[Dictionary] = []
	var structural: Array[Dictionary] = []
	for part: Dictionary in document.parts:
		if bool(Catalog.material(str(part.material_id)).opening): openings.append(part)
		else: structural.append(part)
	for opening: Dictionary in openings:
		var diagnosis: Dictionary = Simulation.opening_support(opening, structural)
		t.assert_true(bool(diagnosis.supported), "A rhombus window is framed by shared sloping edges rather than corner contacts")
		for coverage: float in diagnosis.edge_coverage:
			t.assert_float_approx(coverage, 1.0, 0.001, "Every real edge of each rhombus aperture has full masonry coverage")
	var before: Dictionary = document.serialize()
	var simulation: Simulation = Simulation.new()
	t.add_child(simulation)
	simulation.start(document.parts, document.revision)
	t.assert_eq(simulation._bodies.size(), 2, "Each matching diamond frame forms one separate bonded structural assembly")
	for body: RigidBody2D in simulation._bodies:
		t.assert_eq(body.get_child_count(), 7, "Rhombus glass adds weight but no load-bearing collision polygon")
	await _finish_simulation(t, simulation)
	t.assert_true(bool(simulation.report.stable), "Both sizes of diamond masonry and rhombus glass pass an actual gravity inspection")
	t.assert_eq(document.serialize(), before, "Sloped frame inspection does not alter the original rhombus geometry")
	simulation.stop()
	for opening: Dictionary in openings:
		var size: Vector2 = Catalog.material(str(opening.material_id)).dimensions
		var removed_position: Vector2 = Vector2(opening.position) + Vector2(size.x * 0.5, -size.y * 0.5)
		for part: Dictionary in document.parts:
			if Vector2(part.position).is_equal_approx(removed_position) and not bool(Catalog.material(str(part.material_id)).opening):
				document.select(int(part.id))
				document.delete_selected()
				break
	simulation.start(document.parts, document.revision)
	await _finish_simulation(t, simulation)
	for opening: Dictionary in openings:
		var issue: Dictionary = _issue_for(simulation.report, int(opening.id))
		t.assert_true(simulation.report.unsupported_ids.has(int(opening.id)), "Removing an upper diagonal block invalidates its rhombus window")
		t.assert_eq(issue.get("code", ""), "opening_frame_missing", "Unsupported diamond glazing retains the normal missing-frame diagnosis")
		t.assert_eq(issue.get("missing_edges", []), [0], "The exact unsupported upper-right rhombus edge is identified")
	simulation.stop()
	var floating: Model = Model.new()
	var glazing: Array[Dictionary] = []
	for opening: Dictionary in openings:
		glazing.append({"material_id": str(opening.material_id), "position": opening.position})
	t.assert_true(floating.replace_parts(glazing), "Unframed rhombus windows can be placed for diagnosis without hidden supports")
	simulation.start(floating.parts, floating.revision)
	await _finish_simulation(t, simulation)
	for opening: Dictionary in floating.parts:
		t.assert_true(simulation.report.unsupported_ids.has(int(opening.id)), "An unframed new rhombus window cannot pass after falling onto the ground")
		t.assert_eq(_issue_for(simulation.report, int(opening.id)).get("missing_edges", []).size(), 4, "An unframed rhombus reports all four missing real edge supports")
		t.assert_gt(simulation.pose(int(opening.id)).origin.y, Vector2(opening.position).y + 8.0, "Unsupported diamond glazing really descends under gravity")
	simulation.free()
	await t.get_tree().process_frame

static func _test_balanced_decorations(t: Node) -> void:
	var decorations: Array[Dictionary] = []
	var original_decorations: Array[String] = ["panel", "panel_long", "ornament", "ornament_large"]
	for material: Dictionary in Catalog.materials():
		if str(material.role) != "decor" or original_decorations.has(str(material.id)): continue
		var index: int = decorations.size()
		decorations.append({"material_id": str(material.id), "position": Vector2(140 + (index % 4) * 240, 320 if index < 4 else 480)})
	var items: Array[Dictionary] = []
	for x: int in [140, 380, 620, 860]:
		for y: int in [230, 290, 350, 410, 470, 530]:
			items.append({"material_id": "wall", "position": Vector2(x, y)})
	items.append_array(decorations)
	var document: Model = Model.new()
	t.assert_true(document.replace_parts(items), "The new square, trapezoid, parallelogram and rhombus finish pieces fit on actual wall faces")
	var simulation: Simulation = Simulation.new()
	t.add_child(simulation)
	simulation.start(document.parts, document.revision)
	await _finish_simulation(t, simulation)
	t.assert_true(bool(simulation.report.stable), "Every new facade finish attaches its own weight to a grounded wall")
	for part: Dictionary in document.parts:
		if str(Catalog.material(str(part.material_id)).role) == "decor":
			t.assert_true(simulation.report.stable_ids.has(int(part.id)), "The new %s finish remains attached" % str(part.material_id))
	simulation.stop()
	var loose: Model = Model.new()
	t.assert_true(loose.replace_parts(decorations), "The same finish pieces also form a valid unsupported diagnostic design")
	simulation.start(loose.parts, loose.revision)
	await _finish_simulation(t, simulation)
	for part: Dictionary in loose.parts:
		t.assert_true(simulation.report.unsupported_ids.has(int(part.id)), "A floating new finish piece cannot substitute for a wall")
		t.assert_eq(_issue_for(simulation.report, int(part.id)).get("code", ""), "decoration_unattached", "Each unsupported new finish explains its missing attachment")
	simulation.free()
	await t.get_tree().process_frame

static func _test_unsupported_balanced_structures(t: Node) -> void:
	var document: Model = Model.new()
	var items: Array[Dictionary] = [
		{"material_id": "roof_square", "position": Vector2(160, 220)},
		{"material_id": "beam_trapezoid", "position": Vector2(500, 220)},
		{"material_id": "roof_parallelogram_long", "position": Vector2(840, 220)}
	]
	t.assert_true(document.replace_parts(items), "New structural families can be tested without accidental initial contacts")
	var simulation: Simulation = Simulation.new()
	t.add_child(simulation)
	simulation.start(document.parts, document.revision)
	await _finish_simulation(t, simulation)
	for part: Dictionary in document.parts:
		t.assert_true(simulation.report.unsupported_ids.has(int(part.id)), "The new %s structural part needs a real foundation" % str(part.material_id))
		t.assert_gt(simulation.pose(int(part.id)).origin.y, Vector2(part.position).y + 40.0, "An unsupported new structural polygon really falls")
	simulation.free()
	await t.get_tree().process_frame

static func _test_variant_opening_frames(t: Node) -> void:
	var simulation: Simulation = Simulation.new()
	t.add_child(simulation)
	for opening_id: String in ["window_small", "window_tall", "door_short", "window_square_large"]:
		var document: Model = Model.new()
		var material: Dictionary = Catalog.material(opening_id)
		var dimensions: Vector2 = material.dimensions
		var bottom: float = 520.0 if opening_id == "window_small" else (540.0 if opening_id in ["window_tall", "window_square_large"] else 560.0)
		var top: float = bottom - dimensions.y
		var items: Array[Dictionary] = [{"material_id": opening_id, "position": Vector2(500, bottom - dimensions.y * 0.5)}]
		for x: float in [500.0 - dimensions.x * 0.5 - 20.0, 500.0 + dimensions.x * 0.5 + 20.0]:
			var y: float = 550.0
			while y > top:
				items.append({"material_id": "brick", "position": Vector2(x, y)})
				y -= 20.0
		if opening_id == "window_small":
			items.append({"material_id": "wall_square", "position": Vector2(490, 540)})
			items.append({"material_id": "brick", "position": Vector2(520, 540), "vertices": QuadrilateralMath.rotate_vertices(QuadrilateralMath.create_vertices("rectangle", Vector2(40, 20)), 90.0)})
		elif opening_id == "window_tall":
			for x: int in [480, 520]: items.append({"material_id": "brick", "position": Vector2(x, 550)})
		elif opening_id == "window_square_large":
			for x: int in [460, 500, 540]: items.append({"material_id": "brick", "position": Vector2(x, 550)})
		items.append({"material_id": "lintel_long", "position": Vector2(500, top - 10.0)})
		items.append({"material_id": "roof_medium", "position": Vector2(500, top - 60.0)})
		t.assert_true(document.replace_parts(items), "The new %s size reserves a nonoverlapping real aperture" % opening_id)
		simulation.start(document.parts, document.revision)
		await _finish_simulation(t, simulation)
		t.assert_true(bool(simulation.report.stable), "The new %s frame with long beam and medium roof passes actual gravity" % opening_id)
		t.assert_true(simulation.report.unsupported_ids.is_empty(), "Each new aperture keeps all four real frame supports: " + opening_id)
		simulation.stop()
	simulation.free()
	await t.get_tree().process_frame

static func _test_architectural_presentation(t: Node) -> void:
	var document: Model = Model.new()
	document.add_part("roof", Vector2(300, 300))
	var canvas: Canvas = Canvas.new()
	canvas.document = document
	canvas.size = Vector2(680, 420)
	t.add_child(canvas)
	await t.get_tree().process_frame
	var before: Dictionary = document.serialize()
	var screen_before: Vector2 = canvas.artwork_to_screen(Vector2(300, 300))
	canvas.set_presentation_mode(true)
	t.assert_true(canvas.presentation_mode, "Architectural presentation mode can be selected")
	t.assert_eq(document.serialize(), before, "Presentation styling preserves all authoritative geometry and selection")
	t.assert_eq(canvas.artwork_to_screen(Vector2(300, 300)), screen_before, "Changing render mode preserves the camera and input coordinates")
	canvas.set_presentation_mode(false)
	t.assert_false(canvas.presentation_mode, "Drafting mode can be restored without editing the design")
	for kind: String in ["square", "rectangle", "rhombus", "parallelogram", "trapezoid"]:
		var vertices: PackedVector2Array = QuadrilateralMath.rotate_vertices(QuadrilateralMath.create_vertices(kind, Vector2(120, 80)), 37.0)
		var contained: bool = true
		for u: float in [0.05, 0.5, 0.95]:
			for v: float in [0.05, 0.5, 0.95]:
				var point: Vector2 = canvas._uv_point(vertices, Vector2(u, v))
				contained = contained and point.is_finite() and QuadrilateralMath.contains_point(vertices, point)
		t.assert_true(contained, "Architectural material details stay inside a rotated %s" % kind)
	canvas.free()
	await t.get_tree().process_frame

static func _test_actual_frame_contacts(t: Node) -> void:
	var opening: Dictionary = _test_part(1, "window", Vector2(300, 300))
	var frame: Array[Dictionary] = [
		_test_part(2, "lintel", Vector2(300, 250)), _test_part(3, "lintel", Vector2(300, 350)),
		_test_part(4, "brick", Vector2(250, 280), 90.0), _test_part(5, "brick", Vector2(250, 320), 90.0),
		_test_part(6, "brick", Vector2(350, 280), 90.0), _test_part(7, "brick", Vector2(350, 320), 90.0)
	]
	var diagnosis: Dictionary = Simulation.opening_support(opening, frame)
	t.assert_true(diagnosis.supported, "Four real frame edges support an opening")
	t.assert_eq(diagnosis.missing_edges.size(), 0, "A complete frame has no missing edge diagnosis")
	for coverage: float in diagnosis.edge_coverage:
		t.assert_float_approx(coverage, 1.0, 0.001, "Separated adjacent bricks combine into full edge coverage")
	var moved_opening: Dictionary = opening.duplicate(true)
	moved_opening.position += Vector2(10, 0)
	t.assert_false(Simulation.opening_support(moved_opening, frame).supported, "Moving only the opening breaks its actual frame contacts")
	var rotated_opening: Dictionary = _rotate_test_part(opening, Vector2(300, 300), 37.0)
	var rotated_frame: Array[Dictionary] = []
	for part: Dictionary in frame:
		rotated_frame.append(_rotate_test_part(part, Vector2(300, 300), 37.0))
	t.assert_true(Simulation.opening_support(rotated_opening, rotated_frame).supported, "Rotating the complete frame preserves physical edge supports")
	rotated_opening.position += Vector2(60, 80)
	for part: Dictionary in rotated_frame:
		part.position += Vector2(60, 80)
	t.assert_true(Simulation.opening_support(rotated_opening, rotated_frame).supported, "Moving a rotated frame preserves supports without axis-aligned shortcuts")
	# This angle gives an 80-unit square an exactly 100-unit bounding box.
	# The four bricks touch its four corners, but none touches an actual side.
	var corner_angle: float = rad_to_deg(acos((1.25 + sqrt(0.4375)) * 0.5))
	var corner_opening: Dictionary = _test_part(8, "window", Vector2(300, 300), corner_angle)
	var corner_frame: Array[Dictionary] = [
		_test_part(9, "brick", Vector2(230, 330)), _test_part(10, "brick", Vector2(370, 270)),
		_test_part(11, "brick", Vector2(270, 240)), _test_part(12, "brick", Vector2(330, 360))
	]
	diagnosis = Simulation.opening_support(corner_opening, corner_frame)
	t.assert_false(diagnosis.supported, "Four AABB side contacts at rotated corners do not make a frame")
	t.assert_eq(diagnosis.missing_edges.size(), 4, "Corner-only contacts report every actual opening edge as unsupported")
	var door: Dictionary = _test_part(13, "door", Vector2(500, 500))
	var doorway: Array[Dictionary] = [
		_test_part(14, "lintel", Vector2(500, 430)), _test_part(15, "wall", Vector2(400, 470)),
		_test_part(16, "wall", Vector2(400, 530)), _test_part(17, "wall", Vector2(600, 470)),
		_test_part(18, "wall", Vector2(600, 530))
	]
	t.assert_true(Simulation.opening_support(door, doorway).supported, "A full horizontal ground edge can support the bottom of a door")
	var tipped_door: Dictionary = _test_part(19, "door", Vector2(500, 488), rad_to_deg(atan(0.75)))
	var no_frame: Array[Dictionary] = []
	diagnosis = Simulation.opening_support(tipped_door, no_frame)
	t.assert_eq(diagnosis.missing_edges.size(), 4, "A rotated door corner on the ground is not a supporting bottom edge")
	var horizontal_door: Dictionary = _test_part(20, "door", Vector2(500, 520), 90.0)
	var horizontal_frame: Array[Dictionary] = [
		_test_part(21, "lintel", Vector2(500, 470)), _test_part(22, "brick", Vector2(430, 500), 90.0),
		_test_part(23, "brick", Vector2(430, 540), 90.0), _test_part(24, "brick", Vector2(570, 500), 90.0),
		_test_part(25, "brick", Vector2(570, 540), 90.0)
	]
	t.assert_true(Simulation.opening_support(horizontal_door, horizontal_frame).supported, "Ground support follows the actual rotated edge, not the original bottom-edge index")

static func _test_part(id: int, material_id: String, position: Vector2, degrees: float = 0.0) -> Dictionary:
	var material: Dictionary = Catalog.material(material_id)
	var vertices: PackedVector2Array = QuadrilateralMath.create_vertices(str(material.kind), material.dimensions)
	return {"id": id, "material_id": material_id, "kind": str(material.kind), "position": position, "vertices": QuadrilateralMath.rotate_vertices(vertices, degrees)}

static func _rotate_test_part(part: Dictionary, pivot: Vector2, degrees: float) -> Dictionary:
	var result: Dictionary = part.duplicate(true)
	result.position = pivot + (Vector2(part.position) - pivot).rotated(deg_to_rad(degrees))
	result.vertices = QuadrilateralMath.rotate_vertices(part.vertices, degrees)
	return result

static func _test_diagnostic_directions(t: Node) -> void:
	var opening: Dictionary = _test_part(1, "window", Vector2(300, 300))
	# Leave out only the original top edge, then rotate the entire design.
	var frame: Array[Dictionary] = [
		_test_part(2, "lintel", Vector2(300, 350)),
		_test_part(3, "brick", Vector2(250, 280), 90.0), _test_part(4, "brick", Vector2(250, 320), 90.0),
		_test_part(5, "brick", Vector2(350, 280), 90.0), _test_part(6, "brick", Vector2(350, 320), 90.0)
	]
	var simulation: Simulation = Simulation.new()
	t.add_child(simulation)
	for degrees: float in [90.0, 37.0]:
		var parts: Array[Dictionary] = [_rotate_test_part(opening, Vector2(300, 300), degrees)]
		for part: Dictionary in frame:
			parts.append(_rotate_test_part(part, Vector2(300, 300), degrees))
		simulation.start(parts, 1)
		# Diagnose immediately: an incomplete frame fails even before gravity moves it.
		simulation._finish()
		var issue: Dictionary = _issue_for(simulation.report, 1)
		t.assert_eq(issue.code, "opening_frame_missing", "An incomplete rotated opening has a frame repair diagnosis")
		t.assert_eq(issue.missing_edges, [0], "Missing edges retain the authoritative vertex edge index after rotation")
		var expected_direction: String = "오른쪽 변" if degrees == 90.0 else "오른쪽 위 변"
		t.assert_true(str(issue.message).contains(expected_direction), "Frame repair text follows the actual world direction of the rotated edge")
		t.assert_false(str(issue.message).contains("위쪽 변"), "Rotated frame text does not keep the original local top-edge label")
		simulation.stop()
	# Relative rotation during the simulation is distinguished from a moved part.
	var tilted: Array[Dictionary] = [_test_part(7, "wall", Vector2(300, 300))]
	simulation.start(tilted, 2)
	var body: RigidBody2D = simulation._poses[7].body
	body.rotation = deg_to_rad(12.0)
	simulation._finish()
	t.assert_eq(_issue_for(simulation.report, 7).code, "structure_tilted", "A structure that rotates during inspection gets a balance repair diagnosis")
	simulation.free()

static func _issue_for(report: Dictionary, part_id: int) -> Dictionary:
	for issue: Dictionary in report.get("issues", []):
		if int(issue.part_id) == part_id:
			return issue
	return {}

static func _test_real_gravity_and_balance(t: Node) -> void:
	var document: Model = Model.new()
	var ground_id: int = document.add_part("brick", Vector2(100, 550))
	var upper_id: int = document.add_part("brick", Vector2(100, 530))
	var footing_id: int = document.add_part("brick", Vector2(300, 550))
	var cantilever_id: int = document.add_part("wall", Vector2(360, 510))
	var floating_id: int = document.add_part("wall", Vector2(600, 250))
	var loose_window_id: int = document.add_part("window", Vector2(850, 300))
	var ornament_id: int = document.add_part("ornament", Vector2(120, 530))
	var loose_ornament_id: int = document.add_part("ornament", Vector2(750, 180))
	var carried_ornament_id: int = document.add_part("ornament", Vector2(610, 250))
	var original: String = JSON.stringify(document.serialize())
	var simulation: Simulation = Simulation.new()
	t.add_child(simulation)
	simulation.start(document.parts, document.revision)
	var weighted_body: RigidBody2D = simulation._poses[ground_id].body
	t.assert_float_approx(weighted_body.mass, 6.5, 0.001, "Attached ornament adds its mass to the masonry assembly")
	t.assert_float_approx(weighted_body.center_of_mass.x, 30.0 / 6.5, 0.001, "Off-center ornament moves the assembly center of mass")
	t.assert_gt(weighted_body.inertia, 1000.0, "Compound inertia includes the fitting and its offset")
	await _finish_simulation(t, simulation)
	t.assert_false(simulation.running, "Construction physics finishes in bounded time")
	t.assert_gt(simulation.pose(floating_id).origin.y, 400.0, "Unsupported masonry really falls under engine gravity")
	t.assert_true(simulation.report.unsupported_ids.has(floating_id), "A fallen assembly fails inspection even after landing")
	t.assert_true(simulation.report.stable_ids.has(ground_id), "Grounded masonry is stable")
	t.assert_true(simulation.report.stable_ids.has(upper_id), "Mortar-bonded vertical stack stays stable")
	t.assert_true(simulation.report.stable_ids.has(ornament_id), "Attached decoration follows its weighted support")
	t.assert_true(simulation.report.unsupported_ids.has(cantilever_id), "Off-balance assembly tips under its actual center of mass")
	t.assert_true(simulation.report.unsupported_ids.has(footing_id), "Tipping affects the connected footing too")
	t.assert_true(simulation.report.unsupported_ids.has(loose_window_id), "A window with no surrounding frame cannot pass")
	t.assert_eq(_issue_for(simulation.report, floating_id).code, "structure_moved", "A floating wall reports the need for structural support after falling")
	t.assert_eq(_issue_for(simulation.report, loose_window_id).code, "opening_frame_missing", "An unsupported window reports missing frame edges instead of only motion")
	t.assert_eq(_issue_for(simulation.report, loose_window_id).missing_edges, [0, 1, 2, 3], "A loose window identifies all four missing original frame edges")
	t.assert_eq(_issue_for(simulation.report, loose_ornament_id).code, "decoration_unattached", "Loose decoration gives an attachment repair instruction")
	t.assert_eq(_issue_for(simulation.report, carried_ornament_id).code, "fitting_support_moved", "Attached decoration explains that its supporting structure moved")
	t.assert_eq(simulation.report.issues.size(), simulation.report.unsupported_ids.size(), "Inspection gives exactly one issue per unsupported part")
	var issue_index: int = 0
	for part: Dictionary in document.parts:
		if not simulation.report.unsupported_ids.has(int(part.id)):
			continue
		var issue: Dictionary = simulation.report.issues[issue_index]
		t.assert_eq(issue.part_id, int(part.id), "Inspection issues follow design order")
		t.assert_eq(issue.material_id, str(part.material_id), "Inspection issue identifies the failing material")
		t.assert_true(not str(issue.message).is_empty(), "Every inspection issue includes actionable feedback")
		if str(issue.code) != "opening_frame_missing":
			t.assert_eq(issue.missing_edges.size(), 0, "Only incomplete opening frames expose missing edge indices")
		issue_index += 1
	t.assert_eq(simulation.report.revision, document.revision, "Inspection identifies its exact design revision")
	t.assert_eq(JSON.stringify(document.serialize()), original, "Physics never writes simulated transforms into the design")
	for part: Dictionary in document.parts:
		var transformed: PackedVector2Array = PackedVector2Array()
		for vertex: Vector2 in part.vertices:
			transformed.append(simulation.pose(int(part.id)) * vertex)
		t.assert_true(QuadrilateralMath.matches_kind(transformed, str(part.kind)), "Actual physics preserves every quadrilateral family")
	simulation.stop()
	t.assert_eq(simulation.rendered_parts().size(), 0, "Stopping inspection frees its copied design")
	simulation.free()

static func _test_opening_frames(t: Node) -> void:
	var document: Model = Model.new()
	var door_id: int = document.add_part("door", Vector2(500, 500))
	var window_id: int = document.add_part("window", Vector2(340, 480))
	for point: Vector2 in [Vector2(240, 530), Vector2(240, 470), Vector2(600, 530), Vector2(600, 470)]:
		t.assert_gt(document.add_part("wall", point), 0, "Wall modules leave the reserved opening clear")
	for x: int in [320, 360]:
		for y: int in [530, 550]:
			document.add_part("brick", Vector2(x, y))
	for x: int in [400, 440]:
		for y: int in [450, 470, 490, 510, 530, 550]:
			document.add_part("brick", Vector2(x, y))
	var first_lintel: int = document.add_part("lintel", Vector2(340, 430))
	var second_lintel: int = document.add_part("lintel", Vector2(500, 430))
	var roof_id: int = document.add_part("roof_wide", Vector2(420, 370))
	t.assert_gt(first_lintel, 0, "Lintel spans above the reserved window space")
	t.assert_gt(second_lintel, 0, "Lintel spans above the reserved door space")
	t.assert_gt(roof_id, 0, "Roof sits on the structural lintels")
	t.assert_eq(document.add_part("brick", Vector2(500, 500)), -1, "Building inside the door space is rejected")
	t.assert_eq(document.add_part("wall", Vector2(340, 480)), -1, "Building over the window space is rejected")
	var simulation: Simulation = Simulation.new()
	t.add_child(simulation)
	simulation.start(document.parts, document.revision)
	await _finish_simulation(t, simulation)
	t.assert_true(simulation.report.stable, "A completely framed starter house passes real physics")
	t.assert_eq(simulation.report.issues.size(), 0, "A stable house has no repair issues")
	t.assert_true(simulation.report.stable_ids.has(window_id), "A window installed in its actual opening is supported")
	t.assert_true(simulation.report.stable_ids.has(door_id), "A framed door remains in its opening")
	t.assert_true(simulation.report.stable_ids.has(roof_id), "Lintels carry the roof without relying on door or glass")
	var window_pose: Transform2D = simulation.pose(window_id)
	t.assert_float_approx(window_pose.origin.y, 480.0, 8.0, "Installed window follows its structural frame")
	simulation.stop()
	# Remove both lintels. Neither the door nor the window may become a support.
	document.select(first_lintel)
	document.delete_selected()
	document.select(second_lintel)
	document.delete_selected()
	simulation.start(document.parts, document.revision)
	await _finish_simulation(t, simulation)
	t.assert_false(simulation.report.stable, "Removing lintels makes the house incomplete")
	t.assert_true(simulation.report.unsupported_ids.has(window_id), "Window needs the top of its frame")
	t.assert_true(simulation.report.unsupported_ids.has(door_id), "Door needs the top of its frame")
	t.assert_eq(_issue_for(simulation.report, window_id).missing_edges, [0], "Removing the window lintel identifies the missing top frame edge")
	t.assert_true(str(_issue_for(simulation.report, window_id).message).contains("위쪽 변"), "Missing window lintel feedback names the top edge")
	t.assert_gt(simulation.pose(roof_id).origin.y, 378.0, "Roof falls when lintels are removed; openings carry no structural load")
	simulation.free()

static func _test_canvas_interaction(t: Node) -> void:
	var canvas: Canvas = Canvas.new()
	canvas.document = Model.new()
	canvas.size = Vector2(800, 500)
	t.add_child(canvas)
	await t.get_tree().process_frame
	canvas.choose_material("door")
	_pointer(canvas, Vector2(500, 500), true)
	_pointer(canvas, Vector2(500, 500), false)
	t.assert_eq(canvas.document.parts.size(), 1, "Pointer placement creates an opening in the model")
	canvas.choose_material("wall")
	_pointer(canvas, Vector2(500, 500), true)
	_pointer(canvas, Vector2(500, 500), false)
	t.assert_eq(canvas.document.parts.size(), 1, "Pointer placement cannot cover a reserved door")
	canvas.choose_material("brick")
	_pointer(canvas, Vector2(100, 550), true)
	_pointer(canvas, Vector2(100, 550), false)
	canvas.select_tool()
	_pointer(canvas, Vector2(100, 550), true)
	var history_size: int = canvas.document.command_manager.undo_stack.size()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = canvas.artwork_to_screen(Vector2(160, 550))
	canvas._gui_input(motion)
	t.assert_eq(canvas.document.command_manager.undo_stack.size(), history_size, "Dragging preview does not create history entries")
	_pointer(canvas, Vector2(160, 550), false)
	t.assert_eq(canvas.document.command_manager.undo_stack.size(), history_size + 1, "A complete drag is one undoable operation")
	t.assert_eq(canvas.document.get_selected().position, Vector2(160, 550), "Drag moves the selected whole quadrilateral")
	canvas.document.undo()
	t.assert_eq(canvas.document.get_selected().position, Vector2(100, 550), "Undo restores the initial whole-part position")
	canvas.choose_material("brick")
	_pointer(canvas, Vector2(200, 550), true)
	canvas.cancel_gesture()
	_pointer(canvas, Vector2(200, 550), false)
	t.assert_eq(canvas.document.parts.size(), 2, "A canceled gesture cannot place on later pointer release")
	canvas.editing_enabled = false
	canvas.add_at_cursor()
	t.assert_eq(canvas.document.parts.size(), 2, "Modal editing gate prevents keyboard placement")
	canvas.editing_enabled = true
	var target: Vector2 = Vector2(340, 300)
	canvas.zoom_by(2.0)
	t.assert_true(canvas.screen_to_artwork(canvas.artwork_to_screen(target)).is_equal_approx(target), "Zoom keeps cursor coordinate mapping reversible")
	canvas.reset_view()
	t.assert_eq(canvas.zoom, 1.0, "Reset restores the full building site")
	var before_fit: String = JSON.stringify(canvas.document.serialize())
	canvas.fit_parts()
	t.assert_gt(canvas.zoom, 1.0, "Fit view enlarges the actual house instead of leaving it at the bottom of the whole lot")
	var house_center: Vector2 = Vector2(310, 500)
	t.assert_true(canvas.artwork_to_screen(house_center).is_equal_approx(canvas.size * 0.5), "Fit view centers the occupied geometry")
	canvas.size = Vector2(520, 330)
	await t.get_tree().process_frame
	for part: Dictionary in canvas.document.parts:
		for vertex: Vector2 in canvas.document.world_vertices(part):
			t.assert_true(Rect2(Vector2.ZERO, canvas.size).has_point(canvas.artwork_to_screen(vertex)), "Fit view keeps every vertex visible in a narrow workspace")
	t.assert_eq(JSON.stringify(canvas.document.serialize()), before_fit, "Camera fitting never changes the house or its prices")
	t.assert_true(canvas.artwork_to_screen(house_center).is_equal_approx(canvas.size * 0.5), "Automatic fit follows the final resized canvas layout")
	canvas.fit_context = Rect2(700, 360, 120, 60)
	await t.get_tree().process_frame
	for point: Vector2 in [Vector2(80, 540), Vector2(540, 440), Vector2(700, 360), Vector2(820, 420)]:
		t.assert_true(Rect2(Vector2.ZERO, canvas.size).has_point(canvas.artwork_to_screen(point)), "Auto-fit keeps both the built house and the next external guide preview visible")
	canvas.fit_context = Rect2()
	await t.get_tree().process_frame
	canvas.zoom_by(1.1)
	var manual_zoom: float = canvas.zoom
	canvas.fit_context = Rect2(800, 100, 80, 80)
	canvas.size = Vector2(600, 350)
	await t.get_tree().process_frame
	t.assert_eq(canvas.zoom, manual_zoom, "Manual zoom disables automatic refitting on resize or guide context change")
	canvas.fit_context = Rect2()
	canvas.fit_parts()
	var pan_press: InputEventMouseButton = InputEventMouseButton.new()
	pan_press.button_index = MOUSE_BUTTON_RIGHT
	pan_press.pressed = true
	canvas._gui_input(pan_press)
	t.assert_false(canvas._auto_fit, "Manual panning disables automatic fitting")
	canvas.cancel_gesture()
	canvas.fit_parts()
	canvas.reset_view()
	t.assert_false(canvas._auto_fit, "Reset overview disables automatic fitting")
	canvas.cursor_position = Vector2(200, 400)
	var fine_key: InputEventKey = InputEventKey.new()
	fine_key.keycode = KEY_DOWN
	fine_key.pressed = true
	fine_key.shift_pressed = true
	canvas._gui_input(fine_key)
	t.assert_eq(canvas.cursor_position, Vector2(200, 410), "Shift arrows allow precise half-grid placement of single bricks")
	var replacement: Model = Model.new()
	canvas.document = replacement
	canvas.fit_parts()
	t.assert_eq(canvas.zoom, 1.0, "Fitting an empty new lot restores the overview")
	canvas.fit_context = Rect2(460, 440, 80, 120)
	await t.get_tree().process_frame
	t.assert_gt(canvas.zoom, 1.0, "An empty lot can fit the first external guide preview")
	t.assert_true(canvas.artwork_to_screen(Vector2(500, 500)).is_equal_approx(canvas.size * 0.5), "An empty-lot guide is centered without creating a real part")
	canvas.fit_context = Rect2()
	replacement.add_part("brick", Vector2(100, 550))
	t.assert_true(replacement.changed.is_connected(canvas._document_changed), "Loading another document reconnects canvas updates")
	canvas.start_inspection()
	canvas.hide()
	t.assert_false(canvas.inspection_running, "Hidden construction mode stops physics immediately")
	t.assert_false(canvas.inspection_visible, "Hidden construction mode returns to its saved design")
	canvas.free()
	await t.get_tree().process_frame

static func _test_maximum_masonry(t: Node) -> void:
	var document: Model = Model.new()
	var items: Array[Dictionary] = []
	for row: int in range(16):
		for column: int in range(25):
			items.append({"material_id": "brick", "position": Vector2(20 + column * 40, 550 - row * 20)})
	t.assert_true(document.replace_parts(items), "The supported maximum of 400 individual bricks fits the construction lot")
	var simulation: Simulation = Simulation.new()
	t.add_child(simulation)
	var started: int = Time.get_ticks_msec()
	simulation.start(document.parts, document.revision)
	var build_milliseconds: int = Time.get_ticks_msec() - started
	t.assert_true(build_milliseconds < 5000, "Maximum-size masonry builds the physics copy within a bounded preparation time")
	t.assert_eq(simulation._bodies.size(), 1, "Four hundred touching bricks use one bonded rigid assembly with separate shapes")
	await _finish_simulation(t, simulation)
	t.assert_false(simulation.running, "Maximum-size inspection finishes within the frame bound")
	t.assert_eq(simulation.report.stable_ids.size(), 400, "Maximum-size grounded masonry remains stable")
	print("Construction maximum: 400 bricks, physics preparation %d ms" % build_milliseconds)
	simulation.free()

static func _test_all_contracts(t: Node) -> void:
	var state: State = State.new()
	var simulation: Simulation = Simulation.new()
	t.add_child(simulation)
	for choice: int in range(Catalog.contract_count()):
		var stage: int = int(Catalog.contract(choice).stage)
		var repeats: int = 0
		while not bool(state.stage_unlock_status(stage).unlocked) and repeats < 12:
			t.assert_true(state.repeat_contract(), "A lower-stage client can pay for repeated physically tested work")
			await _finish_staged_physics(t, state, simulation, state.contract_choice)
			repeats += 1
		t.assert_true(state.select_contract(choice), "Earned profits unlock every next authored client")
		t.assert_eq(state.contract_choice, choice, "Chosen clients remain independent of the number of completed projects")
		await _finish_staged_physics(t, state, simulation, choice)
	t.assert_ge(state.records.size(), Catalog.contract_count(), "All ten clients form a playable progression including money-earning repeat work")
	var reloaded: State = State.new()
	t.assert_true(reloaded.restore(JSON.parse_string(JSON.stringify(state.serialize()))), "All staged invoices, award feedback and repeated clients survive validated JSON reload")
	t.assert_eq(reloaded.balance, state.balance, "Reloading every physically inspected contract preserves the exact paid balance")
	simulation.free()
	await t.get_tree().process_frame

static func _finish_staged_physics(t: Node, state: State, simulation: Simulation, choice: int) -> void:
	t.assert_true(state.accept_contract(), "Every unlocked client can fund their build")
	t.assert_true(state.document.replace_parts(ConstructionGuide.example_for_contract(state.current_contract())), "All required apertures and decorations fit within the client's actual material budget")
	simulation.start(state.document.parts, state.document.revision)
	await _finish_simulation(t, simulation)
	t.assert_true(simulation.report.stable, "Client %d has a physically feasible house with all opening frames" % (choice + 1))
	var evaluation: Dictionary = state.evaluate(simulation.report)
	t.assert_true(evaluation.can_submit, "Client %d accepts a feasible covered facade" % (choice + 1))
	t.assert_eq(evaluation.score, 100, "Client %d can reach full satisfaction without impossible geometry" % (choice + 1))
	t.assert_false(state.settle(simulation.report).is_empty(), "Client %d can be settled from an actual physics report" % (choice + 1))
	simulation.stop()

static func _complete_facade(client_index: int) -> Array[Dictionary]:
	if client_index == 0:
		var first: Array[Dictionary] = []
		for step: Dictionary in ConstructionGuide.plan():
			first.append({"material_id": step.material_id, "position": step.position})
		return first
	# A continuous facade with reserved openings, a solid header course and
	# modest eaves. Extra windows are not used to hide incomplete outer walls.
	var windows: int = 3 if client_index == 4 else 2
	var openings: int = windows + 1
	var width: float = 120.0 * openings + 120.0
	var left: float = 500.0 - width * 0.5
	var door_column: int = 1
	var items: Array[Dictionary] = []
	var apertures: Array[Rect2] = []
	for column: int in range(openings):
		var x: float = left + 120.0 + 120.0 * column
		var is_door: bool = column == door_column
		items.append({"material_id": "door" if is_door else "window", "position": Vector2(x, 500 if is_door else 480)})
		apertures.append(Rect2(x - 40.0, 440.0, 80.0, 120.0 if is_door else 80.0))
	for row: int in range(6):
		for column: int in range(roundi(width / 40.0)):
			var point: Vector2 = Vector2(left + 20.0 + column * 40.0, 450.0 + row * 20.0)
			var in_opening: bool = false
			for aperture: Rect2 in apertures:
				if aperture.has_point(point): in_opening = true
			if not in_opening: items.append({"material_id": "brick", "position": point})
	for column: int in range(roundi(width / 120.0)):
		items.append({"material_id": "lintel", "position": Vector2(left + 60.0 + column * 120.0, 430)})
	if client_index == 4:
		for x: float in [340.0, 660.0]:
			items.append({"material_id": "roof_medium", "position": Vector2(x, 380)})
	else:
		items.append({"material_id": "roof_wide", "position": Vector2(500, 370)})
	if client_index in [2, 5]:
		items.append({"material_id": "ornament_large", "position": Vector2(left + 40.0, 480)})
	if client_index in [3, 5]:
		items.append({"material_id": "panel_long", "position": Vector2(left + 120.0, 540)})
	return items

static func _pointer(canvas: Canvas, point: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = canvas.artwork_to_screen(point)
	canvas._gui_input(event)

static func _finish_simulation(t: Node, simulation: Simulation) -> void:
	var frames: int = 0
	while simulation.running and frames < 240:
		await t.get_tree().physics_frame
		frames += 1
	await t.get_tree().process_frame
