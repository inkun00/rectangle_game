extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")
const Saves = preload("res://scripts/construction/construction_save_store.gd")
const Transactions = preload("res://scripts/economy/progression_transactions.gd")
const Studio = preload("res://scenes/wall/wall_studio.gd")

static func run(t: Node) -> void:
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	await t.get_tree().process_frame
	var initial_balance: int = app._economy_state.balance
	if not await _press(t, app._home_screen, "OpenWall"):
		app.free()
		return
	var studio: Studio = app.wall_studio
	t.assert_true(studio.is_visible_in_tree() and not app._home_screen.visible, "The wall commission opens its own workbench")
	var untouched: Dictionary = app.wall_design.to_dict()
	for job: String in ["garden", "station", "harbor"]:
		await _press(t, studio, "WallCommission_" + job)
		var example: Variant = studio._preview.design
		t.assert_true(example != studio.design and example.commission_id == job and example.evaluate().ok, "The client displays an independent example that meets the selected brief")
	t.assert_eq(app.wall_design.to_dict(), untouched, "Reading the briefs never prepares or edits the player's own tile")
	await _press(t, studio, "WallAccept")
	await _press(t, studio, "WallFinishTile")
	await _press(t, studio, "WallReview")
	var submit: Button = studio.find_child("WallSubmit", true, false) as Button
	t.assert_true(submit == null or not submit.is_visible_in_tree() or submit.disabled, "An unfinished wall does not enable payment")
	t.assert_eq(app._economy_state.balance, initial_balance, "Accepting and inspecting an unfinished commission earn no money")
	await _press(t, studio, "WallEditTile")
	for button_name: String in ["WallMotif_trapezoid_pair", "WallPiece_0", "WallColor_0", "WallPiece_1", "WallColor_1", "WallTileColumnsMore", "WallFinishTile", "WallColumnsMore", "WallReview"]:
		await _press(t, studio, button_name)
	var offer: Dictionary = app.wall_design.evaluate()
	t.assert_true(bool(offer.ok), "Repeating the colored quadrilaterals inside a tile and then repeating that tile fulfills the harbor commission")
	var reward: int = int(offer.reward)
	t.assert_gt(reward, 0, "The completed commission quotes a positive reward")
	_test_disk_payment(t, app._economy_state, reward)
	await _press(t, studio, "WallSubmit")
	t.assert_eq(app._economy_state.balance, initial_balance + reward, "Delivering through the visible submit button credits the shared wallet")
	var completed: Dictionary = app.wall_design.to_dict()
	app._claim_wall_commission()
	t.assert_eq(app._economy_state.balance, initial_balance + reward, "A repeated delivery cannot pay twice")
	await _press(t, studio, "WallHome")
	t.assert_true(app._home_screen.visible and not studio.visible, "The wall artist can return to the home menu")
	await _press(t, app._home_screen, "OpenWall")
	t.assert_eq(app.wall_design.to_dict(), completed, "Reopening the wall workbench preserves the submitted design and its receipt")
	app.free()
	await t.get_tree().process_frame

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
