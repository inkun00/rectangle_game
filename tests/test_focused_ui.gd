class_name TestFocusedUi
extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")
const Art = preload("res://scripts/construction_art.gd")

static func run(t: Node) -> void:
	for texture: Texture2D in [Art.surface_texture(), Art.quiet_surface_texture()]:
		t.assert_not_null(texture, "Quiet UI retains the generated metal interior")
		if texture == null: continue
		t.assert_true(texture is AtlasTexture, "Quiet surfaces crop the generated skin rather than enlarging ornaments")
		if texture is AtlasTexture:
			t.assert_true((texture as AtlasTexture).atlas.resource_path.ends_with("starfront-v1/skin.png"), "All quiet chrome shares the new generated palette")
		t.assert_ge(texture.get_width(), 64, "Metal face has enough source detail")
	var window: Window = t.get_window()
	var previous: Dictionary = {
		"size": window.size, "minimum": window.min_size,
		"scale_size": window.content_scale_size, "mode": window.content_scale_mode,
		"aspect": window.content_scale_aspect, "factor": window.content_scale_factor,
	}
	window.min_size = Vector2i.ZERO
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_factor = 1.0
	window.size = Vector2i(1280, 720)
	await _settle(t)
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	app._sound.sound_enabled = false
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(783, 712)]:
		window.size = dimensions
		await _settle(t)
		app._responsive()
		await _settle(t)
		var context: String = "Home %d x %d" % [dimensions.x, dimensions.y]
		t.assert_eq(window.size, dimensions, context + " uses the actual window dimensions")
		for name: String in ["OpenDrawing", "OpenConstruction", "OpenAdventure"]:
			var button: Button = app._home_screen.find_child(name, true, false) as Button
			t.assert_not_null(button, context + " retains the " + name + " entry action")
			if button == null: continue
			t.assert_true(button.is_visible_in_tree() and not button.disabled, context + " keeps " + name + " usable")
			var bounds: Rect2 = _physical_rect(button)
			t.assert_ge(bounds.position.x, -1.0, context + " keeps " + name + " inside the left edge")
			t.assert_le(bounds.end.x, float(dimensions.x) + 1.0, context + " keeps " + name + " inside the right edge")
			if dimensions.x >= 1280:
				t.assert_ge(bounds.position.y, -1.0, context + " shows " + name + " without upward scrolling")
				t.assert_le(bounds.end.y, float(dimensions.y) + 1.0, context + " shows " + name + " without downward scrolling")
	app.free()
	window.content_scale_size = previous["scale_size"]
	window.content_scale_mode = previous["mode"]
	window.content_scale_aspect = previous["aspect"]
	window.content_scale_factor = float(previous["factor"])
	window.min_size = previous["minimum"]
	window.size = previous["size"]
	await _settle(t)
	t.assert_eq(window.size, previous["size"], "Focused UI regression restores the shared window dimensions")
	t.assert_eq(window.content_scale_size, previous["scale_size"], "Focused UI regression restores the shared logical viewport")

static func _physical_rect(control: Control) -> Rect2:
	var transform: Transform2D = control.get_viewport().get_stretch_transform() * control.get_global_transform_with_canvas()
	var bounds: Rect2 = Rect2(transform * Vector2.ZERO, Vector2.ZERO)
	for corner: Vector2 in [Vector2(control.size.x, 0), control.size, Vector2(0, control.size.y)]:
		bounds = bounds.expand(transform * corner)
	return bounds

static func _settle(t: Node) -> void:
	for frame: int in range(8): await t.get_tree().process_frame
