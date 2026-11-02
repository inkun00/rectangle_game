class_name SpaceshipCanvas
extends Control

const Catalog: GDScript = preload("res://scripts/economy/spaceship_catalog.gd")
const PLANET_PATH: String = "res://assets/generated/opening-v1/planet.png"
const LAUNCH_SECONDS: float = 16.0

signal part_selected(part_id: String)

var purchased_ids: Array[String] = []
var selected_part_id: String = "hull"
var launch_time: float = -1.0
var _planet: Texture2D

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	resized.connect(queue_redraw)
	if ResourceLoader.exists(PLANET_PATH): _planet = load(PLANET_PATH) as Texture2D

func set_parts(ids: Array[String]) -> void:
	purchased_ids.assign(ids)
	queue_redraw()

func _scale_factor() -> float:
	var available_height: float = size.y if launch_time >= 0.0 else size.y - 38.0
	return maxf(0.1, minf(size.x / 560.0, available_height / 520.0))

func _ship_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.46)

func _ordered_parts() -> Array[Dictionary]:
	var parts: Array[Dictionary] = Catalog.all_parts()
	parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.layer) < int(b.layer))
	return parts

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1727"))
	if launch_time >= 0.0:
		_draw_launch()
		return
	for x: int in range(0, int(size.x), 32): draw_line(Vector2(x, 0), Vector2(x, size.y), Color("183449"), 1.0)
	for y: int in range(0, int(size.y), 32): draw_line(Vector2(0, y), Vector2(size.x, y), Color("183449"), 1.0)
	_draw_ship(_ship_center(), _scale_factor(), 0.0, false)
	var note: String = "밝은 부품: 구매 완료 · 빈 부품: 미구매"
	draw_string(QuadTheme.FONT, Vector2(12, size.y - 15), note, HORIZONTAL_ALIGNMENT_CENTER, maxf(0.0, size.x - 24), 14, Color("bacbd9"))

func _draw_ship(center: Vector2, factor: float, angle: float, complete: bool) -> void:
	for item: Dictionary in _ordered_parts():
		var points: PackedVector2Array = PackedVector2Array()
		for vertex: Vector2 in item.vertices:
			points.append((vertex + Vector2(item.position)).rotated(angle) * factor + center)
		var owned: bool = complete or purchased_ids.has(str(item.id))
		var fill: Color = Color(item.color) if owned else Color("21374a")
		draw_colored_polygon(points, fill)
		var outline: PackedVector2Array = points.duplicate()
		outline.append(points[0])
		var selected: bool = launch_time < 0.0 and str(item.id) == selected_part_id
		draw_polyline(outline, Color("fff1b7") if selected else (Color("deefed") if owned else Color("607c91")), 3.0 if selected else 1.7, true)
		if owned:
			var inset: PackedVector2Array = PackedVector2Array()
			for vertex: Vector2 in item.vertices:
				inset.append((vertex * 0.82 + Vector2(item.position)).rotated(angle) * factor + center)
			inset.append(inset[0])
			draw_polyline(inset, Color(1.0, 1.0, 1.0, 0.2), 1.0, true)

func _draw_launch() -> void:
	var t: float = clampf(launch_time, 0.0, LAUNCH_SECONDS)
	var lift: float = smoothstep(3.0, 7.5, t)
	var arrival: float = smoothstep(11.0, 15.0, t)
	for index: int in range(70):
		var seed_value: float = float(index)
		var x: float = fposmod(seed_value * 127.37, maxf(1.0, size.x))
		var y: float = fposmod(seed_value * 73.91 + t * (18.0 + float(index % 5) * 15.0), maxf(1.0, size.y))
		var star_size: float = 1.0 + float(index % 3)
		draw_rect(Rect2(Vector2(x, y), Vector2(star_size, star_size + lift * 10.0 * (1.0 - arrival))), Color(0.7, 0.9, 0.9, 0.5))
	if t < 8.0:
		var ground_y: float = size.y * 0.86 + lift * size.y
		draw_rect(Rect2(Vector2(0, ground_y), Vector2(size.x, size.y)), Color("467e72"))
		draw_rect(Rect2(Vector2(size.x * 0.2, ground_y - 12), Vector2(size.x * 0.6, 12)), Color("688a9a"))
	if _planet != null and t > 9.0:
		var planet_size: float = minf(size.x * 0.50, size.y * 0.75) * lerpf(0.1, 1.0, arrival)
		draw_texture_rect(_planet, Rect2(Vector2(size.x * 0.74 - planet_size * 0.5, size.y * 0.46 - planet_size * 0.5), Vector2.ONE * planet_size), false)
	var ship_factor: float = _scale_factor() * lerpf(0.9, 0.48, arrival)
	var center: Vector2 = Vector2(lerpf(size.x * 0.5, size.x * 0.30, arrival), size.y * 0.45 - sin(lift * PI) * size.y * 0.10)
	var rotation_angle: float = lerpf(0.0, 0.48, arrival)
	if t >= 2.9 and t < 14.5:
		var exhaust: Vector2 = center + Vector2(0, 225).rotated(rotation_angle) * ship_factor
		var flame_length: float = (80.0 + 14.0 * sin(t * 30.0)) * ship_factor
		var points: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in [Vector2(-30, 0), Vector2(30, 0), Vector2(14, flame_length / ship_factor), Vector2(-14, flame_length / ship_factor)]:
			points.append(exhaust + p.rotated(rotation_angle) * ship_factor)
		draw_colored_polygon(points, Color("f3b85a"))
	_draw_ship(center, ship_factor, rotation_angle, true)
	var message: String = "출발 준비 %d" % maxi(1, 3 - int(t)) if t < 3.0 else ("우주로 출발!" if t < 10.0 else "사각형 행성이 보여요!")
	if t >= 15.0: message = "드디어, 별빛 고향에 도착했어요!"
	var caption_width: float = minf(size.x - 24.0, QuadTheme.FONT.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 32.0)
	draw_rect(Rect2(Vector2((size.x - caption_width) * 0.5, 7.0), Vector2(caption_width, 38.0)), Color(0.035, 0.086, 0.133, 0.94))
	draw_string(QuadTheme.FONT, Vector2(12, 35), message, HORIZONTAL_ALIGNMENT_CENTER, maxf(0.0, size.x - 24), 22, Color("fff3d6"))

func _gui_input(event: InputEvent) -> void:
	if launch_time >= 0.0: return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed: return
	var point: Vector2 = (event.position - _ship_center()) / _scale_factor()
	var parts: Array[Dictionary] = _ordered_parts()
	parts.reverse()
	for item: Dictionary in parts:
		if Geometry2D.is_point_in_polygon(point - Vector2(item.position), item.vertices):
			selected_part_id = str(item.id)
			part_selected.emit(selected_part_id)
			queue_redraw()
			accept_event()
			return
