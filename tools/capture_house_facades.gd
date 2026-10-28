extends SceneTree

## Render six independently simulated test houses without loading or saving
## player progress. Run with a rendering driver, not --headless.
## godot --path . --script res://tools/capture_house_facades.gd

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/previews")
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = root.size
	var board: PanelContainer = PanelContainer.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.add_theme_stylebox_override("panel", ConstructionArt.panel(false, 16))
	root.add_child(board)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	board.add_child(grid)
	var states: Array[ConstructionState] = []
	var canvases: Array[ConstructionCanvas] = []
	var labels: Array[Label] = []
	for index: int in range(6):
		var state: ConstructionState = ConstructionState.new()
		state.contract_index = index
		assert(state.accept_contract())
		assert(state.document.replace_parts(TestConstructionPhysics._complete_facade(index)), state.document.last_error)
		states.append(state)
		var card: VBoxContainer = VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var title: Label = QuadTheme.paragraph("%s · %s" % [state.current_contract().client, state.current_contract().title], 20, ConstructionArt.INK)
		card.add_child(title)
		var canvas: ConstructionCanvas = ConstructionCanvas.new()
		canvas.document = state.document
		canvas.presentation_mode = true
		canvas.show_grid = false
		canvas.editing_enabled = false
		canvas.custom_minimum_size = Vector2(490, 370)
		canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(canvas)
		canvases.append(canvas)
		var label: Label = QuadTheme.paragraph("실제 중력 검사 중", 16, ConstructionArt.MUTED)
		card.add_child(label)
		labels.append(label)
	for frame: int in range(8): await process_frame
	for canvas: ConstructionCanvas in canvases:
		canvas.fit_parts()
		assert(canvas.start_inspection())
	for frame: int in range(260):
		await physics_frame
		var active: bool = false
		for canvas: ConstructionCanvas in canvases:
			if canvas.inspection_running: active = true
		if not active: break
	for index: int in range(6):
		var report: Dictionary = canvases[index]._simulation.report
		var evaluation: Dictionary = states[index].evaluate(report)
		print("FACADE %d: parts=%d stable=%s score=%d submit=%s feedback=%s" % [index + 1, states[index].document.parts.size(), report.get("stable", false), evaluation.score, evaluation.can_submit, evaluation.feedback])
		labels[index].text = "중력 %s · 만족도 %d점 · %s" % ["통과" if bool(report.get("stable", false)) else "실패", evaluation.score, "납품 가능" if bool(evaluation.can_submit) else str(evaluation.feedback)]
		assert(bool(report.get("stable", false)), str(report))
		assert(bool(evaluation.can_submit), str(evaluation))
		assert(int(evaluation.score) == 100, str(evaluation))
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/previews/house-facades-simulated.png")
	board.free()
	quit()
