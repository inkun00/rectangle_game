class_name TestDrawingSaleFlow
extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")
const Studio = preload("res://scenes/drawing/drawing_studio.gd")
const Drawing = preload("res://scripts/core/drawing_document.gd")
const State = preload("res://scripts/construction/construction_state.gd")
const Market = preload("res://scripts/economy/art_market.gd")
const Saves = preload("res://scripts/construction/construction_save_store.gd")
const Transactions = preload("res://scripts/economy/progression_transactions.gd")

class SaleRenderer:
	extends RefCounted
	signal released
	var bytes: PackedByteArray = PackedByteArray()
	var suspended: bool = false
	var calls: int = 0
	var snapshots: Array[Dictionary] = []

	func render(_tree: SceneTree, document: DrawingDocument) -> PackedByteArray:
		calls += 1
		snapshots.append(document.serialize())
		if suspended: await released
		return bytes

static func run(t: Node) -> void:
	await _test_success_and_undo(t)
	await _test_failed_png(t, false)
	await _test_failed_png(t, true)
	await _test_failed_ledger_and_retry(t)
	await _test_failed_blank_draft(t)
	await _test_stale_render(t, false)
	await _test_stale_render(t, true)

static func _test_success_and_undo(t: Node) -> void:
	var directory: String = _directory()
	var app: QuadrilateralApp = await _app(t, directory)
	var studio: Studio = app._drawing_screen
	var ledger: State = app._construction_screen.state
	_fill_art(studio.document)
	studio.document.set_background("space_planets")
	studio.document.set_masterpiece("starry_night")
	studio.canvas.select_kind("trapezoid")
	studio.canvas.selected_trapezoid_variant = "right_left"
	var artwork: Dictionary = studio.document.serialize()
	var quote: Dictionary = Market.quote(studio.document)
	t.assert_true(quote.can_sell, "The full sale flow uses a real qualifying five-shape painting")
	t.assert_true(studio.save_drawing(false), "The original drawing draft exists before selling")
	var renderer: SaleRenderer = _renderer()
	studio.sale_png_renderer = renderer.render
	studio.testing = false
	studio._sale_button.pressed.emit()
	t.assert_true(studio._sale_dialog.visible, "The actual sale button opens the title and price dialog")
	_set_title(studio, "")
	t.assert_true(studio._sale_dialog.get_ok_button().disabled, "An empty title disables sale confirmation")
	studio._sale_dialog.confirmed.emit()
	t.assert_eq(renderer.calls, 0, "Even a directly emitted confirmation cannot export a painting with an empty title")
	t.assert_eq(ledger.balance, State.INITIAL_BALANCE, "Editing or rejecting a title never pays money")
	_set_title(studio, "  네모별의 첫 그림  ")
	t.assert_false(studio._sale_dialog.get_ok_button().disabled, "A valid user title enables the quoted sale")
	studio._sale_dialog.confirmed.emit()
	await t.get_tree().process_frame
	t.assert_eq(renderer.calls, 1, "One confirmed sale renders exactly one PNG")
	t.assert_eq(renderer.snapshots[0], artwork, "PNG rendering receives the exact painting that the player confirmed")
	t.assert_eq(ledger.art_sales.size(), 1, "The successful UI flow creates exactly one sale receipt")
	t.assert_eq(ledger.art_sales[0].title, "네모별의 첫 그림", "The receipt uses the player's trimmed title")
	t.assert_eq(ledger.balance, State.INITIAL_BALANCE + int(quote.price), "Payment matches the confirmed composition-based quote")
	var images: PackedStringArray = _images(studio.sold_art_directory)
	t.assert_eq(images.size(), 1, "Successful sale automatically creates one PNG in the designated folder")
	if images.size() == 1:
		t.assert_true(images[0].begins_with("네모별의 첫 그림_"), "The automatically saved filename contains the user's readable Korean title")
		t.assert_true(images[0].ends_with(".png"), "The automatically saved painting has a PNG extension")
		var saved_bytes: PackedByteArray = FileAccess.get_file_as_bytes(studio.sold_art_directory.path_join(images[0]))
		t.assert_eq(saved_bytes, renderer.bytes, "The complete rendered PNG bytes are durably stored before clearing the canvas")
		var decoded: Image = Image.new()
		t.assert_eq(decoded.load_png_from_buffer(saved_bytes), OK, "The saved painting is a decodable PNG")
		t.assert_eq(decoded.get_size(), Vector2i(960, 600), "The saved PNG retains the exporter's artwork dimensions")
	_assert_blank(t, studio.document)
	t.assert_eq(studio.canvas.selected_kind, "square", "A fresh canvas starts with the square drawing tool")
	t.assert_eq(studio.canvas.selected_trapezoid_variant, "symmetric", "A fresh canvas resets the previous trapezoid variant")
	t.assert_eq(studio._sale_title.text, "", "A completed sale clears the previous title input")
	t.assert_false(studio._sale_pending, "Successful export and sale release the pending transaction state")
	t.assert_false(studio._sale_busy.visible, "Successful export removes the busy overlay")
	t.assert_false(studio._sale_dialog.visible, "Successful sale closes its confirmation dialog")
	t.assert_true(studio._status.text.contains("네모별의 첫 그림") and studio._status.text.contains("PNG"), "The success status identifies the named artwork and its PNG save")
	t.assert_true(FileAccess.file_exists(studio.save_path), "The cleared canvas is actually persisted as the next drawing draft")
	var reloaded: Studio = Studio.new()
	reloaded.testing = true
	reloaded.save_path = studio.save_path
	reloaded.hide()
	t.add_child(reloaded)
	await t.get_tree().process_frame
	t.assert_true(reloaded.load_drawing(false), "The saved fresh draft loads through the drawing studio's normal loader")
	_assert_blank(t, reloaded.document)
	reloaded.free()
	studio.testing = true
	studio.document.undo()
	t.assert_eq(studio.document.serialize(), artwork, "Undo restores the complete sold drawing including its prior scene and selection")
	studio._sale_button.pressed.emit()
	_set_title(studio, "다른 이름으로 다시 판매")
	t.assert_true(studio._sale_dialog.get_ok_button().disabled, "Restoring and renaming the sold drawing cannot enable another sale")
	studio._sale_dialog.confirmed.emit()
	t.assert_eq(renderer.calls, 1, "A duplicate sale attempt does not export another PNG")
	t.assert_eq(ledger.art_sales.size(), 1, "Undo and rename cannot create another paid receipt")
	t.assert_eq(ledger.balance, State.INITIAL_BALANCE + int(quote.price), "Undoing canvas clearing never repeats the payout")
	t.assert_eq(_images(studio.sold_art_directory), images, "Duplicate attempts leave the original exported PNG unchanged")
	app.free()
	await t.get_tree().process_frame
	_cleanup(directory)

static func _test_failed_png(t: Node, blocked_directory: bool) -> void:
	var directory: String = _directory()
	var app: QuadrilateralApp = await _app(t, directory)
	var studio: Studio = app._drawing_screen
	_fill_art(studio.document)
	var artwork: Dictionary = studio.document.serialize()
	var ledger_before: Dictionary = app._construction_screen.state.serialize()
	var history: int = studio.document.command_manager.undo_stack.size()
	t.assert_true(studio.save_drawing(false), "A recoverable original draft exists before a failed PNG sale")
	var draft: String = FileAccess.get_file_as_string(studio.save_path)
	var renderer: SaleRenderer = _renderer()
	if blocked_directory:
		var blocker: FileAccess = FileAccess.open(studio.sold_art_directory, FileAccess.WRITE)
		blocker.store_string("existing file must survive")
		blocker.close()
	else:
		renderer.bytes = PackedByteArray()
	studio.sale_png_renderer = renderer.render
	studio.testing = false
	_confirm(studio, "저장되지 않은 그림")
	await t.get_tree().process_frame
	t.assert_eq(renderer.calls, 1, "A rejected PNG sale attempts rendering once")
	t.assert_eq(app._construction_screen.state.serialize(), ledger_before, "Empty render output or an unwritable image folder cannot pay money or sell the artwork")
	t.assert_eq(studio.document.serialize(), artwork, "A failed PNG save keeps every editable shape and scene setting")
	t.assert_eq(studio.document.command_manager.undo_stack.size(), history, "A failed PNG save does not add a canvas-clearing command")
	t.assert_eq(FileAccess.get_file_as_string(studio.save_path), draft, "A failed PNG save does not replace the original drawing draft")
	t.assert_false(studio._sale_pending, "A failed PNG save releases the pending UI state")
	t.assert_false(studio._sale_busy.visible, "A failed PNG save removes the busy overlay")
	t.assert_true(studio._sale_title.editable and not studio._sale_dialog.get_cancel_button().disabled, "A failed PNG save restores editable dialog controls for retry")
	t.assert_true(studio._status.text.contains("PNG") or studio._status.text.contains("폴더"), "The drawing screen explains why image export failed")
	if blocked_directory:
		t.assert_eq(FileAccess.get_file_as_string(studio.sold_art_directory), "existing file must survive", "An image destination blocked by a file preserves that existing file")
	else:
		t.assert_false(DirAccess.dir_exists_absolute(studio.sold_art_directory), "Empty render output creates no misleading image directory or file")
	studio.testing = true
	app.free()
	await t.get_tree().process_frame
	_cleanup(directory)

static func _test_failed_ledger_and_retry(t: Node) -> void:
	var directory: String = _directory()
	var app: QuadrilateralApp = await _app(t, directory)
	var studio: Studio = app._drawing_screen
	var ledger: State = app._construction_screen.state
	_fill_art(studio.document)
	var artwork: Dictionary = studio.document.serialize()
	var ledger_before: Dictionary = ledger.serialize()
	var history: int = studio.document.command_manager.undo_stack.size()
	studio.save_drawing(false)
	var draft: String = FileAccess.get_file_as_string(studio.save_path)
	var renderer: SaleRenderer = _renderer()
	studio.sale_png_renderer = renderer.render
	studio.testing = false
	# Persist only this transaction under the isolated test folder. The main
	# app stays in testing mode so tutorial and global preferences cannot write.
	app._art_sale_transaction = func(state: State, action: String, payload: Variant, path: String, _persist: bool) -> Dictionary:
		if not path.begins_with(directory + "/"):
			return {"ok": false, "error": "Test transaction path is outside its isolated directory."}
		return Transactions.commit(state, action, payload, path, true)
	app._construction_screen.save_path = directory.path_join("missing/ledger.json")
	_confirm(studio, "우주로 갈 그림")
	await t.get_tree().process_frame
	t.assert_true(app.testing, "A failing durable sale keeps the main app isolated from real user preferences")
	t.assert_eq(ledger.serialize(), ledger_before, "Failure to publish the economic ledger cannot credit or consume a painting")
	t.assert_eq(studio.document.serialize(), artwork, "A failed economic commit preserves the painting even after a successful PNG export")
	t.assert_eq(studio.document.command_manager.undo_stack.size(), history, "Failed payment preserves the drawing's existing Undo history")
	t.assert_eq(FileAccess.get_file_as_string(studio.save_path), draft, "Failed payment leaves the saved drawing draft intact")
	t.assert_true(studio._status.text.contains("저장"), "The drawing screen reports the failed economic save")
	var first_images: PackedStringArray = _images(studio.sold_art_directory)
	t.assert_eq(first_images.size(), 1, "A durable exported copy remains available when the later economic save fails")
	app._construction_screen.save_path = directory.path_join("ledger.json")
	_confirm(studio, "우주로 갈 그림")
	await t.get_tree().process_frame
	t.assert_true(app.testing, "Retrying a durable sale never enables real user preference persistence")
	t.assert_eq(ledger.art_sales.size(), 1, "Retrying after the economic save is repaired sells the original work once")
	t.assert_eq(ledger.art_sales[0].title, "우주로 갈 그림", "A successful retry persists the intended title")
	t.assert_eq(ledger.balance, State.INITIAL_BALANCE + int(ledger.art_sales[0].price), "Failed and successful attempts together produce exactly one payout")
	_assert_blank(t, studio.document)
	var restored: State = State.new()
	t.assert_true(Saves.load_into(app._construction_screen.save_path, restored).ok, "The retried transaction publishes a valid economic save")
	t.assert_eq(restored.balance, ledger.balance, "The published balance matches the live successful retry")
	t.assert_eq(restored.art_sales[0].title, "우주로 갈 그림", "The published ledger contains the same named sale")
	t.assert_eq(_images(studio.sold_art_directory).size(), 2, "Retrying creates a distinct PNG instead of overwriting the earlier exported copy")
	if first_images.size() == 1:
		t.assert_eq(FileAccess.get_file_as_bytes(studio.sold_art_directory.path_join(first_images[0])), renderer.bytes, "Retrying leaves the first complete exported PNG intact")
	studio.testing = true
	app.free()
	await t.get_tree().process_frame
	_cleanup(directory)

static func _test_failed_blank_draft(t: Node) -> void:
	var directory: String = _directory()
	var app: QuadrilateralApp = await _app(t, directory)
	var studio: Studio = app._drawing_screen
	_fill_art(studio.document)
	var artwork: Dictionary = studio.document.serialize()
	var renderer: SaleRenderer = _renderer()
	studio.sale_png_renderer = renderer.render
	studio.save_path = directory.path_join("missing/draft.json")
	studio.testing = false
	_confirm(studio, "안전하게 남긴 그림")
	await t.get_tree().process_frame
	t.assert_eq(app._construction_screen.state.art_sales.size(), 1, "A completed PNG and payment remain completed when only fresh-draft saving fails")
	t.assert_eq(_images(studio.sold_art_directory).size(), 1, "Fresh-draft failure still leaves the paid painting's exported PNG available")
	t.assert_eq(studio.document.serialize(), artwork, "A fresh-draft write failure preserves the editable painting instead of silently clearing it")
	t.assert_true(studio._status.text.contains("도화지") and studio._status.text.contains("그대로"), "Fresh-draft failure explains that the sold painting remains on the canvas")
	t.assert_false(Market.quote(studio.document, app._construction_screen.state.art_sales).can_sell, "Keeping the drawing after a fresh-draft failure cannot cause a second payout")
	studio.testing = true
	app.free()
	await t.get_tree().process_frame
	_cleanup(directory)

static func _test_stale_render(t: Node, hide_screen: bool) -> void:
	var directory: String = _directory()
	var app: QuadrilateralApp = await _app(t, directory)
	var studio: Studio = app._drawing_screen
	_fill_art(studio.document)
	var artwork: Dictionary = studio.document.serialize()
	var ledger_before: Dictionary = app._construction_screen.state.serialize()
	studio.save_drawing(false)
	var draft: String = FileAccess.get_file_as_string(studio.save_path)
	var renderer: SaleRenderer = _renderer()
	renderer.suspended = true
	studio.sale_png_renderer = renderer.render
	_confirm(studio, "렌더링을 기다리는 그림")
	t.assert_eq(renderer.calls, 1, "The asynchronous sale starts rendering the confirmed painting")
	t.assert_true(studio._sale_pending and studio._sale_busy.visible, "Rendering keeps the transaction pending with a visible busy overlay")
	t.assert_true(studio._sale_button.disabled and studio._sale_dialog.get_ok_button().disabled, "Rendering disables duplicate sale actions")
	t.assert_false(studio._sale_title.editable, "The submitted title cannot change while rendering is pending")
	studio._sale_dialog.confirmed.emit()
	t.assert_eq(renderer.calls, 1, "Repeated confirmation cannot start a concurrent second export")
	if hide_screen:
		app._show_home()
	else:
		studio.document.add_sized_shape("square", Vector2(0, 240), Vector2(60, 60), Color.WHITE)
	var current: Dictionary = studio.document.serialize()
	renderer.released.emit()
	await t.get_tree().process_frame
	t.assert_eq(renderer.snapshots[0], artwork, "The in-flight renderer retains its immutable original snapshot")
	t.assert_eq(app._construction_screen.state.serialize(), ledger_before, "Changing the painting or leaving the screen during rendering cancels all economic changes")
	t.assert_eq(studio.document.serialize(), current, "Cancelling a stale render keeps the latest current drawing intact")
	t.assert_eq(FileAccess.get_file_as_string(studio.save_path), draft, "A cancelled in-flight sale never overwrites the existing saved draft")
	t.assert_false(DirAccess.dir_exists_absolute(studio.sold_art_directory), "Stale render output is discarded before any PNG is published")
	t.assert_false(studio._sale_pending, "Cancelling an in-flight sale releases the pending state")
	t.assert_false(studio._sale_busy.visible, "Cancelling an in-flight sale removes its busy overlay")
	t.assert_true(studio._status.text.contains("취소"), "A stale render receives an understandable cancellation message")
	app.free()
	await t.get_tree().process_frame
	_cleanup(directory)

static func _app(t: Node, directory: String) -> QuadrilateralApp:
	DirAccess.make_dir_recursive_absolute(directory)
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	await t.get_tree().process_frame
	app._show_drawing()
	app._tutorial.cancel()
	app._drawing_screen.save_path = directory.path_join("draft.json")
	app._drawing_screen.sold_art_directory = directory.path_join("art")
	app._construction_screen.save_path = directory.path_join("ledger.json")
	return app

static func _renderer() -> SaleRenderer:
	var renderer: SaleRenderer = SaleRenderer.new()
	var image: Image = Image.create(960, 600, false, Image.FORMAT_RGBA8)
	image.fill(Color("4b9eb0"))
	renderer.bytes = image.save_png_to_buffer()
	return renderer

static func _fill_art(document: Drawing) -> void:
	var colors: Array[Color] = [Color.CORAL, Color.GOLD, Color.SKY_BLUE, Color.LIME_GREEN, Color.PLUM]
	for index: int in range(5):
		document.add_sized_shape(QuadrilateralMath.KINDS[index], Vector2(-280 + index * 140, 0), Vector2(130, 180), colors[index])

static func _set_title(studio: Studio, title: String) -> void:
	studio._sale_title.text = title
	studio._sale_title.text_changed.emit(title)

static func _confirm(studio: Studio, title: String) -> void:
	studio._sale_button.pressed.emit()
	_set_title(studio, title)
	studio._sale_dialog.confirmed.emit()

static func _assert_blank(t: Node, document: Drawing) -> void:
	t.assert_eq(document.shapes.size(), 0, "The new canvas contains no previous painting shapes")
	t.assert_eq(document.background_id, "paper", "The new canvas returns to plain drawing paper")
	t.assert_eq(document.drawing_mode, "free", "The new canvas returns to free drawing mode")
	t.assert_eq(document.masterpiece_id, "", "The new canvas removes the previous masterpiece underlay")
	t.assert_eq(document.selected_id, -1, "The new canvas has no stale selected shape")

static func _directory() -> String:
	return "user://test_drawing_sale_flow_%s" % Crypto.new().generate_random_bytes(12).hex_encode()

static func _images(directory: String) -> PackedStringArray:
	return DirAccess.get_files_at(directory) if DirAccess.dir_exists_absolute(directory) else PackedStringArray()

static func _cleanup(directory: String) -> void:
	# This helper only removes flat files inside the uniquely named test folder.
	if not directory.begins_with("user://test_drawing_sale_flow_"): return
	var images: String = directory.path_join("art")
	if DirAccess.dir_exists_absolute(images):
		for filename: String in DirAccess.get_files_at(images): DirAccess.remove_absolute(images.path_join(filename))
		DirAccess.remove_absolute(images)
	for filename: String in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
