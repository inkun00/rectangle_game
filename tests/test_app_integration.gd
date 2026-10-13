class_name TestAppIntegration
extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")

static func run(t: Node) -> void:
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	await t.get_tree().process_frame
	t.assert_true(app._start_button.disabled, "Incomplete template cannot enter world")
	app._enter_world()
	t.assert_false(app._in_world, "World entry validates completion beyond disabled button")
	app.document.fill_example()
	t.assert_false(app._start_button.disabled, "Complete character enables exploration")
	app._enter_world()
	await t.get_tree().physics_frame
	t.assert_true(app._in_world, "Workshop starts the real world scene")
	t.assert_eq(app.world.player.character["parts"].size(), app.document.shapes.size(), "Drawn character is the actual player")
	t.assert_eq(app.world.player.world_width, QuadrilateralWorld.WORLD_WIDTH, "Actual scene configures player for entire expanded world")
	var quest: Dictionary = QuestCatalog.get_quest("rhombus_chocolates")
	t.assert_true(str(app._quest_waypoint("rhombus_chocolates").get("name", "")).contains(str(quest.npc_name)), "Unaccepted quest guidance leads to its resident")
	var first: Dictionary = _pickup(app, "rhombus_chocolate_0")
	var collected_events: Array[Dictionary] = []
	app.world.item_collected.connect(func(label: String, quest_id: String, count: int, required: int):
		collected_events.append({"label": label, "quest": quest_id, "count": count, "required": required}))
	t.assert_false(app.journal.accepted.has("rhombus_chocolates"), "First pickup happens before accepting its quest")
	app.world.player.position = Vector2(first.position) + Vector2(0, 43)
	app.world.player.velocity = Vector2.ZERO
	t.assert_eq(str(app.world.nearby_pickup().get("id", "")), str(first.id), "Nearby item API identifies visible chocolate")
	_press_pickup()
	t.assert_eq(int(app.journal.inventory.get("rhombus_chocolate", 0)), 1, "Main G handler collects a world item before quest acceptance")
	t.assert_eq(collected_events.size(), 1, "A successful pickup emits one explicit collection event")
	if not collected_events.is_empty():
		t.assert_eq(collected_events[0].count, 1, "Pickup feedback reports current count")
		t.assert_eq(collected_events[0].required, int(quest.target_count), "Pickup feedback reports required quest amount")
	t.assert_true(app._toast.visible, "Collection feedback is visible in actual application")
	t.assert_true(app._toast.text.contains(str(quest.get("item_name", first.label))), "Pickup toast identifies collected item")
	app._show_inventory()
	var inventory_text: String = _labels(app._modal_body)
	t.assert_true(inventory_text.contains(str(quest.get("item_name", first.label))), "Inventory displays the collected item's own name")
	t.assert_true(inventory_text.contains("1"), "Inventory displays pre-acceptance collection count")
	app._close_modal()
	app._talk_to_npc("baker")
	t.assert_false(app.world.controls_enabled, "NPC dialogue locks player controls")
	var accept_button: Button = _button(app._modal_body, "제가 도와드릴게요!")
	t.assert_not_null(accept_button, "Actual NPC dialogue offers quest acceptance")
	if accept_button != null: accept_button.pressed.emit()
	t.assert_true(app.journal.accepted.has("rhombus_chocolates"), "NPC button accepts quest with existing inventory")
	t.assert_eq(int(app.journal.inventory.get("rhombus_chocolate", 0)), 1, "Quest acceptance preserves items collected earlier")
	app._close_modal()
	var second: Dictionary = _pickup(app, "rhombus_chocolate_1")
	var remaining_goal: Dictionary = app._quest_waypoint("rhombus_chocolates")
	t.assert_eq(Vector2(remaining_goal.get("position", Vector2.ZERO)), Vector2(second.position), "Accepted quest guidance skips the already collected first item")
	app.world.player.position = Vector2(second.position) + Vector2(0, 43)
	app.world.player.velocity = Vector2.ZERO
	for frame: int in range(3): await t.get_tree().physics_frame
	t.assert_eq(int(app.journal.inventory.get("rhombus_chocolate", 0)), 2, "Existing proximity auto-pickup still works without pressing G")
	for index: int in range(2, int(quest.target_count)):
		var item: Dictionary = _pickup(app, "rhombus_chocolate_%d" % index)
		app.world.player.position = Vector2(item.position) + Vector2(0, 43)
		app.world.player.velocity = Vector2.ZERO
		_press_pickup()
	t.assert_true(app.journal.can_turn_in("rhombus_chocolates"), "Explicit and automatic pickup together satisfy quest objective")
	t.assert_true(str(app._quest_waypoint("rhombus_chocolates").get("name", "")).contains(str(quest.npc_name)), "Ready quest guidance returns to its resident instead of collected items")
	t.assert_true(app._active_quests.text.contains(app.journal.progress_text("rhombus_chocolates")), "Live quest HUD reflects completed collection progress")
	app._talk_to_npc("baker")
	t.assert_eq(app.journal.quest_state("rhombus_chocolates"), "ready", "Opening dialogue alone never completes a quest")
	var correct: int = int(quest.answer)
	var wrong: int = (correct + 1) % quest.options.size()
	var wrong_button: Button = _button(app._modal_body, str(quest.options[wrong]))
	t.assert_not_null(wrong_button, "Ready dialogue offers curriculum answer options")
	if wrong_button != null: wrong_button.pressed.emit()
	t.assert_eq(app.journal.completed_count(), 0, "Wrong UI answer leaves quest available for retry")
	t.assert_eq(int(app.journal.inventory.get("rhombus_chocolate", 0)), int(quest.target_count), "Wrong answer keeps all gathered items")
	var correct_button: Button = _button(app._modal_body, str(quest.options[correct]))
	t.assert_not_null(correct_button, "Correct learning answer remains available after feedback")
	if correct_button != null: correct_button.pressed.emit()
	t.assert_eq(app.journal.completed_count(), 1, "Correct UI answer completes exploration quest")
	t.assert_eq(app.journal.coins, int(quest.reward), "Completion reward is applied once")
	t.assert_eq(int(app.journal.inventory.get("rhombus_chocolate", 0)), 0, "Turn-in consumes required item inventory")
	app._close_modal()
	app._return_workshop()
	t.assert_false(app._in_world, "Can return to workshop")
	app._enter_world()
	t.assert_true(app.world.camera.enabled, "Camera restored when reentering world")
	t.assert_eq(app.journal.completed_count(), 1, "Editing round trip preserves quests")
	t.assert_false(app.world.collect_pickup("rhombus_chocolate_0"), "Editing round trip cannot farm pickups")
	var save_path: String = "res://.godot/quad_app_integration_%d.json" % Time.get_ticks_usec()
	t.assert_eq(WorldSaveStore.save_game(app.document.serialize(), app.journal.serialize(), app.world.serialize(), save_path, app.adventure.serialize()), OK, "Save file is written atomically")
	var saved: Dictionary = WorldSaveStore.load_game(save_path)
	t.assert_eq(int(saved.get("version", 0)), 1, "Save file version round trip")
	app.free()
	await t.get_tree().process_frame
	var restored: QuadrilateralApp = AppScene.instantiate()
	restored.testing = true
	t.add_child(restored)
	await t.get_tree().process_frame
	t.assert_true(restored.document.restore(saved.editor), "Saved vertices and colors restore into real main application")
	t.assert_true(restored.journal.restore(saved.journal), "Saved collection and quest progress restores into main")
	t.assert_true(restored.adventure.restore(saved.adventure), "Saved RPG rewards restore into main")
	restored._world_data = saved.world.duplicate(true)
	restored._enter_world()
	t.assert_true(restored._in_world, "Restored character can enter expanded world")
	t.assert_eq(restored.journal.completed_count(), 1, "Restored quest completion persists")
	t.assert_false(restored.world.collect_pickup("rhombus_chocolate_0"), "Restored world cannot recollect turned-in item")
	t.assert_eq(WorldSaveStore.save_game(restored.document.serialize(), restored.journal.serialize(), restored.world.serialize(), save_path, restored.adventure.serialize()), OK, "Replacing save preserves a backup")
	for path: String in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	restored.free()
	await t.get_tree().process_frame

static func _pickup(app: QuadrilateralApp, id: String) -> Dictionary:
	for item: Dictionary in app.world.collectibles:
		if str(item.id) == id: return item
	return {}

static func _button(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == text: return button
	return null

static func _labels(root: Node) -> String:
	var texts: PackedStringArray = PackedStringArray()
	for node: Node in root.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	return "\n".join(texts)

static func _press_pickup() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_G
	key.physical_keycode = KEY_G
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	var release: InputEventKey = key.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
