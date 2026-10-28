class_name TestDrawingGestures
extends RefCounted

const Model = preload("res://scripts/core/drawing_document.gd")
const Canvas = preload("res://scenes/drawing/drawing_canvas.gd")

static func run(t: Node) -> void:
	for kind: String in QuadrilateralMath.KINDS:
		for rotation: float in [0.0, 37.0]:
			_test_resize(t, kind, rotation)
	_test_rotation(t)
	_test_snapping(t)
	_test_resize_snap(t)
	_test_bounds_and_cancel(t)
	_test_small_shape_move(t)
	await t.get_tree().process_frame

static func _new_canvas(t: Node) -> Canvas:
	var canvas: Canvas = Canvas.new()
	canvas.document = Model.new()
	canvas.size = Vector2(992, 632)
	t.add_child(canvas)
	canvas.select_tool()
	return canvas

static func _test_resize(t: Node, kind: String, rotation: float) -> void:
	var canvas: Canvas = _new_canvas(t)
	canvas.snap_enabled = false
	canvas.document.add_sized_shape(kind, Vector2(-120, 0), Vector2(120, 80), Color.CORAL)
	canvas.document.rotate_selected(rotation)
	var original: Dictionary = canvas.document.get_selected()
	var original_sides: PackedFloat32Array = QuadrilateralMath.side_lengths(original.vertices)
	var vertices: PackedVector2Array = original.vertices
	for mode: String in ["edge", "vertex"]:
		var press: Vector2 = Vector2(original.position) + (vertices[1] if mode == "vertex" else (vertices[0] + vertices[1]) * 0.5)
		var anchor: Vector2 = Vector2(original.position) + (vertices[3] if mode == "vertex" else (vertices[2] + vertices[3]) * 0.5)
		var end: Vector2 = anchor + (press - anchor) * 1.4
		var history: int = canvas.document.command_manager.undo_stack.size()
		_pointer(canvas, press, true)
		t.assert_true(canvas._resizing, "Edge or corner starts proportional resizing: %s/%s/%s" % [kind, rotation, mode])
		_motion(canvas, end)
		t.assert_eq(canvas.document.get_selected(), original, "Resize preview never mutates the document")
		t.assert_eq(canvas.document.command_manager.undo_stack.size(), history, "Resize preview keeps history untouched")
		var preview: Dictionary = canvas.preview_selected()
		t.assert_true(QuadrilateralMath.matches_kind(preview.vertices, kind), "Resize preview preserves selected family")
		var sides: PackedFloat32Array = canvas.displayed_side_lengths()
		for index: int in range(4):
			t.assert_float_approx(sides[index], original_sides[index] * 1.4, 0.002, "Every live side label follows uniform scale")
		var preview_vertices: PackedVector2Array = preview.vertices
		var fixed: Vector2 = Vector2(preview.position) + (preview_vertices[3] if mode == "vertex" else (preview_vertices[2] + preview_vertices[3]) * 0.5)
		t.assert_true(fixed.distance_to(anchor) < 0.002, "Opposite corner or edge stays anchored")
		_pointer(canvas, end, false)
		t.assert_eq(canvas.document.command_manager.undo_stack.size(), history + 1, "Whole resize commits exactly one undo command")
		canvas.document.undo()
		t.assert_eq(canvas.document.get_selected(), original, "One undo restores vertices and position together")
	canvas.free()

static func _test_rotation(t: Node) -> void:
	var canvas: Canvas = _new_canvas(t)
	canvas.document.add_sized_shape("rectangle", Vector2(30, 20), Vector2(180, 100), Color.GOLD)
	var original: Dictionary = canvas.document.get_selected()
	var sides: PackedFloat32Array = canvas.displayed_side_lengths()
	var handle: Vector2 = canvas.rotation_handle_position()
	var end: Vector2 = Vector2(original.position) + (handle - Vector2(original.position)).rotated(deg_to_rad(42.0))
	var history: int = canvas.document.command_manager.undo_stack.size()
	_pointer(canvas, handle, true)
	t.assert_true(canvas._rotating, "Visible circular handle starts a rotation drag")
	_motion(canvas, end)
	t.assert_eq(canvas.document.get_selected(), original, "Rotation preview leaves original artwork intact")
	t.assert_eq(canvas.document.command_manager.undo_stack.size(), history, "Rotation preview creates no intermediate commands")
	var preview: Dictionary = canvas.preview_selected()
	var expected: PackedVector2Array = QuadrilateralMath.rotate_vertices(original.vertices, 42.0)
	for index: int in range(4):
		t.assert_true(Vector2(preview.vertices[index]).distance_to(expected[index]) < 0.002, "Rotation preview follows pointer angle")
		t.assert_float_approx(canvas.displayed_side_lengths()[index], sides[index], 0.002, "Side length labels do not change while rotating")
	_pointer(canvas, end, false)
	t.assert_eq(canvas.document.command_manager.undo_stack.size(), history + 1, "Rotation drag is one undo command")
	canvas.document.undo()
	t.assert_eq(canvas.document.get_selected(), original, "Undo rotation restores the original family and position")
	_pointer(canvas, handle, true)
	_motion(canvas, end, true)
	_pointer(canvas, end, false, true)
	var snapped: PackedVector2Array = canvas.document.get_selected().vertices
	expected = QuadrilateralMath.rotate_vertices(original.vertices, 45.0)
	t.assert_true(snapped[0].distance_to(expected[0]) < 0.002, "Shift rotates in 15-degree increments")
	canvas.free()

static func _test_snapping(t: Node) -> void:
	var canvas: Canvas = _new_canvas(t)
	var moving_id: int = canvas.document.add_sized_shape("square", Vector2.ZERO, Vector2(100, 100), Color.CORAL)
	canvas.document.add_sized_shape("square", Vector2(200, 0), Vector2(100, 100), Color.GOLD)
	canvas.document.select_shape(moving_id)
	_pointer(canvas, Vector2.ZERO, true)
	_motion(canvas, Vector2(104, 0))
	t.assert_true(canvas._snap_active, "Nearby vertices produce a visible snap guide")
	t.assert_eq(canvas.preview_selected().position, Vector2(100, 0), "Nearby vertices meet at exactly the same point")
	_pointer(canvas, Vector2(104, 0), false)
	t.assert_eq(canvas.document.get_selected().position, Vector2(100, 0), "Release commits the snapped preview position")
	canvas.document.undo()
	canvas.snap_enabled = false
	_pointer(canvas, Vector2.ZERO, true)
	_motion(canvas, Vector2(104, 0))
	t.assert_false(canvas._snap_active, "Snap switch disables snap guides")
	t.assert_eq(canvas.preview_selected().position, Vector2(104, 0), "Disabled snap allows a precise free position")
	canvas.cancel_gesture()
	canvas.snap_enabled = true
	_pointer(canvas, Vector2.ZERO, true)
	_motion(canvas, Vector2(104, 0), false, true)
	t.assert_eq(canvas.preview_selected().position, Vector2(104, 0), "Alt temporarily bypasses snapping")
	canvas.cancel_gesture()
	canvas.document.clear()
	moving_id = canvas.document.add_sized_shape("square", Vector2.ZERO, Vector2(100, 100), Color.CORAL)
	canvas.document.add_sized_shape("rectangle", Vector2(200, 0), Vector2(100, 200), Color.GOLD)
	canvas.document.select_shape(moving_id)
	_pointer(canvas, Vector2.ZERO, true)
	_motion(canvas, Vector2(104, 30))
	t.assert_true(canvas._snap_active and canvas._snap_edge.size() == 2, "Vertex approaching the middle of another edge highlights that edge")
	t.assert_true(Vector2(canvas.preview_selected().position).distance_to(Vector2(100, 30)) < 0.001, "Edge snap uses the perpendicular closest point")
	canvas.cancel_gesture()
	canvas.free()

static func _test_resize_snap(t: Node) -> void:
	var canvas: Canvas = _new_canvas(t)
	var moving_id: int = canvas.document.add_sized_shape("square", Vector2.ZERO, Vector2(100, 100), Color.CORAL)
	canvas.document.add_sized_shape("rectangle", Vector2(180, 0), Vector2(60, 260), Color.GOLD)
	canvas.document.select_shape(moving_id)
	_pointer(canvas, Vector2(50, 0), true)
	_motion(canvas, Vector2(146, 0))
	t.assert_true(canvas._snap_active, "Proportional resizing also snaps a moving vertex to another edge")
	var preview: Dictionary = canvas.preview_selected()
	var vertices: PackedVector2Array = preview.vertices
	t.assert_float_approx(vertices[1].x + Vector2(preview.position).x, 150.0, 0.001, "Resize meets target edge exactly while keeping proportions")
	t.assert_true(QuadrilateralMath.matches_kind(vertices, "square"), "Resize snapping never deforms a square")
	canvas.free()

static func _test_bounds_and_cancel(t: Node) -> void:
	var canvas: Canvas = _new_canvas(t)
	canvas.snap_enabled = false
	canvas.document.add_sized_shape("rectangle", Vector2(300, 180), Vector2(160, 100), Color.SKY_BLUE)
	var original: Dictionary = canvas.document.get_selected()
	var history: int = canvas.document.command_manager.undo_stack.size()
	var press: Vector2 = Vector2(original.position) + Vector2(80, 0)
	_pointer(canvas, press, true)
	_motion(canvas, Vector2(2000, 180))
	var preview: Dictionary = canvas.preview_selected()
	var bounds: Rect2 = QuadrilateralMath.bounds(preview.vertices)
	bounds.position += Vector2(preview.position)
	t.assert_true(Model.ARTBOARD.grow(0.01).encloses(bounds), "Oversized drag stops at the artboard without distorting its ratio")
	canvas.cancel_gesture()
	_pointer(canvas, Vector2(2000, 180), false)
	t.assert_eq(canvas.document.get_selected(), original, "Canceled resize keeps artwork untouched after later release")
	t.assert_eq(canvas.document.command_manager.undo_stack.size(), history, "Canceled resize never adds a history command")
	_pointer(canvas, press, true)
	_motion(canvas, Vector2(-1000, 180))
	preview = canvas.preview_selected()
	t.assert_true(QuadrilateralMath.is_valid(preview.vertices), "Dragging across the opposite edge never collapses or crosses a shape")
	for side: float in canvas.displayed_side_lengths():
		t.assert_ge(side, 4.0, "Minimum size keeps all sides nondegenerate")
	canvas.cancel_gesture()
	var handle: Vector2 = canvas.rotation_handle_position()
	_pointer(canvas, handle, true)
	_motion(canvas, Vector2(original.position) + (handle - Vector2(original.position)).rotated(0.4))
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	canvas._gui_input(escape)
	_pointer(canvas, press, false)
	t.assert_eq(canvas.document.get_selected(), original, "Escape cancels a rotation preview without changing the drawing")
	canvas.free()

static func _test_small_shape_move(t: Node) -> void:
	for zoom: float in [1.0, 0.3]:
		for kind: String in QuadrilateralMath.KINDS:
			for shrink: bool in [false, true]:
				var canvas: Canvas = _new_canvas(t)
				canvas.snap_enabled = false
				canvas.size = Model.ARTBOARD.size * zoom + Vector2(32, 32)
				canvas.document.add_sized_shape(kind, Vector2(-80, -50), Vector2(12, 12), Color.CORAL)
				if shrink:
					var minimum: float = INF
					for side: float in canvas.displayed_side_lengths():
						minimum = minf(minimum, side)
					canvas.document.scale_selected(4.1 / minimum)
				canvas.document.rotate_selected(37.0)
				var original: Dictionary = canvas.document.get_selected()
				var vertices: PackedVector2Array = original.vertices
				var center: Vector2 = Vector2(original.position)
				for vertex: Vector2 in vertices:
					center += vertex * 0.25
				var history: int = canvas.document.command_manager.undo_stack.size()
				_pointer(canvas, center, true)
				t.assert_true(canvas._dragging and not canvas._resizing, "Tiny %s center at zoom %.1f starts a body move" % [kind, zoom])
				_motion(canvas, center + Vector2(60, 30))
				t.assert_eq(canvas.preview_selected().vertices, vertices, "Moving a tiny shape preserves its exact vertices")
				_pointer(canvas, center + Vector2(60, 30), false)
				t.assert_true(Vector2(canvas.document.get_selected().position).distance_to(Vector2(original.position) + Vector2(60, 30)) < 0.001, "Tiny shape body drag follows pointer at either canvas scale")
				t.assert_eq(canvas.document.get_selected().vertices, vertices, "Tiny body drag commits movement without resizing")
				t.assert_eq(canvas.document.command_manager.undo_stack.size(), history + 1, "Tiny body drag remains one undo command")
				canvas.document.undo()
				t.assert_eq(canvas.document.get_selected(), original, "Undo tiny body drag restores complete shape")
				var corner: Vector2 = Vector2(original.position) + vertices[0]
				t.assert_eq(str(canvas._selected_handle_at(corner).get("mode", "")), "vertex", "Exact tiny corner keeps its resize hotspot")
				var midpoint: Vector2 = Vector2(original.position) + (vertices[0] + vertices[1]) * 0.5
				t.assert_eq(str(canvas._selected_handle_at(midpoint).get("mode", "")), "edge", "Exact tiny edge midpoint keeps its own resize hotspot")
				canvas.free()

static func _pointer(canvas: Canvas, point: Vector2, pressed: bool, shift: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.shift_pressed = shift
	event.position = canvas.artwork_to_screen(point)
	canvas._gui_input(event)

static func _motion(canvas: Canvas, point: Vector2, shift: bool = false, alt: bool = false) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = canvas.artwork_to_screen(point)
	event.shift_pressed = shift
	event.alt_pressed = alt
	canvas._gui_input(event)
