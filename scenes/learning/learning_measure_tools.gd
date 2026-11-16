class_name LearningMeasureTools
extends Control

const RULER: String = "ruler"
const PROTRACTOR: String = "protractor"
const BODY_COLOR: Color = Color(0.47, 0.80, 0.87, 0.27)
const INK: Color = Color("163e50")
const HANDLE_COLOR: Color = Color("185b78")
const HANDLE_RADIUS: float = 13.0
const RULER_DEPTH: float = 41.0
const MIN_RULER_CENTIMETERS: int = 8
const MAX_RULER_CENTIMETERS: int = 12

enum Drag { NONE, MOVE, ROTATE }

var tool_kind: String = ""
var tool_origin: Vector2 = Vector2.ZERO
var tool_angle: float = 0.0
var pixels_per_cm: float = 20.0
var _positions: Dictionary = {}
var _angles: Dictionary = {}
var _drag: Drag = Drag.NONE
var _drag_pointer: Vector2 = Vector2.ZERO
var _drag_origin: Vector2 = Vector2.ZERO
var _drag_angle: float = 0.0
var _touch_index: int = -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	resized.connect(_on_resize)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): _end_drag())
	hide()

func select_tool(kind: String) -> void:
	if kind not in ["", RULER, PROTRACTOR] or tool_kind == kind: return
	if not tool_kind.is_empty():
		_positions[tool_kind] = tool_origin
		_angles[tool_kind] = tool_angle
	_end_drag()
	tool_kind = kind
	if tool_kind.is_empty():
		hide()
		return
	var initial: Vector2 = size * Vector2(0.72, 0.68)
	if kind == RULER:
		initial.x = minf(size.x * 0.25, size.x - _ruler_length() - 12.0)
		initial.y = minf(initial.y, size.y - RULER_DEPTH - HANDLE_RADIUS - 15.0)
	tool_origin = _clamp_origin(_positions.get(kind, initial))
	tool_angle = float(_angles.get(kind, 0.0))
	show()
	queue_redraw()

func clear_tool() -> void:
	_end_drag()
	tool_kind = ""
	tool_origin = Vector2.ZERO
	tool_angle = 0.0
	_positions.clear()
	_angles.clear()
	hide()

func set_pixels_per_cm(value: float) -> void:
	if not is_finite(value) or value <= 0.0 or is_equal_approx(pixels_per_cm, value): return
	pixels_per_cm = value
	queue_redraw()

func move_by(delta: Vector2) -> void:
	if not tool_kind.is_empty(): _apply_transform(tool_origin + delta, tool_angle)

func rotate_by(degrees: float) -> void:
	if not tool_kind.is_empty(): _apply_transform(tool_origin, tool_angle + deg_to_rad(degrees))

func rotation_handle_position() -> Vector2:
	var offset: Vector2 = Vector2(minf(_ruler_length() * 0.55, 94.0), RULER_DEPTH + 13.0) if tool_kind == RULER else Vector2(0.0, -_radius() - 12.0)
	var margin: Vector2 = Vector2(minf(size.x * 0.5, HANDLE_RADIUS + 2.0), minf(size.y * 0.5, HANDLE_RADIUS + 2.0))
	return (tool_origin + offset.rotated(tool_angle)).clamp(margin, size - margin)

func handle_input(event: InputEvent) -> bool:
	if tool_kind.is_empty() or not is_visible_in_tree(): return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return _touch_index >= 0 or _hit_body(event.position) or _hit_handle(event.position)
		if event.pressed:
			return _touch_index < 0 and _begin_drag(event.position)
		if _drag != Drag.NONE and _touch_index < 0:
			_drag_to(event.position)
			_end_drag()
			return true
	elif event is InputEventMouseMotion and _drag != Drag.NONE:
		if _touch_index < 0: _drag_to(event.position)
		return true
	elif event is InputEventScreenTouch:
		if event.pressed and _touch_index < 0 and _begin_drag(event.position):
			_touch_index = event.index
			return true
		if not event.pressed and event.index == _touch_index:
			_drag_to(event.position)
			_end_drag()
			return true
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_drag_to(event.position)
		return true
	elif event is InputEventKey and event.pressed:
		return _handle_key(event)
	return false

func _handle_key(event: InputEventKey) -> bool:
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return false
	if event.shift_pressed and event.keycode in [KEY_LEFT, KEY_RIGHT]:
		rotate_by(-5.0 if event.keycode == KEY_LEFT else 5.0)
		return true
	var direction: Vector2
	match event.keycode:
		KEY_LEFT: direction = Vector2.LEFT
		KEY_RIGHT: direction = Vector2.RIGHT
		KEY_UP: direction = Vector2.UP
		KEY_DOWN: direction = Vector2.DOWN
		_: return false
	move_by(direction * 5.0)
	return true

func _hit_body(point: Vector2) -> bool:
	var local: Vector2 = (point - tool_origin).rotated(-tool_angle)
	if tool_kind == RULER: return Rect2(Vector2(-3.0, -5.0), Vector2(_ruler_length() + 6.0, RULER_DEPTH + 10.0)).has_point(local)
	return local.y <= 7.0 and local.length_squared() <= pow(_radius() + 5.0, 2)

func _hit_handle(point: Vector2) -> bool:
	return point.distance_squared_to(rotation_handle_position()) <= pow(HANDLE_RADIUS + 6.0, 2)

func _begin_drag(point: Vector2) -> bool:
	if _hit_handle(point):
		_drag = Drag.ROTATE
	elif _hit_body(point):
		_drag = Drag.MOVE
	else:
		return false
	_drag_pointer = point
	_drag_origin = tool_origin
	_drag_angle = tool_angle
	return true

func _drag_to(point: Vector2) -> void:
	if _drag == Drag.MOVE:
		_apply_transform(_drag_origin + point - _drag_pointer, _drag_angle)
	elif _drag == Drag.ROTATE:
		var vector: Vector2 = point - _drag_origin
		if vector.length_squared() >= 64.0:
			_apply_transform(_drag_origin, _drag_angle + (_drag_pointer - _drag_origin).angle_to(vector))

func _end_drag() -> void:
	_drag = Drag.NONE
	_touch_index = -1

func _apply_transform(next_origin: Vector2, next_angle: float) -> void:
	var bounded: Vector2 = _clamp_origin(next_origin)
	var wrapped: float = wrapf(next_angle, -PI, PI)
	if tool_origin.is_equal_approx(bounded) and is_equal_approx(tool_angle, wrapped): return
	tool_origin = bounded
	tool_angle = wrapped
	queue_redraw()

func _on_resize() -> void:
	if tool_kind.is_empty(): return
	tool_origin = _clamp_origin(tool_origin)
	queue_redraw()

func _clamp_origin(point: Vector2) -> Vector2:
	var margin: Vector2 = Vector2(minf(size.x * 0.5, 6.0), minf(size.y * 0.5, 6.0))
	return point.clamp(margin, size - margin)

func _ruler_centimeters() -> int:
	return clampi(floori(maxf(size.x - 38.0, 1.0) / pixels_per_cm), MIN_RULER_CENTIMETERS, MAX_RULER_CENTIMETERS)

func _ruler_length() -> float:
	return pixels_per_cm * _ruler_centimeters()

func _radius() -> float:
	return clampf(minf(size.x * 0.24, size.y * 0.40), 24.0, 119.0)

func _draw() -> void:
	if tool_kind.is_empty(): return
	draw_set_transform(tool_origin, tool_angle)
	if tool_kind == RULER:
		_draw_ruler()
	else:
		_draw_protractor()
	draw_set_transform(Vector2.ZERO)
	_draw_rotation_handle()

func _draw_ruler() -> void:
	var centimeters: int = _ruler_centimeters()
	var body: Rect2 = Rect2(Vector2.ZERO, Vector2(_ruler_length(), RULER_DEPTH))
	draw_rect(body, BODY_COLOR)
	draw_rect(body, INK, false, 1.5, true)
	var marks_per_cm: int = 10 if pixels_per_cm >= 19.0 else (2 if pixels_per_cm >= 8.0 else 1)
	var number_stride: int = maxi(1, ceili(19.0 / pixels_per_cm))
	var half_cm: int = marks_per_cm >> 1
	for mark: int in range(centimeters * marks_per_cm + 1):
		var reading: float = float(mark) / float(marks_per_cm)
		var whole: bool = mark % marks_per_cm == 0
		var half: bool = half_cm > 0 and mark % half_cm == 0
		var x: float = reading * pixels_per_cm
		var tick: float = 13.0 if whole else (9.0 if half else 5.0)
		draw_line(Vector2(x, 0.0), Vector2(x, tick), INK, 1.5 if whole else 1.0, true)
		if whole and roundi(reading) % number_stride == 0:
			_draw_number(str(roundi(reading)), Vector2(x, 26.0), 13)
	_draw_number("cm", Vector2(minf(19.0, body.size.x * 0.5), 38.0), 10)

func _draw_protractor() -> void:
	var radius: float = _radius()
	var curve: PackedVector2Array = PackedVector2Array()
	for degree: int in range(0, 181, 3):
		curve.append(Vector2.from_angle(-deg_to_rad(float(degree))) * radius)
	draw_colored_polygon(curve, BODY_COLOR)
	draw_polyline(curve, INK, 1.6, true)
	draw_line(Vector2(-radius, 0.0), Vector2(radius, 0.0), INK, 1.6, true)
	for degree: int in range(0, 181, 1 if radius >= 72.0 else 5):
		var direction: Vector2 = Vector2.from_angle(-deg_to_rad(float(degree)))
		var tick: float = 13.0 if degree % 10 == 0 else (7.0 if degree % 5 == 0 else 3.0)
		draw_line(direction * radius, direction * (radius - tick), INK, 1.2, true)
		if degree % 30 == 0:
			_draw_number(str(degree) + "°", direction * maxf(6.0, radius - 26.0) + Vector2(0.0, 4.0), 12)
	draw_line(Vector2(-6.0, 0.0), Vector2(6.0, 0.0), INK, 2.0, true)
	draw_line(Vector2(0.0, -6.0), Vector2(0.0, 6.0), INK, 2.0, true)

func _draw_number(text: String, anchor: Vector2, font_size: int) -> void:
	var width: float = QuadTheme.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_set_transform(tool_origin + anchor.rotated(tool_angle))
	draw_string(QuadTheme.FONT, Vector2(-width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
	draw_set_transform(tool_origin, tool_angle)

func _draw_rotation_handle() -> void:
	var point: Vector2 = rotation_handle_position()
	var attachment: Vector2 = Vector2(minf(_ruler_length() * 0.55, 94.0), RULER_DEPTH) if tool_kind == RULER else Vector2(0.0, -_radius())
	draw_line(tool_origin + attachment.rotated(tool_angle), point, INK, 1.5, true)
	draw_circle(point, HANDLE_RADIUS, HANDLE_COLOR, true, -1.0, true)
	draw_circle(point, HANDLE_RADIUS, Color("b6eaff"), false, 1.5, true)
	draw_arc(point, 5.5, -0.6, 4.2, 16, Color.WHITE, 1.7, true)
	var arrow_tip: Vector2 = point + Vector2.from_angle(-0.6) * 5.5
	draw_polyline(PackedVector2Array([arrow_tip + Vector2(-4.0, 1.0), arrow_tip, arrow_tip + Vector2(-1.0, -4.0)]), Color.WHITE, 1.6, true)
