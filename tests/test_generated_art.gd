class_name TestGeneratedArt
extends RefCounted

const Art = preload("res://scripts/construction_art.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const FILES: Array[String] = ["app-icon.png", "client-portraits.png", "construction-cover.png", "construction-materials.png", "construction-materials-expanded.png", "drawing-cover.png", "ui-icons.png", "ui-surfaces.png"]
const TOOLS: Array[String] = ["select", "undo", "redo", "delete", "rotate", "zoom", "fit", "inspect", "receipt", "home", "save", "help", "duplicate", "draw", "adventure", "book"]

static func run(t: Node) -> void:
	for filename: String in FILES:
		var texture: Texture2D = Art.generated_texture(filename)
		t.assert_not_null(texture, "The shipped generated artwork loads: " + filename)
		if texture != null:
			t.assert_true(texture.get_width() > 0 and texture.get_height() > 0, "The generated artwork has usable dimensions: " + filename)
			t.assert_true(texture.resource_path.begins_with("res://assets/generated/"), "The image comes from a generated source: " + filename)
	var paper: Texture2D = GameArt.drafting_paper()
	t.assert_true(_valid_region(paper), "Drawing and workshop paper has a usable generated atlas region")
	if paper is AtlasTexture:
		t.assert_true(Art.texture_source(paper) == Art.generated_texture("ui-surfaces.png"), "Drawing and workshop use the current generated paper rather than a missing-image fallback")
	_test_tools(t)
	_test_materials(t)
	_test_portraits(t)

static func _test_tools(t: Node) -> void:
	var regions: Array[Rect2] = []
	var source: Texture2D = Art.generated_texture("ui-icons.png")
	for tool: String in TOOLS:
		var texture: Texture2D = Art.tool_icon(tool)
		t.assert_true(_valid_region(texture), "The tool icon has a valid generated image region: " + tool)
		if not texture is AtlasTexture: continue
		t.assert_true(Art.texture_source(texture) == source, "The tool icon shares the generated icon sheet: " + tool)
		regions.append((texture as AtlasTexture).region)
	t.assert_eq(regions.size(), TOOLS.size(), "Every displayed tool has an atlas icon")
	t.assert_true(_disjoint(regions), "Different tool actions do not accidentally reuse or overlap an icon cell")

static func _test_materials(t: Node) -> void:
	var source: Texture2D = Art.generated_texture("construction-materials.png")
	var expanded: Texture2D = Art.generated_texture("construction-materials-expanded.png")
	for material: Dictionary in Catalog.materials():
		var id: String = str(material.id)
		var texture: Texture2D = Art.material_icon(id)
		t.assert_true(_valid_region(texture), "The material can display generated artwork: " + id)
		if texture == null: continue
		var texture_key: String = str(material.get("texture_key", ""))
		var expected: Texture2D = expanded if Art.EXPANDED_MATERIAL_CELLS.has(texture_key) and int(material.get("brick_count", 0)) == 0 else source
		t.assert_true(Art.texture_source(texture) == expected, "The material uses its generated material sheet: " + id)
		t.assert_true(_valid_uvs(texture), "Material UVs stay finite and inside their source image: " + id)

static func _test_portraits(t: Node) -> void:
	var regions: Array[Rect2] = []
	var source: Texture2D = Art.generated_texture("client-portraits.png")
	for index: int in range(6):
		var portrait: Control = Art.portrait(index)
		t.assert_eq(int(portrait.get("client_index")), index, "The portrait control retains its requested client")
		var texture: Texture2D = Art._atlas("client-portraits.png", index, 3, 2)
		t.assert_true(_valid_region(texture), "The client portrait has a usable generated image region")
		if texture is AtlasTexture:
			t.assert_true(Art.texture_source(texture) == source, "The client portrait uses the generated portrait sheet")
			regions.append((texture as AtlasTexture).region)
		portrait.free()
	t.assert_eq(regions.size(), 6, "All six clients have portrait artwork")
	t.assert_true(_disjoint(regions), "Client portraits occupy separate atlas cells")

static func _valid_region(texture: Texture2D) -> bool:
	if not texture is AtlasTexture: return false
	var atlas: AtlasTexture = texture as AtlasTexture
	if atlas.atlas == null or not atlas.region.has_area(): return false
	return Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region) and atlas.atlas.resource_path.begins_with("res://assets/generated/")

static func _valid_uvs(texture: Texture2D) -> bool:
	var uvs: PackedVector2Array = Art.texture_uvs(texture)
	if uvs.size() != 4: return false
	for point: Vector2 in uvs:
		if not point.is_finite() or point.x < 0.0 or point.x > 1.0 or point.y < 0.0 or point.y > 1.0: return false
	return uvs[1].x > uvs[0].x and uvs[3].y > uvs[0].y

static func _disjoint(regions: Array[Rect2]) -> bool:
	for first: int in range(regions.size()):
		for second: int in range(first + 1, regions.size()):
			if regions[first].intersects(regions[second]): return false
	return true
