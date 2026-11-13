class_name TestSpaceIntegration
extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")
const ArtSamples = preload("res://tests/test_art_composition.gd")

static func run(t: Node) -> void:
	await _test_shared_ledger(t)
	await _test_story_branches(t)

static func _test_story_branches(t: Node) -> void:
	var window: Window = t.get_tree().root
	var original_scale: Vector2i = window.content_scale_size
	var directory: String = "user://test_story_endings_%s" % Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	app._art_publications.path = directory.path_join("queue.json")
	app._ending_png_directory = directory.path_join("png")
	var requests: Array[Dictionary] = []
	var renders: Array[Dictionary] = []
	var rendered_images: Dictionary = {}
	app._ending_png_renderer = func(branch: String, offer: Dictionary) -> PackedByteArray:
		renders.append(offer)
		var image: Image = Image.create_empty(960, 600, false, Image.FORMAT_RGBA8)
		image.fill_rect(Rect2i(280, 180, 400, 260), Color.ORANGE if branch == "earth" else Color.AQUA)
		var bytes: PackedByteArray = image.save_png_to_buffer()
		rendered_images[branch] = bytes
		return bytes
	app._art_upload_transport = func(entry: Dictionary, bytes: PackedByteArray) -> Dictionary:
		requests.append({"entry": entry, "bytes": bytes})
		if requests.size() == 1: return {"ok": false, "error": "연결이 끊겼어요."}
		return {"ok": true, "post_url": PadletUploader.BOARD_URL}
	t.add_child(app)
	await t.get_tree().process_frame
	var ledger: ConstructionState = app._economy_state
	t.assert_true(app._home_screen._earth_button.disabled, "A new player earns funds before choosing a home ending")
	var quests: Array[String] = []
	for quest: Dictionary in QuestCatalog.all_quests(): quests.append(str(quest.id))
	ledger.claim_village_rewards(quests)
	t.assert_false(app._home_screen._earth_button.disabled, "Village income unlocks the home project")
	app._home_screen._earth_button.pressed.emit()
	app._tutorial.cancel()
	await t.get_tree().process_frame
	var studio: ConstructionStudio = app._construction_screen
	t.assert_true(studio.visible and ledger.my_house_mode, "Choosing Earth opens the personal house directly")
	t.assert_false(is_instance_valid(studio._modal), "Choosing Earth does not open a commission briefing")
	t.assert_true(ledger.my_house_document.replace_parts(ConstructionGuide.plan()), "A closed guide house can be built from the shared funds")
	t.assert_false(studio.earth_ending_offer().ok, "An uninspected house cannot finalize the Earth ending")
	studio._last_report = {"stable": true, "revision": ledger.my_house_document.revision}
	studio._refresh()
	t.assert_false(studio._earth_ending_button.disabled, "The completed home exposes the ending action")
	studio._earth_ending_button.pressed.emit()
	var metadata: Dictionary = {"author": "건축가", "title": "우리 마을의 집", "description": "사각형 벽과 지붕을 쌓았어요."}
	await app._submit_ending_project(metadata)
	t.assert_false(is_instance_valid(app._ending_scene), "An unsuccessful upload does not start an ending")
	var earth_entry: Dictionary = app._art_publications.ending_entry("earth")
	t.assert_eq(earth_entry.get("status"), "pending", "An interrupted upload saves the exact completed house for retry")
	t.assert_eq(earth_entry.get("price"), ledger.my_house_cost(), "The Earth publication uses the actual material bill")
	t.assert_true(app._art_publications.pending([], true).is_empty(), "A pending ending is handled only through its own retry flow")
	if not earth_entry.is_empty():
		var reloaded: ArtPublicationStore = ArtPublicationStore.new()
		reloaded.path = app._art_publications.path
		t.assert_true(reloaded.load_file().ok, "A reload restores the pending house and original request ID")
		app._art_publications = reloaded
		app._show_home()
		app._home_screen.ending_requested.emit("earth")
		await app._submit_ending_project({})
		t.assert_eq(renders.size(), 1, "Retry does not redraw the saved house")
		t.assert_eq(requests.size(), 2, "Retry sends the saved house again")
		if requests.size() == 2:
			t.assert_eq(requests[1].entry.id, requests[0].entry.id, "Padlet retry keeps the idempotency ID")
			t.assert_eq(requests[1].bytes, rendered_images.earth, "Padlet receives the original house PNG on retry")
		t.assert_true(is_instance_valid(app._ending_scene) and app._ending_scene.branch == "earth", "Successful publication starts the village home ending")
		app._show_home()
		app._home_screen.ending_requested.emit("earth")
		t.assert_true(is_instance_valid(app._ending_scene) and app._ending_scene.branch == "earth", "Home replays the saved house ending")
		t.assert_eq(requests.size(), 2, "Replaying a completed ending does not post twice")
	app._show_home()
	await app._show_space()
	for part: Dictionary in SpaceshipCatalog.all_parts():
		t.assert_true(ledger.purchase_ship_part(str(part.id)).ok, "Village earnings can buy the %s part" % str(part.id))
	app._customize_ship_part("hull", "rhombus", "ff44aa")
	var balance: int = ledger.balance
	app._space_screen.launch_requested.emit()
	await app._submit_ending_project({"author": "설계자", "title": "나의 귀향선", "description": "마름모 몸체와 분홍색으로 꾸몄어요."})
	t.assert_true(is_instance_valid(app._ending_scene) and app._ending_scene.branch == "space", "A completed ship plays the space ending after publication")
	var space_entry: Dictionary = app._art_publications.ending_entry("space")
	t.assert_eq(space_entry.get("price"), ledger.ship_spent(), "The ship publication carries the paid component total")
	if renders.size() == 2: t.assert_eq(renders[1].design, ledger.ship_design, "The exported ship snapshot includes the current shape and color choices")
	t.assert_eq(ledger.balance, balance, "Finalizing an ending does not charge a project twice")
	t.assert_eq(app._art_publications.ending_entry("earth").get("status"), "published", "Completing the ship preserves the separate village ending")
	app.free()
	window.content_scale_size = original_scale
	for name: String in DirAccess.get_files_at(directory.path_join("png")):
		DirAccess.remove_absolute(directory.path_join("png").path_join(name))
	DirAccess.remove_absolute(directory.path_join("png"))
	for name: String in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	await t.get_tree().process_frame

static func _test_shared_ledger(t: Node) -> void:
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
	app._drawing_screen.sold_art_directory = "user://test_space_integration_sold_art"
	app._art_publications.path = "user://test_space_integration_sold_art/publications.json"
	app._drawing_screen.sale_png_renderer = func(_tree: SceneTree, _drawing: DrawingDocument) -> PackedByteArray:
		return Image.create(960, 600, false, Image.FORMAT_RGBA8).save_png_to_buffer()
	var art: DrawingDocument = app._drawing_screen.document
	art.restore(ArtSamples.house().serialize())
	var picture: Dictionary = art.serialize()
	var quote: Dictionary = ArtMarket.quote(art)
	t.assert_true(bool(quote.can_sell), "The integration fixture is a real saleable drawing")
	app._drawing_screen._sale_button.pressed.emit()
	app._drawing_screen._sale_author.text = "별빛 작가"
	app._drawing_screen._sale_title.text = "나의 별빛 그림"
	app._drawing_screen._sale_description.text = "사각형으로 집을 그려 우주선 제작비를 모아요."
	t.assert_true(app._drawing_screen._sale_dialog.visible, "The actual sale button shows its quote")
	t.assert_eq(ledger.balance, ConstructionState.INITIAL_BALANCE, "A quote alone does not pay money")
	app._drawing_screen._sale_dialog.confirmed.emit()
	t.assert_eq(ledger.art_sales.size(), 1, "The actual confirmation records one sale")
	t.assert_eq(ledger.balance, ConstructionState.INITIAL_BALANCE + int(quote.price), "Drawing income reaches the construction ledger")
	t.assert_eq(ledger.art_sales[0].title, "나의 별빛 그림", "Selling records the artist's title")
	t.assert_true(art.shapes.is_empty(), "A saved sale opens a blank drawing")
	t.assert_eq(art.background_id, "paper", "A saved sale resets the paper background")
	art.undo()
	t.assert_eq(art.serialize(), picture, "Undo can recover sold artwork without undoing its payment")
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
	var directory: DirAccess = DirAccess.open("user://test_space_integration_sold_art")
	if directory != null:
		for filename: String in directory.get_files(): directory.remove(filename)
		DirAccess.remove_absolute("user://test_space_integration_sold_art")
	await t.get_tree().process_frame
