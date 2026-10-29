class_name TestDrawingStudio
extends RefCounted

const Model = preload("res://scripts/core/drawing_document.gd")
const Canvas = preload("res://scenes/drawing/drawing_canvas.gd")
const Studio = preload("res://scenes/drawing/drawing_studio.gd")

static func run(t: Node) -> void:
	_test_geometry_and_history(t)
	await _test_canvas(t)
	await _test_persistence(t)

static func _test_geometry_and_history(t: Node) -> void:
	var document: Model = Model.new()
	for kind: String in QuadrilateralMath.KINDS:
		var count: int = document.shapes.size()
		var id: int = document.add_sized_shape(kind, Vector2(count * 110 - 220, 0), Vector2(90, 110), Color.CORAL)
		t.assert_gt(id, 0, "Drawing creates each approved family: " + kind)
		var part: Dictionary = document.get_selected()
		t.assert_eq(part.slot_id, "", "Free drawings never attach to skeleton slots")
		t.assert_true(QuadrilateralMath.matches_kind(part.vertices, kind), "Drawn geometry matches family: " + kind)
		var original: Dictionary = part.duplicate(true)
		document.move_selected(Vector2(0, 180))
		document.rotate_selected(37)
		document.scale_selected(1.3)
		part = document.get_selected()
		t.assert_true(QuadrilateralMath.matches_kind(part.vertices, kind), "Drawing transforms preserve family: " + kind)
		var angle_sum: float = 0.0
		for angle: float in QuadrilateralMath.angles_degrees(part.vertices):
			angle_sum += angle
		t.assert_float_approx(angle_sum, 360.0, 0.01, "Drawing keeps convex quadrilateral angles")
		document.undo()
		document.undo()
		document.undo()
		t.assert_eq(document.get_selected(), original, "Undo restores complete shape before transforms")
		document.undo()
		t.assert_eq(document.shapes.size(), count, "Creation is a single undo operation")
		document.redo()
		t.assert_eq(document.shapes.size(), count + 1, "Redo restores created shape")
	var prior_order: Array[Dictionary] = document.ordered_shapes()
	document.shift_selected_layer(-1)
	t.assert_eq(document.ordered_shapes()[3].id, prior_order[4].id, "Layer move changes overlap ordering")
	document.undo()
	t.assert_eq(document.ordered_shapes(), prior_order, "Layer move is undoable")
	document.duplicate_selected()
	t.assert_eq(document.shapes.size(), 6, "Duplicate adds a separate free shape")
	document.delete_selected()
	t.assert_eq(document.shapes.size(), 5, "Delete removes only the selected shape")
	document.undo()
	t.assert_eq(document.shapes.size(), 6, "Undo deletion restores shape")
	document.move_selected(Vector2(2000, 2000))
	var selected: Dictionary = document.get_selected()
	var bounds: Rect2 = QuadrilateralMath.bounds(selected.vertices)
	bounds.position += Vector2(selected.position)
	t.assert_true(Model.ARTBOARD.encloses(bounds), "Moving keeps the whole shape inside the visible artboard")
	var snapshot: Dictionary = document.serialize()
	document.clear()
	t.assert_eq(document.shapes.size(), 0, "Clear removes all free drawing parts")
	document.undo()
	t.assert_eq(document.serialize(), snapshot, "Clear is completely undoable")
	var restored: Model = Model.new()
	t.assert_true(restored.restore(JSON.parse_string(JSON.stringify(snapshot))), "Free drawing JSON round trip preserves shapes")
	var before: String = JSON.stringify(restored.serialize())
	var invalid: Dictionary = snapshot.duplicate(true)
	invalid.shapes[0].vertices = [[0, 0], [1, 1], [2, 2], [3, 3]]
	t.assert_false(restored.restore(invalid), "Collapsed drawing geometry is rejected")
	t.assert_eq(JSON.stringify(restored.serialize()), before, "Rejected drawing restores are atomic")
	invalid = snapshot.duplicate(true)
	invalid.shapes[0].position = [1400, 1400]
	t.assert_false(restored.restore(invalid), "Off-artboard save cannot make artwork unreachable")
	t.assert_eq(document.add_sized_shape("triangle", Vector2.ZERO, Vector2(50, 50), Color.RED), -1, "Only five quadrilateral families are accepted")
	t.assert_eq(document.add_sized_shape("square", Vector2.ZERO, Vector2(INF, 50), Color.RED), -1, "Nonfinite creation dimensions are rejected")

static func _test_canvas(t: Node) -> void:
	var canvas: Canvas = Canvas.new()
	canvas.document = Model.new()
	canvas.size = Vector2(850, 550)
	t.add_child(canvas)
	await t.get_tree().process_frame
	canvas.select_kind("trapezoid")
	_send_pointer(canvas, Vector2(-180, -110), true)
	var history_before: int = canvas.document.command_manager.undo_stack.size()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = canvas.artwork_to_screen(Vector2(20, 30))
	canvas._gui_input(motion)
	t.assert_eq(canvas.document.command_manager.undo_stack.size(), history_before, "Creation preview does not mutate undo history")
	_send_pointer(canvas, Vector2(20, 30), false)
	t.assert_eq(canvas.document.shapes.size(), 1, "Pointer drag creates a free drawing shape")
	var selected: Dictionary = canvas.document.get_selected()
	var drawn_size: Vector2 = QuadrilateralMath.bounds(selected.vertices).size
	t.assert_float_approx(drawn_size.x, 200.0, 0.001, "Drag controls artwork width across canvas scaling")
	t.assert_float_approx(drawn_size.y, 140.0, 0.001, "Drag controls artwork height across canvas scaling")
	t.assert_false(canvas.drawing_tool, "After drawing, the created shape is ready to move")
	var start: Vector2 = selected.position
	_send_pointer(canvas, start, true)
	history_before = canvas.document.command_manager.undo_stack.size()
	motion.position = canvas.artwork_to_screen(start + Vector2(120, 70))
	canvas._gui_input(motion)
	t.assert_eq(canvas.document.command_manager.undo_stack.size(), history_before, "Move preview does not mutate undo history")
	_send_pointer(canvas, start + Vector2(120, 70), false)
	t.assert_eq(canvas.document.command_manager.undo_stack.size(), history_before + 1, "A full pointer drag creates exactly one undo entry")
	canvas.document.undo()
	t.assert_eq(canvas.document.get_selected().position, start, "Undo restores the whole pointer drag")
	canvas.select_kind("rhombus")
	t.assert_eq(canvas.document.selected_id, -1, "Choosing a new drawing tool releases the previous shape")
	_send_pointer(canvas, Vector2(200, 100), true)
	canvas.cancel_gesture()
	_send_pointer(canvas, Vector2(300, 200), false)
	t.assert_eq(canvas.document.shapes.size(), 1, "Canceled drawing cannot create a shape on later release")
	canvas.free()

static func _send_pointer(canvas: Canvas, point: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = canvas.artwork_to_screen(point)
	canvas._gui_input(event)

static func _test_persistence(t: Node) -> void:
	var studio: Studio = Studio.new()
	studio.testing = true
	var test_path: String = "res://.godot/drawing_studio_test_%d.json" % Time.get_ticks_usec()
	studio.save_path = test_path
	t.add_child(studio)
	await t.get_tree().process_frame
	studio.document.add_sized_shape("rectangle", Vector2(-100, 0), Vector2(180, 90), Color.BLUE)
	studio.document.add_sized_shape("rhombus", Vector2(100, 0), Vector2(70, 130), Color.GOLD)
	var saved: String = JSON.stringify(studio.document.serialize())
	t.assert_true(studio.save_drawing(false), "Independent drawing save succeeds")
	studio.document.clear()
	t.assert_true(studio.load_drawing(false), "Independent drawing save loads")
	t.assert_eq(JSON.stringify(studio.document.serialize()), saved, "Drawing save preserves color, order and geometry")
	var file: FileAccess = FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string('{"format":"quadrilateral-drawing","version":1,"document":{"version":1}}')
	file.close()
	t.assert_false(studio.load_drawing(false), "Malformed drawing file is rejected")
	t.assert_eq(JSON.stringify(studio.document.serialize()), saved, "Malformed file leaves current art intact")
	studio.hide()
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_DELETE
	key.pressed = true
	studio._unhandled_key_input(key)
	t.assert_eq(JSON.stringify(studio.document.serialize()), saved, "Hidden drawing page ignores editing shortcuts")
	studio.free()
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(test_path + suffix)
