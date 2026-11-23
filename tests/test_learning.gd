class_name TestLearning
extends RefCounted

const Catalog = preload("res://scripts/learning/learning_catalog.gd")
const Progress = preload("res://scripts/learning/learning_progress.gd")
const Canvas = preload("res://scenes/learning/learning_canvas.gd")
const Studio = preload("res://scenes/learning/learning_studio.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const Bank = preload("res://scripts/learning/learning_question_bank.gd")
const StartupSet = preload("res://scripts/learning/startup_question_set.gd")
const DailyCompletion = preload("res://scripts/learning/startup_daily_completion.gd")
const Gate = preload("res://scenes/learning/learning_gate.gd")
const AppScene: PackedScene = preload("res://scenes/main/main.tscn")

static func run(t: Node) -> void:
	_test_examples_and_measurements(t)
	await _test_manual_measurement(t)
	await _test_measurement_endpoint_snap(t)
	_test_progress_files(t)
	await _test_activity_flow(t)
	_test_startup_question_bank(t)
	_test_startup_variety(t)
	await _test_startup_response_controls(t)
	_test_daily_completion_storage(t)
	await _test_startup_learning_gate(t)
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
	var directions: String = canvas.measurement_text()
	t.assert_false(directions.contains("4 cm") or directions.contains("5 cm"), "The ruler leaves both lengths for the learner to read")
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
	canvas.measure()
	t.assert_false(canvas.measurement_text().contains("6 cm"), "Opening the quest's measurement tool does not reveal its answer")
	for id: String in ["parallelogram_bridge", "citadel_banners"]:
		canvas.configure_question(id)
		var angle: float = 65.0 if id == "parallelogram_bridge" else 70.0
		t.assert_float_approx(Math.angles(canvas.question_vertices())[0], angle, 0.001, "The original angle question agrees with actual vertices")
	t.assert_eq(Math.measurement_label(4.0), "4", "Whole lengths are displayed exactly")
	t.assert_eq(Math.measurement_label(4.123), "약 4.1", "Rounded lengths explicitly state approximation")
	canvas.free()

static func _test_manual_measurement(t: Node) -> void:
	var canvas: Canvas = Canvas.new()
	t.add_child(canvas)
	await t.get_tree().process_frame
	canvas.size = Vector2(640, 340)
	var line_question: Dictionary = Bank.question("distance", 12)
	canvas.configure_activity(line_question)
	canvas.measure()
	t.assert_eq(canvas.measure_tools.tool_kind, "ruler", "The measurement action opens the ruler for a distance problem")
	t.assert_float_approx(canvas.measure_tools.pixels_per_cm, 20.0 * canvas._model_scale(), 0.001, "Ruler marks and rotated lines share the same scale")
	var start: Vector2 = canvas.measure_tools.tool_origin
	var value_before: float = canvas.value
	var drag_start: Vector2 = start + Vector2(25, 14).rotated(canvas.measure_tools.tool_angle)
	_drag_tool(canvas, drag_start, drag_start + Vector2(36, 18))
	t.assert_gt(canvas.measure_tools.tool_origin.distance_to(start), 20.0, "Dragging on the ruler moves it across the diagram")
	t.assert_eq(canvas.value, value_before, "Grabbing a ruler on the line diagram leaves the geometry alone")
	canvas.select_measure_tool("protractor")
	t.assert_eq(canvas.measure_tools.tool_kind, "protractor", "The alternate measuring tool can be selected on the same diagram")
	var handle: Vector2 = canvas.measure_tools.rotation_handle_position()
	var origin: Vector2 = canvas.measure_tools.tool_origin
	var initial_angle: float = canvas.measure_tools.tool_angle
	_drag_tool(canvas, handle, origin + (handle - origin).rotated(deg_to_rad(30.0)))
	t.assert_float_approx(angle_difference(initial_angle, canvas.measure_tools.tool_angle), deg_to_rad(30.0), 0.015, "Dragging the angle handle rotates the measuring tool independently of the diagram")
	t.assert_eq(canvas.diagram_rotation, line_question.rotation, "Rotating the protractor does not rotate the diagram")
	canvas.close_measure_tools()
	t.assert_true(canvas.measure_tools.tool_kind.is_empty() and canvas.measured, "Closing the tool leaves the completed observation available for checking")
	var rotated_shape: Dictionary = Bank.question("equal_sides", 9)
	canvas.configure_activity(rotated_shape)
	t.assert_false(canvas.measured, "A new question starts with its own observation and measurement state")
	canvas.measure()
	var vertices: PackedVector2Array = rotated_shape.vertices
	for dimensions: Vector2 in [Vector2(440, 265), Vector2(840, 390)]:
		canvas.size = dimensions
		canvas.turn()
		await t.get_tree().process_frame
		var bounds: Rect2 = Math.bounds(Math.rotate_vertices(vertices, canvas.diagram_rotation))
		var diagram_fit: float = minf(400.0 / bounds.size.x, 210.0 / bounds.size.y)
		var rendered_side: float = Math.side_lengths(vertices)[0] * diagram_fit * minf(dimensions.x / 600.0, dimensions.y / 300.0)
		t.assert_float_approx(canvas.measure_tools.pixels_per_cm * 7.0, rendered_side, 0.01, "Seven ruler centimeters cover one visible side after rotating and resizing the rhombus")
	var shape_directions: String = canvas.measurement_text()
	t.assert_false(shape_directions.contains("7 cm") or shape_directions.contains("28 cm"), "Measuring a rhombus leaves its side length and perimeter for the learner")
	canvas.free()

static func _test_measurement_endpoint_snap(t: Node) -> void:
	var canvas: Canvas = Canvas.new()
	t.add_child(canvas)
	await t.get_tree().process_frame
	canvas.size = Vector2(720, 400)
	var distance_question: Dictionary = Bank.question("distance", 0)
	canvas.configure_activity(distance_question)
	canvas.set_value(-30.0)
	canvas.select_measure_tool("ruler")
	canvas.measure_tools.rotate_by(25.0)
	var ruler_angle: float = canvas.measure_tools.tool_angle
	var segment_end: Vector2 = Vector2(300 + canvas.value, 150 + float(distance_question.gap) * 0.5)
	var line_end: Vector2 = _measurement_canvas_point(canvas, canvas._diagram_point(segment_end))
	var radius: float = Canvas.MeasureTools.ORIGIN_SNAP_RADIUS
	var during_drag: Vector2 = _drag_measurement_origin(canvas, line_end + Vector2(radius - 1.0, 0), Vector2(25, 14))
	t.assert_true(during_drag.is_equal_approx(line_end), "The ruler shows the snap while the pointer is still dragging")
	t.assert_true(canvas.measure_tools.tool_origin.is_equal_approx(line_end), "The zero mark snaps to a nearby endpoint of a rotated line")
	t.assert_float_approx(canvas.measure_tools.tool_angle, ruler_angle, 0.001, "Snapping the ruler's zero does not turn the ruler")
	var away: Vector2 = line_end + Vector2(radius + 1.0, 0)
	_drag_measurement_origin(canvas, away, Vector2(25, 14))
	t.assert_true(canvas.measure_tools.tool_origin.is_equal_approx(away), "Dragging beyond the snap distance leaves the ruler at its free position")
	var nudge: InputEventKey = InputEventKey.new()
	nudge.pressed = true
	nudge.keycode = KEY_LEFT
	canvas._gui_input(nudge)
	t.assert_true(canvas.measure_tools.tool_origin.is_equal_approx(line_end), "A keyboard nudge into the snap distance also attaches the ruler")
	nudge.keycode = KEY_RIGHT
	for _step: int in range(5): canvas._gui_input(nudge)
	t.assert_gt(canvas.measure_tools.tool_origin.x, line_end.x + radius, "Repeated arrow keys move the ruler away from its snapped endpoint")

	canvas.configure_activity(Bank.question("lines", 0))
	canvas.select_measure_tool("protractor")
	var intersection: Vector2 = canvas.size * 0.5
	_drag_measurement_origin(canvas, intersection + Vector2(5, 3), Vector2(12, -28))
	t.assert_true(canvas.measure_tools.tool_origin.is_equal_approx(intersection), "A visible intersection is a snap point for the protractor's center")

	var rhombus: Dictionary = Bank.question("equal_sides", 9)
	canvas.configure_activity(rhombus)
	canvas.size = Vector2(440, 265)
	await t.get_tree().process_frame
	canvas.select_measure_tool("protractor")
	canvas.measure_tools.rotate_by(15.0)
	var protractor_angle: float = canvas.measure_tools.tool_angle
	var attached: bool = false
	for dimensions: Vector2 in [Vector2(440, 265), Vector2(840, 390)]:
		canvas.size = dimensions
		canvas.turn()
		await t.get_tree().process_frame
		var rotated: PackedVector2Array = Math.rotate_vertices(rhombus.vertices, canvas.diagram_rotation)
		var bounds: Rect2 = Math.bounds(rotated)
		var vertex: Vector2 = _measurement_canvas_point(canvas, Vector2(300, 150) + (rotated[1] - bounds.get_center()) * canvas._single_figure_fit(bounds))
		if not attached:
			_drag_measurement_origin(canvas, vertex + Vector2(-4, 6), Vector2(12, -28))
			attached = true
		t.assert_true(canvas.measure_tools.tool_origin.is_equal_approx(vertex), "The protractor center snaps to the visible vertex of a rotated, resized rhombus")
		t.assert_float_approx(canvas.measure_tools.tool_angle, protractor_angle, 0.001, "A snapped center leaves the protractor's baseline at its previous angle")

	var selection: Dictionary = Bank.question("right_angles", 0)
	selection.figures[2] = Math.create_vertices("square", Vector2(28.0, 28.0))
	canvas.configure_activity(selection)
	canvas.toggle_choice(2)
	canvas.turn()
	canvas.select_measure_tool("ruler")
	var chosen_vertices: PackedVector2Array = selection.figures[2]
	var chosen_center: Vector2 = canvas._card(2).get_center() - Vector2(0, 8)
	var chosen_point: Vector2 = chosen_vertices[1].rotated(deg_to_rad(canvas.diagram_rotation))
	var chosen_vertex: Vector2 = _measurement_canvas_point(canvas, chosen_center + chosen_point * Canvas.CARD_FIGURE_SCALE)
	var adjacent_point: Vector2 = chosen_vertices[0].rotated(deg_to_rad(canvas.diagram_rotation))
	var adjacent_vertex: Vector2 = _measurement_canvas_point(canvas, chosen_center + adjacent_point * Canvas.CARD_FIGURE_SCALE)
	var between_vertices: Vector2 = chosen_vertex.lerp(adjacent_vertex, 0.45)
	t.assert_lt(between_vertices.distance_to(adjacent_vertex), radius, "Both close corners are within the snap radius")
	_drag_measurement_origin(canvas, between_vertices, Vector2(25, 14))
	t.assert_true(canvas.measure_tools.tool_origin.is_equal_approx(chosen_vertex), "The ruler snaps to the closer of two visible corners in a selection card")
	t.assert_eq(canvas.selected_choices, [2], "Moving the ruler preserves the student's selected card")
	var card_corner: Vector2 = _measurement_canvas_point(canvas, canvas._card(2).position) + Vector2(5, 5)
	_drag_measurement_origin(canvas, card_corner, Vector2(25, 14))
	t.assert_true(canvas.measure_tools.tool_origin.is_equal_approx(card_corner), "A measurement tool moves freely beside the card frame")
	canvas.free()

static func _measurement_canvas_point(canvas: Canvas, point: Vector2) -> Vector2:
	return canvas.size * 0.5 + (point - Vector2(300, 150)) * canvas._model_scale()

static func _drag_measurement_origin(canvas: Canvas, target_origin: Vector2, body_offset: Vector2) -> Vector2:
	var offset: Vector2 = body_offset.rotated(canvas.measure_tools.tool_angle)
	return _drag_tool(canvas, canvas.measure_tools.tool_origin + offset, target_origin + offset)

static func _drag_tool(canvas: Canvas, start: Vector2, end: Vector2) -> Vector2:
	var pointer: InputEventMouseButton = InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.position = start
	pointer.pressed = true
	canvas._gui_input(pointer)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = end
	motion.relative = end - start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	canvas._gui_input(motion)
	var moved_origin: Vector2 = canvas.measure_tools.tool_origin
	pointer.position = end
	pointer.pressed = false
	canvas._gui_input(pointer)
	return moved_origin

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

static func _test_startup_question_bank(t: Node) -> void:
	var ids: Dictionary = {}
	var drawing_kinds: Dictionary = {}
	var blank_grids: int = 0
	var partial_grids: int = 0
	for type_id: String in Bank.TYPES:
		var modes: Dictionary = {}
		for index: int in range(Bank.PER_TYPE):
			var question: Dictionary = Bank.question(type_id, index)
			modes[question.mode] = true
			t.assert_false(ids.has(question.id), "Every gate variant has a unique question ID")
			ids[question.id] = true
			t.assert_eq(question.type_id, type_id, "Every bank item belongs to its requested type")
			t.assert_true(Bank.next_index(index) != index, "A retry changes the current variant")
			if question.mode == "draw":
				drawing_kinds[question.lesson_id] = true
				var vertices: PackedVector2Array = PackedVector2Array()
				for point: Vector2i in question.draw_solution:
					t.assert_true(point.x >= 0 and point.x <= question.grid_size.x and point.y >= 0 and point.y <= question.grid_size.y, "All example vertices fit on the printed grid")
					vertices.append(Vector2(point))
				t.assert_true(Math.is_valid(vertices) and Math.matches_kind(vertices, str(question.lesson_id)), "Every grid challenge has a valid completion")
				for given_index: int in range(question.given.size()):
					t.assert_eq(question.given[given_index], question.draw_solution[given_index], "The fixed segments are part of a valid completion")
				if question.given.is_empty(): blank_grids += 1
				else: partial_grids += 1
			elif question.mode == "select":
				var expected: Array[int] = []
				for slot: int in range(question.figures.size()):
					if Math.matches_kind(question.figures[slot], str(question.lesson_id)): expected.append(slot)
				t.assert_eq(question.correct_choices, expected, "Correct figure choices follow their geometric properties")
				t.assert_true(not expected.is_empty() and expected.size() < question.figures.size(), "Each figure set has examples and nonexamples")
			elif question.mode == "measure":
				t.assert_true(question.answer_index >= 0 and question.answer_index < question.choices.size(), "Measurement questions have a selectable answer")
				var centimeters: float
				if question.lesson_id == "distance":
					centimeters = float(question.gap) / 20.0
				else:
					var perimeter: bool = str(question.prompt).contains("네 변")
					centimeters = Math.side_lengths(question.vertices)[0] * (4.0 if perimeter else 1.0) / 20.0
				t.assert_eq(question.choices[int(question.answer_index)], "%d cm" % roundi(centimeters), "The answer agrees with the distance or side the learner can measure in the diagram")
			elif question.mode == "choice":
				t.assert_true(question.choices.size() >= 3 and question.answer_index >= 0 and question.answer_index < question.choices.size(), "Each concept question offers a valid answer and distractors")
			elif question.mode == "short":
				t.assert_true(not question.accepted_answers.is_empty(), "Every short question accepts an answer")
				for answer: String in question.accepted_answers:
					t.assert_true(Bank.short_answer_correct(question, " " + answer + " "), "Short answers accept surrounding whitespace")
				t.assert_false(Bank.short_answer_correct(question, ""), "An empty short answer cannot be correct")
				t.assert_false(Bank.short_answer_correct(question, "모르겠어요"), "Unrelated text cannot match a short answer")
			elif question.mode in ["order", "match"]:
				var matching: bool = question.mode == "match"
				var mapping: Array = question.answer_pairs if matching else question.answer_order
				var labels: Array = question.right_items if matching else question.choices
				t.assert_eq(mapping.size(), labels.size(), "Every visible card appears in the solution")
				if matching:
					t.assert_eq(question.left_items.size(), labels.size(), "Matching has the same number of cards on each side")
				for card: int in range(labels.size()):
					t.assert_true(mapping.count(card) == 1, "A complete solution uses each card exactly once")
					t.assert_true(labels.count(labels[card]) == 1, "Cards have distinguishable labels")
		for required: String in ["choice", "short", "order", "match"]:
			t.assert_true(modes.has(required), "Each curriculum topic offers " + required)
	t.assert_eq(Bank.TYPES.size(), 5, "A launch covers five distinct curriculum types")
	t.assert_eq(ids.size(), 200, "The expanded bank has 200 unique launch questions")
	t.assert_eq(drawing_kinds.size(), 5, "Grid construction covers all five quadrilateral families")
	t.assert_true(blank_grids > 0 and partial_grids > 0, "Grid construction includes blank diagrams and given segments")

static func _test_startup_variety(t: Node) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var observed_modes: Dictionary = {}
	for seed_value: int in range(48):
		rng.seed = seed_value
		var picks: Array[int] = StartupSet.pick(rng)
		t.assert_eq(picks.size(), Bank.TYPES.size(), "A launch chooses one question per topic")
		var modes: Array[String] = []
		for slot: int in range(picks.size()):
			var question: Dictionary = Bank.question(Bank.TYPES[slot], picks[slot])
			t.assert_false(question.is_empty(), "Every planned question exists")
			if question.is_empty(): return
			var mode: String = str(question.mode)
			t.assert_false(modes.has(mode), "Each of the five opening problems has a different interaction")
			modes.append(mode)
			observed_modes[mode] = true
		t.assert_true(modes.has("short") and modes.has("choice"), "Each launch includes writing an answer and choosing one")
		t.assert_true(modes.has("draw") or modes.has("line"), "Each launch asks the learner to manipulate geometry")
		t.assert_true(modes.has("order") or modes.has("match"), "Each launch includes arranging or pairing cards")
	for mode: String in ["line", "select", "draw", "measure", "choice", "short", "order", "match"]:
		t.assert_true(observed_modes.has(mode), "Repeat launches can reach format " + mode)

static func _fill_card_response(gate: Gate, question: Dictionary, correct: bool) -> void:
	match str(question.mode):
		"choice":
			var option: int = int(question.answer_index)
			if not correct: option = (option + 1) % question.choices.size()
			gate._response.option_buttons[option].pressed.emit()
		"short":
			gate._response.short_input.text = str(question.accepted_answers[0]) if correct else "모르겠어요"
		"order":
			var order: Array = question.answer_order.duplicate()
			if not correct: order.reverse()
			for index: int in order: gate._response.option_buttons[index].pressed.emit()
		"match":
			for row: int in range(question.answer_pairs.size()):
				var right: int = int(question.answer_pairs[row])
				if not correct: right = (right + 1) % question.right_items.size()
				gate._response.left_buttons[row].pressed.emit()
				gate._response.right_buttons[right].pressed.emit()

static func _test_startup_response_controls(t: Node) -> void:
	var gate: Gate = Gate.new()
	t.add_child(gate)
	await t.get_tree().process_frame
	var results: Array[bool] = []
	gate.answer_submitted.connect(func(correct: bool) -> void: results.append(correct))
	for index: int in range(20, 24):
		var question: Dictionary = Bank.question("lines", index)
		gate.present(question, 1, 5)
		t.assert_false(gate.canvas.is_visible_in_tree() or gate.grid_canvas.is_visible_in_tree(), "Response cards do not show an unrelated diagram")
		gate._check.pressed.emit()
		t.assert_true(results.is_empty() and gate._feedback.visible, "Incomplete input shows guidance and costs no attempt")
		_fill_card_response(gate, question, false)
		gate._check.pressed.emit()
		t.assert_eq(results, [false], "A fully answered but incorrect response emits one failed attempt")
		gate.present(question, 1, 5)
		gate._check.pressed.emit()
		t.assert_eq(results, [false], "A retry clears old input")
		if question.mode == "order":
			gate._response.option_buttons[0].pressed.emit()
			gate._response.option_buttons[0].pressed.emit()
			t.assert_false(gate._response.option_buttons[0].button_pressed, "An order card can be removed before submission")
		if question.mode == "match":
			for row: int in [0, 1]:
				gate._response.left_buttons[row].pressed.emit()
				gate._response.right_buttons[0].pressed.emit()
			gate._check.pressed.emit()
			t.assert_eq(results, [false], "Reusing a match card leaves the previous row incomplete")
		_fill_card_response(gate, question, true)
		if question.mode == "short":
			gate._response.short_input.text_submitted.emit(gate._response.short_input.text)
		else:
			gate._check.pressed.emit()
		gate._check.pressed.emit()
		t.assert_eq(results, [false, true], "Correct input succeeds once without the ruler")
		results.clear()
	gate.free()

static func _test_daily_completion_storage(t: Node) -> void:
	var path: String = "user://test_gate_date_%d.txt" % Time.get_ticks_usec()
	var before_midnight: int = Time.get_unix_time_from_datetime_string("2026-11-23T14:59:59")
	var midnight: int = before_midnight + 1
	t.assert_eq(DailyCompletion.korean_date(before_midnight), "2026-11-23", "23:59:59 in Korea still belongs to the current school day")
	t.assert_eq(DailyCompletion.korean_date(midnight), "2026-11-24", "The daily gate resets at midnight in Korea")
	t.assert_false(DailyCompletion.completed_today(path, before_midnight), "A new browser profile has no completion date")
	t.assert_true(DailyCompletion.mark_completed(path, before_midnight), "Completing a day saves its date")
	t.assert_true(DailyCompletion.completed_today(path, before_midnight), "Completion reloads before midnight")
	t.assert_false(DailyCompletion.completed_today(path, midnight), "Yesterday's entry cannot unlock the next day")
	t.assert_true(DailyCompletion.mark_completed(path, midnight), "The next day's completion replaces the previous record")
	t.assert_true(DailyCompletion.completed_today(path, midnight), "The replaced record survives a new read")
	t.assert_false(DailyCompletion.completed_today(path, before_midnight), "A future date does not skip an earlier day")
	var corrupt: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("2026-11-24other")
		corrupt.close()
	t.assert_not_null(corrupt, "The corrupt completion fixture was created")
	t.assert_false(DailyCompletion.completed_today(path, midnight), "A corrupt completion record fails closed")
	var impossible: String = path + "/unwritable.txt"
	t.assert_false(DailyCompletion.mark_completed(impossible, midnight), "A failed disk write is reported")
	t.assert_false(DailyCompletion.completed_today(impossible, midnight), "Failure cannot manufacture a completed day")
	DirAccess.remove_absolute(path)

static func _launch_gate_app(t: Node, path: String) -> QuadrilateralApp:
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	app.show_startup_learning_for_testing = true
	app.startup_completion_path = path
	t.add_child(app)
	await t.get_tree().process_frame
	return app

static func _test_startup_learning_gate(t: Node) -> void:
	var path: String = "user://test_gate_session_%d.txt" % Time.get_ticks_usec()
	var partial: QuadrilateralApp = await _launch_gate_app(t, path)
	var partial_gate: Gate = partial._startup_learning
	t.assert_not_null(partial_gate, "First visit opens the math gate")
	if partial_gate == null:
		partial.free()
		return
	partial._startup_variants[0] = 20
	partial._present_startup_question()
	_fill_card_response(partial_gate, partial_gate.question, true)
	partial_gate._check.pressed.emit()
	t.assert_eq(partial._startup_type_index, 1, "Answering one problem advances the current visit")
	t.assert_false(DailyCompletion.completed_today(path), "Partial progress cannot exempt a future visit")
	partial.free()
	var app: QuadrilateralApp = await _launch_gate_app(t, path)
	t.assert_eq(app._startup_type_index, 0, "Reloading before all five answers starts a fresh quiz")
	var gate: Gate = app._startup_learning
	t.assert_not_null(gate, "The launch opens the required math dialog")
	if gate == null:
		app.free()
		return
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	app._input(escape)
	app._home_screen.drawing_requested.emit()
	app._home_screen.construction_requested.emit()
	app._home_screen.wall_requested.emit()
	app._home_screen.adventure_requested.emit()
	app._home_screen.notebook_requested.emit()
	app._show_home()
	t.assert_true(gate.is_visible_in_tree() and not app._home_screen.visible, "Escape and mode navigation cannot close the launch dialog")
	t.assert_false(is_instance_valid(app.wall_studio), "The wall workshop cannot bypass the opening learning gate")
	t.assert_true(not app._drawing_screen.visible and not app._construction_screen.visible and app.world == null, "Gameplay stays hidden before all answers are correct")
	# Pin the diagram used for this retry so all starting formats can be sampled at launch.
	app._startup_variants[0] = 0
	app._present_startup_question()
	var starting: Dictionary = gate.question
	gate._check.pressed.emit()
	t.assert_eq(gate.question.id, starting.id, "Incomplete input prompts observation without using a retry")
	gate.canvas.set_value(45.0)
	gate._measure.pressed.emit()
	gate._check.pressed.emit()
	t.assert_eq(gate.question.type_id, starting.type_id, "A wrong answer stays in the same curriculum type")
	t.assert_true(gate.question.id != starting.id, "A wrong answer shows a different problem")
	t.assert_eq(app._startup_type_index, 0, "An incorrect answer cannot advance the launch progress")
	# Cover all interaction modes without relying on the random choices made at launch.
	app._startup_variants[1] = 12
	app._startup_variants[2] = 0
	app._startup_variants[3] = 12
	app._startup_variants[4] = 13
	for step: int in range(Bank.TYPES.size()):
		t.assert_eq(gate.question.type_id, Bank.TYPES[step], "A correct answer advances to the next distinct curriculum type")
		t.assert_true(gate.visible and not app._home_screen.visible, "The home screen stays locked while any type remains")
		var question: Dictionary = gate.question
		if question.mode != "draw":
			gate._measure.pressed.emit()
			t.assert_true(gate.canvas.measure_tools.tool_kind in ["ruler", "protractor"], "Every applicable startup problem has manual measuring tools")
			t.assert_true(gate._measure_buttons[1].visible and gate._measure_buttons[2].visible, "The measuring toolbar lets the learner switch between both tools")
			if question.mode == "measure":
				var correct_text: String = str(question.choices[question.answer_index])
				t.assert_false(gate._metrics.text.contains(correct_text), "The measurement panel does not disclose the selected numeric answer")
		match str(question.mode):
			"line": gate.canvas.set_value(90.0 if question.lesson_id == "perpendicular" else 0.0)
			"measure": gate._choice_buttons[int(question.answer_index)].pressed.emit()
			"select":
				for option: int in question.correct_choices: gate.canvas.toggle_choice(option)
			"draw":
				for point_index: int in range(question.given.size(), question.draw_solution.size()):
					gate.grid_canvas.place_vertex(question.draw_solution[point_index])
		if question.mode != "draw":
			gate._measure_buttons[3].pressed.emit()
			t.assert_true(gate.canvas.measure_tools.tool_kind.is_empty(), "The learner can put away the tool before checking")
		gate._check.pressed.emit()
	await t.get_tree().process_frame
	t.assert_true(app._startup_learning == null and app._home_screen.visible, "The fifth correct type opens the game")
	t.assert_true(app._home_screen._drawing_button.has_focus(), "Keyboard focus returns to the first game activity")
	app._home_screen.drawing_requested.emit()
	t.assert_true(app._drawing_screen.visible, "A player can enter drawing after solving the launch tasks")
	app._show_home()
	t.assert_true(app._startup_learning == null, "Returning to the menu does not start another attempt")
	app.free()
	t.assert_true(DailyCompletion.completed_today(path), "Only finishing all five topics records today's completion")
	var revisit: QuadrilateralApp = await _launch_gate_app(t, path)
	t.assert_true(revisit._startup_learning == null and revisit._home_screen.visible, "A fresh app instance skips the questions on the same Korean day")
	revisit._home_screen.drawing_requested.emit()
	t.assert_true(revisit._drawing_screen.visible, "A same-day return can enter drawing immediately")
	revisit.free()
	var yesterday: int = int(Time.get_unix_time_from_system()) - 86400
	t.assert_true(DailyCompletion.mark_completed(path, yesterday), "The next launch sees a previous-day record")
	var next_session: QuadrilateralApp = await _launch_gate_app(t, path)
	t.assert_true(is_instance_valid(next_session._startup_learning) and next_session._startup_type_index == 0, "A previous day's completion requires a new five-topic session")
	var next_gate: Gate = next_session._startup_learning
	if next_gate == null:
		next_session.free()
		DirAccess.remove_absolute(path)
		return
	_finish_mixed_session(t, next_gate)
	t.assert_true(next_session._startup_learning == null and next_session._home_screen.visible, "Solving a naturally generated mixed session unlocks the game")
	next_session.free()
	var failed_path: String = path + "/unsaved.txt"
	var unsaved: QuadrilateralApp = await _launch_gate_app(t, failed_path)
	if is_instance_valid(unsaved._startup_learning):
		_finish_mixed_session(t, unsaved._startup_learning)
	t.assert_true(unsaved._startup_learning == null and unsaved._home_screen.visible, "A storage failure still lets the player enter after solving today's problems")
	unsaved.free()
	var unsaved_reload: QuadrilateralApp = await _launch_gate_app(t, failed_path)
	t.assert_not_null(unsaved_reload._startup_learning, "An unpersisted completion cannot bypass questions on another launch")
	unsaved_reload.free()
	DirAccess.remove_absolute(path)
	await t.get_tree().process_frame

static func _finish_mixed_session(t: Node, next_gate: Gate) -> void:
	var session_modes: Array[String] = []
	for step: int in range(Bank.TYPES.size()):
		var question: Dictionary = next_gate.question
		var mode: String = str(question.mode)
		t.assert_eq(question.type_id, Bank.TYPES[step], "The normal launch visits every curriculum topic")
		t.assert_false(session_modes.has(mode), "The normal entry point presents five distinct formats")
		session_modes.append(mode)
		match mode:
			"line":
				next_gate._measure.pressed.emit()
				next_gate.canvas.set_value(90.0 if question.lesson_id == "perpendicular" else 0.0)
			"measure":
				next_gate._measure.pressed.emit()
				next_gate._choice_buttons[int(question.answer_index)].pressed.emit()
			"select":
				next_gate._measure.pressed.emit()
				for choice: int in question.correct_choices: next_gate.canvas.toggle_choice(choice)
			"draw":
				for vertex: int in range(question.given.size(), question.draw_solution.size()):
					next_gate.grid_canvas.place_vertex(question.draw_solution[vertex])
			_: _fill_card_response(next_gate, question, true)
		next_gate._check.pressed.emit()

static func _test_touch_and_peaceful(t: Node) -> void:
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	app._sound.sound_enabled = false
	t.assert_true(app._home_screen._drawing_button.has_focus(), "Home seeds keyboard focus on its drawing action")
	app.learning_progress.touch_controls = true
	app.learning_progress.peaceful = true
	app._learning_changed()
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
