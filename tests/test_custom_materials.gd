class_name TestCustomMaterials
extends RefCounted

const Custom = preload("res://scripts/construction/custom_material_catalog.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const State = preload("res://scripts/construction/construction_state.gd")
const Document = preload("res://scripts/construction/construction_document.gd")
const Guide = preload("res://scripts/construction/construction_guide.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")

static func run(t: Node) -> void:
	_test_recipe_validation(t)
	_test_geometry_and_quote(t)
	_test_registration(t)
	_test_persistence_and_atomicity(t)
	_test_contracts_and_history(t)

static func _test_recipe_validation(t: Node) -> void:
	var id: String = Custom.make_id("rectangle", Vector2(120, 20), "wood", "plain", "beam")
	t.assert_eq(id, "custom_v1:rectangle:120:20:wood:plain:beam:symmetric", "A recipe has one stable canonical identity without stored prices")
	t.assert_eq(Custom.make_id("rectangle", Vector2(120, 20), "wood", "plain", "beam"), id, "Repeating the same choices produces exactly the same ID")
	for invalid: String in [
		id.replace("custom_v1", "custom_v2"), id.replace(":120:", ":0120:"), id.replace(":120:", ":120.0:"),
		id.replace(":120:", ":1e2:"), id.replace(":120:", ":-120:"), id.replace(":120:", ":121:"),
		id.replace(":120:", ":610:"), id.replace(":20:", ":410:"), id.replace(":20:", ":0:"),
		id.replace(":wood:", ":glass:"), id.replace(":plain:", ":unknown:"), id.replace(":beam:", ":window:"),
		id.replace("symmetric", "right_left"), id + ":100", "custom_v1:rectangle", "custom_" + "x".repeat(200)
	]:
		t.assert_true(Custom.material(invalid).is_empty(), "Malformed or noncanonical custom recipe is rejected: " + invalid.left(70))
		t.assert_true(Custom.quote(invalid).is_empty(), "Malformed recipe cannot have a usable price")
	t.assert_eq(Custom.make_id("square", Vector2(100, 80), "wood", "plain", "wall"), "", "A square recipe cannot disguise unequal width and height")
	t.assert_eq(Custom.make_id("rectangle", Vector2(INF, 80), "wood", "plain", "wall"), "", "Nonfinite dimensions cannot enter an identity")
	t.assert_eq(Custom.make_id("triangle", Vector2(100, 80), "wood", "plain", "wall"), "", "Custom material creation preserves the five-family limit")
	t.assert_eq(Custom.make_id("rectangle", Vector2(105, 80), "wood", "plain", "wall"), "", "Dimensions use exact half-grid increments")
	t.assert_true(Catalog.material("custom_v2:rectangle:100:80:wood:plain:wall:symmetric").is_empty(), "The main catalog does not reinterpret an unknown pricing version")

static func _test_geometry_and_quote(t: Node) -> void:
	for kind: String in Math.KINDS:
		for surface: String in Custom.SURFACE_IDS:
			var dimensions: Vector2 = Vector2(100, 100) if kind == "square" else Vector2(120, 80)
			var id: String = Custom.make_id(kind, dimensions, surface, "checks", "wall")
			var item: Dictionary = Catalog.material(id)
			var vertices: PackedVector2Array = Catalog.material_vertices(id)
			t.assert_true(Math.matches_kind(vertices, kind), "A custom %s %s retains its declared family" % [surface, kind])
			t.assert_eq(vertices.size(), 4, "Custom geometry has four authoritative finite vertices")
			var angle_sum: float = 0.0
			for angle: float in Math.angles_degrees(vertices): angle_sum += angle
			t.assert_float_approx(angle_sum, 360.0, 0.01, "Every custom polygon is a valid convex quadrilateral")
			t.assert_true(bool(item.custom) and bool(item.structural) and not bool(item.opening), "A custom wall has explicit structural metadata")
			t.assert_eq(int(item.brick_count), 0, "A custom brick surface is not a counted brick bundle")
			t.assert_eq(item.surface_id, surface, "The surface choice survives deterministic decoding")
			t.assert_eq(item.pattern_id, "checks", "The pattern choice survives deterministic decoding")
			t.assert_eq(int(item.price) % 100, 0, "Custom unit prices use integer hundreds of won")
			t.assert_gt(float(item.mass), 0.0, "Every surface has a positive derived mass")
			var quote: Dictionary = Custom.quote(id)
			t.assert_float_approx(float(quote.area_cells), absf(Math.signed_area(vertices)) / 400.0, 0.0001, "Pricing uses actual polygon area rather than bounding-box area")
			t.assert_eq(int(quote.total), int(item.price), "The displayed quote equals the material cost charged by the document")
			t.assert_eq(int(quote.total), int(quote.base_cost) + int(quote.shape_fee) + int(quote.pattern_fee) + int(quote.role_fee), "The shown price breakdown reconciles exactly")
	var beam_id: String = Custom.make_id("rectangle", Vector2(120, 20), "wood", "plain", "beam")
	var beam_quote: Dictionary = Custom.quote(beam_id)
	t.assert_eq(int(beam_quote.base_cost), 13200, "Six grid-square units of wood at 2,200 won cost 13,200 won")
	t.assert_eq(int(beam_quote.role_fee), 700, "Beam processing rounds its five-percent surcharge to one hundred won")
	t.assert_eq(int(beam_quote.total), 13900, "A known beam recipe has a reproducible complete unit price")
	var decorated: String = Custom.make_id("rectangle", Vector2(120, 20), "wood", "bands", "beam")
	t.assert_eq(int(Custom.quote(decorated).total), 14600, "A visible pattern adds its disclosed per-piece processing cost")
	var larger: String = Custom.make_id("rectangle", Vector2(240, 20), "wood", "plain", "beam")
	t.assert_gt(int(Custom.material(larger).price), int(Custom.material(beam_id).price), "Larger real geometry costs more than the otherwise identical recipe")
	for variant: String in ["right_left", "right_right"]:
		var id: String = Custom.make_id("trapezoid", Vector2(200, 60), "metal", "diamond", "roof", variant)
		var vertices: PackedVector2Array = Catalog.material_vertices(id)
		t.assert_eq(Math.trapezoid_variant(vertices), variant, "Both right-trapezoid recipes preserve their two right angles")
		var document: Document = Document.new()
		t.assert_gt(document.add_part(id, Vector2(500, 280)), 0, "A stateless recipe is available to temporary document and record validators")
		t.assert_true(document.rotate_selected(37.0), "Custom asymmetric geometry follows the existing rotation command")
		var restored: Document = Document.new()
		t.assert_true(restored.restore(_json(document.serialize())), "Rotated custom geometry survives validated document restoration")
		t.assert_eq(restored.material_cost(), document.material_cost(), "Rotation and restoration preserve the recipe price")

static func _test_registration(t: Node) -> void:
	var state: State = State.new()
	var id: String = Custom.make_id("rectangle", Vector2(120, 20), "wood", "plain", "beam")
	var changes: Array[int] = [0]
	state.changed.connect(func(): changes[0] += 1)
	t.assert_true(state.register_custom_material(id), "A validated material can be registered without opening a contract")
	t.assert_eq(state.balance, State.INITIAL_BALANCE, "Registration does not charge an extra setup fee")
	t.assert_eq(state.saved_balance(), State.INITIAL_BALANCE, "Registering a recipe preserves progression assets")
	t.assert_eq(changes[0], 1, "A new registration emits one coherent state update")
	t.assert_true(state.register_custom_material(id), "Repeated registration is idempotent")
	t.assert_eq(changes[0], 1, "An existing recipe neither duplicates nor emits a spurious change")
	t.assert_eq(state.custom_material_ids.size(), 1, "Identical choices appear once in the reusable library")
	t.assert_eq(state.available_materials().size(), Catalog.materials().size() + 1, "The state library combines original choices and registered recipes")
	t.assert_eq(State.new().available_materials().size(), Catalog.materials().size(), "Registration is isolated to its state rather than a mutable global catalog")
	var before: Dictionary = state.serialize()
	t.assert_false(state.register_custom_material("brick"), "A built-in ID cannot be forged into the custom library")
	t.assert_eq(state.serialize(), before, "Rejected registration preserves geometry, library and balance")
	var capacity: State = State.new()
	for index: int in range(Custom.MAX_REGISTERED):
		var dimensions: Vector2 = Vector2(10 + (index % 32) * 10, 20 if index >= 32 else 10)
		var unique_id: String = Custom.make_id("rectangle", dimensions, "wood", "plain", "wall")
		t.assert_true(capacity.register_custom_material(unique_id), "A bounded library accepts unique valid recipes")
	t.assert_true(capacity.register_custom_material(capacity.custom_material_ids[0]), "An already-registered recipe remains usable when the library is full")
	t.assert_false(capacity.register_custom_material(Custom.make_id("rectangle", Vector2(600, 400), "metal", "diamond", "decor")), "The sixty-fifth distinct recipe is rejected without growing the save")
	t.assert_eq(capacity.custom_material_ids.size(), Custom.MAX_REGISTERED, "The reusable library keeps its hard capacity")

static func _test_persistence_and_atomicity(t: Node) -> void:
	var state: State = State.new()
	var id: String = Custom.make_id("trapezoid", Vector2(200, 60), "stone", "bands", "roof", "right_left")
	state.register_custom_material(id)
	var empty_library_save: Dictionary = _json(state.serialize())
	var no_parts: State = State.new()
	t.assert_true(no_parts.restore(empty_library_save), "A registered recipe persists even before its first placement")
	t.assert_eq(no_parts.custom_material_ids, state.custom_material_ids, "Reloading restores reusable recipes in their original order")
	state.set_my_house_mode(true)
	t.assert_gt(state.my_house_document.add_part(id, Vector2(500, 280)), 0, "Registered recipes can be used in a personal house")
	t.assert_eq(state.my_house_cost(), int(Custom.material(id).price), "Personal-house reserves use the quoted per-piece price")
	t.assert_eq(state.my_house_available_balance(), State.INITIAL_BALANCE - state.my_house_cost(), "Only placed material cost reduces the personal-house funds")
	var restored: State = State.new()
	t.assert_true(restored.restore(_json(state.serialize())), "The personal house and custom library restore together")
	var before: Dictionary = restored.serialize()
	var bad: Dictionary = _json(state.serialize())
	bad.erase("custom_materials")
	t.assert_false(restored.restore(bad), "A house cannot reference an unregistered custom recipe")
	t.assert_eq(restored.serialize(), before, "Missing registration does not partly replace the live library or house")
	for invalid_registry: Variant in ["not an array", [id, id], ["brick"], [id, 12], [id.replace("custom_v1", "custom_v2")]]:
		bad = _json(state.serialize())
		bad.custom_materials = invalid_registry
		t.assert_false(restored.restore(bad), "Invalid registry shapes, duplicates and unknown recipes are rejected")
		t.assert_eq(restored.serialize(), before, "Every malformed registry leaves all live state intact")
	bad = _json(state.serialize())
	bad.balance += 100
	t.assert_false(restored.restore(bad), "Custom registration does not weaken exact ledger reconciliation")
	t.assert_eq(restored.serialize(), before, "A forged balance preserves the existing custom house and library")
	var legacy: State = State.new()
	t.assert_true(restored.restore(_json(legacy.serialize())), "An earlier save without a custom library still restores normally")
	t.assert_true(restored.custom_material_ids.is_empty(), "Loading an old save cannot inherit recipes from a previous live state")

static func _test_contracts_and_history(t: Node) -> void:
	var expensive_id: String = Custom.make_id("rectangle", Vector2(600, 400), "metal", "diamond", "decor")
	var state: State = State.new()
	state.register_custom_material(expensive_id)
	state.accept_contract()
	var before: Dictionary = state.document.serialize()
	t.assert_eq(state.document.add_part(expensive_id, Vector2(500, 280)), -1, "Custom unit cost obeys the client's material budget")
	t.assert_eq(state.document.serialize(), before, "An unaffordable custom placement changes neither design nor reservations")
	state.set_my_house_mode(true)
	t.assert_gt(state.my_house_document.add_part(expensive_id, Vector2(500, 280)), 0, "Personal-house funding uses earned assets rather than the client's lower material budget")
	var id: String = Custom.make_id("rectangle", Vector2(40, 20), "wood", "bands", "decor")
	var completed: State = State.new()
	completed.register_custom_material(id)
	completed.accept_contract()
	completed.document.replace_parts(Guide.plan())
	t.assert_gt(completed.document.add_part(id, Vector2(240, 480)), 0, "A custom finish can be attached to an existing real wall")
	var evaluation: Dictionary = completed.evaluate(_stable_report(completed.document))
	t.assert_true(evaluation.can_submit, "A registered recipe participates in ordinary contract evaluation")
	var record: Dictionary = completed.settle(_stable_report(completed.document))
	t.assert_false(record.is_empty(), "The existing settlement ledger accepts a completed house with custom material")
	t.assert_eq(int(record.material_cost), completed.document.material_cost(), "The paid record contains the exact quoted custom material charge")
	t.assert_eq(completed.balance, State.INITIAL_BALANCE + int(record.profit), "Registration adds no hidden transaction to completed profit")
	var restored: State = State.new()
	t.assert_true(restored.restore(_json(completed.serialize())), "A completed custom house restores with its exact score and earned balance")
	t.assert_eq(restored.balance, completed.balance, "Historical custom prices remain deterministic across loading")
	completed.next_contract()
	t.assert_true(completed.document.parts.is_empty(), "The next commission has no current custom part")
	t.assert_true(restored.restore(_json(completed.serialize())), "A recipe used only in an earlier completed record remains reusable")
	var saved: Dictionary = restored.serialize()
	var missing: Dictionary = _json(completed.serialize())
	missing.erase("custom_materials")
	t.assert_false(restored.restore(missing), "Archived houses also require every custom recipe to be registered")
	t.assert_eq(restored.serialize(), saved, "A missing archived recipe preserves the complete current ledger")
	var unregistered: State = State.new()
	unregistered.accept_contract()
	unregistered.document.replace_parts(Guide.plan())
	unregistered.document.add_part(id, Vector2(240, 480))
	t.assert_false(unregistered.evaluate(_stable_report(unregistered.document)).can_submit, "Direct document calls cannot settle an unregistered custom material")
	t.assert_true(unregistered.settle(_stable_report(unregistered.document)).is_empty(), "Unregistered recipes cannot create an unrestorable paid record")

static func _stable_report(document: Document) -> Dictionary:
	var ids: Array[int] = []
	for part: Dictionary in document.parts: ids.append(int(part.id))
	return {"stable": true, "stable_ids": ids, "unsupported_ids": [], "revision": document.revision, "message": "검사 통과"}

static func _json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))
