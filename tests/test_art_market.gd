class_name TestArtMarket
extends RefCounted

const Market = preload("res://scripts/economy/art_market.gd")
const Model = preload("res://scripts/core/drawing_document.gd")
const Studio = preload("res://scenes/drawing/drawing_studio.gd")
const Economy = preload("res://scripts/construction/construction_state.gd")
const ArtSamples = preload("res://tests/art_sale_samples.gd")

static func run(t: Node) -> void:
	_test_quotes(t)
	_test_sale_requirements(t)
	_test_receipts(t)
	_test_duplicate_sales(t)
	await _test_sale_ui(t)

static func sample_art() -> DrawingDocument:
	return ArtSamples.house()

static func _test_quotes(t: Node) -> void:
	var drawing: DrawingDocument = sample_art()
	var before: Dictionary = drawing.serialize()
	var history: int = drawing.command_manager.undo_stack.size()
	var offer: Dictionary = Market.quote(drawing)
	t.assert_true(offer.can_sell, "The house fixture meets the three geometry requirements")
	t.assert_eq(offer.visible_shapes, 6, "Quote counts actual visible quadrilaterals")
	t.assert_eq(offer.families, 3, "Rectangle, trapezoid and square geometry avoid inclusive double counting")
	t.assert_eq(offer.colors, 3, "Visible colors are counted once each")
	var check_ids: Array[String] = []
	for check: Dictionary in offer.checks:
		check_ids.append(str(check.id))
		t.assert_true(bool(check.met), "The fixture passes each stated sale requirement: " + str(check.label))
	t.assert_eq(check_ids, ["pieces", "families", "coverage"], "The quote evaluates only shape count, variety and occupied paper area")
	t.assert_gt(offer.price, 1000000, "Art sales contribute meaningful spaceship savings")
	t.assert_le(offer.price, Market.MAX_PRICE, "Art offers respect the long-term progression cap")
	t.assert_eq(int(offer.price) % 100, 0, "Art prices use 100 won increments")
	t.assert_eq(drawing.serialize(), before, "Quoting never changes the player's drawing")
	t.assert_eq(drawing.command_manager.undo_stack.size(), history, "Quoting never changes undo history")
	t.assert_false(Market.quote(Model.new()).can_sell, "A background alone is not sellable artwork")
	var hidden: DrawingDocument = Model.new()
	for index: int in range(8):
		hidden.add_sized_shape("square", Vector2.ZERO, Vector2(240, 240), Color.RED if index % 2 == 0 else Color.BLUE)
	var uncovered: DrawingDocument = Model.new()
	uncovered.add_sized_shape("square", Vector2.ZERO, Vector2(240, 240), Color.BLUE)
	var layered_offer: Dictionary = Market.quote(hidden)
	t.assert_eq(layered_offer.visible_shapes, 1, "Fully obscured copies do not inflate shape count")
	t.assert_eq(layered_offer.price, Market.quote(uncovered).price, "Stacking identical shapes cannot increase the discounted sale price")
	t.assert_true(layered_offer.price > 0 and layered_offer.price < layered_offer.full_price, "One visible shape is eligible for a discounted sale")
	var transparent: DrawingDocument = sample_art()
	for shape: Dictionary in transparent.shapes:
		transparent.select_shape(int(shape.id))
		transparent.set_color(Color(1, 0, 0, 0.3))
	t.assert_false(Market.quote(transparent).can_sell, "Almost invisible polygons do not qualify for payment")
	var one_color: DrawingDocument = sample_art()
	for shape: Dictionary in one_color.shapes:
		one_color.select_shape(int(shape.id))
		one_color.set_color(Color.CORAL)
	var monochrome_offer: Dictionary = Market.quote(one_color)
	t.assert_true(monochrome_offer.can_sell, "One color is enough when the geometry requirements are met")
	t.assert_eq(monochrome_offer.price, offer.price, "Recoloring a qualifying drawing does not change its price")
	var relabeled: Dictionary = drawing.serialize()
	for shape: Dictionary in relabeled.shapes: shape.kind = "trapezoid"
	var inclusive: DrawingDocument = Model.new()
	t.assert_true(inclusive.restore(relabeled), "The house's rectangles, squares and roof all remain inclusive trapezoids")
	t.assert_eq(Market.quote(inclusive).families, offer.families, "Relabeling family metadata cannot increase value")
	t.assert_eq(Market.quote(inclusive).price, offer.price, "Price follows geometry rather than chosen family label")

static func _abstract_drawing(count: int, kinds: Array[String], dimensions: Vector2) -> DrawingDocument:
	var drawing: DrawingDocument = Model.new()
	for index: int in range(count):
		var position: Vector2 = Vector2(-260 + (index % 3) * 260, -120 if index < 3 else 120)
		drawing.add_sized_shape(kinds[index % kinds.size()], position, dimensions, Color.CORAL)
	return drawing


static func _test_sale_requirements(t: Node) -> void:
	var mixed: Array[String] = ["rectangle", "square", "trapezoid"]
	var large: Vector2 = Vector2(160, 140)
	var abstract_drawing: DrawingDocument = _abstract_drawing(6, mixed, large)
	var offer: Dictionary = Market.quote(abstract_drawing)
	t.assert_true(offer.can_sell, "A monochrome abstract arrangement with six separate shapes, three families and enough coverage can be sold")
	t.assert_eq(offer.visible_shapes, 6, "The abstract drawing meets the exact minimum piece count")
	t.assert_eq(offer.families, 3, "The abstract drawing meets the exact minimum family count")
	t.assert_eq(offer.completion_ratio, 1.0, "Meeting all three goals reports full satisfaction")
	t.assert_eq(offer.price, offer.full_price, "Meeting all three goals pays the full quote")
	_assert_discounted_payment(t, _abstract_drawing(5, mixed, large), "pieces", 17.0 / 18.0)
	_assert_discounted_payment(t, _abstract_drawing(6, ["rectangle", "square"], large), "families", 8.0 / 9.0)
	var small: DrawingDocument = _abstract_drawing(6, mixed, Vector2(60, 52))
	var coverage: float = float(Market.quote(small).coverage)
	_assert_discounted_payment(t, small, "coverage", (2.0 + coverage / 0.12) / 3.0)
	var exact_payment: DrawingDocument = Model.new()
	for height: float in [-90.0, 90.0]:
		exact_payment.add_sized_shape("rectangle", Vector2(10, height), Vector2(580, 60), Color.CORAL)
	var exact_offer: Dictionary = Market.quote(exact_payment)
	t.assert_eq(exact_offer.full_price, 3070800, "The two rectangles cover exactly 174 sampling cells")
	t.assert_eq(exact_offer.price, 1706000, "An exact 100-won payment survives fractional-rounding noise")

static func _assert_discounted_payment(t: Node, drawing: DrawingDocument, missing_goal: String, expected_ratio: float) -> void:
	var offer: Dictionary = Market.quote(drawing)
	t.assert_true(offer.can_sell, "A drawing with an unmet %s goal can still be sold" % missing_goal)
	for check: Dictionary in offer.checks:
		t.assert_eq(bool(check.met), check.id != missing_goal, "Only the %s goal is unmet in this fixture" % missing_goal)
	t.assert_float_approx(float(offer.completion_ratio), expected_ratio, 0.000001, "The %s shortfall reduces satisfaction by its share" % missing_goal)
	var expected_price: int = floori(float(offer.full_price) * expected_ratio / 100.0) * 100
	t.assert_eq(offer.price, expected_price, "The %s shortfall discounts the full quote in 100 won steps" % missing_goal)
	t.assert_true(offer.price > 0 and offer.price < offer.full_price, "A discounted offer has a positive payout below the full price")
	var economy: ConstructionState = Economy.new()
	var original: Dictionary = drawing.serialize()
	var history: int = drawing.command_manager.undo_stack.size()
	var payment: Dictionary = economy.sell_art(original, "사각형 모임")
	t.assert_true(payment.ok, "The ledger accepts a quoted partial sale")
	t.assert_eq(payment.get("price", 0), expected_price, "The ledger pays the exact discounted amount")
	t.assert_eq(economy.balance, Economy.INITIAL_BALANCE + expected_price, "Only the discounted amount is added to the balance")
	t.assert_eq(drawing.serialize(), original, "Selling through the ledger preserves the player's editable composition")
	t.assert_eq(drawing.command_manager.undo_stack.size(), history, "Selling through the ledger preserves the drawing Undo history")

static func _test_receipts(t: Node) -> void:
	var offer: Dictionary = Market.quote(sample_art())
	var receipt: Dictionary = Market.receipt_from_quote(offer, "나의 우주 그림")
	t.assert_true(Market.validate_receipt(receipt), "A quote produces a valid compact receipt")
	t.assert_eq(receipt.version, 3, "New receipts record proportional pricing")
	t.assert_eq(receipt.size(), 9, "Receipt keeps compact scalar fields rather than a document snapshot")
	var previous: Dictionary = receipt.duplicate()
	previous.version = 2
	t.assert_true(Market.validate_receipt(previous), "The previous full-price receipts retain their original amount")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(receipt))
	t.assert_true(Market.validate_receipt(roundtrip), "Receipt validates after JSON numeric conversion")
	var receipts: Array[Dictionary] = [roundtrip]
	t.assert_eq(Market.income(receipts), offer.price, "Income sums validated art payments")
	receipts.append(roundtrip)
	t.assert_eq(Market.income(receipts), -1, "Duplicate receipts cannot be counted as independent income")
	var full_ledger: Array[Dictionary] = []
	full_ledger.resize(Market.MAX_SALES)
	full_ledger.fill(receipt)
	t.assert_false(Market.quote(sample_art(), full_ledger).can_sell, "Full ledger prevents further sale records")
	for key: String in ["price", "visible_shapes", "families", "colors", "coverage", "fingerprint", "signature"]:
		var invalid: Dictionary = receipt.duplicate(true)
		match key:
			"price": invalid.price = int(receipt.price) + 100
			"visible_shapes": invalid.visible_shapes = 0
			"families": invalid.families = 0
			"colors": invalid.colors = 0
			"coverage": invalid.coverage = NAN
			"fingerprint": invalid.fingerprint = "invalid"
			"signature": invalid.signature = str(receipt.signature).left(30)
		t.assert_false(Market.validate_receipt(invalid), "Receipt rejects malformed " + key)
	var unknown: Dictionary = receipt.duplicate(true)
	unknown.document = sample_art().serialize()
	t.assert_false(Market.validate_receipt(unknown), "Receipts reject unexpected nested document payloads")
	unknown = receipt.duplicate(true)
	unknown.price = -100
	receipts = [unknown]
	t.assert_eq(Market.income(receipts), -1, "Invalid ledger income is never silently paid")
	t.assert_true(Market.receipt_from_quote(Market.quote(Model.new())).is_empty(), "Unsellable artwork creates no receipt")
	var abstract_drawing: DrawingDocument = _abstract_drawing(5, ["rectangle", "square", "trapezoid"], Vector2(160, 140))
	var economy: ConstructionState = Economy.new()
	var sale: Dictionary = economy.sell_art(abstract_drawing.serialize(), "한 색 사각형")
	t.assert_true(sale.ok, "A monochrome abstract drawing earns payment through the state API")
	if not sale.ok: return
	var mono_receipt: Dictionary = sale.receipt
	t.assert_eq(mono_receipt.colors, 1, "Monochrome receipts keep the original raster metadata")
	var restored: ConstructionState = Economy.new()
	t.assert_true(restored.restore(JSON.parse_string(JSON.stringify(economy.serialize()))), "A state with a discounted monochrome receipt restores")
	t.assert_eq(restored.art_income(), int(sale.price), "Restoring the monochrome sale keeps the credited amount")
	t.assert_false(restored.sell_art(abstract_drawing.serialize()).ok, "The restored ledger still prevents a repeat sale")

static func _test_duplicate_sales(t: Node) -> void:
	var drawing: DrawingDocument = sample_art()
	var offer: Dictionary = Market.quote(drawing)
	var sold: Array[Dictionary] = [Market.receipt_from_quote(offer)]
	t.assert_false(Market.quote(drawing, sold).can_sell, "Same drawing cannot be sold twice")
	var encoded: Dictionary = drawing.serialize()
	for shape: Dictionary in encoded.shapes: shape.id = int(shape.id) + 1000
	encoded.selected_id = -1
	var copy: DrawingDocument = Model.new()
	t.assert_true(copy.restore(encoded), "Copy with new IDs remains a valid document")
	t.assert_false(Market.quote(copy, sold).can_sell, "New IDs cannot resell the same artwork")
	copy.set_background("galaxy")
	copy.set_masterpiece("starry_night")
	copy.select_shape(int(copy.shapes[0].id))
	copy.shift_selected_layer(1)
	t.assert_false(Market.quote(copy, sold).can_sell, "Background, mode, selection and layer metadata cannot resell art")
	copy.move_selected(Vector2(copy.get_selected().position) + Vector2(2, 0))
	t.assert_false(Market.quote(copy, sold).can_sell, "A tiny nudge cannot resell the same art")
	var shifted: DrawingDocument = sample_art()
	for shape: Dictionary in shifted.shapes:
		shifted.select_shape(int(shape.id))
		shifted.move_selected(Vector2(shifted.get_selected().position) + Vector2(35, 30))
	t.assert_true(Market.quote(shifted).can_sell, "Translating the sample house keeps its geometry requirements satisfied")
	t.assert_false(Market.quote(shifted, sold).can_sell, "Translating the whole artwork does not create a new sale")
	var duplicate: DrawingDocument = sample_art()
	var part: Dictionary = duplicate.shapes[0]
	duplicate.add_sized_shape(str(part.kind), part.position, QuadrilateralMath.bounds(part.vertices).size, part.color)
	for _layer: int in range(duplicate.shapes.size() - 1): duplicate.shift_selected_layer(-1)
	t.assert_true(Market.quote(duplicate).can_sell, "A duplicate body hidden behind the house preserves its six visible pieces")
	t.assert_false(Market.quote(duplicate, sold).can_sell, "An exactly overlapping duplicate cannot create a sale")
	var different: DrawingDocument = ArtSamples.house(true)
	t.assert_true(Market.quote(different, sold).can_sell, "A visibly different composition remains sellable")
	var layered: DrawingDocument = sample_art()
	var window: Dictionary = layered.shapes[3]
	layered.add_sized_shape("square", window.position, QuadrilateralMath.bounds(window.vertices).size, Color.GREEN)
	var layered_offer: Dictionary = Market.quote(layered)
	t.assert_true(layered_offer.can_sell, "A differently colored overlapping window preserves the qualifying geometry")
	var layered_sales: Array[Dictionary] = [Market.receipt_from_quote(layered_offer)]
	for _layer: int in range(layered.shapes.size() - 1): layered.shift_selected_layer(-1)
	t.assert_true(Market.quote(layered).can_sell, "Moving the overlapping window behind the house leaves a valid original house")
	t.assert_false(Market.quote(layered, layered_sales).can_sell, "Reordering occluding layers alone cannot generate another payment")

static func _test_sale_ui(t: Node) -> void:
	var studio: DrawingStudio = Studio.new()
	studio.testing = true
	t.add_child(studio)
	await t.get_tree().process_frame
	var economy: ConstructionState = Economy.new()
	studio.configure_economy(economy)
	studio.document.restore(sample_art().serialize())
	var requests: Array[Dictionary] = []
	studio.art_sale_requested.connect(func(data: Dictionary): requests.append(data))
	t.assert_false(studio._sale_button.disabled, "Connected economy enables the art sale button")
	studio._open_sale()
	t.assert_true(studio._sale_dialog.visible, "Sale opens a reviewable price confirmation")
	t.assert_false(studio._sale_details.text.contains("나무"), "The sale dialog has no tree requirement")
	for check: Dictionary in studio._sale_offer.checks:
		t.assert_true(studio._sale_details.text.contains(str(check.label)), "The sale dialog shows " + str(check.id))
	studio._sale_title.text = "   "
	studio._sale_title.text_changed.emit(studio._sale_title.text)
	t.assert_true(studio._sale_dialog.get_ok_button().disabled, "Blank titles cannot authorize a sale")
	studio._confirm_sale()
	t.assert_eq(requests.size(), 0, "Blank title confirmation never dispatches a sale")
	studio._sale_title.text = "색깔 우주선"
	studio._sale_title.text_changed.emit(studio._sale_title.text)
	t.assert_true(studio._sale_dialog.get_ok_button().disabled, "A title alone cannot submit unnamed artwork without a description")
	studio._sale_author.text = "네모 작가"
	studio._sale_author.text_changed.emit(studio._sale_author.text)
	t.assert_true(studio._sale_dialog.get_ok_button().disabled, "Artwork still needs its own description after an author is provided")
	studio._sale_description.text = "사각형으로 만든 색깔 우주선이에요."
	studio._sale_description.text_changed.emit()
	t.assert_false(studio._sale_dialog.get_ok_button().disabled, "A finished composition enables confirmation")
	var drawing_before: Dictionary = studio.document.serialize()
	studio._sale_dialog.hide()
	studio._confirm_sale()
	t.assert_eq(requests.size(), 0, "Cancelled or hidden confirmation cannot sell a drawing")
	t.assert_eq(studio.document.serialize(), drawing_before, "Cancelling a sale preserves drawing and history")
	studio._open_sale()
	studio._confirm_sale()
	studio._confirm_sale()
	t.assert_eq(requests.size(), 1, "Repeated confirmations dispatch only one payment request")
	t.assert_eq(requests[0].title, "색깔 우주선", "Sale intent includes the title chosen in the dialog")
	t.assert_eq(requests[0].author, "네모 작가", "Sale intent includes the artist's display name")
	t.assert_eq(requests[0].description, "사각형으로 만든 색깔 우주선이에요.", "Sale intent includes the actual artwork description")
	t.assert_eq(requests[0].document, drawing_before, "Sale intent captures the exact quoted drawing")
	t.assert_true(studio._sale_button.disabled, "Sale button is blocked while persistence is pending")
	studio.show_sale_result({"ok": false, "error": "테스트 저장 실패"})
	t.assert_false(studio._sale_button.disabled, "Persistence failure returns control to the artist")
	t.assert_eq(studio.document.serialize(), drawing_before, "Failed sale never clears the artwork")
	studio._open_sale()
	var result: Dictionary = economy.sell_art(studio.document.serialize())
	studio._confirm_sale()
	t.assert_eq(requests.size(), 1, "An economy change invalidates a previously displayed sale offer")
	t.assert_true(studio._sale_dialog.get_ok_button().disabled, "Duplicate sale confirmation is visibly disabled")
	studio._sale_dialog.hide()
	studio.show_sale_result(result)
	t.assert_true(studio._status.text.contains("판매했어요"), "Successful sale gives clear Korean feedback")
	studio.document.undo()
	t.assert_eq(economy.art_sales.size(), 1, "Undoing artwork edits never undoes an economy payment")
	studio.tutorial_blocked = true
	studio._open_sale()
	t.assert_false(studio._sale_dialog.visible, "Tutorial input ownership prevents a new sale dialog")
	studio.tutorial_blocked = false
	studio._open_sale()
	studio.hide()
	t.assert_false(studio._sale_dialog.visible, "Leaving the studio closes its sale confirmation")
	studio.queue_free()
	await t.get_tree().process_frame
