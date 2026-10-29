class_name GameArt
extends RefCounted
## Atlas slicing only. Every source pixel is generated artwork, never procedural art.
static var _sheets: Dictionary = {}
static var _cells: Dictionary = {}

static func sheet(name: String) -> Texture2D:
	if not _sheets.has(name):
		_sheets[name] = load("res://assets/generated/" + name + ".png") as Texture2D
	return _sheets[name]

static func cell(name: String, index: int, columns: int, rows: int, trim: bool = true) -> AtlasTexture:
	var key: String = "%s:%d:%s" % [name, index, trim]
	if _cells.has(key): return _cells[key]
	var source: Texture2D = sheet(name)
	var dimensions: Vector2i = source.get_size()
	var width: int = floori(float(dimensions.x) / columns)
	var height: int = floori(float(dimensions.y) / rows)
	var region: Rect2i = Rect2i((index % columns) * width, floori(float(index) / columns) * height, width, height)
	if name == "environment_atlas":
		var boundaries: Array[int] = [0, 397, 749, 1086]
		var row: int = floori(float(index) / columns)
		region.position.y = boundaries[row]
		region.size.y = boundaries[row + 1] - boundaries[row]
	if trim:
		var image: Image = source.get_image()
		if image.is_compressed(): image.decompress()
		var used: Rect2i = image.get_region(region).get_used_rect()
		if used.has_area(): region = Rect2i(region.position + used.position, used.size)
	var result: AtlasTexture = AtlasTexture.new()
	result.atlas = source
	result.region = region
	result.filter_clip = true
	_cells[key] = result
	return result

static func item(index: int) -> AtlasTexture:
	return cell("items_atlas", index, 4, 4)

static func npc(index: int) -> AtlasTexture:
	return cell("npc_atlas", index, 4, 2)

static func quest_item(quest: Dictionary) -> AtlasTexture:
	var atlas_name: String = str(quest.get("item_sheet", "items_atlas"))
	return cell(atlas_name, int(quest.get("item_icon", 0)), 4, 4 if atlas_name == "items_atlas" else 2)

static func quest_npc(quest: Dictionary) -> AtlasTexture:
	return cell(str(quest.get("npc_sheet", "npc_atlas")), int(quest.get("npc_icon", 0)), 4, 2)

static func panel(index: int, padding: int = 16) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = panel_texture(index)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 0.0)
		style.set_content_margin(side, padding)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return style

static func panel_texture(index: int) -> AtlasTexture:
	var key: String = "panel_interior:%d" % index
	if _cells.has(key): return _cells[key]
	# Use the generated panel's quiet interior for scalable controls. This avoids
	# enlarging corner ornaments into the text area of narrow buttons and bars.
	var source: AtlasTexture = cell("ui_atlas", index, 2, 2)
	var result: AtlasTexture = AtlasTexture.new()
	result.atlas = source.atlas
	result.region = source.region.grow(-88)
	result.filter_clip = true
	_cells[key] = result
	return result

static func drafting_paper() -> Texture2D:
	# Both sources are ImageGen originals. The earlier paper remains usable
	# while a fresh checkout imports the revision atlas for the first time.
	if ResourceLoader.exists("res://assets/generated/revision/ui-surfaces.png"):
		return cell("revision/ui-surfaces", 0, 2, 2, false)
	return panel_texture(0)

static func view(texture: Texture2D, dimensions: Vector2 = Vector2(56, 56)) -> TextureRect:
	var result: TextureRect = TextureRect.new()
	result.texture = texture
	result.custom_minimum_size = dimensions
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
