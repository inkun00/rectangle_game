class_name TestConstructionModel
extends RefCounted

const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Document = preload("res://scripts/construction/construction_document.gd")
const State = preload("res://scripts/construction/construction_state.gd")
const Save = preload("res://scripts/construction/construction_save_store.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")

static func run(t: Node) -> void:
	_test_materials_and_openings(t)
	_test_balanced_catalog(t)
	_test_history_and_validation(t)
	_test_contracts_and_money(t)
	_test_persistence(t)
	_test_save_recovery(t)
	_test_roof_coverage_and_legacy_records(t)
	_test_length_conditions(t)
	_test_facade_grading_migration(t)

static func _test_facade_grading_migration(t: Node) -> void:
	var historical: State = State.new()
	historical.accept_contract()
	historical.contract_grading_version = 3
	historical.build_starter()
	historical.document.add_part("lintel", Vector2(340, 430))
	historical.document.add_part("lintel", Vector2(500, 430))
	historical.document.add_part("brick", Vector2(420, 430))
	historical.document.add_part("roof_wide", Vector2(420, 370))
	var report: Dictionary = _stable_report(historical.document)
	t.assert_true(historical.evaluate(report).can_submit, "A previously accepted v3 contract keeps its agreed rules")
	var current: Dictionary = State._evaluate(historical.document, historical.current_contract(), report, true)
	t.assert_false(current.can_submit, "New facade grading rejects the earlier guide's open eaves despite a stable physics report")
	t.assert_false(current.facade.complete, "Facade diagnosis is derived from real geometry instead of trusting the stable flag")
	var draft: State = State.new()
	t.assert_true(draft.restore(JSON.parse_string(JSON.stringify(historical.serialize()))), "Existing v3 drafts retain their parts and accepted contract")
	t.assert_eq(draft.contract_grading_version, 3, "A draft migration does not silently change an accepted commission")
	var paid: Dictionary = historical.settle(report)
	t.assert_false(paid.is_empty(), "An old accepted draft can settle once under its original conditions")
	var loaded: State = State.new()
	t.assert_true(loaded.restore(JSON.parse_string(JSON.stringify(historical.serialize()))), "Paid v3 houses with former eave gaps remain readable")
	t.assert_eq(loaded.balance, historical.balance, "Facade migration does not recalculate already-paid money")
	t.assert_true(loaded.next_contract(), "An old house can continue to the next client")
	t.assert_eq(loaded.contract_grading_version, State.GRADING_VERSION, "The next client adopts the new facade conditions")

static func _test_materials_and_openings(t: Node) -> void:
	var families: Array[String] = []
	for material: Dictionary in Catalog.materials():
		t.assert_true(int(material.price) >= 100 and int(material.price) % 100 == 0, "Construction prices are integer hundreds: " + str(material.id))
		t.assert_false(str(material.source_url).is_empty(), "Construction material has price provenance: " + str(material.id))
		var vertices: PackedVector2Array = Math.create_vertices(str(material.kind), material.dimensions)
		t.assert_true(Math.matches_kind(vertices, str(material.kind)), "Construction material preserves its quadrilateral family")
		var angle_sum: float = 0.0
		for angle: float in Math.angles_degrees(vertices): angle_sum += angle
		t.assert_float_approx(angle_sum, 360.0, 0.01, "Construction quadrilateral angle sum")
		if not families.has(str(material.kind)): families.append(str(material.kind))
	t.assert_eq(families.size(), 5, "Construction offers all five curriculum families")
	t.assert_eq(Catalog.format_won(199500000), "199,500,000원", "Large KRW uses thousands separators")
	t.assert_eq(Catalog.read_won(199500000), "1억 9,950만 원", "Large KRW uses Korean four-digit grouping")
	t.assert_eq(Catalog.read_won(123456700), "1억 2,345만 6,700 원", "Korean money retains hundred-won precision")
	t.assert_eq(Catalog.format_won(0), "0원", "Zero balance is readable")
	var model: Document = Document.new()
	t.assert_gt(model.add_part("window", Vector2(340, 480)), 0, "Window can reserve a space before walls")
	t.assert_eq(model.add_part("brick", Vector2(340, 480)), -1, "Brick cannot cover a reserved window")
	t.assert_true(model.last_error.contains("문·창문"), "Opening conflict explains the reserved space")
	t.assert_gt(model.add_part("brick", Vector2(320, 530)), 0, "Brick can touch window sill without overlap")
	t.assert_gt(model.add_part("door", Vector2(500, 500)), 0, "Door can reserve a ground-level aperture")
	t.assert_eq(model.add_part("wall", Vector2(500, 500)), -1, "Wall bundle cannot fill door aperture")
	t.assert_eq(model.add_part("ornament", Vector2(500, 500)), -1, "Decoration cannot cover a real doorway")
	t.assert_eq(model.add_part("brick", Vector2(60, 580)), -1, "Building material cannot go below foundation")
	t.assert_eq(model.add_part("brick", Vector2(INF, 20)), -1, "Nonfinite positions are rejected")
	t.assert_eq(model.add_part("window", Vector2(800, 400), "triangle"), -1, "Unapproved shape families rejected")
	var expensive: Document = Document.new()
	expensive.budget_limit = 1000
	t.assert_eq(expensive.add_part("door", Vector2(500, 500)), -1, "Budget prevents unaffordable purchases")
	t.assert_eq(expensive.material_cost(), 0, "Rejected purchase charges no money")

static func _test_balanced_catalog(t: Node) -> void:
	var counts: Dictionary = {}
	var roles: Dictionary = {}
	var lengths: Dictionary = {}
	var seen: Array[String] = []
	for family: String in Math.KINDS:
		counts[family] = 0
		roles[family] = {}
		lengths[family] = {}
	for material: Dictionary in Catalog.materials():
		var id: String = str(material.id)
		var family: String = str(material.kind)
		t.assert_false(seen.has(id), "Balanced catalog has unique purchase IDs: " + id)
		seen.append(id)
		counts[family] = int(counts[family]) + 1
		roles[family][str(material.role)] = true
		var vertices: PackedVector2Array = Math.create_vertices(family, material.dimensions)
		var longest: float = 0.0
		for length: float in Math.side_lengths(vertices): longest = maxf(longest, length)
		lengths[family][snappedf(longest, 0.001)] = true
	t.assert_eq(seen.size(), 42, "Construction offers forty materials plus two genuine flat roof sizes")
	for family: String in Math.KINDS:
		t.assert_ge(int(counts[family]), 8, "Every quadrilateral family retains at least eight catalog choices: " + family)
		t.assert_gt((roles[family] as Dictionary).size(), 2, "Each family has functional uses beyond a single decoration role: " + family)
		t.assert_gt((lengths[family] as Dictionary).size(), 2, "Each family offers several measured lengths: " + family)
	var legacy_prices: Dictionary = {"brick": 500, "wall": 4500, "wall_square": 1000, "door": 572100, "door_short": 476800, "window": 233300, "window_small": 131200, "window_tall": 350000, "window_wide": 466600, "lintel": 13200, "lintel_long": 22000, "roof": 177100, "roof_medium": 265700, "roof_wide": 354200, "panel": 25400, "panel_long": 33100, "ornament": 41900, "ornament_large": 73800}
	for id: String in legacy_prices:
		t.assert_eq(int(Catalog.material(id).price), int(legacy_prices[id]), "Expanded catalog preserves prices used by existing saved ledgers: " + id)
	for id: String in Catalog.BALANCED_SPECS:
		var material: Dictionary = Catalog.material(id)
		t.assert_false(str(material.texture_key).is_empty(), "New material identifies its generated surface: " + id)
		t.assert_true(str(material.source_note).contains("추정") or str(material.source_note).contains("8장"), "New surface prices disclose their educational estimate: " + id)
		t.assert_false(Catalog.short_label(id).is_empty(), "New materials have a readable compact label: " + id)
		var document: Document = Document.new()
		var placed: int = document.add_part(id, Vector2(500, 280))
		t.assert_gt(placed, 0, "New material can be purchased and placed through normal commands: " + id)
		var original: Dictionary = document.serialize()
		t.assert_true(document.rotate_selected(90.0), "New material supports the existing rotation command: " + id)
		t.assert_true(Math.matches_kind(document.get_selected().vertices, str(material.kind)), "Rotation preserves a new material's chosen family: " + id)
		document.undo()
		t.assert_eq(document.serialize().parts, original.parts, "Undo restores every original vertex and position: " + id)
		t.assert_gt(document.revision, int(original.revision), "Undo keeps prior inspection reports invalidated for a new material: " + id)
		var restored: Document = Document.new()
		t.assert_true(restored.restore(JSON.parse_string(JSON.stringify(document.serialize()))), "New material survives validated JSON restoration: " + id)
		t.assert_eq(restored.material_cost(), document.material_cost(), "Restoring a new material preserves the quoted cost: " + id)

static func _test_history_and_validation(t: Node) -> void:
	var model: Document = Document.new()
	model.add_part("ornament", Vector2(200, 200))
	var initial: Dictionary = model.get_selected()
	t.assert_true(model.rotate_selected(37.0), "Free decoration can rotate")
	t.assert_true(Math.matches_kind(model.get_selected().vertices, "rhombus"), "Rotation preserves rhombus")
	model.undo()
	t.assert_eq(model.get_selected(), initial, "Rotation is one reversible command")
	model.move_selected(Vector2(300, 300))
	model.undo()
	t.assert_eq(model.get_selected(), initial, "Move restores all four local vertices and position")
	model.redo()
	t.assert_eq(model.get_selected().position, Vector2(300, 300), "Redo restores whole move")
	model.delete_selected()
	t.assert_eq(model.material_cost(), 0, "Delete refunds reserved material cost")
	model.undo()
	t.assert_eq(model.material_cost(), 41900, "Undo restores purchase reservation")
	model.clear()
	model.undo()
	t.assert_eq(model.parts.size(), 1, "Clear can be undone")
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(model.serialize()))
	var restored: Document = Document.new()
	t.assert_true(restored.restore(serialized), "Geometry survives JSON roundtrip")
	var before: String = JSON.stringify(restored.serialize())
	var bad: Dictionary = serialized.duplicate(true)
	bad.parts[0].vertices = [[0, 0], [20, 0], [40, 0], [60, 0]]
	t.assert_false(restored.restore(bad), "Collapsed construction part rejected")
	t.assert_eq(JSON.stringify(restored.serialize()), before, "Malformed construction restore is atomic")
	bad = serialized.duplicate(true)
	for vertex: Array in bad.parts[0].vertices:
		vertex[0] *= 2
		vertex[1] *= 2
	t.assert_false(restored.restore(bad), "Oversized saved part cannot bypass catalog size and price")
	bad = serialized.duplicate(true)
	bad.parts.append(bad.parts[0].duplicate(true))
	t.assert_false(restored.restore(bad), "Duplicate saved part ID rejected")
	model.editing_enabled = false
	var count: int = model.parts.size()
	model.delete_selected()
	model.undo()
	t.assert_eq(model.parts.size(), count, "Settled/briefing document ignores edit commands")
	model.editing_enabled = true
	var invalid_items: Array[Dictionary] = [{"material_id": "brick", "position": "not a vector"}]
	t.assert_false(model.replace_parts(invalid_items), "Malformed command position is rejected without a runtime error")
	invalid_items = [{"material_id": "brick", "position": Vector2(NAN, 0)}]
	t.assert_false(model.replace_parts(invalid_items), "Nonfinite command replacement is rejected")
	t.assert_eq(model.parts.size(), count, "Rejected replacement keeps existing construction")

static func _test_contracts_and_money(t: Node) -> void:
	var state: State = State.new()
	t.assert_eq(state.balance, 30000000, "New construction company seed balance")
	t.assert_eq(state.document.add_part("brick", Vector2(20, 550)), -1, "Must accept commission before spending")
	t.assert_true(state.accept_contract(), "Client commission can be accepted")
	t.assert_eq(state.balance, 70000000, "Contract advance is paid once")
	t.assert_false(state.accept_contract(), "Repeated acceptance cannot duplicate advance")
	t.assert_true(state.build_starter(), "Starter reserves real windows and doors with surrounding brickwork")
	var starter_count: int = state.document.parts.size()
	state.document.undo()
	t.assert_eq(state.document.parts.size(), 0, "Starter is one undoable construction command")
	state.document.redo()
	t.assert_eq(state.document.parts.size(), starter_count, "Starter can be redone")
	t.assert_eq(state.counts().windows, 1, "Starter has one visible aperture")
	t.assert_gt(state.counts().by_kind.rectangle, 0, "Inclusive classifications count rectangles")
	t.assert_gt(state.counts().by_kind.rhombus, 0, "Square window also satisfies rhombus classification")
	t.assert_false(state.evaluate(_stable_report(state.document)).can_submit, "Missing roof prevents handing in starter")
	state.document.add_part("roof", Vector2(860, 530))
	t.assert_false(state.evaluate(_stable_report(state.document)).can_submit, "A safe roof on the ground does not count as shelter for the house")
	state.document.delete_selected()
	_finish_first_house(state)
	var report: Dictionary = _stable_report(state.document)
	var evaluation: Dictionary = state.evaluate(report)
	t.assert_true(evaluation.can_submit, "Complete stable facade can be submitted")
	t.assert_eq(evaluation.score, 100, "All first-client preferences reach full satisfaction")
	var stale: Dictionary = report.duplicate(true)
	stale.revision = state.document.revision - 1
	t.assert_false(state.evaluate(stale).can_submit, "Stale physics report cannot approve changed design")
	var unsupported: Dictionary = report.duplicate(true)
	unsupported.stable_ids = []
	t.assert_false(state.evaluate(unsupported).can_submit, "Stable report must cover every actual part")
	var cash_before: int = state.balance
	var price: int = state.material_cost()
	t.assert_eq(state.available_balance(), cash_before - price, "Budget display reserves planned materials")
	var settled: Dictionary = state.settle(report)
	t.assert_false(settled.is_empty(), "Settlement succeeds")
	t.assert_eq(settled.grading_version, State.GRADING_VERSION, "New completed houses record the facade enclosure grading version")
	t.assert_eq(state.balance, State.INITIAL_BALANCE + int(settled.profit), "Settlement deducts base/material costs and credits only remaining payment")
	t.assert_eq(state.records.size(), 1, "Settlement records one finished house")
	var settled_balance: int = state.balance
	t.assert_true(state.settle(report).is_empty(), "Repeated submit cannot duplicate reward")
	t.assert_eq(state.balance, settled_balance, "Repeated submit keeps cash unchanged")
	t.assert_true(state.next_contract(), "Another client visits after settlement")
	t.assert_eq(state.contract_index, 1, "Next client advances progression")
	t.assert_eq(state.document.parts.size(), 0, "Next building starts a new lot")
	t.assert_eq(state.balance, settled_balance, "Next commission does not erase earned money")
	var names: Array[String] = []
	for index: int in range(6): names.append(str(Catalog.contract(index).client))
	t.assert_eq(names.size(), 6, "Six authored clients exist")
	t.assert_eq(Catalog.contract(6).id, "commission_6", "Repeat visits receive unique settlement IDs")
	var fewer_preferences: State = State.new()
	fewer_preferences.accept_contract()
	fewer_preferences.build_starter()
	for part: Dictionary in fewer_preferences.document.parts.duplicate():
		var position: Vector2 = part.position
		if str(part.material_id) == "window" or (position.x in [320.0, 360.0] and position.y in [530.0, 550.0]):
			fewer_preferences.document.select(int(part.id))
			fewer_preferences.document.delete_selected()
	fewer_preferences.document.add_part("window_tall", Vector2(340, 500))
	fewer_preferences.document.add_part("tile_square", Vector2(240, 480))
	_finish_first_house(fewer_preferences)
	var partial: Dictionary = fewer_preferences.evaluate(_stable_report(fewer_preferences.document))
	t.assert_true(partial.can_submit, "Stable mandatory-complete house may be delivered without optional square preference")
	t.assert_true(int(partial.score) < 100 and int(partial.bonus) < int(fewer_preferences.current_contract().max_bonus), "Optional preference affects visible satisfaction and payment")

static func _test_persistence(t: Node) -> void:
	var state: State = State.new()
	state.accept_contract()
	state.build_starter()
	_finish_first_house(state)
	state.settle(_stable_report(state.document))
	var stored: Dictionary = JSON.parse_string(JSON.stringify(state.serialize()))
	var restored: State = State.new()
	t.assert_true(restored.restore(stored), "Completed house and money ledger survive JSON roundtrip")
	t.assert_eq(restored.balance, state.balance, "Restored earnings are exact integer won")
	t.assert_eq(restored.records.size(), 1, "Completed commission persists")
	restored.document.select(int(restored.document.parts[0].id))
	var selected_copy: State = State.new()
	t.assert_true(selected_copy.restore(JSON.parse_string(JSON.stringify(restored.serialize()))), "Looking at another part after settlement does not invalidate the save")
	var before: String = JSON.stringify(restored.serialize())
	var bad: Dictionary = stored.duplicate(true)
	bad.balance += 100
	t.assert_false(restored.restore(bad), "Cash inconsistent with ledger rejected")
	t.assert_eq(JSON.stringify(restored.serialize()), before, "Malformed account restore leaves current progress intact")
	bad = stored.duplicate(true)
	bad.records[0].bonus += 100
	t.assert_false(restored.restore(bad), "Modified reward does not pass saved account validation")
	bad = stored.duplicate(true)
	bad.phase = "building"
	t.assert_false(restored.restore(bad), "Replaying completed contract phase rejected")
	bad = stored.duplicate(true)
	bad.document.parts[0].position = [0, -200]
	t.assert_false(restored.restore(bad), "Malformed saved house rejected before live changes")
	restored.next_contract()
	restored.accept_contract()
	restored.build_starter()
	var building: State = State.new()
	t.assert_true(building.restore(JSON.parse_string(JSON.stringify(restored.serialize()))), "Current advance and unfinished house persist")
	t.assert_false(building.accept_contract(), "Reloading cannot replay advance")
	var path: String = "res://.godot/construction_test_%d.json" % Time.get_ticks_usec()
	t.assert_true(Save.save(path, building).ok, "Independent construction save writes")
	var file_loaded: State = State.new()
	t.assert_true(Save.load_into(path, file_loaded).ok, "Independent construction save loads")
	t.assert_eq(file_loaded.balance, building.balance, "File save preserves balance")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ damaged")
	file.close()
	var file_before: String = JSON.stringify(file_loaded.serialize())
	t.assert_false(Save.load_into(path, file_loaded).ok, "Corrupt file is rejected")
	t.assert_eq(JSON.stringify(file_loaded.serialize()), file_before, "Corrupt file preserves live progress")
	DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path + ".bak"): DirAccess.remove_absolute(path + ".bak")

static func _test_save_recovery(t: Node) -> void:
	var path: String = "res://.godot/construction_recovery_%d.json" % Time.get_ticks_usec()
	var first: State = State.new()
	first.accept_contract()
	first.build_starter()
	var first_snapshot: String = JSON.stringify(first.serialize())
	t.assert_true(Save.save(path, first).ok, "Recovery fixture creates original save")
	first.document.add_part("lintel", Vector2(340, 430))
	var newest_snapshot: String = JSON.stringify(first.serialize())
	t.assert_true(Save.save(path, first).ok, "Second successful save retains an earlier backup")
	_write_test_file(path, "{ interrupted")
	var restored: State = State.new()
	var outcome: Dictionary = Save.load_into(path, restored)
	t.assert_true(outcome.ok and outcome.recovered, "Corrupt primary recovers from a valid backup")
	t.assert_eq(JSON.stringify(restored.serialize()), first_snapshot, "Recovered backup restores an internally consistent earlier ledger")
	t.assert_eq(outcome.source, path + ".bak", "Recovery result identifies the selected backup")
	t.assert_true(Save.save(path, first).ok, "Saving after primary corruption repairs the main file")
	var backup: State = State.new()
	t.assert_true(Save.load_into(path + ".bak", backup).ok, "Repair keeps the good backup readable")
	t.assert_eq(JSON.stringify(backup.serialize()), first_snapshot, "Corrupt primary does not overwrite the good backup")
	t.assert_true(Save.load_into(path, restored).ok, "Repaired main save loads")
	t.assert_eq(JSON.stringify(restored.serialize()), newest_snapshot, "Repaired main save holds the newest intended state")
	_write_test_file(path + ".tmp", newest_snapshot)
	DirAccess.remove_absolute(path)
	t.assert_true(Save.has_save(path), "Recovery files count as an existing save even if main is missing")
	outcome = Save.load_into(path, restored)
	t.assert_true(outcome.ok and outcome.recovered, "Interrupted publish recovers the complete temporary save")
	t.assert_eq(outcome.source, path + ".tmp", "Missing main selects complete newest temporary before old backup")
	t.assert_eq(JSON.stringify(restored.serialize()), newest_snapshot, "Temporary recovery preserves current money and material reservations")
	_write_test_file(path + ".tmp", "{ truncated")
	outcome = Save.load_into(path, restored)
	t.assert_true(outcome.ok and outcome.recovered, "Truncated temporary falls back to valid backup")
	t.assert_eq(JSON.stringify(restored.serialize()), first_snapshot, "Truncated temporary never partially replaces live state")
	_write_test_file(path, first_snapshot)
	_write_test_file(path + ".tmp", newest_snapshot)
	outcome = Save.load_into(path, restored)
	t.assert_true(outcome.ok and not outcome.recovered, "Valid primary wins over leftover temporary files")
	t.assert_eq(JSON.stringify(restored.serialize()), first_snapshot, "Unpublished temporary does not replay a newer transaction over a valid main save")
	var before: String = JSON.stringify(restored.serialize())
	for suffix: String in ["", ".tmp", ".bak"]:
		_write_test_file(path + suffix, "{ broken")
	t.assert_false(Save.load_into(path, restored).ok, "All malformed recovery candidates are rejected")
	t.assert_eq(JSON.stringify(restored.serialize()), before, "Failed recovery keeps the complete current live model")
	for suffix: String in ["", ".tmp", ".bak", ".invalid"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	t.assert_false(Save.has_save(path), "Test recovery files are cleaned up")

static func _write_test_file(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

static func _finish_first_house(state: State) -> void:
	for x: float in [240.0, 360.0, 480.0, 600.0]:
		state.document.add_part("lintel", Vector2(x, 430))
	state.document.add_part("roof_flat_wide" if state.contract_grading_version >= 5 else "roof_wide", Vector2(420, 400 if state.contract_grading_version >= 5 else 370))

static func _test_roof_coverage_and_legacy_records(t: Node) -> void:
	var model: Document = Document.new()
	model.add_part("door", Vector2(500, 500))
	model.add_part("roof", Vector2(420, 390))
	t.assert_false(State._openings_have_roofs(model.parts), "A roof covering only the door center leaves an exposed edge and fails")
	model.delete_selected()
	model.add_part("roof", Vector2(400, 390))
	model.add_part("roof", Vector2(600, 390))
	t.assert_true(State._openings_have_roofs(model.parts), "Two adjacent roof spans can jointly cover one whole doorway")
	model.move_selected(Vector2(620, 390))
	t.assert_false(State._openings_have_roofs(model.parts), "A real gap between two roofs does not count as continuous shelter")
	var old: State = State.new()
	old.accept_contract()
	old.build_starter()
	old.document.add_part("lintel", Vector2(340, 430))
	old.document.add_part("lintel", Vector2(500, 430))
	old.document.add_part("brick", Vector2(420, 430))
	old.document.add_part("roof", Vector2(420, 390))
	var report: Dictionary = _stable_report(old.document)
	t.assert_false(old.evaluate(report).can_submit, "New live grading requires coverage of the full window and door widths")
	var offer: Dictionary = Catalog.contract(0, 1)
	var legacy_evaluation: Dictionary = State._evaluate(old.document, offer, report, true, 1)
	t.assert_true(legacy_evaluation.can_submit, "Fixture accurately represents the previously valid center-coverage rule")
	var record: Dictionary = {"index": 0, "id": offer.id, "client": offer.client, "title": offer.title, "total": offer.total, "advance": offer.advance, "base_cost": offer.base_cost, "material_cost": old.material_cost(), "score": legacy_evaluation.score, "bonus": legacy_evaluation.bonus, "final_payment": int(offer.total) - int(offer.advance) + int(legacy_evaluation.bonus), "profit": legacy_evaluation.profit, "document": old.document.serialize()}
	var legacy: Dictionary = {"version": 1, "balance": State.INITIAL_BALANCE + int(record.profit), "contract_index": 0, "phase": "settled", "records": [record], "document": old.document.serialize()}
	legacy = JSON.parse_string(JSON.stringify(legacy))
	var restored: State = State.new()
	t.assert_true(restored.restore(legacy), "Earlier completed v1 house remains loadable without retroactive grading loss")
	t.assert_eq(restored.balance, int(legacy.balance), "Legacy migration preserves exactly the already-paid money")
	t.assert_true(restored.next_contract(), "Legacy completion can continue to another client")
	var bad: Dictionary = legacy.duplicate(true)
	bad.records[0].grading_version = 2
	t.assert_false(State.new().restore(bad), "A record claiming new grading must actually cover full aperture widths")
	bad.records[0].grading_version = "two"
	t.assert_false(State.new().restore(bad), "Invalid grading metadata is rejected without coercion")

static func _stable_report(model: Document) -> Dictionary:
	var ids: Array[int] = []
	for item: Dictionary in model.parts: ids.append(int(item.id))
	return {"stable": true, "stable_ids": ids, "unsupported_ids": [], "message": "검사 통과", "revision": model.revision}

static func _test_length_conditions(t: Node) -> void:
	t.assert_gt(Catalog.materials().size(), 17, "Length learning retains the original eighteen material choices when the catalog expands")
	var dimensions_by_family: Dictionary = {}
	for material: Dictionary in Catalog.materials():
		var family: String = str(material.kind)
		if not dimensions_by_family.has(family): dimensions_by_family[family] = []
		if not dimensions_by_family[family].has(material.dimensions): dimensions_by_family[family].append(material.dimensions)
	for family: String in Math.KINDS:
		t.assert_true(dimensions_by_family[family].size() >= 2, "Every selectable quadrilateral family has more than one size: " + family)
	t.assert_eq(Catalog.dimensions_label("window_small"), "가로 3칸 · 세로 3칸", "Material measurements use logical grid units")
	t.assert_eq(Catalog.edge_lengths_label("ornament_large"), "변 길이 3 · 3 · 3 · 3칸", "Rhombus side lengths come from its actual vertices, not its diagonal bounds")
	t.assert_true(Catalog.edge_lengths_label("ornament").contains("약"), "Rounded irrational side lengths are explicitly identified as approximate")
	t.assert_eq(Catalog.format_length(10.0), "10", "Whole grid lengths retain trailing integral zeroes")
	var state: State = State.new()
	state.accept_contract()
	state.document.add_part("ornament_large", Vector2(300, 300))
	var requirement: Dictionary = Catalog._length_need("한 변 3칸", "decor", "rhombus", 3.0, 3.0)
	t.assert_eq(State._requirement_count(state.document.parts, state.counts(), requirement), 1, "An equal-sided rhombus matches its measured edge-length requirement")
	state.document.rotate_selected(37.0)
	t.assert_eq(State._requirement_count(state.document.parts, state.counts(), requirement), 1, "Rotating a rhombus never changes its edge-length condition")
	state.document.delete_selected()
	state.document.add_part("ornament", Vector2(300, 300))
	t.assert_eq(State._requirement_count(state.document.parts, state.counts(), requirement), 0, "A smaller rhombus cannot pass by sharing only the shape family")
	state.document.add_part("window_small", Vector2(600, 300))
	var square_need: Dictionary = Catalog._length_need("한 변 3칸", "window", "square", 3.0, 3.0)
	t.assert_eq(State._requirement_count(state.document.parts, state.counts(), square_need), 1, "A small square window matches three grid units")
	state.document.add_part("window", Vector2(800, 300))
	t.assert_eq(State._requirement_count(state.document.parts, state.counts(), square_need), 1, "The larger square is not incorrectly counted as a three-unit window")
	var variety: Dictionary = Catalog._need("서로 다른 길이", "length_variety", "", 3, false)
	t.assert_eq(State._requirement_count(state.document.parts, state.counts(), variety), 3, "Distinct-length requests count measured lengths rather than part count")
	state.document.select(int(state.document.parts.back().id))
	state.document.duplicate_selected()
	t.assert_eq(State._requirement_count(state.document.parts, state.counts(), variety), 3, "Duplicating the same size never increases the length variety")
	for index: int in range(6):
		var has_length: bool = false
		for need: Dictionary in Catalog.contract(index).requirements:
			if str(need.category) == "edge_lengths": has_length = true
		t.assert_true(has_length, "Every authored commission includes a readable shape-and-length preference")
	var legacy_draft: Dictionary = state.serialize()
	legacy_draft.erase("contract_grading_version")
	var restored: State = State.new()
	t.assert_true(restored.restore(JSON.parse_string(JSON.stringify(legacy_draft))), "A pre-length-conditions construction draft remains loadable")
	t.assert_eq(restored.contract_grading_version, 2, "An older accepted commission retains its original contract conditions")
	t.assert_eq(restored.current_contract().requirements.size(), Catalog.contract(0, 2).requirements.size(), "Restoring a draft does not retroactively add preferences")
	var legacy_complete: State = State.new()
	legacy_complete.accept_contract()
	legacy_complete.contract_grading_version = 2
	legacy_complete.build_starter()
	_finish_first_house(legacy_complete)
	var paid: Dictionary = legacy_complete.settle(_stable_report(legacy_complete.document))
	t.assert_eq(paid.grading_version, 2, "A previously accepted commission settles under its original rules")
	var old_save: Dictionary = legacy_complete.serialize()
	old_save.erase("contract_grading_version")
	var migrated: State = State.new()
	t.assert_true(migrated.restore(JSON.parse_string(JSON.stringify(old_save))), "Already-paid v2 houses keep their exact score and money")
	t.assert_eq(migrated.balance, legacy_complete.balance, "Length-rule migration never recalculates old income")
	t.assert_true(migrated.next_contract(), "Legacy completion progresses to a new commission")
	t.assert_eq(migrated.contract_grading_version, State.GRADING_VERSION, "The next new client introduces current facade conditions")
	var old_briefing: Dictionary = State.new().serialize()
	old_briefing.erase("contract_grading_version")
	var waiting: State = State.new()
	t.assert_true(waiting.restore(old_briefing), "An older not-yet-accepted commission remains loadable")
	t.assert_eq(waiting.contract_grading_version, State.GRADING_VERSION, "An older briefing immediately uses current facade conditions")
	t.assert_eq(waiting.current_contract().requirements.size(), Catalog.contract(0).requirements.size(), "The client states current stage conditions before acceptance")
	old_briefing.contract_grading_version = 2
	t.assert_true(waiting.restore(old_briefing), "A briefing with older explicit grading can be upgraded safely")
	t.assert_eq(waiting.contract_grading_version, State.GRADING_VERSION, "An unaccepted old rule version never freezes future client conditions")
	t.assert_true(waiting.accept_contract(), "The upgraded brief can be accepted normally")
	t.assert_eq(waiting.contract_grading_version, State.GRADING_VERSION, "Acceptance commits the current contract rules")
	var bad: Dictionary = migrated.serialize()
	bad.contract_grading_version = State.GRADING_VERSION + 1
	var before: Dictionary = migrated.serialize()
	t.assert_false(migrated.restore(bad), "Unknown future grading metadata is rejected")
	t.assert_eq(migrated.serialize(), before, "A malformed grading version leaves live geometry and ledger intact")
