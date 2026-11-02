class_name TestConstructionRotation
extends RefCounted

const Document = preload("res://scripts/construction/construction_document.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Custom = preload("res://scripts/construction/custom_material_catalog.gd")
const Canvas = preload("res://scenes/construction/construction_canvas.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")

static func run(t: Node) -> void:
	_test_geometry_and_validation(t)
	await _test_pointer_rotation(t)
	await _test_rejected_and_canceled_gestures(t)
	await _test_small_material_edges(t)

static func _test_geometry_and_validation(t: Node) -> void:
	var ids: Array[String] = Catalog.MATERIAL_IDS.duplicate()
	for kind: String in Math.KINDS:
		var variants: Array[String] = ["symmetric"]
		if kind == "trapezoid": variants.assign(Math.TRAPEZOID_VARIANTS)
		for variant: String in variants:
			ids.append(Custom.make_id(kind, Vector2(100, 100) if kind == "square" else Vector2(160, 80), "metal", "diamond", "wall", variant))
	for material_id: String in ids:
		var document: Document = Document.new()
		t.assert_gt(document.add_part(material_id, Vector2(1000, 0)), 0, "Rotation fixture accepts " + material_id)
		var original: Dictionary = document.serialize()
		var vertices: PackedVector2Array = document.get_selected().vertices
		var cost: int = document.material_cost()
		var history: int = document.command_manager.undo_stack.size()
		t.assert_eq(document.rotation_error(37.25), "", "Every catalog and custom family supports arbitrary angles")
		t.assert_eq(document.serialize(), original, "Rotation validation does not modify live geometry or revision")
		t.assert_eq(document.command_manager.undo_stack.size(), history, "Preview validation does not create commands")
		t.assert_true(document.rotate_selected(37.25), "Free rotation preserves canonical material dimensions")
		var rotated: PackedVector2Array = document.get_selected().vertices
		t.assert_true(Math.matches_kind(rotated, str(document.get_selected().kind)), "Rotation preserves the selected family and convexity")
		var sum: float = 0.0
		for angle: float in Math.angles_degrees(rotated): sum += angle
		t.assert_float_approx(sum, 360.0, 0.01, "Arbitrary rotation retains the four-angle sum")
		for index: int in range(4):
			t.assert_true(rotated[index].is_finite(), "Rotated vertices remain finite")
			t.assert_float_approx(rotated[index].distance_to(rotated[(index + 1) % 4]), vertices[index].distance_to(vertices[(index + 1) % 4]), 0.001, "Rotating never resizes a material")
		t.assert_eq(document.material_cost(), cost, "Free rotation does not buy or resize materials")
		var restored: Document = Document.new()
		t.assert_true(restored.restore(JSON.parse_string(JSON.stringify(document.serialize()))), "Arbitrary angles survive validated saves including asymmetric right trapezoids")
		t.assert_eq(restored.parts, document.parts, "Reloading preserves actual rotated vertices")
		document.undo()
		t.assert_eq(document.get_selected().vertices, vertices, "One undo restores exact original geometry")
		document.redo()
		t.assert_eq(document.get_selected().vertices, rotated, "Redo restores the chosen angle")
		history = document.command_manager.undo_stack.size()
		t.assert_true(document.rotate_selected(360.0), "A full turn is a successful no-op")
		t.assert_eq(document.command_manager.undo_stack.size(), history, "A full turn does not pollute undo history")
		t.assert_false(document.rotate_selected(NAN), "Nonfinite rotation is rejected")
		t.assert_eq(document.get_selected().vertices, rotated, "Invalid rotation leaves geometry intact")
	var boundary: Document = Document.new()
	boundary.add_part("wall", Vector2(60, 530))
	var before: Dictionary = boundary.serialize()
	t.assert_false(boundary.rotation_error(37.0).is_empty(), "Preview detects a rotated corner crossing the foundation")
	t.assert_false(boundary.rotate_selected(37.0), "The model refuses rotation outside the enlarged lot")
	t.assert_eq(boundary.serialize(), before, "Rejected rotation preserves the document atomically")
	boundary.editing_enabled = false
	t.assert_false(boundary.rotate_selected(15.0), "Finalized houses cannot rotate materials")

static func _test_pointer_rotation(t: Node) -> void:
	var canvas: Canvas = await _canvas(t)
	var document: Document = canvas.document
	var material_id: String = Custom.make_id("rectangle", Vector2(160, 80), "wood", "checks", "wall")
	var id: int = document.add_part(material_id, Vector2(1000, 40))
	canvas._place_anims.clear()
	var original: PackedVector2Array = document.get_selected().vertices
	var history: int = document.command_manager.undo_stack.size()
	canvas.choose_material("brick")
	_pointer(canvas, Vector2(1000, 40), true)
	_pointer(canvas, Vector2(1000, 40), false)
	t.assert_eq(document.selected_id, id, "Clicking a built material selects it directly from placement mode")
	t.assert_false(canvas.drawing_tool, "Direct selection switches off placement and highlights the placed material")
	t.assert_eq(document.parts.size(), 1, "Selecting a built material does not buy a new one")
	t.assert_eq(document.command_manager.undo_stack.size(), history, "A plain selection click does not add a move command")
	var center: Vector2 = Vector2(document.get_selected().position)
	var edge: Vector2 = original[1].lerp(original[2], 0.5)
	_pointer(canvas, center + edge, true)
	t.assert_true(canvas._rotating and not canvas._dragging, "Dragging a selected edge starts rotation instead of movement")
	for degrees: float in [10.0, 20.0, 37.25]:
		_motion(canvas, center + edge.rotated(deg_to_rad(degrees)))
		t.assert_eq(document.get_selected().vertices, original, "Drag preview keeps authoritative geometry untouched")
		t.assert_eq(document.command_manager.undo_stack.size(), history, "Intermediate drag frames create no undo entries")
	t.assert_float_approx(canvas._rotation_degrees, 37.25, 0.001, "Pointer movement produces a continuous arbitrary angle")
	t.assert_false(canvas._part_gizmo.visible, "The button panel stays out of the active rotation gesture")
	_pointer(canvas, center + edge.rotated(deg_to_rad(37.25)), false)
	t.assert_false(canvas._rotating, "Releasing the edge ends rotation")
	t.assert_eq(document.command_manager.undo_stack.size(), history + 1, "One entire drag creates exactly one undo command")
	_assert_vertices(t, document.get_selected().vertices, Math.rotate_vertices(original, 37.25), "Free-angle release commits actual rotated vertices")
	t.assert_eq(document.get_selected().position, center, "Free rotation keeps the material's position")
	document.undo()
	t.assert_eq(document.get_selected().vertices, original, "Ctrl+Z can restore the complete drag in one step")
	document.redo()
	var handle: Vector2 = canvas.screen_to_artwork(canvas._rotation_handle_screen(document.get_selected()))
	_pointer(canvas, handle, true)
	t.assert_true(canvas._rotating, "The visible round handle also starts rotation")
	_motion(canvas, center + (handle - center).rotated(deg_to_rad(9.0)), true)
	_pointer(canvas, center + (handle - center).rotated(deg_to_rad(9.0)), false, true)
	var selected_vertices: PackedVector2Array = document.get_selected().vertices
	t.assert_float_approx(rad_to_deg((selected_vertices[1] - selected_vertices[0]).angle()), 45.0, 0.001, "Shift snaps the absolute orientation to 15 degrees after a prior arbitrary rotation")
	# Cross the -180/180 boundary with successive pointer events.
	handle = canvas.screen_to_artwork(canvas._rotation_handle_screen(document.get_selected()))
	_pointer(canvas, handle, true)
	for degrees: float in [80.0, 160.0, 200.0, 280.0, 350.0]:
		_motion(canvas, center + (handle - center).rotated(deg_to_rad(degrees)))
	t.assert_float_approx(canvas._rotation_degrees, 350.0, 0.01, "A long drag unwraps the angle smoothly across the branch cut")
	_pointer(canvas, center + (handle - center).rotated(deg_to_rad(350.0)), false)
	canvas.select_tool()
	var before_move: PackedVector2Array = document.get_selected().vertices
	_pointer(canvas, center, true)
	_motion(canvas, center + Vector2(40, 20))
	_pointer(canvas, center + Vector2(40, 20), false)
	t.assert_eq(document.get_selected().position, center + Vector2(40, 20), "The body still drags to move the material")
	t.assert_eq(document.get_selected().vertices, before_move, "Body dragging never rotates or resizes the part")
	canvas.free()
	await t.get_tree().process_frame

static func _test_rejected_and_canceled_gestures(t: Node) -> void:
	var canvas: Canvas = await _canvas(t)
	var document: Document = canvas.document
	var id: int = document.add_part("wall", Vector2(1000, 40))
	document.add_part("wall", Vector2(1120, 40))
	document.select(id)
	canvas.select_tool()
	canvas._place_anims.clear()
	var original: Dictionary = document.serialize()
	var history: int = document.command_manager.undo_stack.size()
	var center: Vector2 = Vector2(document.get_selected().position)
	var handle: Vector2 = canvas.screen_to_artwork(canvas._rotation_handle_screen(document.get_selected()))
	_pointer(canvas, handle, true)
	_motion(canvas, center + (handle - center).rotated(deg_to_rad(45.0)))
	t.assert_false(canvas._rotation_error.is_empty(), "Preview detects overlap with the adjacent material")
	_pointer(canvas, center + (handle - center).rotated(deg_to_rad(45.0)), false)
	t.assert_eq(document.serialize(), original, "Releasing an overlapping rotation restores the original design")
	t.assert_eq(document.command_manager.undo_stack.size(), history, "Rejected rotation does not create an undo command")
	for key: Key in [KEY_ESCAPE, KEY_NONE]:
		document.select(id)
		canvas.select_tool()
		handle = canvas.screen_to_artwork(canvas._rotation_handle_screen(document.get_selected()))
		_pointer(canvas, handle, true)
		_motion(canvas, center + (handle - center).rotated(0.1))
		if key == KEY_ESCAPE:
			var event: InputEventKey = InputEventKey.new()
			event.keycode = key
			event.pressed = true
			canvas._gui_input(event)
		else:
			var event: InputEventMouseButton = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_RIGHT
			event.pressed = true
			canvas._gui_input(event)
		_pointer(canvas, handle, false)
		t.assert_true(canvas.pan_tool and not canvas._rotating, "Esc and right click cancel rotation and permit screen movement")
		t.assert_eq(document.parts, original_to_parts(original), "Canceled preview and its later release leave geometry intact")
		t.assert_eq(document.command_manager.undo_stack.size(), history, "Canceling rotation leaves history intact")
	canvas.select_tool()
	document.select(id)
	handle = canvas.screen_to_artwork(canvas._rotation_handle_screen(document.get_selected()))
	_pointer(canvas, handle, true)
	document.select(int(document.parts[1].id))
	t.assert_false(canvas._rotating, "Changing selection cancels an unfinished rotation")
	_pointer(canvas, handle, false)
	t.assert_eq(document.command_manager.undo_stack.size(), history, "A stale release cannot rotate the newly selected part")
	document.select(id)
	_pointer(canvas, handle, true)
	document.undo()
	t.assert_false(canvas._rotating, "Undo during a gesture cancels the stale preview")
	var after_undo: Dictionary = document.serialize()
	_pointer(canvas, handle, false)
	t.assert_eq(document.serialize(), after_undo, "Release after undo cannot restore removed geometry")
	canvas.inspection_visible = true
	t.assert_false(canvas._rotation_hit(handle), "Inspection view never exposes editing hit targets")
	canvas.free()
	await t.get_tree().process_frame

static func original_to_parts(snapshot: Dictionary) -> Array[Dictionary]:
	var restored: Document = Document.new()
	restored.restore(snapshot)
	return restored.parts

static func _test_small_material_edges(t: Node) -> void:
	var canvas: Canvas = await _canvas(t)
	canvas.zoom = 1.0
	canvas.document.add_part("brick", Vector2(1000, 40))
	canvas.select_tool()
	var center: Vector2 = Vector2(canvas.document.get_selected().position)
	var vertices: PackedVector2Array = canvas.document.get_selected().vertices
	for index: int in range(4):
		var edge: Vector2 = vertices[index].lerp(vertices[(index + 1) % 4], 0.5)
		_pointer(canvas, center + edge, true)
		t.assert_true(canvas._rotating, "Every edge remains a rotation target on a zoomed-out single brick")
		_motion(canvas, center + edge.rotated(deg_to_rad(25.0)))
		t.assert_float_approx(canvas._rotation_degrees, 25.0, 0.001, "Small edge gestures are not swallowed by the rotation-center dead zone")
		canvas.cancel_gesture()
	_pointer(canvas, center, true)
	t.assert_true(canvas._dragging and not canvas._rotating, "A small material's center still starts body movement")
	canvas.cancel_gesture()
	canvas.free()
	await t.get_tree().process_frame

static func _canvas(t: Node) -> Canvas:
	var canvas: Canvas = Canvas.new()
	canvas.document = Document.new()
	canvas.size = Vector2(1000, 650)
	t.add_child(canvas)
	for frame: int in range(3): await t.get_tree().process_frame
	canvas.zoom = 3.0
	canvas.pan = Vector2.ZERO
	return canvas

static func _pointer(canvas: Canvas, point: Vector2, pressed: bool, shift: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = canvas.artwork_to_screen(point)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.shift_pressed = shift
	canvas._gui_input(event)

static func _motion(canvas: Canvas, point: Vector2, shift: bool = false) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = canvas.artwork_to_screen(point)
	event.shift_pressed = shift
	canvas._gui_input(event)

static func _assert_vertices(t: Node, actual: PackedVector2Array, expected: PackedVector2Array, message: String) -> void:
	for index: int in range(4): t.assert_true(actual[index].distance_to(expected[index]) < 0.001, message)
