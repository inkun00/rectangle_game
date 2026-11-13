class_name SpaceshipCanvas
extends Control

const Catalog: GDScript = preload("res://scripts/economy/spaceship_catalog.gd")
const Assembly: GDScript = preload("res://scripts/economy/spaceship_assembly.gd")
const Style: GDScript = preload("res://scripts/economy/spaceship_style.gd")
const PLANET_PATH: String = "res://assets/generated/opening-v1/planet.webp"
const LAUNCH_SECONDS: float = 16.0
const PNG_SIZE: Vector2i = Vector2i(960, 600)
const REQUIRED_SLOTS: Array[String] = ["hull", "nose", "window", "left_wing", "right_wing", "left_tank", "right_tank", "engine", "nozzle", "core", "navigation", "shield"]

signal part_selected(part_id: String)

var purchased_ids: Array[String] = []
var selected_part_id: String = "hull"
var launch_time: float = -1.0
var _preview_id: String = ""
var _assembly: Dictionary = {}
var _appearance: Dictionary = Style.defaults()
var _palette: Dictionary = Style.palette(_appearance)
var _inside: bool = false
var _design_preview: bool = false
var _export_mode: bool = false
var _planet: Texture2D

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	resized.connect(queue_redraw)
	if not _export_mode and ResourceLoader.exists(PLANET_PATH): _planet = load(PLANET_PATH) as Texture2D
	if _assembly.is_empty(): _rebuild_assembly()

func set_parts(ids: Array[String]) -> void:
	if purchased_ids == ids and not _assembly.is_empty(): return
	purchased_ids.assign(ids)
	_rebuild_assembly()

func show_preview(id: String) -> void:
	if _preview_id == id: return
	_preview_id = id
	_rebuild_assembly()

func set_appearance(appearance: Dictionary) -> void:
	if _appearance == appearance or not Style.is_valid(appearance): return
	_appearance = appearance.duplicate(true)
	_palette = Style.palette(_appearance)
	_rebuild_assembly()

func show_structure(enabled: bool) -> void:
	if _inside == enabled: return
	_inside = enabled
	queue_redraw()

func show_design_preview(enabled: bool) -> void:
	if _design_preview == enabled: return
	_design_preview = enabled
	queue_redraw()

static func export_png(tree: SceneTree, ids: Array[String], appearance: Dictionary = {}) -> PackedByteArray:
	if DisplayServer.get_name() == "headless" or ids.size() != Catalog.PART_COUNT:
		return PackedByteArray()
	var slots: Dictionary = {}
	for id: String in ids:
		var part: Dictionary = Catalog.part(id)
		if part.is_empty() or slots.has(part.slot_id): return PackedByteArray()
		slots[part.slot_id] = true
	var viewport: SubViewport = SubViewport.new()
	viewport.size = PNG_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var plate: SpaceshipCanvas = SpaceshipCanvas.new()
	plate._export_mode = true
	plate.size = Vector2(PNG_SIZE)
	if not appearance.is_empty(): plate.set_appearance(appearance)
	plate.set_parts(ids)
	viewport.add_child(plate)
	tree.root.add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return image.save_png_to_buffer() if image != null and not image.is_empty() else PackedByteArray()

static func exhaust_layout(ids: Array[String], appearance: Dictionary) -> Array[Dictionary]:
	var build: Dictionary = Assembly.build(ids, appearance)
	var bounds: Rect2 = build.bounds
	var ports: Array[Dictionary] = []
	if not bounds.has_area(): return ports
	var exhausts: Array[Vector2] = build.exhausts
	var widths: Array[float] = build.port_widths
	for index: int in range(exhausts.size()):
		var point: Vector2 = (exhausts[index] - bounds.position) / bounds.size
		ports.append({"x": clampf(point.x, 0.0, 1.0), "y": clampf(point.y, 0.0, 1.0), "width": clampf(widths[index] / bounds.size.x, 0.01, 1.0)})
	return ports

static func draw_product(target: CanvasItem, room: Rect2, item: Dictionary, appearance: Dictionary = {}) -> void:
	if item.is_empty() or not room.has_area(): return
	var panel: Dictionary = Assembly.product_panel(str(item.id))
	if panel.is_empty(): return
	var bounds: Rect2 = QuadrilateralMath.bounds(panel.vertices)
	if not bounds.has_area(): return
	var factor: float = minf(room.size.x / bounds.size.x, room.size.y / bounds.size.y)
	var points: PackedVector2Array = _screen_points(panel.vertices, room.get_center() - bounds.get_center() * factor, factor, 0.0)
	var actual: Dictionary = appearance if Style.is_valid(appearance) else Style.defaults()
	_paint_panel(target, points, panel, Style.palette(actual), str(actual.finish), false)

func _rebuild_assembly() -> void:
	var by_slot: Dictionary = {}
	for item: Dictionary in Catalog.installed_parts(purchased_ids): by_slot[item.slot_id] = item
	var preview: Dictionary = Catalog.part(_preview_id)
	var ids: Array[String] = []
	for base: Dictionary in Catalog.all_parts():
		var item: Dictionary = by_slot.get(base.slot_id, base)
		if not preview.is_empty() and preview.slot_id == base.slot_id: item = preview
		ids.append(str(item.id))
	_assembly = Assembly.build(ids, _appearance)
	queue_redraw()

func _ship_bounds() -> Rect2:
	return _assembly.get("bounds", Rect2())

func _scale_factor() -> float:
	var bounds: Rect2 = _ship_bounds()
	if not bounds.has_area(): return 1.0
	var usable: Vector2 = (size - Vector2(36.0, 52.0)).max(Vector2.ONE)
	return minf(usable.x / bounds.size.x, usable.y / bounds.size.y)

func _ship_center() -> Vector2:
	return Vector2(size.x * 0.5, (size.y - 28.0) * 0.5) - _ship_bounds().get_center() * _scale_factor()

func _draw() -> void:
	if _export_mode:
		_draw_export()
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1727"))
	if launch_time >= 0.0:
		_draw_launch()
		return
	for x: int in range(0, int(size.x), 32): draw_line(Vector2(x, 0), Vector2(x, size.y), Color("183449"), 1.0)
	for y: int in range(0, int(size.y), 32): draw_line(Vector2(0, y), Vector2(size.x, y), Color("183449"), 1.0)
	_draw_ship(_ship_center(), _scale_factor(), 0.0, false)
	var note: String = "조립 설계도 · 어두운 칸은 아직 비어 있어요."
	if _inside: note = "내부 보기 · 항법 장치, 에너지 핵, 보호 장치를 확인해요."
	elif _design_preview: note = "완성 모습 미리 보기"
	elif not _preview_id.is_empty(): note = "금빛 테두리 · 선택한 부품 미리 보기"
	elif purchased_ids.size() == Catalog.PART_COUNT: note = "12종의 필수 부품을 모두 조립했어요."
	draw_string(QuadTheme.FONT, Vector2(12, size.y - 15), note, HORIZONTAL_ALIGNMENT_CENTER, maxf(0.0, size.x - 24), 14, Color("bacbd9"))

func _draw_export() -> void:
	var bounds: Rect2 = _ship_bounds()
	if not bounds.has_area(): return
	var safe_size: Vector2 = size - Vector2(96.0, 80.0)
	var factor: float = minf(safe_size.x / bounds.size.x, safe_size.y / bounds.size.y)
	_draw_ship(size * 0.5 - bounds.get_center() * factor, factor, 0.0, true)

func _draw_ship(center: Vector2, factor: float, angle: float, complete: bool) -> void:
	var panels: Array[Dictionary] = _assembly.get("panels", [])
	var shown: Dictionary = {}
	for id: String in purchased_ids:
		var product: Dictionary = Catalog.part(id)
		shown[product.get("slot_id", "")] = true
	var preview: Dictionary = Catalog.part(_preview_id)
	if not preview.is_empty(): shown[preview.slot_id] = true
	var selection: Array[PackedVector2Array] = []
	for panel: Dictionary in panels:
		if not _panel_visible(panel, complete): continue
		var slot: String = str(panel.slot)
		var points: PackedVector2Array = _screen_points(panel.vertices, center, factor, angle)
		var real: bool = complete or _design_preview or shown.has(slot) or slot not in REQUIRED_SLOTS
		if not real and bool(panel.get("detail", false)): continue
		_paint_panel(self, points, panel, _palette, str(_appearance.finish), not real)
		if not complete and not _design_preview and slot == selected_part_id and not bool(panel.get("detail", false)):
			selection.append(_outline(points))
	for edge: PackedVector2Array in selection:
		draw_polyline(edge, Color("ffde97"), 1.6, true)

func _panel_visible(panel: Dictionary, complete: bool = false) -> bool:
	var cutaway: bool = _inside and not complete
	return not ((bool(panel.get("internal", false)) and not cutaway) or (bool(panel.get("cover", false)) and cutaway))

static func _screen_points(vertices: PackedVector2Array, center: Vector2, factor: float, angle: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for vertex: Vector2 in vertices: points.append(vertex.rotated(angle) * factor + center)
	return points

static func _outline(points: PackedVector2Array) -> PackedVector2Array:
	var line: PackedVector2Array = points.duplicate()
	line.append(points[0])
	return line

static func _paint_panel(target: CanvasItem, points: PackedVector2Array, panel: Dictionary, palette: Dictionary, finish: String, ghost: bool) -> void:
	var tone: String = str(panel.tone)
	var detail: bool = bool(panel.get("detail", false))
	if ghost:
		target.draw_colored_polygon(points, Color("1b3043"))
		if bool(panel.get("seam", false)): target.draw_polyline(_outline(points), Color("456174"), 0.8, true)
		return
	var color: Color = palette.get(tone, Color("7a8b9b"))
	var box: Rect2 = QuadrilateralMath.bounds(points)
	var colors: PackedColorArray = PackedColorArray()
	for p: Vector2 in points:
		var local: Vector2 = (p - box.position) / box.size.max(Vector2.ONE)
		var light: float = (0.75 - local.y - local.x * 0.25) * (0.20 if finish == "titanium" else 0.13)
		if tone == "glass": light *= 2.5
		colors.append(color.lightened(light) if light >= 0.0 else color.darkened(-light))
	target.draw_polygon(points, colors)
	if not detail and tone in ["shell", "metal", "shade"]:
		_draw_finish(target, points, color, finish)
	if bool(panel.get("seam", false)):
		target.draw_polyline(_outline(points), Color(palette.get("edge", Color("182f42")), 0.65), 0.8, true)

static func _draw_finish(target: CanvasItem, points: PackedVector2Array, color: Color, finish: String) -> void:
	var span: float = minf(points[0].distance_to(points[3]), points[1].distance_to(points[2]))
	if span < 10.0: return
	if finish == "titanium":
		# A narrow specular streak across the panel distinguishes brushed metal.
		var highlight: Color = Color(color.lightened(0.44), 0.35)
		target.draw_colored_polygon(PackedVector2Array([
			points[0].lerp(points[3], 0.19), points[1].lerp(points[2], 0.19),
			points[1].lerp(points[2], 0.29), points[0].lerp(points[3], 0.29),
		]), highlight)
	elif finish == "carbon":
		# Interpolate entirely inside the quad, including slanted wing surfaces.
		for row: int in range(1, clampi(roundi(span / 4.0), 2, 36)):
			var t: float = float(row) / float(clampi(roundi(span / 4.0), 2, 36))
			var left: Vector2 = points[0].lerp(points[3], t)
			var right: Vector2 = points[1].lerp(points[2], t)
			for col: int in range(8):
				if (row + col) % 2 == 0:
					target.draw_line(left.lerp(right, float(col) / 8.0), left.lerp(right, float(col + 1) / 8.0), Color(color.darkened(0.24), 0.44), 1.25)

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
	var rotation_angle: float = lerpf(0.0, 0.48, arrival)
	var center: Vector2 = Vector2(lerpf(size.x * 0.5, size.x * 0.30, arrival), size.y * 0.45 - sin(lift * PI) * size.y * 0.10)
	center -= _ship_bounds().get_center().rotated(rotation_angle) * ship_factor
	if t >= 2.9 and t < 14.5:
		var exhausts: Array[Vector2] = _assembly.exhausts
		var widths: Array[float] = _assembly.port_widths
		for index: int in range(exhausts.size()):
			var exhaust: Vector2 = exhausts[index]
			var flame_length: float = 80.0 + 14.0 * sin(t * 30.0)
			var width: float = widths[index] * 0.36
			var points: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in [Vector2(-width, 0), Vector2(width, 0), Vector2(3, flame_length), Vector2(-3, flame_length)]:
				points.append(center + (exhaust + point).rotated(rotation_angle) * ship_factor)
			draw_colored_polygon(points, Color(_palette.glow, 0.75))
	_draw_ship(center, ship_factor, rotation_angle, true)
	var message: String = "출발 준비 %d" % maxi(1, 3 - int(t)) if t < 3.0 else ("우주로 출발!" if t < 10.0 else "사각성이 보여요!")
	if t >= 15.0: message = "드디어 사각성에 도착했어요!"
	var caption_width: float = minf(size.x - 24.0, QuadTheme.FONT.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 32.0)
	draw_rect(Rect2(Vector2((size.x - caption_width) * 0.5, 7.0), Vector2(caption_width, 38.0)), Color(0.035, 0.086, 0.133, 0.94))
	draw_string(QuadTheme.FONT, Vector2(12, 35), message, HORIZONTAL_ALIGNMENT_CENTER, maxf(0.0, size.x - 24), 22, Color("fff3d6"))

func _gui_input(event: InputEvent) -> void:
	if launch_time >= 0.0: return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed: return
	var point: Vector2 = (event.position - _ship_center()) / _scale_factor()
	var panels: Array[Dictionary] = _assembly.get("panels", [])
	for index: int in range(panels.size() - 1, -1, -1):
		var panel: Dictionary = panels[index]
		if not _panel_visible(panel) or str(panel.slot) not in REQUIRED_SLOTS: continue
		if Geometry2D.is_point_in_polygon(point, panel.vertices):
			selected_part_id = str(panel.slot)
			part_selected.emit(selected_part_id)
			queue_redraw()
			accept_event()
			return
