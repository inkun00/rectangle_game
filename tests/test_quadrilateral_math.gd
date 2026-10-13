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
