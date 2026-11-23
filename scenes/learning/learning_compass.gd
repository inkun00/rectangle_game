class_name LearningCompass
extends BoxContainer

const DIRECTIONS: Array[String] = ["east", "south", "west", "north"]
const KOREAN: Array[String] = ["동쪽", "남쪽", "서쪽", "북쪽"]

var quarter_turns: int = 0
var _start: int = 0
var _clockwise: bool = true
var _angle: float = 0.0
var _motion: Tween
var _dial: CompassDial
var _status: Label
var _turn: Button
var _reset: Button

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_dial = CompassDial.new()
	_dial.name = "CompassDial"
	_dial.view = self
	add_child(_dial)
	var tools: VBoxContainer = VBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_theme_constant_override("separation", 4)
	add_child(tools)
	_status = QuadTheme.paragraph("", 18, QuadTheme.TEAL)
	_status.name = "CompassStatus"
	tools.add_child(_status)
	var actions: HFlowContainer = HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 4)
	tools.add_child(actions)
	_turn = QuadTheme.button("직각 한 번", turn_quarter, true)
	_turn.name = "CompassTurn"
	actions.add_child(_turn)
	_reset = QuadTheme.button("처음으로", reset)
	_reset.name = "CompassReset"
	actions.add_child(_reset)
	tools.add_child(QuadTheme.paragraph("버튼을 누르거나 화살표 끝을 끌어 보세요.", 15, QuadTheme.MUTED))
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	_layout()
	_refresh()

func configure(question: Dictionary) -> void:
	_start = maxi(0, DIRECTIONS.find(str(question.get("compass_start", "east"))))
	_clockwise = bool(question.get("compass_clockwise", true))
	reset()

func reset() -> void:
	_stop_motion()
	if is_instance_valid(_dial): _dial.cancel_drag()
	quarter_turns = 0
	_set_angle(_start * 90.0)
	_refresh()

func current_direction() -> String:
	return DIRECTIONS[_direction_index()]

func _direction_index() -> int:
	return posmod(_start + (quarter_turns if _clockwise else -quarter_turns), 4)

func _target_angle() -> float:
	return 90.0 * (_start + (quarter_turns if _clockwise else -quarter_turns))

func turn_quarter() -> void:
	if is_instance_valid(_dial): _dial.cancel_drag()
	quarter_turns += 1
	_settle()

func _settle() -> void:
	_stop_motion()
	var target: float = _target_angle()
	if not is_inside_tree() or is_equal_approx(_angle, target):
		_set_angle(target)
	else:
		_motion = create_tween()
		_motion.tween_method(_set_angle, _angle, target, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_refresh()

func _stop_motion() -> void:
	if is_instance_valid(_motion): _motion.kill()
	_motion = null

func _set_angle(value: float) -> void:
	_angle = value
	if is_instance_valid(_dial): _dial.queue_redraw()

func _refresh() -> void:
	if not is_instance_valid(_status): return
	_status.text = "직각 %d번 · %s" % [quarter_turns, KOREAN[_direction_index()]]
	var direction: String = "시계 방향" if _clockwise else "시계 반대 방향"
	_turn.text = "%s으로 돌리기" % direction
	_turn.tooltip_text = "%s으로 직각 한 번(90°) 돌려요." % direction
	_turn.accessibility_name = _turn.tooltip_text + " " + _status.text
	_dial.accessibility_name = _status.text

func focus_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if is_instance_valid(_turn): controls.append(_turn)
	if is_instance_valid(_reset): controls.append(_reset)
	return controls

func _layout() -> void:
	vertical = size.x < 350.0
	_dial.custom_minimum_size = Vector2(112.0 if not vertical else 0.0, 116.0 if vertical else 130.0)
	_dial.size_flags_horizontal = Control.SIZE_EXPAND_FILL if vertical else Control.SIZE_SHRINK_CENTER

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		_dial.cancel_drag()
		_stop_motion()
		_set_angle(_target_angle())

class CompassDial extends Control:
	const QUARTER: float = PI / 2.0
	const CARDINALS: Array[String] = ["동", "남", "서", "북"]
	const GOLD: Color = Color("#ffcf70")
	const INK: Color = Color("#173441")
	const RING: Color = Color("#59868a")
	var view: LearningCompass
	var _pointer: int = -2
	var _previous: float = 0.0
	var _sweep: float = 0.0
	var _moved: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		resized.connect(queue_redraw)

	func _radius() -> float:
		return maxf(12.0, minf(size.x, size.y) * 0.5 - 15.0)

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var r: float = _radius()
		draw_circle(center, r + 13, Color("#10232e"), true, -1, true)
		draw_circle(center, r, INK, true, -1, true)
		draw_arc(center, r, 0, TAU, 80, RING, 1.5, true)
		var facing: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(view._angle))
		var font: Font = QuadTheme.FONT
		for quarter: int in range(4):
			var axis: Vector2 = Vector2.RIGHT.rotated(quarter * QUARTER)
			draw_line(center + axis * 6.0, center + axis * (r - 4.0), RING.darkened(0.38), 1, true)
			var c: Color = GOLD if quarter == view._direction_index() else Color("#d5edeb")
			var label_center: Vector2 = center + axis * (r + 7.0)
			var text_width: float = font.get_string_size(CARDINALS[quarter], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(font, label_center + Vector2(-text_width * 0.5, (font.get_ascent(15) - font.get_descent(15)) * 0.5), CARDINALS[quarter], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, c)
		var perp: Vector2 = facing.orthogonal()
		var length: float = r * 0.91
		var tip: Vector2 = center + facing * length
		var shoulder: Vector2 = center + facing * length * 0.57
		draw_line(center - facing * r * 0.2, shoulder, Color("#dc9a49"), 6, true)
		draw_colored_polygon(PackedVector2Array([tip, shoulder + perp * 8, shoulder - perp * 8]), GOLD)
		draw_circle(center, 4.5, Color("#fff2ce"), true, -1, true)

	func cancel_drag() -> void:
		_pointer = -2
		_moved = false
		_sweep = 0.0

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _press(-1, event.position)
			else: _release(-1, event.position)
		elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
			_drag(-1, event.position)
		elif event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION:
			if event.pressed: _press(event.index, event.position)
			elif event.canceled and _pointer == event.index:
				cancel_drag()
				view._settle()
			else: _release(event.index, event.position)
		elif event is InputEventScreenDrag and event.device != InputEvent.DEVICE_ID_EMULATION:
			_drag(event.index, event.position)

	func _press(id: int, at: Vector2) -> void:
		if _pointer != -2: return
		var delta: Vector2 = at - size * 0.5
		var facing: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(view._angle))
		if delta.dot(facing) < 3.0 or delta.length() > _radius() + 10 or absf(delta.dot(facing.orthogonal())) > 16.0: return
		view._stop_motion()
		view._set_angle(view._target_angle())
		_pointer = id
		_previous = delta.angle()
		_sweep = 0.0
		_moved = false
		accept_event()

	func _drag(id: int, at: Vector2) -> void:
		if _pointer != id: return
		var offset: Vector2 = at - size * 0.5
		if offset.length() > 4.0:
			var angle_now: float = offset.angle()
			_sweep += angle_difference(_previous, angle_now) * (1 if view._clockwise else -1)
			_previous = angle_now
			if absf(_sweep) > 0.1: _moved = true
			view._set_angle(view._target_angle() + rad_to_deg(maxf(0, _sweep)) * (1 if view._clockwise else -1))
		accept_event()

	func _release(id: int, at: Vector2) -> void:
		if _pointer != id: return
		_drag(id, at)
		view.quarter_turns += roundi(maxf(0, _sweep) / QUARTER) if _moved else 1
		cancel_drag()
		view._settle()
		accept_event()
