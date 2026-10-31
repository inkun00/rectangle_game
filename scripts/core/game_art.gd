class_name GameArt
extends RefCounted
## Atlas slicing only. Every source pixel is generated artwork, never procedural art.
static var _sheets: Dictionary = {}
static var _cells: Dictionary = {}

static func sheet(name: String) -> Texture2D:
	if name == "world_backdrop": return StarfrontArt.scene(0)
	if name == "expansion_backdrop": return StarfrontArt.scene(3)
	if not _sheets.has(name):
		_sheets[name] = load("res://assets/generated/" + name + ".png") as Texture2D
	return _sheets[name]

static func cell(name: String, index: int, columns: int, rows: int, trim: bool = true) -> AtlasTexture:
	match name:
		"npc_atlas": return StarfrontArt.cell("crew", index, 4, 4, trim)
		"expansion_npcs": return StarfrontArt.cell("crew", index + 8, 4, 4, trim)
		"items_atlas": return StarfrontArt.cell("items", index, 4, 6, trim)
		"expansion_items": return StarfrontArt.cell("items", index + 16, 4, 6, trim)
		"environment_atlas": return StarfrontArt.cell("props", index, 4, 5, trim)
		"expansion_environment": return StarfrontArt.cell("props", [12, 18, 13, 14, 19, 15, 16, 17][index], 4, 5, trim)
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
	return StarfrontArt.panel([0, 4, 2, 3][posmod(index, 4)], padding)

static func framed_panel(index: int = 0, padding: int = 16, _border_px: int = 8, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var result: StyleBoxTexture = panel(index, padding)
	result.modulate_color = tint
	return result

static func framed_texture(index: int, _border_px: int = 11) -> Texture2D:
	return StarfrontArt.face([0, 4, 2, 3][posmod(index, 4)])

static func panel_texture(index: int) -> Texture2D:
	return StarfrontArt.interior([0, 4, 2, 3][posmod(index, 4)])

static func drafting_paper() -> Texture2D:
	return load("res://assets/generated/focused-ui/paper-v1.png") as Texture2D

static func view(texture: Texture2D, dimensions: Vector2 = Vector2(56, 56)) -> TextureRect:
	var result: TextureRect = TextureRect.new()
	result.texture = texture
	result.custom_minimum_size = dimensions
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
