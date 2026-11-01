class_name TestStarfrontPresentation
extends RefCounted

static func run(t: Node) -> void:
	_test_native_resolution(t)
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
	t.assert_true(snow_prop.region == StarfrontArt.prop(19).region, "Snow scenery uses ice rather than a fortress from the repacked atlas")
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

static func _test_native_resolution(t: Node) -> void:
	var scene_size: Vector2 = StarfrontArt.scene(0).get_size()
	for index: int in range(9):
		var background: Texture2D = StarfrontArt.scene(index)
		t.assert_false(background is AtlasTexture, "Full-screen backgrounds never enlarge a small atlas cell")
		t.assert_ge(background.get_width(), 1600, "Each background has native full-screen width")
		t.assert_ge(background.get_height(), 900, "Each background has native full-screen height")
		t.assert_eq(background.get_size(), scene_size, "All biome and activity backgrounds share one native resolution")
		t.assert_true(background.resource_path.begins_with(StarfrontArt.HD_ROOT), "Background resolves to its regenerated project asset")
	for index: int in range(20):
		var prop: AtlasTexture = StarfrontArt.prop(index)
		t.assert_true(Rect2(Vector2.ZERO, prop.atlas.get_size()).encloses(prop.region), "Environmental sprite crop stays inside its source")
		t.assert_ge(prop.get_width(), 320, "Environmental art has enough native width for the displayed object")
		t.assert_ge(prop.get_height(), 300, "Environmental art has enough native height for the displayed object")
	for index: int in range(1, 24):
		var material: AtlasTexture = StarfrontArt.material(index)
		t.assert_true(Rect2(Vector2.ZERO, material.atlas.get_size()).encloses(material.region), "Regenerated material UV region stays within the actual source")
		t.assert_ge(material.get_width(), 2048 if StarfrontArt.WIDE_MATERIALS.has(index) else 500, "Wide building parts never stretch a tiny material swatch")
		t.assert_ge(material.get_height(), 480, "Material crops retain native detail at editor zoom")
