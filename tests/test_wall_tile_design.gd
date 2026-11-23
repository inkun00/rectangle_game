extends RefCounted

const Design = preload("res://scripts/core/wall_tile_design.gd")
const Geometry = preload("res://scripts/core/quadrilateral_math.gd")


static func run(t: Node) -> void:
	_test_tiling(t)
	_test_orders(t)
	_test_restore(t)


static func _test_tiling(t: Node) -> void:
	var design := Design.new()
	design.set_tile_repeat(3, 2)
	design.set_repeat(4, 3)
	for motif: String in Design.MOTIFS:
		design.select_motif(motif)
		for quarter: int in range(4):
			var unit: Array[Dictionary] = design.unit_parts()
			var unit_area: float = 0.0
			for i: int in range(unit.size()):
				var vertices: PackedVector2Array = unit[i].vertices
				t.assert_true(Geometry.is_valid(vertices), "Every wall shape is a finite convex quadrilateral")
				unit_area += absf(Geometry.signed_area(vertices))
				var angle_sum: float = 0.0
				for angle: float in Geometry.angles(vertices):
					angle_sum += angle
				t.assert_float_approx(angle_sum, 360, 0.02, "Rotated tile retains four interior angles")
				for j: int in range(i):
					var overlap: Array[PackedVector2Array] = Geometry2D.intersect_polygons(vertices, unit[j].vertices)
					t.assert_true(overlap.is_empty(), "Base shapes share only edges and never overlap")
			t.assert_float_approx(unit_area, 10000.0, 0.01, "Motif covers its complete square unit")
			design.rotate_tile()
		for layout: String in Design.LAYOUTS:
			design.set_layout(layout)
			var wall: Array[Dictionary] = design.wall_parts()
			t.assert_eq(wall.size(), design.unit_parts().size() * 6 * 12, "Each placed tile includes every repeated group")
			t.assert_eq(design.wall_size(), Vector2(1200, 600), "Whole wall preserves rectangular tile aspect ratio")
			var tile: Array[Dictionary] = design.motif_parts()
			var tile_count: int = tile.size()
			for j: int in range(tile_count):
				var first: Dictionary = wall[j]
				var next: Dictionary = wall[tile_count + j]
				t.assert_eq(first.vertices, tile[j].vertices, "First cell preserves the painted tile")
				var next_vertices: PackedVector2Array = next.vertices
				t.assert_true(Geometry.is_valid(next_vertices), "Reflection retains real convex quadrilaterals")
				t.assert_eq(Geometry.classifications(next_vertices), Geometry.classifications(first.vertices), "A reflection or rotation preserves all shape classifications")
				var p: Vector2 = first.vertices[0]
				if layout == "mirror":
					p.x = 300.0 - p.x
				elif layout == "alternate":
					p = design.tile_size() - p
				t.assert_eq(next_vertices[0], p + Vector2(300, 0), "Neighbor uses the selected layout transform")
				t.assert_eq(first.color, next.color, "Transforming a tile preserves its paint")


static func _test_orders(t: Node) -> void:
	var design := Design.new()
	t.assert_eq(design.claim(), 0, "Unpainted draft is ineligible")
	design.set_color(1, 1)
	design.set_repeat(4, 2)
	t.assert_false(design.evaluate().ok, "Repeating tiles across the wall does not replace repetitions within the tile")
	design.set_tile_repeat(2, 1)
	t.assert_eq(design.claim(), 3000000, "Completed harbor order pays its quoted price")
	t.assert_eq(design.claim(), 0, "Second sale does not pay")
	design.set_commission("garden")
	t.assert_false(design.evaluate().ok, "Satisfying another motif cannot finish the greenhouse order")
	design.select_motif("square_frame")
	design.set_color(0, 2)
	design.set_repeat(3, 3)
	t.assert_false(design.evaluate().ok, "Greenhouse requires repeats along both axes")
	design.set_tile_repeat(2, 2)
	design.set_color(3, 2)
	t.assert_false(design.evaluate().ok, "One matching border prevents center contrast")
	design.set_color(3, 1)
	t.assert_eq(design.claim(), 7000000, "Greenhouse order pays after all four borders contrast")
	design.set_commission("station")
	design.select_motif("mirror_stripe")
	design.set_color(1, 3)
	design.set_repeat(4, 3)
	t.assert_false(design.evaluate().ok, "Space station requests mirrored neighbors")
	design.set_layout("mirror")
	t.assert_eq(design.claim(), 12000000, "Mirrored station order pays the highest price")
	t.assert_eq(design.total_income(), 22000000, "Wall income is the sum of unique fulfilled commissions")


static func _test_restore(t: Node) -> void:
	var design := Design.new()
	design.set_color(1, 1)
	design.set_tile_repeat(2, 1)
	design.set_repeat(4, 2)
	design.claim()
	design.rotate_tile()
	design.select_motif("square_frame")
	design.set_color(0, 3)
	var data: Dictionary = JSON.parse_string(JSON.stringify(design.to_dict()))
	var restored := Design.new()
	t.assert_true(restored.restore(data), "A save survives the JSON number conversion")
	t.assert_eq(restored.to_dict(), design.to_dict(), "Reloading keeps the complete ledger representation stable")
	restored.select_motif("trapezoid_pair")
	t.assert_eq(restored.unit_parts()[1].palette_index, 1, "Paint is retained per motif")
	t.assert_eq(restored.claim(), 0, "Reloading does not repay a completed order")
	var before: Dictionary = restored.to_dict()
	var invalid: Dictionary = data.duplicate(true)
	invalid.completed = ["harbor", "harbor"]
	t.assert_false(restored.restore(invalid), "A duplicated receipt is rejected")
	invalid = data.duplicate(true)
	invalid.colors.square_frame[0] = -1
	t.assert_false(restored.restore(invalid), "Invalid palette indices are rejected")
	invalid = data.duplicate(true)
	invalid.tile_columns = 1.5
	t.assert_false(restored.restore(invalid), "Partial repeat counts are rejected")
	t.assert_eq(restored.to_dict(), before, "Invalid save data never changes the active design")
	t.assert_false(restored.set_tile_repeat(4, 3), "Reject out-of-range inner dimensions")
	t.assert_false(restored.set_repeat(2, 7), "Reject out-of-range wall dimensions")
	t.assert_false(restored.set_color(-1, 4), "An invalid piece cannot alias the last piece")
