class_name TestStarfrontPresentation
extends RefCounted

static func run(t: Node) -> void:
	var app: QuadrilateralApp = load("res://scenes/main/main.tscn").instantiate()
	app.testing = true
	t.add_child(app)
	app._sound.sound_enabled = false
	app.document.fill_example()
	app._enter_world()
	for frame: int in range(4): await t.get_tree().process_frame
	var artwork: WorldArtwork = app.world._artwork
	t.assert_true(artwork._backdrop_layer.visible, "Viewport background appears when entering the world")
	var scenes: Array[Texture2D] = []
	for x_position: float in [500.0, 2300.0, 3900.0, 5900.0, 7600.0, 9700.0]:
		artwork.update_backdrop(x_position, 0.0)
		t.assert_false(scenes.has(artwork._backdrop_view.texture), "Each region has a distinct readable biome background")
		scenes.append(artwork._backdrop_view.texture)
		t.assert_ge(artwork._backdrop_view.size.x, t.get_viewport().get_visible_rect().size.x, "Parallax overscan covers the viewport")
	var snow_prop: AtlasTexture = artwork.atlas("expansion_environment", 4) as AtlasTexture
	t.assert_true(snow_prop.region == StarfrontArt.cell("props", 19, 4, 5, true).region, "Snow scenery uses ice rather than a fortress from the repacked atlas")
	for enemy_id: String in artwork.enemy_sprites:
		var sprite: Sprite2D = artwork.enemy_sprites[enemy_id]
		t.assert_true(sprite.texture == GameArt.item(12) or sprite.texture == GameArt.item(13), "Encounter art remains a creature after atlas replacement")
	app._show_learning("square")
	for frame: int in range(3): await t.get_tree().process_frame
	t.assert_false(artwork._backdrop_layer.visible, "World background does not leak into the learning activity")
	app._show_workshop()
	app._enter_world()
	for frame: int in range(3): await t.get_tree().process_frame
	t.assert_true(app.world._artwork._backdrop_layer.visible, "Returning from an activity restores the world background")
	app.free()
	await t.get_tree().process_frame
