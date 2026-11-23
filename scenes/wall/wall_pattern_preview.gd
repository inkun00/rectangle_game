extends Control

const Design = preload("res://scripts/core/wall_tile_design.gd")
const Geometry = preload("res://scripts/core/quadrilateral_math.gd")
const WallArt = preload("res://scenes/wall/wall_art.gd")

signal piece_selected(index: int)
signal piece_placed(point: Vector2)
signal edited

var design: Design
var view_kind: String = "blank"
var selected_piece: int = -1
var placing: bool = false
var location: String = ""
var backdrop: Texture2D
var export_only: bool = false
var _pointer: int = -2
var _grab: Vector2
var _origin: Vector2
var _drag_delta: Vector2
var _corner: int = -1
var _draw_parts: Array[Dictionary] = []

func _ready() -> void:
	if not export_only: custom_minimum_size.y = 180
	focus_mode = Control.FOCUS_ALL if view_kind == "tile" else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if view_kind == "tile" else Control.MOUSE_FILTER_IGNORE
	accessibility_name = "타일 편집판. 방향키로 선택한 조각을 움직여요."
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
	for part: Dictionary in _draw_parts:
		var points: PackedVector2Array = PackedVector2Array(part.vertices)
		if _pointer != -2 and int(part.index) == selected_piece:
			if _corner >= 0: points[_corner] += _drag_delta
			else: points = Transform2D(0.0, _drag_delta) * points
		points = Transform2D(0.0, Vector2.ONE * factor, 0.0, area.position) * points
		draw_colored_polygon(points, part.color)
		var outline: PackedVector2Array = points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color("#544f48"), 1.3, true)
		if int(part.index) == selected_piece:
			draw_polyline(outline, Color("#146e78"), 3, true)
			if str(part.kind) == "freeform":
				for v: Vector2 in points:
					draw_circle(v, 5.0, Color.WHITE)
					draw_circle(v, 3.0, Color("#146e78"))
	draw_rect(area, Color("#fbc773") if has_focus() else Color("#c9bd9d"), false, 2)

func _draw_wall(area: Rect2) -> void:
	if area.size.x < 1 or area.size.y < 1: return
	# Fit whole, undistorted copies to the height. Crop the outside column at the
	# edge of the pictured wall, just as a tile setter cuts the last strip.
	var tile: Vector2 = design.tile_size()
	var scale_factor: float = minf(area.size.x / design.wall_size().x, area.size.y / design.wall_size().y)
	if scale_factor <= 0: return
	var block_size: Vector2 = design.wall_size() * scale_factor
	draw_rect(area, Color("#f8f0dc"))
	var limit: PackedVector2Array = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
	for by: int in range(ceili(area.size.y / block_size.y)):
		for bx: int in range(ceili(area.size.x / block_size.x)):
			var transform: Transform2D = Transform2D(0.0, Vector2.ONE * scale_factor, 0.0, area.position + block_size * Vector2(bx, by))
			for part: Dictionary in _draw_parts:
				var points: PackedVector2Array = transform * PackedVector2Array(part.vertices)
				var bounds: Rect2 = Geometry.bounds(points)
				if area.encloses(bounds):
					draw_colored_polygon(points, part.color)
				elif area.intersects(bounds):
					for polygon: PackedVector2Array in Geometry2D.intersect_polygons(points, limit):
						if polygon.size() >= 3 and Geometry2D.triangulate_polygon(polygon).size() >= 3: draw_colored_polygon(polygon, part.color)
	if not export_only:
		var cell: Vector2 = tile * scale_factor
		for x: int in range(1, ceili(area.size.x / cell.x)):
			var a: Vector2 = area.position + Vector2(x * cell.x, 0)
			draw_line(a, a + Vector2(0, area.size.y), Color(0.3, 0.28, 0.24, 0.23), 1)
		for y: int in range(1, ceili(area.size.y / cell.y)):
			var a: Vector2 = area.position + Vector2(0, y * cell.y)
			draw_line(a, a + Vector2(area.size.x, 0), Color(0.3, 0.28, 0.24, 0.23), 1)

func _to_tile(at: Vector2) -> Vector2:
	var sheet: Rect2 = _sheet_rect()
	return (at - sheet.position) * (design.tile_size().x / sheet.size.x)

func place_at(tile_position: Vector2) -> void:
	if view_kind == "tile" and placing: piece_placed.emit(tile_position)

func nudge(delta: Vector2) -> void:
	if view_kind != "tile" or selected_piece < 0 or selected_piece >= _draw_parts.size(): return
	if design.move_piece(selected_piece, Vector2(_draw_parts[selected_piece].position) + delta): edited.emit()

func cancel_drag() -> void:
	_pointer = -2
	_corner = -1
	_drag_delta = Vector2.ZERO
	queue_redraw()

func _press(id: int, at: Vector2) -> void:
	if _pointer != -2 or not _sheet_rect().has_point(at): return
	var pos: Vector2 = _to_tile(at)
	grab_focus()
	if placing:
		place_at(pos)
		accept_event()
		return
	_corner = -1
	if selected_piece >= 0 and selected_piece < _draw_parts.size() and str(_draw_parts[selected_piece].kind) == "freeform":
		var pts: PackedVector2Array = _draw_parts[selected_piece].vertices
		var tolerance: float = 12.0 * design.tile_size().x / _sheet_rect().size.x
		for i: int in range(4):
			if pos.distance_to(pts[i]) < tolerance:
				_corner = i
				break
	if _corner < 0:
		selected_piece = design.hit_test(pos)
		piece_selected.emit(selected_piece)
	if selected_piece >= 0:
		_grab = pos
		_origin = _draw_parts[selected_piece].position
		_pointer = id
		_drag_delta = Vector2.ZERO
		accept_event()

func _drag(id: int, at: Vector2) -> void:
	if _pointer != id: return
	var delta: Vector2 = _to_tile(at) - _grab
	var pts: PackedVector2Array = PackedVector2Array(_draw_parts[selected_piece].vertices)
	if _corner >= 0:
		var vertex: Vector2 = pts[_corner]
		pts[_corner] = (vertex + delta).clamp(Vector2.ZERO, design.tile_size())
		if Geometry.is_valid(pts): _drag_delta = pts[_corner] - vertex
	else:
		var bounds: Rect2 = Geometry.bounds(pts)
		_drag_delta = delta.clamp(-bounds.position, design.tile_size() - bounds.end)
	queue_redraw()
	accept_event()

func _release(id: int, at: Vector2) -> void:
	if _pointer != id: return
	_drag(id, at)
	var changed: bool = false
	if _drag_delta.length_squared() >= 0.01:
		if _corner >= 0:
			changed = design.set_vertex(selected_piece, _corner, Vector2(_draw_parts[selected_piece].vertices[_corner]) + _drag_delta)
		else: changed = design.move_piece(selected_piece, _origin + _drag_delta)
	cancel_drag()
	if changed: edited.emit()
	accept_event()

func _gui_input(event: InputEvent) -> void:
	if view_kind != "tile": return
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _press(-1, event.position)
		else: _release(-1, event.position)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		_drag(-1, event.position)
	elif event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.canceled: cancel_drag()
		elif event.pressed: _press(event.index, event.position)
		else: _release(event.index, event.position)
	elif event is InputEventScreenDrag and event.device != InputEvent.DEVICE_ID_EMULATION:
		_drag(event.index, event.position)
	elif event is InputEventKey and event.pressed and has_focus():
		var steps: Dictionary = {KEY_LEFT:Vector2.LEFT, KEY_RIGHT:Vector2.RIGHT, KEY_UP:Vector2.UP, KEY_DOWN:Vector2.DOWN}
		if steps.has(event.keycode):
			nudge(Vector2(steps[event.keycode]) * 5.0)
			accept_event()
