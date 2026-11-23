class_name LearningClockAid
extends VBoxContainer

var hour: int = 12
var minute: int = 0
var _dial: ClockDial
var _readout: Label
var _instruction: Label
var _hours: HFlowContainer
var _steps: HFlowContainer
var _measure: Button

func configure(question: Dictionary) -> void:
	if _dial == null: _build()
	for child: Node in _hours.get_children():
		_hours.remove_child(child)
		child.queue_free()
	for preset: int in question.get("clock_hours", [2, 3, 6]):
		if preset < 1 or preset > 12: continue
		var button: Button = QuadTheme.button("%d시" % preset, set_time.bind(preset, 0))
		button.name = "ClockHour%d" % preset
		_hours.add_child(button)
	_measure.set_pressed_no_signal(false)
	_set_measure(false)
	_dial.drag_hand = ""
	set_time(12, 0)

func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 5)
	_readout = QuadTheme.label("", 18, QuadTheme.INK)
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_readout)
	_dial = ClockDial.new()
	_dial.name = "ClockDial"
	_dial.clock = self
	_dial.custom_minimum_size = Vector2(140, 158)
	_dial.focus_mode = Control.FOCUS_ALL
	_dial.tooltip_text = "방향키 좌우로 한 시간, 위아래로 5분씩 움직여요."
	_dial.focus_entered.connect(_dial.queue_redraw)
	_dial.focus_exited.connect(_dial.queue_redraw)
	add_child(_dial)
	_hours = HFlowContainer.new()
	_hours.alignment = FlowContainer.ALIGNMENT_CENTER
	add_child(_hours)
	_steps = HFlowContainer.new()
	_steps.alignment = FlowContainer.ALIGNMENT_CENTER
	add_child(_steps)
	var back: Button = QuadTheme.button("−5분", shift_minutes.bind(-5))
	back.name = "ClockBack5"
	_steps.add_child(back)
	var forward: Button = QuadTheme.button("+5분", shift_minutes.bind(5))
	forward.name = "ClockForward5"
	_steps.add_child(forward)
	_measure = QuadTheme.button("각 보기", Callable())
	_measure.name = "ClockMeasure"
	_measure.toggle_mode = true
	_measure.toggled.connect(_set_measure)
	_steps.add_child(_measure)
	_instruction = QuadTheme.paragraph("", 15, QuadTheme.MUTED)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_instruction)

func focus_controls() -> Array[Control]:
	var controls: Array[Control] = [_dial]
	for row: HFlowContainer in [_hours, _steps]:
		for child: Node in row.get_children(): controls.append(child as Control)
	return controls

func set_time(hours: int, minutes: int) -> void:
	var total: int = posmod(hours * 60 + minutes, 720)
	hour = floori(float(total) / 60)
	if hour == 0: hour = 12
	minute = total % 60
	_readout.text = "시계 · %d시" % hour if minute == 0 else "시계 · %d시 %d분" % [hour, minute]
	_dial.queue_redraw()

func shift_minutes(delta: int) -> void:
	set_time(hour, minute + delta)

func hour_degrees() -> float:
	return (hour % 12) * 30.0 + minute * 0.5

func angle_degrees() -> float:
	return absf(wrapf(minute * 6.0 - hour_degrees(), -180.0, 180.0))

func _set_measure(active: bool) -> void:
	_instruction.text = "숫자 사이 한 칸은 30°예요.\n두 바늘 사이의 각을 살펴봐요." if active else "시각을 고르거나\n두 바늘을 움직여 보세요."
	_dial.queue_redraw()

class ClockDial extends Control:
	var clock: LearningClockAid
	var drag_hand: String = ""

	func _radius() -> float:
		return minf(size.x, size.y) * 0.47

	func _tip(degrees: float, distance: float) -> Vector2:
		return size * 0.5 + Vector2.UP.rotated(deg_to_rad(degrees)) * _radius() * distance

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = _radius()
		var ink: Color = Color("253b4a")
		draw_circle(center, radius, Color("fff5d8"), true, -1.0, true)
		draw_arc(center, radius, 0.0, TAU, 96, QuadTheme.TEAL if has_focus() else Color("b7915b"), 3.0, true)
		for tick: int in range(60):
			var major: bool = tick % 5 == 0
			draw_line(_tip(tick * 6, 0.87 if major else 0.93), _tip(tick * 6, 0.97), ink, 2.0 if major else 1.0, true)
		for label: int in range(1, 13):
			var position_on_dial: Vector2 = _tip(label * 30, 0.74)
			draw_string(QuadTheme.FONT, position_on_dial + Vector2(-12, 5), str(label), HORIZONTAL_ALIGNMENT_CENTER, 24, 14, ink)
		var start: float = clock.hour_degrees()
		var span: float = wrapf(clock.minute * 6.0 - start, -180.0, 180.0)
		if clock._measure.button_pressed and absf(span) > 0.01:
			var sector: PackedVector2Array = PackedVector2Array([center])
			for step: int in range(37): sector.append(_tip(start + span * step / 36.0, 0.44))
			draw_colored_polygon(sector, Color("bde4d3"))
		draw_line(center, _tip(start, 0.47), Color("a24c25"), 7.0, true)
		draw_circle(_tip(start, 0.47), 3.5, Color("a24c25"), true, -1.0, true)
		draw_line(center, _tip(clock.minute * 6, 0.67), ink, 3.0, true)
		draw_circle(center, 4.5, ink, true, -1.0, true)

	func _begin_drag(point: Vector2) -> void:
		var distance: float = point.distance_to(size * 0.5) / _radius()
		if distance < 0.12 or distance > 1.1: return
		grab_focus()
		var short_tip: Vector2 = _tip(clock.hour_degrees(), 0.47)
		var long_tip: Vector2 = _tip(clock.minute * 6, 0.67)
		drag_hand = "minute" if point.distance_squared_to(long_tip) < point.distance_squared_to(short_tip) else "hour"
		_move_hand(point)

	func _move_hand(point: Vector2) -> void:
		if drag_hand.is_empty(): return
		var offset: Vector2 = point - size * 0.5
		if offset.length() < _radius() * 0.1: return
		var degrees: float = fposmod(rad_to_deg(Vector2.UP.angle_to(offset)), 360.0)
		if drag_hand == "hour":
			clock.set_time(roundi((degrees - clock.minute * 0.5) / 30.0), clock.minute)
		else:
			var target: int = posmod(roundi(degrees / 30.0) * 5, 60)
			clock.shift_minutes(posmod(target - clock.minute + 30, 60) - 30)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_LEFT: clock.shift_minutes(-60)
				KEY_RIGHT: clock.shift_minutes(60)
				KEY_UP: clock.shift_minutes(5)
				KEY_DOWN: clock.shift_minutes(-5)
				_: return
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _begin_drag(event.position)
			else: drag_hand = ""
		elif event is InputEventMouseMotion and not drag_hand.is_empty(): _move_hand(event.position)
		elif event is InputEventScreenTouch:
			if event.pressed: _begin_drag(event.position)
			else: drag_hand = ""
		elif event is InputEventScreenDrag and not drag_hand.is_empty(): _move_hand(event.position)
		else: return
		accept_event()
