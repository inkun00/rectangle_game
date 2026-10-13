class_name QuestJournal
extends RefCounted

## The world owns physical pickup instances. This model owns objective counts,
## educational answers and one-time rewards; dialogue cannot skip exploration.

signal changed

const Catalog = preload("res://scripts/world/quest_catalog.gd")
const SAVE_VERSION: int = 1

var accepted: Dictionary = {}
var completed: Dictionary = {}
var inventory: Dictionary = {}
var coins: int = 0


func accept_quest(quest_id: String) -> bool:
	if Catalog.get_quest(quest_id).is_empty() or accepted.has(quest_id):
		return false
	accepted[quest_id] = true
	changed.emit()
	return true


func collect_item(item_id: String) -> bool:
	var limit: int = Catalog.target_limit(item_id)
	var amount: int = int(inventory.get(item_id, 0))
	if limit == 0 or amount >= limit:
		return false
	# Do not grant extra objective items after their associated task is finished.
	var unfinished: bool = false
	for quest: Dictionary in Catalog.all_quests():
		if String(quest["target"]) == item_id and not completed.has(String(quest["id"])):
			unfinished = true
	if not unfinished:
		return false
	inventory[item_id] = amount + 1
	changed.emit()
	return true


func can_turn_in(quest_id: String) -> bool:
	var quest: Dictionary = Catalog.get_quest(quest_id)
	if quest.is_empty() or not accepted.has(quest_id) or completed.has(quest_id):
		return false
	return int(inventory.get(String(quest["target"]), 0)) >= int(quest["target_count"])


func answer_quest(quest_id: String, answer_index: int) -> Dictionary:
	var quest: Dictionary = Catalog.get_quest(quest_id)
	if quest.is_empty():
		return _result(false, "알 수 없는 부탁이에요.")
	if completed.has(quest_id):
		return _result(false, "이미 도와준 부탁이에요. 다른 주민을 만나 보세요.")
	if not accepted.has(quest_id):
		return _result(false, "먼저 주민의 부탁을 받아 주세요.")
	if not can_turn_in(quest_id):
		return _result(false, "먼저 탐험 목표를 마쳐 주세요. " + progress_text(quest_id))
	var options: Array = quest["options"]
	if answer_index < 0 or answer_index >= options.size():
		return _result(false, "보기 중 하나를 골라 주세요.")
	if answer_index != int(quest["answer"]):
		return _result(false, "다시 생각해 볼까요? " + String(quest["explanation"]))
	var target: String = String(quest["target"])
	inventory[target] = int(inventory.get(target, 0)) - int(quest["target_count"])
	completed[quest_id] = true
	var reward: int = int(quest["reward"])
	coins += reward
	changed.emit()
	return {"correct": true, "message": "맞았어요! " + String(quest["explanation"]), "completed": true, "reward": reward}


func quest_state(quest_id: String) -> String:
	if Catalog.get_quest(quest_id).is_empty():
		return "unknown"
	if completed.has(quest_id):
		return "completed"
	if can_turn_in(quest_id):
		return "ready"
	if accepted.has(quest_id):
		return "active"
	return "available"


func progress_text(quest_id: String) -> String:
	var quest: Dictionary = Catalog.get_quest(quest_id)
	if quest.is_empty():
		return ""
	if completed.has(quest_id):
		return "완료 · " + String(quest["title"])
	var count: int = mini(int(inventory.get(String(quest["target"]), 0)), int(quest["target_count"]))
	return "%s (%d/%d)" % [String(quest["objective"]), count, int(quest["target_count"])]


func completed_count() -> int:
	return completed.size()


func serialize() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"accepted": accepted.keys(),
		"completed": completed.keys(),
		"inventory": inventory.duplicate(true),
		"coins": coins
	}


func restore(data: Dictionary) -> bool:
	# Validate into temporary values so a bad save never partially clears progress.
	if not _is_whole_number(data.get("version", 0)) or int(data.get("version", 0)) != SAVE_VERSION:
		return false
	if not data.get("accepted") is Array or not data.get("completed") is Array:
		return false
	if not data.get("inventory") is Dictionary or not _is_whole_number(data.get("coins")):
		return false
	var restored_coins: int = int(data["coins"])
	if restored_coins < 0:
		return false
	var restored_accepted: Dictionary = {}
	var restored_completed: Dictionary = {}
	var restored_inventory: Dictionary = {}
	for value: Variant in data["accepted"]:
		if not value is String or Catalog.get_quest(String(value)).is_empty() or restored_accepted.has(value):
			return false
		restored_accepted[value] = true
	for value: Variant in data["completed"]:
		if not value is String or not restored_accepted.has(value) or restored_completed.has(value):
			return false
		restored_completed[value] = true
	for key: Variant in data["inventory"]:
		if not key is String or Catalog.target_limit(String(key)) == 0:
			return false
		var amount: Variant = data["inventory"][key]
		if not _is_whole_number(amount) or int(amount) < 0 or int(amount) > Catalog.target_limit(String(key)):
			return false
		restored_inventory[key] = int(amount)
	accepted = restored_accepted
	completed = restored_completed
	inventory = restored_inventory
	coins = restored_coins
	changed.emit()
	return true


static func _is_whole_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) < 2147483647.0
	return false


static func _result(correct: bool, message: String) -> Dictionary:
	return {"correct": correct, "message": message, "completed": false, "reward": 0}
