extends SceneTree

const Studio = preload("res://scenes/drawing/drawing_studio.gd")
const Exporter = preload("res://scripts/export/drawing_exporter.gd")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1600, 900)
	var studio: Studio = Studio.new()
	studio.testing = true
	root.add_child(studio)
	DirAccess.make_dir_recursive_absolute("res://.godot/previews/drawing-features")
	await _frames()
	studio.document.set_background("city_day")
	studio.document.add_sized_shape("rectangle", Vector2(-140, 65), Vector2(220, 160), Color("ffc36c"))
	studio.document.add_sized_shape("trapezoid", Vector2(-140, -70), Vector2(260, 110), Color("e78683"))
	studio.document.add_sized_shape("square", Vector2(-170, 65), Vector2(55, 55), Color("b6e5ea"))
	studio.document.add_sized_shape("rectangle", Vector2(-70, 95), Vector2(45, 100), Color("557f99"))
	studio.document.add_sized_shape("rhombus", Vector2(160, -50), Vector2(110, 170), Color("a893d2"))
	studio.canvas.select_tool()
	await _save("studio")
	var scene_png: PackedByteArray = await Exporter.export_png(self, studio.document)
	var scene_image: Image = Image.new()
	assert(scene_image.load_png_from_buffer(scene_png) == OK)
	assert(scene_image.get_size() == Vector2i(960, 600))
	assert(scene_image.get_pixel(0, 0) != Color.WHITE)
	scene_image.save_png("res://.godot/previews/drawing-features/scene-export.png")
	var origin: Dictionary = studio.document.get_selected()
	var midpoint: Vector2 = Vector2(origin.position) + (Vector2(origin.vertices[0]) + Vector2(origin.vertices[1])) * 0.5
	_pointer(studio.canvas, midpoint, true)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = studio.canvas.artwork_to_screen(Vector2(origin.position) + (midpoint - Vector2(origin.position)) * 1.6)
	studio.canvas._gui_input(motion)
	await _save("resizing")
	studio.canvas.cancel_gesture()
	studio.document.set_background("paper")
	studio.document.clear()
	studio.document.set_masterpiece("starry_night")
	studio.document.add_sized_shape("rectangle", Vector2(-200, 190), Vector2(100, 90), Color("deb86b"))
	studio.document.add_sized_shape("trapezoid", Vector2(-200, 115), Vector2(120, 60), Color("648d9f"))
	studio.document.add_sized_shape("rhombus", Vector2(140, -150), Vector2(55, 55), Color("f2ca68"))
	await _save("masterpiece")
	studio._open_gallery(true)
	await _save("masterpiece-gallery")
	studio._gallery.hide()
	studio._open_colors()
	await _save("palette")
	studio._color_dialog.hide()
	root.size = Vector2i(1024, 720)
	root.content_scale_size = Vector2i(1024, 720)
	await _save("small")
	studio._open_gallery(true)
	await _save("gallery-small")
	studio._gallery.hide()
	var png: PackedByteArray = await Exporter.export_png(self, studio.document)
	var image: Image = Image.new()
	assert(image.load_png_from_buffer(png) == OK)
	assert(image.get_size() == Vector2i(960, 600))
	assert(image.get_pixel(0, 0).is_equal_approx(Color.WHITE))
	image.save_png("res://.godot/previews/drawing-features/export.png")
	studio.free()
	print("Drawing feature previews and clean PNG export verified.")
	quit()

func _save(name: String) -> void:
	await _frames()
	root.get_texture().get_image().save_png("res://.godot/previews/drawing-features/" + name + ".png")

func _frames() -> void:
	for frame: int in range(6):
		await process_frame
	await RenderingServer.frame_post_draw

func _pointer(canvas: Control, point: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = canvas.artwork_to_screen(point)
	canvas._gui_input(event)
