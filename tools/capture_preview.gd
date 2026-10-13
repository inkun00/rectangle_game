extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1600, 900)
	var app: QuadrilateralApp = load("res://scenes/main/main.tscn").instantiate()
	app.testing = true
	root.add_child(app)
	DirAccess.make_dir_recursive_absolute("res://.godot/previews")
	await _frames()
	root.get_texture().get_image().save_png("res://.godot/previews/workshop-empty.png")
	app.document.fill_example()
	await _frames()
	root.get_texture().get_image().save_png("res://.godot/previews/workshop.png")
	var png: PackedByteArray = await CharacterExporter.export_png(self, app.document.character_data())
	var file: FileAccess = FileAccess.open("res://.godot/previews/character-export.png", FileAccess.WRITE)
	file.store_buffer(png)
	file.close()
	app._enter_world()
	await create_timer(0.3).timeout
	await _frames()
	root.get_texture().get_image().save_png("res://.godot/previews/world.png")
	app._talk_to_npc("baker")
	await _frames()
	root.get_texture().get_image().save_png("res://.godot/previews/dialogue.png")
	app._close_modal()
	app._show_map()
	await _frames()
	root.get_texture().get_image().save_png("res://.godot/previews/map.png")
	app._close_modal()
	app._show_story()
	await _frames()
	root.get_texture().get_image().save_png("res://.godot/previews/story.png")
	app._close_modal()
	for region_id: String in ["harbor", "snow", "citadel"]:
		app.adventure.discover(region_id)
		app.world.travel_to(region_id)
		await create_timer(0.3).timeout
		await _frames()
		root.get_texture().get_image().save_png("res://.godot/previews/%s.png" % region_id)
	app._return_workshop()
	root.size = Vector2i(1100, 760)
	await _frames()
	root.get_texture().get_image().save_png("res://.godot/previews/workshop-small.png")
	print("Visual previews captured.")
	app.free()
	quit()

func _frames() -> void:
	for frame: int in range(6): await process_frame
	await RenderingServer.frame_post_draw
