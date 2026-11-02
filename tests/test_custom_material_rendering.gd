class_name TestCustomMaterialRendering
extends RefCounted

const Art = preload("res://scripts/construction_art.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")

static func run(t: Node) -> void:
	t.assert_true(Art.pattern_uv_polygons("plain").is_empty(), "Plain material keeps its generated surface without an overlay")
	t.assert_true(Art.pattern_uv_polygons("unknown").is_empty(), "Unknown pattern cannot draw outside a material")
	for pattern: String in ["bands", "checks", "diamond"]:
		var masks: Array[PackedVector2Array] = Art.pattern_uv_polygons(pattern)
		t.assert_false(masks.is_empty(), "Each patterned material has visible surface masks: " + pattern)
		for kind: String in Math.KINDS:
			var variants: Array[String] = ["symmetric"]
			if kind == "trapezoid": variants.assign(Math.TRAPEZOID_VARIANTS)
			for variant: String in variants:
				var vertices: PackedVector2Array = Math.create_vertices(kind, Vector2(170, 90), variant)
				var screen_points: PackedVector2Array = Math.rotate_vertices(Math.scale_vertices(vertices, 1.7), 37.0)
				for index: int in range(screen_points.size()): screen_points[index] += Vector2(420, 260)
				for mask: PackedVector2Array in masks:
					var mapped: PackedVector2Array = PackedVector2Array()
					for uv: Vector2 in mask:
						t.assert_true(uv.is_finite() and uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0, "Pattern masks stay inside source texture UVs")
						var point: Vector2 = Art.quad_point(screen_points, uv)
						mapped.append(point)
						var local: Vector2 = Art.quad_point(vertices, uv)
						var transformed: Vector2 = (local * 1.7).rotated(deg_to_rad(37.0)) + Vector2(420, 260)
						t.assert_true(point.distance_to(transformed) < 0.001, "Patterns move, scale and rotate with the actual artwork")
					t.assert_true(Math.is_valid(mapped, 0.001), "Every material pattern patch remains a convex quadrilateral")
					var outside_area: float = 0.0
					for outside: PackedVector2Array in Geometry2D.clip_polygons(mapped, screen_points):
						outside_area += absf(_polygon_area(outside))
					t.assert_true(outside_area <= 0.01, "Surface pattern remains clipped to the true rotated " + kind + " / " + variant)

static func _polygon_area(vertices: PackedVector2Array) -> float:
	var twice_area: float = 0.0
	for index: int in range(vertices.size()):
		twice_area += vertices[index].cross(vertices[(index + 1) % vertices.size()])
	return twice_area * 0.5
