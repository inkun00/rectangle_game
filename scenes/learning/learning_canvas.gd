class_name LearningCanvas
extends Control

const Catalog = preload("res://scripts/learning/learning_catalog.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const MeasureTools = preload("res://scenes/learning/learning_measure_tools.gd")
const LETTERS: Array[String] = ["가", "나", "다", "라"]
const MODEL_UNITS_PER_CM: float = 20.0
const MODEL_CENTER: Vector2 = Vector2(300.0, 150.0)
const CARD_FIGURE_SCALE: float = 0.63
signal changed
signal measure_tool_changed(kind: String)
var lesson_id: String = "perpendicular"
var value: float = 55.0
var diagram_rotation: float = 0.0
var measured: bool = false
var selected_choices: Array[int] = []
var focus_index: int = 0
var question_mode: bool = false
var question_angle: float = 65.0
var question_size: Vector2 = Vector2(150, 100)
var measure_tools: MeasureTools
var _activity_figures: Array[PackedVector2Array] = []
var _activity_vertices: PackedVector2Array
var _distance_span: float = 80.0
var _dragging: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(240, 170 if question_mode else 250)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	measure_tools = MeasureTools.new()
	measure_tools.name = "LearningMeasureTools"
	add_child(measure_tools)
	resized.connect(_update_measurement_geometry)
	visibility_changed.connect(func(): _dragging = false)
	_update_measurement_geometry()

func configure(id: String) -> void:
	question_mode = false
	lesson_id = id
	value = 60.0 if id == "distance" else (20.0 if id == "parallel" else 55.0)
	diagram_rotation = 0.0
	measured = false
	if is_instance_valid(measure_tools): measure_tools.clear_tool()
	measure_tool_changed.emit("")
	_activity_figures.clear()
	_activity_vertices = PackedVector2Array()
	_distance_span = 80.0
	_dragging = false
	selected_choices.clear()
	focus_index = 0
	queue_redraw()

func configure_activity(activity: Dictionary) -> void:
	configure(str(activity.lesson_id))
	question_mode = str(activity.mode) == "measure"
	_distance_span = float(activity.get("gap", 80.0))
	var figures: Array = activity.get("figures", [])
	if figures.size() == 4: _activity_figures.assign(figures)
	_activity_vertices = activity.get("vertices", PackedVector2Array())
	diagram_rotation = float(activity.get("rotation", 0.0))
	set_value(float(activity.get("start_value", value)))

func configure_question(quest_id: String) -> void:
	configure(Catalog.quest_topic(quest_id))
	question_mode = true
	question_size = Vector2(144, 192) if quest_id == "snow_lanterns" else Vector2(150, 100)
	question_angle = 70.0 if quest_id == "citadel_banners" else 65.0
	value = 0.0 if lesson_id == "parallel" else (60.0 if lesson_id == "distance" else 90.0)
	diagram_rotation = 24.0 if quest_id in ["snow_windows", "right_angle_sign"] else 0.0
	custom_minimum_size.y = 170
	_update_measurement_geometry()

func is_line_activity() -> bool:
	return lesson_id in ["perpendicular", "parallel", "distance"]

func set_value(next: float) -> void:
	value = snappedf(clampf(next, -100.0, 100.0), 10.0) if lesson_id == "distance" else snappedf(clampf(next, 0.0, 180.0), 5.0)
	_update_measurement_geometry()
	changed.emit()

func turn() -> void:
	diagram_rotation = fmod(diagram_rotation + 30.0, 360.0)
	_update_measurement_geometry()
	changed.emit()

func measure() -> void:
	if _measure_tool_kind().is_empty():
		select_measure_tool("ruler" if lesson_id in ["rhombus", "distance"] else "protractor")
	elif is_inside_tree():
		grab_focus()

func select_measure_tool(kind: String) -> void:
	if kind not in ["ruler", "protractor"]: return
	measured = true
	if is_instance_valid(measure_tools):
		_update_measurement_geometry()
		measure_tools.select_tool(kind)
		if is_inside_tree(): grab_focus()
		measure_tool_changed.emit(kind)
	changed.emit()
	queue_redraw()

func close_measure_tools() -> void:
	if _measure_tool_kind().is_empty(): return
	measure_tools.select_tool("")
	if is_visible_in_tree(): grab_focus()
	measure_tool_changed.emit("")
	changed.emit()
	queue_redraw()

func _measure_tool_kind() -> String:
	return measure_tools.tool_kind if is_instance_valid(measure_tools) else ""

func add_measure_buttons(parent: Container, primary: bool = false) -> Array[Button]:
	var open: Button = QuadTheme.button("재어 보기", measure, primary)
	open.name = "OpenLearningMeasureTools"
	var ruler: Button = QuadTheme.button("투명 자", select_measure_tool.bind("ruler"))
	ruler.name = "SelectLearningRuler"
	var protractor: Button = QuadTheme.button("투명 각도기", select_measure_tool.bind("protractor"))
	protractor.name = "SelectLearningProtractor"
	var close: Button = QuadTheme.button("도구 넣기", close_measure_tools)
	close.name = "CloseLearningMeasureTools"
	var buttons: Array[Button] = [open, ruler, protractor, close]
	for button: Button in buttons: parent.add_child(button)
	ruler.hide()
	protractor.hide()
	close.hide()
	measure_tool_changed.connect(func(kind: String):
		for button: Button in [ruler, protractor, close]: button.visible = not kind.is_empty()
		ButtonArt.apply(ruler, kind == "ruler")
		ButtonArt.apply(protractor, kind == "protractor"))
	return buttons

func toggle_choice(index: int) -> void:
	if index < 0 or index >= 4 or question_mode: return
	focus_index = index
	if selected_choices.has(index): selected_choices.erase(index)
	else: selected_choices.append(index)
	selected_choices.sort()
	changed.emit()
	queue_redraw()

func construction_correct() -> bool:
	if not measured: return false
	match lesson_id:
		"perpendicular": return absf(value - 90.0) < 0.1
		"parallel": return absf(sin(deg_to_rad(value))) < 0.001
		"distance": return absf(value) < 0.1
		_:
			var answers: Array[int] = []
			var figures: Array[PackedVector2Array] = _figures()
			for index: int in range(figures.size()):
				if Math.matches_kind(figures[index], lesson_id): answers.append(index)
			return selected_choices == answers

func _figures() -> Array[PackedVector2Array]:
	return Catalog.figures(lesson_id) if _activity_figures.is_empty() else _activity_figures

func measurement_text() -> String:
	var guidance: String
	match _measure_tool_kind():
		"ruler": guidance = "자의 0을 꼭짓점 가까이 가져가 붙인 뒤, 다른 끝의 눈금을 읽어요."
		"protractor": guidance = "중심을 꼭짓점에 놓고 한 변에 0°를 맞춰요. 그 0°에서 시작하는 눈금으로 다른 변이 가리키는 각을 읽어요."
		_: return "‘재어 보기’를 누르면 투명 자와 각도기를 꺼낼 수 있어요."
	return guidance + "\n몸체를 끌어 옮기고, 둥근 손잡이로 돌려요. 방향키로 이동하고 Shift+왼쪽·오른쪽 방향키로 돌려요."

func question_vertices() -> PackedVector2Array:
	if not _activity_vertices.is_empty(): return _activity_vertices
	if lesson_id == "parallelogram":
		var side: Vector2 = Vector2.from_angle(deg_to_rad(-question_angle)) * 110.0
		return PackedVector2Array([Vector2(-80, 35), Vector2(80, 35), Vector2(80, 35) + side, Vector2(-80, 35) + side])
	return Math.create_vertices(lesson_id, question_size)

func _model_scale() -> float:
	return maxf(0.01, minf(size.x / 600.0, size.y / 300.0))

func _single_figure_bounds() -> Rect2:
	return Math.bounds(Math.rotate_vertices(question_vertices(), diagram_rotation))

func _single_figure_fit(bounds: Rect2) -> float:
	return minf(400.0 / bounds.size.x, 210.0 / bounds.size.y)

func measurement_pixels_per_cm() -> float:
	var diagram_scale: float = 1.0
	if not is_line_activity():
		diagram_scale = _single_figure_fit(_single_figure_bounds()) if question_mode else CARD_FIGURE_SCALE
	return MODEL_UNITS_PER_CM * _model_scale() * diagram_scale

func _update_measurement_geometry() -> void:
	if is_instance_valid(measure_tools):
		measure_tools.set_pixels_per_cm(measurement_pixels_per_cm())
		measure_tools.set_snap_points(measurement_snap_points())
	queue_redraw()

func measurement_snap_points() -> PackedVector2Array:
	var targets: PackedVector2Array = PackedVector2Array()
	if is_line_activity():
		var segments: Array[PackedVector2Array] = _diagram_lines()
		if lesson_id == "distance":
			for endpoint: Vector2 in segments[2]: targets.append(_diagram_point(endpoint))
		else:
			var intersection: Variant = Geometry2D.segment_intersects_segment(segments[0][0], segments[0][1], segments[1][0], segments[1][1])
			if intersection is Vector2: targets.append(_diagram_point(intersection))
	else:
		for vertices: PackedVector2Array in _diagram_figures(): targets.append_array(vertices)
	return _canvas_transform() * targets

func _canvas_transform() -> Transform2D:
	var zoom: float = _model_scale()
	return Transform2D(0.0, Vector2.ONE * zoom, 0.0, size * 0.5 - MODEL_CENTER * zoom)

func _to_model(point: Vector2) -> Vector2:
	return _canvas_transform().affine_inverse() * point

func _card(index: int) -> Rect2:
	return Rect2(Vector2(12 + (index % 2) * 294, 10 + int(index / 2) * 144), Vector2(282, 134))

func _diagram_figures() -> Array[PackedVector2Array]:
	if question_mode:
		var bounds: Rect2 = _single_figure_bounds()
		var fit: float = _single_figure_fit(bounds)
		return [_plot_figure(question_vertices(), MODEL_CENTER - bounds.get_center() * fit, fit)]
	var result: Array[PackedVector2Array] = []
	var examples: Array[PackedVector2Array] = _figures()
	for index: int in range(examples.size()):
		result.append(_plot_figure(examples[index], _card(index).get_center() - Vector2(0, 8), CARD_FIGURE_SCALE))
	return result

func _plot_figure(vertices: PackedVector2Array, center: Vector2, zoom: float) -> PackedVector2Array:
	return Transform2D(deg_to_rad(diagram_rotation), Vector2.ONE * zoom, 0.0, center) * vertices

func _gui_input(event: InputEvent) -> void:
	if is_instance_valid(measure_tools) and measure_tools.handle_input(event):
		_dragging = false
		if event is InputEventMouseButton or event is InputEventScreenTouch: grab_focus()
		accept_event()
		return
	if question_mode: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			if is_line_activity():
				_dragging = true
				_drag_to(_to_model(event.position))
			else:
				for index: int in range(4):
					if _card(index).has_point(_to_model(event.position)): toggle_choice(index)
		else: _dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_drag_to(_to_model(event.position))
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_RIGHT]:
			if is_line_activity(): set_value(value + (5 if event.keycode == KEY_RIGHT else -5) * (2 if lesson_id == "distance" else 1))
			else:
				focus_index = posmod(focus_index + (1 if event.keycode == KEY_RIGHT else -1), 4)
				changed.emit()
				queue_redraw()
			accept_event()
		elif event.keycode in [KEY_SPACE, KEY_ENTER] and not is_line_activity():
			toggle_choice(focus_index)
			accept_event()

func _drag_to(point: Vector2) -> void:
	var local: Vector2 = (point - MODEL_CENTER).rotated(-deg_to_rad(diagram_rotation))
	if lesson_id == "distance": set_value(local.x)
	else:
		if lesson_id == "parallel": local -= Vector2(20, 30)
		set_value(fposmod(rad_to_deg(local.angle()), 180.0))

func _draw() -> void:
	draw_texture_rect(GameArt.drafting_paper(), Rect2(Vector2.ZERO, size), false)
	draw_set_transform_matrix(_canvas_transform())
	if is_line_activity(): _draw_lines()
	elif question_mode:
		_draw_quad(_diagram_figures()[0], true)
	else:
		var figures: Array[PackedVector2Array] = _diagram_figures()
		for index: int in range(4):
			var card: Rect2 = _card(index)
			draw_rect(card, Color("d9eee4") if selected_choices.has(index) else Color("f9fbf7"))
			draw_rect(card, Color("0c6658") if selected_choices.has(index) else Color("bdcec5"), false, 2.0 if selected_choices.has(index) else 1.0)
			_draw_quad(figures[index], not _measure_tool_kind().is_empty() and focus_index == index)
			_text(card.position + Vector2(12, 24), LETTERS[index] + (" · 선택" if selected_choices.has(index) else ""), 18)
			if has_focus() and focus_index == index: draw_rect(card.grow(-4), Color("0c6658"), false, 2)
	draw_set_transform(Vector2.ZERO)
	if has_focus(): draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2), Color("0c6658"), false, 2)

func _text(at: Vector2, text: String, font_size: int = 18, ink: Color = Color("213b42")) -> void:
	var readable_size: int = ceili(float(font_size) / _model_scale()) if question_mode else font_size
	draw_string(QuadTheme.FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, readable_size, ink)

func _draw_quad(points: PackedVector2Array, label_vertices: bool) -> void:
	draw_colored_polygon(points, Color("c7ded4"))
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color("0c6658"), 2.5, true)
	if not label_vertices: return
	var center: Vector2 = Math.bounds(points).get_center()
	var labels: Array[String] = ["ㄱ", "ㄴ", "ㄷ", "ㄹ"]
	for index: int in range(4):
		var first: Vector2 = points[index]
		_text(first + (first - center).normalized() * 13 + Vector2(-5, 5), labels[index], 16)

func _diagram_point(point: Vector2) -> Vector2:
	return MODEL_CENTER + (point - MODEL_CENTER).rotated(deg_to_rad(diagram_rotation))

func _line(a: Vector2, b: Vector2, color: Color, width: float = 3.0) -> void:
	draw_line(_diagram_point(a), _diagram_point(b), color, width, true)

func _straight_line(a: Vector2, b: Vector2, color: Color) -> void:
	_line(a, b, color)
	var direction: Vector2 = (b - a).normalized()
	for endpoint: Vector2 in [a, b]:
		var inward: Vector2 = direction if endpoint == a else -direction
		_line(endpoint, endpoint + inward * 10 + inward.orthogonal() * 5, color, 2)
		_line(endpoint, endpoint + inward * 10 - inward.orthogonal() * 5, color, 2)

func _diagram_lines() -> Array[PackedVector2Array]:
	if lesson_id == "perpendicular":
		var direction: Vector2 = Vector2.from_angle(deg_to_rad(value)) * 115
		return [PackedVector2Array([Vector2(70, 150), Vector2(530, 150)]), PackedVector2Array([MODEL_CENTER - direction, MODEL_CENTER + direction])]
	if lesson_id == "parallel":
		var pivot: Vector2 = Vector2(320, 180)
		var direction: Vector2 = Vector2.from_angle(deg_to_rad(value)) * 90
		return [PackedVector2Array([Vector2(55, 95), Vector2(510, 95)]), PackedVector2Array([pivot - direction, pivot + direction])]
	var top: float = MODEL_CENTER.y - _distance_span * 0.5
	var bottom: float = MODEL_CENTER.y + _distance_span * 0.5
	return [
		PackedVector2Array([Vector2(65, top), Vector2(535, top)]),
		PackedVector2Array([Vector2(100, bottom), Vector2(565, bottom)]),
		PackedVector2Array([Vector2(MODEL_CENTER.x, top), Vector2(MODEL_CENTER.x + value, bottom)]),
	]

func _draw_lines() -> void:
	var segments: Array[PackedVector2Array] = _diagram_lines()
	var adjustable: PackedVector2Array = segments.back()
	for index: int in range(segments.size() - 1):
		_straight_line(segments[index][0], segments[index][1], Color("213b42"))
	if lesson_id == "distance": _line(adjustable[0], adjustable[1], Color("0c6658"), 4)
	else: _straight_line(adjustable[0], adjustable[1], Color("0c6658"))
	if not question_mode:
		var handle: Vector2 = _diagram_point(adjustable[1])
		draw_circle(handle, 12, Color("2c7dba"))
		draw_circle(handle, 6, Color.WHITE)
