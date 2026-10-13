class_name TestAdventureState
extends RefCounted

const Adventure = preload("res://scripts/world/adventure_state.gd")
const Journal = preload("res://scripts/world/quest_journal.gd")
const Catalog = preload("res://scripts/world/quest_catalog.gd")


static func run(t) -> void:
	_test_progression(t)
	_test_health(t)
	_test_shop_and_inn(t)
	_test_one_time_rewards(t)
	_test_save_roundtrip(t)
	_test_invalid_saves_are_atomic(t)
	_test_expanded_regions_and_legacy_save(t)


static func _test_progression(t) -> void:
	var state = Adventure.new()
	var events: Array[int] = [0]
	state.changed.connect(func() -> void: events[0] += 1)
	t.assert_eq(state.level, 1, "A new adventurer starts at level one")
	t.assert_eq(state.hp, 100, "A new adventurer has full health")
	t.assert_eq(state.potions, 3, "New adventurers receive three potions")
	t.assert_eq(state.xp_for_next_level(), 100, "First level costs one hundred XP")
	t.assert_false(state.gain_xp(-10), "Negative XP cannot remove progression")
	t.assert_false(state.gain_xp(0), "Zero XP does not emit a change")
	t.assert_true(state.gain_xp(99), "Positive XP advances progress")
	t.assert_eq(state.level, 1, "XP below threshold does not level up")
	t.assert_eq(state.xp_in_level(), 99, "XP bar shows progress within the level")
	state.damage(50)
	t.assert_true(state.gain_xp(1), "Crossing threshold levels up")
	t.assert_eq(state.level, 2, "First threshold unlocks level two")
	t.assert_eq(state.max_hp, 110, "Level increases maximum health")
	t.assert_eq(state.hp, 110, "Level-up fully heals")
	t.assert_eq(state.xp, 100, "XP remains cumulative")
	t.assert_eq(state.xp_in_level(), 0, "New level resets only the displayed progress")
	t.assert_eq(state.xp_for_next_level(), 200, "Second level costs two hundred more XP")
	state.gain_xp(505)
	t.assert_eq(state.level, 4, "One large reward can cross multiple level thresholds")
	t.assert_eq(state.xp_in_level(), 5, "Large reward preserves excess XP")
	t.assert_eq(state.max_hp, 130, "Multiple levels derive correct maximum health")
	t.assert_eq(events[0], 4, "Only successful mutations emit one signal each")
	state.gain_xp(Adventure.MAX_XP)
	t.assert_eq(state.xp, Adventure.MAX_XP, "Extreme rewards are bounded")
	t.assert_false(state.gain_xp(20), "Capped XP does not emit a false change")


static func _test_health(t) -> void:
	var state = Adventure.new()
	t.assert_false(state.use_potion(), "Potions are preserved at full health")
	t.assert_eq(state.potions, 3, "Full-health potion attempt consumes nothing")
	t.assert_false(state.damage(0), "Zero damage does nothing")
	t.assert_false(state.damage(-5), "Negative damage does not heal")
	t.assert_false(state.heal(-5), "Negative healing does not damage")
	t.assert_true(state.damage(55), "Damage reduces health")
	t.assert_eq(state.hp, 45, "Damage is applied exactly")
	t.assert_true(state.use_potion(), "Potion can heal an injured adventurer")
	t.assert_eq(state.hp, 85, "Potion heals forty health")
	t.assert_eq(state.potions, 2, "Healing consumes one potion")
	state.use_potion()
	t.assert_eq(state.hp, 100, "Potion health is capped at maximum")
	state.damage(999)
	t.assert_eq(state.hp, 0, "Lethal damage clamps at zero")
	t.assert_false(state.damage(5), "Already-depleted health is stable")
	t.assert_true(state.heal(25), "Recovery can restore depleted health")
	t.assert_eq(state.hp, 25, "Recovery applies its exact amount")
	state.use_potion()
	t.assert_false(state.use_potion(), "Empty potion supply cannot heal")
	t.assert_eq(state.potions, 0, "Potion count cannot become negative")
	state.heal(999)
	t.assert_eq(state.hp, 100, "Large heal is capped")
	t.assert_false(state.heal(1), "Full-health heal emits no mutation")


static func _test_shop_and_inn(t) -> void:
	var state = Adventure.new()
	var journal = Journal.new()
	var snapshots: Array[Dictionary] = []
	var observe_transaction: Callable = func() -> void:
		snapshots.append({"coins": journal.coins, "potions": state.potions, "hp": state.hp})
	journal.changed.connect(observe_transaction)
	t.assert_false(state.purchase_potion(journal), "Shop rejects purchases without funds")
	t.assert_false(state.purchase_potion(null), "Shop rejects a missing coin authority")
	journal.coins = 15
	t.assert_true(state.purchase_potion(journal), "Ten coins buy one potion")
	t.assert_eq(journal.coins, 5, "Shop debits the journal coin balance")
	t.assert_eq(state.potions, 4, "Shop adds exactly one potion")
	t.assert_eq(snapshots[0], {"coins": 5, "potions": 4, "hp": 100}, "Autosave observes both purchase changes together")
	t.assert_false(state.rest(journal), "Full-health inn visit costs nothing")
	t.assert_eq(journal.coins, 5, "Unneeded inn visit preserves coins")
	state.damage(65)
	t.assert_true(state.rest(journal), "Five coins restore all health")
	t.assert_eq(journal.coins, 0, "Inn debits the remaining five coins")
	t.assert_eq(state.hp, 100, "Inn fully heals")
	t.assert_eq(snapshots[1], {"coins": 0, "potions": 4, "hp": 100}, "Autosave observes the complete inn transaction")
	state.damage(10)
	t.assert_false(state.rest(journal), "Paid rest requires enough coins")
	t.assert_eq(state.hp, 90, "Unaffordable rest does not heal")
	state.damage(100)
	t.assert_true(state.rest(journal), "A defeated penniless adventurer gets free rescue")
	t.assert_eq(state.hp, 100, "Free rescue restores health")
	t.assert_eq(journal.coins, 0, "Rescue cannot create debt")
	t.assert_eq(snapshots.size(), 2, "Free rescue does not report an unchanged coin balance")
	state.potions = Adventure.MAX_POTIONS
	journal.coins = 10
	t.assert_false(state.purchase_potion(journal), "Shop cannot exceed inventory capacity")
	t.assert_eq(journal.coins, 10, "Capacity failure preserves money")
	journal.changed.disconnect(observe_transaction)


static func _test_one_time_rewards(t) -> void:
	var state = Adventure.new()
	t.assert_true(state.discovered_regions.has("market"), "Starting village is discovered")
	t.assert_false(state.discover("market"), "Discovery is idempotent")
	t.assert_false(state.discover("ocean"), "Unknown regions are rejected")
	t.assert_true(state.discover("forest"), "First forest visit is recorded")
	t.assert_eq(state.xp, 0, "Discovery does not replace learning rewards")
	t.assert_false(state.record_enemy_defeat("  "), "An encounter needs a stable ID")
	t.assert_true(state.record_enemy_defeat("forest_crystal_1"), "First enemy defeat grants XP")
	t.assert_eq(state.xp, 20, "A crystal encounter grants twenty XP")
	t.assert_false(state.record_enemy_defeat("forest_crystal_1"), "Repeated defeat cannot farm XP")
	t.assert_eq(state.xp, 20, "Repeated defeat preserves XP")
	t.assert_false(state.claim_quest("missing"), "Unknown quest has no XP reward")
	var total_rewards: int = 0
	for quest: Dictionary in Catalog.all_quests():
		var quest_id: String = quest["id"]
		t.assert_true(state.claim_quest(quest_id), "Each learning quest can award XP once")
		t.assert_false(state.claim_quest(quest_id), "Quest XP cannot be claimed twice")
		total_rewards += int(quest["reward"]) * 2
	t.assert_eq(state.claimed_quests.size(), Catalog.all_quests().size(), "Every catalog learning quest retains progression")
	t.assert_eq(state.xp, total_rewards + 20, "Quest rewards use the catalog values")
	t.assert_true(state.level > 1, "Finishing the curriculum advances the character")
	t.assert_true(state.xp_in_level() >= 0 and state.xp_in_level() < state.xp_for_next_level(), "Expanded rewards settle at the correct level threshold")


static func _test_save_roundtrip(t) -> void:
	var state = Adventure.new()
	state.discover("forest")
	state.discover("valley")
	state.record_enemy_defeat("forest_crystal_1")
	state.claim_quest("square_puppy")
	state.damage(70)
	state.use_potion()
	var snapshot: Dictionary = state.serialize()
	var restored = Adventure.new()
	var json_data: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	t.assert_true(restored.restore(json_data), "JSON numeric floats restore successfully")
	t.assert_eq(restored.serialize(), snapshot, "All adventure fields survive a JSON round trip")
	t.assert_false(restored.record_enemy_defeat("forest_crystal_1"), "Loaded encounters cannot pay twice")
	t.assert_false(restored.claim_quest("square_puppy"), "Loaded quest rewards cannot pay twice")
	json_data["defeated_enemies"]["new_enemy"] = true
	t.assert_false(restored.defeated_enemies.has("new_enemy"), "Restored state does not alias its input")
	snapshot["discovered_regions"].clear()
	t.assert_true(state.discovered_regions.has("market"), "Serialized state does not alias live dictionaries")
	t.assert_false(restored.serialize().has("coins"), "Coins remain exclusively owned by the quest journal")


static func _test_invalid_saves_are_atomic(t) -> void:
	var state = Adventure.new()
	state.gain_xp(150)
	state.discover("forest")
	var valid: Dictionary = state.serialize()
	var events: Array[int] = [0]
	state.changed.connect(func() -> void: events[0] += 1)
	for field: String in ["version", "xp", "level", "max_hp", "hp", "potions"]:
		for malformed: Variant in [null, true, "1", [], {}, 0.5, -1, INF, NAN]:
			var candidate: Dictionary = valid.duplicate(true)
			candidate[field] = malformed
			t.assert_false(state.restore(candidate), "Invalid numeric field %s is rejected" % field)
			t.assert_eq(state.serialize(), valid, "Rejected numeric field preserves live state")
	for field: String in ["defeated_enemies", "discovered_regions", "claimed_quests"]:
		for malformed: Variant in [null, [], "bad", 3, {"": true}, {"market": false}, {"market": 1}]:
			var candidate: Dictionary = valid.duplicate(true)
			candidate[field] = malformed
			t.assert_false(state.restore(candidate), "Invalid flags in %s are rejected" % field)
			t.assert_eq(state.serialize(), valid, "Rejected flags preserve live state")
	var cases: Array[Dictionary] = [
		{"version": 2}, {"hp": 111}, {"level": 3}, {"max_hp": 100},
		{"xp": Adventure.MAX_XP + 1}, {"potions": Adventure.MAX_POTIONS + 1},
		{"discovered_regions": {"forest": true}},
		{"discovered_regions": {"market": true, "ocean": true}},
		{"claimed_quests": {"unknown": true}},
		{"claimed_quests": {"square_festival": true, "square_puppy": true, "rhombus_chocolates": true}}
	]
	for overrides: Dictionary in cases:
		var candidate: Dictionary = valid.duplicate(true)
		candidate.merge(overrides, true)
		t.assert_false(state.restore(candidate), "Inconsistent progression is rejected")
		t.assert_eq(state.serialize(), valid, "Inconsistent progression cannot partially load")
	t.assert_false(state.restore({}), "Missing fields are rejected")
	t.assert_eq(events[0], 0, "Rejected saves do not trigger autosaves or UI changes")


static func _test_expanded_regions_and_legacy_save(t) -> void:
	var state = Adventure.new()
	for region: String in ["forest", "valley", "harbor", "snow", "citadel"]:
		t.assert_true(state.discover(region), "Every expanded region can be discovered without progression gates")
		t.assert_false(state.discover(region), "Discovery remains idempotent in all regions")
	t.assert_eq(state.discovered_regions.size(), Adventure.REGIONS.size(), "The complete region registry can be discovered")
	state.claim_quest("starlight_core")
	var restored = Adventure.new()
	t.assert_true(restored.restore(JSON.parse_string(JSON.stringify(state.serialize()))), "Six discovered regions and expanded quest XP restore")
	t.assert_true(restored.discovered_regions.has("citadel"), "Citadel discovery persists")
	t.assert_false(restored.claim_quest("starlight_core"), "New final quest cannot pay XP twice after loading")
	var legacy: Dictionary = {
		"version": 1, "hp": 84, "max_hp": 120, "xp": 400, "level": 3, "potions": 1,
		"defeated_enemies": {}, "discovered_regions": {"market": true, "forest": true, "valley": true},
		"claimed_quests": {"rhombus_chocolates": true, "square_puppy": true, "trapezoid_roofs": true,
			"parallelogram_bridge": true, "rectangle_library": true, "parallel_rails": true,
			"right_angle_sign": true, "square_festival": true}
	}
	t.assert_true(restored.restore(legacy), "Original three-region v1 progress remains valid")
	t.assert_eq(restored.hp, 84, "Old health is not reset by expansion")
	t.assert_eq(restored.xp, 400, "Old experience is not retroactively changed")
	t.assert_false(restored.discovered_regions.has("harbor"), "New regions remain unexplored in old saves")
	t.assert_true(restored.discover("harbor"), "An old save can continue into the expansion")
	t.assert_true(restored.claim_quest("harbor_sails"), "New quest XP can be claimed on an old save")
	var valid: Dictionary = restored.serialize()
	var bad: Dictionary = valid.duplicate(true)
	bad["claimed_quests"]["snow_unknown"] = true
	t.assert_false(restored.restore(bad), "Unknown expansion quest names remain invalid")
	t.assert_eq(restored.serialize(), valid, "Unknown expansion quest rejection is atomic")
