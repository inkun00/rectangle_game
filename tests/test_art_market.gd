class_name TestArtMarket
extends RefCounted

const Market = preload("res://scripts/economy/art_market.gd")
const Model = preload("res://scripts/core/drawing_document.gd")
const Studio = preload("res://scenes/drawing/drawing_studio.gd")
const Economy = preload("res://scripts/construction/construction_state.gd")
const ArtSamples = preload("res://tests/test_art_composition.gd")

static func run(t: Node) -> void:
	_test_quotes(t)
	_test_quality_gates(t)
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
	t.assert_true(offer.can_sell, "A connected house with body, roof, door, windows and chimney can be sold")
	t.assert_eq(offer.visible_shapes, 6, "Quote counts actual visible quadrilaterals")
	t.assert_eq(offer.families, 3, "Rectangle, trapezoid and square geometry avoid inclusive double counting")
	t.assert_eq(offer.colors, 3, "Visible colors are counted once each")
	t.assert_true(not str(offer.subject).is_empty(), "A qualifying house quote identifies the recognized subject")
	t.assert_true(not offer.checks.is_empty(), "A quality quote exposes reviewable requirement checks")
	for check: Dictionary in offer.checks:
		t.assert_true(bool(check.met), "A saleable house passes every stated quality check: " + str(check.label))
	t.assert_gt(offer.price, 1000000, "Art sales contribute meaningful spaceship savings")
	t.assert_le(offer.price, Market.MAX_PRICE, "Art offers respect the long-term progression cap")
	t.assert_eq(int(offer.price) % 100, 0, "Art prices use 100 won increments")
	t.assert_eq(drawing.serialize(), before, "Quoting never changes the player's drawing")
	t.assert_eq(drawing.command_manager.undo_stack.size(), history, "Quoting never changes undo history")
	t.assert_false(Market.quote(Model.new()).can_sell, "A background alone is not sellable artwork")
	var hidden: DrawingDocument = Model.new()
	for index: int in range(8):
		hidden.add_sized_shape("square", Vector2.ZERO, Vector2(240, 240), Color.RED if index % 2 == 0 else Color.BLUE)
	t.assert_eq(Market.quote(hidden).visible_shapes, 1, "Fully obscured copies do not inflate shape count")
	t.assert_false(Market.quote(hidden).can_sell, "Stacking identical shapes cannot manufacture sale income")
	var transparent: DrawingDocument = sample_art()
	for shape: Dictionary in transparent.shapes:
		transparent.select_shape(int(shape.id))
		transparent.set_color(Color(1, 0, 0, 0.3))
	t.assert_false(Market.quote(transparent).can_sell, "Almost invisible polygons do not qualify for payment")
	var tiny: DrawingDocument = Model.new()
	for index: int in range(6): tiny.add_sized_shape("square", Vector2(index * 70 - 200, 0), Vector2(42, 42), Color.RED if index % 2 == 0 else Color.BLUE)
	t.assert_false(Market.quote(tiny).can_sell, "Very small total coverage does not qualify for payment")
	var one_color: DrawingDocument = sample_art()
	for shape: Dictionary in one_color.shapes:
		one_color.select_shape(int(shape.id))
		one_color.set_color(Color.CORAL)
	t.assert_false(Market.quote(one_color).can_sell, "Artwork needs two visible colors")
	var relabeled: Dictionary = drawing.serialize()
	for shape: Dictionary in relabeled.shapes: shape.kind = "trapezoid"
	var inclusive: DrawingDocument = Model.new()
	t.assert_true(inclusive.restore(relabeled), "The house's rectangles, squares and roof all remain inclusive trapezoids")
	t.assert_eq(Market.quote(inclusive).families, offer.families, "Relabeling family metadata cannot increase value")
	t.assert_eq(Market.quote(inclusive).price, offer.price, "Price follows geometry rather than chosen family label")

static func _test_quality_gates(t: Node) -> void:
	var tiles: DrawingDocument = Model.new()
	var colors: Array[Color] = [Color.CORAL, Color.DODGER_BLUE, Color.GOLD]
	for index: int in range(6):
		var kind: String = "square" if index % 2 == 0 else "rectangle"
		tiles.add_sized_shape(kind, Vector2(-280 + (index % 3) * 250, -140 if index < 3 else 120), Vector2(150, 140), colors[index % 3])
	_assert_rejected_without_payment(t, tiles, "The former six disconnected color tiles no longer count as a finished composition")
	var row: DrawingDocument = Model.new()
	for index: int in range(6):
		row.add_sized_shape("rectangle", Vector2(-375 + index * 150, 0), Vector2(120, 140), colors[index % 3])
	_assert_rejected_without_payment(t, row, "A uniform row cannot qualify merely by meeting shape, color and area totals")
	var overlap: DrawingDocument = Model.new()
	var positions: Array[Vector2] = [Vector2(-80, -30), Vector2(30, 45), Vector2(90, -15), Vector2(-40, 50), Vector2(45, -40), Vector2.ZERO]
	for index: int in range(positions.size()):
		overlap.add_sized_shape("rectangle", positions[index], Vector2(260, 180), colors[index % 3])
		overlap.rotate_selected(13 + index * 17)
	_assert_rejected_without_payment(t, overlap, "Unstructured overlapping quadrilaterals do not automatically become a sellable object")
	var color_dot: DrawingDocument = sample_art()
	for shape: Dictionary in color_dot.shapes:
		color_dot.select_shape(int(shape.id))
		color_dot.set_color(Color.CORAL)
	color_dot.add_sized_shape("square", Vector2(0, 0), Vector2(40, 40), Color.DODGER_BLUE)
	_assert_rejected_without_payment(t, color_dot, "A tiny contrasting color dot cannot satisfy the meaningful-color requirement")
	var similar: DrawingDocument = sample_art()
	for index: int in range(similar.shapes.size()):
		similar.select_shape(int(similar.shapes[index].id))
		similar.set_color(Color(0.5 if index % 2 == 0 else 0.6, 0.5, 0.5))
	_assert_rejected_without_payment(t, similar, "Nearly indistinguishable colors do not count as meaningful visual contrast")
	var concealed_openings: DrawingDocument = sample_art()
	var wall_color: Color = concealed_openings.shapes[0].color
	for index: int in [2, 3, 4]:
		concealed_openings.select_shape(int(concealed_openings.shapes[index].id))
		concealed_openings.set_color(wall_color)
	_assert_rejected_without_payment(t, concealed_openings, "Doors and windows painted exactly like their supporting wall do not form visible house details")

static func _assert_rejected_without_payment(t: Node, drawing: DrawingDocument, message: String) -> void:
	var offer: Dictionary = Market.quote(drawing)
	t.assert_false(offer.can_sell, message)
	var economy: ConstructionState = Economy.new()
	var ledger: Dictionary = economy.serialize()
	var original: Dictionary = drawing.serialize()
	var history: int = drawing.command_manager.undo_stack.size()
	t.assert_false(economy.sell_art(original, "새 작품 판매 시도").ok, "A rejected quality quote cannot be bypassed by directly requesting payment")
	t.assert_eq(economy.serialize(), ledger, "Rejected quality leaves money, receipts and spaceship progress unchanged")
	t.assert_eq(drawing.serialize(), original, "A rejected quality check preserves the player's editable composition")
	t.assert_eq(drawing.command_manager.undo_stack.size(), history, "A rejected quality check preserves drawing Undo history")

static func _test_receipts(t: Node) -> void:
	var offer: Dictionary = Market.quote(sample_art())
	var receipt: Dictionary = Market.receipt_from_quote(offer, "나의 우주 그림")
	t.assert_true(Market.validate_receipt(receipt), "A quote produces a valid compact receipt")
	t.assert_eq(receipt.size(), 9, "Receipt keeps compact scalar fields rather than a document snapshot")
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
			"visible_shapes": invalid.visible_shapes = 129
			"families": invalid.families = 6
			"colors": invalid.colors = 1
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
	t.assert_true(Market.quote(shifted).can_sell, "Translating the connected house keeps its structural sale requirements satisfied")
	t.assert_false(Market.quote(shifted, sold).can_sell, "Translating the whole artwork does not create a new sale")
	var duplicate: DrawingDocument = sample_art()
	var part: Dictionary = duplicate.shapes[0]
	duplicate.add_sized_shape(str(part.kind), part.position, QuadrilateralMath.bounds(part.vertices).size, part.color)
	for _layer: int in range(duplicate.shapes.size() - 1): duplicate.shift_selected_layer(-1)
	t.assert_true(Market.quote(duplicate).can_sell, "A duplicate body hidden behind the house preserves all six visible structural pieces")
	t.assert_false(Market.quote(duplicate, sold).can_sell, "An exactly overlapping duplicate cannot create a sale")
	var different: DrawingDocument = ArtSamples.house(true)
	t.assert_true(Market.quote(different, sold).can_sell, "A visibly different composition remains sellable")
	var layered: DrawingDocument = sample_art()
	var window: Dictionary = layered.shapes[3]
	layered.add_sized_shape("square", window.position, QuadrilateralMath.bounds(window.vertices).size, Color.GREEN)
	var layered_offer: Dictionary = Market.quote(layered)
	t.assert_true(layered_offer.can_sell, "A differently colored overlapping window still forms a complete recognizable house")
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
