class_name TestQuestJournal
extends RefCounted

const Catalog = preload("res://scripts/world/quest_catalog.gd")
const Journal = preload("res://scripts/world/quest_journal.gd")


static func run(t) -> void:
	_test_catalog(t)
	_test_objective_gate_and_feedback(t)
	_test_every_adventure(t)
	_test_preaccept_collection_and_legacy_save(t)
	_test_expansion_contract(t)
	_test_save_roundtrip(t)
	_test_invalid_save_is_atomic(t)


static func _test_catalog(t) -> void:
	var quests: Array[Dictionary] = Catalog.all_quests()
	t.assert_eq(quests.size(), 16, "The expanded adventure has sixteen learning quests")
	var ids: Dictionary = {}
	var npcs: Dictionary = {}
	for quest: Dictionary in quests:
		t.assert_false(ids.has(quest["id"]), "Quest IDs are unique")
		t.assert_false(npcs.has(quest["npc_id"]), "Each quest has a distinct NPC")
		ids[quest["id"]] = true
		npcs[quest["npc_id"]] = true
		t.assert_true(int(quest["target_count"]) > 0, "Every quest requires exploration")
		t.assert_true(int(quest["answer"]) >= 0 and int(quest["answer"]) < quest["options"].size(), "Correct answer points to a real option")
		t.assert_false(String(quest["explanation"]).is_empty(), "Every answer teaches with feedback")
		t.assert_true(int(quest["reward"]) > 0, "Each quest rewards completion")
		t.assert_false(String(quest["item_name"]).is_empty(), "Each objective has a readable item name")
		t.assert_true(int(quest["item_icon"]) >= 0 and int(quest["item_icon"]) < 8, "Item icon stays within its sheet")
		t.assert_true(int(quest["npc_icon"]) >= 0 and int(quest["npc_icon"]) < 8, "NPC icon stays within its sheet")
		t.assert_true(["items_atlas", "expansion_items"].has(quest["item_sheet"]), "Item sheet is explicit")
		t.assert_true(["npc_atlas", "expansion_npcs"].has(quest["npc_sheet"]), "NPC sheet is explicit")
	quests[0]["title"] = "changed"
	t.assert_false(String(Catalog.all_quests()[0]["title"]) == "changed", "Catalog callers cannot mutate shared content")
	t.assert_eq(Catalog.get_quest("square_festival")["answer"], 2, "Square includes all four broader categories")
	t.assert_eq(Catalog.get_quest("trapezoid_roofs")["answer"], 2, "Trapezoid definition is inclusive")


static func _test_objective_gate_and_feedback(t) -> void:
	var journal = Journal.new()
	var signals: Array[int] = [0]
	journal.changed.connect(func() -> void: signals[0] += 1)
	t.assert_eq(journal.quest_state("missing"), "unknown", "Unknown quest state is explicit")
	t.assert_false(journal.accept_quest("missing"), "Unknown quests cannot be accepted")
	t.assert_false(journal.collect_item("missing"), "Unknown items cannot enter inventory")
	t.assert_eq(journal.quest_state("rhombus_chocolates"), "available", "A new quest is available")
	t.assert_false(journal.answer_quest("rhombus_chocolates", 1)["completed"], "Unaccepted quest cannot finish")
	t.assert_true(journal.accept_quest("rhombus_chocolates"), "A valid quest can be accepted")
	t.assert_false(journal.accept_quest("rhombus_chocolates"), "Acceptance is idempotent")
	t.assert_eq(journal.quest_state("rhombus_chocolates"), "active", "Accepted quest is active")
	t.assert_false(journal.answer_quest("rhombus_chocolates", 1)["completed"], "Correct answer alone does not skip collection")
	for index: int in range(3):
		t.assert_true(journal.collect_item("rhombus_chocolate"), "A chocolate pickup advances the objective")
	t.assert_false(journal.can_turn_in("rhombus_chocolates"), "Three chocolates are not enough")
	t.assert_true(journal.progress_text("rhombus_chocolates").contains("3/4"), "Progress reports actual inventory")
	t.assert_true(journal.collect_item("rhombus_chocolate"), "Fourth chocolate completes the collection")
	t.assert_false(journal.collect_item("rhombus_chocolate"), "Objective inventory is bounded")
	t.assert_eq(journal.quest_state("rhombus_chocolates"), "ready", "Collected objective unlocks the question")
	t.assert_false(journal.answer_quest("rhombus_chocolates", -1)["completed"], "Invalid option cannot complete a quest")
	var wrong: Dictionary = journal.answer_quest("rhombus_chocolates", 0)
	t.assert_false(wrong["correct"], "A misconception receives corrective feedback")
	t.assert_true(String(wrong["message"]).contains("네 변"), "Wrong answers explain the relevant property")
	t.assert_eq(journal.inventory["rhombus_chocolate"], 4, "A wrong answer does not consume collected items")
	t.assert_eq(journal.coins, 0, "A wrong answer does not grant a reward")
	var result: Dictionary = journal.answer_quest("rhombus_chocolates", 1)
	t.assert_true(result["correct"] and result["completed"], "Correct answer plus collection completes the quest")
	t.assert_eq(journal.inventory["rhombus_chocolate"], 0, "Delivered items are consumed once")
	t.assert_eq(journal.coins, 20, "Completion grants the configured reward")
	t.assert_eq(journal.completed_count(), 1, "Completion count advances once")
	t.assert_eq(journal.quest_state("rhombus_chocolates"), "completed", "Completion state is stable")
	t.assert_false(journal.answer_quest("rhombus_chocolates", 1)["completed"], "Repeated answers cannot farm rewards")
	t.assert_false(journal.collect_item("rhombus_chocolate"), "Completed objective items cannot be farmed")
	t.assert_eq(journal.coins, 20, "Repeated interaction preserves reward balance")
	t.assert_eq(signals[0], 6, "Only acceptance, pickups, and completion emit changes")


static func _test_every_adventure(t) -> void:
	var journal = Journal.new()
	var expected_coins: int = 0
	for quest: Dictionary in Catalog.all_quests():
		var quest_id: String = String(quest["id"])
		t.assert_true(journal.accept_quest(quest_id), "Every adventure can be started")
		for index: int in range(int(quest["target_count"])):
			t.assert_true(journal.collect_item(String(quest["target"])), "Every configured objective is collectable")
		t.assert_true(journal.can_turn_in(quest_id), "Every adventure reaches turn-in state")
		t.assert_true(journal.answer_quest(quest_id, int(quest["answer"]))["completed"], "Every adventure can finish")
		expected_coins += int(quest["reward"])
	t.assert_eq(journal.completed_count(), Catalog.all_quests().size(), "All catalog adventures finish")
	t.assert_eq(journal.coins, expected_coins, "All rewards sum correctly")
	var restored = Journal.new()
	t.assert_true(restored.restore(JSON.parse_string(JSON.stringify(journal.serialize()))), "All expanded completions survive JSON save/load")
	t.assert_eq(restored.completed_count(), Catalog.all_quests().size(), "Expanded completion count persists")


static func _test_preaccept_collection_and_legacy_save(t) -> void:
	var journal = Journal.new()
	for quest: Dictionary in Catalog.all_quests():
		for index: int in range(int(quest["target_count"])):
			t.assert_true(journal.collect_item(String(quest["target"])), "Every item can be picked up before meeting its NPC")
		t.assert_false(journal.can_turn_in(String(quest["id"])), "Collected items still need an accepted NPC request")
		t.assert_false(journal.collect_item(String(quest["target"])), "Preaccepted collection cannot exceed the objective")
	var restored = Journal.new()
	t.assert_true(restored.restore(JSON.parse_string(JSON.stringify(journal.serialize()))), "Unaccepted discoveries survive a reload")
	t.assert_true(restored.accept_quest("starlight_core"), "The final-region quest can be accepted first")
	t.assert_true(restored.can_turn_in("starlight_core"), "Earlier exploration immediately counts after acceptance")
	t.assert_false(restored.answer_quest("starlight_core", 1)["completed"], "Having all items does not bypass learning")
	t.assert_eq(restored.inventory["square_core"], 4, "A wrong answer preserves precollected items")
	t.assert_true(restored.answer_quest("starlight_core", 0)["completed"], "The final-region quest does not require earlier quests")
	var legacy_ids: Array[String] = ["rhombus_chocolates", "square_puppy", "trapezoid_roofs", "parallelogram_bridge", "rectangle_library", "parallel_rails", "right_angle_sign", "square_festival"]
	var legacy_save: Dictionary = {"version": 1, "accepted": legacy_ids, "completed": legacy_ids, "inventory": {}, "coins": 200}
	var legacy = Journal.new()
	t.assert_true(legacy.restore(legacy_save), "A completed original eight-quest v1 save remains valid")
	t.assert_eq(legacy.completed_count(), legacy_ids.size(), "Old completions are preserved")
	t.assert_eq(legacy.quest_state("harbor_sails"), "available", "Expanded quests start available in old saves")
	t.assert_eq(legacy.coins, 200, "Expanding the catalog does not change saved money")


static func _test_expansion_contract(t) -> void:
	var expected: Array[Array] = [
		["harbor_sails", "sailor", "trapezoid_sail", 3, "harbor"],
		["harbor_crates", "keeper", "rectangle_crate", 2, "harbor"],
		["snow_lanterns", "lamplighter", "rhombus_lantern", 3, "snow"],
		["snow_tracks", "tracker", "parallel_track", 2, "snow"],
		["snow_windows", "glazier", "square_window", 3, "snow"],
		["citadel_banners", "guardian", "parallel_banner", 3, "citadel"],
		["citadel_seals", "archivist", "rectangle_seal", 2, "citadel"],
		["starlight_core", "astronomer", "square_core", 4, "citadel"]
	]
	for index: int in range(expected.size()):
		var entry: Array = expected[index]
		var quest: Dictionary = Catalog.get_quest(String(entry[0]))
		t.assert_eq([quest["npc_id"], quest["target"], quest["target_count"], quest["region"]], entry.slice(1), "Expanded NPC and collectible IDs match the world contract")
		t.assert_eq(quest["item_icon"], index, "Expansion items use the agreed atlas order")
		t.assert_eq(quest["npc_icon"], index, "Expansion NPCs use the agreed atlas order")
		t.assert_eq(quest["item_sheet"], "expansion_items", "Expansion items use the new sheet")
		t.assert_eq(quest["npc_sheet"], "expansion_npcs", "Expansion NPCs use the new sheet")
	var old_npc_order: Array[String] = ["baker", "roofer", "ranger", "guide", "carpenter", "surveyor", "librarian", "mayor"]
	var target_total: int = 0
	var region_counts: Dictionary = {}
	for quest: Dictionary in Catalog.all_quests():
		target_total += int(quest["target_count"])
		region_counts[quest["region"]] = int(region_counts.get(quest["region"], 0)) + 1
		if quest["npc_sheet"] == "npc_atlas":
			t.assert_eq(quest["npc_icon"], old_npc_order.find(quest["npc_id"]), "Original NPC portraits keep their established order")
	t.assert_eq(target_total, 41, "The six-region adventure has forty-one distinct objective pickups")
	t.assert_eq(region_counts, {"market": 2, "forest": 3, "valley": 3, "harbor": 2, "snow": 3, "citadel": 3}, "Story chapters follow the world region distribution")
	for region: String in region_counts:
		var story: Dictionary = Catalog.region_story(region)
		for key: String in ["title", "intro", "outro"]:
			t.assert_false(String(story.get(key, "")).is_empty(), "Every region has a complete story chapter")
	t.assert_true(Catalog.region_story("unknown").is_empty(), "Unknown regions do not invent story content")
	var altered: Dictionary = Catalog.region_story("harbor")
	altered["title"] = "changed"
	t.assert_false(Catalog.region_story("harbor")["title"] == "changed", "UI cannot mutate shared story content")


static func _test_save_roundtrip(t) -> void:
	var journal = Journal.new()
	t.assert_true(journal.collect_item("square_puppy"), "The model safely supports discoveries before acceptance")
	journal.accept_quest("square_puppy")
	journal.answer_quest("square_puppy", 0)
	journal.accept_quest("rhombus_chocolates")
	journal.collect_item("rhombus_chocolate")
	var saved: Dictionary = journal.serialize()
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	var restored = Journal.new()
	t.assert_true(parsed is Dictionary and restored.restore(parsed), "JSON numeric conversion is supported on restore")
	t.assert_eq(restored.quest_state("square_puppy"), "completed", "Completed quests persist")
	t.assert_eq(restored.quest_state("rhombus_chocolates"), "active", "In-progress quests persist")
	t.assert_eq(restored.inventory["rhombus_chocolate"], 1, "Objective progress persists")
	t.assert_eq(restored.coins, 30, "Rewards persist")
	saved["inventory"]["rhombus_chocolate"] = 4
	t.assert_eq(journal.inventory["rhombus_chocolate"], 1, "Serialized data does not alias live inventory")
	t.assert_false(restored.answer_quest("square_puppy", 0)["completed"], "Reloading does not allow repeat rewards")


static func _test_invalid_save_is_atomic(t) -> void:
	var journal = Journal.new()
	journal.accept_quest("rhombus_chocolates")
	journal.collect_item("rhombus_chocolate")
	var good: Dictionary = journal.serialize()
	var invalid: Array[Dictionary] = []
	var bad: Dictionary = good.duplicate(true)
	bad["inventory"]["rhombus_chocolate"] = -1
	invalid.append(bad)
	bad = good.duplicate(true)
	bad["inventory"]["rhombus_chocolate"] = 1.5
	invalid.append(bad)
	bad = good.duplicate(true)
	bad["inventory"]["rhombus_chocolate"] = 5
	invalid.append(bad)
	bad = good.duplicate(true)
	bad["accepted"] = ["not_a_quest"]
	invalid.append(bad)
	bad = good.duplicate(true)
	bad["completed"] = ["square_puppy"]
	invalid.append(bad)
	bad = good.duplicate(true)
	bad["coins"] = -5
	invalid.append(bad)
	bad = good.duplicate(true)
	bad["version"] = 999
	invalid.append(bad)
	invalid.append({})
	for invalid_save: Dictionary in invalid:
		t.assert_false(journal.restore(invalid_save), "Malformed quest saves are rejected")
		t.assert_eq(journal.serialize(), good, "Malformed restore preserves existing progress atomically")
