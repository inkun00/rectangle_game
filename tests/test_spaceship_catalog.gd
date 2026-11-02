class_name TestSpaceshipCatalog
extends RefCounted

const Catalog: GDScript = preload("res://scripts/economy/spaceship_catalog.gd")
const Math: GDScript = preload("res://scripts/core/quadrilateral_math.gd")

static func run(t: Node) -> void:
	var parts: Array[Dictionary] = Catalog.all_parts()
	t.assert_eq(parts.size(), 12, "The homecoming ship has twelve individually purchasable components")
	t.assert_eq(Catalog.total_price(), 1200000000, "The ship requires 1.2 billion won of earned progress")
	var ids: Dictionary = {}
	var families: Dictionary = {}
	var previous_price: int = 0
	for item: Dictionary in parts:
		var vertices: PackedVector2Array = item.vertices
		t.assert_false(ids.has(str(item.id)), "Spaceship part identifiers are unique")
		ids[str(item.id)] = true
		families[str(item.kind)] = true
		t.assert_eq(vertices.size(), 4, "Every ship component is one four-vertex polygon")
		t.assert_true(Math.is_valid(vertices), "Every ship component is finite, convex and nondegenerate")
		t.assert_true(Math.matches_kind(vertices, str(item.kind)), "Each component preserves its advertised shape family")
		var total_angle: float = 0.0
		for angle: float in Math.angles_degrees(vertices): total_angle += angle
		t.assert_float_approx(total_angle, 360.0, 0.01, "Each ship component has a 360 degree interior angle sum")
		var transformed: PackedVector2Array = Math.scale_vertices(Math.rotate_vertices(vertices, 37.0), 0.45)
		t.assert_true(Math.matches_kind(transformed, str(item.kind)), "Launch rotation and scaling preserve every ship family")
		t.assert_gt(int(item.price), previous_price, "Part prices form an expensive increasing progression")
		previous_price = int(item.price)
		t.assert_ge(int(item.price), 20000000, "Even the first component requires substantial earned funds")
		t.assert_eq(Catalog.part(str(item.id)).price, item.price, "Catalog lookup agrees with the displayed price")
	t.assert_eq(families.size(), 5, "The complete ship contains all five selectable quadrilateral families")
	t.assert_true(Catalog.part("missing").is_empty(), "Unknown component identifiers cannot be purchased")
	parts[0].vertices[0] = Vector2(99999, 99999)
	t.assert_true(Math.is_valid(Catalog.part("hull").vertices), "Catalog consumers cannot corrupt future ship geometry")
