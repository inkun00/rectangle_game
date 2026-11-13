class_name TestDeferredFeatures
extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")

class PackGate:
	extends RefCounted
	signal completed(success: bool)
	var available: bool = true
	var waiting: bool = false
	var calls: Array[String] = []

	func ensure(feature: String) -> bool:
		calls.append(feature)
		if waiting: return await completed
		return available

static func _app(t: Node, gate: PackGate) -> QuadrilateralApp:
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	app.defer_feature_screens_for_testing = true
	app._resource_pack_loader = gate.ensure
	t.add_child(app)
	return app

static func _settle(t: Node) -> void:
	# ColorPicker creates and skins popup controls in deferred engine callbacks.
	# Let those finish before destroying a freshly opened feature screen.
	await t.get_tree().process_frame
	await t.get_tree().process_frame

static func run(t: Node) -> void:
	await _test_lazy_screens_and_shared_ledger(t)
	await _test_failure_and_retry(t)
	await _test_cancel_and_stale_navigation(t)
	await _test_world_entry_gate(t)
	await _test_tutorial_resumes_after_download(t)
	await _test_drawing_tutorial_pointer_navigation(t)

static func _test_lazy_screens_and_shared_ledger(t: Node) -> void:
	var gate: PackGate = PackGate.new()
	var app: QuadrilateralApp = _app(t, gate)
	await t.get_tree().process_frame
	t.assert_true(app._home_screen.visible, "Deferred delivery starts on the same home page")
	t.assert_true(gate.calls.is_empty(), "Home never starts an optional feature download")
	t.assert_false(is_instance_valid(app._drawing_screen), "Drawing art is not loaded by constructing its hidden screen")
	t.assert_false(is_instance_valid(app._construction_screen), "Construction art is not loaded by constructing its hidden screen")
	t.assert_false(is_instance_valid(app._space_screen), "Planet art is not loaded before opening the hangar")
	t.assert_true(app._tutorial != null and app._learning_screen != null, "Learning and tutorial services remain available before optional screens")
	var ledger: ConstructionState = app._economy_state
	await app._show_space()
	t.assert_true(gate.calls.is_empty(), "A locked ending never starts an optional resource download")
	t.assert_true(TestSpaceIntegration.settle_commissions(ledger, 10), "Ten settled commissions make the hangar available")
	await app._show_space()
	t.assert_eq(gate.calls, ["space"], "Opening the hangar requests only its feature")
	t.assert_true(app._space_screen.visible and app._space_screen.state == ledger, "The hangar uses the authoritative shared ledger")
	t.assert_false(is_instance_valid(app._construction_screen), "Visiting space never constructs the construction screen")
	app._show_home()
	await app._show_drawing()
	t.assert_true(app._drawing_screen.visible and app._drawing_screen.economy == ledger, "Drawing can earn money before the construction screen exists")
	t.assert_true(app._tutorial._drawing_bound == app._drawing_screen, "The drawing tutorial binds after the real screen is created")
	ledger.balance += 1000
	var balance: int = ledger.balance
	var artwork: Dictionary = app._drawing_screen.document.serialize()
	await app._show_construction()
	t.assert_true(app._construction_screen.visible, "The requested construction feature opens its existing UI")
	t.assert_true(app._construction_screen.state == ledger, "Lazy construction adopts the same ledger without replacing it")
	t.assert_eq(ledger.balance, balance, "Late construction does not reload and overwrite income earned elsewhere")
	t.assert_eq(app._drawing_screen.document.serialize(), artwork, "Feature navigation preserves the drawing document")
	t.assert_true(app._tutorial._construction_bound == app._construction_screen, "Construction tutorials bind after material controls exist")
	app._show_home()
	t.assert_true(app._home_screen.visible and not app._construction_screen.visible, "All lazy modes retain their home navigation")
	await _settle(t)
	app.free()
	await t.get_tree().process_frame

static func _test_failure_and_retry(t: Node) -> void:
	var gate: PackGate = PackGate.new()
	gate.available = false
	var app: QuadrilateralApp = _app(t, gate)
	await app._show_drawing()
	t.assert_true(app._home_screen.visible, "A failed download preserves the current screen")
	t.assert_false(is_instance_valid(app._drawing_screen), "A failed download never constructs a screen with missing textures")
	t.assert_false(is_instance_valid(app._feature_loading_overlay), "Failure releases the loading overlay")
	t.assert_true(app._toast.text.contains("다시"), "Failure gives a route to retry")
	gate.available = true
	await app._show_drawing()
	t.assert_true(app._drawing_screen.visible, "The same feature can be retried successfully")
	t.assert_eq(gate.calls, ["drawing", "drawing"], "Retry makes a new resource request")
	await _settle(t)
	app.free()
	await t.get_tree().process_frame

static func _test_cancel_and_stale_navigation(t: Node) -> void:
	var gate: PackGate = PackGate.new()
	gate.waiting = true
	var app: QuadrilateralApp = _app(t, gate)
	t.assert_true(TestSpaceIntegration.settle_commissions(app._economy_state, 10), "The fixture unlocks the optional hangar")
	app._show_space()
	t.assert_true(is_instance_valid(app._feature_loading_overlay), "An asynchronous feature request displays its loading state")
	app._show_home()
	gate.completed.emit(true)
	await t.get_tree().process_frame
	t.assert_true(app._home_screen.visible, "An obsolete download cannot navigate away from home")
	t.assert_false(is_instance_valid(app._space_screen), "A canceled request cannot instantiate a stale screen")
	app._show_drawing()
	app._show_construction()
	gate.completed.emit(true)
	await t.get_tree().process_frame
	t.assert_true(app._construction_screen != null and app._construction_screen.visible, "Only the latest requested destination can become active")
	t.assert_false(is_instance_valid(app._drawing_screen), "A superseded drawing request never constructs hidden optional art")
	await _settle(t)
	app.free()
	await t.get_tree().process_frame

static func _test_world_entry_gate(t: Node) -> void:
	var gate: PackGate = PackGate.new()
	gate.available = false
	var app: QuadrilateralApp = _app(t, gate)
	var character: Dictionary = app.document.serialize()
	await app._enter_world()
	t.assert_eq(gate.calls, ["adventure"], "Entering the world requests the adventure resources")
	t.assert_true(app._home_screen.visible and app.world == null, "A failed village download keeps home available for a retry")
	t.assert_eq(app.document.serialize(), character, "A download failure never changes the player's artwork")
	await _settle(t)
	app.free()
	await t.get_tree().process_frame

static func _test_tutorial_resumes_after_download(t: Node) -> void:
	var gate: PackGate = PackGate.new()
	gate.waiting = true
	var app: QuadrilateralApp = _app(t, gate)
	app._show_learning()
	t.assert_true(app._tutorial.start("learning"), "The existing learning guide can start before optional art loads")
	await _settle(t)
	t.assert_true(app._tutorial.overlay.visible, "The active learning guide is initially visible")
	app._show_drawing()
	await _settle(t)
	t.assert_true(app._tutorial.active and not app._tutorial.overlay.visible, "Loading suspends the active guide without ending it")
	app._cancel_feature_navigation()
	gate.completed.emit(false)
	await _settle(t)
	t.assert_true(app._tutorial.active and app._tutorial.overlay.visible, "Canceling a download resumes the suspended guide")
	t.assert_eq(app._tutorial.mode, "learning", "Cancellation retains the learner's current tutorial")
	t.assert_true(app._learning_screen.visible, "Cancellation preserves the existing learning screen")
	app._show_construction()
	await _settle(t)
	t.assert_false(app._tutorial.overlay.visible, "The guide can suspend for a subsequent download")
	gate.completed.emit(false)
	await _settle(t)
	t.assert_true(app._tutorial.active and app._tutorial.overlay.visible, "A failed download also resumes the suspended guide")
	t.assert_false(is_instance_valid(app._construction_screen), "Failure keeps optional construction controls uncreated")
	app.free()
	await t.get_tree().process_frame


static func _test_drawing_tutorial_pointer_navigation(t: Node) -> void:
	var window: Window = t.get_window()
	var previous_size: Vector2i = window.size
	window.size = Vector2i(1280, 800)
	await _settle(t)
	var app: QuadrilateralApp = _app(t, PackGate.new())
	await app._show_drawing()
	var canvas: DrawingCanvas = app._drawing_screen.canvas
	canvas.select_kind("rectangle")
	var tutorial: TutorialDirector = app._tutorial
	tutorial.start("drawing")
	await _settle(t)
	_click(canvas)
	t.assert_eq(canvas.document.shapes.size(), 0, "The visible welcome curtain blocks pointer edits behind it")
	_click(tutorial.overlay._next_button)
	await _settle(t)
	t.assert_eq(tutorial.index, 1, "Clicking Next advances the guide above the lazily added drawing studio")
	t.assert_false(app._drawing_screen.tutorial_blocked, "Next opens real drawing practice")
	_click(canvas)
	await _settle(t)
	t.assert_eq(canvas.document.shapes.size(), 1, "The practice card lets the pointer reach the drawing canvas")
	t.assert_eq(tutorial.index, 2, "Placing the rectangle by pointer advances the practice")
	_click(tutorial.overlay._skip_button)
	t.assert_false(tutorial.active, "Clicking Skip closes the practice card")
	t.assert_eq(canvas.document.shapes.size(), 1, "Skipping preserves the drawing")
	app.free()
	window.size = previous_size
	await t.get_tree().process_frame


static func _click(control: Control) -> void:
	var viewport: Viewport = control.get_viewport()
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		viewport.push_input(event, true)
