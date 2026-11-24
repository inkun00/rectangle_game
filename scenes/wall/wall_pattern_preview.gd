extends Control

const Design = preload("res://scripts/core/wall_tile_design.gd")
const Geometry = preload("res://scripts/core/quadrilateral_math.gd")
const WallArt = preload("res://scenes/wall/wall_art.gd")

signal selection_changed(indices: Array[int])
signal context_requested(indices: Array[int], viewport_position: Vector2)
signal piece_placed(point: Vector2)
signal edited

const NO_POINTER: int = -2
const DRAG_DISTANCE: float = 4.0
const SNAP_DISTANCE: float = 10.0
const SELECTION_COLOR: Color = Color("#146e78")
const HANDLE_COLOR: Color = Color("#fbc773")

var design: Design
var view_kind: String = "blank"
var selected_indices: Array[int] = []
var placing: bool = false
var location: String = ""
var backdrop: Texture2D
var export_only: bool = false
var _pointer: int = NO_POINTER
var _gesture: String = ""
var _transform_mode: String = ""
var _grab: Vector2
var _cursor: Vector2
var _pivot: Vector2
var _direction: Vector2
var _offset: Vector2
var _degrees: float = 0.0
var _scale: float = 1.0
var _corner: int = -1
var _vertex_target: Vector2
var _additive: bool = false
var _invalid_preview: bool = false
var _preview_points: Dictionary[int, PackedVector2Array] = {}
var _draw_parts: Array[Dictionary] = []

func _ready() -> void:
	if not export_only: custom_minimum_size.y = 180
	focus_mode = Control.FOCUS_ALL if view_kind == "tile" else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if view_kind == "tile" else Control.MOUSE_FILTER_IGNORE
	accessibility_name = "타일 편집판. 빈 곳에서 끌어 여러 조각을 고르고, 방향키로 움직여요."
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	visibility_changed.connect(cancel_drag)
	refresh()

func background_path() -> String:
	return WallArt.path_for(location)

func set_location(id: String) -> void:
	location = id
	var path: String = background_path()
	backdrop = load(path) as Texture2D if ResourceLoader.exists(path) else null
	queue_redraw()

func refresh() -> void:
	if design != null:
		_draw_parts = design.wall_parts() if view_kind == "filled" else design.motif_parts()
		if view_kind == "tile": selected_indices = design.expand_selection(selected_indices)
	queue_redraw()

func _fit(dimensions: Vector2, area: Rect2) -> Rect2:
	var scale_factor: float = minf(area.size.x / dimensions.x, area.size.y / dimensions.y)
	var extent: Vector2 = dimensions * maxf(0.01, scale_factor)
	return Rect2(area.get_center() - extent * 0.5, extent)

func _sheet_rect() -> Rect2:
	return _fit(design.tile_size(), Rect2(Vector2.ZERO, size).grow(-12))

func _draw() -> void:
	if design == null: return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#152b37"))
	if view_kind == "tile":
		_draw_tile()
		return
	var image_size: Vector2 = backdrop.get_size() if backdrop != null else Vector2(16, 10)
	var picture: Rect2 = _fit(image_size, Rect2(Vector2.ZERO, size))
	if backdrop != null: draw_texture_rect(backdrop, picture, false)
	var normalized: Rect2 = WallArt.wall_rect(location)
	var area: Rect2 = Rect2(picture.position + normalized.position * picture.size, normalized.size * picture.size)
	if backdrop == null: draw_rect(area, Color("#d4c6ad"))
	if view_kind == "filled": _draw_wall(area)

func _draw_tile() -> void:
	var area: Rect2 = _sheet_rect()
	draw_rect(area, Color("#f8f0dc"))
	var factor: float = area.size.x / design.tile_size().x
	for x: int in range(0, ceili(design.tile_size().x), 10):
		var a: Vector2 = area.position + Vector2(x * factor, 0)
		draw_line(a, a + Vector2(0, area.size.y), Color("#d9d3bd"), 1)
	for y: int in range(0, ceili(design.tile_size().y), 10):
		var a: Vector2 = area.position + Vector2(0, y * factor)
		draw_line(a, a + Vector2(area.size.x, 0), Color("#d9d3bd"), 1)
	var to_screen: Transform2D = Transform2D(0.0, Vector2.ONE * factor, 0.0, area.position)
	for part: Dictionary in _draw_parts:
		var points: PackedVector2Array = to_screen * _vertices(int(part.index))
		draw_colored_polygon(points, part.color)
		points.append(points[0])
		draw_polyline(points, Color("#544f48"), 1.3, true)
	_draw_selection(to_screen)
	draw_rect(area, Color("#fbc773") if has_focus() else Color("#c9bd9d"), false, 2)

func _vertices(index: int) -> PackedVector2Array:
	return _preview_points.get(index, _draw_parts[index].vertices)

func _draw_selection(to_screen: Transform2D) -> void:
	var indices: Array[int] = _marquee_indices() if _gesture == "box" else selected_indices
	var stroke: Color = Color("#c24234") if _invalid_preview else SELECTION_COLOR
	for index: int in indices:
		if index < 0 or index >= _draw_parts.size(): continue
		var points: PackedVector2Array = to_screen * _vertices(index)
		points.append(points[0])
		draw_polyline(points, stroke, 3.0, true)
		if indices.size() == 1 and _transform_mode.is_empty() and _gesture != "box" and str(_draw_parts[index].kind) == Geometry.FREEFORM:
			for corner: int in range(4):
				draw_circle(points[corner], 5.0, Color.WHITE)
				draw_circle(points[corner], 3.0, stroke)
	if _gesture == "box":
		var marquee: Rect2 = Rect2(to_screen * _grab, to_screen * _cursor - to_screen * _grab).abs()
		draw_rect(marquee, Color(0.08, 0.43, 0.47, 0.14))
		draw_rect(marquee, SELECTION_COLOR, false, 1.5)
	elif not selected_indices.is_empty():
		var bounds: Rect2 = _selection_bounds(selected_indices)
		var screen_bounds: Rect2 = Rect2(to_screen * bounds.position, bounds.size * to_screen.x.x)
		if selected_indices.size() > 1 or not _transform_mode.is_empty():
			draw_rect(screen_bounds.grow(3.0), stroke, false, 1.5)
		if not _transform_mode.is_empty():
			_draw_transform_handle(screen_bounds, stroke)

func _draw_transform_handle(bounds: Rect2, stroke: Color) -> void:
	var handle: Vector2 = _transform_handle()
	var rotating: bool = _transform_mode == "rotate"
	var anchor: Vector2 = Vector2(bounds.get_center().x, bounds.position.y) if rotating else bounds.end
	draw_line(anchor, handle, stroke, 1.5, true)
	if rotating:
		draw_circle(handle, 10.0, stroke, true, -1.0, true)
		draw_circle(handle, 8.0, HANDLE_COLOR, true, -1.0, true)
		draw_arc(handle, 4.5, -PI * 0.4, PI * 1.15, 18, stroke, 1.5, true)
		draw_colored_polygon(PackedVector2Array([handle + Vector2(2, -6), handle + Vector2(6, -2), handle + Vector2(1, -1)]), stroke)
	else:
		draw_rect(Rect2(handle - Vector2(8, 8), Vector2(16, 16)), stroke)
		draw_rect(Rect2(handle - Vector2(6, 6), Vector2(12, 12)), HANDLE_COLOR)
		draw_line(handle - Vector2(4, 4), handle + Vector2(4, 4), stroke, 1.5, true)
	if _gesture in ["rotate", "resize"]:
		var measure: String = "%+.0f°" % _degrees if rotating else "%.0f%%" % (_scale * 100.0)
		if _invalid_preview: measure += " · 타일 경계"
		var font: Font = QuadTheme.FONT
		var metrics: Vector2 = font.get_string_size(measure, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		var sheet: Rect2 = _sheet_rect()
		var top_left: Vector2 = (handle + Vector2(12, -31)).clamp(sheet.position, sheet.end - metrics - Vector2(12, 8))
		draw_rect(Rect2(top_left, metrics + Vector2(12, 8)), Color("#152b37"))
		draw_string(font, top_left + Vector2(6, 4 + font.get_ascent(15)), measure, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

func _wall_grid_rect(area: Rect2) -> Rect2:
	var dimensions: Vector2 = design.wall_size()
	var factor: float = minf(area.size.x / dimensions.x, area.size.y / dimensions.y)
	var extent: Vector2 = dimensions * factor
	return Rect2(area.get_center() - extent * 0.5, extent)

func _draw_wall(area: Rect2) -> void:
	if area.size.x < 1.0 or area.size.y < 1.0: return
	# Fit the entire row/column layout at the same scale on both axes.
	var grid: Rect2 = _wall_grid_rect(area)
	var factor: float = grid.size.x / design.wall_size().x
	var transform: Transform2D = Transform2D(0.0, Vector2.ONE * factor, 0.0, grid.position)
	draw_rect(area, Color("#f8f0dc"))
	for part: Dictionary in _draw_parts:
		draw_colored_polygon(transform * PackedVector2Array(part.vertices), part.color)
	if not export_only:
		var cell: Vector2 = design.tile_size() * factor
		var line_color: Color = Color(0.3, 0.28, 0.24, 0.23)
		for x: int in range(1, design.columns):
			var a: Vector2 = grid.position + Vector2(x * cell.x, 0)
			draw_line(a, a + Vector2(0, grid.size.y), line_color, 1)
		for y: int in range(1, design.rows):
			var a: Vector2 = grid.position + Vector2(0, y * cell.y)
			draw_line(a, a + Vector2(grid.size.x, 0), line_color, 1)

func _to_tile(at: Vector2) -> Vector2:
	var sheet: Rect2 = _sheet_rect()
	return (at - sheet.position) * (design.tile_size().x / sheet.size.x)

func _to_screen(at: Vector2) -> Vector2:
	var sheet: Rect2 = _sheet_rect()
	return sheet.position + at * (sheet.size.x / design.tile_size().x)

func _tile_units(pixels: float) -> float:
	return pixels * design.tile_size().x / _sheet_rect().size.x

func snap_tolerance() -> float:
	return _tile_units(SNAP_DISTANCE)

func place_at(tile_position: Vector2) -> void:
	if view_kind == "tile" and placing: piece_placed.emit(tile_position)

func _selection_bounds(indices: Array[int], with_preview: bool = true) -> Rect2:
	var combined: Rect2
	var has_piece: bool = false
	for index: int in indices:
		if index < 0 or index >= _draw_parts.size(): continue
		var points: PackedVector2Array = _vertices(index) if with_preview else _draw_parts[index].vertices
		var bounds: Rect2 = Geometry.bounds(points)
		combined = combined.merge(bounds) if has_piece else bounds
		has_piece = true
	return combined

func _transform_handle() -> Vector2:
	var bounds: Rect2 = _selection_bounds(selected_indices)
	var handle: Vector2 = _to_screen(Vector2(bounds.get_center().x, bounds.position.y)) + Vector2(0, -22) if _transform_mode == "rotate" else _to_screen(bounds.end) + Vector2(10, 10)
	# The margin keeps a handle reachable even when a piece touches a tile edge.
	return handle.clamp(Vector2(10, 10), size - Vector2(10, 10))

func begin_transform(mode: String) -> void:
	if not mode in ["rotate", "resize"] or selected_indices.is_empty(): return
	cancel_drag()
	_transform_mode = mode
	grab_focus()

func clear_transform() -> void:
	_transform_mode = ""
	cancel_drag()

func _select_indices(indices: Array[int]) -> void:
	var next: Array[int] = design.expand_selection(indices)
	if next == selected_indices: return
	_transform_mode = ""
	selected_indices = next
	selection_changed.emit(next.duplicate())
	queue_redraw()

func _marquee_indices() -> Array[int]:
	var indices: Array[int] = []
	if _additive: indices.assign(selected_indices)
	var marquee: Rect2 = Rect2(_grab, _cursor - _grab).abs()
	if marquee.size.length() >= _tile_units(DRAG_DISTANCE):
		for part: Dictionary in _draw_parts:
			if marquee.encloses(Geometry.bounds(part.vertices)):
				indices.append(int(part.index))
	return design.expand_selection(indices)

func _keyboard_offset(request: Vector2) -> Vector2:
	var bounds: Rect2 = _selection_bounds(selected_indices, false)
	var anchor: Vector2 = _draw_parts[selected_indices[0]].position if selected_indices.size() == 1 else Vector2.ZERO
	return ((anchor + request).snappedf(Design.GRID_STEP) - anchor).clamp(-bounds.position, design.tile_size() - bounds.end)

func nudge(delta: Vector2) -> void:
	if view_kind != "tile" or selected_indices.is_empty() or _pointer != NO_POINTER or not delta.is_finite(): return
	if design.transform_pieces(selected_indices, Vector2.ZERO, 0.0, 1.0, _keyboard_offset(delta)): edited.emit()

func cancel_drag() -> void:
	_pointer = NO_POINTER
	_gesture = ""
	_corner = -1
	_preview_points.clear()
	_invalid_preview = false
	_offset = Vector2.ZERO
	_degrees = 0.0
	_scale = 1.0
	queue_redraw()

func _press(id: int, at: Vector2, additive: bool = false) -> void:
	if _pointer != NO_POINTER: return
	var handle_hit: bool = not _transform_mode.is_empty() and not selected_indices.is_empty() and _transform_handle().distance_to(at) <= 14.0
	if not _sheet_rect().has_point(at) and not handle_hit: return
	var pos: Vector2 = _to_tile(at)
	grab_focus()
	if placing:
		place_at(pos)
		accept_event()
		return
	var hit: int = design.hit_test(pos)
	if handle_hit or (not _transform_mode.is_empty() and selected_indices.has(hit) and not additive):
		_gesture = _transform_mode
		_pivot = _selection_bounds(selected_indices, false).get_center()
		_direction = pos - _pivot
		if _direction.length() < _tile_units(8.0):
			_direction = _to_tile(_transform_handle()) - _pivot
	elif selected_indices.size() == 1 and _transform_mode.is_empty() and not additive and str(_draw_parts[selected_indices[0]].kind) == Geometry.FREEFORM:
		var pts: PackedVector2Array = _draw_parts[selected_indices[0]].vertices
		for i: int in range(4):
			if pos.distance_to(pts[i]) < _tile_units(12.0):
				_corner = i
				_vertex_target = pts[i]
				_gesture = "vertex"
				break
	if _gesture.is_empty():
		if hit < 0:
			_transform_mode = ""
			_gesture = "box"
			_additive = additive
		else:
			var hit_selection: Array[int] = [hit]
			if additive:
				hit_selection = design.expand_selection(hit_selection)
				var next: Array[int] = selected_indices.duplicate()
				for index: int in hit_selection:
					if selected_indices.has(hit): next.erase(index)
					else: next.append(index)
				_select_indices(next)
				accept_event()
				return
			if not selected_indices.has(hit): _select_indices(hit_selection)
			_gesture = "move"
	_grab = pos
	_cursor = pos
	_pointer = id
	queue_redraw()
	accept_event()

func _preview_transform(pivot: Vector2, degrees: float, factor: float, offset: Vector2) -> void:
	var parts: Array[Dictionary] = design.preview_transform(selected_indices, pivot, degrees, factor, offset)
	_invalid_preview = parts.is_empty()
	if _invalid_preview: return
	_preview_points.clear()
	for part: Dictionary in parts:
		_preview_points[int(part.index)] = part.vertices
	_degrees = degrees
	_scale = factor
	_offset = offset

func _preview_vertex(delta: Vector2) -> void:
	var index: int = selected_indices[0]
	var points: PackedVector2Array = PackedVector2Array(_draw_parts[index].vertices).duplicate()
	var snapped: Vector2 = design.snap_vertex(index, points[_corner] + delta, snap_tolerance())
	points[_corner] = snapped
	_invalid_preview = not Geometry.is_valid(points)
	if _invalid_preview: return
	_vertex_target = snapped
	_preview_points[index] = points

func _drag(id: int, at: Vector2, snap_angle: bool = false) -> void:
	if _pointer != id: return
	var point: Vector2 = _to_tile(at)
	var delta: Vector2 = point - _grab
	_cursor = point.clamp(Vector2.ZERO, design.tile_size())
	if delta.length() < _tile_units(DRAG_DISTANCE):
		_preview_points.clear()
		_invalid_preview = false
		_offset = Vector2.ZERO
		_degrees = 0.0
		_scale = 1.0
		if _corner >= 0: _vertex_target = _draw_parts[selected_indices[0]].vertices[_corner]
	else:
		match _gesture:
			"move":
				var offset: Vector2 = design.snap_translation(selected_indices, delta, snap_tolerance())
				_preview_transform(Vector2.ZERO, 0.0, 1.0, offset)
			"vertex": _preview_vertex(delta)
			"rotate":
				var current: Vector2 = _direction + delta
				if current.length_squared() > 0.0001:
					var angle: float = rad_to_deg(_direction.angle_to(current))
					_preview_transform(_pivot, snappedf(angle, 15.0) if snap_angle else angle, 1.0, Vector2.ZERO)
			"resize":
				var factor: float = (_direction + delta).length() / maxf(_direction.length(), 0.001)
				_preview_transform(_pivot, 0.0, factor, Vector2.ZERO)
	queue_redraw()
	accept_event()

func _release(id: int, at: Vector2, snap_angle: bool = false) -> void:
	if _pointer != id: return
	_drag(id, at, snap_angle)
	var changed: bool = false
	match _gesture:
		"box": _select_indices(_marquee_indices())
		"vertex":
			var index: int = selected_indices[0]
			if not _vertex_target.is_equal_approx(_draw_parts[index].vertices[_corner]):
				changed = design.set_vertex(index, _corner, _vertex_target, false)
		"move", "rotate", "resize":
			if not _offset.is_zero_approx() or not is_zero_approx(_degrees) or not is_equal_approx(_scale, 1.0):
				var pivot: Vector2 = Vector2.ZERO if _gesture == "move" else _pivot
				changed = design.transform_pieces(selected_indices, pivot, _degrees, _scale, _offset)
	cancel_drag()
	if changed: edited.emit()
	accept_event()

func _request_context(at: Vector2) -> void:
	if _pointer != NO_POINTER or not _sheet_rect().has_point(at): return
	var hit: int = design.hit_test(_to_tile(at))
	accept_event()
	if hit < 0: return
	grab_focus()
	if not selected_indices.has(hit): _select_indices([hit])
	context_requested.emit(selected_indices.duplicate(), get_global_transform_with_canvas() * at)

func _gui_input(event: InputEvent) -> void:
	if view_kind != "tile" or design == null: return
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _press(-1, event.position, event.shift_pressed)
			else: _release(-1, event.position, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_request_context(event.position)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		_drag(-1, event.position, event.shift_pressed)
	elif event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.canceled: cancel_drag()
		elif event.pressed: _press(event.index, event.position)
		else: _release(event.index, event.position)
	elif event is InputEventScreenDrag and event.device != InputEvent.DEVICE_ID_EMULATION:
		_drag(event.index, event.position)
	elif event is InputEventKey and event.pressed and has_focus():
		var steps: Dictionary = {KEY_LEFT:Vector2.LEFT, KEY_RIGHT:Vector2.RIGHT, KEY_UP:Vector2.UP, KEY_DOWN:Vector2.DOWN}
		if event.keycode == KEY_ESCAPE and (_pointer != NO_POINTER or not _transform_mode.is_empty()):
			clear_transform()
			accept_event()
		elif steps.has(event.keycode):
			nudge(Vector2(steps[event.keycode]) * 5.0)
			accept_event()
