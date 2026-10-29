class_name ConstructionState
extends RefCounted

const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Document = preload("res://scripts/construction/construction_document.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const Facade = preload("res://scripts/construction/construction_facade.gd")
const Awards = preload("res://scripts/construction/construction_awards.gd")
const INITIAL_BALANCE: int = 30000000
const MAX_CONTRACTS: int = 1000
const GRADING_VERSION: int = 5

signal changed

var document: Document = Document.new()
var balance: int = INITIAL_BALANCE
var contract_index: int = 0
var contract_choice: int = 0
var contract_grading_version: int = GRADING_VERSION
var phase: String = "briefing"
var records: Array[Dictionary] = []
var last_result: Dictionary = {}
var last_error: String = ""

func _init() -> void:
	document.editing_enabled = false
	document.changed.connect(_document_changed)

func _document_changed() -> void:
	changed.emit()

func current_contract() -> Dictionary:
	return _offer(contract_index, contract_choice, GRADING_VERSION if phase == "briefing" else contract_grading_version)

static func _offer(index: int, choice: int, grading: int) -> Dictionary:
	var offer: Dictionary = Catalog.contract(choice if grading >= 5 else index, grading)
	offer.index = index
	offer.id = "commission_%d" % index
	return offer

static func record_contract(record: Dictionary) -> Dictionary:
	return _offer(int(record.index), int(record.get("contract_choice", 0)), int(record.get("grading_version", 1)))

func earned_profit() -> int:
	var total: int = 0
	for record: Dictionary in records: total += int(record.profit)
	return total

func stage_info(number: int = 0) -> Dictionary:
	var current: Dictionary = current_contract()
	var selected_stage: int = number if number > 0 else int(current.get("stage", _legacy_stage(contract_index)))
	var info: Dictionary = Catalog.stage(selected_stage)
	if info.is_empty(): return {}
	info.earned_profit = earned_profit()
	info.saved_balance = INITIAL_BALANCE + earned_profit()
	info.completed_projects = records.size()
	return info

func stage_unlock_status(number: int) -> Dictionary:
	return _unlock_status(number, records)

static func _legacy_stage(index: int) -> int:
	var stages: Array[int] = [1, 1, 2, 3, 4, 5]
	return stages[index % 6]

static func _unlock_status(number: int, completed: Array[Dictionary]) -> Dictionary:
	var info: Dictionary = Catalog.stage(number)
	if info.is_empty(): return {"unlocked": false, "reason": "찾을 수 없는 건축 단계예요."}
	var profit: int = 0
	var previous_complete: bool = number == 1
	for record: Dictionary in completed:
		profit += int(record.profit)
		var record_stage: int = int(record_contract(record).get("stage", _legacy_stage(int(record.index))))
		if record_stage == number - 1: previous_complete = true
	var saved_balance: int = INITIAL_BALANCE + profit
	var enough_profit: bool = profit >= int(info.minimum_profit)
	var enough_balance: bool = saved_balance >= int(info.minimum_balance)
	var unlocked: bool = previous_complete and enough_profit and enough_balance
	var reason: String = "이 단계의 의뢰를 받을 수 있어요."
	if not previous_complete: reason = "%d단계 집을 먼저 완성해 주세요." % (number - 1)
	elif not enough_profit or not enough_balance: reason = "앞 단계 의뢰를 다시 지어 돈을 모아요. 모은 이익 %s, 남은 돈 %s가 필요해요." % [Catalog.format_won(int(info.minimum_profit)), Catalog.format_won(int(info.minimum_balance))]
	return {"stage": number, "unlocked": unlocked, "reason": reason, "previous_complete": previous_complete, "earned_profit": profit, "saved_balance": saved_balance, "minimum_profit": int(info.minimum_profit), "minimum_balance": int(info.minimum_balance), "missing_profit": maxi(0, int(info.minimum_profit) - profit), "missing_balance": maxi(0, int(info.minimum_balance) - saved_balance)}

func select_contract(choice: int) -> bool:
	if phase not in ["briefing", "settled"] or choice < 0 or choice >= Catalog.contract_count(): return false
	var offer: Dictionary = Catalog.contract(choice)
	var status: Dictionary = stage_unlock_status(int(offer.stage))
	if not bool(status.unlocked):
		last_error = str(status.reason)
		return false
	if phase == "settled":
		if contract_index + 1 >= MAX_CONTRACTS: return false
		contract_index += 1
	contract_choice = choice
	contract_grading_version = GRADING_VERSION
	phase = "briefing"
	last_result = {}
	document.editing_enabled = false
	document.reset()
	document.budget_limit = int(offer.material_budget)
	changed.emit()
	return true

func repeat_contract() -> bool:
	return select_contract(contract_choice) if phase == "settled" else false

func material_cost() -> int:
	return document.material_cost()

func available_balance() -> int:
	return balance - (material_cost() if phase == "building" else 0)

func accept_contract() -> bool:
	if phase != "briefing" or contract_index >= MAX_CONTRACTS: return false
	contract_grading_version = GRADING_VERSION
	var offer: Dictionary = current_contract()
	var status: Dictionary = stage_unlock_status(int(offer.stage))
	if not bool(status.unlocked):
		last_error = str(status.reason)
		return false
	balance += int(offer.advance)
	phase = "building"
	document.budget_limit = mini(int(offer.material_budget), balance)
	document.editing_enabled = true
	changed.emit()
	return true

func build_starter() -> bool:
	if phase != "building": return false
	var items: Array[Dictionary] = [
		{"material_id": "door", "position": Vector2(500, 500)},
		{"material_id": "window", "position": Vector2(340, 480)}
	]
	for x: float in [240.0, 600.0]:
		for y: float in [530.0, 470.0]:
			items.append({"material_id": "wall", "position": Vector2(x, y)})
	for x: float in [320.0, 360.0]:
		for y: float in [530.0, 550.0]:
			items.append({"material_id": "brick", "position": Vector2(x, y)})
	for x: float in [400.0, 440.0]:
		for y: float in [450.0, 470.0, 490.0, 510.0, 530.0, 550.0]:
			items.append({"material_id": "brick", "position": Vector2(x, y)})
	return document.replace_parts(items)

func counts() -> Dictionary:
	return count_parts(document.parts)

static func count_parts(parts: Array[Dictionary]) -> Dictionary:
	var by_role: Dictionary = {}
	var by_kind: Dictionary = {}
	var selected_by_kind: Dictionary = {}
	var bricks: int = 0
	for family: String in Math.KINDS:
		by_kind[family] = 0
		selected_by_kind[family] = 0
	for item: Dictionary in parts:
		var material: Dictionary = Catalog.material(str(item.material_id))
		var role: String = str(material.role)
		by_role[role] = int(by_role.get(role, 0)) + 1
		bricks += int(material.brick_count)
		if Math.matches_kind(item.vertices, str(item.kind)):
			selected_by_kind[str(item.kind)] = int(selected_by_kind.get(str(item.kind), 0)) + 1
		for family: String in Math.classifications(item.vertices):
			by_kind[family] = int(by_kind[family]) + 1
	return {"doors": int(by_role.get("door", 0)), "windows": int(by_role.get("window", 0)), "bricks": bricks, "by_kind": by_kind, "selected_by_kind": selected_by_kind, "by_role": by_role, "placed": parts.size()}

func evaluate(inspection: Dictionary) -> Dictionary:
	var offer: Dictionary = current_contract()
	var result: Dictionary = _evaluate(document, offer, inspection, phase == "building", contract_grading_version)
	if contract_grading_version >= 5: result.award = Awards.assess(document.parts, result, offer)
	return result

func settle(inspection: Dictionary) -> Dictionary:
	if phase != "building":
		last_error = "이미 정산했거나 아직 의뢰를 받지 않았어요."
		return {}
	var evaluation: Dictionary = evaluate(inspection)
	if not bool(evaluation.can_submit):
		last_error = str(evaluation.feedback)
		return {}
	var offer: Dictionary = current_contract()
	var final_payment: int = int(offer.total) - int(offer.advance) + int(evaluation.bonus)
	var cost: int = material_cost() + int(offer.base_cost)
	if balance + final_payment < cost:
		last_error = "정산할 돈이 부족해요. 자재 예산을 다시 살펴보세요."
		return {}
	var record: Dictionary = {
		"index": contract_index, "id": str(offer.id), "client": str(offer.client), "title": str(offer.title),
		"total": int(offer.total), "advance": int(offer.advance), "base_cost": int(offer.base_cost),
		"material_cost": material_cost(), "score": int(evaluation.score), "bonus": int(evaluation.bonus), "grading_version": contract_grading_version,
		"final_payment": final_payment, "profit": int(evaluation.profit), "document": document.serialize()
	}
	if contract_grading_version >= 5:
		record.contract_choice = contract_choice
		record.award = Awards.assess(document.parts, evaluation, offer)
	balance += final_payment - cost
	records.append(record)
	last_result = record.duplicate(true)
	phase = "settled"
	document.editing_enabled = false
	document.command_manager.clear()
	changed.emit()
	return record.duplicate(true)

func next_contract() -> bool:
	if phase != "settled" or contract_index + 1 >= MAX_CONTRACTS: return false
	var next_choice: int = (contract_choice + 1) % Catalog.contract_count()
	if not bool(stage_unlock_status(int(Catalog.contract(next_choice).stage)).unlocked):
		next_choice = contract_choice
	if not bool(stage_unlock_status(int(Catalog.contract(next_choice).stage)).unlocked): next_choice = 0
	return select_contract(next_choice)

func serialize() -> Dictionary:
	return {"version": 1, "progression_version": 1, "balance": balance, "contract_index": contract_index, "contract_choice": contract_choice, "contract_grading_version": contract_grading_version, "phase": phase, "records": records.duplicate(true), "document": document.serialize()}

func restore(data: Dictionary) -> bool:
	if not data.has_all(["version", "balance", "contract_index", "phase", "records", "document"]): return false
	if not Document._integer(data.version, 1, 1) or not Document._integer(data.contract_index, 0, MAX_CONTRACTS - 1): return false
	if not Document._integer(data.balance, 0, 10000000000000) or int(data.balance) % 100 != 0: return false
	if not data.phase is String or not ["briefing", "building", "settled"].has(data.phase): return false
	# Drafts created before length conditions retain the conditions they accepted.
	var checked_grading: Variant = data.get("contract_grading_version", 2 if str(data.phase) == "building" else GRADING_VERSION)
	if not Document._integer(checked_grading, 1, GRADING_VERSION): return false
	if str(data.phase) == "briefing": checked_grading = GRADING_VERSION
	if not data.records is Array or not data.document is Dictionary: return false
	var index: int = int(data.contract_index)
	var checked_choice: int = 0
	var has_progression: bool = data.has("progression_version")
	if has_progression:
		if not Document._integer(data.progression_version, 1, 1) or not Document._integer(data.get("contract_choice"), 0, Catalog.contract_count() - 1): return false
		checked_choice = int(data.contract_choice)
	elif data.has("contract_choice"):
		return false
	var expected_records: int = index + (1 if str(data.phase) == "settled" else 0)
	if data.records.size() != expected_records: return false
	var checked_records: Array[Dictionary] = []
	var expected_balance: int = INITIAL_BALANCE
	for number: int in range(data.records.size()):
		var raw: Variant = data.records[number]
		if not raw is Dictionary or not _valid_record(raw, number): return false
		if int(raw.get("grading_version", 1)) >= 5:
			if not bool(_unlock_status(int(record_contract(raw).stage), checked_records).unlocked): return false
		checked_records.append(raw.duplicate(true))
		expected_balance += int(raw.profit)
	if str(data.phase) == "settled":
		var settled_grading: int = int(checked_records.back().get("grading_version", 1))
		if data.has("contract_grading_version") and int(checked_grading) != settled_grading: return false
		checked_grading = settled_grading
		if int(checked_grading) >= 5 and int(checked_records.back().contract_choice) != checked_choice: return false
	if not has_progression:
		# Earlier ledgers preserve accepted rules. An unaccepted next visit starts
		# at an affordable current offer, without discarding any completed house.
		checked_choice = index % Catalog.contract_count()
		if str(data.phase) == "briefing" and not bool(_unlock_status(int(Catalog.contract(checked_choice).stage), checked_records).unlocked): checked_choice = 0
	if int(checked_grading) >= 5 and not bool(_unlock_status(int(Catalog.contract(checked_choice).stage), checked_records).unlocked): return false
	var checked_offer: Dictionary = _offer(index, checked_choice, int(checked_grading))
	if str(data.phase) == "building": expected_balance += int(checked_offer.advance)
	if int(data.balance) != expected_balance: return false
	var checked: Document = Document.new()
	checked.budget_limit = int(checked_offer.material_budget)
	if not checked.restore(data.document): return false
	if str(data.phase) == "briefing" and not checked.parts.is_empty(): return false
	if str(data.phase) == "settled" and data.document.parts != checked_records.back().document.parts:
		return false
	# No live model is changed until the entire ledger and geometry have passed validation.
	document.changed.disconnect(_document_changed)
	document = checked
	document.changed.connect(_document_changed)
	balance = expected_balance
	contract_index = index
	contract_choice = checked_choice
	contract_grading_version = int(checked_grading)
	phase = str(data.phase)
	records = checked_records
	last_result = records.back().duplicate(true) if phase == "settled" else {}
	document.editing_enabled = phase == "building"
	changed.emit()
	return true

static func _evaluate(model: Document, offer: Dictionary, inspection: Dictionary, building: bool, grading_version: int = GRADING_VERSION) -> Dictionary:
	var rows: Array[Dictionary] = []
	var all_required: bool = true
	var met_optional: int = 0
	var optional_count: int = 0
	var met_required: int = 0
	var required_count: int = 0
	var counts: Dictionary = count_parts(model.parts)
	for requirement: Dictionary in offer.requirements:
		if int(requirement.get("since", 1)) > grading_version: continue
		var current: int = _requirement_count(model.parts, counts, requirement)
		var met: bool = current >= int(requirement.amount)
		var mandatory: bool = bool(requirement.mandatory)
		rows.append({"label": str(requirement.label), "met": met, "current": current, "target": int(requirement.amount), "mandatory": mandatory})
		if mandatory:
			required_count += 1
			if met: met_required += 1
			all_required = all_required and met
		else:
			optional_count += 1
			if met: met_optional += 1
	var fresh: bool = Document._integer(inspection.get("revision", -1), 0, 1000000000) and int(inspection.get("revision", -1)) == model.revision
	var stable: bool = fresh and inspection.get("stable", false) is bool and bool(inspection.get("stable", false))
	var stable_ids: Variant = inspection.get("stable_ids", [])
	var unsupported: Variant = inspection.get("unsupported_ids", [])
	stable = stable and stable_ids is Array and unsupported is Array and unsupported.is_empty() and not model.parts.is_empty()
	if stable:
		for item: Dictionary in model.parts:
			if not stable_ids.has(int(item.id)): stable = false
	rows.append({"label": "중력 검사 · 문과 창 주변 지지", "met": stable, "current": 1 if stable else 0, "target": 1, "mandatory": true})
	var sheltered: bool = _openings_have_roofs(model.parts, grading_version >= 2)
	rows.append({"label": "문·창문 위에 지붕 올리기", "met": sheltered, "current": 1 if sheltered else 0, "target": 1, "mandatory": true})
	var facade: Dictionary = Facade.inspect(model.parts)
	var enclosed: bool = bool(facade.complete) or grading_version < 4
	if grading_version >= 4:
		rows.append({"label": "바닥부터 처마까지 외벽 빈틈 채우기", "met": enclosed, "current": 1 if enclosed else 0, "target": 1, "mandatory": true})
	var within_budget: bool = model.material_cost() <= int(offer.material_budget)
	rows.append({"label": "자재 예산 지키기", "met": within_budget, "current": model.material_cost(), "target": int(offer.material_budget), "mandatory": true})
	var approved: bool = true
	if grading_version >= 5 and offer.has("allowed_kinds"):
		for item: Dictionary in model.parts:
			if not offer.allowed_kinds.has(str(item.kind)): approved = false
			if str(Catalog.material(str(item.material_id)).role) == "roof" and not offer.roof_allowed_kinds.has(str(item.kind)): approved = false
		rows.append({"label": "이번 단계에서 고를 수 있는 사각형 사용하기", "met": approved, "current": 1 if approved else 0, "target": 1, "mandatory": true})
	var score: int = (30 if stable else 0) + (10 if sheltered and enclosed else 0) + (30 * met_required / maxi(required_count, 1)) + (20 * met_optional / maxi(optional_count, 1)) + (10 if within_budget else 0)
	var bonus: int = (int(offer.max_bonus) * score / 10000) * 100
	var feedback: String = "의뢰인의 부탁을 모두 살폈어요. 집을 전달할 수 있어요."
	if not building: feedback = "새 의뢰를 받아 건축을 시작해 주세요."
	elif not fresh: feedback = "설계가 바뀌었어요. 시공 검사를 다시 해 주세요."
	elif not stable: feedback = str(inspection.get("message", "문과 창 주변, 벽과 지붕의 받침을 확인해 주세요."))
	elif not sheltered: feedback = "문과 창문 위를 지붕으로 덮어 주세요. 땅에 놓은 지붕은 집을 덮지 못해요."
	elif not enclosed: feedback = str(facade.message)
	elif not approved: feedback = "이번 단계에서 고를 수 있는 사각형으로 바꿔 주세요. 다음 단계에서 새 도형을 사용할 수 있어요."
	elif not all_required: feedback = "필수 부탁이 남았어요. 문·창문·벽·지붕을 확인해 주세요."
	elif not within_budget: feedback = "자재 예산을 넘었어요. 견적을 다시 살펴보세요."
	elif met_optional < optional_count: feedback = "안전한 집이에요. 추가 부탁을 채우면 만족도와 보너스가 더 올라가요. 지금 전달할 수도 있어요."
	return {"can_submit": building and stable and sheltered and enclosed and all_required and within_budget and approved, "score": score, "bonus": bonus, "rows": rows, "feedback": feedback, "facade": facade, "material_cost": model.material_cost(), "base_cost": int(offer.base_cost), "total": int(offer.total), "profit": int(offer.total) + bonus - int(offer.base_cost) - model.material_cost(), "revision": model.revision}

static func _openings_have_roofs(parts: Array[Dictionary], full_width: bool = true) -> bool:
	var found: bool = false
	for opening: Dictionary in parts:
		if not bool(Catalog.material(str(opening.material_id)).opening): continue
		found = true
		var aperture: Rect2 = Math.bounds(Document.world_vertices(opening))
		var covered: bool = false
		var ranges: Array[Vector2] = []
		for candidate: Dictionary in parts:
			if str(Catalog.material(str(candidate.material_id)).role) != "roof": continue
			var roof: Rect2 = Math.bounds(Document.world_vertices(candidate))
			if roof.end.y > aperture.position.y + 0.1: continue
			if full_width:
				ranges.append(Vector2(roof.position.x, roof.end.x))
				continue
			var center_x: float = aperture.get_center().x
			if center_x >= roof.position.x and center_x <= roof.end.x:
				covered = true
				break
		if full_width:
			# Project the actual four-vertex roofs and merge adjacent spans. A
			# center-only match left the outer sides of a window exposed.
			ranges.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
			var reached: float = aperture.position.x
			for interval: Vector2 in ranges:
				if interval.y < reached: continue
				if interval.x > reached + 0.1: break
				reached = maxf(reached, interval.y)
				if reached >= aperture.end.x - 0.1:
					covered = true
					break
		if not covered: return false
	return found

static func _requirement_count(parts: Array[Dictionary], counts: Dictionary, requirement: Dictionary) -> int:
	var category: String = str(requirement.category)
	if category == "family_variety":
		var families: int = 0
		for family: String in counts.selected_by_kind:
			if int(counts.selected_by_kind[family]) > 0: families += 1
		return families
	if category.begins_with("selected_") and category.ends_with("_kind"):
		var selected_role: String = category.trim_prefix("selected_").trim_suffix("_kind")
		var selected_count: int = 0
		for item: Dictionary in parts:
			if str(Catalog.material(str(item.material_id)).role) == selected_role and str(item.kind) == str(requirement.target) and Math.matches_kind(item.vertices, str(requirement.target)):
				selected_count += 1
		return selected_count
	if category == "role": return int(counts.by_role.get(str(requirement.target), 0))
	if category == "brick_count": return int(counts.bricks)
	if category == "kind": return int(counts.by_kind.get(str(requirement.target), 0))
	if category == "length_variety":
		var distinct_lengths: Array[float] = []
		for item: Dictionary in parts:
			var longest: float = _part_lengths(item).y
			var found: bool = false
			for previous: float in distinct_lengths:
				if absf(previous - longest) <= 0.01: found = true
			if not found: distinct_lengths.append(longest)
		return distinct_lengths.size()
	if category == "edge_lengths":
		var matches: int = 0
		for item: Dictionary in parts:
			if str(Catalog.material(str(item.material_id)).role) != str(requirement.role): continue
			if not Math.matches_kind(item.vertices, str(requirement.target)): continue
			var lengths: Vector2 = _part_lengths(item)
			var short_met: bool = float(requirement.shortest) <= 0.0 or absf(lengths.x - float(requirement.shortest)) <= 0.01
			var long_met: bool = lengths.y + 0.01 >= float(requirement.longest) if bool(requirement.minimum) else absf(lengths.y - float(requirement.longest)) <= 0.01
			if short_met and long_met: matches += 1
		return matches
	var role: String = category.trim_suffix("_kind")
	var total: int = 0
	for item: Dictionary in parts:
		if str(Catalog.material(str(item.material_id)).role) == role and Math.matches_kind(item.vertices, str(requirement.target)):
			total += 1
	return total

static func _part_lengths(item: Dictionary) -> Vector2:
	var lengths: PackedFloat32Array = Math.side_lengths(item.vertices)
	var shortest: float = INF
	var longest: float = 0.0
	for length: float in lengths:
		shortest = minf(shortest, length / Catalog.GRID_UNIT)
		longest = maxf(longest, length / Catalog.GRID_UNIT)
	return Vector2(shortest, longest)

static func _valid_record(raw: Dictionary, index: int) -> bool:
	if not raw.has_all(["index", "id", "client", "title", "total", "advance", "base_cost", "material_cost", "score", "bonus", "final_payment", "profit", "document"]): return false
	var grading: Variant = raw.get("grading_version", 1)
	if not Document._integer(grading, 1, GRADING_VERSION): return false
	if not Document._integer(raw.index, index, index): return false
	if int(grading) >= 5 and (not Document._integer(raw.get("contract_choice"), 0, Catalog.contract_count() - 1) or not raw.has("award")): return false
	if int(grading) < 5 and raw.has("award"): return false
	var offer: Dictionary = record_contract(raw)
	if raw.id != offer.id or raw.client != offer.client or raw.title != offer.title: return false
	for field: String in ["total", "advance", "base_cost"]:
		if not Document._integer(raw[field], int(offer[field]), int(offer[field])): return false
	if not raw.document is Dictionary: return false
	var model: Document = Document.new()
	model.budget_limit = int(offer.material_budget)
	if not model.restore(raw.document): return false
	var ids: Array[int] = []
	for item: Dictionary in model.parts: ids.append(int(item.id))
	# v1 predates full-width roofs, v2 lengths, and v3 facade enclosure.
	# Reconstruct each old offer before validating its already-paid ledger.
	var evaluation: Dictionary = _evaluate(model, offer, {"stable": true, "stable_ids": ids, "unsupported_ids": [], "revision": model.revision}, true, int(grading))
	if not bool(evaluation.can_submit): return false
	if int(grading) >= 5 and not Awards.matches(raw.award, model.parts, evaluation, offer): return false
	for field: String in ["material_cost", "score", "bonus", "profit"]:
		if not Document._integer(raw[field], int(evaluation[field]), int(evaluation[field])): return false
	var payment: int = int(offer.total) - int(offer.advance) + int(evaluation.bonus)
	return Document._integer(raw.final_payment, payment, payment)
