class_name TestTutorialIntegration
extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")


static func run(t: Node) -> void:
	var window: Window = t.get_window()
	var previous: Dictionary = {
		"size": window.size, "minimum": window.min_size,
		"scale_size": window.content_scale_size, "mode": window.content_scale_mode,
		"aspect": window.content_scale_aspect, "factor": window.content_scale_factor,
	}
	var persisted: Dictionary = _stored_preferences()
	window.min_size = Vector2i.ZERO
	window.size = Vector2i(1280, 800)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_factor = 1.0
	await _settle(t)
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	app._sound.sound_enabled = false
	await _settle(t)
	t.assert_false(app._tutorial.active, "Testing mode does not launch a first-visit tutorial on the home screen")
	for mode: String in TutorialCatalog.MODE_IDS:
		t.assert_true(app._tutorial.progress.should_offer(mode), "Testing app keeps first-visit preference in memory for " + mode)
	await _drawing(t, app)
	await _color_popup(t, app)
	await _masterpiece(t, app)
	await _learning(t, app)
	await _workshop(t, app)
	await _world(t, app)
	await _construction(t, app)
	await _my_house(t, app)
	await _responsive_overlay(t, app)
	app._show_home()
	t.assert_false(app._tutorial.active, "Returning home cancels an unfinished tour")
	t.assert_false(app._tutorial.overlay.visible, "A cancelled tour leaves no dialogue over the home page")
	t.assert_eq(_stored_preferences(), persisted, "Testing tutorial starts, skips and completions never write real user preferences")
	app.free()
	window.content_scale_size = previous["scale_size"]
	window.content_scale_mode = previous["mode"]
	window.content_scale_aspect = previous["aspect"]
	window.content_scale_factor = float(previous["factor"])
	window.min_size = previous["minimum"]
	window.size = previous["size"]
	await _settle(t)


static func _drawing(t: Node, app: QuadrilateralApp) -> void:
	app._show_drawing()
	t.assert_false(app._tutorial.active, "Opening a studio under testing does not automatically begin its tutorial")
	var doc: DrawingDocument = app._drawing_screen.document
	t.assert_true(app._tutorial.start("drawing"), "Free drawing tutorial can be explicitly started")
	t.assert_true(app._tutorial.blocks_gameplay(), "Welcome dialogue owns input before practice")
	t.assert_true(app._drawing_screen.tutorial_blocked, "Drawing shortcuts are blocked while the guide speaks")
	app._tutorial.advance()
	_assert_event(t, app, "drawing_add", "Drawing welcome advances to actual shape placement")
	t.assert_false(app._drawing_screen.tutorial_blocked, "Shape placement practice restores editing")
	var waiting_index: int = app._tutorial.index
	app._tutorial.advance()
	app._tutorial.notify("world_jump")
	app._drawing_screen.canvas.select_kind("rectangle")
	await _settle(t)
	t.assert_eq(app._tutorial.index, waiting_index, "Next, unrelated events and choosing a tool cannot fake shape placement")
	app._drawing_screen.canvas.add_at_center()
	await _settle(t)
	_assert_event(t, app, "drawing_edit", "A real canvas creation advances to editing")
	t.assert_eq(doc.shapes.size(), 1, "Tutorial creation adds only the shape the player actually requested")
	doc.move_selected(Vector2(100, 40))
	await _settle(t)
	_assert_event(t, app, "drawing_undo", "A real position edit advances to Undo practice")
	app._drawing_screen._undo.pressed.emit()
	await _settle(t)
	t.assert_true(app._tutorial.blocks_gameplay(), "Undo evidence returns to the next guide dialogue")
	t.assert_eq(Vector2(doc.get_selected().position), Vector2.ZERO, "Tutorial Undo uses the existing command history")
	_finish_dialogue(app._tutorial)
	t.assert_false(app._tutorial.active, "Finishing the free drawing conversation dismisses its view")
	t.assert_eq(app._tutorial.progress.statuses.get("drawing", ""), "completed", "A completed tour records completion separately from artwork")
	var artwork: Dictionary = doc.serialize()
	t.assert_true(app._tutorial.start("drawing"), "A finished tutorial can be replayed")
	_key(app._drawing_screen, KEY_DELETE)
	_key(app._drawing_screen, KEY_Z, true)
	t.assert_eq(doc.serialize(), artwork, "Dialogue blocks destructive editor shortcuts behind the guide")
	app._tutorial.overlay._skip_button.pressed.emit()
	t.assert_false(app._tutorial.active, "The visible Skip button immediately ends the tutorial")
	t.assert_eq(doc.serialize(), artwork, "Skipping a replay preserves the current drawing")
	t.assert_false(app._tutorial.progress.should_offer("drawing"), "Skipped or completed guidance is not offered repeatedly")
	app._tutorial.start("drawing")
	app._show_workshop()
	t.assert_false(app._tutorial.active, "Changing modes cancels the old tutorial")
	t.assert_eq(doc.serialize(), artwork, "Navigating away from a tutorial preserves the independent drawing")


static func _masterpiece(t: Node, app: QuadrilateralApp) -> void:
	app._show_drawing()
	var doc: DrawingDocument = app._drawing_screen.document
	var shapes: Array[Dictionary] = doc.shapes.duplicate(true)
	app._tutorial.start("masterpiece")
	app._tutorial.advance()
	_assert_event(t, app, "masterpiece_chosen", "Masterpiece tutorial waits for a real gallery choice")
	app._drawing_screen._masterpiece_button.pressed.emit()
	await _settle(t)
	t.assert_true(is_instance_valid(app._drawing_screen._gallery) and app._drawing_screen._gallery.visible, "Masterpiece instruction opens the existing gallery")
	t.assert_false(app._tutorial.overlay.visible, "Tutorial card yields to the gallery popup")
	app._drawing_screen._choose_scene("starry_night", true)
	await _settle(t)
	_assert_event(t, app, "masterpiece_guide", "Choosing an actual masterpiece advances after the gallery closes")
	t.assert_true(app._tutorial.overlay.visible, "Practice guidance returns after the popup closes")
	app._drawing_screen._guide_toggle.button_pressed = not app._drawing_screen._guide_toggle.button_pressed
	await _settle(t)
	_assert_event(t, app, "drawing_add", "Changing guide visibility continues to actual masterpiece drawing")
	app._drawing_screen.canvas.add_at_center()
	await _settle(t)
	t.assert_true(app._tutorial.blocks_gameplay(), "A real shape over the masterpiece continues its explanation")
	_finish_dialogue(app._tutorial)
	t.assert_eq(doc.shapes.slice(0, shapes.size()), shapes, "Masterpiece guidance preserves previously drawn shapes")
	t.assert_eq(app._tutorial.progress.statuses.get("masterpiece", ""), "completed", "Masterpiece tutorial tracks its own completion")
	var window: Window = t.get_window()
	var previous_size: Vector2i = window.size
	window.size = Vector2i(800, 600)
	await _settle(t)
	app._responsive()
	app._tutorial.start("masterpiece")
	app._tutorial.advance()
	await _settle(t)
	_assert_event(t, app, "masterpiece_guide", "An existing masterpiece skips selection when replayed in a compact window")
	t.assert_false(app._drawing_screen._masterpiece_tools.is_visible_in_tree(), "Compact masterpiece practice uses the alternate edit menu")
	var guide_visible: bool = app._drawing_screen.canvas.show_masterpiece
	app._drawing_screen._more_edit_action(10)
	await _settle(t)
	t.assert_eq(app._drawing_screen.canvas.show_masterpiece, not guide_visible, "The compact menu actually changes the guide visibility")
	_assert_event(t, app, "drawing_add", "Compact guide-menu evidence advances just like the large-screen toggle")
	app._drawing_screen.canvas.add_at_center()
	await _settle(t)
	_finish_dialogue(app._tutorial)
	window.size = previous_size
	await _settle(t)
	app._responsive()


static func _color_popup(t: Node, app: QuadrilateralApp) -> void:
	app._show_drawing()
	app._tutorial.start("drawing")
	app._tutorial.advance()
	app._drawing_screen.canvas.add_at_center()
	await _settle(t)
	_assert_event(t, app, "drawing_edit", "Color-popup practice starts at a real editable shape")
	var waiting_index: int = app._tutorial.index
	var popup: PopupPanel = app._drawing_screen._color_picker.get_popup()
	popup.popup_centered(Vector2i(360, 440))
	await _settle(t)
	t.assert_false(app._tutorial.overlay.visible, "The native color picker owns input above the practice card")
	app._drawing_screen._color_picker.color_changed.emit(Color("ff7043"))
	await _settle(t)
	t.assert_eq(app._drawing_screen.document.get_selected().color, Color("ff7043"), "Color-picker practice uses the real recolor command")
	t.assert_eq(app._tutorial.index, waiting_index, "Recolor evidence waits until the color popup closes")
	popup.hide()
	await _settle(t)
	_assert_event(t, app, "drawing_undo", "Closing the color popup resumes the queued tutorial step")
	app._tutorial.cancel()


static func _learning(t: Node, app: QuadrilateralApp) -> void:
	app._show_learning("perpendicular")
	app._tutorial.start("learning")
	app._tutorial.advance()
	_assert_event(t, app, "learning_measure", "Learning guide waits for measurement")
	app._learning_screen.canvas.measure()
	await _settle(t)
	_assert_event(t, app, "learning_adjust", "Measured evidence advances to manipulation")
	app._learning_screen.canvas.set_value(90.0)
	await _settle(t)
	_assert_event(t, app, "learning_check", "Changing the line advances to checking the result")
	app._learning_screen._primary.pressed.emit()
	await _settle(t)
	t.assert_true(app._tutorial.blocks_gameplay(), "Checking the actual activity continues the explanation")
	t.assert_eq(app._learning_screen.phase, 1, "Tutorial leaves the student's reason choice unanswered")
	t.assert_false(app.learning_progress.completed.has("perpendicular"), "Tutorial evidence cannot award a lesson completion")
	_finish_dialogue(app._tutorial)
	var current_value: float = app._learning_screen.canvas.value
	var practice: Dictionary = app.learning_progress.serialize()
	app._tutorial.start("learning")
	app._tutorial.advance()
	t.assert_true(app._tutorial.index >= 4 and app._tutorial.blocks_gameplay(), "A checked learning activity replays dialogue instead of asking for hidden controls")
	t.assert_float_approx(app._learning_screen.canvas.value, current_value, 0.001, "Replayed guidance retains the student's line position")
	t.assert_eq(app._learning_screen.phase, 1, "Replaying guidance preserves the pending reason choice")
	t.assert_eq(app.learning_progress.serialize(), practice, "Replaying a checked activity does not change attempt or completion records")
	app._tutorial.skip()
	app._learning_screen.answer_reason(0)
	var finished_practice: Dictionary = app.learning_progress.serialize()
	app._tutorial.start("learning")
	app._tutorial.advance()
	t.assert_true(app._tutorial.index >= 4 and app._tutorial.blocks_gameplay(), "A completed learning activity also skips unavailable manipulation steps")
	t.assert_eq(app._learning_screen.phase, 2, "Replayed guidance preserves the completed activity phase")
	t.assert_eq(app.learning_progress.serialize(), finished_practice, "Completed lesson records remain unchanged by tutorial replay")
	app._tutorial.skip()


static func _workshop(t: Node, app: QuadrilateralApp) -> void:
	app._show_workshop()
	t.assert_false(app._tutorial.active, "Workshop entry remains direct in test mode")
	app._tutorial.start("workshop")
	app._tutorial.advance()
	_assert_event(t, app, "workshop_place", "Workshop tutorial asks for an actual filled skeleton slot")
	var slot: Dictionary = CharacterTemplates.get_template(app.document.template_id).parts[0]
	t.assert_true(app.document.fill_slot(str(slot.id), str(slot.kind), Color("77e2dc")), "The player's matching quadrilateral fills a real slot")
	await _settle(t)
	t.assert_true(app._tutorial.blocks_gameplay(), "Filling one skeleton slot continues the guide dialogue")
	app._tutorial.advance()
	_assert_event(t, app, "workshop_ready", "Workshop tour waits for every required skeleton slot")
	app.document.fill_example()
	await _settle(t)
	t.assert_true(app._tutorial.blocks_gameplay(), "A real completed character satisfies readiness")
	_finish_dialogue(app._tutorial)
	var character: Dictionary = app.document.serialize()
	app._tutorial.start("workshop")
	_key(app, KEY_DELETE)
	t.assert_eq(app.document.serialize(), character, "Workshop conversation blocks the main editor's delete shortcut")
	app._tutorial.advance()
	t.assert_true(app._tutorial.index > 1 and app._tutorial.blocks_gameplay(), "Replaying with a complete character recognizes an already filled slot")
	app._tutorial.skip()
	t.assert_eq(app.document.serialize(), character, "Workshop skip does not replace the student's character")


static func _world(t: Node, app: QuadrilateralApp) -> void:
	app._enter_world()
	await _settle(t)
	t.assert_true(app._in_world, "The completed constructed character enters the real world")
	app._tutorial.start("world")
	t.assert_false(app.world.controls_enabled, "World introduction pauses movement and combat")
	t.assert_true(app.world.peaceful, "World tutorial protects the learner during practice")
	app._show_controls()
	await _settle(t)
	t.assert_false(app._tutorial.overlay.visible, "A foreign gameplay modal takes input above the guide")
	app._close_modal()
	await _settle(t)
	t.assert_false(app.world.controls_enabled, "Closing another modal cannot resume movement underneath tutorial dialogue")
	t.assert_true(app._tutorial.overlay.visible, "The guide returns when the foreign modal closes")
	app._tutorial.advance()
	_assert_event(t, app, "world_move", "World dialogue advances to movement practice")
	t.assert_true(app.world.controls_enabled, "Movement practice restores player controls")
	var origin: float = app.world.player.position.x
	app.world.player.set_touch_control("right", true)
	for frame: int in range(90):
		await t.get_tree().physics_frame
		if str(app._tutorial.current_step().get("event", "")) != "world_move": break
	app.world.player.set_touch_control("right", false)
	await _settle(t)
	t.assert_ge(app.world.player.position.x - origin, 80.0, "Movement practice is satisfied by real physics displacement")
	_assert_event(t, app, "world_jump", "Walking far enough continues to jump practice")
	app.world.player.set_touch_control("jump", true)
	for frame: int in range(20):
		await t.get_tree().physics_frame
		if str(app._tutorial.current_step().get("event", "")) != "world_jump": break
	app.world.player.set_touch_control("jump", false)
	await _settle(t)
	_assert_event(t, app, "world_inventory", "A real player jump continues to bag practice")
	var inventory_index: int = app._tutorial.index
	app._show_inventory()
	await _settle(t)
	t.assert_eq(app._tutorial.index, inventory_index, "Opening the inventory queues evidence while the modal remains open")
	t.assert_false(app._tutorial.overlay.visible, "Inventory remains readable without a tutorial card over it")
	t.assert_false(app.world.controls_enabled, "Inventory modal keeps practice movement paused")
	app._close_modal()
	await _settle(t)
	_assert_event(t, app, "world_journal", "Inventory evidence advances only after the player closes it")
	app._show_journal()
	await _settle(t)
	t.assert_false(app._tutorial.overlay.visible, "Quest journal owns input while the learner reads it")
	app._close_modal()
	await _settle(t)
	t.assert_true(app._tutorial.blocks_gameplay(), "Closing the real journal continues the final world conversation")
	t.assert_false(app.world.controls_enabled, "Final world dialogue pauses gameplay again")
	_finish_dialogue(app._tutorial)
	t.assert_true(app.world.controls_enabled, "Completing the world tutorial restores live movement")
	t.assert_eq(app.world.peaceful, app.learning_progress.peaceful, "Tutorial completion restores the player's chosen combat setting")
	app._tutorial.start("world")
	app._show_home()
	t.assert_false(app._tutorial.active, "Leaving the world cancels its active guidance")
	t.assert_false(app.world.controls_enabled, "Cancelling by navigation cannot activate the hidden world")


static func _construction(t: Node, app: QuadrilateralApp) -> void:
	app._show_construction()
	app._tutorial.start("construction")
	await _settle(t)
	var studio: ConstructionStudio = app._construction_screen
	t.assert_true(studio.tutorial_active and studio.tutorial_blocked, "Construction introduction explicitly owns editing input")
	t.assert_false(is_instance_valid(studio._modal), "Deferred first-house briefing does not race the tutorial dialogue")
	var untouched: Dictionary = studio.state.serialize()
	app._tutorial.skip()
	await _settle(t)
	t.assert_false(studio.tutorial_active, "Skipping clears the construction tutorial ownership flag")
	t.assert_true(is_instance_valid(studio._modal), "Normal first-house briefing resumes after skipping guidance")
	t.assert_eq(studio.state.serialize(), untouched, "Skipping the welcome neither accepts a contract nor changes money or materials")
	studio._close_modal()
	app._tutorial.start("construction")
	app._tutorial.advance()
	_assert_event(t, app, "construction_accept", "Construction guide waits for the player's contract acceptance")
	studio._client_action.pressed.emit()
	await _settle(t)
	t.assert_false(app._tutorial.overlay.visible, "The real customer briefing can be read without an overlapping tutorial")
	var accept: Button = _button(studio._modal, "부탁 받고 집 짓기")
	t.assert_not_null(accept, "Existing contract action remains available during acceptance practice")
	if accept != null: accept.pressed.emit()
	await _settle(t)
	_assert_event(t, app, "construction_place", "Accepting the real contract advances after its briefing closes")
	studio._guide_place.pressed.emit()
	await _settle(t)
	t.assert_gt(studio.state.document.parts.size(), 0, "Construction practice places a real guided part")
	t.assert_true(app._tutorial.blocks_gameplay(), "A placed material continues the structural explanation")
	app._tutorial.advance()
	_assert_event(t, app, "construction_inspect", "Structural explanation asks for the actual inspection")
	studio._inspect.pressed.emit()
	for frame: int in range(240):
		await t.get_tree().physics_frame
		if not studio.canvas.inspection_running: break
	await _settle(t)
	t.assert_false(studio.canvas.inspection_running, "Practice waits for the real physics inspection to finish")
	t.assert_true(app._tutorial.blocks_gameplay(), "Inspection result evidence continues the final construction conversation")
	_finish_dialogue(app._tutorial)
	t.assert_eq(studio.state.phase, "building", "Tutorial inspection does not submit or reward the unfinished house")


static func _my_house(t: Node, app: QuadrilateralApp) -> void:
	var studio: ConstructionStudio = app._construction_screen
	var commission: Dictionary = studio.state.document.serialize()
	studio._enter_my_house_mode()
	await _settle(t)
	t.assert_false(app._tutorial.active, "Testing submode changes do not force another first-visit tour")
	app._tutorial.start("my_house")
	_finish_dialogue(app._tutorial)
	_assert_event(t, app, "my_house_place", "Personal-house dialogue asks for a real material placement")
	var id: int = studio.state.my_house_document.add_part("brick", Vector2(100, 550))
	t.assert_gt(id, 0, "Personal-house practice uses the normal validated placement command")
	await _settle(t)
	_assert_event(t, app, "my_house_view", "Personal-house placement advances to its material view")
	var waiting_index: int = app._tutorial.index
	studio._set_view(false)
	await _settle(t)
	t.assert_eq(app._tutorial.index, waiting_index, "Returning to design view cannot substitute for material-view practice")
	studio._material_view.pressed.emit()
	await _settle(t)
	t.assert_true(app._tutorial.blocks_gameplay(), "Actual view switching continues the personal-house dialogue")
	_finish_dialogue(app._tutorial)
	t.assert_eq(studio.state.document.serialize(), commission, "Personal-house tutorial never changes the commissioned house")
	t.assert_eq(app._tutorial.progress.statuses.get("my_house", ""), "completed", "Personal-house completion is tracked independently")


static func _responsive_overlay(t: Node, app: QuadrilateralApp) -> void:
	app._drawing_screen.document.set_mode("free")
	app._show_drawing()
	var window: Window = t.get_window()
	for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1920, 1080)]:
		window.size = dimensions
		await _settle(t)
		app._responsive()
		app._tutorial.start("drawing")
		await _settle(t, 5)
		_assert_overlay_bounds(t, app._tutorial.overlay, dimensions, "Dialogue")
		app._tutorial.advance()
		await _settle(t, 5)
		_assert_overlay_bounds(t, app._tutorial.overlay, dimensions, "Practice")
		t.assert_false(app._tutorial.overlay.is_blocking(), "Practice layout remains nonmodal at %d × %d" % [dimensions.x, dimensions.y])
		app._tutorial.cancel()
	app._tutorial.start("drawing")


static func _assert_overlay_bounds(t: Node, overlay: TutorialOverlay, dimensions: Vector2i, context: String) -> void:
	var bounds: Rect2 = _physical_rect(overlay._panel)
	var label: String = "%s %d × %d" % [context, dimensions.x, dimensions.y]
	t.assert_ge(bounds.position.x, -1.0, label + " keeps the dialogue inside the left edge")
	t.assert_ge(bounds.position.y, -1.0, label + " keeps the dialogue inside the top edge")
	t.assert_le(bounds.end.x, float(dimensions.x) + 1.0, label + " keeps the dialogue inside the right edge")
	t.assert_le(bounds.end.y, float(dimensions.y) + 1.0, label + " keeps the dialogue inside the bottom edge")
	for button: Button in [overlay._next_button, overlay._skip_button]:
		var button_bounds: Rect2 = _physical_rect(button)
		t.assert_ge(button_bounds.size.y, 47.9, label + " keeps tutorial controls at least 48 physical pixels high")
		t.assert_true(bounds.grow(1.0).encloses(button_bounds), label + " keeps its navigation control inside the panel")
	t.assert_true(overlay._skip_button.visible and not overlay._skip_button.disabled, label + " always offers Skip")


static func _stored_preferences() -> Dictionary:
	var result: Dictionary = {}
	for path: String in [TutorialProgress.SAVE_PATH, TutorialProgress.SAVE_PATH + ".tmp", TutorialProgress.SAVE_PATH + ".bak"]:
		result[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return result


static func _assert_event(t: Node, app: QuadrilateralApp, event: String, message: String) -> void:
	t.assert_true(app._tutorial.active and str(app._tutorial.current_step().get("event", "")) == event, message)


static func _finish_dialogue(director: TutorialDirector) -> void:
	for index: int in range(TutorialCatalog.steps(director.mode).size() + 1):
		if not director.active or not str(director.current_step().get("event", "")).is_empty(): return
		director.advance()


static func _button(parent: Node, text: String) -> Button:
	if parent == null: return null
	for node: Node in parent.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == text: return button
	return null


static func _key(target: Node, code: Key, control: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.ctrl_pressed = control
	event.pressed = true
	target.call("_unhandled_key_input", event)


static func _physical_rect(control: Control) -> Rect2:
	var transform: Transform2D = control.get_viewport().get_stretch_transform() * control.get_global_transform_with_canvas()
	var bounds: Rect2 = Rect2(transform * Vector2.ZERO, Vector2.ZERO)
	for point: Vector2 in [Vector2(control.size.x, 0), control.size, Vector2(0, control.size.y)]:
		bounds = bounds.expand(transform * point)
	return bounds


static func _settle(t: Node, frames: int = 3) -> void:
	for frame: int in range(frames):
		await t.get_tree().process_frame
