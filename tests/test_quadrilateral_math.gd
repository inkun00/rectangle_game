class_name TestQuadrilateralMath
extends RefCounted

const Math = preload("res://scripts/core/quadrilateral_math.gd")
const Templates = preload("res://scripts/core/character_templates.gd")

static func run(t) -> void:
	for kind: String in Math.KINDS:
		var vertices: PackedVector2Array = Math.create_vertices(kind, Vector2(92, 68))
		t.assert_eq(vertices.size(), 4, "Every available shape has exactly four authoritative vertices")
		t.assert_true(Math.matches_kind(vertices, kind), "Constructed shape belongs to its selected family: " + kind)
		for angle: int in range(0, 360, 15):
			var transformed: PackedVector2Array = Math.scale_vertices(Math.rotate_vertices(vertices, float(angle)), 0.63)
			t.assert_true(Math.is_valid(transformed), "Rotation and uniform scaling preserve convexity")
			t.assert_true(Math.matches_kind(transformed, kind), "Allowed edits preserve chosen family")
			var sum: float = 0.0
			for interior: float in Math.angles(transformed):
				sum += interior
			t.assert_float_approx(sum, 360.0, 0.01, "Four interior angles total 360 degrees")
			var display_sum: int = 0
			for rounded: int in Math.display_angles(transformed):
				display_sum += rounded
			t.assert_eq(display_sum, 360, "Rounded angles total exactly 360")
	var square: PackedVector2Array = Math.create_vertices("square")
	t.assert_eq(Math.classifications(square).size(), 5, "Square belongs to all five inclusive quadrilateral classes")
	var rectangle: PackedVector2Array = Math.create_vertices("rectangle", Vector2(100, 60))
	t.assert_true(Math.matches_kind(rectangle, "trapezoid"), "Rectangle is an inclusive trapezoid")
	t.assert_false(Math.matches_kind(rectangle, "rhombus"), "Unequal rectangle sides do not form rhombus")
	var trapezoid: PackedVector2Array = Math.create_vertices("trapezoid")
	t.assert_eq(Math.parallel_pair_count(trapezoid), 1, "Distinctive default trapezoid has one parallel pair")
	_test_right_trapezoids(t)
	t.assert_false(Math.is_valid(PackedVector2Array([Vector2.ZERO, Vector2(30, 0), Vector2(60, 0), Vector2(90, 0)])), "Collinear quadrilateral rejected")
	t.assert_false(Math.is_valid(PackedVector2Array([Vector2.ZERO, Vector2(80, 80), Vector2(0, 80), Vector2(80, 0)])), "Crossed bow-tie rejected")
	t.assert_false(Math.is_valid(PackedVector2Array([Vector2.ZERO, Vector2(80, 0), Vector2(20, 20), Vector2(0, 80)])), "Concave quadrilateral rejected")
	t.assert_false(Math.is_valid(PackedVector2Array([Vector2.ZERO, Vector2(80, 0), Vector2(0, 80)])), "Triangle rejected")
	t.assert_false(Math.is_valid(PackedVector2Array([Vector2(NAN, 0), Vector2(80, 0), Vector2(80, 80), Vector2(0, 80)])), "Nonfinite vertex rejected")
	t.assert_true(Math.contains_point(square, Vector2.ZERO), "Point at center hits square")
	t.assert_false(Math.contains_point(square, Vector2(100, 100)), "Outside point misses square")
	for template: Dictionary in Templates.all_templates():
		t.assert_true(template.parts.size() >= 8, "Template has articulated parts")
		var identifiers: Dictionary = {}
		for slot: Dictionary in template.parts:
			t.assert_false(identifiers.has(slot.id), "Template slot IDs are unique")
			identifiers[slot.id] = true
			t.assert_true(Math.matches_kind(slot.vertices, str(slot.kind)), "Every template slot obeys its advertised geometry")

static func _test_right_trapezoids(t: Node) -> void:
	for variant: String in ["right_left", "right_right"]:
		var vertices: PackedVector2Array = Math.create_vertices("trapezoid", Vector2(160, 90), variant)
		t.assert_eq(Math.bounds(vertices), Rect2(-80, -45, 160, 90), "Both right trapezoids use the requested drawing bounds")
		var first_corner: int = 0 if variant == "right_left" else 1
		var second_corner: int = 3 if variant == "right_left" else 2
		for turn: int in range(0, 360, 15):
			var transformed: PackedVector2Array = Math.rotate_vertices(Math.scale_vertices(vertices, 0.63), float(turn))
			t.assert_eq(transformed.size(), 4, "Right trapezoids keep four ordered vertices")
			t.assert_true(Math.is_valid(transformed), "Right trapezoids remain finite, convex and nondegenerate under editing")
			t.assert_eq(Math.parallel_pair_count(transformed), 1, "Right trapezoids have exactly one parallel pair after rotation")
			t.assert_eq(Math.classifications(transformed), ["trapezoid"], "Two right angles do not classify a right trapezoid as a rectangle")
			t.assert_eq(Math.trapezoid_variant(transformed), variant, "Subtype is derived from vertices after rotation and scaling")
			var interior: PackedFloat32Array = Math.angles_degrees(transformed)
			var sum: float = 0.0
			var right_count: int = 0
			for index: int in range(4):
				sum += interior[index]
				if absf(interior[index] - 90.0) <= 0.1: right_count += 1
				if index == first_corner or index == second_corner:
					t.assert_float_approx(interior[index], 90.0, 0.01, "Both corners of the chosen leg stay perpendicular")
			t.assert_eq(right_count, 2, "A right trapezoid keeps exactly two right angles")
			t.assert_float_approx(sum, 360.0, 0.01, "Right trapezoid interior angles sum to 360 degrees")
			t.assert_true(Math.property_summary(transformed).contains("직각 2개"), "Measurements report both right angles")
	for invalid: String in ["unknown", ""]:
		t.assert_true(Math.create_vertices("trapezoid", Vector2(160, 90), invalid).is_empty(), "Unknown creation subtype cannot produce mislabeled geometry")
	t.assert_true(Math.create_vertices("trapezoid", Vector2(INF, 90), "right_left").is_empty(), "Nonfinite right trapezoid dimensions are rejected")
