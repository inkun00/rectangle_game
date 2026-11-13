class_name TestSpaceshipCatalog
extends RefCounted

const Catalog: GDScript = preload("res://scripts/economy/spaceship_catalog.gd")
const Math: GDScript = preload("res://scripts/core/quadrilateral_math.gd")
const Assembly: GDScript = preload("res://scripts/economy/spaceship_assembly.gd")

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
	var elite_total: int = 0
	var elite_ids: Array[String] = []
	var variant_ids: Dictionary = {}
	for index: int in range(parts.size()):
		var slot: Dictionary = parts[index]
		var id: String = str(slot.id)
		var models: Array[Dictionary] = Catalog.variants(id)
		t.assert_eq(models.size(), 3, "Each required slot offers three distinct models")
		for tier: int in range(models.size()):
			var model: Dictionary = models[tier]
			var vertices: PackedVector2Array = model.vertices
			t.assert_false(variant_ids.has(model.id), "Each product has a unique purchase ID")
			variant_ids[model.id] = true
			t.assert_eq(model.slot_id, id, "Variants share one required slot")
			t.assert_eq(model.slot_index, index, "Models in one slot share the same atlas cell index")
			t.assert_eq(model.tier, tier, "Each model has its own sprite sheet and price tier")
			t.assert_true(Math.is_valid(vertices) and Math.matches_kind(vertices, str(model.kind)), "Every variant has its advertised quadrilateral shape")
			var transformed: PackedVector2Array = Math.scale_vertices(Math.rotate_vertices(vertices, 31.0), 0.65)
			t.assert_true(Math.matches_kind(transformed, str(model.kind)), "Rotating and scaling a model preserves its family")
			var angle_sum: float = 0.0
			for angle: float in Math.angles_degrees(vertices): angle_sum += angle
			t.assert_float_approx(angle_sum, 360.0, 0.01, "Each variant retains 360 degrees")
			if tier > 0:
				var previous: Dictionary = models[tier - 1]
				t.assert_gt(int(model.price), int(previous.price), "A larger model costs more than the prior tier")
				t.assert_gt(int(model.performance), int(previous.performance), "A higher tier gives a stronger ship")
				t.assert_true(model.name != previous.name and model.vertices != previous.vertices, "A higher tier changes both the label and the outline")
		elite_total += int(models.back().price)
		elite_ids.append(str(models.back().id))
	t.assert_eq(variant_ids.size(), 36, "The catalog offers thirty-six unique products")
	t.assert_eq(elite_total, Catalog.MAX_TOTAL_PRICE, "The top-tier price bound matches a real complete ship")
	var installed: Array[Dictionary] = Catalog.installed_parts(elite_ids)
	t.assert_eq(installed.size(), 12, "The renderer resolves all twelve equipped models")
	t.assert_eq(installed.front().id, "left_wing_elite", "The wings render underneath the installed body")
	t.assert_eq(installed.back().id, "shield_elite", "The equipped shield renders above the body")
	_test_shape_variation(t)
	_test_connected_assemblies(t)

static func _test_shape_variation(t: Node) -> void:
	var square_sizes: Dictionary = {}
	var square_orientations: Dictionary = {}
	var rectangle_aspects: Dictionary = {}
	var rectangle_orientations: Dictionary = {}
	var rhombus_ratios: Dictionary = {}
	var rhombus_orientations: Dictionary = {}
	var parallelogram_leans: Dictionary = {}
	var parallelogram_orientations: Dictionary = {}
	var trapezoid_ratios: Dictionary = {}
	var trapezoid_offsets: Dictionary = {}
	var trapezoid_facings: Dictionary = {}
	for slot: Dictionary in Catalog.all_parts():
		for part: Dictionary in Catalog.variants(str(slot.id)):
			var vertices: PackedVector2Array = part.vertices
			var lengths: PackedFloat32Array = Math.side_lengths(vertices)
			var top_center: Vector2 = (vertices[0] + vertices[1]) * 0.5
			var bottom_center: Vector2 = (vertices[2] + vertices[3]) * 0.5
			var direction: Vector2 = (vertices[1] - vertices[0]).normalized()
			var orientation: int = roundi(rad_to_deg(direction.angle()))
			match str(part.kind):
				"square":
					square_sizes[roundi(lengths[0])] = true
					square_orientations[orientation] = true
				"rectangle":
					t.assert_false(Math.matches_kind(vertices, "square"), "Rectangle products have distinct adjacent side lengths")
					rectangle_aspects[roundi(100.0 * lengths[0] / lengths[1])] = true
					rectangle_orientations[orientation] = true
				"rhombus":
					t.assert_false(Math.matches_kind(vertices, "square"), "Rhombus products have unequal diagonals")
					rhombus_ratios[roundi(100.0 * vertices[0].distance_to(vertices[2]) / vertices[1].distance_to(vertices[3]))] = true
					rhombus_orientations[orientation] = true
				"parallelogram":
					t.assert_false(Math.matches_kind(vertices, "rectangle"), "Parallelogram products have slanted sides")
					parallelogram_leans[roundi((top_center - bottom_center).dot(direction))] = true
					parallelogram_orientations[orientation] = true
				"trapezoid":
					t.assert_eq(Math.parallel_pair_count(vertices), 1, "Trapezoid products show one parallel pair within the inclusive classification")
					trapezoid_ratios[roundi(100.0 * lengths[0] / lengths[2])] = true
					var center_shift: Vector2 = top_center - bottom_center
					trapezoid_offsets[roundi(center_shift.dot(direction))] = true
					var facing: Vector2 = (center_shift - center_shift.project(direction)).normalized()
					trapezoid_facings[Vector2i(roundi(facing.x), roundi(facing.y))] = true
	t.assert_ge(square_sizes.size(), 4, "Square products have several actual side lengths")
	t.assert_ge(square_orientations.size(), 3, "Square products include level and differently tilted pieces")
	t.assert_ge(rectangle_aspects.size(), 4, "Rectangle products have several proportions")
	t.assert_ge(rectangle_orientations.size(), 2, "Rectangle products include level and tilted pieces")
	t.assert_ge(rhombus_ratios.size(), 3, "Rhombus products use different diagonal proportions")
	t.assert_ge(rhombus_orientations.size(), 3, "Rhombus products include differently tilted pieces")
	t.assert_ge(parallelogram_leans.size(), 5, "Parallelograms lean both ways with varying slant")
	t.assert_ge(parallelogram_orientations.size(), 4, "Parallelogram products include different rotations")
	t.assert_ge(trapezoid_ratios.size(), 6, "Trapezoid products use varied ratios of the short and long bases")
	t.assert_ge(trapezoid_offsets.size(), 6, "Trapezoid products include different asymmetric offsets")
	t.assert_eq(trapezoid_facings.size(), 4, "Trapezoids can have a short edge facing up, down, left or right")


static func _test_connected_assemblies(t: Node) -> void:
	var basic_ids: Array[String] = []
	for base: Dictionary in Catalog.all_parts(): basic_ids.append(str(base.id))
	for slot: Dictionary in Catalog.all_parts():
		var previous_vertices: PackedVector2Array = PackedVector2Array()
		for variant: Dictionary in Catalog.variants(str(slot.id)):
			var primary: Dictionary = Assembly.product_panel(str(variant.id))
			t.assert_false(primary.is_empty(), "Each purchased model maps to an installed panel")
			if primary.is_empty(): continue
			t.assert_eq(primary.kind, variant.kind, "The installed panel preserves the advertised quadrilateral family")
			t.assert_true(primary.vertices != previous_vertices, "Each product changes the actual installed panel")
			previous_vertices = primary.vertices

	var basic: Dictionary = Assembly.build(basic_ids)
	var finishes: Dictionary = {"finish": "brushed", "base": "night", "accent": "red"}
	t.assert_eq(Assembly.build(basic_ids, finishes).panels, basic.panels, "Painting and materials leave the shape of the ship unchanged")
	var choices: Dictionary = {"fore": ["scanner", "sensor"], "wings": ["fins", "solar"], "sides": ["cargo", "pods"], "tail": ["radiators", "boosters"]}
	for mount: String in choices:
		var old_panels: Array[Dictionary] = []
		for option: String in choices[mount]:
			var appearance: Dictionary = {}
			appearance[mount] = option
			var outfitted: Dictionary = Assembly.build(basic_ids, appearance)
			var new_panels: Array[Dictionary] = []
			for panel: Dictionary in outfitted.panels:
				if panel.slot == mount: new_panels.append(panel)
			t.assert_false(new_panels.is_empty(), "Each optional accessory has mounted geometry")
			t.assert_true(new_panels != old_panels, "Each accessory option has a different shape")
			old_panels = new_panels
			_assert_ship_integrity(t, outfitted, option)

	for hull_tier: int in range(3):
		for left_tier: int in range(3):
			for right_tier: int in range(3):
				var ids: Array[String] = basic_ids.duplicate()
				ids[0] = str(Catalog.variants("hull")[hull_tier].id)
				ids[1] = str(Catalog.variants("nose")[right_tier].id)
				ids[2] = str(Catalog.variants("window")[left_tier].id)
				ids[3] = str(Catalog.variants("left_wing")[left_tier].id)
				ids[4] = str(Catalog.variants("right_wing")[right_tier].id)
				ids[5] = str(Catalog.variants("left_tank")[right_tier].id)
				ids[6] = str(Catalog.variants("right_tank")[left_tier].id)
				ids[7] = str(Catalog.variants("engine")[left_tier].id)
				ids[8] = str(Catalog.variants("nozzle")[right_tier].id)
				var style: Dictionary = {"fore": "scanner", "wings": "solar", "sides": "pods", "tail": "boosters"}
				_assert_ship_integrity(t, Assembly.build(ids, style), "mixed grades %d/%d/%d" % [hull_tier, left_tier, right_tier])


static func _assert_ship_integrity(t: Node, design: Dictionary, description: String) -> void:
	var exterior: Array[PackedVector2Array] = []
	for panel: Dictionary in design.panels:
		var vertices: PackedVector2Array = panel.vertices
		t.assert_true(Math.is_valid(vertices) and Math.matches_kind(vertices, str(panel.kind)), "The assembled %s panel is a valid quadrilateral" % panel.slot)
		if not panel.internal and not panel.detail: exterior.append(vertices)
	# Starting with any hull piece, reach each exterior piece through a
	# positive-area overlap or a shared edge. This catches floating attachments
	# as well as gaps when unlike wing, engine, or nose grades are combined.
	var connected: Array[PackedVector2Array] = [exterior.pop_back()]
	var index: int = 0
	while index < connected.size() and not exterior.is_empty():
		for candidate: int in range(exterior.size() - 1, -1, -1):
			if Geometry2D.merge_polygons(connected[index], exterior[candidate]).size() == 1:
				connected.append(exterior[candidate])
				exterior.remove_at(candidate)
		index += 1
	t.assert_true(exterior.is_empty(), "All visible pieces of %s connect to the same airframe" % description)
	var port_centers: Array[Vector2] = design.exhausts
	var port_widths: Array[float] = design.port_widths
	t.assert_eq(port_centers.size(), port_widths.size(), "Every engine exhaust has a matching port width")
	t.assert_float_approx(port_centers[0].y, design.bounds.end.y, 0.05, "The main exhaust lands on the rear edge of the completed silhouette")
