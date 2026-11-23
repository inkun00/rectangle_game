extends RefCounted

const Bank = preload("res://scripts/learning/learning_question_bank.gd")

# Indices only. The gate builds the actual question when its turn starts.
static var _indices_by_topic: Dictionary = {}

static func _modes_for(topic: String) -> Dictionary:
	if not _indices_by_topic.has(topic):
		var by_mode: Dictionary = {}
		for index: int in range(Bank.PER_TYPE):
			var mode: String = str(Bank.question(topic, index).mode)
			if not by_mode.has(mode): by_mode[mode] = []
			by_mode[mode].append(index)
		_indices_by_topic[topic] = by_mode
	return _indices_by_topic[topic]

static func pick(rng: RandomNumberGenerator) -> Array[int]:
	var variants: Array[int] = []
	var remaining_topics: Array[int] = []
	var used_modes: Array[String] = []
	variants.resize(Bank.TYPES.size())
	for topic_index: int in range(Bank.TYPES.size()):
		remaining_topics.append(topic_index)
	# Assign formats in random topic order, then present topics in curriculum order.
	var formats: Array = [["line", "draw"], ["choice"], ["short"], ["order", "match"], []]
	for allowed: Array in formats:
		var topic_index: int = remaining_topics.pop_at(rng.randi_range(0, remaining_topics.size() - 1))
		var by_mode: Dictionary = _modes_for(Bank.TYPES[topic_index])
		var candidates: Array[String] = []
		for mode: String in by_mode:
			if not used_modes.has(mode) and (allowed.is_empty() or allowed.has(mode)):
				candidates.append(mode)
		var mode: String = candidates[rng.randi_range(0, candidates.size() - 1)]
		var indices: Array = by_mode[mode]
		variants[topic_index] = indices[rng.randi_range(0, indices.size() - 1)]
		used_modes.append(mode)
	return variants
