class_name StarfrontArt
extends RefCounted
## Original ImageGen assets; presentation only, never geometry or game state.
const ROOT: String = "res://assets/generated/starfront-v1/"
const HD_ROOT: String = "res://assets/generated/starfront-hd/"
const SCENE_NAMES: Array[String] = ["market", "forest", "valley", "harbor", "snow", "citadel", "workshop", "construction", "observatory"]
const PROP_SHEETS: Array[String] = ["settlement", "vegetation", "terrain", "destinations", "landmarks"]
# Measured opaque silhouettes retain overhanging lanterns and smoke. A uniform
# grid would clip the wide rocks and the inn even on a high-resolution sheet.
const PROP_REGIONS: Array[Rect2i] = [
	Rect2i(13, 0, 582, 633),
	Rect2i(636, 191, 600, 442),
	Rect2i(28, 687, 640, 513),
	Rect2i(687, 652, 526, 567),
	Rect2i(37, 28, 590, 595),
	Rect2i(663, 28, 565, 595),
	Rect2i(31, 657, 702, 569),
	Rect2i(786, 645, 362, 581),
	Rect2i(20, 19, 587, 595),
	Rect2i(635, 218, 609, 313),
	Rect2i(11, 810, 605, 350),
	Rect2i(673, 655, 531, 520),
	Rect2i(28, 110, 652, 515),
	Rect2i(735, 43, 427, 582),
	Rect2i(21, 650, 647, 537),
	Rect2i(682, 683, 556, 504),
	Rect2i(28, 112, 598, 497),
	Rect2i(652, 74, 574, 537),
	Rect2i(34, 731, 597, 453),
	Rect2i(635, 701, 594, 487)
]
const MATERIAL_SHEETS: Array[String] = ["details-a", "details-b", "details-c"]
const MATERIAL_INDICES: Array[int] = [1, 2, 3, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 20, 21, 22, 23]
const WIDE_MATERIALS: Dictionary[int, String] = {4: "beam-wood", 5: "roof-blue", 16: "roof-zinc", 18: "roof-slate", 19: "roof-metal"}
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
	return _slice(source, region, key, trim)

static func _slice(source: Texture2D, source_region: Rect2i, key: String, trim: bool = false) -> AtlasTexture:
	if _cells.has(key): return _cells[key] as AtlasTexture
	var region: Rect2i = source_region
	if trim:
		var pixels: Image = source.get_image()
		if pixels.is_compressed(): pixels.decompress()
		var used: Rect2i = pixels.get_region(region).get_used_rect()
		if used.has_area(): region = Rect2i(region.position + used.position, used.size)
	var result: AtlasTexture = AtlasTexture.new()
	result.atlas = source
	result.region = Rect2(region)
	result.filter_clip = true
	result.set_meta("generated_source", source.resource_path)
	_cells[key] = result
	return result

static func hd_sheet(asset: String) -> Texture2D:
	var key: String = "hd:" + asset
	if not _sheets.has(key): _sheets[key] = load(HD_ROOT + asset + ".png") as Texture2D
	return _sheets[key] as Texture2D

static func scene(index: int) -> Texture2D:
	# Each screen uses a complete newly generated image, never a tiny atlas cell.
	return hd_sheet("backgrounds/" + SCENE_NAMES[index])

static func prop(index: int, trim: bool = true) -> AtlasTexture:
	var group: int = floori(float(index) / 4.0)
	var source: Texture2D = hd_sheet("props/" + PROP_SHEETS[group])
	return _slice(source, PROP_REGIONS[index], "hd_prop:%d:%s" % [index, trim], trim)

static func material(index: int) -> AtlasTexture:
	if index == 0: return cell("brick", 0, 1, 1)
	if WIDE_MATERIALS.has(index):
		var wide: Texture2D = hd_sheet("materials/" + WIDE_MATERIALS[index])
		return _slice(wide, Rect2i(Vector2i.ZERO, Vector2i(wide.get_size())), "hd_material:%d" % index)
	var slot: int = MATERIAL_INDICES.find(index)
	assert(slot >= 0, "Unknown construction material cell")
	var group: int = floori(float(slot) / 6.0)
	var local: int = posmod(slot, 6)
	var row: int = floori(float(local) / 2.0)
	var source: Texture2D = hd_sheet("materials/" + MATERIAL_SHEETS[group])
	var width: int = floori(float(source.get_width()) / 2.0)
	# The third generated sheet has measured row dividers at 501 and 1010.
	var cuts: Array[int] = [0, 512, 1024, 1536]
	if group == 2: cuts.assign([0, 501, 1010, 1536])
	var region: Rect2i = Rect2i(posmod(local, 2) * width, cuts[row], width, cuts[row + 1] - cuts[row])
	return _slice(source, region, "hd_material:%d" % index)

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
