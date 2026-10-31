class_name DrawingCanvas
extends Control

const Model = preload("res://scripts/core/drawing_document.gd")
const Catalog = preload("res://scripts/core/drawing_catalog.gd")
const HANDLE_RADIUS: float = 10.0
const SNAP_DISTANCE: float = 10.0
const MIN_SIDE: float = 4.1

signal hint_requested(message: String)
signal tool_changed

var document: Model
var selected_kind: String = "square"
var paint_color: Color = Color("29a995")
var drawing_tool: bool = true
var show_grid: bool = true
var snap_enabled: bool = true
var show_masterpiece: bool = true
var masterpiece_opacity: float = 0.65
var _background_path: String = ""
var _masterpiece_path: String = ""
var _background_texture: Texture2D
var _masterpiece_texture: Texture2D
var _creating: bool = false
var _dragging: bool = false
var _resizing: bool = false
var _rotating: bool = false
var _press_position: Vector2 = Vector2.ZERO
var _drag_position: Vector2 = Vector2.ZERO
var _drag_origin: Vector2 = Vector2.ZERO
var _drag_id: int = -1
var _origin_vertices: PackedVector2Array = PackedVector2Array()
var _preview_vertices: PackedVector2Array = PackedVector2Array()
var _resize_anchor: Vector2 = Vector2.ZERO
var _resize_vector: Vector2 = Vector2.ZERO
var _snap_active: bool = false
var _snap_from: Vector2 = Vector2.ZERO
var _snap_to: Vector2 = Vector2.ZERO
var _snap_edge: PackedVector2Array = PackedVector2Array()
var _hover: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	if document == null:
		document = Model.new()
	document.changed.connect(_document_changed)
	_sync_scene_textures()
	resized.connect(queue_redraw)
	visibility_changed.connect(cancel_gesture)
	mouse_exited.connect(func():
		_hover.clear()
		queue_redraw())

func canvas_scale() -> float:
	return maxf(0.01, minf((size.x - 32.0) / Model.ARTBOARD.size.x, (size.y - 32.0) / Model.ARTBOARD.size.y))

func artwork_to_screen(point: Vector2) -> Vector2:
	return size * 0.5 + point * canvas_scale()

func screen_to_artwork(point: Vector2) -> Vector2:
	return (point - size * 0.5) / canvas_scale()

func select_kind(kind: String) -> void:
	if not QuadrilateralMath.KINDS.has(kind):
		return
	cancel_gesture()
	selected_kind = kind
	drawing_tool = true
	if document != null:
		document.select_shape(-1)
	tool_changed.emit()
	queue_redraw()

func select_tool() -> void:
	cancel_gesture()
	drawing_tool = false
	tool_changed.emit()
	queue_redraw()

func add_at_center() -> void:
	cancel_gesture()
	var new_id: int = document.add_shape(selected_kind, Vector2.ZERO, paint_color)
	if new_id < 0:
		hint_requested.emit("도형은 최대 128개까지 그릴 수 있어요.")
	select_tool()

func cancel_gesture() -> void:
	_creating = false
	_dragging = false
	_resizing = false
	_rotating = false
	_snap_active = false
	_preview_vertices = PackedVector2Array()
	_hover.clear()
	queue_redraw()

func _has_transform_gesture() -> bool:
	return _dragging or _resizing or _rotating

func _document_changed() -> void:
	if _has_transform_gesture() and document.selected_id != _drag_id:
		cancel_gesture()
	_sync_scene_textures()
	queue_redraw()

func _sync_scene_textures() -> void:
	var background: Dictionary = Catalog.background(document.background_id)
	var path: String = str(background.get("path", ""))
	if path != _background_path:
		_background_path = path
		_background_texture = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
	var masterpiece: Dictionary = Catalog.masterpiece(document.masterpiece_id)
	path = str(masterpiece.get("path", ""))
	if path != _masterpiece_path:
		_masterpiece_path = path
		_masterpiece_texture = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null

func _gui_input(event: InputEvent) -> void:
	if document == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = screen_to_artwork(event.position)
		if event.pressed:
			var handle: Dictionary = _selected_handle_at(point)
			if not Model.ARTBOARD.has_point(point) and handle.is_empty():
				return
			if is_inside_tree():
				grab_focus()
			_press(point)
		else:
			_release(point, event.shift_pressed, event.alt_pressed)
		accept_event()
	elif event is InputEventMouseMotion:
		var point: Vector2 = screen_to_artwork(event.position)
		_update_gesture(point, event.shift_pressed, event.alt_pressed)
		_update_hover(point)
		queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			cancel_gesture()
			accept_event()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and not document.get_selected().is_empty():
			cancel_gesture()
			var direction: Vector2 = Vector2.ZERO
			match event.keycode:
				KEY_LEFT: direction = Vector2.LEFT
				KEY_RIGHT: direction = Vector2.RIGHT
				KEY_UP: direction = Vector2.UP
				KEY_DOWN: direction = Vector2.DOWN
			document.move_selected(Vector2(document.get_selected().position) + direction * (10.0 if event.shift_pressed else 2.0))
			accept_event()

func _press(point: Vector2) -> void:
	var handle: Dictionary = _selected_handle_at(point)
	cancel_gesture()
	_press_position = point
	_drag_position = point
	if drawing_tool:
		_creating = true
		queue_redraw()
		return
	var id: int = int(handle.get("id", _shape_at(point)))
	document.select_shape(id)
	if id < 0:
		queue_redraw()
		return
	var selected: Dictionary = document.get_selected()
	_drag_id = id
	_drag_origin = selected.position
	_drag_position = _drag_origin
	_origin_vertices = selected.vertices.duplicate()
	_preview_vertices = _origin_vertices.duplicate()
	if handle.is_empty():
		handle = _edge_handle(selected, point)
	var mode: String = str(handle.get("mode", "move"))
	if mode == "rotate":
		_rotating = true
		hint_requested.emit("회전 손잡이로 방향을 바꿔요. Shift를 누르면 15°씩 회전해요.")
	elif mode in ["edge", "vertex"]:
		_resizing = true
		var index: int = int(handle.index)
		var anchor: Vector2 = _origin_vertices[(index + 2) % 4]
		if mode == "edge":
			anchor = (_origin_vertices[(index + 2) % 4] + _origin_vertices[(index + 3) % 4]) * 0.5
		_resize_anchor = _drag_origin + anchor
		_resize_vector = point - _resize_anchor
		hint_requested.emit("가장자리를 끌면 비율을 유지하며 커지고 작아져요. Esc로 취소해요.")
	else:
		_dragging = true
	queue_redraw()

func _release(point: Vector2, shift: bool = false, alt: bool = false) -> void:
	if _creating:
		var end: Vector2 = point.clamp(Model.ARTBOARD.position, Model.ARTBOARD.end)
		var extent: Vector2 = (end - _press_position).abs()
		var center: Vector2 = (_press_position + end) * 0.5
		if extent.length() < 8.0:
			extent = Vector2(100, 80)
			center = _press_position
		var new_id: int = document.add_sized_shape(selected_kind, center, extent, paint_color)
		if new_id < 0:
			hint_requested.emit("도형은 최대 128개까지 그릴 수 있어요.")
		select_tool()
	elif _has_transform_gesture():
		_update_gesture(point, shift, alt)
		var vertices: PackedVector2Array = _preview_vertices.duplicate()
		var position: Vector2 = _drag_position
		var was_transform: bool = _resizing or _rotating
		# Commit once only after the full gesture preview has finished.
		cancel_gesture()
		if was_transform:
			document.transform_selected(vertices, position)
		else:
			document.move_selected(position)
	cancel_gesture()

func _update_gesture(point: Vector2, shift: bool = false, alt: bool = false) -> void:
	_snap_active = false
	_snap_edge = PackedVector2Array()
	if _creating:
		_drag_position = point.clamp(Model.ARTBOARD.position, Model.ARTBOARD.end)
	elif _dragging:
		_drag_position = Model.fitted_position(_origin_vertices, _drag_origin + point - _press_position)
		if snap_enabled and not alt:
			_drag_position = _snapped_position(_origin_vertices, _drag_position)
	elif _resizing:
		_update_resize(point, snap_enabled and not alt)
	elif _rotating:
		var start: Vector2 = _press_position - _drag_origin
		var direction: Vector2 = point - _drag_origin
		if direction.length_squared() < 0.01:
			return
		var degrees: float = rad_to_deg(start.angle_to(direction))
		if shift:
			degrees = snappedf(degrees, 15.0)
		var vertices: PackedVector2Array = QuadrilateralMath.rotate_vertices(_origin_vertices, degrees)
		var bounds: Rect2 = QuadrilateralMath.bounds(vertices)
		if bounds.size.x <= Model.ARTBOARD.size.x and bounds.size.y <= Model.ARTBOARD.size.y:
			_preview_vertices = vertices
			_drag_position = Model.fitted_position(vertices, _drag_origin)

func _update_resize(point: Vector2, allow_snap: bool) -> void:
	if _resize_vector.length_squared() < 0.01:
		return
	var minimum: float = 0.001
	for side: float in QuadrilateralMath.side_lengths(_origin_vertices):
		minimum = maxf(minimum, MIN_SIDE / side)
	var maximum: float = _maximum_resize_factor()
	var factor: float = clampf((point - _resize_anchor).dot(_resize_vector) / _resize_vector.length_squared(), minimum, maximum)
	if allow_snap:
		factor = _snapped_resize_factor(factor, minimum, maximum)
	_preview_vertices = QuadrilateralMath.scale_vertices(_origin_vertices, factor)
	_drag_position = _resize_anchor + (_drag_origin - _resize_anchor) * factor

func _maximum_resize_factor() -> float:
	var maximum: float = 1000.0
	for vertex: Vector2 in _origin_vertices:
		var direction: Vector2 = _drag_origin + vertex - _resize_anchor
		for axis: int in range(2):
			if absf(direction[axis]) > 0.0001:
				var limit: float = Model.ARTBOARD.end[axis] if direction[axis] > 0.0 else Model.ARTBOARD.position[axis]
				maximum = minf(maximum, (limit - _resize_anchor[axis]) / direction[axis])
			if absf(vertex[axis]) > 0.0001:
				maximum = minf(maximum, 600.0 / absf(vertex[axis]))
	return maximum

func _snapped_position(vertices: PackedVector2Array, position: Vector2) -> Vector2:
	var best: float = SNAP_DISTANCE / canvas_scale()
	var correction: Vector2 = Vector2.ZERO
	var found_vertex: bool = false
	# Vertices take priority over edge proximity so corners meet precisely.
	for part: Dictionary in document.ordered_shapes():
		if int(part.id) == _drag_id:
			continue
		for target_local: Vector2 in part.vertices:
			var target: Vector2 = Vector2(part.position) + target_local
			for vertex: Vector2 in vertices:
				var source: Vector2 = position + vertex
				var distance: float = source.distance_to(target)
				if distance < best:
					best = distance
					correction = target - source
					_set_snap(source, target)
					found_vertex = true
	if not found_vertex:
		for part: Dictionary in document.ordered_shapes():
			if int(part.id) == _drag_id:
				continue
			var target_vertices: PackedVector2Array = part.vertices
			for index: int in range(4):
				var edge_start: Vector2 = Vector2(part.position) + target_vertices[index]
				var edge_end: Vector2 = Vector2(part.position) + target_vertices[(index + 1) % 4]
				for vertex: Vector2 in vertices:
					var source: Vector2 = position + vertex
					var target: Vector2 = Geometry2D.get_closest_point_to_segment(source, edge_start, edge_end)
					var distance: float = source.distance_to(target)
					if distance < best:
						best = distance
						correction = target - source
						_set_snap(source, target, PackedVector2Array([edge_start, edge_end]))
	if _snap_active:
		var fitted: Vector2 = Model.fitted_position(vertices, position + correction)
		if fitted.distance_to(position + correction) < 0.01:
			return fitted
		_snap_active = false
	return position

func _snapped_resize_factor(factor: float, minimum: float, maximum: float) -> float:
	var best: float = SNAP_DISTANCE / canvas_scale()
	var result: float = factor
	for vertex: Vector2 in _origin_vertices:
		var ray: Vector2 = _drag_origin + vertex - _resize_anchor
		if ray.length_squared() < 0.01:
			continue
		var source: Vector2 = _resize_anchor + ray * factor
		for part: Dictionary in document.ordered_shapes():
			if int(part.id) == _drag_id:
				continue
			var other: PackedVector2Array = part.vertices
			for index: int in range(4):
				var target: Vector2 = Vector2(part.position) + other[index]
				var candidate: float = (target - _resize_anchor).dot(ray) / ray.length_squared()
				var aligned: Vector2 = _resize_anchor + ray * candidate
				if candidate >= minimum and candidate <= maximum and aligned.distance_to(target) < 0.5 / canvas_scale() and source.distance_to(target) < best:
					best = source.distance_to(target)
					result = candidate
					_set_snap(source, aligned)
				var edge_end: Vector2 = Vector2(part.position) + other[(index + 1) % 4]
				var intersection: Variant = Geometry2D.segment_intersects_segment(_resize_anchor + ray * minimum, _resize_anchor + ray * maximum, target, edge_end)
				if intersection is Vector2 and source.distance_to(intersection) < best:
					best = source.distance_to(intersection)
					result = (Vector2(intersection) - _resize_anchor).dot(ray) / ray.length_squared()
					_set_snap(source, intersection, PackedVector2Array([target, edge_end]))
	return result

func _set_snap(source: Vector2, target: Vector2, edge: PackedVector2Array = PackedVector2Array()) -> void:
	_snap_active = true
	_snap_from = source
	_snap_to = target
	_snap_edge = edge

func _shape_at(point: Vector2) -> int:
	for index: int in range(document.shapes.size() - 1, -1, -1):
		var part: Dictionary = document.shapes[index]
		if QuadrilateralMath.contains_point(part.vertices, point - Vector2(part.position)) or not _edge_handle(part, point).is_empty():
			return int(part.id)
	return -1

func _edge_handle(part: Dictionary, point: Vector2) -> Dictionary:
	var vertices: PackedVector2Array = part.vertices
	var local: Vector2 = point - Vector2(part.position)
	var threshold: float = HANDLE_RADIUS / canvas_scale()
	var center: Vector2 = Vector2.ZERO
	for vertex: Vector2 in vertices:
		center += vertex * 0.25
	var clearance: float = INF
	for index: int in range(4):
		clearance = minf(clearance, center.distance_to(Geometry2D.get_closest_point_to_segment(center, vertices[index], vertices[(index + 1) % 4])))
	# Small shapes retain a central body target even when every point lies
	# within the usual screen-space handle radius. Exact edges stay outside it.
	if clearance <= threshold * 1.5 and local.distance_to(center) < minf(clearance * 0.5, 6.0 / canvas_scale()):
		return {}
	for index: int in range(4):
		var adjacent: float = minf(vertices[index].distance_to(vertices[(index + 1) % 4]), vertices[index].distance_to(vertices[(index + 3) % 4]))
		if local.distance_to(vertices[index]) <= minf(threshold, adjacent * 0.32):
			return {"id": int(part.id), "mode": "vertex", "index": index}
	for index: int in range(4):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(local, vertices[index], vertices[(index + 1) % 4])
		if local.distance_to(closest) <= threshold:
			return {"id": int(part.id), "mode": "edge", "index": index}
	return {}

func _selected_handle_at(point: Vector2) -> Dictionary:
	if drawing_tool or document == null:
		return {}
	var selected: Dictionary = document.get_selected()
	if selected.is_empty():
		return {}
	if point.distance_to(rotation_handle_position()) <= 13.0 / canvas_scale():
		return {"id": document.selected_id, "mode": "rotate"}
	return _edge_handle(selected, point)

func rotation_handle_position() -> Vector2:
	var selected: Dictionary = preview_selected()
	if selected.is_empty():
		return Vector2(INF, INF)
	var vertices: PackedVector2Array = selected.vertices
	for index: int in [0, 2, 1, 3]:
		var midpoint: Vector2 = (vertices[index] + vertices[(index + 1) % 4]) * 0.5
		var edge: Vector2 = vertices[(index + 1) % 4] - vertices[index]
		var outward: Vector2 = Vector2(edge.y, -edge.x).normalized() * signf(QuadrilateralMath.signed_area(vertices))
		var handle: Vector2 = Vector2(selected.position) + midpoint + outward * (68.0 / canvas_scale())
		if Rect2(Vector2(16, 16), size - Vector2(32, 32)).has_point(artwork_to_screen(handle)):
			return handle
	return Vector2(selected.position)

func preview_selected() -> Dictionary:
	var selected: Dictionary = document.get_selected() if document != null else {}
	if not selected.is_empty() and _has_transform_gesture() and int(selected.id) == _drag_id:
		selected.vertices = _preview_vertices.duplicate()
		selected.position = _drag_position
	return selected

func displayed_side_lengths() -> PackedFloat32Array:
	var selected: Dictionary = preview_selected()
	return QuadrilateralMath.side_lengths(selected.vertices) if not selected.is_empty() else PackedFloat32Array()

func _update_hover(point: Vector2) -> void:
	_hover = _selected_handle_at(point)
	if drawing_tool:
		mouse_default_cursor_shape = Control.CURSOR_CROSS
	elif _rotating or str(_hover.get("mode", "")) == "rotate":
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif _resizing or not _hover.is_empty():
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	elif _shape_at(point) >= 0:
		mouse_default_cursor_shape = Control.CURSOR_MOVE
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW

func _draw() -> void:
	draw_texture_rect(GameArt.drafting_paper(), Rect2(Vector2.ZERO, size), false, Color("e8efed"))
	var board: Rect2 = Rect2(artwork_to_screen(Model.ARTBOARD.position), Model.ARTBOARD.size * canvas_scale())
	draw_texture_rect(GameArt.drafting_paper(), board, false)
	if document != null:
		if _background_texture != null:
			draw_texture_rect(_background_texture, board, false)
		elif document.drawing_mode == "masterpiece":
			draw_rect(board, Color("fffdf7"))
		if document.drawing_mode == "masterpiece" and show_masterpiece and _masterpiece_texture != null:
			draw_texture_rect(_masterpiece_texture, board, false, Color(1, 1, 1, clampf(masterpiece_opacity, 0.0, 1.0)))
	if show_grid:
		for x: int in range(-460, 480, 20):
			for y: int in range(-280, 300, 20):
				draw_circle(artwork_to_screen(Vector2(x, y)), 0.8, Color("dfe8e3"))
	if document == null:
		return
	for part: Dictionary in document.ordered_shapes():
		var selected: bool = int(part.id) == document.selected_id
		var position: Vector2 = _drag_position if _has_transform_gesture() and selected else Vector2(part.position)
		var vertices: PackedVector2Array = _preview_vertices if _has_transform_gesture() and selected else part.vertices
		_draw_part(vertices, position, part.color, selected)
	if _creating:
		var extent: Vector2 = (_drag_position - _press_position).abs().max(Vector2(12, 12))
		var vertices: PackedVector2Array = QuadrilateralMath.create_vertices(selected_kind, extent)
		_draw_part(vertices, (_drag_position + _press_position) * 0.5, Color(paint_color, 0.6), false)
	var selected: Dictionary = preview_selected()
	if not selected.is_empty():
		_draw_selection(selected)
	if _snap_active:
		_draw_snap()
	draw_rect(board, Color("c9d9d1"), false, 1.0)
	if has_focus():
		draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), QuadTheme.TEAL, false, 2.0)

func _draw_part(vertices: PackedVector2Array, position: Vector2, color: Color, selected: bool) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for vertex: Vector2 in vertices:
		points.append(artwork_to_screen(position + vertex))
	draw_colored_polygon(points, color)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, QuadTheme.INK if selected else color.darkened(0.18), 2.5 if selected else 1.0, true)

func _draw_selection(part: Dictionary) -> void:
	var vertices: PackedVector2Array = part.vertices
	var position: Vector2 = part.position
	var lengths: PackedFloat32Array = QuadrilateralMath.side_lengths(vertices)
	var winding: float = signf(QuadrilateralMath.signed_area(vertices))
	var handle: Vector2 = artwork_to_screen(rotation_handle_position())
	var closest: Vector2 = Vector2.ZERO
	var distance: float = INF
	for index: int in range(4):
		var midpoint: Vector2 = artwork_to_screen(position + (vertices[index] + vertices[(index + 1) % 4]) * 0.5)
		if midpoint.distance_to(handle) < distance:
			distance = midpoint.distance_to(handle)
			closest = midpoint
	# Keep the connector behind the opaque measurement pills.
	draw_line(closest, handle, QuadTheme.TEAL, 1.5, true)
	for index: int in range(4):
		var first: Vector2 = artwork_to_screen(position + vertices[index])
		var second: Vector2 = artwork_to_screen(position + vertices[(index + 1) % 4])
		var midpoint: Vector2 = (first + second) * 0.5
		var edge: Vector2 = second - first
		var normal: Vector2 = Vector2(edge.y, -edge.x).normalized() * winding
		var hovered: bool = int(_hover.get("index", -1)) == index and str(_hover.get("mode", "")) == "edge"
		if hovered:
			draw_line(first, second, QuadTheme.TEAL, 5.0, true)
		draw_circle(first, 5.0, Color.WHITE)
		draw_arc(first, 5.0, 0.0, TAU, 20, QuadTheme.INK, 1.5, true)
		draw_rect(Rect2(midpoint - Vector2(3.5, 3.5), Vector2(7, 7)), Color.WHITE)
		draw_rect(Rect2(midpoint - Vector2(3.5, 3.5), Vector2(7, 7)), QuadTheme.TEAL, false, 1.5)
		_draw_length_label(midpoint + normal * 23.0, QuadrilateralMath.measurement_label(lengths[index] / 20.0) + "칸")
	draw_circle(handle, 11.0, Color.WHITE)
	draw_arc(handle, 11.0, 0.0, TAU, 24, QuadTheme.TEAL, 2.0, true)
	draw_arc(handle, 5.5, -PI * 0.85, PI * 0.65, 18, QuadTheme.TEAL, 1.7, true)
	var arrow: Vector2 = handle + Vector2.from_angle(PI * 0.65) * 5.5
	draw_line(arrow, arrow + Vector2(0.5, -4.0), QuadTheme.TEAL, 1.7, true)
	draw_line(arrow, arrow + Vector2(4.0, -0.5), QuadTheme.TEAL, 1.7, true)

func _draw_length_label(center: Vector2, text: String) -> void:
	var font: Font = QuadTheme.FONT
	var font_size: int = 13
	var dimensions: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) + Vector2(10, 6)
	var top_left: Vector2 = (center - dimensions * 0.5).clamp(Vector2(3, 3), (size - dimensions - Vector2(3, 3)).max(Vector2(3, 3)))
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color("ffffffed")
	box.border_color = Color("b5cdc4")
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	draw_style_box(box, Rect2(top_left, dimensions))
	draw_string(font, top_left + Vector2(5, 3 + font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, QuadTheme.INK)

func _draw_snap() -> void:
	var source: Vector2 = artwork_to_screen(_snap_from)
	var target: Vector2 = artwork_to_screen(_snap_to)
	if _snap_edge.size() == 2:
		draw_line(artwork_to_screen(_snap_edge[0]), artwork_to_screen(_snap_edge[1]), QuadTheme.TEAL, 3.0, true)
	draw_dashed_line(source, target, QuadTheme.TEAL, 1.5, 4.0, true)
	draw_circle(target, 7.0, Color.WHITE)
	draw_arc(target, 7.0, 0.0, TAU, 24, QuadTheme.TEAL, 2.0, true)
	draw_line(target - Vector2(10, 0), target + Vector2(10, 0), QuadTheme.TEAL, 1.0, true)
	draw_line(target - Vector2(0, 10), target + Vector2(0, 10), QuadTheme.TEAL, 1.0, true)
