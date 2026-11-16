class_name LearningGridCanvas
extends Control

const Math = preload("res://scripts/core/quadrilateral_math.gd")
const DEFAULT_GRID: Vector2i = Vector2i(10, 6)
const NO_CELL: Vector2i = Vector2i(-1, -1)
const GEOMETRY_STEP: float = 20.0
const MARGIN: float = 23.0
const GRID_INK: Color = Color("7e9697")
const GIVEN_INK: Color = Color("25496a")
const PLAYER_INK: Color = Color("00695a")
const INVALID_INK: Color = Color("a34129")
const FOCUS_INK: Color = Color("a94f19")

signal changed

var _grid_size: Vector2i = DEFAULT_GRID
var _given: Array[Vector2i] = []
var _vertices: Array[Vector2i] = []
var _lesson_id: String = ""
var _cursor: Vector2i = Vector2i.ZERO
var _pointer_cell: Vector2i = NO_CELL
var _mouse_dragging: bool = false
var _touch_index: int = -1
var _configured: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(240, 185)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(_reset_pointer)
	mouse_exited.connect(_pointer_exited)
	visibility_changed.connect(_reset_pointer)

func configure(question: Dictionary) -> void:
	_configured = false
	_lesson_id = str(question.get("lesson_id", ""))
	var raw_size: Variant = question.get("grid_size", DEFAULT_GRID)
	_grid_size = raw_size if raw_size is Vector2i and raw_size.x > 0 and raw_size.y > 0 else DEFAULT_GRID
	_given.clear()
	var raw_given: Variant = question.get("given", [])
	if _lesson_id in Math.KINDS and raw_given is Array and raw_given.size() < 4:
		for point: Variant in raw_given:
			if not point is Vector2i or not _contains(point) or _given.has(point):
				_given.clear()
				reset()
				return
			_given.append(point)
		_configured = true
	reset()

func place_vertex(cell: Vector2i) -> bool:
	if not _configured or is_complete() or not _contains(cell) or _vertices.has(cell):
		return false
	_vertices.append(cell)
	_cursor = cell
	queue_redraw()
	changed.emit()
	return true

func has_edits() -> bool:
	return _vertices.size() > _given.size()

func is_complete() -> bool:
	return _vertices.size() == 4

func construction_correct() -> bool:
	return is_complete() and Math.matches_kind(_geometry(), _lesson_id)

func measurement_text() -> String:
	return "꼭짓점 %d/4" % _vertices.size()

func undo_last() -> void:
	if not has_edits(): return
	_cursor = _vertices.pop_back()
	queue_redraw()
	changed.emit()

func reset() -> void:
	_vertices.assign(_given)
	_cursor = _vertices.back() if not _vertices.is_empty() else Vector2i(Vector2(_grid_size) * 0.5)
	_reset_pointer()
	changed.emit()

func _contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x <= _grid_size.x and cell.y >= 0 and cell.y <= _grid_size.y

func _geometry() -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for cell: Vector2i in _vertices:
		result.append(Vector2(cell) * GEOMETRY_STEP)
	return result

func _step() -> float:
	return maxf(1.0, minf((size.x - MARGIN * 2.0) / float(_grid_size.x), (size.y - MARGIN * 2.0) / float(_grid_size.y)))

func _board(step: float) -> Rect2:
	var board_size: Vector2 = Vector2(_grid_size) * step
	return Rect2((size - board_size) * 0.5, board_size)

func _snap(point: Vector2) -> Vector2i:
	var step: float = _step()
	var board: Rect2 = _board(step)
	if not board.grow(step * 0.45).has_point(point): return NO_CELL
	var target: Vector2 = (point - board.position) / step
	return Vector2i(roundi(target.x), roundi(target.y)).clamp(Vector2i.ZERO, _grid_size)

func _reset_pointer() -> void:
	_mouse_dragging = false
	_touch_index = -1
	_pointer_cell = NO_CELL
	queue_redraw()

func _pointer_exited() -> void:
	if _mouse_dragging or _touch_index >= 0: return
	_pointer_cell = NO_CELL
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _configured: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _touch_index < 0:
		_pointer_cell = _snap(event.position)
		queue_redraw()
	elif event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_pointer_cell = _snap(event.position)
		queue_redraw()
		accept_event()
	elif event is InputEventKey and event.pressed:
		_handle_key(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	_pointer_cell = _snap(event.position)
	if event.pressed:
		if _pointer_cell == NO_CELL: return
		grab_focus()
		_mouse_dragging = true
	elif _mouse_dragging:
		_mouse_dragging = false
		place_vertex(_pointer_cell)
	else:
		return
	queue_redraw()
	accept_event()

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch_index >= 0: return
		_pointer_cell = _snap(event.position)
		if _pointer_cell == NO_CELL: return
		grab_focus()
		_touch_index = event.index
	elif event.index == _touch_index:
		_touch_index = -1
		place_vertex(_snap(event.position))
		_pointer_cell = NO_CELL
	else:
		return
	queue_redraw()
	accept_event()

func _handle_key(event: InputEventKey) -> void:
	var direction: Vector2i = Vector2i.ZERO
	match event.keycode:
		KEY_LEFT: direction = Vector2i.LEFT
		KEY_RIGHT: direction = Vector2i.RIGHT
		KEY_UP: direction = Vector2i.UP
		KEY_DOWN: direction = Vector2i.DOWN
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not event.echo: place_vertex(_cursor)
		KEY_BACKSPACE, KEY_DELETE:
			if not event.echo: undo_last()
		KEY_Z:
			if not (event.ctrl_pressed or event.meta_pressed): return
			if not event.echo: undo_last()
		_:
			return
	_pointer_cell = NO_CELL
	_cursor = (_cursor + direction).clamp(Vector2i.ZERO, _grid_size)
	queue_redraw()
	accept_event()

func _draw() -> void:
	draw_texture_rect(GameArt.drafting_paper(), Rect2(Vector2.ZERO, size), false)
	var step: float = _step()
	var board: Rect2 = _board(step)
	for column: int in range(_grid_size.x + 1):
		var x: float = board.position.x + float(column) * step
		draw_line(Vector2(x, board.position.y), Vector2(x, board.end.y), GRID_INK)
	for row: int in range(_grid_size.y + 1):
		var y: float = board.position.y + float(row) * step
		draw_line(Vector2(board.position.x, y), Vector2(board.end.x, y), GRID_INK)
	var points: PackedVector2Array = PackedVector2Array()
	for cell: Vector2i in _vertices:
		points.append(board.position + Vector2(cell) * step)
	var valid_outline: bool = is_complete() and Math.is_valid(_geometry())
	if valid_outline: draw_colored_polygon(points, Color(0.0, 0.41, 0.35, 0.16))
	var player_color: Color = INVALID_INK if is_complete() and not valid_outline else PLAYER_INK
	for index: int in range(1, points.size()):
		var color: Color = GIVEN_INK if index < _given.size() else player_color
		draw_line(points[index - 1], points[index], color, 3.0, true)
	if is_complete(): draw_line(points[-1], points[0], player_color, 3.0, true)
	_draw_cursor(board.position, step, points)
	for index: int in range(points.size()):
		var color: Color = GIVEN_INK if index < _given.size() else player_color
		draw_circle(points[index], 6.0, color, true, -1.0, true)
		draw_string(QuadTheme.FONT, points[index] + Vector2(7, -6), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	if has_focus(): draw_rect(Rect2(Vector2.ONE, size - Vector2(2.0, 2.0)), FOCUS_INK, false, 2.0)

func _draw_cursor(origin: Vector2, step: float, points: PackedVector2Array) -> void:
	if not _configured or is_complete(): return
	if _pointer_cell == NO_CELL and not has_focus(): return
	var cell: Vector2i = _cursor if _pointer_cell == NO_CELL else _pointer_cell
	var target: Vector2 = origin + Vector2(cell) * step
	var available: bool = not _vertices.has(cell)
	if not points.is_empty() and available:
		draw_dashed_line(points[-1], target, PLAYER_INK, 2.0, 6.0, true, true)
	draw_arc(target, 8.0, 0.0, TAU, 24, PLAYER_INK if available else GIVEN_INK, 2.0, true)
