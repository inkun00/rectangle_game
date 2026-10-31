class_name StarfrontArt
extends RefCounted
## Original ImageGen assets; presentation only, never geometry or game state.
const ROOT: String = "res://assets/generated/starfront-v1/"
const INK: Color = Color("edf5fc")
const MUTED: Color = Color("bacbd9")
const ACCENT: Color = Color("77e2dc")
const AMBER: Color = Color("ffd18a")
const DARK: Color = Color("111c29")
static var _sheets: Dictionary = {}
static var _cells: Dictionary = {}

static func sheet(asset: String) -> Texture2D:
	if not _sheets.has(asset): _sheets[asset] = load(ROOT + asset + ".png") as Texture2D
	return _sheets[asset] as Texture2D

static func cell(asset: String, index: int, columns: int, rows: int, trim: bool = false) -> AtlasTexture:
	var key: String = "%s:%d:%s" % [asset, index, trim]
	if _cells.has(key): return _cells[key] as AtlasTexture
	var source: Texture2D = sheet(asset)
	var extent: Vector2i = Vector2i(source.get_size())
	var column: int = posmod(index, columns)
	var row: int = floori(float(index) / float(columns))
	var left: int = roundi(float(column * extent.x) / float(columns))
	var top: int = roundi(float(row * extent.y) / float(rows))
	var right: int = roundi(float((column + 1) * extent.x) / float(columns))
	var bottom: int = roundi(float((row + 1) * extent.y) / float(rows))
	var region: Rect2i = Rect2i(left, top, right - left, bottom - top)
	if trim:
		var pixels: Image = source.get_image()
		if pixels.is_compressed(): pixels.decompress()
		var used: Rect2i = pixels.get_region(region).get_used_rect()
		if used.has_area(): region = Rect2i(region.position + used.position, used.size)
	var result: AtlasTexture = AtlasTexture.new()
	result.atlas = source
	result.region = Rect2(region)
	result.filter_clip = true
	result.set_meta("generated_source", ROOT + asset + ".png")
	_cells[key] = result
	return result

static func scene(index: int) -> Texture2D:
	return cell("environment-scenes", index, 3, 3)

static func face(index: int) -> Texture2D:
	var key: String = "face:%d" % index
	if _cells.has(key): return _cells[key] as Texture2D
	var source: AtlasTexture = cell("skin", index, 4, 2)
	var pixels: Image = source.get_image()
	if pixels.is_compressed(): pixels.decompress()
	# Compress the complete decorative frame before nine-slicing it. Its broad
	# source border must never expand into a label's text region.
	pixels.resize(64, 64, Image.INTERPOLATE_NEAREST)
	var result: ImageTexture = ImageTexture.create_from_image(pixels)
	result.set_meta("generated_source", ROOT + "skin.png")
	_cells[key] = result
	return result

static func panel(index: int = 0, padding: int = 14) -> StyleBoxTexture:
	var result: StyleBoxTexture = StyleBoxTexture.new()
	result.texture = face(index)
	for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(edge, 10.0)
		result.set_content_margin(edge, float(padding))
	return result

static func interior(index: int = 0) -> Texture2D:
	var source: AtlasTexture = cell("skin", index, 4, 2)
	var result: AtlasTexture = AtlasTexture.new()
	result.atlas = source.atlas
	result.region = source.region.grow(-source.region.size.x * 0.24)
	result.filter_clip = true
	return result

static func gauge(index: int) -> StyleBoxTexture:
	var result: StyleBoxTexture = panel(index, 0)
	result.texture = interior(index)
	for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: result.set_texture_margin(edge, 0.0)
	return result
