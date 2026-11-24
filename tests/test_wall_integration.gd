extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")
const Saves = preload("res://scripts/construction/construction_save_store.gd")
const Transactions = preload("res://scripts/economy/progression_transactions.gd")
const Studio = preload("res://scenes/wall/wall_studio.gd")
const Preview = preload("res://scenes/wall/wall_pattern_preview.gd")
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
	await _test_tile_context(t, directory)
	_test_fitted_wall_grid(t)
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

static func _test_tile_context(t: Node, directory: String) -> void:
	var app: QuadrilateralApp = await _new_app(t, directory)
	if not await _press(t, app._home_screen, "OpenWall"):
		app.free()
		return
	var studio: Studio = app.wall_studio
	if not await _press(t, studio, "WallFreeDesign"):
		app.free()
		return
	var canvas: Preview = studio._preview
	var design: Design = canvas.design
	await _press(t, studio, "WallShape_square")
	canvas.place_at(Vector2(45, 35))
	await _press(t, studio, "WallShape_rhombus")
	canvas.place_at(Vector2(78, 52))
	await _press(t, studio, "WallShape_trapezoid")
	canvas.place_at(Vector2(125, 80))
	await t.get_tree().process_frame
	var original: Dictionary = design.to_dict()
	var parts: Array[Dictionary] = design.motif_parts()
	t.assert_eq(parts.size(), 3, "The context menu fixture places three distinct tile pieces")
	if parts.size() != 3:
		app.free()
		return
	var first: Vector2 = _tile_point(canvas, parts[0].position)
	var blank: Vector2 = _tile_point(canvas, Vector2(10, 10))
	_tile_button(canvas, first, MOUSE_BUTTON_LEFT, true)
	_tile_button(canvas, first, MOUSE_BUTTON_LEFT, false)
	var menu: PopupMenu = _open_wall_menu(studio, first)
	t.assert_true(menu != null and menu.visible, "Right-clicking a selected tile piece opens the edit popup")
	if menu == null or not menu.visible:
		app.free()
		return
	for label: String in ["복제", "삭제", "회전", "크기 조절"]:
		t.assert_ge(_menu_item(menu, label), 0, "The selected piece menu offers " + label)
	t.assert_eq(_menu_item(menu, "그룹"), -1, "One independent piece does not offer grouping")
	t.assert_eq(_menu_item(menu, "그룹 해제"), -1, "One independent piece does not offer ungrouping")
	t.assert_eq(design.to_dict(), original, "Opening the menu changes no artwork")
	if _choose_wall_item(t, menu, "회전"):
		var rotated: Vector2 = first + (canvas._transform_handle() - first).rotated(deg_to_rad(37))
		_drag_wall_transform(t, canvas, rotated, original)
		var expected: Vector2 = Vector2(parts[0].position) + (Vector2(parts[0].vertices[0]) - Vector2(parts[0].position)).rotated(deg_to_rad(37))
		t.assert_true(Vector2(design.motif_parts()[0].vertices[0]).distance_to(expected) < 0.02, "The handle follows a free 37-degree angle")
		await _press(t, studio, "WallUndo")
		t.assert_eq(design.to_dict(), original, "One undo restores the entire rotate gesture")

	menu = _open_wall_menu(studio, first)
	if _choose_wall_item(t, menu, "크기 조절"):
		var larger: Vector2 = first + (canvas._transform_handle() - first) * 1.24
		_drag_wall_transform(t, canvas, larger, original)
		var sides: PackedFloat32Array = QuadrilateralMath.side_lengths(design.motif_parts()[0].vertices)
		var original_sides: PackedFloat32Array = QuadrilateralMath.side_lengths(parts[0].vertices)
		for corner: int in range(4):
			t.assert_float_approx(sides[corner], original_sides[corner] * 1.24, 0.02, "Dragging the resize handle proportionally changes every side")
		await _press(t, studio, "WallUndo")
		t.assert_eq(design.to_dict(), original, "One undo restores the entire resize gesture")

	var left_edge: float = QuadrilateralMath.bounds(parts[0].vertices).position.x
	var near_border: Vector2 = _tile_point(canvas, Vector2(parts[0].position) + Vector2(0.75 - left_edge, 0.0))
	_tile_button(canvas, first, MOUSE_BUTTON_LEFT, true)
	_tile_motion(canvas, near_border)
	t.assert_eq(design.to_dict(), original, "The live magnetic move remains a temporary preview")
	_tile_button(canvas, near_border, MOUSE_BUTTON_LEFT, false)
	t.assert_float_approx(QuadrilateralMath.bounds(design.motif_parts()[0].vertices).position.x, 0.0, 0.001, "Releasing near the left tile edge attaches the piece with no gap")
	await _press(t, studio, "WallUndo")
	t.assert_eq(design.to_dict(), original, "One undo restores the tile before magnet snapping")

	menu = _open_wall_menu(studio, first)
	if _choose_wall_item(t, menu, "복제"):
		parts = design.motif_parts()
		t.assert_eq(parts.size(), 4, "Context duplication makes one new piece")
		if parts.size() == 4:
			t.assert_eq(parts[3].color, parts[0].color, "Context duplication keeps the selected color")
			menu = _open_wall_menu(studio, _tile_point(canvas, parts[3].position))
			_choose_wall_item(t, menu, "삭제")
			t.assert_eq(design.to_dict(), original, "Context deletion removes only the selected duplicate")

	var far_corner: Vector2 = _tile_point(canvas, Vector2(105, 70))
	_tile_button(canvas, blank, MOUSE_BUTTON_LEFT, true)
	_tile_motion(canvas, far_corner)
	_tile_button(canvas, far_corner, MOUSE_BUTTON_LEFT, false)
	t.assert_eq(canvas.selected_indices, [0, 1], "A drag rectangle selects the two enclosed pieces")
	menu = _open_wall_menu(studio, first)
	t.assert_eq(_menu_item(menu, "그룹 해제"), -1, "A marquee over independent shapes does not offer ungrouping")
	if _choose_wall_item(t, menu, "그룹"):
		t.assert_eq(design.expand_selection([0]), [0, 1], "Grouping applies to both marquee-selected members")
		t.assert_eq(design.expand_selection([2]), [2], "Grouping leaves the outside shape independent")
		var grouped: Dictionary = design.to_dict()
		var original_group: Array[Dictionary] = design.motif_parts()
		var offset: Vector2 = Vector2(5.5, 6.5)
		var moved_group: Vector2 = _tile_point(canvas, Vector2(original_group[0].position) + offset)
		_tile_button(canvas, first, MOUSE_BUTTON_LEFT, true)
		_tile_motion(canvas, moved_group)
		_tile_button(canvas, moved_group, MOUSE_BUTTON_LEFT, false)
		var translated: Array[Dictionary] = design.motif_parts()
		for idx: int in [0, 1]:
			t.assert_true(Vector2(translated[idx].position).is_equal_approx(Vector2(original_group[idx].position) + offset), "Dragging either grouped member moves both by the same amount")
		t.assert_eq(translated[2], original_group[2], "Group movement does not affect the rest of the design")
		await _press(t, studio, "WallUndo")
		t.assert_eq(design.to_dict(), grouped, "Undo restores the complete grouped move")
		menu = _open_wall_menu(studio, first)
		t.assert_eq(_menu_item(menu, "그룹"), -1, "A selected group only offers ungrouping")
		if _choose_wall_item(t, menu, "그룹 해제"):
			t.assert_eq(design.to_dict(), original, "Ungrouping preserves geometry and colors")
			await _press(t, studio, "WallUndo")
			t.assert_eq(design.to_dict(), grouped, "One undo restores group membership from the menu")
			await _press(t, studio, "WallRedo")
			t.assert_eq(design.to_dict(), original, "One redo dissolves the group again")
	app.free()
	await t.get_tree().process_frame

static func _drag_wall_transform(t: Node, canvas: Preview, destination: Vector2, original: Dictionary) -> void:
	var handle: Vector2 = canvas._transform_handle()
	_tile_button(canvas, handle, MOUSE_BUTTON_LEFT, true)
	_tile_motion(canvas, handle.lerp(destination, 0.5))
	_tile_motion(canvas, destination)
	t.assert_eq(canvas.design.to_dict(), original, "A live transform drag leaves the saved geometry intact until release")
	_tile_button(canvas, destination, MOUSE_BUTTON_LEFT, false)
	t.assert_true(canvas.design.to_dict() != original, "Releasing the handle commits the visible gesture")

static func _tile_point(canvas: Preview, point: Vector2) -> Vector2:
	var tile: Rect2 = canvas._sheet_rect()
	return tile.position + point * (tile.size.x / canvas.design.tile_size().x)

static func _tile_button(canvas: Preview, point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = canvas.get_global_transform_with_canvas() * point
	event.button_index = button
	event.pressed = pressed
	canvas._gui_input(event)

static func _tile_motion(canvas: Preview, point: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = canvas.get_global_transform_with_canvas() * point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	canvas._gui_input(event)

static func _open_wall_menu(studio: Studio, point: Vector2) -> PopupMenu:
	_tile_button(studio._preview, point, MOUSE_BUTTON_RIGHT, true)
	return studio.find_child("WallPieceMenu", true, false) as PopupMenu

static func _menu_item(menu: PopupMenu, label: String) -> int:
	if menu != null:
		for index: int in range(menu.item_count):
			if menu.get_item_text(index) == label: return index
	return -1

static func _choose_wall_item(t: Node, menu: PopupMenu, label: String) -> bool:
	var item: int = _menu_item(menu, label)
	var available: bool = item >= 0 and not menu.is_item_disabled(item)
	t.assert_true(available, "The popup allows " + label)
	if available: menu.id_pressed.emit(menu.get_item_id(item))
	return available

static func _test_fitted_wall_grid(t: Node) -> void:
	var design: Design = Design.new()
	design.set_commission("bakery")
	design.add_piece("rectangle", Vector2.ZERO, 1)
	design.add_piece("square", design.tile_size(), 3)
	t.assert_true(design.finish_tile(), "A finished five-by-two wall can include pieces at the full tile edges")
	var preview: Preview = Preview.new()
	preview.design = design
	preview.view_kind = "filled"
	preview.set_location("bakery")
	var backdrop_size: Vector2 = preview.backdrop.get_size() if preview.backdrop != null else Vector2(16, 10)
	var backdrop_rect: Rect2 = preview._fit(backdrop_size, Rect2(0, 0, 960, 570))
	var normalized: Rect2 = Art.wall_rect("bakery")
	var panel: Rect2 = Rect2(backdrop_rect.position + normalized.position * backdrop_rect.size, normalized.size * backdrop_rect.size)
	var grid: Rect2 = preview._wall_grid_rect(panel)
	var expected_scale: float = minf(panel.size.x / design.wall_size().x, panel.size.y / design.wall_size().y)
	t.assert_true(panel.grow(0.001).encloses(grid), "The real bakery panel contains every row and column of the tile grid")
	t.assert_true(grid.get_center().is_equal_approx(panel.get_center()), "The finished grid is centered on an aspect-mismatched panel")
	t.assert_true(grid.size.is_equal_approx(design.wall_size() * expected_scale), "The uniform fit uses the available space without stretching the quadrilaterals")
	var cells: Dictionary[Vector2i, bool] = {}
	var rendered_points: PackedVector2Array = PackedVector2Array()
	for part: Dictionary in design.wall_parts():
		cells[Vector2i(part.column, part.row)] = true
		for corner: Vector2 in part.vertices:
			rendered_points.append(grid.position + corner * expected_scale)
	t.assert_eq(cells.size(), 10, "All five columns and two rows land inside the same fitted grid")
	t.assert_true(cells.has(Vector2i.ZERO) and cells.has(Vector2i(4, 1)), "The two outside corner tiles are both included")
	t.assert_true(QuadrilateralMath.bounds(rendered_points).is_equal_approx(grid), "Pieces touching the first and last tile boundaries remain fully visible")
	preview.export_only = true
	t.assert_eq(preview._wall_grid_rect(panel), grid, "Export and preview fit the wall to the same rectangle")
	preview.free()

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
