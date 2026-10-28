extends SceneTree

const Studio = preload("res://scenes/construction/construction_studio.gd")
const State = preload("res://scripts/construction/construction_state.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Guide = preload("res://scripts/construction/construction_guide.gd")
const Awards = preload("res://scripts/construction/construction_awards.gd")
const Exporter = preload("res://scripts/export/construction_exporter.gd")
const AwardFixture = preload("res://tests/test_construction_awards.gd")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/previews/construction-game")
	_resize(Vector2i(1600, 900))
	var studio: Studio = Studio.new()
	studio.testing = true
	root.add_child(studio)
	await _shot("brief")
	studio._close_modal()
	studio._accept_contract()
	await _shot("build")
	_resize(Vector2i(1024, 720))
	await _shot("build-small")
	_resize(Vector2i(800, 600))
	await _shot("build-compact")
	_resize(Vector2i(1024, 720))
	studio._show_stages()
	await _shot("stages-small")
	studio._show_glossary()
	await _shot("help-small")
	studio._close_modal()
	_resize(Vector2i(1600, 900))
	assert(studio.state.document.replace_parts(Guide.plan()))
	studio._start_inspection()
	await _inspection(studio)
	assert(studio.state.evaluate(studio._last_report).can_submit)
	studio._submit()
	await _shot("first-reward")
	studio._close_modal()
	# Build a legitimate account through authored offers and repeated lower work.
	for choice: int in range(1, 9):
		var target: Dictionary = Catalog.contract(choice)
		while not bool(studio.state.stage_unlock_status(int(target.stage)).unlocked):
			assert(studio.state.repeat_contract())
			_pay_example(studio.state)
		assert(studio.state.select_contract(choice))
		assert(studio.state.accept_contract())
		if choice == 8: break
		assert(studio.state.document.replace_parts(Guide.example_for_contract(studio.state.current_contract())))
		assert(not studio.state.settle(_report(studio.state)).is_empty())
	var excellent: ConstructionDocument = AwardFixture.excellent_document()
	assert(studio.state.document.restore(excellent.serialize()))
	studio.canvas.fit_parts()
	studio._start_inspection()
	await _inspection(studio)
	assert(studio.state.evaluate(studio._last_report).can_submit)
	assert(studio.state.evaluate(studio._last_report).award.tier == 5)
	studio._submit()
	await _shot("hall-award")
	var bytes: PackedByteArray = await Exporter.export_png(self, studio.state.document, studio.state.last_result.award)
	var pixels: Image = Image.new()
	assert(pixels.load_png_from_buffer(bytes) == OK)
	assert(pixels.get_size() == Vector2i(1200, 800))
	pixels.save_png("res://.godot/previews/construction-game/house-badge-5.png")
	var plain: PackedByteArray = await Exporter.export_png(self, studio.state.document)
	var plain_pixels: Image = Image.new()
	assert(plain_pixels.load_png_from_buffer(plain) == OK)
	assert(pixels.get_pixel(90, 90) != plain_pixels.get_pixel(90, 90))
	plain_pixels.save_png("res://.godot/previews/construction-game/house-no-badge.png")
	studio._show_hall()
	await _shot("hall-gallery")
	studio._close_modal()
	studio._show_stages()
	await _shot("stages-unlocked")
	print("Construction game UI, funded progression, real tier-five physics and top-left PNG badge verified.")
	studio.free()
	quit()

func _pay_example(state: State) -> void:
	assert(state.accept_contract())
	assert(state.document.replace_parts(Guide.example_for_contract(state.current_contract())))
	assert(not state.settle(_report(state)).is_empty())

func _report(state: State) -> Dictionary:
	var ids: Array[int] = []
	for part: Dictionary in state.document.parts: ids.append(int(part.id))
	return {"stable": true, "stable_ids": ids, "unsupported_ids": [], "revision": state.document.revision}

func _inspection(studio: Studio) -> void:
	for index: int in range(250):
		if not studio.canvas.inspection_running: return
		await physics_frame

func _resize(dimensions: Vector2i) -> void:
	root.size = dimensions
	root.content_scale_size = dimensions

func _shot(name: String) -> void:
	for index: int in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/previews/construction-game/" + name + ".png")
