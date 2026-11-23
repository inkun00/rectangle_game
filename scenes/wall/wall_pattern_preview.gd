extends Control

const Design = preload("res://scripts/core/wall_tile_design.gd")

signal piece_selected(index: int)

var design: Design
var wall: bool = false
var selected_piece: int = 0

func _ready() -> void:
	custom_minimum_size = Vector2(0, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE if wall else Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW if wall else Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)

func _sheet_rect() -> Rect2:
	var units: Vector2 = design.wall_size() if wall else design.tile_size()
	var available: Vector2 = (size - Vector2(34, 30)).max(Vector2.ONE)
	var side: float = minf(available.x / units.x, available.y / units.y)
	var extent: Vector2 = units * side
	return Rect2((size - extent) * 0.5, extent)

func _draw() -> void:
	if design == null: return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#182e3c"))
	var sheet: Rect2 = _sheet_rect()
	draw_rect(Rect2(sheet.position + Vector2(2, 4), sheet.size).grow(4), Color("#101f28"))
	draw_rect(sheet.grow(3), Color("#d2c6ac"))
	draw_rect(sheet, Color("#fff4da"))
	var scale_factor: float = sheet.size.x / (design.wall_size().x if wall else design.tile_size().x)
	var pieces: Array[Dictionary] = design.wall_parts() if wall else design.motif_parts()
	for piece: Dictionary in pieces:
		var points: PackedVector2Array = PackedVector2Array()
		for v: Vector2 in piece.vertices:
			points.append(sheet.position + v * scale_factor)
		draw_colored_polygon(points, piece.color)
		points.append(points[0])
		draw_polyline(points, Color(0.22, 0.26, 0.32, 0.65), 1.1, true)
		if not wall and int(piece.index) == selected_piece:
			draw_polyline(points, Color("#183346"), 3.4, true)
			draw_polyline(points, Color.WHITE, 1.2, true)
	if wall:
		for x: int in range(1, design.columns):
			var start: Vector2 = sheet.position + Vector2(x * sheet.size.x / design.columns, 0)
			draw_line(start, start + Vector2(0, sheet.size.y), Color(0.27, 0.30, 0.29, 0.6), 1)
		for y: int in range(1, design.rows):
			var start: Vector2 = sheet.position + Vector2(0, y * sheet.size.y / design.rows)
			draw_line(start, start + Vector2(sheet.size.x, 0), Color(0.27, 0.30, 0.29, 0.6), 1)

func _gui_input(event: InputEvent) -> void:
	if wall or design == null: return
	var position_on_sheet: Vector2
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		position_on_sheet = event.position
	elif event is InputEventScreenTouch and event.pressed:
		position_on_sheet = event.position
	else: return
	var sheet: Rect2 = _sheet_rect()
	if not sheet.has_point(position_on_sheet): return
	var unit_point: Vector2 = (position_on_sheet - sheet.position) * (design.tile_size().x / sheet.size.x)
	for piece: Dictionary in design.motif_parts():
		if Geometry2D.is_point_in_polygon(unit_point, piece.vertices):
			piece_selected.emit(int(piece.index))
			accept_event()
			return
