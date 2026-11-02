class_name TestSpaceIntegration
extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")

static func run(t: Node) -> void:
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	await t.get_tree().process_frame
	var ledger: ConstructionState = app._construction_screen.state
	t.assert_true(app._space_screen.state == ledger, "Ship and construction share one ledger")
	t.assert_true(app._drawing_screen.economy == ledger, "Drawing income uses that same ledger")
	t.assert_false(app._space_screen.visible, "Ship menu starts hidden")
	app._home_screen._space_button.pressed.emit()
	t.assert_true(app._space_screen.visible, "Home ship button opens the hangar")
	t.assert_false(app._home_screen.visible, "The hangar owns the screen")
	t.assert_true(app.world == null or not app.world.controls_enabled, "Hangar navigation keeps hidden RPG controls inactive")
	app._space_screen.drawing_requested.emit()
	t.assert_true(app._drawing_screen.visible, "The hangar offers a route to earn drawing income")
	t.assert_false(app._space_screen.visible, "Opening drawing hides the hangar")
	app._tutorial.cancel()
	var art: DrawingDocument = app._drawing_screen.document
	var colors: Array[Color] = [Color.CORAL, Color.GOLD, Color.SKY_BLUE, Color.LIME_GREEN, Color.PLUM]
	for index: int in range(5):
		art.add_sized_shape(QuadrilateralMath.KINDS[index], Vector2(-280 + index * 140, 0), Vector2(130, 180), colors[index])
	var picture: Dictionary = art.serialize()
	var quote: Dictionary = ArtMarket.quote(art)
	t.assert_true(bool(quote.can_sell), "The integration fixture is a real saleable drawing")
	app._drawing_screen._sale_button.pressed.emit()
	t.assert_true(app._drawing_screen._sale_dialog.visible, "The actual sale button shows its quote")
	t.assert_eq(ledger.balance, ConstructionState.INITIAL_BALANCE, "A quote alone does not pay money")
	app._drawing_screen._sale_dialog.confirmed.emit()
	t.assert_eq(ledger.art_sales.size(), 1, "The actual confirmation records one sale")
	t.assert_eq(ledger.balance, ConstructionState.INITIAL_BALANCE + int(quote.price), "Drawing income reaches the construction ledger")
	t.assert_eq(art.serialize(), picture, "Selling preserves the editable artwork")
	t.assert_false(app._drawing_screen._sale_pending, "The transaction resolves the pending UI state")
	t.assert_true(app._home_screen._space_status.text.contains("1점"), "The home screen reflects the sale")
	app._drawing_screen._sale_button.pressed.emit()
	t.assert_true(app._drawing_screen._sale_dialog.get_ok_button().disabled, "A sold picture cannot be sold again")
	app._drawing_screen.home_requested.emit()
	t.assert_true(app._home_screen.visible, "The drawing home action still works after sale")
	t.assert_false(app._drawing_screen._sale_dialog.visible, "Navigation dismisses the native sale popup")
	var balance: int = ledger.balance
	app._drawing_screen.art_sale_requested.emit(picture)
	t.assert_eq(ledger.balance, balance, "A hidden drawing screen cannot submit transactions")
	app._show_space()
	app._space_screen.purchase_requested.emit("hull")
	t.assert_eq(ledger.purchased_ship_parts.size(), 0, "Not enough money cannot buy the first expensive part")
	app._space_screen.launch_requested.emit()
	t.assert_false(ledger.launched, "An incomplete ship cannot trigger the ending through signals")
	t.assert_false(app._space_screen._launch_panel.visible, "A rejected launch never plays the ending")
	app._space_screen.construction_requested.emit()
	t.assert_true(app._construction_screen.visible, "The hangar offers a route to earn construction income")
	t.assert_true(app._construction_screen.state == ledger, "Navigation never replaces the common ledger")
	t.assert_eq(ledger.balance, balance, "Navigation does not change earned money")
	app._show_space()
	app._space_screen.home_requested.emit()
	t.assert_true(app._home_screen.visible, "Hangar home action returns to the main page")
	t.assert_false(app._space_screen.is_processing(), "Leaving the hangar releases animation processing")
	app.free()
	await t.get_tree().process_frame
