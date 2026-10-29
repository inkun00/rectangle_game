class_name TestWorldGame
extends RefCounted

const World = preload("res://scenes/world/quadrilateral_world.gd")
const Journal = preload("res://scripts/world/quest_journal.gd")
const Catalog = preload("res://scripts/world/quest_catalog.gd")
const Templates = preload("res://scripts/core/character_templates.gd")
const Adventure = preload("res://scripts/world/adventure_state.gd")


static func run(runner: Node) -> void:
	var journal: QuestJournal = Journal.new()
	var world: QuadrilateralWorld = World.new()
	runner.add_child(world)
	world.setup(Templates.get_template("robot"), journal)
	runner.assert_eq(world.npcs.size(), 16, "Every quest has an NPC in the world")
	runner.assert_eq(world.collectibles.size(), 41, "All 41 objectives exist as unique pickups")
	runner.assert_eq(world.navigation_points().size(), 16, "Map has all NPC destinations")
	runner.assert_eq(World.region_at(1599.0)["id"], "market", "Market ends before forest")
	runner.assert_eq(World.region_at(1600.0)["id"], "forest", "Forest boundary belongs to forest")
	runner.assert_eq(World.region_at(3300.0)["id"], "valley", "Valley boundary belongs to valley")
	runner.assert_eq(World.region_at(5200.0)["id"], "harbor", "The original eastern boundary now leads to the harbor")
	runner.assert_eq(World.region_at(7000.0)["id"], "snow", "Harbor trail reaches the snow region")
	runner.assert_eq(World.region_at(8800.0)["id"], "citadel", "Snow trail reaches the citadel")
	runner.assert_float_approx(world.player.world_width, World.WORLD_WIDTH, 0.01, "Player movement covers the entire expanded map")
	var seen: Dictionary = {}
	for item: Dictionary in world.collectibles:
		runner.assert_false(seen.has(item["id"]), "Pickup instance IDs are unique")
		seen[item["id"]] = true
	for quest: Dictionary in Catalog.all_quests():
		var count: int = 0
		for item: Dictionary in world.collectibles:
			if item["target"] == quest["target"]:
				count += 1
		runner.assert_eq(count, int(quest["target_count"]), "Every quest target count is available in the world")
	runner.assert_true(world.collect_pickup("rhombus_chocolate_0"), "Items can be collected before accepting their quest")
	journal.accept_quest("rhombus_chocolates")
	runner.assert_eq(journal.inventory.get("rhombus_chocolate"), 1, "Accepting the quest preserves items already in the bag")
	runner.assert_false(world.collect_pickup("rhombus_chocolate_0"), "Unique pickup cannot be farmed")
	var snapshot: Dictionary = world.serialize()
	world.restore(snapshot)
	runner.assert_false(world.collect_pickup("rhombus_chocolate_0"), "Reload keeps pickup consumed")
	runner.assert_eq(world.serialize()["collected"].size(), 1, "One unique pickup is serialized")
	world.restore({"player_x": -900.0, "player_y": 4000.0, "collected": ["forged_id", "rhombus_chocolate_0"]})
	runner.assert_float_approx(world.player.position.x, 36.0, 0.01, "Saved horizontal position is clamped")
	runner.assert_float_approx(world.player.position.y, World.GROUND_Y, 0.01, "Saved vertical position cannot fall through ground")
	runner.assert_eq(world.serialize()["collected"].size(), 1, "Unknown saved pickup ids are ignored")
	runner.assert_true(World.is_valid_save({}), "An unentered world uses an empty save")
	for invalid: Dictionary in [{"player_x": INF}, {"player_y": NAN}, {"player_x": "280"}, {"player_y": {}}, {"player_x": true}, {"collected": {}}, {"collected": [17]}, {"collected": [null]}, {"collected": "rhombus_chocolate_0"}]:
		runner.assert_false(World.is_valid_save(invalid), "Malformed world save is rejected: " + str(invalid))
	var stable_snapshot: Dictionary = world.serialize()
	world.restore({"player_x": "invalid", "collected": []})
	runner.assert_eq(world.serialize(), stable_snapshot, "Rejected restore preserves current world state")
	world.player.position = Vector2(485, World.GROUND_Y)
	runner.assert_eq(world.nearest_interaction().get("id", ""), "baker", "E finds the nearest quest NPC")
	world.player.position = Vector2(280, World.GROUND_Y)
	for frame: int in range(6):
		await runner.get_tree().physics_frame
	runner.assert_true(world.player.is_on_floor(), "Character stands on real collidable ground")
	var start_x: float = world.player.position.x
	_press(KEY_D, true)
	for frame: int in range(12):
		await runner.get_tree().physics_frame
	_press(KEY_D, false)
	runner.assert_gt(world.player.position.x, start_x + 15.0, "Keyboard D moves the custom character")
	_press(KEY_SPACE, true)
	for frame: int in range(6):
		await runner.get_tree().physics_frame
	_press(KEY_SPACE, false)
	runner.assert_lt(world.player.position.y, World.GROUND_Y - 20.0, "Space jumps above ground")
	for frame: int in range(65):
		await runner.get_tree().physics_frame
	runner.assert_true(world.player.is_on_floor(), "Character lands after jumping")
	world.set_controls_enabled(false)
	var locked_x: float = world.player.position.x
	_press(KEY_D, true)
	for frame: int in range(8):
		await runner.get_tree().physics_frame
	_press(KEY_D, false)
	runner.assert_float_approx(world.player.position.x, locked_x, 0.05, "Modal disables world movement")
	world.player.position.y = 1300.0
	for frame: int in range(3):
		await runner.get_tree().physics_frame
	runner.assert_lt(world.player.position.y, 710.0, "Out of bounds fall safely respawns")
	world.free()
	_test_explicit_pickup_controls(runner)
	await _test_walkable_collection_route(runner)
	await _test_rpg_services_combat_and_travel(runner)
	_test_same_instance_adventure_restore(runner)
	_test_story_landmark_restoration(runner)


static func _test_story_landmark_restoration(runner: Node) -> void:
	var journal: QuestJournal = Journal.new()
	var empty_story: Dictionary = journal.serialize()
	var world: QuadrilateralWorld = World.new()
	world.setup(Templates.get_template("robot"), journal)
	runner.add_child(world)
	for region: String in ["harbor", "snow", "citadel"]:
		var landmark: Sprite2D = world._artwork.story_landmarks[region]
		runner.assert_eq(landmark.modulate, world._artwork.DORMANT_STORY_COLOR, "Unfinished chapter leaves its landmark dormant: " + region)
		var quests: Array[Dictionary] = []
		for quest: Dictionary in Catalog.all_quests():
			if quest["region"] == region:
				quests.append(quest)
		for index: int in range(quests.size()):
			var quest: Dictionary = quests[index]
			journal.accept_quest(str(quest["id"]))
			for count: int in range(int(quest["target_count"])):
				journal.collect_item(str(quest["target"]))
			journal.answer_quest(str(quest["id"]), int(quest["answer"]))
			if index == quests.size() - 2:
				runner.assert_eq(landmark.modulate, world._artwork.DORMANT_STORY_COLOR, "Partial completion does not relight the whole chapter: " + region)
		runner.assert_eq(landmark.modulate, Color.WHITE, "Finishing all regional quests immediately restores its light: " + region)
	var saved: Dictionary = JSON.parse_string(JSON.stringify({"journal": journal.serialize(), "world": world.serialize()}))
	world.free()
	journal = Journal.new()
	runner.assert_true(journal.restore(saved["journal"]), "Completed story journal reloads from JSON")
	world = World.new()
	world.setup(Templates.get_template("robot"), journal)
	world.restore(saved["world"])
	runner.add_child(world)
	for region: String in ["harbor", "snow", "citadel"]:
		var landmark: Sprite2D = world._artwork.story_landmarks[region]
		runner.assert_eq(landmark.modulate, Color.WHITE, "Reloaded completed story retains its restored light: " + region)
	runner.assert_true(journal.restore(empty_story), "An earlier unfinished story can replace the same journal")
	for region: String in ["harbor", "snow", "citadel"]:
		var landmark: Sprite2D = world._artwork.story_landmarks[region]
		runner.assert_eq(landmark.modulate, world._artwork.DORMANT_STORY_COLOR, "Earlier save restores the dormant appearance: " + region)
	world.free()


static func _test_explicit_pickup_controls(runner: Node) -> void:
	var journal: QuestJournal = Journal.new()
	var world: QuadrilateralWorld = World.new()
	world.setup(Templates.get_template("robot"), journal)
	runner.add_child(world)
	var announcements: Array[Dictionary] = []
	world.item_collected.connect(func(label: String, quest_id: String, count: int, required: int) -> void: announcements.append({"label": label, "quest": quest_id, "count": count, "required": required}))
	world.player.position = Vector2(2470, World.GROUND_Y)
	runner.assert_true(world.nearby_pickup().is_empty(), "A high platform item cannot be picked through its floor")
	runner.assert_false(world.pickup_nearest(), "G refuses an item on another height")
	world.player.position = Vector2(7870, 589)
	runner.assert_eq(world.nearest_interaction().get("type"), "item", "E gives nearby collectible priority over the snow NPC")
	world.interact()
	runner.assert_eq(journal.inventory.get("rhombus_lantern"), 1, "E collects a snow item before talking to the NPC")
	world.player.position = Vector2(5910, 485)
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_G
	event.pressed = true
	world._unhandled_key_input(event)
	runner.assert_eq(journal.inventory.get("trapezoid_sail"), 1, "G keyboard event collects the harbor item")
	runner.assert_eq(announcements.size(), 2, "Successful pickups emit exactly one progress announcement")
	runner.assert_eq(announcements[1], {"label": "사다리꼴 돛", "quest": "harbor_sails", "count": 1, "required": 3}, "Collection signal carries the visible objective and counts")
	world.player.position = Vector2(10260, 589)
	world.set_controls_enabled(false)
	runner.assert_false(world.pickup_nearest(), "A modal blocks the dedicated pickup button")
	runner.assert_false(journal.inventory.has("square_core"), "Paused pickup does not change inventory")
	world.set_controls_enabled(true)
	runner.assert_true(world.pickup_nearest(), "The citadel item is collectable once controls resume")
	for npc: Dictionary in world.npcs:
		var sprite: Sprite2D = world._artwork.npc_sprites[str(npc["id"])]
		runner.assert_true(sprite.texture != null, "NPC has a valid atlas texture: " + str(npc["id"]))
	for item: Dictionary in world.collectibles:
		var sprite: Sprite2D = world._artwork.pickup_sprites[str(item["id"])]
		runner.assert_true(sprite.texture != null, "Collectible has a valid atlas texture: " + str(item["id"]))
	world.free()


static func _test_same_instance_adventure_restore(runner: Node) -> void:
	var adventure: Adventure = Adventure.new()
	var before_encounter: Dictionary = adventure.serialize()
	var world: QuadrilateralWorld = World.new()
	world.setup(Templates.get_template("robot"), Journal.new())
	world.configure_adventure(adventure)
	runner.add_child(world)
	world.enemy_defeated.connect(func(id: String) -> void: adventure.record_enemy_defeat(id))
	var enemy: Dictionary = world.get_enemy_status()[0]
	var origin: Vector2 = Vector2(enemy["position"]) + Vector2(-60, -35)
	world.attack_at(origin, 1.0)
	world.configure_adventure(adventure)
	runner.assert_eq(world.get_enemy_status()[0]["hp"], 1, "Ordinary reentry preserves damage to a living patrol")
	world.attack_at(origin, 1.0)
	world.configure_adventure(adventure)
	runner.assert_eq(world.get_enemy_status()[0]["hp"], 0, "Ordinary reentry preserves authoritative defeated encounters")
	runner.assert_true(adventure.restore(before_encounter), "An earlier save restores into the same adventure object")
	world.configure_adventure(adventure)
	runner.assert_eq(world.get_enemy_status()[0]["hp"], 2, "Same-object older save revives a patrol missing from its defeat record")
	runner.assert_eq(adventure.xp, 0, "Resynchronizing encounters does not grant experience")
	world.free()


static func _test_rpg_services_combat_and_travel(runner: Node) -> void:
	var journal: QuestJournal = Journal.new()
	var adventure: Adventure = Adventure.new()
	var world: QuadrilateralWorld = World.new()
	world.configure_adventure(adventure)
	world.setup(Templates.get_template("robot"), journal)
	runner.add_child(world)
	world.enemy_defeated.connect(func(id: String) -> void: adventure.record_enemy_defeat(id))
	world.player.damaged.connect(func(amount: int) -> void: adventure.damage(amount))
	await _frames(runner, 8)
	runner.assert_eq(world.get_enemy_status().size(), 7, "Seven textured patrol encounters inhabit the world")
	world.player.position = Vector2(650, World.GROUND_Y)
	runner.assert_eq(world.nearest_interaction().get("id"), "shop", "The supply chest opens the shop service")
	world.player.position = Vector2(205, World.GROUND_Y)
	runner.assert_eq(world.nearest_interaction().get("id"), "inn", "The village inn is independently accessible")
	world.player.position = Vector2(90, World.GROUND_Y)
	runner.assert_eq(world.nearest_interaction().get("id"), "travel", "Region portal opens the travel service")
	var first_enemy: Dictionary = world.get_enemy_status()[0]
	var attack_origin: Vector2 = Vector2(first_enemy["position"]) + Vector2(-60, -35)
	runner.assert_eq(world.attack_at(attack_origin, -1.0), 0, "Facing away cannot hit a patrol behind the player")
	runner.assert_eq(world.attack_at(attack_origin, 1.0), 1, "A forward attack reaches a patrol within110px")
	runner.assert_eq(world.get_enemy_status()[0]["hp"], 1, "The first hit leaves the patrol alive")
	runner.assert_eq(world.attack_at(attack_origin, 1.0), 1, "A second hit defeats a two-HP patrol")
	runner.assert_eq(adventure.xp, 20, "Defeat emits one event for the persistent20XP reward")
	runner.assert_eq(world.attack_at(attack_origin, 1.0), 0, "Defeated patrol cannot be hit repeatedly")
	runner.assert_eq(adventure.xp, 20, "Repeated attacks cannot farm experience")
	world.set_controls_enabled(false)
	var paused_patrols: Array[Dictionary] = world.get_enemy_status()
	await _frames(runner, 10)
	runner.assert_eq(world.get_enemy_status(), paused_patrols, "Dialogues freeze enemy motion and timers")
	runner.assert_eq(world.attack_at(Vector2(paused_patrols[1]["position"]) + Vector2(-50, -35), 1), 0, "Dialogues disable combat")
	world.set_controls_enabled(true)
	world.player.position = world.get_enemy_status()[1]["position"]
	world.player.set_health(100, 100)
	await _frames(runner, 3)
	runner.assert_eq(world.player.hp, 92, "Patrol contact causes eight health damage")
	runner.assert_eq(adventure.hp, 92, "Root-style damage connection keeps persistent health synchronized")
	await _frames(runner, 4)
	runner.assert_eq(world.player.hp, 92, "Contact invulnerability prevents damage every frame")
	runner.assert_false(world.travel_to("valley"), "Fast travel cannot skip an undiscovered region")
	adventure.discover("forest")
	runner.assert_true(world.travel_to("forest"), "Discovered forest portal supports fast travel")
	runner.assert_eq(world.serialize()["checkpoint_region"], "forest", "Travel sets the safe checkpoint")
	world.player.position = Vector2(1200, World.GROUND_Y)
	world.recover_at_checkpoint()
	runner.assert_float_approx(world.player.position.x, 1850.0, 0.01, "Recovery returns to the latest region shelter")
	runner.assert_eq(world.player.hp, 92, "Checkpoint recovery leaves health ownership with adventure state")
	world.player.position = Vector2(3360, World.GROUND_Y)
	await _frames(runner, 3)
	runner.assert_true(adventure.discovered_regions.has("valley"), "Entering a new region unlocks its portal")
	for region_id: String in ["harbor", "snow", "citadel"]:
		runner.assert_false(world.travel_to(region_id), "A new region needs exploration before travel: " + region_id)
		world.player.position = World.REGION_SPAWNS[region_id]
		await _frames(runner, 3)
		# Discovery runs in _process. Catch-up physics ticks can finish before
		# an idle update, and process_frame itself is emitted before _process.
		for idle_frame: int in range(8):
			if adventure.discovered_regions.has(region_id): break
			await runner.get_tree().process_frame
		runner.assert_true(adventure.discovered_regions.has(region_id), "Walking into a new region unlocks it: " + region_id)
		runner.assert_true(world.travel_to(region_id), "Discovered expansion region permits return travel: " + region_id)
	runner.assert_false(World.is_valid_save({"checkpoint_region": "missing"}), "Unknown checkpoint is rejected")
	runner.assert_false(World.is_valid_save({"checkpoint_region": null}), "Invalid checkpoint type is rejected")
	var state_save: Dictionary = adventure.serialize()
	var world_save: Dictionary = world.serialize()
	world.free()
	var restored_adventure: Adventure = Adventure.new()
	runner.assert_true(restored_adventure.restore(state_save), "Adventure save restores after combat")
	world = World.new()
	world.setup(Templates.get_template("robot"), journal)
	world.configure_adventure(restored_adventure)
	world.restore(world_save)
	runner.add_child(world)
	runner.assert_eq(world.get_enemy_status()[0]["hp"], 0, "A saved defeated patrol stays defeated in a rebuilt world")
	runner.assert_true(world.travel_to("valley"), "Saved discovered regions retain fast travel")
	world.free()


static func _test_walkable_collection_route(runner: Node) -> void:
	var journal: QuestJournal = Journal.new()
	var world: QuadrilateralWorld = World.new()
	world.setup(Templates.get_template("cat"), journal)
	runner.add_child(world)
	var route: Array[Dictionary] = world.collectibles.duplicate(true)
	route.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a["position"]).x < Vector2(b["position"]).x)
	# A valid journal paired with a stale world list must not hide needed items.
	var stale_ids: Array[String] = []
	for item: Dictionary in route:
		stale_ids.append(str(item["id"]))
	world.restore({"collected": stale_ids})
	runner.assert_eq(world.serialize()["collected"].size(), 0, "Stale world state cannot strand an empty journal")
	await _frames(runner, 8)
	for index: int in range(route.size()):
		var item: Dictionary = route[index]
		if not world.serialize()["collected"].has(str(item["id"])):
			await _reach_pickup(runner, world, item)
		runner.assert_true(world.serialize()["collected"].has(str(item["id"])), "Walking and jumping reach " + str(item["id"]))
		if index == 8 or index == 27:
			# Recreate the entire scene and journal mid-route, just like resuming
			# a JSON save. The route continues using physical input afterward.
			var saved: Dictionary = JSON.parse_string(JSON.stringify({"world": world.serialize(), "journal": journal.serialize()}))
			var prior_count: int = world.serialize()["collected"].size()
			world.free()
			journal = Journal.new()
			runner.assert_true(journal.restore(saved["journal"]), "Mid-route journal restores from JSON")
			world = World.new()
			world.setup(Templates.get_template("cat"), journal)
			world.restore(saved["world"])
			runner.add_child(world)
			runner.assert_eq(world.serialize()["collected"].size(), prior_count, "Mid-route unique pickups survive scene recreation")
			await _frames(runner, 8)
	for quest: Dictionary in Catalog.all_quests():
		runner.assert_true(journal.accept_quest(str(quest["id"])), "An unaccepted quest can use previously collected objectives")
		runner.assert_true(journal.can_turn_in(str(quest["id"])), "Physical exploration completes objective " + str(quest["id"]))
		journal.answer_quest(str(quest["id"]), int(quest["answer"]))
	runner.assert_eq(journal.completed_count(), 16, "Physical world route supports all sixteen quest turn-ins")
	world.restore({"collected": []})
	runner.assert_eq(world.serialize()["collected"].size(), 41, "Completed journal prevents respawn even if saved pickup list is missing")
	for item: Dictionary in route:
		runner.assert_false(world.collect_pickup(str(item["id"])), "Completed objectives cannot be farmed after restore")
	world.free()


static func _reach_pickup(runner: Node, world: QuadrilateralWorld, item: Dictionary) -> void:
	var target: Vector2 = item["position"]
	if target.y < 500.0:
		# Reach the 108px lower step, then jump onto the 104px higher one.
		# This navigates actual collision geometry instead of teleporting.
		var step_x: float = 0.0
		for platform: Rect2 in world.platforms:
			if platform.position.y > 550.0 and platform.get_center().x < target.x:
				step_x = maxf(step_x, platform.get_center().x)
		await _walk_to(runner, world, step_x)
		await _frames(runner, 40)
		if world.player.position.y > 590.0:
			await _jump_toward(runner, world, step_x)
		await _jump_toward(runner, world, target.x)
	else:
		await _walk_to(runner, world, target.x)
		await _frames(runner, 24)
		if target.y < 600.0:
			await _jump_toward(runner, world, target.x)
		elif not world.serialize()["collected"].has(str(item["id"])):
			# Step off the edge if the preceding pickup left us on a platform.
			await _walk_to(runner, world, target.x + 85.0)
			await _frames(runner, 35)
			await _walk_to(runner, world, target.x)
			await _frames(runner, 45)
	await _frames(runner, 10)


static func _walk_to(runner: Node, world: QuadrilateralWorld, target_x: float) -> void:
	for frame: int in range(1000):
		var offset: float = target_x - world.player.position.x
		if absf(offset) < 7.0:
			break
		_press(KEY_D, offset > 0.0)
		_press(KEY_A, offset < 0.0)
		await runner.get_tree().physics_frame
	_press(KEY_D, false)
	_press(KEY_A, false)
	await _frames(runner, 10)


static func _jump_toward(runner: Node, world: QuadrilateralWorld, target_x: float) -> void:
	_press(KEY_SPACE, false)
	await _frames(runner, 2)
	_press(KEY_SPACE, true)
	for frame: int in range(60):
		var offset: float = target_x - world.player.position.x
		_press(KEY_D, offset > 7.0)
		_press(KEY_A, offset < -7.0)
		await runner.get_tree().physics_frame
	_press(KEY_SPACE, false)
	_press(KEY_D, false)
	_press(KEY_A, false)
	await _frames(runner, 10)


static func _frames(runner: Node, amount: int) -> void:
	for frame: int in range(amount):
		await runner.get_tree().physics_frame


static func _press(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
