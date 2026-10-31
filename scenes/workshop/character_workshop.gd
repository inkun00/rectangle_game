class_name CharacterWorkshop
extends Control

const Math = preload("res://scripts/core/quadrilateral_math.gd")
const Templates = preload("res://scripts/core/character_templates.gd")
const Document = preload("res://scripts/core/character_document.gd")

signal hint_requested(message: String)

var document: Document:
	set(value):
		if document != null and document.changed.is_connected(_document_changed):
			document.changed.disconnect(_document_changed)
		document = value
		if document != null:
			document.changed.connect(_document_changed)
		queue_redraw()
var selected_kind: String = "square"
var paint_color: Color = Color("28aaa0")
var _hover_slot: String = ""
var _dragging: bool = false
var _creating: bool = false
var _drag_origin: Vector2 = Vector2.ZERO
var _drag_position: Vector2 = Vector2.ZERO
var _press_position: Vector2 = Vector2.ZERO
var _drag_id: int = -1
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_font = get_theme_default_font()
	resized.connect(queue_redraw)
	mouse_exited.connect(_on_mouse_exited)
	if document == null:
		document = Document.new()

func select_kind(kind: String) -> void:
	if not Math.KINDS.has(kind):
		return
	selected_kind = kind
	queue_redraw()

func cancel_gesture() -> void:
	_dragging = false
	_creating = false
	_hover_slot = ""
	release_focus()
	queue_redraw()

func set_paint_color(color: Color) -> void:
	paint_color = color
	queue_redraw()

func canvas_scale() -> float:
	return maxf(0.35, minf(size.x / 490.0, (size.y - 106.0) / 375.0))

func canvas_origin() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5 + 8.0)

func character_to_screen(point: Vector2) -> Vector2:
	return canvas_origin() + point * canvas_scale()

func screen_to_character(point: Vector2) -> Vector2:
	return (point - canvas_origin()) / canvas_scale()

func _document_changed() -> void:
	if _dragging and document.selected_id != _drag_id:
		_dragging = false
	queue_redraw()

func _on_mouse_exited() -> void:
	_hover_slot = ""
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if document == null:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		var point: Vector2 = screen_to_character(motion.position)
		_hover_slot = _slot_at(point)
		if _dragging:
			_drag_position = _drag_origin + point - _press_position
		elif _creating:
			_drag_position = point
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _hover_slot.is_empty() else Control.CURSOR_CROSS
		queue_redraw()
	elif event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		var point: Vector2 = screen_to_character(mouse.position)
		if mouse.pressed:
			if is_inside_tree():
				grab_focus()
			_press(point)
		else:
			_release(point)
		accept_event()
	elif event is InputEventKey:
		var key: InputEventKey = event
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_ESCAPE:
			_dragging = false
			_creating = false
			document.select_shape(-1)
			queue_redraw()
			accept_event()

func _press(point: Vector2) -> void:
	var slot_id: String = _slot_at(point)
	if not slot_id.is_empty():
		var existing: Dictionary = document.shape_for_slot(slot_id)
		if existing.is_empty():
			var slot: Dictionary = document.get_slot(slot_id)
			if document.fill_slot(slot_id, selected_kind, paint_color):
				hint_requested.emit("%s에 %s을 붙였어요!" % [str(slot.label), Math.kind_name(selected_kind)])
			else:
				hint_requested.emit("%s에는 %s이 필요해요. 왼쪽에서 골라 주세요." % [str(slot.label), Math.kind_name(str(slot.kind))])
			return
	var hit: int = _shape_at(point)
	if hit >= 0:
		document.select_shape(hit)
		var shape: Dictionary = document.get_selected()
		_drag_id = hit
		_dragging = true
		_drag_origin = shape.position
		_drag_position = shape.position
		_press_position = point
	else:
		document.select_shape(-1)
		_creating = true
		_drag_position = point
		_press_position = point
	queue_redraw()

func _release(point: Vector2) -> void:
	if _dragging:
		_drag_position = _drag_origin + point - _press_position
		var distance: float = _drag_position.distance_to(_drag_origin)
		_dragging = false
		if distance >= 1.0:
			var selected: Dictionary = document.get_selected()
			var target_slot: String = _snap_slot(_drag_position, str(selected.get("kind", "")))
			if target_slot.is_empty() or not document.attach_selected(target_slot):
				document.move_selected(_drag_position.snapped(Vector2(2, 2)))
			else:
				hint_requested.emit("골격에 딱 맞게 붙었어요!")
	elif _creating:
		_creating = false
		var target_slot: String = _snap_slot(point, selected_kind)
		if not target_slot.is_empty():
			document.fill_slot(target_slot, selected_kind, paint_color)
		else:
			document.add_shape(selected_kind, point.snapped(Vector2(2, 2)), paint_color)
			hint_requested.emit("꾸미기 도형을 만들었어요. 끌어 옮기거나 회전해 보세요.")
	queue_redraw()

func _shape_at(point: Vector2) -> int:
	var ordered: Array[Dictionary] = document.ordered_shapes()
	for index: int in range(ordered.size() - 1, -1, -1):
		var shape: Dictionary = ordered[index]
		if Math.contains_point(shape.vertices, point - Vector2(shape.position)):
			return int(shape.id)
	return -1

func _slot_at(point: Vector2) -> String:
	var template: Dictionary = Templates.get_template(document.template_id)
	var parts: Array = template.parts
	for index: int in range(parts.size() - 1, -1, -1):
		var slot: Dictionary = parts[index]
		if Math.contains_point(slot.vertices, point - Vector2(slot.position)):
			return str(slot.id)
	return ""

func _snap_slot(point: Vector2, kind: String) -> String:
	var template: Dictionary = Templates.get_template(document.template_id)
	var closest: String = ""
	var best_distance: float = 29.0
	for slot: Dictionary in template.parts:
		if str(slot.kind) != kind:
			continue
		var occupied: Dictionary = document.shape_for_slot(str(slot.id))
		if not occupied.is_empty() and int(occupied.id) != document.selected_id:
			continue
		var distance: float = point.distance_to(slot.position)
		if distance < best_distance:
			best_distance = distance
			closest = str(slot.id)
	return closest

func _draw() -> void:
	draw_texture_rect(GameArt.drafting_paper(), Rect2(Vector2.ZERO, size), false)
	if document == null or _font == null:
		return
	var origin: Vector2 = canvas_origin()
	var scale: float = canvas_scale()
	var spacing: float = 20.0 * scale
	for x: int in range(int(size.x / spacing) + 2):
		for y: int in range(int(size.y / spacing) + 2):
			var dot: Vector2 = Vector2(fmod(origin.x, spacing) + x * spacing, fmod(origin.y, spacing) + y * spacing)
			draw_circle(dot, 1.0, Color("d5e1df"))
	var template: Dictionary = Templates.get_template(document.template_id)
	for slot: Dictionary in template.parts:
		_draw_slot(slot, scale)
	for shape: Dictionary in document.ordered_shapes():
		var position: Vector2 = shape.position
		if _dragging and int(shape.id) == _drag_id:
			position = _drag_position
		_draw_shape(shape, position, scale)
	# Unfilled details remain visible above larger, already-painted body pieces.
	for slot: Dictionary in template.parts:
		if document.shape_for_slot(str(slot.id)).is_empty():
			_draw_slot(slot, scale)
	if _creating:
		var draft: PackedVector2Array = Math.create_vertices(selected_kind, _default_dimensions(selected_kind))
		var points: PackedVector2Array = _screen_polygon(draft, _drag_position)
		draw_colored_polygon(points, Color(paint_color, 0.55))
		_draw_outline(points, Color("159b91"), 2.0, true)
	_draw_annotations()

func _draw_slot(slot: Dictionary, scale: float) -> void:
	var points: PackedVector2Array = _screen_polygon(slot.vertices, slot.position)
	var highlighted: bool = str(slot.id) == _hover_slot
	var matches: bool = str(slot.kind) == selected_kind
	var tint: Color = Color("dfe8e6")
	if matches:
		tint = Color("d0eae3")
	if highlighted:
		tint = Color("bfe4d9") if matches else Color("f8dfc3")
	draw_colored_polygon(points, tint)
	_draw_outline(points, Color("82a6a2") if matches else Color("afc1be"), 1.5, true)
	if document.shape_for_slot(str(slot.id)).is_empty():
		var center: Vector2 = character_to_screen(slot.position)
		var rect: Rect2 = Math.bounds(slot.vertices)
		if rect.size.x * scale >= 76 and rect.size.y * scale >= 39:
			var label: String = Math.kind_name(str(slot.kind))
			var font_size: int = 12 if scale < 1.25 else 14
			var width: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(_font, center + Vector2(-width * 0.5, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("668884"))

func _draw_shape(shape: Dictionary, position: Vector2, _scale: float) -> void:
	var points: PackedVector2Array = _screen_polygon(shape.vertices, position)
	draw_colored_polygon(points, shape.color)
	_draw_outline(points, Color(0.13, 0.22, 0.29, 0.28), 1.25, false)
	if int(shape.id) == document.selected_id:
		_draw_outline(points, Color("153b50"), 3.0, false)
		for index: int in range(points.size()):
			var point: Vector2 = points[index]
			draw_circle(point, 5, Color("fffdf6"))
			draw_arc(point, 5, 0, TAU, 16, Color("153b50"), 1.5, true)
			var label_at: Vector2 = point + (point - Math.bounds(points).get_center()).normalized() * 17 + Vector2(-6, 5)
			draw_string_outline(_font, label_at, ["ㄱ", "ㄴ", "ㄷ", "ㄹ"][index], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color("fffdf6"))
			draw_string(_font, label_at, ["ㄱ", "ㄴ", "ㄷ", "ㄹ"][index], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("153b50"))

func _draw_annotations() -> void:
	var status: Dictionary = document.completion()
	var title: String = "나만의 캐릭터 작업대"
	draw_string(_font, Vector2(25, 35), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("304755"))
	var progress: String = "%d / %d 조각" % [int(status.filled), int(status.total)]
	var progress_width: float = _font.get_string_size(progress, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(_font, Vector2(size.x - progress_width - 25, 35), progress, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("2c8f82"))
	var message: String = "도형 선택 → 점선 조각 클릭 · 빈 공간은 자유롭게 꾸미기"
	if not _hover_slot.is_empty():
		var slot: Dictionary = document.get_slot(_hover_slot)
		message = "%s  ·  %s" % [str(slot.label), Math.kind_name(str(slot.kind))]
	elif bool(status.ready):
		message = "캐릭터 완성! 사각형 월드로 떠날 준비가 됐어요."
	var text_size: int = 13
	var message_width: float = _font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	draw_style_box(_bubble_style(), Rect2(Vector2(maxf(14.0, (size.x - message_width) * 0.5 - 16.0), size.y - 51.0), Vector2(minf(message_width + 32.0, size.x - 28.0), 34.0)))
	draw_string(_font, Vector2(maxf(22.0, (size.x - message_width) * 0.5), size.y - 28), message, HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, text_size, StarfrontArt.INK)

func _screen_polygon(vertices: PackedVector2Array, position: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for vertex: Vector2 in vertices:
		points.append(character_to_screen(position + vertex))
	return points

func _draw_outline(points: PackedVector2Array, color: Color, width: float, dashed: bool) -> void:
	for index: int in range(points.size()):
		if dashed:
			draw_dashed_line(points[index], points[(index + 1) % points.size()], color, width, 6.0, true, true)
		else:
			draw_line(points[index], points[(index + 1) % points.size()], color, width, true)

static func _default_dimensions(kind: String) -> Vector2:
	if kind == "rhombus":
		return Vector2(72, 98)
	if kind == "rectangle":
		return Vector2(92, 58)
	if kind == "trapezoid" or kind == "parallelogram":
		return Vector2(88, 64)
	return Vector2(70, 70)

static func _bubble_style() -> StyleBoxTexture:
	var style: StyleBoxTexture = GameArt.panel(0, 0)
	style.modulate_color.a = 1.0
	return style
