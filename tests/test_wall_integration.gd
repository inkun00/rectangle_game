extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")
const Saves = preload("res://scripts/construction/construction_save_store.gd")
const Transactions = preload("res://scripts/economy/progression_transactions.gd")
const Studio = preload("res://scenes/wall/wall_studio.gd")
const Design = preload("res://scripts/core/wall_tile_design.gd")
const Art = preload("res://scenes/wall/wall_art.gd")
const SaleTests = preload("res://tests/test_drawing_sale_flow.gd")
const WALL_BOARD: String = "https://padlet.com/inkun02/padlet-s025pydws5qowdbbgrdp"

static func run(t: Node) -> void:
	var directory: String = "user://test_wall_gallery_" + Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: QuadrilateralApp = await _new_app(t, directory)
	var initial_balance: int = app._economy_state.balance
	if not await _press(t, app._home_screen, "OpenWall"):
		app.free()
		return
	var studio: Studio = app.wall_studio
	t.assert_true(studio.is_visible_in_tree() and not app._home_screen.visible, "The wall commission opens its own workbench")
	var untouched: Dictionary = app.wall_design.to_dict()
	var images: Array[String] = []
	t.assert_eq(Design.COMMISSIONS.size(), 10, "The wall artist can choose among ten clients")
	for job: String in Design.COMMISSIONS:
		await _press(t, studio, "WallCommission_" + job)
		var path: String = studio._preview.background_path()
		t.assert_eq(path, Art.path_for(job), "Selecting a brief shows that client's location")
		t.assert_true(studio._preview.backdrop != null and studio._preview.backdrop.get_size().x > 0 and not images.has(path), "The client has a distinct, loadable wall illustration: " + job)
		t.assert_eq(studio._preview.view_kind, "blank", "The initial picture shows an undecorated wall")
		images.append(path)
	t.assert_eq(app.wall_design.to_dict(), untouched, "Reading the briefs never prepares or edits the player's own tile")
	await _press(t, studio, "WallCommission_harbor")
	await _press(t, studio, "WallAccept")
	t.assert_true(studio._preview.name == &"WallBlankPreview" and studio._preview.view_kind == "blank", "Accepting shows the empty wall before editing")
	await _press(t, studio, "WallStartTile")
	t.assert_true(studio._preview.view_kind == "tile" and app.wall_design.motif_parts().is_empty(), "The player starts with a blank tile")
	var finish: Button = studio.find_child("WallFinishTile", true, false) as Button
	t.assert_true(finish != null and finish.disabled, "An empty composition cannot fill the wall")
	await _press(t, studio, "WallShape_square")
	studio._preview.place_at(Vector2(25, 50))
	await _press(t, studio, "WallColor_0")
	await _press(t, studio, "WallShape_square")
	await _press(t, studio, "WallPlaceCenter")
	await _press(t, studio, "WallColor_1")
	await _press(t, studio, "WallShape_trapezoid")
	studio._preview.place_at(Vector2(120, 45))
	var pieces: Array[Dictionary] = app.wall_design.motif_parts()
	t.assert_eq(pieces.size(), 3, "The artist can freely place three pieces, including two of the same shape")
	if pieces.size() != 3:
		app.free()
		return
	t.assert_true(pieces[0].kind == "square" and pieces[1].kind == "square" and pieces[2].kind == "trapezoid", "Each selected shape occupies its own part on the tile")
	t.assert_true(pieces[0].color != pieces[1].color, "Separate squares can have different colors")
	studio._preview.nudge(Vector2(5, 0))
	t.assert_eq(app.wall_design.motif_parts()[2].position, Vector2(pieces[2].position) + Vector2(5, 0), "Nudging moves the selected trapezoid")
	var before_turn: PackedVector2Array = app.wall_design.motif_parts()[2].vertices
	await _press(t, studio, "WallRotate")
	t.assert_true(app.wall_design.motif_parts()[2].vertices != before_turn, "Rotating edits the selected part's geometry")
	await _press(t, studio, "WallUndo")
	t.assert_eq(app.wall_design.motif_parts()[2].vertices, before_turn, "Undo restores this part's placement before rotation")
	await _press(t, studio, "WallRedo")
	await _press(t, studio, "WallFinishTile")
	t.assert_true(studio._preview.view_kind == "filled" and studio._preview.design == app.wall_design, "Finishing overlays the actual design on the selected wall")
	_check_wall_copies(t, app.wall_design)
	t.assert_eq(app._economy_state.balance, initial_balance, "Filling the wall still awaits delivery for payment")
	var offer: Dictionary = app.wall_design.evaluate()
	t.assert_true(bool(offer.ok), "The player's arrangement qualifies for the client's promised reward")
	var reward: int = int(offer.reward)
	t.assert_gt(reward, 0, "The completed commission quotes a positive reward")
	_test_disk_payment(t, app._economy_state, reward)
	await _press(t, studio, "WallSubmit")
	t.assert_eq(app._economy_state.balance, initial_balance + reward, "Delivering through the visible submit button credits the shared wallet")
	var completed: Dictionary = app.wall_design.to_dict()
	app._claim_wall_commission()
	t.assert_eq(app._economy_state.balance, initial_balance + reward, "A repeated delivery cannot pay twice")
	await _test_gallery(t, app, studio, directory)
	await _press(t, studio, "WallHome")
	t.assert_true(app._home_screen.visible and not studio.visible, "The wall artist can return to the home menu")
	await _press(t, app._home_screen, "OpenWall")
	t.assert_eq(app.wall_design.to_dict(), completed, "Reopening the wall workbench preserves the submitted design and its receipt")
	app.free()
	await t.get_tree().process_frame
	await _test_free_workspace(t, directory)
	var images_directory: String = directory.path_join("images")
	if DirAccess.dir_exists_absolute(images_directory):
		for file: String in DirAccess.get_files_at(images_directory): DirAccess.remove_absolute(images_directory.path_join(file))
		DirAccess.remove_absolute(images_directory)
	for file: String in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)

static func _new_app(t: Node, directory: String) -> QuadrilateralApp:
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	app._wall_png_directory = directory.path_join("images")
	app._art_publications.path = directory.path_join("publications.json")
	t.add_child(app)
	await t.get_tree().process_frame
	return app

static func _test_free_workspace(t: Node, directory: String) -> void:
	var app: QuadrilateralApp = await _new_app(t, directory)
	var paid: Dictionary = _paid_state(app._economy_state)
	await _press(t, app._home_screen, "OpenWall")
	var studio: Studio = app.wall_studio
	await _press(t, studio, "WallCommission_garden")
	if not await _press(t, studio, "WallFreeDesign"):
		app.free()
		return
	var free_design: Design = studio._preview.design
	t.assert_true(studio._preview.view_kind == "tile" and free_design.commission_id == "garden", "Free design opens the tile editor directly at the chosen location")
	t.assert_true(free_design != app.wall_design, "Editing for fun preserves the separate paid draft")
	for i: int in range(3):
		await _press(t, studio, "WallShape_square")
		studio._preview.place_at(Vector2(25 + 45 * i, 50))
		await _press(t, studio, "WallColor_%d" % (i % 2))
	await _press(t, studio, "WallFinishTile")
	t.assert_true(studio._preview.view_kind == "filled" and studio._preview.background_path() == Art.path_for("garden"), "Finishing shows the free design on the chosen garden wall")
	t.assert_true(bool(free_design.evaluate().ok), "This free wall would meet the commission's actual geometry requirements")
	var payment: Button = studio.find_child("WallSubmit", true, false) as Button
	t.assert_true(payment == null or not payment.is_visible_in_tree() or payment.disabled, "Even a qualifying free wall cannot claim a commission reward")
	t.assert_eq(_paid_state(app._economy_state), paid, "Free editing cannot alter the commission draft, receipt, or balance")
	var rendered: Array[Dictionary] = []
	var png: Image = Image.create(960, 600, false, Image.FORMAT_RGBA8)
	png.fill(Color.CORAL)
	var bytes: PackedByteArray = png.save_png_to_buffer()
	app._wall_png_renderer = func(snapshot: Dictionary) -> PackedByteArray:
		rendered.append(snapshot)
		return bytes
	var uploader: SaleTests.UploadTransport = SaleTests.UploadTransport.new()
	uploader.response = {"ok": true, "post_url": WALL_BOARD + "/wish/test-free-wall"}
	app._art_upload_transport = uploader.upload
	await _press(t, studio, "WallPublish")
	var form: ConfirmationDialog = studio.find_child("WallPublicationForm", true, false) as ConfirmationDialog
	t.assert_true(form != null and form.visible, "The free-design artist can register a finished wall")
	if form != null:
		(form.find_child("WallAuthor", true, false) as LineEdit).text = "하나"
		(form.find_child("WallPublicationTitle", true, false) as LineEdit).text = "내 정원"
		(form.find_child("WallDescription", true, false) as TextEdit).text = "두 가지 색으로 꾸민 정원이에요."
		form.confirmed.emit()
		await t.get_tree().process_frame
	t.assert_eq(rendered, [studio.publication_design()], "The export uses the free tile and selected location")
	t.assert_true(uploader.calls == 1 and uploader.entries[0].kind == "wall" and uploader.images[0] == bytes, "Free registration sends exactly one wall image")
	t.assert_eq(_paid_state(app._economy_state), paid, "Registering a free wall cannot pay out a commission")
	var saved: Dictionary = free_design.to_dict()
	await _press(t, studio, "WallOrders")
	await _press(t, studio, "WallCommission_station")
	await _press(t, studio, "WallFreeDesign")
	t.assert_true(studio._preview.design.motif_parts().is_empty(), "A different location opens its own free tile")
	await _press(t, studio, "WallOrders")
	await _press(t, studio, "WallCommission_garden")
	await _press(t, studio, "WallFreeDesign")
	t.assert_eq(studio._preview.design.to_dict(), saved, "Returning to the garden recovers the artist's free tile")
	await _press(t, studio, "WallOrders")
	await _press(t, studio, "WallCommission_harbor")
	await _press(t, studio, "WallAccept")
	await _press(t, studio, "WallStartTile")
	t.assert_true(studio._preview.design == app.wall_design and _paid_state(app._economy_state) == paid, "The paid studio reopens its original tile and money")
	var path: String = directory.path_join("free-wall.json")
	var recovered: ConstructionState = ConstructionState.new()
	t.assert_true(Saves.save(path, app._economy_state).ok and Saves.load_into(path, recovered).ok, "The free workspace survives a real ledger save and reload")
	t.assert_true(recovered.free_wall_designs.has("garden") and recovered.free_wall_designs.garden.to_dict() == saved, "A fresh ledger recovers the exact free tile under the chosen location")
	t.assert_eq(_paid_state(recovered), paid, "Reloading free work preserves the independent paid ledger")
	app.free()
	await t.get_tree().process_frame

static func _paid_state(state: ConstructionState) -> Dictionary:
	var saved: Dictionary = state.serialize()
	saved.erase("free_wall_designs")
	return saved

static func _test_gallery(t: Node, app: QuadrilateralApp, studio: Studio, directory: String) -> void:
	var ledger: Dictionary = app._economy_state.serialize()
	var opens: Array[String] = []
	var uploader: SaleTests.UploadTransport = SaleTests.UploadTransport.new()
	uploader.response = {"ok": false, "error": "offline", "retryable": true, "retry_after_seconds": 120}
	var bytes: PackedByteArray = SaleTests._renderer().bytes
	var snapshots: Array[Dictionary] = []
	app._wall_png_renderer = func(snapshot: Dictionary) -> PackedByteArray:
		snapshots.append(snapshot)
		return bytes
	app._art_upload_transport = uploader.upload
	app.exhibition_board_opener = func(url: String) -> bool:
		opens.append(url)
		return true
	await _press(t, studio, "WallBrowse")
	t.assert_eq(opens, [WALL_BOARD], "The wall exhibition button opens the separate wall board")
	t.assert_true(uploader.calls == 0 and snapshots.is_empty(), "Visiting the wall exhibition neither renders nor submits a picture")
	await _press(t, studio, "WallPublish")
	var form: ConfirmationDialog = studio.find_child("WallPublicationForm", true, false) as ConfirmationDialog
	t.assert_true(form != null and form.visible, "Registering a wall opens a separate confirmation with metadata")
	if form == null: return
	form.confirmed.emit()
	t.assert_true(form.visible and uploader.calls == 0 and snapshots.is_empty(), "Missing author, title and description are rejected before PNG generation")
	(form.find_child("WallAuthor", true, false) as LineEdit).text = "  지우  "
	(form.find_child("WallPublicationTitle", true, false) as LineEdit).text = "항구 타일"
	(form.find_child("WallDescription", true, false) as TextEdit).text = "정사각형 둘과 사다리꼴 하나를 놓았어요."
	form.confirmed.emit()
	await t.get_tree().process_frame
	t.assert_eq(snapshots, [studio.publication_design()], "The renderer receives the completed wall the player confirmed")
	t.assert_eq(uploader.calls, 1, "One confirmation attempts one upload")
	if uploader.calls != 1: return
	var first: Dictionary = uploader.entries[0]
	t.assert_true(first.kind == "wall" and int(first.price) == 0, "Wall posts use their own gallery and carry no payment")
	t.assert_true(first.author == "지우" and first.title == "항구 타일" and first.description == "정사각형 둘과 사다리꼴 하나를 놓았어요.", "The outbox receives the player's trimmed metadata")
	t.assert_eq(uploader.images[0], bytes, "The uploader receives the confirmed PNG")
	t.assert_eq(app._art_publications.pending_walls().size(), 1, "Offline registration keeps one pending wall")
	t.assert_eq(app._economy_state.serialize(), ledger, "Browsing, registration and upload failure preserve the original receipt and wallet")
	var fresh: QuadrilateralApp = await _new_app(t, directory)
	t.assert_true(fresh._economy_state.restore(ledger), "The next launch can load the player's paid wall")
	fresh._art_upload_transport = uploader.upload
	uploader.response = {"ok": true, "post_url": WALL_BOARD + "/wish/test-wall"}
	fresh._resume_pending_publications()
	await t.get_tree().process_frame
	t.assert_eq(uploader.calls, 2, "The next launch resumes an offline wall registration")
	if uploader.calls == 2:
		t.assert_eq(uploader.entries[1].id, first.id, "Reload reuses the original server deduplication ID")
		t.assert_eq(uploader.images[1], bytes, "Reload sends the original PNG without rendering another wall")
	t.assert_eq(fresh._art_publications.pending_walls().size(), 0, "A successful registration leaves the durable queue")
	await _press(t, fresh._home_screen, "OpenWall")
	var next: Studio = fresh.wall_studio
	await _press(t, next, "WallCommission_harbor")
	await _press(t, next, "WallAccept")
	await _press(t, next, "WallResume")
	await _press(t, next, "WallPublish")
	var second_form: ConfirmationDialog = next.find_child("WallPublicationForm", true, false) as ConfirmationDialog
	t.assert_true(second_form != null and second_form.visible, "The reopened wall offers a registration form in the fresh session")
	if second_form != null:
		(second_form.find_child("WallAuthor", true, false) as LineEdit).text = "지우"
		(second_form.find_child("WallPublicationTitle", true, false) as LineEdit).text = "다시 쓴 제목"
		(second_form.find_child("WallDescription", true, false) as TextEdit).text = "같은 담장이에요."
		fresh._wall_png_renderer = func(_snapshot: Dictionary) -> PackedByteArray: return bytes
		second_form.confirmed.emit()
		await t.get_tree().process_frame
	t.assert_eq(uploader.calls, 2, "Submitting the same published wall with a new title cannot upload it twice")
	t.assert_eq(fresh._art_publications.entries.size(), 1, "A repeat confirmation cannot create another registration")
	t.assert_eq(fresh._economy_state.serialize(), ledger, "Uploading and reopening do not change the paid commission ledger")
	fresh.free()
	await t.get_tree().process_frame

static func _check_wall_copies(t: Node, design: Design) -> void:
	var original: Array[Dictionary] = design.motif_parts()
	var copies: Array[Dictionary] = design.wall_parts()
	t.assert_eq(copies.size(), original.size() * design.columns * design.rows, "Every cell gets one copy of the whole tile")
	var unique: Dictionary = {}
	for part: Dictionary in copies:
		var cell: Vector2i = Vector2i(part.column, part.row)
		var source: Dictionary = original[int(part.index)]
		var shift: Vector2 = Vector2(cell) * design.tile_size()
		var copy: PackedVector2Array = Transform2D(0, shift) * PackedVector2Array(source.vertices)
		var key: Vector3i = Vector3i(cell.x, cell.y, int(part.index))
		t.assert_true(not unique.has(key) and cell.x >= 0 and cell.y >= 0 and cell.x < design.columns and cell.y < design.rows, "Each finished-wall part occupies one unique authored slot")
		unique[key] = true
		t.assert_eq(part.vertices, copy, "Each copy retains the player's rotated vertices and relative placement")
		t.assert_eq(part.color, source.color, "Each copy retains the player's chosen color")

static func _press(t: Node, root: Node, button_name: String) -> bool:
	var button: Button = root.find_child(button_name, true, false) as Button
	var available: bool = button != null and button.is_visible_in_tree() and not button.disabled
	t.assert_true(available, "A player can press " + button_name)
	if available: button.pressed.emit()
	await t.get_tree().process_frame
	return available

static func _test_disk_payment(t: Node, live_state: ConstructionState, reward: int) -> void:
	var directory: String = "user://test_wall_payment_" + Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory.path_join("ledger.json")
	var restored: ConstructionState = ConstructionState.new()
	var legacy: Dictionary = live_state.serialize()
	legacy.erase("wall_design")
	t.assert_true(restored.restore(legacy) and restored.wall_design.total_income() == 0 and restored.balance == live_state.balance, "Earlier saves load the same wallet and start without paid wall commissions")
	legacy.wall_design = {"version": 1, "commission": "harbor", "motif": "trapezoid_pair", "turns": 0, "layout": "straight", "columns": 4, "rows": 2, "tile_columns": 2, "tile_rows": 1, "colors": {"trapezoid_pair": [0, 1], "square_frame": [2, 0, 0, 0, 0], "mirror_stripe": [0, 1, 2, 0, 1, 2]}, "completed": ["harbor"]}
	legacy.balance = int(legacy.balance) + reward
	t.assert_true(restored.restore(legacy), "An already paid v1 tiled wall opens in the new studio")
	t.assert_eq(restored.wall_design.motif_parts().size(), 4, "The old two-piece unit repeated twice becomes four individually editable parts")
	t.assert_eq(restored.wall_design.to_dict().version, 2, "The next save uses editable wall parts")
	t.assert_eq(restored.balance, live_state.balance + reward, "Migration keeps the old shared wallet balance")
	t.assert_true(not restored.claim_wall_commission().ok and restored.wall_design.total_income() == reward, "A migrated delivery receipt blocks a second payment")
	t.assert_true(bool(Saves.save(path, live_state).ok) and bool(Saves.load_into(path, restored).ok), "An eligible wall draft can be saved and reloaded")
	var snapshot: Dictionary = restored.serialize()
	var failed: Dictionary = Transactions.commit(restored, "claim_wall_commission", null, directory.path_join("missing/ledger.json"), true)
	t.assert_false(bool(failed.ok), "No reward is issued when the ledger cannot be written")
	t.assert_eq(restored.serialize(), snapshot, "A failed write preserves the draft, unpaid commission and wallet")
	var payment: Dictionary = Transactions.commit(restored, "claim_wall_commission", null, path, true)
	t.assert_true(bool(payment.ok), "The artist can deliver the saved draft after a failed write")
	var awarded: ConstructionState = ConstructionState.new()
	t.assert_true(bool(Saves.load_into(path, awarded).ok), "A successful wall payment survives a new ledger instance")
	t.assert_eq(awarded.balance, live_state.balance + reward, "The saved wallet includes the quoted reward once")
	Transactions.commit(awarded, "claim_wall_commission", null, path, true)
	t.assert_eq(awarded.balance, live_state.balance + reward, "Reloading a submitted commission never duplicates the reward")
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
