class_name ConstructionArt
extends RefCounted

## All decorative pixels come from the imagegen sheets recorded in GENERATION.md.
## Geometry, text, focus rings and live construction measurements stay independent.
const GENERATED_ROOT: String = "res://assets/generated/revision/"
const GAME_ROOT: String = "res://assets/generated/construction-game/"
const GAME_FILES: Dictionary = {"construction-cover.png": "worksite.png", "client-portraits.png": "client-portraits.png", "construction-materials.png": "material-base.png", "construction-materials-expanded.png": "material-expanded.png", "ui-icons.png": "tool-icons.png"}
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const INK: Color = Color("edf5fc")
const MUTED: Color = Color("bacbd9")
const PAPER: Color = Color("182432")
const BOARD: Color = Color("111c29")
const ACCENT: Color = Color("77e2dc")
const COPPER: Color = Color("edb75f")
const GOLD: Color = Color("ffd18a")
const SLATE_DARK: Color = Color("101a27")
const LINE: Color = Color("42586d")
const QUIET_PAPER_PATH: String = "res://assets/generated/focused-ui/paper-v1.png"
const TOOL_CELLS: Dictionary = {"select": 0, "undo": 1, "redo": 2, "delete": 3, "rotate": 4, "zoom": 5, "fit": 6, "inspect": 7, "receipt": 8, "home": 9, "save": 10, "help": 11, "duplicate": 12, "draw": 13, "adventure": 14, "book": 15}
const EXPANDED_MATERIAL_CELLS: Dictionary = {"stone": 0, "concrete": 1, "plaster": 2, "green_brick": 3, "frosted_glass": 4, "amber_glass": 5, "teal_glass": 6, "grille": 7, "zinc_roof": 8, "clay_roof": 9, "slate_roof": 10, "metal_roof": 11, "cedar": 12, "louver": 13, "mosaic": 14, "copper": 15}
static var _textures: Dictionary = {}
static var _regions: Dictionary = {}

static func generated_texture(filename: String) -> Texture2D:
	match filename:
		"client-portraits.png": return StarfrontArt.sheet("crew")
		"construction-materials.png", "construction-materials-expanded.png": return StarfrontArt.sheet("materials")
		"ui-icons.png": return StarfrontArt.sheet("tools")
		"ui-surfaces.png": return StarfrontArt.sheet("skin")
		"drawing-cover.png": return StarfrontArt.scene(6)
		"construction-cover.png": return StarfrontArt.scene(7)
		"app-icon.png": return StarfrontArt.cell("items", 23, 4, 6, true)
	if _textures.has(filename): return _textures[filename] as Texture2D
	var path: String = GENERATED_ROOT + filename
	if GAME_FILES.has(filename) and ResourceLoader.exists(GAME_ROOT + str(GAME_FILES[filename])):
		path = GAME_ROOT + str(GAME_FILES[filename])
	if not ResourceLoader.exists(path): return null
	var result: Texture2D = load(path) as Texture2D
	if result != null: _textures[filename] = result
	return result

static func _atlas(filename: String, cell: int, columns: int, rows: int) -> Texture2D:
	match filename:
		"construction-materials.png": return StarfrontArt.cell("brick", 0, 1, 1) if cell == 0 else StarfrontArt.cell("materials", cell, 4, 6)
		"construction-materials-expanded.png": return StarfrontArt.cell("materials", cell + 8, 4, 6)
		"client-portraits.png": return StarfrontArt.cell("crew", cell, 4, 4, true)
		"ui-icons.png": return StarfrontArt.cell("tools", cell, 4, 4, true)
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

static func surface_texture(_primary: bool = false, _button: bool = false) -> Texture2D:
	return StarfrontArt.interior(0)

static func _paper_style(_tint: Color, padding: int) -> StyleBoxTexture:
	return StarfrontArt.panel(5, padding)

static func panel(primary: bool = false, padding: int = 14) -> StyleBoxTexture:
	return StarfrontArt.panel(3 if primary else 0, padding)

static func dark_panel(padding: int = 12) -> StyleBoxTexture:
	return StarfrontArt.panel(4, padding)

static func gold_panel(padding: int = 10) -> StyleBoxTexture:
	return StarfrontArt.panel(2, padding)

static func card_panel(padding: int = 10, _tint: Color = Color("eef4f1")) -> StyleBoxTexture:
	return StarfrontArt.panel(5, padding)

static func pill_style(_tint: Color = Color("e3ede8"), padding_h: int = 8, padding_v: int = 4) -> StyleBoxTexture:
	var result: StyleBoxTexture = StarfrontArt.panel(4, 4)
	result.texture = StarfrontArt.interior(4)
	for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: result.set_texture_margin(edge, 0.0)
	result.content_margin_left = float(maxi(padding_h, 7))
	result.content_margin_right = float(maxi(padding_h, 7))
	result.content_margin_top = float(maxi(padding_v, 4))
	result.content_margin_bottom = float(maxi(padding_v, 4))
	return result

static func button_style(primary: bool = false, state: String = "normal", padding: int = 12) -> StyleBoxTexture:
	return ButtonArt.style(primary, state, padding)

static func quiet_surface_texture(_primary: bool = false) -> Texture2D:
	return surface_texture()

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
	if tool == "pan":
		return _pan_icon()
	if tool == "clear":
		return _clear_icon()
	return _atlas("ui-icons.png", int(TOOL_CELLS.get(tool, 0)), 4, 4)

static func _clear_icon() -> Texture2D:
	var key: String = "tool_icon:clear"
	if _textures.has(key): return _textures[key] as Texture2D
	var img: Image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var handle_col: Color = Color("d49a55")
	var metal_col: Color = Color("8fa2a6")
	var bristle_col: Color = Color("f6cf46")
	var bristle_shade: Color = Color("d4a822")
	var spark_col: Color = Color("62c7b8")
	for i: int in range(10):
		var x: int = 19 - i
		var y: int = 4 + i
		if x >= 0 and x < 24 and y >= 0 and y < 24:
			img.set_pixel(x, y, handle_col)
			if x + 1 < 24:
				img.set_pixel(x + 1, y, handle_col)
	for ox: int in range(-1, 2):
		for oy: int in range(-1, 2):
			var fx: int = 10 + ox
			var fy: int = 13 + oy
			if fx >= 0 and fx < 24 and fy >= 0 and fy < 24:
				img.set_pixel(fx, fy, metal_col)
	for bx: int in range(4, 12):
		for by: int in range(14, 22):
			if (bx + by) >= 18 and (bx + by) <= 28 and (by - bx) >= 6:
				if bx >= 0 and bx < 24 and by >= 0 and by < 24:
					img.set_pixel(bx, by, bristle_col if (bx + by) % 2 == 0 else bristle_shade)
	img.set_pixel(3, 21, spark_col)
	img.set_pixel(4, 22, spark_col)
	img.set_pixel(14, 21, spark_col)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex

static func _pan_icon() -> Texture2D:
	var key: String = "tool_icon:pan"
	if _textures.has(key): return _textures[key] as Texture2D
	var img: Image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col: Color = Color("f6b338")
	for y: int in range(10, 14):
		for x: int in range(10, 14):
			img.set_pixel(x, y, col)
	for i: int in range(5, 19):
		img.set_pixel(11, i, col)
		img.set_pixel(12, i, col)
		img.set_pixel(i, 11, col)
		img.set_pixel(i, 12, col)
	for d: int in range(4):
		for ox: int in range(-d, d + 1):
			var px: int = 11 + ox if ox <= 0 else 12 + ox - 1
			if px >= 0 and px < 24:
				img.set_pixel(px, 3 + d, col)
				img.set_pixel(px, 20 - d, col)
	for d: int in range(4):
		for oy: int in range(-d, d + 1):
			var py: int = 11 + oy if oy <= 0 else 12 + oy - 1
			if py >= 0 and py < 24:
				img.set_pixel(3 + d, py, col)
				img.set_pixel(20 - d, py, col)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex

static func category_icon(category: String) -> Texture2D:
	match category:
		"wall": return material_icon("wall")
		"opening": return material_icon("window")
		"roof": return material_icon("roof")
		"decor": return material_icon("ornament")
		_: return tool_icon("draw")

static func shape_icon(kind: String) -> Texture2D:
	var key: String = "shape_icon:" + kind
	if _textures.has(key):
		return _textures[key] as Texture2D
	var img: Image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dims: Vector2 = Vector2(16, 16)
	match kind:
		"rectangle": dims = Vector2(18, 12)
		"trapezoid": dims = Vector2(18, 13)
		"parallelogram": dims = Vector2(18, 12)
		"rhombus": dims = Vector2(14, 18)
		_: dims = Vector2(15, 15)
	var verts: PackedVector2Array = Math.create_vertices(kind if kind in Math.KINDS else "square", dims)
	var center: Vector2 = Vector2(12, 12)
	var poly: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in verts:
		poly.append(v + center)
	var fill_col: Color = Color("e8a838")
	match kind:
		"square": fill_col = Color("4da6ff")
		"rectangle": fill_col = Color("e07a5f")
		"trapezoid": fill_col = Color("52b788")
		"parallelogram": fill_col = Color("9b72cf")
		"rhombus": fill_col = Color("f4a261")
	for py: int in range(24):
		for px: int in range(24):
			var pt: Vector2 = Vector2(float(px) + 0.5, float(py) + 0.5)
			if Geometry2D.is_point_in_polygon(pt, poly):
				var min_d: float = 99.0
				for i: int in range(poly.size()):
					var a: Vector2 = poly[i]
					var b: Vector2 = poly[(i + 1) % poly.size()]
					var seg: Vector2 = Geometry2D.get_closest_point_to_segment(pt, a, b)
					min_d = minf(min_d, pt.distance_to(seg))
				img.set_pixel(px, py, Color("edf5fc") if min_d < 1.35 else fill_col)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex

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
	result.client_index = posmod(index, 9)
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
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		resized.connect(queue_redraw)

	func _draw() -> void:
		var material: Dictionary = Catalog.material(material_id)
		var sample: Texture2D = ConstructionArt.material_icon(material_id)
		if material.is_empty() or sample == null: return
		var vertices: PackedVector2Array = Math.create_vertices(str(material.kind), Vector2(material.dimensions))
		var bounds: Rect2 = Math.bounds(vertices)
		var ground_h: float = minf(8.0, size.y * 0.16)
		var ground_y: float = size.y - ground_h
		var cells_w: float = maxf(1.0, bounds.size.x / Catalog.GRID_UNIT)
		var cells_h: float = maxf(1.0, bounds.size.y / Catalog.GRID_UNIT)
		var cell_px: float = clampf(minf(maxf(size.x - 14.0, 4.0) / cells_w, maxf(ground_y - 8.0, 4.0) / cells_h), 2.5, 16.0)
		var scale: float = cell_px / Catalog.GRID_UNIT
		var center_pt: Vector2 = Vector2(roundf(size.x * 0.5), ground_y - (bounds.end.y - bounds.get_center().y) * scale)
		var left_x: float = center_pt.x + (bounds.position.x - bounds.get_center().x) * scale
		# Tactile game item slot backdrop (blueprint sky + miniature ground strip)
		draw_rect(Rect2(Vector2.ZERO, size), Color("dfece8"))
		draw_rect(Rect2(Vector2(0.0, ground_y), Vector2(size.x, ground_h)), Color("c9b99f"))
		var grid_col: Color = Color(0.16, 0.34, 0.31, 0.16)
		var step_px: float = maxf(cell_px, 4.0)
		var start_x: float = fposmod(left_x, step_px)
		var gx: float = start_x
		while gx < size.x - 1.0:
			if gx > 1.0:
				draw_line(Vector2(gx, 1.0), Vector2(gx, ground_y), grid_col, 1.0)
			gx += step_px
		var gy: float = ground_y - step_px
		while gy > 1.0:
			draw_line(Vector2(1.0, gy), Vector2(size.x - 1.0, gy), grid_col, 1.0)
			gy -= step_px
		draw_line(Vector2(0.0, ground_y), Vector2(size.x, ground_y), Color("527d62"), 1.5)
		# Recessed 3D slot bevel
		draw_rect(Rect2(Vector2.ZERO, size), Color("5b7870"), false, 1.5)
		draw_line(Vector2(1, size.y - 1), Vector2(size.x - 1, size.y - 1), Color(1.0, 1.0, 1.0, 0.65), 1.0)
		# Drop shadow behind the quadrilateral part
		var shadow_pts: PackedVector2Array = PackedVector2Array()
		for vertex: Vector2 in vertices:
			shadow_pts.append((vertex - bounds.get_center()) * scale + center_pt + Vector2(2.0, 2.0))
		if shadow_pts.size() == 4:
			draw_colored_polygon(shadow_pts, Color(0.08, 0.16, 0.15, 0.22))
		var counted_bricks: bool = int(material.get("brick_count", 0)) > 1
		var columns: int = maxi(1, roundi((vertices[1] - vertices[0]).length() / 40.0)) if counted_bricks else 1
		var rows: int = maxi(1, roundi((vertices[2] - vertices[1]).length() / 20.0)) if counted_bricks else 1
		for row: int in range(rows):
			for column: int in range(columns):
				var area: Rect2 = Rect2(float(column) / columns, float(row) / rows, 1.0 / columns, 1.0 / rows)
				var corners: PackedVector2Array = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
				var points: PackedVector2Array = PackedVector2Array()
				for corner: Vector2 in corners: points.append((ConstructionArt.quad_point(vertices, corner) - bounds.get_center()) * scale + center_pt)
				draw_polygon(points, PackedColorArray([Color.WHITE]), ConstructionArt.texture_uvs(sample), ConstructionArt.texture_source(sample))
		var outline: PackedVector2Array = PackedVector2Array()
		for vertex: Vector2 in vertices:
			outline.append((vertex - bounds.get_center()) * scale + center_pt)
		if outline.size() >= 2:
			draw_line(outline[0], outline[1], Color(1.0, 1.0, 0.94, 0.45), 1.5, true)
		outline.append(outline[0])
		draw_polyline(outline, Color("233834"), 1.5, true)

class ClientPortrait extends Control:
	var client_index: int = 0:
		set(value):
			client_index = posmod(value, 9)
			queue_redraw()
	# Satisfaction is always communicated in text. The generated portrait is
	# preserved rather than drawing a replacement facial expression in code.
	var mood: String = "happy":
		set(value):
			mood = value if value in ["happy", "straight", "sad"] else "happy"
			queue_redraw()

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		resized.connect(queue_redraw)

	func _draw() -> void:
		var bg_tint: Color = Color("173845") if mood == "happy" else (Color("423024") if mood == "sad" else Color("1c2b38"))
		var border_tint: Color = Color("1f6f4e") if mood == "happy" else (Color("c27428") if mood == "sad" else Color("4a6b63"))
		draw_rect(Rect2(Vector2.ZERO, size), bg_tint)
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(1.0, 1.0, 1.0, 0.35), false, 1.5)
		var image: Texture2D = ConstructionArt._atlas("client-portraits.png", client_index, 3, 2) if client_index < 6 else GameArt.npc(client_index - 6)
		if image != null:
			var scale: float = minf(size.x / image.get_width(), size.y / image.get_height())
			var dimensions: Vector2 = image.get_size() * scale
			draw_texture_rect(image, Rect2((size - dimensions) * 0.5, dimensions), false)
		draw_rect(Rect2(Vector2.ZERO, size), border_tint, false, 2.0)
		for corner: Vector2 in [Vector2(3, 3), Vector2(size.x - 5, 3), Vector2(3, size.y - 5), Vector2(size.x - 5, size.y - 5)]:
			draw_rect(Rect2(corner, Vector2(2, 2)), Color("d69636"))
