class_name TestArtMarket
extends RefCounted

const Market = preload("res://scripts/economy/art_market.gd")
const Model = preload("res://scripts/core/drawing_document.gd")
const Studio = preload("res://scenes/drawing/drawing_studio.gd")
const Economy = preload("res://scripts/construction/construction_state.gd")
const ArtSamples = preload("res://tests/art_sale_samples.gd")
const CommissionCatalog = preload("res://scripts/economy/art_commission_catalog.gd")

static func run(t: Node) -> void:
	_test_quotes(t)
	_test_freeform_quote(t)
	_test_sale_requirements(t)
	_test_commission_quotes(t)
	_test_receipts(t)
	_test_duplicate_sales(t)
	await _test_sale_ui(t)

static func sample_art() -> DrawingDocument:
	return ArtSamples.house()

static func _test_freeform_quote(t: Node) -> void:
	var drawing: DrawingDocument = Model.new()
	drawing.add_sized_shape("rectangle", Vector2.ZERO, Vector2(860, 450), Color.CORAL)
	var kinds: Array[String] = ["square", "rhombus", "trapezoid", "parallelogram", "freeform"]
	for index: int in range(kinds.size()):
		drawing.add_sized_shape(kinds[index], Vector2(-280 + index * 140, 0), Vector2(100, 72), Color.DARK_BLUE)
	var center: Vector2 = drawing.get_selected().position
	var irregular: PackedVector2Array = PackedVector2Array([Vector2(-35, -43), Vector2(55, -25), Vector2(40, 38), Vector2(-50, 28)])
	drawing.transform_selected(irregular, center)
	drawing.work_msec = Model.REQUIRED_WORK_MSEC
	var offer: Dictionary = Market.quote(drawing, [], ArtSamples.COMMISSION_ID)
	t.assert_eq(offer.families, 6, "An irregular visible quadrilateral counts alongside all five named families")
	var receipt: Dictionary = Market.receipt_from_quote(offer, "여섯 가지 사각형")
	t.assert_true(Market.validate_receipt(receipt), "A six-family commission can be paid and its receipt reloaded")
	drawing.transform_selected(QuadrilateralMath.create_vertices("square", Vector2(72, 72)), center)
	t.assert_eq(Market.quote(drawing).families, 5, "A freeform edited into a square counts once with the other squares")

static func _test_quotes(t: Node) -> void:
	var drawing: DrawingDocument = sample_art()
	var before: Dictionary = drawing.serialize()
	var history: int = drawing.command_manager.undo_stack.size()
	var offer: Dictionary = Market.quote(drawing)
	t.assert_true(offer.can_sell, "The house fixture meets the area and working-time requirements")
	t.assert_eq(offer.visible_shapes, 6, "Quote counts actual visible quadrilaterals")
	t.assert_eq(offer.families, 3, "Rectangle, trapezoid and square geometry avoid inclusive double counting")
	t.assert_eq(offer.colors, 3, "Visible colors are counted once each")
	var check_ids: Array[String] = []
	for check: Dictionary in offer.checks:
		check_ids.append(str(check.id))
		t.assert_true(bool(check.met), "The fixture passes each stated sale requirement: " + str(check.label))
	t.assert_eq(check_ids, ["coverage", "time"], "Eligibility checks cover paper area and drawing time")
	t.assert_false(offer.has("full_price") or offer.has("completion_ratio"), "The offer supplies a price without a satisfaction or discount breakdown")
	t.assert_gt(offer.price, 1000000, "Art sales contribute meaningful spaceship savings")
	t.assert_le(offer.price, Market.MAX_PRICE, "Art offers respect the long-term progression cap")
	t.assert_eq(int(offer.price) % 100, 0, "Art prices use 100 won increments")
	t.assert_eq(drawing.serialize(), before, "Quoting never changes the player's drawing")
	t.assert_eq(drawing.command_manager.undo_stack.size(), history, "Quoting never changes undo history")
	t.assert_false(Market.quote(Model.new()).can_sell, "A background alone is not sellable artwork")
	var hidden: DrawingDocument = Model.new()
	for index: int in range(8):
		hidden.add_sized_shape("square", Vector2.ZERO, Vector2(480, 480), Color.RED if index % 2 == 0 else Color.BLUE)
	hidden.work_msec = Model.REQUIRED_WORK_MSEC
	var uncovered: DrawingDocument = Model.new()
	uncovered.add_sized_shape("square", Vector2.ZERO, Vector2(480, 480), Color.BLUE)
	uncovered.work_msec = Model.REQUIRED_WORK_MSEC
	var layered_offer: Dictionary = Market.quote(hidden)
	t.assert_eq(layered_offer.visible_shapes, 1, "Fully obscured copies do not inflate shape count")
	t.assert_eq(layered_offer.price, Market.quote(uncovered).price, "Stacking identical shapes cannot increase the sale price")
	t.assert_true(layered_offer.can_sell and layered_offer.price > 0, "One visible shape is eligible if its coverage and time qualify")
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

static func _tiled_drawing(columns: int) -> DrawingDocument:
	var drawing: DrawingDocument = Model.new()
	for index: int in range(columns):
		var position: Vector2 = Vector2(-240 + (index + 0.5) * 480.0 / columns, 0)
		drawing.add_sized_shape("rectangle", position, Vector2(480.0 / columns, 480), Color.CORAL)
	drawing.work_msec = Model.REQUIRED_WORK_MSEC
	return drawing


static func _test_sale_requirements(t: Node) -> void:
	var exact: DrawingDocument = Model.new()
	exact.add_sized_shape("square", Vector2.ZERO, Vector2(480, 480), Color.CORAL)
	exact.work_msec = Model.REQUIRED_WORK_MSEC - 1
	_assert_blocked_payment(t, exact, "time")
	exact.work_msec = Model.REQUIRED_WORK_MSEC
	var offer: Dictionary = Market.quote(exact)
	t.assert_true(offer.can_sell, "Exactly 40% of the paper and exactly five minutes qualify")
	t.assert_float_approx(float(offer.coverage), 0.4, 0.000001, "The square covers 576 grid samples")
	var just_below: DrawingDocument = Model.new()
	just_below.add_sized_shape("rectangle", Vector2(10, 10), Vector2(460, 500), Color.CORAL)
	just_below.work_msec = Model.REQUIRED_WORK_MSEC
	t.assert_float_approx(float(Market.quote(just_below).coverage), 575.0 / 1440.0, 0.000001, "A rectangular footprint covers one fewer sample")
	_assert_blocked_payment(t, just_below, "coverage")
	var previous_offer: Dictionary = offer
	for piece_count: int in [2, 12, 13, 24]:
		var more_pieces: Dictionary = Market.quote(_tiled_drawing(piece_count))
		t.assert_true(more_pieces.can_sell, "A tiled picture meets both sale requirements")
		t.assert_eq(more_pieces.visible_shapes, piece_count, "Each tile counts as one visible shape")
		t.assert_float_approx(float(more_pieces.coverage), float(offer.coverage), 0.000001, "The count comparison holds occupied paper area constant")
		t.assert_gt(more_pieces.price, previous_offer.price, "Additional visible shapes increase the price")
		previous_offer = more_pieces

static func _assert_blocked_payment(t: Node, drawing: DrawingDocument, missing_goal: String) -> void:
	var offer: Dictionary = Market.quote(drawing)
	t.assert_false(offer.can_sell, "A drawing with an unmet %s requirement cannot be sold" % missing_goal)
	for check: Dictionary in offer.checks:
		t.assert_eq(bool(check.met), check.id != missing_goal, "Only the %s goal is unmet in this fixture" % missing_goal)
	t.assert_eq(offer.price, 0, "A blocked quote supplies no sale price")
	var economy: ConstructionState = Economy.new()
	economy.accept_art_commission(ArtSamples.COMMISSION_ID)
	var original: Dictionary = drawing.serialize()
	var history: int = drawing.command_manager.undo_stack.size()
	var payment: Dictionary = economy.sell_art(original, "사각형 모임")
	t.assert_false(payment.ok, "The ledger rejects an ineligible sale at its own entry point")
	t.assert_eq(economy.balance, Economy.INITIAL_BALANCE, "A blocked sale keeps the starting balance")
	t.assert_eq(drawing.serialize(), original, "Selling through the ledger preserves the player's editable composition")
	t.assert_eq(drawing.command_manager.undo_stack.size(), history, "Selling through the ledger preserves the drawing Undo history")

static func _test_commission_quotes(t: Node) -> void:
	var catalog: Array[Dictionary] = CommissionCatalog.all()
	var commission_id: String = ArtSamples.COMMISSION_ID
	t.assert_eq(catalog.size(), 9, "The drawing studio has nine independent commission briefs")
	var drawing: DrawingDocument = ArtSamples.poster()
	var original: Dictionary = drawing.serialize()
	var full: Dictionary = Market.quote(drawing, [], commission_id)
	var partial: Dictionary = Market.quote(ArtSamples.poster(false), [], commission_id)
	t.assert_true(full.can_sell and partial.can_sell, "A drawing can be submitted while some client requirements are incomplete")
	t.assert_eq(full.score, 100, "Fulfilling the selected brief gives full client satisfaction")
	t.assert_lt(partial.score, full.score, "Missing a requested shape family lowers client satisfaction")
	t.assert_gt(partial.score, 0, "A qualifying partial drawing earns positive satisfaction")
	t.assert_gt(full.price, partial.price, "Higher satisfaction earns a higher reward")
	t.assert_eq(full.visible_shapes, partial.visible_shapes, "Changing the brief's family requirement keeps piece counts comparable")
	t.assert_eq(full.coverage, partial.coverage, "The family comparison covers the same amount of paper")
	t.assert_eq(full.commission_id, commission_id, "A quote identifies the specific brief the player accepted")
	var other: Dictionary = Market.quote(drawing, [], "space_mural")
	t.assert_lt(other.score, full.score, "The same painting is reviewed against the selected brief")
	t.assert_true(other.can_sell and other.price > 0, "Missing a space mural goal never rejects an eligible submission")
	t.assert_false(Market.quote(drawing, [], "unknown").can_sell, "An unknown brief never authorizes payment")
	var requirement_ids: Array[String] = []
	for requirement: Dictionary in full.requirements:
		requirement_ids.append(str(requirement.id))
		t.assert_true(bool(requirement.met), "The review marks each fulfilled client requirement complete")
	t.assert_eq(requirement_ids, ["coverage", "pieces", "families"], "Client review identifies each concrete requirement")
	t.assert_eq(drawing.serialize(), original, "Reviewing different briefs leaves the artist's work unchanged")
	var expanded: DrawingDocument = ArtSamples.poster()
	expanded.add_sized_shape("square", Vector2(0, 120), Vector2(80, 80), Color.GOLD)
	var detailed: Dictionary = Market.quote(expanded, [], commission_id)
	t.assert_eq(detailed.score, full.score, "A full brief stays at 100 percent when an artist adds a visible detail")
	t.assert_gt(detailed.price, full.price, "An additional visible shape still increases a qualifying commission reward")
	drawing.work_msec = Model.REQUIRED_WORK_MSEC - 1
	t.assert_false(Market.quote(drawing, [], commission_id).can_sell, "Even a full client composition requires five minutes of editing")
	var too_small: DrawingDocument = Model.new()
	too_small.add_sized_shape("square", Vector2.ZERO, Vector2(400, 400), Color.CORAL)
	too_small.work_msec = Model.REQUIRED_WORK_MSEC
	t.assert_false(Market.quote(too_small, [], commission_id).can_sell, "Client satisfaction never overrides the basic paper area threshold")
	var receipt: Dictionary = Market.receipt_from_quote(partial, "공원 안내 그림")
	t.assert_true(Market.validate_receipt(receipt), "A partial commission earns a receipt with independently verified satisfaction")
	t.assert_eq(receipt.version, Market.RECEIPT_VERSION, "The current receipt records commission terms")
	t.assert_eq(receipt.score, partial.score, "The receipt records the satisfaction at payment")
	t.assert_eq(receipt.size(), 11, "The commission receipt stores metadata without a document snapshot")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(receipt))
	t.assert_true(Market.validate_receipt(restored), "A commission receipt validates after JSON round-tripping")
	for key: String in ["price", "score", "commission_id"]:
		var invalid: Dictionary = restored.duplicate()
		match key:
			"price": invalid.price += 100
			"score": invalid.score = 100
			"commission_id": invalid.commission_id = "unknown"
		t.assert_false(Market.validate_receipt(invalid), "Changing a stored commission's %s invalidates the receipt" % key)

static func _test_receipts(t: Node) -> void:
	var offer: Dictionary = Market.quote(sample_art())
	var receipt: Dictionary = Market.receipt_from_quote(offer, "나의 우주 그림")
	t.assert_true(Market.validate_receipt(receipt), "A quote produces a valid compact receipt")
	t.assert_eq(receipt.version, 4, "New receipts record the visible-piece pricing revision")
	t.assert_eq(receipt.size(), 9, "Receipt keeps compact scalar fields rather than a document snapshot")
	_test_legacy_receipts(t)
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
	var abstract_drawing: DrawingDocument = _tiled_drawing(5)
	var economy: ConstructionState = Economy.new()
	economy.accept_art_commission(ArtSamples.COMMISSION_ID)
	var sale: Dictionary = economy.sell_art(abstract_drawing.serialize(), "한 색 사각형")
	t.assert_true(sale.ok, "A monochrome abstract drawing earns payment through the state API")
	if not sale.ok: return
	var mono_receipt: Dictionary = sale.receipt
	t.assert_eq(mono_receipt.colors, 1, "Monochrome receipts keep the original raster metadata")
	var restored: ConstructionState = Economy.new()
	t.assert_true(restored.restore(JSON.parse_string(JSON.stringify(economy.serialize()))), "A state with a monochrome receipt restores")
	t.assert_eq(restored.art_income(), int(sale.price), "Restoring the monochrome sale keeps the credited amount")
	restored.accept_art_commission(ArtSamples.COMMISSION_ID)
	t.assert_false(restored.sell_art(abstract_drawing.serialize()).ok, "The restored ledger still prevents a repeat sale")

static func _test_legacy_receipts(t: Node) -> void:
	var empty_samples: String = "___".repeat(1266)
	var historical: Array[Dictionary] = [
		{
			"version": 1, "title": "이전 그림 1", "fingerprint": "a".repeat(64),
			"signature": "f00".repeat(58) + "0f0".repeat(58) + "00f".repeat(58) + empty_samples,
			"visible_shapes": 6, "families": 3, "colors": 3, "price": 3170800, "coverage": 174.0 / 1440.0,
		},
		{
			"version": 2, "title": "이전 그림 2", "fingerprint": "b".repeat(64),
			"signature": "f00".repeat(174) + empty_samples,
			"visible_shapes": 6, "families": 3, "colors": 1, "price": 3070800, "coverage": 174.0 / 1440.0,
		},
		{
			"version": 3, "title": "이전 그림 3", "fingerprint": "c".repeat(64),
			"signature": "00f".repeat(174) + empty_samples,
			"visible_shapes": 2, "families": 1, "colors": 1, "price": 1706000, "coverage": 174.0 / 1440.0,
		},
	]
	for receipt: Dictionary in historical:
		t.assert_true(Market.validate_receipt(receipt), "Version %d retains its historical price" % int(receipt.version))
	t.assert_eq(Market.income(historical), 7947600, "The ledger sums historical versions at their original prices")
	var below_new_coverage: Dictionary = historical[2].duplicate()
	below_new_coverage.version = 4
	below_new_coverage.price = 600000
	t.assert_false(Market.validate_receipt(below_new_coverage), "The current receipt version enforces the new coverage requirement")

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
	copy.shift_selected_layer(-1)
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
	economy.accept_art_commission(ArtSamples.COMMISSION_ID)
	studio.document.restore(sample_art().serialize())
	var requests: Array[Dictionary] = []
	studio.art_sale_requested.connect(func(data: Dictionary): requests.append(data))
	t.assert_false(studio._sale_button.disabled, "Connected economy enables the art sale button")
	studio._open_sale()
	t.assert_true(studio._sale_dialog.visible, "Sale opens a reviewable price confirmation")
	t.assert_false(studio._sale_details.text.contains("나무"), "The sale dialog has no tree requirement")
	for check: Dictionary in studio._sale_offer.checks:
		t.assert_true(studio._sale_details.text.contains(str(check.label)), "The sale dialog shows " + str(check.id))
	t.assert_eq(studio._sale_price.text, "받을 보상 " + ConstructionCatalog.format_won(int(studio._sale_offer.price)), "The confirmation shows only the final reward")
	t.assert_true(studio._sale_details.text.contains("의뢰인의 만족도"), "The confirmation includes client satisfaction")
	for price_term: String in ["계산식", "줄어든 금액", "기준 금액"]:
		t.assert_false(studio._sale_details.text.contains(price_term), "Pricing inputs stay out of the confirmation breakdown")
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
	t.assert_eq(requests[0].commission_revision, economy.art_commission_revision, "Submission captures the accepted commission's revision")
	t.assert_true(studio._sale_button.disabled, "Sale button is blocked while persistence is pending")
	studio.show_sale_result({"ok": false, "error": "테스트 저장 실패"})
	t.assert_false(studio._sale_button.disabled, "Persistence failure returns control to the artist")
	t.assert_eq(studio.document.serialize(), drawing_before, "Failed sale never clears the artwork")
	studio._open_sale()
	var result: Dictionary = economy.sell_art(studio.document.serialize())
	studio._confirm_sale()
	t.assert_eq(requests.size(), 1, "An economy change invalidates a previously displayed sale offer")
	t.assert_true(not studio._sale_dialog.visible or studio._sale_dialog.get_ok_button().disabled, "Duplicate sale confirmation is unavailable")
	studio._sale_dialog.hide()
	studio.show_sale_result(result)
	t.assert_true(studio._status.text.contains("의뢰"), "Successful commission gives clear Korean feedback")
	studio._commission_dialog.hide()
	studio.document.undo()
	t.assert_eq(economy.art_sales.size(), 1, "Undoing artwork edits never undoes an economy payment")
	studio.tutorial_blocked = true
	studio._open_sale()
	t.assert_false(studio._sale_dialog.visible, "Tutorial input ownership prevents a new sale dialog")
	studio.tutorial_blocked = false
	economy.accept_art_commission(ArtSamples.COMMISSION_ID)
	studio._open_sale()
	studio.hide()
	t.assert_false(studio._sale_dialog.visible, "Leaving the studio closes its sale confirmation")
	studio.queue_free()
	await t.get_tree().process_frame
