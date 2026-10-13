class_name AdventureState
extends RefCounted

## Persistent RPG progression. QuestJournal is the sole owner of the coin balance.
signal changed

const Catalog = preload("res://scripts/world/quest_catalog.gd")
const Journal = preload("res://scripts/world/quest_journal.gd")
const SAVE_VERSION: int = 1
const ENEMY_XP: int = 20
const POTION_HEAL: int = 40
const POTION_COST: int = 10
const REST_COST: int = 5
const MAX_XP: int = 1000000
const MAX_POTIONS: int = 9999
const REGIONS: Array[String] = ["market", "forest", "valley", "harbor", "snow", "citadel"]

var hp: int = 100
var max_hp: int = 100
var xp: int = 0
var level: int = 1
var potions: int = 3
var defeated_enemies: Dictionary = {}
var discovered_regions: Dictionary = {"market": true}
var claimed_quests: Dictionary = {}


func gain_xp(amount: int) -> bool:
	if amount <= 0 or xp >= MAX_XP:
		return false
	_apply_xp(amount)
	changed.emit()
	return true


## The caller supplies a stable world encounter ID, so reloading cannot farm XP.
func record_enemy_defeat(enemy_id: String) -> bool:
	if enemy_id.strip_edges().is_empty() or enemy_id.length() > 128 or defeated_enemies.has(enemy_id):
		return false
	defeated_enemies[enemy_id] = true
	_apply_xp(ENEMY_XP)
	changed.emit()
	return true


## Call only after QuestJournal has completed the objective and answer transaction.
func claim_quest(quest_id: String) -> bool:
	var quest: Dictionary = Catalog.get_quest(quest_id)
	if quest.is_empty() or claimed_quests.has(quest_id):
		return false
	claimed_quests[quest_id] = true
	_apply_xp(int(quest["reward"]) * 2)
	changed.emit()
	return true


func damage(amount: int) -> bool:
	if amount <= 0 or hp == 0:
		return false
	hp = maxi(0, hp - amount)
	changed.emit()
	return true


func heal(amount: int) -> bool:
	if amount <= 0 or hp >= max_hp:
		return false
	hp += mini(amount, max_hp - hp)
	changed.emit()
	return true


func use_potion() -> bool:
	if potions <= 0 or hp >= max_hp:
		return false
	potions -= 1
	hp += mini(POTION_HEAL, max_hp - hp)
	changed.emit()
	return true


func purchase_potion(journal: Journal) -> bool:
	if journal == null or journal.coins < POTION_COST or potions >= MAX_POTIONS:
		return false
	journal.coins -= POTION_COST
	potions += 1
	# Both models are committed before either observer can autosave.
	journal.changed.emit()
	changed.emit()
	return true


## A full heal costs five coins; rescue at zero HP is free and cannot strand a child.
func rest(journal: Journal) -> bool:
	if journal == null or hp >= max_hp:
		return false
	var cost: int = 0 if hp == 0 else REST_COST
	if journal.coins < cost:
		return false
	journal.coins -= cost
	hp = max_hp
	if cost > 0:
		journal.changed.emit()
	changed.emit()
	return true


func discover(region: String) -> bool:
	if not REGIONS.has(region) or discovered_regions.has(region):
		return false
	discovered_regions[region] = true
	changed.emit()
	return true


func xp_in_level() -> int:
	return xp - _level_threshold(level)


func xp_for_next_level() -> int:
	return level * 100


func serialize() -> Dictionary:
	return {
		"version": SAVE_VERSION, "hp": hp, "max_hp": max_hp,
		"xp": xp, "level": level, "potions": potions,
		"defeated_enemies": defeated_enemies.duplicate(true),
		"discovered_regions": discovered_regions.duplicate(true),
		"claimed_quests": claimed_quests.duplicate(true)
	}


## Validate every field before committing any state. JSON uses floating-point numbers.
func restore(data: Dictionary) -> bool:
	if not _whole_number(data.get("version"), SAVE_VERSION, SAVE_VERSION):
		return false
	if not _whole_number(data.get("xp"), 0, MAX_XP):
		return false
	var next_xp: int = int(data["xp"])
	var next_level: int = _level_for_xp(next_xp)
	var next_max_hp: int = 100 + 10 * (next_level - 1)
	if not _whole_number(data.get("level"), next_level, next_level):
		return false
	if not _whole_number(data.get("max_hp"), next_max_hp, next_max_hp):
		return false
	if not _whole_number(data.get("hp"), 0, next_max_hp):
		return false
	if not _whole_number(data.get("potions"), 0, MAX_POTIONS):
		return false
	if not _valid_flags(data.get("defeated_enemies"), []):
		return false
	if not _valid_flags(data.get("discovered_regions"), REGIONS):
		return false
	var next_regions: Dictionary = data["discovered_regions"]
	if not next_regions.has("market"):
		return false
	var quest_ids: Array[String] = []
	for quest: Dictionary in Catalog.all_quests():
		quest_ids.append(String(quest["id"]))
	if not _valid_flags(data.get("claimed_quests"), quest_ids):
		return false
	# Claimed one-time rewards must be reflected in the cumulative experience.
	var earned_xp: int = data["defeated_enemies"].size() * ENEMY_XP
	for quest_id: String in data["claimed_quests"]:
		earned_xp += int(Catalog.get_quest(quest_id)["reward"]) * 2
	if next_xp < mini(earned_xp, MAX_XP):
		return false
	hp = int(data["hp"])
	max_hp = next_max_hp
	xp = next_xp
	level = next_level
	potions = int(data["potions"])
	defeated_enemies = data["defeated_enemies"].duplicate(true)
	discovered_regions = next_regions.duplicate(true)
	claimed_quests = data["claimed_quests"].duplicate(true)
	changed.emit()
	return true


func _apply_xp(amount: int) -> void:
	xp += mini(amount, MAX_XP - xp)
	var new_level: int = _level_for_xp(xp)
	if new_level > level:
		level = new_level
		max_hp = 100 + 10 * (level - 1)
		hp = max_hp


static func _level_threshold(for_level: int) -> int:
	return 50 * for_level * (for_level - 1)


static func _level_for_xp(total_xp: int) -> int:
	var result: int = 1
	while total_xp >= _level_threshold(result + 1):
		result += 1
	return result


static func _whole_number(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = float(value)
	return is_finite(number) and number == floorf(number) and number >= minimum and number <= maximum


static func _valid_flags(value: Variant, allowed: Array[String]) -> bool:
	if not value is Dictionary or value.size() > 50000:
		return false
	for key: Variant in value:
		if not key is String or key.strip_edges().is_empty() or key.length() > 128:
			return false
		if not allowed.is_empty() and not allowed.has(key):
			return false
		if not value[key] is bool or not value[key]:
			return false
	return true
