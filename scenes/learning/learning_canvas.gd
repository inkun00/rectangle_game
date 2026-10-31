class_name LearningCanvas
extends Control

const Catalog = preload("res://scripts/learning/learning_catalog.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const Art = preload("res://scripts/construction_art.gd")
const LETTERS: Array[String] = ["가", "나", "다", "라"]
signal changed
var lesson_id: String = "perpendicular"
var value: float = 55.0
var diagram_rotation: float = 0.0
var measured: bool = false
var selected_choices: Array[int] = []
var focus_index: int = 0
var question_mode: bool = false
var question_angle: float = 65.0
var question_size: Vector2 = Vector2(150, 100)
var _dragging: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(240, 170 if question_mode else 250)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)
	visibility_changed.connect(func(): _dragging = false)

func configure(id: String) -> void:
	question_mode = false
	lesson_id = id
	value = 60.0 if id == "distance" else (20.0 if id == "parallel" else 55.0)
	diagram_rotation = 0.0
	measured = false
	selected_choices.clear()
	focus_index = 0
	queue_redraw()

func configure_question(quest_id: String) -> void:
	configure(Catalog.quest_topic(quest_id))
	question_mode = true
	question_size = Vector2(144, 192) if quest_id == "snow_lanterns" else Vector2(150, 100)
	question_angle = 70.0 if quest_id == "citadel_banners" else 65.0
	value = 0.0 if lesson_id == "parallel" else (60.0 if lesson_id == "distance" else 90.0)
	diagram_rotation = 24.0 if quest_id in ["snow_windows", "right_angle_sign"] else 0.0
	custom_minimum_size.y = 170

func is_line_activity() -> bool:
	return lesson_id in ["perpendicular", "parallel", "distance"]

func set_value(next: float) -> void:
	value = snappedf(clampf(next, -100.0, 100.0), 10.0) if lesson_id == "distance" else snappedf(clampf(next, 0.0, 180.0), 5.0)
	changed.emit()
	queue_redraw()

func turn() -> void:
	diagram_rotation = fmod(diagram_rotation + 30.0, 360.0)
	changed.emit()
	queue_redraw()

func measure() -> void:
	measured = true
	changed.emit()
	queue_redraw()

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
		_: return selected_choices == Catalog.correct_choices(lesson_id)

func measurement_text() -> String:
	if not measured: return "‘재어 보기’를 눌러 변과 각을 확인해요. 길이는 그림 속 칸 단위예요."
	match lesson_id:
		"perpendicular": return "만나는 각: %s° · 두 선이 수직이면 한 선은 다른 선에 대한 수선이에요." % Math.measurement_label(value)
		"parallel": return "공통 수선과 만나는 각: 90° / %s°" % Math.measurement_label(absf(90.0 - value))
		"distance": return "수직인 선분: 4칸 · 움직인 선분: %s칸" % Math.measurement_label(Vector2(value, 80).length() / 20.0)
		_:
			var vertices: PackedVector2Array = question_vertices() if question_mode else Catalog.figures(lesson_id)[focus_index]
			var sides: PackedStringArray = PackedStringArray()
			for side: float in Math.side_lengths(vertices): sides.append(Math.measurement_label(side / 20.0))
			return "%s · 변 ㄱㄴ / ㄴㄷ / ㄷㄹ / ㄹㄱ: %s칸\n%s" % ["관찰 도형" if question_mode else LETTERS[focus_index], " / ".join(sides), Math.property_summary(vertices)]

func question_vertices() -> PackedVector2Array:
	if lesson_id == "parallelogram":
		var side: Vector2 = Vector2.from_angle(deg_to_rad(-question_angle)) * 110.0
		return PackedVector2Array([Vector2(-80, 35), Vector2(80, 35), Vector2(80, 35) + side, Vector2(-80, 35) + side])
	return Math.create_vertices(lesson_id, question_size)

func _model_scale() -> float:
	return maxf(0.01, minf(size.x / 600.0, size.y / 300.0))

func _to_model(point: Vector2) -> Vector2:
	return (point - size * 0.5) / _model_scale() + Vector2(300, 150)

func _card(index: int) -> Rect2:
	return Rect2(Vector2(12 + (index % 2) * 294, 10 + int(index / 2) * 144), Vector2(282, 134))

func _gui_input(event: InputEvent) -> void:
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
	var local: Vector2 = (point - Vector2(300, 150)).rotated(-deg_to_rad(diagram_rotation))
	if lesson_id == "distance": set_value(local.x)
	else:
		if lesson_id == "parallel": local -= Vector2(20, 30)
		set_value(fposmod(rad_to_deg(local.angle()), 180.0))

func _draw() -> void:
	draw_style_box(Art.card_panel(0, Color("f7faf5")), Rect2(Vector2.ZERO, size))
	var zoom: float = _model_scale()
	draw_set_transform(size * 0.5 - Vector2(300, 150) * zoom, 0.0, Vector2.ONE * zoom)
	if is_line_activity(): _draw_lines()
	elif question_mode:
		var vertices: PackedVector2Array = question_vertices()
		var bounds: Rect2 = Math.bounds(Math.rotate_vertices(vertices, diagram_rotation))
		var fit: float = minf(400.0 / bounds.size.x, 210.0 / bounds.size.y)
		_draw_quad(vertices, Vector2(300, 150) - bounds.get_center() * fit, fit, true, diagram_rotation)
	else:
		var examples: Array[PackedVector2Array] = Catalog.figures(lesson_id)
		for index: int in range(4):
			var card: Rect2 = _card(index)
			draw_style_box(Art.card_panel(0, Color("d9eee4") if selected_choices.has(index) else Color("f9fbf7")), card)
			draw_rect(card, QuadTheme.TEAL if selected_choices.has(index) else Color("bdcec5"), false, 2.0 if selected_choices.has(index) else 1.0)
			_draw_quad(examples[index], card.get_center() - Vector2(0, 8), 0.63, measured and focus_index == index, diagram_rotation)
			_text(card.position + Vector2(12, 24), LETTERS[index] + (" · 선택" if selected_choices.has(index) else ""), 18)
			if has_focus() and focus_index == index: draw_rect(card.grow(-4), QuadTheme.TEAL, false, 2)
	draw_set_transform(Vector2.ZERO)
	if has_focus(): draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2), QuadTheme.TEAL, false, 2)

func _text(at: Vector2, text: String, font_size: int = 18, ink: Color = QuadTheme.INK) -> void:
	var readable_size: int = ceili(float(font_size) / _model_scale()) if question_mode else font_size
	draw_string(QuadTheme.FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, readable_size, ink)

func _draw_quad(vertices: PackedVector2Array, center: Vector2, zoom: float, details: bool, turn_degrees: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for vertex: Vector2 in vertices: points.append(center + vertex.rotated(deg_to_rad(turn_degrees)) * zoom)
	draw_colored_polygon(points, Color("c7ded4"))
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, QuadTheme.TEAL, 2.5, true)
	if not details: return
	var angles: PackedFloat32Array = Math.angles(vertices)
	var labels: Array[String] = ["ㄱ", "ㄴ", "ㄷ", "ㄹ"]
	for index: int in range(4):
		var first: Vector2 = points[index]
		var next: Vector2 = points[(index + 1) % 4]
		var previous: Vector2 = points[(index + 3) % 4]
		var a: Vector2 = (next - first).normalized()
		var b: Vector2 = (previous - first).normalized()
		_text(first + (first - center).normalized() * 13 + Vector2(-5, 5), labels[index], 16)
		if absf(angles[index] - 90.0) < 0.1:
			draw_polyline(PackedVector2Array([first + a * 10, first + (a + b) * 10, first + b * 10]), QuadTheme.TEAL, 1.8, true)
		elif question_mode and lesson_id == "parallelogram" and measured:
			_text(first + (a + b).normalized() * 28 + Vector2(-12, 5), Math.measurement_label(angles[index]) + "°", 17)
		var opposite: Vector2 = points[(index + 3) % 4] - points[(index + 2) % 4]
		if absf((next - first).normalized().cross(opposite.normalized())) <= Math.TOLERANCE:
			var midpoint: Vector2 = (first + next) * 0.5
			var normal: Vector2 = a.orthogonal()
			draw_line(midpoint - a * 5 + normal * 4, midpoint + a * 4, Color("b46b27"), 2, true)
			draw_line(midpoint + a * 4, midpoint - a * 5 - normal * 4, Color("b46b27"), 2, true)

func _diagram_point(point: Vector2) -> Vector2:
	return Vector2(300, 150) + (point - Vector2(300, 150)).rotated(deg_to_rad(diagram_rotation))

func _line(a: Vector2, b: Vector2, color: Color, width: float = 3.0) -> void:
	draw_line(_diagram_point(a), _diagram_point(b), color, width, true)

func _straight_line(a: Vector2, b: Vector2, color: Color) -> void:
	_line(a, b, color)
	var direction: Vector2 = (b - a).normalized()
	for endpoint: Vector2 in [a, b]:
		var inward: Vector2 = direction if endpoint == a else -direction
		_line(endpoint, endpoint + inward * 10 + inward.orthogonal() * 5, color, 2)
		_line(endpoint, endpoint + inward * 10 - inward.orthogonal() * 5, color, 2)

func _draw_lines() -> void:
	var handle: Vector2
	if lesson_id == "perpendicular":
		_straight_line(Vector2(70, 150), Vector2(530, 150), QuadTheme.INK)
		var direction: Vector2 = Vector2.from_angle(deg_to_rad(value)) * 115
		_straight_line(Vector2(300, 150) - direction, Vector2(300, 150) + direction, QuadTheme.TEAL)
		handle = Vector2(300, 150) + direction
		if measured:
			_text(Vector2(325, 138), Math.measurement_label(value) + "°", 20)
			if absf(value - 90.0) < 0.1:
				_line(Vector2(316, 150), Vector2(316, 166), Color("b46b27"), 2)
				_line(Vector2(316, 166), Vector2(300, 166), Color("b46b27"), 2)
	elif lesson_id == "parallel":
		_straight_line(Vector2(55, 95), Vector2(510, 95), QuadTheme.INK)
		var direction: Vector2 = Vector2.from_angle(deg_to_rad(value)) * 90
		_straight_line(Vector2(320, 180) - direction, Vector2(320, 180) + direction, QuadTheme.TEAL)
		handle = Vector2(320, 180) + direction
		if measured:
			_line(Vector2(300, 55), Vector2(300, 245), Color("b46b27"), 2)
			_text(Vector2(310, 87), "90°", 18)
			_text(Vector2(310, 170), Math.measurement_label(absf(90.0 - value)) + "°", 18)
	else:
		_straight_line(Vector2(65, 110), Vector2(535, 110), QuadTheme.INK)
		_straight_line(Vector2(100, 190), Vector2(565, 190), QuadTheme.INK)
		_line(Vector2(180, 110), Vector2(180, 190), Color("b46b27"), 2)
		_line(Vector2(300, 110), Vector2(300 + value, 190), QuadTheme.TEAL, 4)
		handle = Vector2(300 + value, 190)
		if measured:
			_text(Vector2(112, 157), "4칸", 20)
			_text(Vector2(320 + value * 0.5, 156), Math.measurement_label(Vector2(value, 80).length() / 20.0) + "칸", 20)
			_line(Vector2(180, 174), Vector2(196, 174), Color("b46b27"), 2)
			_line(Vector2(196, 174), Vector2(196, 190), Color("b46b27"), 2)
	if not question_mode:
		draw_circle(_diagram_point(handle), 12, Color("2c7dba"))
		draw_circle(_diagram_point(handle), 6, Color.WHITE)
