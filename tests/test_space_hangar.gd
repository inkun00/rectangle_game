class_name TestSpaceHangar
extends RefCounted

const Hangar: GDScript = preload("res://scenes/space/space_hangar.gd")
const Catalog: GDScript = preload("res://scripts/economy/spaceship_catalog.gd")

static func run(t: Node) -> void:
	var state: ConstructionState = ConstructionState.new()
	var hangar: SpaceHangar = Hangar.new()
	hangar.state = state
	hangar.size = Vector2(800, 600)
	var purchases: Array[String] = []
	var launches: Array[bool] = []
	var homes: Array[bool] = []
	var designs: Array[Dictionary] = []
	hangar.purchase_requested.connect(func(id: String): purchases.append(id))
	hangar.design_requested.connect(func(id: String, kind: String, color: String): designs.append({"id": id, "kind": kind, "color": color}))
	hangar.launch_requested.connect(func(): launches.append(true))
	hangar.home_requested.connect(func(): homes.append(true))
	t.add_child(hangar)
	await t.get_tree().process_frame
	t.assert_eq(hangar._part_buttons.size(), 12, "All twelve parts are accessible in the hangar")
	t.assert_true(hangar._purchase.disabled, "Starting working capital cannot buy a spaceship part")
	t.assert_true(hangar._launch.disabled, "An incomplete ship cannot launch")
	hangar._ask_purchase()
	t.assert_false(hangar._confirmation.visible, "An unaffordable selection cannot open a purchase confirmation")
	hangar._select_part("core")
	t.assert_eq(hangar.canvas.selected_part_id, "core", "Selecting a component highlights its actual quadrilateral")
	t.assert_true(hangar._detail.text.contains("마름모"), "Selected part details teach its true shape")
	var before: Dictionary = state.serialize()
	hangar._request_launch()
	t.assert_eq(launches.size(), 0, "Disabled launch paths cannot dispatch a transaction")
	t.assert_eq(state.serialize(), before, "Browsing the hangar never mutates the economic model")
	# A price-only receipt is sufficient for this UI fixture. Receipt integrity is
	# exercised by the economy tests; the UI must only emit an approved intent.
	state.art_sales.append({"price": 300000000})
	hangar.refresh()
	hangar._ask_purchase()
	t.assert_true(hangar._confirmation.visible, "Affordable purchases require a second confirmation")
	t.assert_eq(purchases.size(), 0, "Opening the confirmation alone cannot spend money")
	hangar._select_part("nose")
	hangar._confirm_purchase()
	t.assert_eq(purchases, ["core"], "Confirmation purchases the quoted component even if selection changes")
	hangar._confirm_purchase()
	t.assert_eq(purchases.size(), 1, "Repeated confirmation cannot dispatch a second purchase")
	t.assert_eq(state.purchased_ship_parts.size(), 0, "Purchase intent leaves all model mutations to the saved transaction")
	hangar._ask_purchase()
	state.art_sales.clear()
	hangar.refresh()
	t.assert_true(hangar._confirmation.get_ok_button().disabled, "A stale quote is disabled when funds change")
	hangar._confirm_purchase()
	t.assert_eq(purchases.size(), 1, "An outdated confirmation cannot overspend")
	# UI launch tests operate on a fixture; real purchases and ledger validation
	# belong to the economy integration tests.
	for item: Dictionary in Catalog.all_parts(): state.purchased_ship_parts.append(str(item.id))
	state.launched = true
	hangar.refresh()
	hangar._select_part("hull")
	hangar._design_shape.select(QuadrilateralMath.KINDS.find("rhombus"))
	hangar._design_color.color = Color("e31881")
	hangar._preview_design()
	t.assert_true(hangar._design_row.visible and not hangar._apply_design.disabled, "Owned parts expose a live design preview and save action")
	t.assert_eq(hangar.canvas._design.get("hull", {}), {"kind": "rhombus", "color": "e31881"}, "The actual hangar preview shows the selected family and color")
	t.assert_true(state.ship_design.is_empty(), "Previewing a new part does not mutate the durable design")
	hangar._request_launch()
	t.assert_false(hangar._launch_panel.visible, "Departure does not discard an unapplied preview")
	hangar._request_design()
	t.assert_eq(designs, [{"id": "hull", "kind": "rhombus", "color": "e31881"}], "The save control emits the selected part and actual design")
	state.customize_ship_part("hull", "rhombus", "e31881")
	t.assert_false(hangar._launch.disabled, "A completed ship exposes its departure action")
	t.assert_true(hangar._launch.text.contains("다시"), "A completed homecoming can be replayed without a new charge")
	hangar._request_launch()
	t.assert_true(hangar._launch_panel.visible, "A replay presents the animated homecoming scene")
	t.assert_false(hangar._content.visible, "Purchases are unavailable during the launch animation")
	t.assert_eq(hangar._launch_canvas.purchased_ids.size(), 12, "The launched ship uses all twelve assembled components")
	t.assert_eq(hangar._launch_canvas._design, state.ship_design, "A legacy replay uses the player's chosen geometry and color")
	hangar._process(4.0)
	t.assert_gt(hangar._launch_canvas.launch_time, 3.0, "The real launch advances beyond its countdown")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	hangar._unhandled_key_input(escape)
	t.assert_true(hangar._launch_done, "Escape reaches the arrival scene without undoing completion")
	t.assert_true(state.launched, "Skipping the animation retains the earned homecoming")
	t.assert_true(hangar._launch_home.visible, "Arrival provides a visible route back to the main page")
	t.assert_eq(purchases.size(), 1, "Replaying the homecoming never purchases anything")
	hangar._launch_home.pressed.emit()
	t.assert_eq(homes.size(), 1, "The arrival screen returns through the normal home signal")
	hangar.cancel_activity()
	t.assert_false(hangar._launch_panel.visible, "Leaving the hangar releases the animation overlay")
	t.assert_false(hangar.is_processing(), "A hidden hangar does not continue animating")
	hangar.free()
	await t.get_tree().process_frame
