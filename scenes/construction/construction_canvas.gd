class_name ConstructionCanvas
extends Control

const Model = preload("res://scripts/construction/construction_document.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Language = preload("res://scripts/construction/construction_language.gd")
const Art = preload("res://scripts/construction_art.gd")
const Simulation = preload("res://scenes/construction/construction_physics.gd")
const BOARD: Rect2 = Rect2(0, 0, 1000, 600)
const INK: Color = Color("243136")
const PAPER: Color = Color("f6f7f3")
const GRID_COLOR: Color = Color("dde2dd")
const ACCENT: Color = Color("315f65")
const COPPER: Color = Color("b57246")
const REPAIR_COLOR: Color = Color("a74130")

signal hint_requested(message: String)
signal tool_changed
signal inspection_finished(report: Dictionary)

var document: Model:
	set(value):
		if document == value:
			return
		if document != null and document.changed.is_connected(_document_changed):
			document.changed.disconnect(_document_changed)
		document = value
		if document != null and is_node_ready():
			document.changed.connect(_document_changed)
		cancel_gesture()
		stop_inspection()
		_clear_repair_report()
var editing_enabled: bool = true
var material_id: String = "wall"
var selected_kind: String = "rectangle"
var drawing_tool: bool = true
var inspection_running: bool = false
var inspection_visible: bool = false
var show_grid: bool = true
var presentation_mode: bool = false
var fit_context: Rect2 = Rect2():
	set(value):
		if fit_context == value:
			return
		fit_context = value
		_schedule_fit()
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO
var cursor_position: Vector2 = Vector2(500, 500)
var last_report: Dictionary = {}
var repair_issue: Dictionary = {}
var facade_gaps: Array[Rect2] = []
var _simulation: Simulation
var _hovered: bool = false
var _dragging: bool = false
var _panning: bool = false
var _pending_place: bool = false
var _drag_id: int = -1
var _drag_origin: Vector2 = Vector2.ZERO
var _press_position: Vector2 = Vector2.ZERO
var _drag_position: Vector2 = Vector2.ZERO
var _auto_fit: bool = false
var _fit_pending: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	if document == null:
		document = Model.new()
	document.changed.connect(_document_changed)
	resized.connect(_canvas_resized)
	visibility_changed.connect(_visibility_changed)
	mouse_entered.connect(func(): _hovered = true; queue_redraw())
	mouse_exited.connect(func(): _hovered = false; queue_redraw())
	_simulation = Simulation.new()
	_simulation.advanced.connect(queue_redraw)
	_simulation.finished.connect(_inspection_finished)
	add_child(_simulation)
	_schedule_fit()

func canvas_scale() -> float:
	return maxf(0.01, minf((size.x - 24.0) / BOARD.size.x, (size.y - 24.0) / BOARD.size.y)) * zoom

func _hint(message: String) -> void:
	hint_requested.emit(Language.simplify(message))

func artwork_to_screen(point: Vector2) -> Vector2:
	return (size - BOARD.size * canvas_scale()) * 0.5 + pan + point * canvas_scale()

func screen_to_artwork(point: Vector2) -> Vector2:
	return (point - (size - BOARD.size * canvas_scale()) * 0.5 - pan) / canvas_scale()

func set_presentation_mode(value: bool) -> void:
	presentation_mode = value
	queue_redraw()

func choose_material(id: String) -> void:
	var material: Dictionary = Catalog.material(id)
	if material.is_empty():
		return
	cancel_gesture()
	material_id = id
	selected_kind = str(material.kind)
	drawing_tool = true
	if document != null:
		document.select(-1)
	tool_changed.emit()
	queue_redraw()

func select_tool() -> void:
	cancel_gesture()
	drawing_tool = false
	tool_changed.emit()
	queue_redraw()

func cancel_gesture() -> void:
	_dragging = false
	_pending_place = false
	_panning = false
	queue_redraw()

func zoom_by(factor: float, screen_anchor: Vector2 = Vector2(-1, -1)) -> void:
	_auto_fit = false
	var anchor: Vector2 = size * 0.5 if screen_anchor.x < 0.0 else screen_anchor
	var before: Vector2 = screen_to_artwork(anchor)
	zoom = clampf(zoom * factor, 1.0, 3.0)
	pan += anchor - artwork_to_screen(before)
	_limit_pan()
	queue_redraw()

func reset_view() -> void:
	_auto_fit = false
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()

func fit_parts() -> void:
	_auto_fit = true
	_apply_fit_parts()
	_schedule_fit()

func _canvas_resized() -> void:
	queue_redraw()
	_schedule_fit()

func _schedule_fit() -> void:
	if _auto_fit and not _fit_pending and is_inside_tree():
		_fit_pending = true
		_refit_after_layout.call_deferred()

func _refit_after_layout() -> void:
	_fit_pending = false
	if _auto_fit:
		_apply_fit_parts()

func _apply_fit_parts() -> void:
	cancel_gesture()
	var has_parts: bool = document != null and not document.parts.is_empty()
	if (not has_parts and not fit_context.has_area()) or size.x <= 32.0 or size.y <= 32.0:
		zoom = 1.0
		pan = Vector2.ZERO
		queue_redraw()
		return
	var bounds: Rect2 = fit_context
	if has_parts:
		var first_bounds: Rect2 = QuadrilateralMath.bounds(document.world_vertices(document.parts[0]))
		bounds = bounds.merge(first_bounds) if bounds.has_area() else first_bounds
		for index: int in range(1, document.parts.size()):
			bounds = bounds.merge(QuadrilateralMath.bounds(document.world_vertices(document.parts[index])))
	# A small surround leaves the foundation and the roof outline readable.
	var framed: Rect2 = bounds.grow(24.0)
	var base_scale: float = maxf(0.01, minf((size.x - 24.0) / BOARD.size.x, (size.y - 24.0) / BOARD.size.y))
	var desired_scale: float = minf((size.x - 32.0) / maxf(framed.size.x, 1.0), (size.y - 32.0) / maxf(framed.size.y, 1.0))
	zoom = clampf(desired_scale / base_scale, 1.0, 3.0)
	pan = (BOARD.get_center() - framed.get_center()) * canvas_scale()
	_limit_pan()
	queue_redraw()

func _limit_pan() -> void:
	# Allow a part near the foundation or board edge to reach the screen center.
	# At least part of the board remains visible, and reset_view always restores it.
	var limit: Vector2 = BOARD.size * canvas_scale() * 0.5
	pan = pan.clamp(-limit, limit)

func start_inspection() -> bool:
	if document == null or document.parts.is_empty() or _simulation == null:
		_hint("먼저 벽과 문, 창문을 놓아 주세요.")
		return false
	cancel_gesture()
	inspection_running = true
	inspection_visible = true
	_clear_repair_report()
	_simulation.start(document.parts, document.revision)
	_hint("무게와 받침을 확인하고 있어요. 문·창문 위에는 가로 받침이 필요해요.")
	tool_changed.emit()
	queue_redraw()
	return true

func stop_inspection() -> void:
	if _simulation != null:
		_simulation.stop()
	inspection_running = false
	inspection_visible = false
	queue_redraw()

func focus_repair(issue: Dictionary) -> bool:
	if not _has_fresh_report() or not last_report.get("issues", []).has(issue):
		return false
	var part_id: int = int(issue.get("part_id", -1))
	var part: Dictionary = document.part(part_id)
	if part.is_empty() or not last_report.get("unsupported_ids", []).has(part_id):
		return false
	stop_inspection()
	select_tool()
	document.select(part_id)
	repair_issue = issue.duplicate(true)
	_auto_fit = false
	var bounds: Rect2 = QuadrilateralMath.bounds(document.world_vertices(part)).grow(28.0)
	var base_scale: float = maxf(0.01, minf((size.x - 24.0) / BOARD.size.x, (size.y - 24.0) / BOARD.size.y))
	var desired_scale: float = minf(maxf(size.x - 64.0, 1.0) / bounds.size.x, maxf(size.y - 88.0, 1.0) / bounds.size.y)
	zoom = clampf(desired_scale / base_scale, 1.0, 3.0)
	pan = (BOARD.get_center() - bounds.get_center()) * canvas_scale()
	_limit_pan()
	cursor_position = Vector2(part.position)
	grab_focus()
	_hint(str(issue.get("message", "표시한 재료의 받침을 살펴보세요.")))
	queue_redraw()
	return true

func _has_fresh_report() -> bool:
	return document != null and not last_report.is_empty() and int(last_report.get("revision", -1)) == document.revision

func _clear_repair_report() -> void:
	last_report.clear()
	repair_issue.clear()
	facade_gaps.clear()

func show_facade_gaps(gaps: Array) -> void:
	stop_inspection()
	select_tool()
	facade_gaps.clear()
	for gap: Variant in gaps:
		if gap is Rect2: facade_gaps.append(gap)
	fit_parts()
	grab_focus()
	queue_redraw()

func add_at_cursor() -> void:
	if not _can_edit():
		return
	var position: Vector2 = document.snapped_position(material_id, cursor_position, selected_kind)
	var reason: String = document.placement_error(material_id, position, selected_kind)
	if not reason.is_empty():
		_hint(reason)
		return
	var id: int = document.add_part(material_id, position, selected_kind)
	if id < 0:
		_hint(document.last_error)
	else:
		_hint("%s 놓기 · %s" % [str(Catalog.material(material_id).label), Catalog.format_won(int(Catalog.material(material_id).price))])
	queue_redraw()

func _can_edit() -> bool:
	return editing_enabled and document != null and document.editing_enabled and not inspection_visible and is_visible_in_tree()

func _document_changed() -> void:
	if _dragging and document.selected_id != _drag_id:
		_dragging = false
	if inspection_visible and _simulation != null and document.revision != _simulation.revision:
		stop_inspection()
	if not _has_fresh_report():
		_clear_repair_report()
	elif not repair_issue.is_empty() and document.selected_id != int(repair_issue.get("part_id", -1)):
		repair_issue.clear()
	queue_redraw()

func _inspection_finished(report: Dictionary) -> void:
	inspection_running = false
	last_report = report.duplicate(true)
	_hint(str(report.message))
	inspection_finished.emit(report)
	tool_changed.emit()
	queue_redraw()

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_gesture()
		stop_inspection()

func _gui_input(event: InputEvent) -> void:
	if document == null or not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2, event.position)
			accept_event()
			return
		if event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				_auto_fit = false
			_panning = event.pressed
			accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT or not _can_edit():
			return
		var point: Vector2 = screen_to_artwork(event.position)
		if event.pressed:
			if not BOARD.has_point(point):
				return
			grab_focus()
			_press(point)
		else:
			_release(point)
		accept_event()
	elif event is InputEventMouseMotion:
		if _panning:
			pan += event.relative
			_limit_pan()
		else:
			var point: Vector2 = screen_to_artwork(event.position)
			cursor_position = point
			if _dragging:
				var selected: Dictionary = document.get_selected()
				if not selected.is_empty():
					_drag_position = document.snapped_position(str(selected.material_id), _drag_origin + point - _press_position, str(selected.kind))
		mouse_default_cursor_shape = Control.CURSOR_DRAG if _panning else (Control.CURSOR_CROSS if drawing_tool else Control.CURSOR_MOVE)
		queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and not event.meta_pressed:
		if not _can_edit():
			return
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER] and drawing_tool:
			add_at_cursor()
			accept_event()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			cancel_gesture()
			var direction: Vector2 = Vector2.ZERO
			match event.keycode:
				KEY_LEFT: direction = Vector2.LEFT
				KEY_RIGHT: direction = Vector2.RIGHT
				KEY_UP: direction = Vector2.UP
				KEY_DOWN: direction = Vector2.DOWN
			var step: float = 10.0 if event.shift_pressed else 20.0
			if drawing_tool:
				cursor_position = (cursor_position + direction * step).clamp(BOARD.position, Vector2(1000, 560))
			elif not document.get_selected().is_empty():
				if not document.move_selected(Vector2(document.get_selected().position) + direction * step):
					_hint(document.last_error)
			queue_redraw()
			accept_event()

func _press(point: Vector2) -> void:
	cancel_gesture()
	_press_position = point
	cursor_position = point
	if drawing_tool:
		_pending_place = true
	else:
		var id: int = _part_at(point)
		document.select(id)
		if id >= 0:
			_dragging = true
			_drag_id = id
			_drag_origin = Vector2(document.get_selected().position)
			_drag_position = _drag_origin
	queue_redraw()

func _release(point: Vector2) -> void:
	if _pending_place:
		_pending_place = false
		cursor_position = point
		add_at_cursor()
	elif _dragging:
		_dragging = false
		if not document.move_selected(_drag_origin + point - _press_position):
			_hint(document.last_error)
	cancel_gesture()

func _part_at(point: Vector2) -> int:
	for index: int in range(document.parts.size() - 1, -1, -1):
		var part: Dictionary = document.parts[index]
		if QuadrilateralMath.contains_point(part.vertices, point - Vector2(part.position)):
			return int(part.id)
	return -1

func _draw() -> void:
	var worksite: Texture2D = Art.game_texture("worksite.png")
	if worksite != null:
		draw_texture_rect(worksite, Rect2(Vector2.ZERO, size), false)
	var board: Rect2 = Rect2(artwork_to_screen(Vector2.ZERO), BOARD.size * canvas_scale())
	if not presentation_mode:
		# This translucent work surface is an editing aid. The illustrated yard
		# remains visible instead of stretching a framed panel across the board.
		draw_rect(board, Color("fffdf7a8"))
	if show_grid and not presentation_mode:
		for x: int in range(0, 1001, 20):
			draw_line(artwork_to_screen(Vector2(x, 0)), artwork_to_screen(Vector2(x, 560)), GRID_COLOR.darkened(0.035) if x % 100 == 0 else GRID_COLOR, 1.0 if x % 100 == 0 else 0.55)
		for y: int in range(0, 561, 20):
			draw_line(artwork_to_screen(Vector2(0, y)), artwork_to_screen(Vector2(1000, y)), GRID_COLOR.darkened(0.035) if y % 100 == 0 else GRID_COLOR, 1.0 if y % 100 == 0 else 0.55)
	_draw_foundation()
	if document == null:
		return
	if inspection_visible and _simulation != null:
		for part: Dictionary in _simulation.rendered_parts():
			var bad: bool = last_report.get("unsupported_ids", []).has(int(part.id))
			_draw_part(part, _simulation.pose(int(part.id)), false, Color.WHITE, bad)
	else:
		for part: Dictionary in document.parts:
			var position: Vector2 = _drag_position if _dragging and int(part.id) == _drag_id else Vector2(part.position)
			_draw_part(part, Transform2D(0.0, position), editing_enabled and not presentation_mode and int(part.id) == document.selected_id)
		if _has_fresh_report():
			_draw_repair_outlines()
		if drawing_tool and _can_edit() and (_hovered or has_focus()) and BOARD.has_point(cursor_position):
			var material: Dictionary = Catalog.material(material_id)
			var position: Vector2 = document.snapped_position(material_id, cursor_position, selected_kind)
			var reason: String = document.placement_error(material_id, position, selected_kind)
			var preview: Dictionary = {"id": -1, "material_id": material_id, "kind": selected_kind, "position": position, "vertices": QuadrilateralMath.create_vertices(selected_kind, Vector2(material.dimensions))}
			_draw_part(preview, Transform2D(0.0, position), false, Color(1, 1, 1, 0.55), not reason.is_empty())
	if not presentation_mode:
		_draw_dimensions()
		_draw_rulers()
	for gap: Rect2 in facade_gaps:
		var area: Rect2 = Rect2(artwork_to_screen(gap.position), gap.size * canvas_scale())
		draw_rect(area, Color(0.75, 0.25, 0.15, 0.35))
		draw_rect(area, REPAIR_COLOR, false, 3.0)
	if not facade_gaps.is_empty():
		var label_position: Vector2 = artwork_to_screen(facade_gaps[0].position) - Vector2(0, 25)
		label_position = label_position.clamp(Vector2(6, 6), Vector2(maxf(6, size.x - 98), maxf(6, size.y - 30)))
		draw_rect(Rect2(label_position, Vector2(92, 24)), Color("fff6d5"))
		draw_rect(Rect2(label_position, Vector2(92, 24)), REPAIR_COLOR, false, 1.0)
		draw_string(QuadTheme.FONT, label_position + Vector2(6, 17), "벽 빈틈", HORIZONTAL_ALIGNMENT_LEFT, 80, 14, REPAIR_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), Color("c9d0c9"), false, 1.0)
	if has_focus():
		draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), ACCENT, false, 2.0)
	if inspection_running:
		var progress: float = clampf(_simulation.elapsed / Simulation.INSPECTION_SECONDS, 0.0, 1.0)
		draw_rect(Rect2(Vector2(12, 12), Vector2(size.x - 24, 6)), Color("d4dfd9"))
		draw_rect(Rect2(Vector2(12, 12), Vector2((size.x - 24) * progress, 6)), COPPER)
	if size.x >= 430.0:
		var caption: String = "튼튼한지 확인 중" if inspection_running else ("완성 모습" if presentation_mode else "집 앞모습  /  눈금 단위: 칸")
		draw_string(QuadTheme.FONT, Vector2(34, size.y - 12), caption, HORIZONTAL_ALIGNMENT_LEFT, maxf(0, size.x - 48), 13, Color("64716f"))

func _draw_foundation() -> void:
	var start: Vector2 = artwork_to_screen(Vector2(0, Model.GROUND_Y))
	var width: float = BOARD.size.x * canvas_scale()
	var depth: float = 40.0 * canvas_scale()
	var surface: Texture2D = Art.material_icon("wall")
	if surface != null:
		for offset: int in range(0, 1000, 80):
			var tile_start: Vector2 = start + Vector2(float(offset) * canvas_scale(), 0)
			var tile_width: float = minf(80.0, 1000.0 - float(offset)) * canvas_scale()
			draw_texture_rect(surface, Rect2(tile_start, Vector2(tile_width, depth)), false, Color("e2d8cc"))
	draw_line(start, start + Vector2(width, 0), Color("6b7c72"), 1.5)
	if not presentation_mode and start.y > 38.0 and start.y < size.y - 28.0:
		draw_string(QuadTheme.FONT, Vector2(maxf(start.x + 12.0, 34.0), start.y - 7.0), "땅의 높이", HORIZONTAL_ALIGNMENT_LEFT, 100.0, 11, Color("67786f"))

func _document_bounds() -> Rect2:
	var bounds: Rect2 = QuadrilateralMath.bounds(document.world_vertices(document.parts[0]))
	for index: int in range(1, document.parts.size()):
		bounds = bounds.merge(QuadrilateralMath.bounds(document.world_vertices(document.parts[index])))
	return bounds

func _draw_rulers() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 24.0)), Color("edf0e9"))
	draw_rect(Rect2(Vector2.ZERO, Vector2(24.0, size.y)), Color("edf0e9"))
	draw_line(Vector2(24, 24), Vector2(size.x, 24), Color("c8d0c8"), 1.0)
	draw_line(Vector2(24, 24), Vector2(24, size.y), Color("c8d0c8"), 1.0)
	for x: int in range(0, 1001, 20):
		var screen_x: float = artwork_to_screen(Vector2(x, 0)).x
		if screen_x < 30.0 or screen_x > size.x - 12.0: continue
		draw_line(Vector2(screen_x, 24), Vector2(screen_x, 16 if x % 100 == 0 else 20), Color("8f9d95"), 1.0)
		if x % 100 == 0: draw_string(QuadTheme.FONT, Vector2(screen_x + 4, 13), str(int(float(x) / 20.0)), HORIZONTAL_ALIGNMENT_LEFT, 28, 11, Color("68796e"))
	for y: int in range(0, 561, 20):
		var screen_y: float = artwork_to_screen(Vector2(0, y)).y
		if screen_y < 40.0 or screen_y > size.y - 26.0: continue
		draw_line(Vector2(24, screen_y), Vector2(16 if y % 100 == 0 else 20, screen_y), Color("8f9d95"), 1.0)
		if y % 100 == 0: draw_string(QuadTheme.FONT, Vector2(2, screen_y - 3), str(int(float(y) / 20.0)), HORIZONTAL_ALIGNMENT_LEFT, 20, 11, Color("68796e"))

func _draw_dimensions() -> void:
	if document.parts.is_empty() or inspection_visible: return
	var bounds: Rect2 = _document_bounds()
	var first: Vector2 = artwork_to_screen(bounds.position)
	var last: Vector2 = artwork_to_screen(bounds.end)
	if last.x - first.x < 80.0 or first.y < 60.0: return
	var dimension_y: float = first.y - 22.0
	var label: String = "%s칸" % _format_dimension(bounds.size.x / Model.GRID)
	var text_width: float = QuadTheme.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var midpoint: float = (first.x + last.x) * 0.5
	draw_line(Vector2(first.x, first.y - 4), Vector2(first.x, dimension_y - 5), Color("8e9e95"), 0.8)
	draw_line(Vector2(last.x, first.y - 4), Vector2(last.x, dimension_y - 5), Color("8e9e95"), 0.8)
	draw_line(Vector2(first.x, dimension_y), Vector2(midpoint - text_width * 0.5 - 6, dimension_y), Color("71867c"), 0.8)
	draw_line(Vector2(midpoint + text_width * 0.5 + 6, dimension_y), Vector2(last.x, dimension_y), Color("71867c"), 0.8)
	for x: float in [first.x, last.x]: draw_line(Vector2(x - 3, dimension_y + 3), Vector2(x + 3, dimension_y - 3), ACCENT, 1.0, true)
	draw_string(QuadTheme.FONT, Vector2(midpoint - text_width * 0.5, dimension_y + 5), label, HORIZONTAL_ALIGNMENT_LEFT, text_width + 2, 14, ACCENT)
	if first.x < 48.0 or last.y - first.y < 90.0: return
	var height_x: float = first.x - 22.0
	var height_label: String = "%s칸" % _format_dimension(bounds.size.y / Model.GRID)
	var height_text: float = QuadTheme.FONT.get_string_size(height_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var middle_y: float = (first.y + last.y) * 0.5
	draw_line(Vector2(height_x, first.y), Vector2(height_x, middle_y - height_text * 0.5 - 6.0), Color("71867c"), 0.8)
	draw_line(Vector2(height_x, middle_y + height_text * 0.5 + 6.0), Vector2(height_x, last.y), Color("71867c"), 0.8)
	for y: float in [first.y, last.y]:
		draw_line(Vector2(height_x - 5, y), Vector2(first.x - 4, y), Color("8e9e95"), 0.8)
		draw_line(Vector2(height_x - 3, y + 3), Vector2(height_x + 3, y - 3), ACCENT, 1.0, true)
	draw_set_transform(Vector2(height_x + 4.0, middle_y + height_text * 0.5), -PI * 0.5)
	draw_string(QuadTheme.FONT, Vector2.ZERO, height_label, HORIZONTAL_ALIGNMENT_LEFT, height_text + 2.0, 14, ACCENT)
	draw_set_transform(Vector2.ZERO)

func _format_dimension(value: float) -> String:
	return str(int(roundf(value))) if is_equal_approx(value, roundf(value)) else "%.1f" % value

func _draw_repair_outlines() -> void:
	for part: Dictionary in document.parts:
		var part_id: int = int(part.id)
		if not last_report.get("unsupported_ids", []).has(part_id):
			continue
		var position: Vector2 = _drag_position if _dragging and part_id == _drag_id else Vector2(part.position)
		var points: PackedVector2Array = _screen_points(part.vertices, Transform2D(0.0, position))
		_draw_outline(points, REPAIR_COLOR, 2.0)
		if repair_issue.is_empty() or part_id != int(repair_issue.get("part_id", -1)) or part_id != document.selected_id:
			continue
		for edge_index: int in repair_issue.get("missing_edges", []):
			if edge_index < 0 or edge_index >= points.size():
				continue
			var first: Vector2 = points[edge_index]
			var second: Vector2 = points[(edge_index + 1) % points.size()]
			draw_line(first, second, Color("fff6d5"), 8.0, true)
			draw_line(first, second, REPAIR_COLOR, 4.0, true)
			var midpoint: Vector2 = first.lerp(second, 0.5)
			draw_circle(midpoint, 9.0, Color("fff6d5"))
			draw_arc(midpoint, 9.0, 0.0, TAU, 20, REPAIR_COLOR, 2.0, true)
			draw_string(QuadTheme.FONT, midpoint + Vector2(-7.0, 4.0), "!", HORIZONTAL_ALIGNMENT_CENTER, 14.0, 12, INK)
		var bounds: Rect2 = QuadrilateralMath.bounds(points)
		var label_position: Vector2 = Vector2(clampf(bounds.position.x, 6.0, maxf(6.0, size.x - 94.0)), clampf(bounds.position.y - 27.0, 6.0, maxf(6.0, size.y - 52.0)))
		draw_rect(Rect2(label_position, Vector2(88.0, 23.0)), Color("fff6d5"))
		draw_rect(Rect2(label_position, Vector2(88.0, 23.0)), REPAIR_COLOR, false, 1.0)
		draw_string(QuadTheme.FONT, label_position + Vector2(6.0, 16.0), "고칠 재료", HORIZONTAL_ALIGNMENT_LEFT, 76.0, 14, INK)

func _draw_part(part: Dictionary, pose: Transform2D, selected: bool, tint: Color = Color.WHITE, invalid: bool = false) -> void:
	var vertices: PackedVector2Array = part.vertices
	var points: PackedVector2Array = _screen_points(vertices, pose)
	var material_texture: Texture2D = Art.material_icon(str(part.material_id))
	var paint: Color = Color("e89083") * tint if invalid else tint
	if material_texture != null:
		var material: Dictionary = Catalog.material(str(part.material_id))
		if int(material.get("brick_count", 0)) > 1:
			_draw_wall_texture(vertices, pose, material_texture, paint)
		else:
			draw_polygon(points, PackedColorArray([paint]), Art.texture_uvs(material_texture), Art.texture_source(material_texture))
	_draw_outline(points, REPAIR_COLOR if invalid else (ACCENT if selected else Color("58665f")), 2.0 if selected or invalid else 0.75)
	if selected:
		for point: Vector2 in points:
			draw_circle(point, 3.5, Color("fff9e9"))
			draw_arc(point, 3.5, 0, TAU, 12, INK, 1.0, true)

func _draw_wall_texture(vertices: PackedVector2Array, pose: Transform2D, texture: Texture2D, paint: Color) -> void:
	# Repeat the generated single-brick pixels, so the visible count stays equal
	# to each counted catalog module, including rotation.
	var columns: int = maxi(1, roundi((vertices[1] - vertices[0]).length() / 40.0))
	var rows: int = maxi(1, roundi((vertices[2] - vertices[1]).length() / 20.0))
	for row: int in range(rows):
		for column: int in range(columns):
			var area: Rect2 = Rect2(float(column) / columns, float(row) / rows, 1.0 / columns, 1.0 / rows)
			var corners: PackedVector2Array = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
			var local: PackedVector2Array = PackedVector2Array()
			for corner: Vector2 in corners: local.append(_uv_point(vertices, corner))
			draw_polygon(_screen_points(local, pose), PackedColorArray([paint]), Art.texture_uvs(texture), Art.texture_source(texture))

func _uv_point(vertices: PackedVector2Array, uv: Vector2) -> Vector2:
	return vertices[0].lerp(vertices[1], uv.x).lerp(vertices[3].lerp(vertices[2], uv.x), uv.y)

func _screen_points(vertices: PackedVector2Array, pose: Transform2D) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for vertex: Vector2 in vertices:
		points.append(artwork_to_screen(pose * vertex))
	return points

func _draw_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, color, width, true)
