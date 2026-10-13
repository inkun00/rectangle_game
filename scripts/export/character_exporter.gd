class_name CharacterExporter
extends RefCounted

static func export_png(tree: SceneTree, character: Dictionary) -> PackedByteArray:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var drawing: Node2D = Node2D.new()
	viewport.add_child(drawing)
	var parts: Array = character.get("parts", [])
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for part: Dictionary in parts:
		for vertex: Vector2 in part["vertices"]:
			var point: Vector2 = vertex + Vector2(part["position"])
			if first:
				bounds = Rect2(point, Vector2.ZERO)
				first = false
			else: bounds = bounds.expand(point)
	var fit: float = 440.0 / maxf(maxf(bounds.size.x, bounds.size.y), 1.0)
	for part: Dictionary in parts:
		var polygon: Polygon2D = Polygon2D.new()
		polygon.polygon = part["vertices"]
		polygon.position = (Vector2(part["position"]) - bounds.get_center()) * fit + Vector2(256, 256)
		polygon.scale = Vector2.ONE * fit
		polygon.color = part["color"]
		polygon.antialiased = true
		drawing.add_child(polygon)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var pixels: Image = viewport.get_texture().get_image()
	var bytes: PackedByteArray = pixels.save_png_to_buffer()
	viewport.queue_free()
	return bytes
