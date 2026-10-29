extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	_resize(Vector2i(1600, 900))
	var app: QuadrilateralApp = load("res://scenes/main/main.tscn").instantiate()
	app.testing = true
	root.add_child(app)
	DirAccess.make_dir_recursive_absolute("res://.godot/previews")
	await _capture("home-construction")
	app._show_construction()
	await _capture("construction-brief")
	_resize(Vector2i(800, 600))
	await _capture("construction-brief-resized")
	_resize(Vector2i(1600, 900))
	var studio: ConstructionStudio = app._construction_screen
	studio._accept_contract()
	await _capture("construction-empty")
	_resize(Vector2i(1024, 720))
	await _capture("construction-guide-small")
	_resize(Vector2i(800, 600))
	await _capture("construction-guide-compact")
	_resize(Vector2i(1600, 900))
	studio._build_starter()
	await _capture("construction-starter")
	for x: float in [240.0, 360.0, 480.0, 600.0]:
		assert(studio.state.document.add_part("lintel", Vector2(x, 430)) > 0)
	assert(studio.state.document.add_part("roof_wide", Vector2(420, 370)) > 0)
	studio.canvas.select_tool()
	studio.state.document.select(-1)
	await _capture("construction-built")
	studio._start_inspection()
	await create_timer(3.3).timeout
	await _capture("construction-inspected")
	print("Construction inspected: ", studio._last_report)
	assert(studio.state.evaluate(studio._last_report).can_submit)
	studio._show_report()
	await _capture("construction-review")
	studio._submit()
	assert(studio.state.phase == "settled")
	await _capture("construction-settlement")
	studio._close_modal()
	await _capture("construction-completed")
	_resize(Vector2i(1024, 720))
	await _capture("construction-small")
	studio._next_contract()
	await _capture("construction-next")
	studio._accept_contract()
	studio.state.document.add_part("wall", Vector2(300, 350))
	var repair_window: int = studio.state.document.add_part("window", Vector2(700, 350))
	studio.canvas.fit_parts()
	studio._start_inspection()
	await create_timer(3.3).timeout
	assert(studio._fresh_issues().size() == 2)
	studio._show_repairs()
	await _capture("construction-repair-list-small")
	studio._focus_repair(repair_window)
	await _capture("construction-repair-focus-small")
	_resize(Vector2i(1600, 900))
	studio._show_repairs()
	await _capture("construction-repair-list")
	studio._focus_repair(repair_window)
	await _capture("construction-repair-focus")
	print("Construction previews and first full commission completed.")
	app.free()
	quit()

func _resize(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	root.content_scale_size = viewport_size

func _capture(name: String) -> void:
	for frame: int in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/previews/%s.png" % name)
