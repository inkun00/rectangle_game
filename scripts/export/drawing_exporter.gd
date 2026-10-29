class_name DrawingExporter
extends RefCounted

const Model = preload("res://scripts/core/drawing_document.gd")
const Catalog = preload("res://scripts/core/drawing_catalog.gd")

## Export only the chosen scene and player artwork, without editing guides.
static func export_png(tree: SceneTree, document: Model) -> PackedByteArray:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(960, 600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var paper: ColorRect = ColorRect.new()
	paper.color = Color.WHITE
	paper.size = Vector2(960, 600)
	viewport.add_child(paper)
	var scene: Dictionary = Catalog.background(document.background_id)
	if not scene.is_empty():
		var background: TextureRect = TextureRect.new()
		background.texture = load(str(scene.path)) as Texture2D
		background.size = Vector2(960, 600)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_SCALE
		viewport.add_child(background)
	for part: Dictionary in document.ordered_shapes():
		var polygon: Polygon2D = Polygon2D.new()
		polygon.polygon = part.vertices
		polygon.position = Vector2(part.position) - Model.ARTBOARD.position
		polygon.color = part.color
		polygon.antialiased = true
		viewport.add_child(polygon)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var bytes: PackedByteArray = viewport.get_texture().get_image().save_png_to_buffer()
	viewport.queue_free()
	return bytes
