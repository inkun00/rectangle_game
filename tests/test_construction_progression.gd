class_name TestConstructionProgression
extends RefCounted

const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const State = preload("res://scripts/construction/construction_state.gd")
const Document = preload("res://scripts/construction/construction_document.gd")
const Guide = preload("res://scripts/construction/construction_guide.gd")
const Facade = preload("res://scripts/construction/construction_facade.gd")

static func run(t: Node) -> void:
	_test_stages_and_flat_roofs(t)
	_test_progression_and_repeats(t)
	_test_legacy_and_atomic_restore(t)

static func _test_stages_and_flat_roofs(t: Node) -> void:
	t.assert_eq(Catalog.stages().size(), 5, "Construction has five explicit difficulty stages")
	t.assert_eq(Catalog.contract_count(), 10, "Each construction stage has two authored offers")
	var previous_budget: int = 0
	var previous_profit: int = -1
	for stage_number: int in range(1, 6):
		var stage: Dictionary = Catalog.stage(stage_number)
		t.assert_eq(stage.allowed_kinds.size(), mini(stage_number + 1, 5), "Stages gradually introduce the five selectable families")
		t.assert_gt(int(stage.minimum_profit), previous_profit, "Later stages require progressively more earned profit")
		previous_profit = int(stage.minimum_profit)
		for choice: int in range((stage_number - 1) * 2, stage_number * 2):
			var offer: Dictionary = Catalog.contract(choice)
			t.assert_eq(int(offer.stage), stage_number, "Every offer belongs to its explicit stage")
			t.assert_gt(int(offer.total) - int(offer.base_cost) - int(offer.material_budget), 0, "Even full-budget work makes money without any bonus")
			t.assert_true(offer.roof_allowed_kinds.has("rectangle"), "A flat rectangular main roof remains available throughout progression")
			t.assert_true(int(offer.advance) + State.INITIAL_BALANCE >= int(offer.material_budget), "Clients fund the material budget before construction")
		var offer: Dictionary = Catalog.contract((stage_number - 1) * 2)
		t.assert_gt(int(offer.material_budget), previous_budget, "More difficult stages offer a larger material budget")
		previous_budget = int(offer.material_budget)
	for id: String in ["roof_flat", "roof_flat_wide"]:
		var material: Dictionary = Catalog.material(id)
		var vertices: PackedVector2Array = QuadrilateralMath.create_vertices(str(material.kind), material.dimensions)
		t.assert_eq(material.role, "roof", "Flat slabs function as roofs rather than relabeled decoration")
		t.assert_true(bool(material.structural), "Flat roof slabs supply real structural collision")
		t.assert_eq(material.kind, "rectangle", "Flat roof material declares its genuine rectangle family")
		t.assert_true(QuadrilateralMath.matches_kind(vertices, "rectangle"), "Four actual roof vertices form a rectangle")
		t.assert_true(QuadrilateralMath.matches_kind(vertices, "trapezoid"), "Flat rectangles retain inclusive trapezoid classification")
	var state: State = State.new()
	state.accept_contract()
	t.assert_true(state.document.replace_parts(Guide.plan()), "The first guide buys only simple square and rectangle materials")
	t.assert_true(Facade.inspect(state.document.parts).complete, "The flat-roof guide encloses the entire house facade")
	var evaluation: Dictionary = state.evaluate(stable_report(state.document))
	t.assert_true(evaluation.can_submit, "A simple flat-roof house satisfies the first contract")
	t.assert_eq(evaluation.score, 100, "The first client can be fully satisfied using two shape families")
	var counts: Dictionary = state.counts()
	var variety: Dictionary = Catalog._need("종류", "family_variety", "", 2, true)
	t.assert_eq(State._requirement_count(state.document.parts, counts, variety), 2, "Inclusive classifications do not inflate the number of selected families")
	var flat_roofs: Array[Dictionary] = []
	for part: Dictionary in state.document.parts:
		if str(Catalog.material(str(part.material_id)).role) == "roof": flat_roofs.append(part)
	var selected_trapezoid: Dictionary = Catalog._need("사다리꼴 지붕 고르기", "selected_roof_kind", "trapezoid", 1, false)
	var inclusive_trapezoid: Dictionary = Catalog._need("사다리꼴 성질", "roof_kind", "trapezoid", 1, false)
	t.assert_eq(State._requirement_count(flat_roofs, State.count_parts(flat_roofs), selected_trapezoid), 0, "A request to select trapezoid material distinguishes a flat rectangle")
	t.assert_eq(State._requirement_count(flat_roofs, State.count_parts(flat_roofs), inclusive_trapezoid), 1, "A property-based trapezoid request still includes rectangles")
	state.document.add_part("ornament", Vector2(240, 480))
	t.assert_false(state.evaluate(stable_report(state.document)).can_submit, "A later-stage family cannot bypass the first stage's restrictions")
	t.assert_true(state.settle(stable_report(state.document)).is_empty(), "Unsupported early-stage shapes cannot earn a payment")

static func _test_progression_and_repeats(t: Node) -> void:
	var state: State = State.new()
	var untouched: Dictionary = state.serialize()
	t.assert_false(state.select_contract(2), "The second stage is locked before earning money or finishing the first")
	t.assert_eq(state.serialize(), untouched, "A locked commission cannot change finance, history or the current site")
	t.assert_false(state.stage_unlock_status(5).unlocked, "The fifth stage cannot be skipped from a fresh company")
	var completed_choices: Array[int] = []
	for choice: int in range(Catalog.contract_count()):
		var stage: int = int(Catalog.contract(choice).stage)
		var repeats: int = 0
		while not bool(state.stage_unlock_status(stage).unlocked) and repeats < 12:
			t.assert_true(state.repeat_contract(), "Unlocked lower-stage work can be repeated to save more money")
			_finish_offer(t, state)
			repeats += 1
		t.assert_true(state.stage_unlock_status(stage).unlocked, "Earned lower-stage profits make the next stage reachable")
		t.assert_true(state.select_contract(choice), "An affordable unlocked client can be chosen")
		t.assert_eq(int(state.stage_info().stage), stage, "Stage information follows the selected client")
		_finish_offer(t, state)
		completed_choices.append(choice)
		var restored: State = State.new()
		t.assert_true(restored.restore(JSON.parse_string(JSON.stringify(state.serialize()))), "Each paid stage restores its precise offer, account and award metadata")
		t.assert_eq(restored.balance, state.balance, "Restoring progression preserves the exact legitimately earned balance")
		t.assert_eq(restored.contract_choice, choice, "Restoring progression preserves a chosen offer independently of the project count")
		t.assert_eq(restored.records.size(), state.records.size(), "Repeated work remains separate paid projects in the ledger")
	t.assert_eq(completed_choices.size(), 10, "All ten clients are reachable without inventing money")
	for stage: int in range(1, 6): t.assert_true(state.stage_unlock_status(stage).unlocked, "Every earned construction stage remains available")
	var saved_balance: int = state.balance
	var previous_projects: int = state.records.size()
	t.assert_true(state.select_contract(0), "An experienced builder can return to an affordable first-stage client")
	_finish_offer(t, state)
	t.assert_gt(state.balance, saved_balance, "Low-stage repeated work continues to pay a meaningful positive profit")
	t.assert_eq(state.records.size(), previous_projects + 1, "Repeating a client creates a new unique settlement")
	t.assert_eq(state.records.back().id, "commission_%d" % (state.records.size() - 1), "Repeat invoices have unique project identities")
	t.assert_eq(State.record_contract(state.records.back()).client, Catalog.contract(0).client, "A repeated invoice reconstructs the selected client rather than the project number")
	var before: String = JSON.stringify(state.serialize())
	var invalid: Dictionary = state.serialize()
	invalid.records.back().award.tier = int(invalid.records.back().award.tier) + 1
	t.assert_false(state.restore(JSON.parse_string(JSON.stringify(invalid))), "Award metadata cannot be edited independently of the saved house")
	t.assert_eq(JSON.stringify(state.serialize()), before, "A forged award leaves the entire live ledger unchanged")

static func _finish_offer(t: Node, state: State) -> void:
	t.assert_true(state.accept_contract(), "Chosen commission can be accepted once")
	var balance_after_advance: int = state.balance
	t.assert_false(state.accept_contract(), "Repeating acceptance cannot duplicate the customer's advance")
	t.assert_eq(state.balance, balance_after_advance, "Duplicate acceptance preserves the account")
	var offer: Dictionary = state.current_contract()
	t.assert_true(state.document.replace_parts(Guide.example_for_contract(offer)), "Every stage has an affordable nonoverlapping design using its approved shapes")
	t.assert_true(Facade.inspect(state.document.parts).complete, "Every stage example has a completely closed facade")
	var inspection: Dictionary = stable_report(state.document)
	var evaluation: Dictionary = state.evaluate(inspection)
	t.assert_true(evaluation.can_submit, "Every staged offer can be completed with real catalog materials")
	t.assert_eq(int(evaluation.score), 100, "Every staged client has a feasible design satisfying all preferences")
	var cash_before: int = state.balance
	var record: Dictionary = state.settle(inspection)
	t.assert_false(record.is_empty(), "Successful construction records a paid invoice")
	if record.is_empty(): return
	t.assert_gt(int(record.profit), 0, "The completed job increases accumulated earnings")
	t.assert_eq(state.balance, cash_before + int(record.final_payment) - int(record.base_cost) - int(record.material_cost), "Payment and both cost components commit together")
	t.assert_eq(state.balance, State.INITIAL_BALANCE + state.earned_profit(), "Savings contain seed money and recorded profits only")
	t.assert_true(record.has("award"), "Current invoices preserve deterministic design award feedback")
	var paid_balance: int = state.balance
	t.assert_true(state.settle(inspection).is_empty(), "A repeated delivery cannot pay twice")
	t.assert_eq(state.balance, paid_balance, "An already-paid house cannot change savings")

static func _test_legacy_and_atomic_restore(t: Node) -> void:
	var old: State = State.new()
	old.accept_contract()
	old.contract_grading_version = 3
	old.build_starter()
	old.document.add_part("lintel", Vector2(340, 430))
	old.document.add_part("lintel", Vector2(500, 430))
	old.document.add_part("brick", Vector2(420, 430))
	old.document.add_part("roof_wide", Vector2(420, 370))
	t.assert_false(old.settle(stable_report(old.document)).is_empty(), "A previously accepted v3 contract retains its original roof and facade rules")
	var historical: Dictionary = old.serialize()
	historical.erase("progression_version")
	historical.erase("contract_choice")
	var restored: State = State.new()
	t.assert_true(restored.restore(JSON.parse_string(JSON.stringify(historical))), "Earlier v3 construction ledgers migrate without losing their houses")
	t.assert_eq(restored.balance, old.balance, "Earlier v3 income is preserved rather than repriced")
	t.assert_false(restored.last_result.has("award"), "Migration does not invent an unearned design award")
	t.assert_true(restored.next_contract(), "A migrated company can accept new stage-based work")
	t.assert_eq(restored.contract_grading_version, 5, "New work after migration uses current progression rules")
	var before: String = JSON.stringify(restored.serialize())
	var invalid: Dictionary = restored.serialize()
	invalid.contract_choice = 9
	t.assert_false(restored.restore(invalid), "A saved choice cannot jump to an unearned stage")
	t.assert_eq(JSON.stringify(restored.serialize()), before, "Rejected progression metadata leaves the current site and savings intact")
	invalid = restored.serialize()
	invalid.balance += 100
	t.assert_false(restored.restore(invalid), "Money must still reconcile exactly to the paid ledger")
	t.assert_eq(JSON.stringify(restored.serialize()), before, "A rejected account preserves all live state")

static func stable_report(document: Document) -> Dictionary:
	var ids: Array[int] = []
	for part: Dictionary in document.parts: ids.append(int(part.id))
	return {"stable": true, "stable_ids": ids, "unsupported_ids": [], "revision": document.revision, "message": "검사 통과"}
