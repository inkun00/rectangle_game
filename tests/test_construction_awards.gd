class_name TestConstructionAwards
extends RefCounted

const Awards = preload("res://scripts/construction/construction_awards.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Document = preload("res://scripts/construction/construction_document.gd")
const Guide = preload("res://scripts/construction/construction_guide.gd")

static func run(t: Node) -> void:
	_test_five_tiers(t)
	_test_geometry_and_gating(t)
	_test_saved_metadata(t)

static func _test_five_tiers(t: Node) -> void:
	t.assert_eq(Awards.tier_for_score(59), 0, "A design below sixty points earns no badge")
	var names: Array[String] = []
	for tier: int in range(1, 6):
		var threshold: int = Awards.THRESHOLDS[tier - 1]
		t.assert_eq(Awards.tier_for_score(threshold), tier, "Each of five excellence thresholds has its own award tier")
		t.assert_eq(Awards.tier_for_score(threshold - 1), tier - 1, "A badge cannot be earned before its published threshold")
		var title: String = Awards.title_for_tier(tier)
		t.assert_false(title.is_empty() or names.has(title), "All five badges have distinct readable titles")
		names.append(title)
		t.assert_true(ResourceLoader.exists(Awards.badge_path(tier)), "Every award tier has a packaged generated badge")
	t.assert_eq(Awards.tier_for_score(100), 5, "A complete one-hundred-point rubric earns the highest award")
	t.assert_eq(Awards.badge_path(0), "", "An unawarded house has no badge asset")

static func _model() -> Document:
	var document: Document = Document.new()
	document.replace_parts(Guide.example_for_contract(Catalog.contract(8, 5)))
	return document

## A closed two-course elevation with a centered flat roof and square end caps.
## This is also a reproducible fixture for the generated fifth badge's PNG QA.
static func excellent_document() -> Document:
	var items: Array[Dictionary] = []
	for item: Dictionary in Guide.example_for_contract(Catalog.contract(8, 5)):
		if str(Catalog.material(str(item.material_id)).role) != "roof":
			items.append(item.duplicate(true))
	for x: int in range(220, 800, 40):
		for y: int in [370, 390, 410]:
			items.append({"material_id": "brick", "position": Vector2(x, y)})
	for x: int in range(260, 800, 120):
		items.append({"material_id": "lintel", "position": Vector2(x, 350)})
	items.append({"material_id": "roof_flat_wide", "position": Vector2(500, 320)})
	items.append({"material_id": "roof_square", "position": Vector2(200, 300)})
	items.append({"material_id": "roof_square", "position": Vector2(800, 300)})
	var document: Document = Document.new()
	document.replace_parts(items)
	return document

static func _test_geometry_and_gating(t: Node) -> void:
	var document: Document = _model()
	t.assert_gt(document.parts.size(), 0, "A real high-stage house supplies the award geometry")
	var offer: Dictionary = Catalog.contract(8, 5)
	var award: Dictionary = Awards.assess(document.parts, {"can_submit": true}, offer)
	t.assert_true(award.eligible, "A closed inspected high-stage facade can enter the design rubric")
	t.assert_gt(int(award.tier), 0, "A high-quality high-stage example earns a real badge")
	var total: int = 0
	for row: Dictionary in award.breakdown:
		total += int(row.score)
		t.assert_eq(int(row.maximum), 20, "Every published design criterion has the same twenty-point maximum")
		t.assert_false(str(row.detail).is_empty(), "Every score explains its actual geometric measurements")
	t.assert_eq(total, int(award.score), "Five transparent criterion scores add up to the award score")
	t.assert_true(Awards.is_awarded(award), "Validated earned metadata enables its export badge")
	t.assert_eq(Awards.assess(document.parts, {"can_submit": false}, offer).tier, 0, "A failed or stale inspection can never earn a badge")
	var early: Dictionary = offer.duplicate(true)
	early.stage = 2
	t.assert_eq(Awards.assess(document.parts, {"can_submit": true}, early).tier, 0, "Stages one and two never enter the hall of fame")
	t.assert_eq(Awards.assess([], {"can_submit": true}, offer).tier, 0, "An empty design can never earn an award")
	var duplicate: Array[Dictionary] = document.parts.duplicate(true)
	duplicate.append(duplicate[0].duplicate(true))
	t.assert_eq(Awards.assess(duplicate, {"can_submit": true}, offer).tier, 0, "Stacking an exact duplicate cannot farm design awards")
	var changed_offer: Dictionary = offer.duplicate(true)
	changed_offer.requirements = []
	t.assert_eq(Awards.assess(document.parts, {"can_submit": true}, changed_offer), award, "The design rubric never divides by optional or required family counts")
	var excellent: Document = excellent_document()
	t.assert_gt(excellent.parts.size(), 0, "The highest badge fixture uses valid catalog parts")
	var highest: Dictionary = Awards.assess(excellent.parts, {"can_submit": true}, offer)
	t.assert_eq(highest.score, 100, "Actual balanced quadrilateral geometry can attain every published design criterion")
	t.assert_eq(highest.tier, 5, "The fifth tier is attainable with a real closed house and a flat roof")
	excellent.add_part("ornament", Vector2(500, 390))
	t.assert_eq(Awards.assess(excellent.parts, {"can_submit": true}, offer), highest, "Repeating an existing decoration family and surface cannot farm extra points")

static func _test_saved_metadata(t: Node) -> void:
	var document: Document = _model()
	var offer: Dictionary = Catalog.contract(8, 5)
	var evaluation: Dictionary = {"can_submit": true}
	var award: Dictionary = Awards.assess(document.parts, evaluation, offer)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(award))
	t.assert_true(Awards.matches(saved, document.parts, evaluation, offer), "Saved awards survive JSON float-number restoration")
	saved.score = float(saved.score) + 0.5
	t.assert_false(Awards.matches(saved, document.parts, evaluation, offer), "Fractional tampered award scores are rejected")
	saved = JSON.parse_string(JSON.stringify(award))
	saved.tier = 0
	t.assert_false(Awards.matches(saved, document.parts, evaluation, offer), "A changed saved badge tier cannot bypass recomputation")
	saved = JSON.parse_string(JSON.stringify(award))
	saved.breakdown[0].score = 0
	t.assert_false(Awards.matches(saved, document.parts, evaluation, offer), "Changed saved rubric rows are rejected")
	saved = JSON.parse_string(JSON.stringify(award))
	saved.extra_reward = 100000000
	t.assert_false(Awards.matches(saved, document.parts, evaluation, offer), "Unknown award fields are not accepted in the ledger")
	saved = JSON.parse_string(JSON.stringify(award))
	saved.eligible = 1
	t.assert_false(Awards.matches(saved, document.parts, evaluation, offer), "Award eligibility must restore as a boolean")
	t.assert_false(Awards.is_awarded({}), "Drafts and older unawarded records export without a badge")
