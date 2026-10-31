class_name TestLearning
extends RefCounted

const Catalog = preload("res://scripts/learning/learning_catalog.gd")
const Progress = preload("res://scripts/learning/learning_progress.gd")
const Canvas = preload("res://scenes/learning/learning_canvas.gd")
const Studio = preload("res://scenes/learning/learning_studio.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const AppScene: PackedScene = preload("res://scenes/main/main.tscn")

static func run(t: Node) -> void:
	_test_examples_and_measurements(t)
	_test_progress_files(t)
	await _test_activity_flow(t)
	await _test_touch_and_peaceful(t)

static func _test_examples_and_measurements(t: Node) -> void:
	for codepoint: int in [43, 45, 9679, 8592, 8594, 12593, 12596, 12599, 12601, 176]:
		t.assert_true(QuadTheme.FONT.has_char(codepoint), "Every practice annotation and selection mark has a shipped web-font glyph")
	var expected: Dictionary = {"trapezoid": [0, 2, 3], "parallelogram": [0, 2], "rhombus": [0, 1], "rectangle": [0, 2], "square": [0, 1]}
	for id: String in expected:
		t.assert_eq(Catalog.correct_choices(id), expected[id], "Original examples and nonexamples apply the inclusive definition of " + id)
		for vertices: PackedVector2Array in Catalog.figures(id):
			t.assert_true(Math.is_valid(vertices), "Learning examples remain valid convex quadrilaterals")
			for turn: float in [30.0, 90.0, 210.0]:
				t.assert_eq(Math.classifications(Math.rotate_vertices(vertices, turn)), Math.classifications(vertices), "Turning a learning example preserves its properties")
	var canvas: Canvas = Canvas.new()
	canvas.configure("perpendicular")
	canvas.set_value(90)
	t.assert_false(canvas.construction_correct(), "Setting a target without observing measurements cannot complete practice")
	canvas.measure()
	t.assert_true(canvas.construction_correct(), "Right-angle measurement confirms perpendicularity")
	canvas.turn()
	t.assert_true(canvas.construction_correct(), "Perpendicular lines need not be horizontal and vertical")
	canvas.configure("parallel")
	canvas.measure()
	t.assert_false(canvas.construction_correct(), "Separated visible segments are not enough to prove parallelism")
	canvas.set_value(180)
	t.assert_true(canvas.construction_correct(), "Reversed direction still represents parallel lines")
	canvas.configure("distance")
	canvas.measure()
	t.assert_true(canvas.measurement_text().contains("5칸"), "The original oblique 3-4-5 example has the measured five-unit length")
	t.assert_false(canvas.construction_correct(), "An oblique segment does not measure the distance")
	canvas.set_value(0)
	t.assert_true(canvas.construction_correct(), "A perpendicular segment measures the four-unit distance")
	for quest: Dictionary in QuestCatalog.all_quests():
		canvas.configure_question(str(quest.id))
		if canvas.is_line_activity(): continue
		t.assert_true(Math.matches_kind(canvas.question_vertices(), str(quest.topic)), "Each quest illustration derives its actual mathematical shape")
	canvas.configure_question("snow_lanterns")
	for length: float in Math.side_lengths(canvas.question_vertices()):
		t.assert_float_approx(length / 20.0, 6.0, 0.001, "The lantern illustration matches the six-unit side in its question")
	for id: String in ["parallelogram_bridge", "citadel_banners"]:
		canvas.configure_question(id)
		var angle: float = 65.0 if id == "parallelogram_bridge" else 70.0
		t.assert_float_approx(Math.angles(canvas.question_vertices())[0], angle, 0.001, "The original angle question agrees with actual vertices")
	t.assert_eq(Math.measurement_label(4.0), "4", "Whole lengths are displayed exactly")
	t.assert_eq(Math.measurement_label(4.123), "약 4.1", "Rounded lengths explicitly state approximation")
	canvas.free()

static func _test_progress_files(t: Node) -> void:
	var progress: Progress = Progress.new()
	progress.record_attempt("square", false)
	t.assert_true(progress.completed.is_empty(), "An incorrect attempt never marks an activity complete")
	progress.record_attempt("square", true)
	progress.peaceful = true
	progress.touch_controls = true
	var path: String = "res://.godot/learning_test_%d.json" % Time.get_ticks_usec()
	t.assert_eq(progress.save_file(path), OK, "Anonymous learning progress saves")
	progress.record_attempt("perpendicular", true)
	t.assert_eq(progress.save_file(path), OK, "Replacing an existing learning save succeeds on Windows")
	var loaded: Progress = Progress.new()
	t.assert_true(loaded.load_file(path), "Learning history restores from JSON")
	t.assert_eq(loaded.serialize(), progress.serialize(), "Activity history and accessibility preferences round trip exactly")
	var before: Dictionary = loaded.serialize()
	for invalid: Dictionary in [{"version": {}, "completed": {}, "attempts": {}}, {"version": 1, "completed": {"square": true}, "attempts": {}}, {"version": 1, "completed": {}, "attempts": {"square": -1}}, {"version": 1, "completed": {}, "attempts": {"unknown": 2}}, {"version": 1, "completed": {}, "attempts": {}, "peaceful": 1}]:
		t.assert_false(loaded.restore(invalid), "Malformed learning data is rejected")
		t.assert_eq(loaded.serialize(), before, "Invalid history cannot partially replace current progress")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	t.assert_false(loaded.load_file(path), "A corrupt progress file is ignored")
	t.assert_eq(loaded.serialize(), before, "Corrupt files preserve live activity history")
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)

static func _test_activity_flow(t: Node) -> void:
	var studio: Studio = Studio.new()
	t.add_child(studio)
	await t.get_tree().process_frame
	studio.canvas.turn()
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = studio.canvas.size * 0.5 + Vector2(0, 100).rotated(deg_to_rad(30.0)) * studio.canvas._model_scale()
	studio.canvas._gui_input(press)
	t.assert_float_approx(studio.canvas.value, 90.0, 0.001, "Dragging the rotated diagram maps pointer coordinates back to the mathematical angle")
	press.pressed = false
	studio.canvas._gui_input(press)
	for id: String in Catalog.IDS:
		studio.open_lesson(id)
		studio.check_activity()
		t.assert_false(studio.progress.completed.has(id), "Every activity requires observing and explaining")
		studio.canvas.measure()
		if studio.canvas.is_line_activity(): studio.canvas.set_value(90 if id == "perpendicular" else 0)
		else:
			for index: int in Catalog.correct_choices(id): studio.canvas.toggle_choice(index)
		studio.check_activity()
		t.assert_eq(studio.phase, 1, "Correct manipulation opens the reason step")
		studio.answer_reason(1)
		t.assert_false(studio.progress.completed.has(id), "Incorrect reasoning cannot complete an activity")
		studio.answer_reason(0)
		t.assert_true(studio.progress.completed.has(id), "Both observation and a reason produce an activity record")
		t.assert_eq(studio.phase, 2, "Completion exposes the next activity")
	t.assert_eq(studio.progress.completed.size(), 8, "All eight grade-level topics are reachable without game gates")
	studio.free()

static func _test_touch_and_peaceful(t: Node) -> void:
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	app._sound.sound_enabled = false
	t.assert_true(app._home_screen._learning_button.has_focus(), "Home seeds keyboard focus on its direct learning action")
	app.learning_progress.touch_controls = true
	app.learning_progress.peaceful = true
	app._learning_changed()
	app.document.fill_example()
	app._enter_world()
	for frame: int in range(8): await t.get_tree().process_frame
	app.world.set_physics_process(false)
	for pair: Array in [[0, "right"], [1, "jump"]]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.index = int(pair[0])
		touch.pressed = true
		var button: Button = app._touch_buttons[str(pair[1])]
		touch.position = button.get_global_transform_with_canvas() * (button.size * 0.5)
		app._input(touch)
	t.assert_true(app.world.player.touch_right and app.world.player.touch_jump, "Two fingers can move and jump simultaneously")
	var start_x: float = app.world.player.position.x
	for frame: int in range(8): await t.get_tree().physics_frame
	t.assert_gt(app.world.player.position.x, start_x, "Screen movement actually advances the player")
	t.assert_lt(app.world.player.velocity.y, 0.0, "A second held finger actually jumps while moving")
	app._show_game_menu()
	t.assert_false(app.world.player.touch_right or app.world.player.touch_jump, "Opening a modal clears held touch controls")
	t.assert_true(app._touch_fingers.is_empty(), "A modal releases every tracked finger")
	app._close_modal()
	app.world.player.position = Vector2(float(app.world.enemies[0].base_x), QuadrilateralWorld.GROUND_Y)
	app.world.player.invulnerability = 0.0
	var hp: int = app.world.player.hp
	app.world._update_enemies(0)
	t.assert_eq(app.world.player.hp, hp, "Peaceful exploration prevents monster contact damage")
	app.learning_progress.peaceful = false
	app._learning_changed()
	app.world._update_enemies(0)
	t.assert_lt(app.world.player.hp, hp, "Normal exploration still applies ordinary contact damage")
	app._show_learning("parallel")
	t.assert_true(app._learning_screen.visible and not app._in_world, "Direct learning remains accessible from an existing adventure")
	app.free()
	await t.get_tree().process_frame
