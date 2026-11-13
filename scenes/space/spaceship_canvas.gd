class_name SpaceshipCanvas
extends Control

const Catalog: GDScript = preload("res://scripts/economy/spaceship_catalog.gd")
const TextureUvs: GDScript = preload("res://scenes/space/spaceship_texture_uvs.gd")
const PLANET_PATH: String = "res://assets/generated/opening-v1/planet.webp"
const ATLAS_FILES: Array[String] = ["standard.webp", "advanced.webp", "elite.webp"]
const ATLAS_DIRECTORY: String = "res://assets/generated/ship-parts-v2/"
const ATLAS_GRID: Vector2i = Vector2i(4, 3)
const LAUNCH_SECONDS: float = 16.0
const PNG_SIZE: Vector2i = Vector2i(960, 600)

signal part_selected(part_id: String)

var purchased_ids: Array[String] = []
var selected_part_id: String = "hull"
var launch_time: float = -1.0
var _preview_id: String = ""
var _assembly: Array[Dictionary] = []
var _export_mode: bool = false
var _planet: Texture2D
static var _part_textures: Dictionary = {}
static var _part_uvs: Dictionary = {}

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

static func export_png(tree: SceneTree, ids: Array[String]) -> PackedByteArray:
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
	plate.set_parts(ids)
	viewport.add_child(plate)
	tree.root.add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return image.save_png_to_buffer() if image != null and not image.is_empty() else PackedByteArray()

static func part_texture(item: Dictionary) -> AtlasTexture:
	var id: String = str(item.id)
	if _part_textures.has(id): return _part_textures[id] as AtlasTexture
	var tier: int = int(item.tier)
	var path: String = ATLAS_DIRECTORY + ATLAS_FILES[tier]
	if not ResourceLoader.exists(path): return null
	var atlas: Texture2D = load(path) as Texture2D
	if atlas == null: return null
	var index: int = int(item.slot_index)
	var cell: Vector2 = atlas.get_size() / Vector2(ATLAS_GRID)
	var col: int = index % ATLAS_GRID.x
	var row: int = floori(float(index) / ATLAS_GRID.x)
	var tile: AtlasTexture = AtlasTexture.new()
	tile.atlas = atlas
	tile.region = Rect2(Vector2(col, row) * cell, cell)
	tile.filter_clip = true
	_part_textures[id] = tile
	return tile

func _rebuild_assembly() -> void:
	var by_slot: Dictionary = {}
	for item: Dictionary in Catalog.installed_parts(purchased_ids): by_slot[item.slot_id] = item
	var preview: Dictionary = Catalog.part(_preview_id)
	_assembly.clear()
	for base: Dictionary in Catalog.all_parts():
		var item: Dictionary = by_slot.get(base.slot_id, base)
		if not preview.is_empty() and preview.slot_id == base.slot_id: item = preview
		_assembly.append(item)
	_assembly.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.layer) < int(b.layer))
	queue_redraw()

func _ship_bounds() -> Rect2:
	var bounds: Rect2 = Rect2()
	for item: Dictionary in _assembly:
		var part_bounds: Rect2 = QuadrilateralMath.bounds(item.vertices)
		part_bounds.position += Vector2(item.position)
		bounds = bounds.merge(part_bounds) if bounds.has_area() else part_bounds
	return bounds

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
	var note: String = "조립된 부품과 아직 비어 있는 자리"
	if not _preview_id.is_empty(): note = "금빛 테두리 · 선택한 부품 미리 보기"
	elif purchased_ids.size() == Catalog.PART_COUNT: note = "12종의 필수 부품을 모두 조립했어요."
	draw_string(QuadTheme.FONT, Vector2(12, size.y - 15), note, HORIZONTAL_ALIGNMENT_CENTER, maxf(0.0, size.x - 24), 14, Color("bacbd9"))

func _draw_export() -> void:
	var bounds: Rect2 = _ship_bounds()
	if not bounds.has_area(): return
	var safe_size: Vector2 = size - Vector2(96.0, 80.0)
	var factor: float = minf(safe_size.x / bounds.size.x, safe_size.y / bounds.size.y)
	_draw_ship(size * 0.5 - bounds.get_center() * factor, factor, 0.0, true)

func _draw_ship(center: Vector2, factor: float, angle: float, complete: bool) -> void:
	var selection: PackedVector2Array = PackedVector2Array()
	for item: Dictionary in _assembly:
		var points: PackedVector2Array = PackedVector2Array()
		for vertex: Vector2 in item.vertices:
			points.append((vertex + Vector2(item.position)).rotated(angle) * factor + center)
		var owned: bool = complete or purchased_ids.has(str(item.id))
		var previewing: bool = not complete and _preview_id == str(item.id)
		if owned or previewing: draw_installed_part(self, points, item)
		else: draw_colored_polygon(points, Color(0.10, 0.18, 0.24, 0.38))
		var outline: PackedVector2Array = points.duplicate()
		outline.append(points[0])
		var selected: bool = not complete and launch_time < 0.0 and str(item.slot_id) == selected_part_id
		if selected: selection = outline
		draw_polyline(outline, Color("314b61") if owned or previewing else Color("607c91"), 1.25, true)
	if not selection.is_empty(): draw_polyline(selection, Color("ffe1a0"), 2.7, true)

static func draw_installed_part(target: CanvasItem, points: PackedVector2Array, item: Dictionary) -> void:
	var metal: Color = Color(item.color).lerp(Color("46596f"), 0.35)
	var shades: PackedColorArray = PackedColorArray([metal.lightened(0.12), metal, metal.darkened(0.25), metal.darkened(0.14)])
	target.draw_polygon(points, shades)
	var sprite: AtlasTexture = part_texture(item)
	if sprite == null: return
	var id: String = str(item.id)
	if not _part_uvs.has(id):
		var corners: Array = TextureUvs.PART_UVS[int(item.tier)][int(item.slot_index)]
		var uvs: PackedVector2Array = PackedVector2Array()
		for index: int in range(0, corners.size(), 2):
			var relative: Vector2 = Vector2(float(corners[index]), float(corners[index + 1]))
			uvs.append((sprite.region.position + sprite.region.size * relative) / sprite.atlas.get_size())
		_part_uvs[id] = uvs
	target.draw_polygon(points, PackedColorArray([Color.WHITE]), _part_uvs[id], sprite.atlas)

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
		for item: Dictionary in _assembly:
			if item.slot_id != "nozzle": continue
			var port: Rect2 = QuadrilateralMath.bounds(item.vertices)
			var exhaust: Vector2 = Vector2(item.position) + Vector2(port.get_center().x, port.end.y - 2.0)
			var flame_length: float = 80.0 + 14.0 * sin(t * 30.0)
			var width: float = port.size.x * 0.30
			var points: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in [Vector2(-width, 0), Vector2(width, 0), Vector2(14, flame_length), Vector2(-14, flame_length)]:
				points.append(center + (exhaust + point).rotated(rotation_angle) * ship_factor)
			draw_colored_polygon(points, Color("f3b85a"))
			break
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
	for index: int in range(_assembly.size() - 1, -1, -1):
		var item: Dictionary = _assembly[index]
		if Geometry2D.is_point_in_polygon(point - Vector2(item.position), item.vertices):
			selected_part_id = str(item.slot_id)
			part_selected.emit(selected_part_id)
			queue_redraw()
			accept_event()
			return
