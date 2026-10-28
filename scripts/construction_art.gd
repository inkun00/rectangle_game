class_name ConstructionArt
extends RefCounted

## All decorative pixels come from the imagegen sheets recorded in GENERATION.md.
## Geometry, text, focus rings and live construction measurements stay independent.
const GENERATED_ROOT: String = "res://assets/generated/revision/"
const GAME_ROOT: String = "res://assets/generated/construction-game/"
const GAME_FILES: Dictionary = {"construction-cover.png": "worksite.png", "client-portraits.png": "client-portraits.png", "construction-materials.png": "material-base.png", "construction-materials-expanded.png": "material-expanded.png", "ui-icons.png": "tool-icons.png"}
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const INK: Color = Color("183957")
const MUTED: Color = Color("4e6478")
const PAPER: Color = Color("f8f9f5")
const BOARD: Color = Color("e9ece6")
const ACCENT: Color = Color("2467c4")
const COPPER: Color = Color("e99b26")
const LINE: Color = Color("cfd6d0")
const TOOL_CELLS: Dictionary = {"select": 0, "undo": 1, "redo": 2, "delete": 3, "rotate": 4, "zoom": 5, "fit": 6, "inspect": 7, "receipt": 8, "home": 9, "save": 10, "help": 11, "duplicate": 12, "draw": 13, "adventure": 14, "book": 15}
const EXPANDED_MATERIAL_CELLS: Dictionary = {"stone": 0, "concrete": 1, "plaster": 2, "green_brick": 3, "frosted_glass": 4, "amber_glass": 5, "teal_glass": 6, "grille": 7, "zinc_roof": 8, "clay_roof": 9, "slate_roof": 10, "metal_roof": 11, "cedar": 12, "louver": 13, "mosaic": 14, "copper": 15}
static var _textures: Dictionary = {}
static var _regions: Dictionary = {}

static func generated_texture(filename: String) -> Texture2D:
	if _textures.has(filename): return _textures[filename] as Texture2D
	var path: String = GENERATED_ROOT + filename
	if GAME_FILES.has(filename) and ResourceLoader.exists(GAME_ROOT + str(GAME_FILES[filename])):
		path = GAME_ROOT + str(GAME_FILES[filename])
	if not ResourceLoader.exists(path): return null
	var result: Texture2D = load(path) as Texture2D
	if result != null: _textures[filename] = result
	return result

static func _atlas(filename: String, cell: int, columns: int, rows: int) -> Texture2D:
	var key: String = "%s:%d:%d:%d" % [filename, cell, columns, rows]
	if _regions.has(key): return _regions[key] as Texture2D
	var sheet: Texture2D = generated_texture(filename)
	if sheet == null: return null
	var cell_size: Vector2 = sheet.get_size() / Vector2(columns, rows)
	var result: AtlasTexture = AtlasTexture.new()
	result.atlas = sheet
	result.region = Rect2(Vector2(cell % columns, int(cell / columns)) * cell_size, cell_size)
	if filename == "ui-surfaces.png": result.region = result.region.grow(-minf(cell_size.x, cell_size.y) * 0.02)
	if filename == "client-portraits.png":
		# Keep adjacent sleeves out of a portrait without clipping the head or
		# changing the generated pixels. The bust may extend to the cell edge.
		var inset: float = cell_size.x * 0.04
		result.region.position.x += inset
		result.region.size.x -= inset * 2.0
	result.filter_clip = true
	_regions[key] = result
	return result

static func game_texture(filename: String) -> Texture2D:
	var key: String = "game:" + filename
	if _textures.has(key): return _textures[key] as Texture2D
	var result: Texture2D = load(GAME_ROOT + filename) as Texture2D if ResourceLoader.exists(GAME_ROOT + filename) else null
	if result != null: _textures[key] = result
	return result

static func surface_texture(primary: bool = false, button: bool = false) -> Texture2D:
	var filename: String = ("button-blue.png" if primary else "button-light.png") if button else ("panel-dark.png" if primary else "panel-light.png")
	var key: String = "skin:" + filename
	if _textures.has(key): return _textures[key] as Texture2D
	var source: Texture2D = game_texture(filename)
	if source == null: return _atlas("ui-surfaces.png", (2 if button else 0) + (1 if primary else 0), 2, 2)
	# Standard runtime slicing/scaling retains the generated painted surface.
	var pixels: Image = source.get_image()
	if pixels.is_compressed(): pixels.decompress()
	var used: Rect2i = pixels.get_used_rect()
	if used.has_area(): pixels = pixels.get_region(used)
	# Nine-slice borders are measured in these runtime pixels. A small source
	# keeps the painted rim narrow instead of expanding it over the label.
	pixels.resize(96 if button else 160, 32 if button else 64, Image.INTERPOLATE_LANCZOS)
	var result: ImageTexture = ImageTexture.create_from_image(pixels)
	_textures[key] = result
	return result

static func panel(primary: bool = false, padding: int = 14) -> StyleBoxTexture:
	var result: StyleBoxTexture = StyleBoxTexture.new()
	result.texture = surface_texture(primary)
	for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(edge, 14.0 if edge in [SIDE_LEFT, SIDE_RIGHT] else 12.0)
		result.set_content_margin(edge, float(maxi(padding, 8)))
	return result

static func button_style(primary: bool = false, state: String = "normal", padding: int = 12) -> StyleBoxTexture:
	var result: StyleBoxTexture = StyleBoxTexture.new()
	result.texture = surface_texture(primary, true)
	for edge: Side in [SIDE_LEFT, SIDE_RIGHT]:
		result.set_texture_margin(edge, 16.0)
		result.set_content_margin(edge, float(maxi(padding, 18)))
	for edge: Side in [SIDE_TOP, SIDE_BOTTOM]:
		result.set_texture_margin(edge, 10.0)
		result.set_content_margin(edge, 10.0)
	if state == "hover": result.modulate_color = Color(1.08, 1.08, 1.08)
	elif state == "pressed": result.modulate_color = Color(0.88, 0.92, 0.91)
	elif state == "disabled":
		result.texture = surface_texture(false, true)
		result.modulate_color = Color(0.94, 0.96, 0.98, 0.78)
	return result

static func quiet_surface_texture(primary: bool = false) -> Texture2D:
	var key: String = "quiet-skin:" + str(primary)
	if _textures.has(key): return _textures[key] as Texture2D
	var source: Texture2D = surface_texture(primary)
	if source == null: return null
	var center: AtlasTexture = AtlasTexture.new()
	center.atlas = source
	center.region = Rect2(Vector2(20, 18), source.get_size() - Vector2(40, 36))
	center.filter_clip = true
	_textures[key] = center
	return center

static func material_icon(material_id: String) -> Texture2D:
	var material: Dictionary = Catalog.material(material_id)
	if material.is_empty(): return null
	# Counted masonry always uses one generated brick per repeated tile.
	if int(material.get("brick_count", 0)) > 0: return _atlas("construction-materials.png", 0, 4, 2)
	var texture_key: String = str(material.get("texture_key", ""))
	if EXPANDED_MATERIAL_CELLS.has(texture_key):
		return _atlas("construction-materials-expanded.png", int(EXPANDED_MATERIAL_CELLS[texture_key]), 4, 4)
	var cell: int = 0
	match str(material.role):
		"wall": cell = 0
		"window": cell = 2
		"door": cell = 3
		"beam": cell = 4
		"roof": cell = 5
		"decor": cell = 7 if str(material.kind) == "rhombus" else 6
	return _atlas("construction-materials.png", cell, 4, 2)

static func tool_icon(tool: String) -> Texture2D:
	return _atlas("ui-icons.png", int(TOOL_CELLS.get(tool, 0)), 4, 4)

static func texture_source(texture: Texture2D) -> Texture2D:
	return (texture as AtlasTexture).atlas if texture is AtlasTexture else texture

static func texture_uvs(texture: Texture2D) -> PackedVector2Array:
	var area: Rect2 = Rect2(0, 0, 1, 1)
	if texture is AtlasTexture:
		var atlas: AtlasTexture = texture as AtlasTexture
		var pixels: Rect2 = atlas.region.grow(-0.5)
		area = Rect2(pixels.position / atlas.atlas.get_size(), pixels.size / atlas.atlas.get_size())
	return PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])

static func quad_point(vertices: PackedVector2Array, uv: Vector2) -> Vector2:
	return vertices[0].lerp(vertices[1], uv.x).lerp(vertices[3].lerp(vertices[2], uv.x), uv.y)

static func portrait(index: int) -> Control:
	var result: ClientPortrait = ClientPortrait.new()
	result.client_index = posmod(index, 6)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.clip_contents = true
	return result

class MaterialSample extends Control:
	var material_id: String = "":
		set(value):
			material_id = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		resized.connect(queue_redraw)

	func _draw() -> void:
		var material: Dictionary = Catalog.material(material_id)
		var sample: Texture2D = ConstructionArt.material_icon(material_id)
		if material.is_empty() or sample == null: return
		var vertices: PackedVector2Array = Math.create_vertices(str(material.kind), Vector2(material.dimensions))
		var bounds: Rect2 = Math.bounds(vertices)
		var scale: float = minf(maxf(size.x - 6.0, 1.0) / bounds.size.x, maxf(size.y - 6.0, 1.0) / bounds.size.y)
		var counted_bricks: bool = int(material.get("brick_count", 0)) > 1
		var columns: int = maxi(1, roundi((vertices[1] - vertices[0]).length() / 40.0)) if counted_bricks else 1
		var rows: int = maxi(1, roundi((vertices[2] - vertices[1]).length() / 20.0)) if counted_bricks else 1
		for row: int in range(rows):
			for column: int in range(columns):
				var area: Rect2 = Rect2(float(column) / columns, float(row) / rows, 1.0 / columns, 1.0 / rows)
				var corners: PackedVector2Array = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
				var points: PackedVector2Array = PackedVector2Array()
				for corner: Vector2 in corners: points.append((ConstructionArt.quad_point(vertices, corner) - bounds.get_center()) * scale + size * 0.5)
				draw_polygon(points, PackedColorArray([Color.WHITE]), ConstructionArt.texture_uvs(sample), ConstructionArt.texture_source(sample))

class ClientPortrait extends Control:
	var client_index: int = 0:
		set(value):
			client_index = posmod(value, 6)
			queue_redraw()
	# Satisfaction is always communicated in text. The generated portrait is
	# preserved rather than drawing a replacement facial expression in code.
	var mood: String = "happy":
		set(value):
			mood = value if value in ["happy", "straight", "sad"] else "happy"
			queue_redraw()

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		resized.connect(queue_redraw)

	func _draw() -> void:
		var image: Texture2D = ConstructionArt._atlas("client-portraits.png", client_index, 3, 2)
		if image == null: return
		var scale: float = minf(size.x / image.get_width(), size.y / image.get_height())
		var dimensions: Vector2 = image.get_size() * scale
		draw_texture_rect(image, Rect2((size - dimensions) * 0.5, dimensions), false)
