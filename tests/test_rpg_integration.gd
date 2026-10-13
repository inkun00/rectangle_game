class_name TestRpgIntegration
extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")

static func run(t: Node) -> void:
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	await t.get_tree().process_frame
	app.document.fill_example()
	app._enter_world()
	var player: WorldPlayer = app.world.player
	t.assert_true(app._in_world, "RPG test enters actual main application world")
	t.assert_eq(app.adventure.hp, player.hp, "Persistent adventure and live player start with synchronized HP")
	var hp_before: int = app.adventure.hp
	t.assert_true(player.take_damage(55, player.global_position.x - 100.0), "Live player receives real damage")
	t.assert_eq(app.adventure.hp, hp_before - 55, "Main damage signal updates AdventureState exactly once")
	t.assert_eq(player.hp, app.adventure.hp, "Damage is synchronized back without double subtraction")
	var immunity: float = player.invulnerability
	t.assert_gt(immunity, 0.0, "Main HP synchronization preserves newly granted immunity")
	t.assert_false(player.take_damage(55, player.global_position.x - 100.0), "Repeated contact is blocked after main state synchronization")
	t.assert_eq(app.adventure.hp, hp_before - 55, "Blocked contact leaves persistent HP unchanged")
	t.assert_true(player.begin_attack(), "Live player can begin an attack after contact")
	var cooldown: float = player.attack_cooldown
	var attack_pose: float = player._attack_pose_left
	app.adventure.discover("forest")
	t.assert_eq(player.invulnerability, immunity, "Discovery-triggered main HP sync preserves immunity")
	t.assert_eq(player.attack_cooldown, cooldown, "Discovery-triggered main HP sync preserves attack cooldown")
	t.assert_eq(player._attack_pose_left, attack_pose, "Discovery-triggered main HP sync preserves attack animation")
	t.assert_false(player.begin_attack(), "Persistent state updates cannot bypass attack cooldown")
	var potions_before: int = app.adventure.potions
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_Q
	key.physical_keycode = KEY_Q
	key.pressed = true
	app._unhandled_key_input(key)
	t.assert_eq(app.adventure.potions, potions_before - 1, "Main Q handler consumes exactly one potion")
	t.assert_eq(app.adventure.hp, hp_before - 15, "Q restores exactly forty HP below the maximum")
	t.assert_eq(player.hp, app.adventure.hp, "Potion synchronizes the live player immediately")
	t.assert_eq(player.invulnerability, immunity, "Potion health sync preserves ongoing immunity")
	t.assert_eq(player.attack_cooldown, cooldown, "Potion health sync preserves attack cooldown")
	key.echo = true
	app._unhandled_key_input(key)
	t.assert_eq(app.adventure.potions, potions_before - 1, "Repeated-key echo cannot consume extra potions")
	key.echo = false
	app._show_inventory()
	var paused_position: Vector2 = player.position
	var paused_cooldown: float = player.attack_cooldown
	var paused_potions: int = app.adventure.potions
	app._unhandled_key_input(key)
	for frame: int in range(4):
		await t.get_tree().physics_frame
	t.assert_false(app.world.controls_enabled, "Inventory modal pauses the world")
	t.assert_false(player.controls_enabled, "Inventory modal pauses live player controls")
	t.assert_eq(player.position, paused_position, "Modal pauses falling and movement")
	t.assert_eq(player.attack_cooldown, paused_cooldown, "Modal pauses combat timers")
	t.assert_eq(app.adventure.potions, paused_potions, "Global potion key is blocked behind modal")
	t.assert_false(player.begin_attack(), "Modal also blocks direct player attack requests")
	app._close_modal()
	t.assert_true(app.world.controls_enabled, "Closing inventory resumes world controls")
	var location_before: Vector2 = player.position
	t.assert_false(app.world.travel_to("valley"), "Undiscovered region cannot be used for fast travel")
	t.assert_eq(player.position, location_before, "Rejected travel preserves player position")
	app._show_travel()
	var travel_buttons: Array[Node] = app._modal_body.find_children("*", "Button", true, false)
	var forest_button: Button = null
	var valley_button: Button = null
	for node: Node in travel_buttons:
		var button: Button = node as Button
		if button.text.begins_with("바람 숲"):
			forest_button = button
		elif button.text.begins_with("평행 계곡"):
			valley_button = button
	t.assert_not_null(forest_button, "Travel UI contains forest destination")
	t.assert_not_null(valley_button, "Travel UI contains valley destination")
	if forest_button != null and valley_button != null:
		t.assert_false(forest_button.disabled, "Previously discovered forest travel is enabled")
		t.assert_true(valley_button.disabled, "Undiscovered valley travel stays disabled")
		forest_button.pressed.emit()
		t.assert_eq(player.position, QuadrilateralWorld.REGION_SPAWNS["forest"], "Travel button moves to discovered-region checkpoint")
		t.assert_eq(app.world.serialize()["checkpoint_region"], "forest", "Travel establishes persistent region checkpoint")
		t.assert_true(app.world.controls_enabled, "Successful travel closes modal and resumes movement")
	app._close_modal()
	app.journal.coins = 30
	app.journal.changed.emit()
	app.journal.accept_quest("trapezoid_roofs")
	app.world.collect_pickup("trapezoid_tile_0")
	var inventory_before_death: Dictionary = app.journal.inventory.duplicate(true)
	var coins_before_death: int = app.journal.coins
	var potions_before_death: int = app.adventure.potions
	player.position = Vector2(2200, QuadrilateralWorld.GROUND_Y)
	player.invulnerability = 0.0
	t.assert_true(player.take_damage(1000, 2250), "Lethal hit reaches the main defeat handler")
	t.assert_eq(app.adventure.hp, app.adventure.max_hp, "Defeat handler fully restores persistent health")
	t.assert_eq(player.hp, app.adventure.hp, "Defeat handler restores live player health")
	t.assert_eq(player.position, QuadrilateralWorld.REGION_SPAWNS["forest"], "Defeat returns player to discovered forest checkpoint")
	t.assert_eq(app.journal.coins, coins_before_death, "Defeat keeps earned coins")
	t.assert_eq(app.journal.inventory, inventory_before_death, "Defeat keeps collected quest objects")
	t.assert_eq(app.adventure.potions, potions_before_death, "Defeat does not consume a potion")
	t.assert_gt(player.invulnerability, 0.0, "Checkpoint recovery grants safe respawn immunity")
	var enemy: Dictionary = app.world.enemies[0]
	player.position = Vector2(enemy.position) + Vector2(-80, 0)
	player.facing = 1.0
	player.attack_cooldown = 0.0
	var xp_before: int = app.adventure.xp
	t.assert_true(player.begin_attack(), "Player attack signal reaches the real world hit test")
	t.assert_eq(int(enemy.hp), 1, "First accepted attack removes one of two enemy HP")
	t.assert_eq(app.adventure.xp, xp_before, "First hit does not award defeat experience")
	player.attack_cooldown = 0.0
	t.assert_true(player.begin_attack(), "Second accepted attack completes encounter")
	t.assert_eq(int(enemy.hp), 0, "Second hit defeats enemy")
	t.assert_eq(app.adventure.xp, xp_before + 20, "World defeat signal awards twenty XP through main")
	t.assert_true(app.adventure.defeated_enemies.has(str(enemy.id)), "Main records stable defeated-enemy identity")
	t.assert_gt(player.attack_cooldown, 0.0, "XP sync does not reset attack cooldown")
	app.world.attack_at(Vector2(enemy.position) + Vector2(-58, -58), 1.0)
	app._on_enemy_defeated(str(enemy.id))
	t.assert_eq(app.adventure.xp, xp_before + 20, "Repeated hit or defeat signal cannot award XP again")
	app._show_service("shop")
	var shop_buttons: Array[Node] = app._modal_body.find_children("*", "Button", true, false)
	var purchase_button: Button = null
	for node: Node in shop_buttons:
		var button: Button = node as Button
		if button.text.contains("회복약 구입"):
			purchase_button = button
	t.assert_not_null(purchase_button, "Shop exposes potion purchase UI")
	var coins_before_shop: int = app.journal.coins
	var potions_before_shop: int = app.adventure.potions
	if purchase_button != null:
		purchase_button.pressed.emit()
	t.assert_eq(app.journal.coins, coins_before_shop - 10, "Shop spends coins from the one QuestJournal balance")
	t.assert_eq(app.adventure.potions, potions_before_shop + 1, "Shop adds exactly one persistent potion")
	app._close_modal()
	# Unique test path: no default user save is read or written by this suite.
	var save_path: String = "res://.godot/rpg_integration_%d.json" % Time.get_ticks_usec()
	t.assert_eq(WorldSaveStore.save_game(app.document.serialize(), app.journal.serialize(), app.world.serialize(), save_path, app.adventure.serialize()), OK, "Combined RPG save writes optional AdventureState")
	var saved: Dictionary = WorldSaveStore.load_game(save_path)
	t.assert_true(saved.has("adventure"), "Combined save includes persistent RPG data")
	var restored_adventure: AdventureState = AdventureState.new()
	var restored_journal: QuestJournal = QuestJournal.new()
	t.assert_true(restored_adventure.restore(saved.get("adventure", {})), "Saved adventure validates and restores")
	t.assert_true(restored_journal.restore(saved.get("journal", {})), "Saved journal validates and restores")
	t.assert_eq(restored_adventure.serialize(), app.adventure.serialize(), "Health, XP, potions, defeats and discoveries round-trip")
	t.assert_eq(restored_journal.serialize(), app.journal.serialize(), "Shop balance and quest items round-trip")
	t.assert_eq(saved.get("world", {}).get("checkpoint_region", ""), "forest", "Checkpoint is included in combined RPG save")
	for path: String in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	app.free()
	await t.get_tree().process_frame
	await _test_new_region_collection_and_story(t)

static func _test_new_region_collection_and_story(t: Node) -> void:
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	await t.get_tree().process_frame
	app.document.set_template("cat")
	app.document.fill_example()
	app._enter_world()
	var new_quests: Array[Dictionary] = []
	var new_regions: Dictionary = {}
	for quest: Dictionary in QuestCatalog.all_quests():
		if str(quest.get("region", "")) in ["harbor", "snow", "citadel"]:
			new_quests.append(quest)
			new_regions[str(quest.region)] = true
	t.assert_eq(QuestCatalog.all_quests().size(), 16, "Expanded world exposes sixteen NPC adventures")
	t.assert_eq(new_quests.size(), 8, "Eight new story quests live in the expansion")
	t.assert_eq(new_regions.size(), 3, "Harbor, snow and citadel all have their own quests")
	t.assert_eq(app.world.npcs.size(), 16, "Every catalog quest has an actual world NPC")
	t.assert_eq(app.world.player.world_width, 11000.0, "Main world supports all six regions without old edge clamp")
	var story_key: InputEventKey = InputEventKey.new()
	story_key.keycode = KEY_H
	story_key.physical_keycode = KEY_H
	story_key.pressed = true
	app._unhandled_key_input(story_key)
	t.assert_false(app.world.controls_enabled, "H opens the story journal and pauses exploration")
	var opening_story: String = _labels(app._modal_body)
	for region: Dictionary in QuadrilateralWorld.REGION_DATA:
		var chapter: Dictionary = QuestCatalog.region_story(str(region.id))
		t.assert_true(opening_story.contains(str(chapter.title)), "Story journal lists region chapter: " + str(region.id))
		t.assert_false(opening_story.contains(str(chapter.outro)), "Unfinished region story does not reveal its ending: " + str(region.id))
	app._close_modal()
	var expected_coins: int = 0
	var finished: int = 0
	for quest: Dictionary in new_quests:
		var quest_id: String = str(quest.id)
		var target: String = str(quest.target)
		var item_name: String = str(quest.get("item_name", ""))
		var pickups: Array[Dictionary] = []
		for item: Dictionary in app.world.collectibles:
			if str(item.quest) == quest_id: pickups.append(item)
		t.assert_eq(pickups.size(), int(quest.target_count), "New quest has all physically present required items: " + quest_id)
		t.assert_false(item_name.is_empty(), "New quest exposes an inventory item name")
		t.assert_false(app.journal.accepted.has(quest_id), "Expansion objects can be found before NPC conversation")
		for item: Dictionary in pickups:
			app.world.player.position = Vector2(item.position) + Vector2(0, 43)
			app.world.player.velocity = Vector2.ZERO
			var nearby: Dictionary = app.world.nearby_pickup()
			t.assert_eq(str(nearby.get("id", "")), str(item.id), "Expanded-region item is exposed by nearby pickup API")
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
			t.assert_true(app.world.serialize()["collected"].has(str(item.id)), "Actual main G input collects expansion item: " + str(item.id))
		for frame: int in range(2): await t.get_tree().physics_frame
		for frame: int in range(2): await t.get_tree().process_frame
		t.assert_gt(app.world.player.position.x, 5200.0, "Physics does not clamp expansion character back to old map")
		t.assert_true(app.adventure.discovered_regions.has(str(quest.region)), "Entering expanded region discovers it persistently")
		t.assert_eq(int(app.journal.inventory.get(target, 0)), int(quest.target_count), "All pre-accepted new quest items remain in inventory")
		app._show_inventory()
		var bag_text: PackedStringArray = PackedStringArray()
		for node: Node in app._modal_body.find_children("*", "Label", true, false):
			bag_text.append((node as Label).text)
		t.assert_true("\n".join(bag_text).contains(item_name), "Actual inventory UI names expansion item before quest acceptance")
		app._close_modal()
		if finished == 0:
			# Recreate the actual app with pre-acceptance inventory to catch the reported lost-item flow.
			var save_path: String = "res://.godot/quad_expansion_%d.json" % Time.get_ticks_usec()
			t.assert_eq(WorldSaveStore.save_game(app.document.serialize(), app.journal.serialize(), app.world.serialize(), save_path, app.adventure.serialize()), OK, "Expansion pre-acceptance pickup save succeeds")
			var saved: Dictionary = WorldSaveStore.load_game(save_path)
			app.free()
			await t.get_tree().process_frame
			app = AppScene.instantiate()
			app.testing = true
			t.add_child(app)
			await t.get_tree().process_frame
			t.assert_true(app.document.restore(saved.editor), "Expansion save restores authored character")
			t.assert_true(app.journal.restore(saved.journal), "Expansion save restores inventory before quest acceptance")
			t.assert_true(app.adventure.restore(saved.adventure), "Expansion save restores discovered region")
			app._world_data = saved.world.duplicate(true)
			app._enter_world()
			t.assert_eq(int(app.journal.inventory.get(target, 0)), int(quest.target_count), "Pre-acceptance inventory survives full main recreation")
			t.assert_false(app.journal.accepted.has(quest_id), "Loading inventory does not silently accept quest")
			for item: Dictionary in pickups:
				t.assert_false(app.world.collect_pickup(str(item.id)), "Saved expansion pickup cannot be duplicated")
			for path: String in [save_path, save_path + ".bak", save_path + ".tmp"]:
				if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		app._talk_to_npc(str(quest.npc_id))
		var accept: Button = _find_button(app._modal_body, "제가 도와드릴게요!")
		t.assert_not_null(accept, "Expansion NPC presents an actual acceptance button")
		if accept != null: accept.pressed.emit()
		t.assert_eq(app.journal.quest_state(quest_id), "ready", "Accepting new quest recognizes items found earlier")
		t.assert_true(app._active_quests.text.contains(app.journal.progress_text(quest_id)), "Main quest HUD displays new quest inventory progress")
		app._close_modal()
		app._talk_to_npc(str(quest.npc_id))
		var correct: int = int(quest.answer)
		var wrong: int = (correct + 1) % quest.options.size()
		var wrong_answer: Button = _find_button(app._modal_body, str(quest.options[wrong]))
		t.assert_not_null(wrong_answer, "New quest offers learning choices through dialogue UI")
		if wrong_answer != null: wrong_answer.pressed.emit()
		t.assert_eq(app.journal.quest_state(quest_id), "ready", "Wrong new quest answer preserves retry state")
		t.assert_eq(int(app.journal.inventory.get(target, 0)), int(quest.target_count), "Wrong new quest answer preserves objects")
		var right_answer: Button = _find_button(app._modal_body, str(quest.options[correct]))
		t.assert_not_null(right_answer, "Correct expansion learning answer is present")
		if right_answer != null: right_answer.pressed.emit()
		finished += 1
		expected_coins += int(quest.reward)
		t.assert_eq(app.journal.quest_state(quest_id), "completed", "New NPC quest completes through real dialogue")
		t.assert_eq(int(app.journal.inventory.get(target, 0)), 0, "Successful new quest consumes its collected objects")
		t.assert_eq(app.journal.coins, expected_coins, "New quest pays one exact coin reward")
		t.assert_true(app.adventure.claimed_quests.has(quest_id), "New story completion awards persistent RPG progress")
		app._close_modal()
	t.assert_eq(app.journal.completed_count(), new_quests.size(), "All eight new-region quests complete end to end")
	t.assert_true(app._world_stats.text.contains("%d / %d" % [new_quests.size(), QuestCatalog.all_quests().size()]), "HUD completion denominator includes all sixteen residents")
	app._show_story()
	var completed_story: String = _labels(app._modal_body)
	for region: Dictionary in QuadrilateralWorld.REGION_DATA:
		var is_expansion: bool = str(region.id) in ["harbor", "snow", "citadel"]
		t.assert_eq(app._region_completed(str(region.id)), is_expansion, "Region completion is based on only its own residents: " + str(region.id))
		t.assert_eq(completed_story.contains(str(QuestCatalog.region_story(str(region.id)).outro)), is_expansion, "Story endings unlock only for completed regions: " + str(region.id))
	app._close_modal()
	for region: String in ["harbor", "snow", "citadel"]:
		t.assert_true(app.world.travel_to(region), "Explored expansion region supports return travel: " + region)
		t.assert_eq(app.world.player.position, QuadrilateralWorld.REGION_SPAWNS[region], "Travel reaches the correct new-region checkpoint")
	app.free()
	await t.get_tree().process_frame

static func _find_button(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == text: return button
	return null

static func _labels(root: Node) -> String:
	var texts: PackedStringArray = PackedStringArray()
	for node: Node in root.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	return "\n".join(texts)
