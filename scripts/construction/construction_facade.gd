class_name ConstructionFacade
extends RefCounted

## A finished front elevation has a closed facade from its foundation to its
## roof. Deliberate door/window apertures occupy their reserved polygons here;
## their real frame support is checked separately by ConstructionPhysics.
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const GROUND_Y: float = 560.0
const TOLERANCE: float = 0.1

static func inspect(parts: Array[Dictionary]) -> Dictionary:
	var polygons: Array[Dictionary] = []
	var footprint: Rect2 = Rect2()
	var has_footprint: bool = false
	var wall_count: int = 0
	for part: Dictionary in parts:
		var material: Dictionary = Catalog.material(str(part.material_id))
		var role: String = str(material.role)
		if role == "decor": continue
		var vertices: PackedVector2Array = PackedVector2Array()
		for vertex: Vector2 in part.vertices:
			vertices.append(vertex + Vector2(part.position))
		var bounds: Rect2 = QuadrilateralMath.bounds(vertices)
		polygons.append({"vertices": vertices, "bounds": bounds, "role": role})
		if role in ["wall", "brick", "window", "door"]:
			footprint = footprint.merge(bounds) if has_footprint else bounds
			has_footprint = true
		if role in ["wall", "brick"]: wall_count += 1
	var gaps: Array[Rect2] = []
	var issues: Array[Dictionary] = []
	if not has_footprint or wall_count == 0:
		return {"complete": false, "message": "문과 창문 둘레에 벽을 쌓아 집의 앞면을 만들어 주세요.", "gaps": gaps, "issues": issues, "body_bounds": footprint}
	var cuts: Array[float] = _critical_x(polygons, footprint.position.x, footprint.end.x)
	for index: int in range(cuts.size() - 1):
		var left: float = cuts[index]
		var right: float = cuts[index + 1]
		if right - left <= 0.00001: continue
		var sample_x: float = (left + right) * 0.5
		var spans: Array[Vector2] = []
		var roof_spans: Array[Vector2] = []
		var roof_top: float = INF
		var body_top: float = INF
		var body_present: bool = false
		for polygon: Dictionary in polygons:
			var interval: Vector2 = _vertical_interval(polygon.vertices, sample_x)
			if not is_finite(interval.x): continue
			spans.append(interval)
			if str(polygon.role) == "roof":
				roof_spans.append(interval)
			else:
				body_top = minf(body_top, interval.x)
				if str(polygon.role) in ["wall", "brick", "window", "door"]: body_present = true
		# The main covering roof touches the top of the actual wall/header.
		# A second shaped roof above a closed flat roof may have open air below
		# its outer tips; that air is outside the already enclosed house front.
		for roof_span: Vector2 in roof_spans:
			if roof_span.x <= body_top + TOLERANCE and roof_span.y >= body_top - TOLERANCE:
				roof_top = minf(roof_top, roof_span.x)
		if not body_present:
			_add_gap(gaps, issues, Rect2(left, footprint.position.y, right - left, GROUND_Y - footprint.position.y), "separated_facade")
			continue
		if not is_finite(roof_top) or roof_top > body_top + TOLERANCE:
			_add_gap(gaps, issues, Rect2(left, maxf(0.0, body_top - 20.0), right - left, 20.0), "roof_missing")
			continue
		spans.sort_custom(func(first: Vector2, second: Vector2) -> bool: return first.x < second.x)
		var reached: float = roof_top
		for interval: Vector2 in spans:
			if interval.y < roof_top: continue
			if interval.x > reached + TOLERANCE:
				_add_gap(gaps, issues, Rect2(left, reached, right - left, minf(interval.x, GROUND_Y) - reached), "wall_gap")
				reached = interval.x
			reached = maxf(reached, interval.y)
			if reached >= GROUND_Y - TOLERANCE: break
		if reached < GROUND_Y - TOLERANCE:
			_add_gap(gaps, issues, Rect2(left, reached, right - left, GROUND_Y - reached), "foundation_gap")
	var complete: bool = gaps.is_empty()
	var message: String = "벽·문·창문이 바닥부터 지붕까지 빈틈없이 이어져 있어요." if complete else "집 앞면에 빈틈이 있어요. 벽을 바닥부터 지붕까지 잇고, 앞면 전체를 지붕으로 덮어 주세요."
	return {"complete": complete, "message": message, "gaps": gaps, "issues": issues, "body_bounds": footprint}

## Vertex and segment-intersection abscissae partition the elevation into
## slabs with invariant edge ordering. One exact slice per slab detects even
## a narrow sloping opening without relying on the placement grid or pixels.
static func _critical_x(polygons: Array[Dictionary], left: float, right: float) -> Array[float]:
	var values: Array[float] = [left, right]
	for polygon: Dictionary in polygons:
		for vertex: Vector2 in polygon.vertices:
			if vertex.x > left and vertex.x < right: values.append(vertex.x)
	for first_index: int in range(polygons.size()):
		var first: Dictionary = polygons[first_index]
		for second_index: int in range(first_index + 1, polygons.size()):
			var second: Dictionary = polygons[second_index]
			if not Rect2(first.bounds).intersects(Rect2(second.bounds), true): continue
			for edge: int in range(4):
				for other: int in range(4):
					var crossing: Variant = Geometry2D.segment_intersects_segment(first.vertices[edge], first.vertices[(edge + 1) % 4], second.vertices[other], second.vertices[(other + 1) % 4])
					if crossing is Vector2 and crossing.x > left and crossing.x < right: values.append(float(crossing.x))
	values.sort()
	var result: Array[float] = []
	for value: float in values:
		if result.is_empty() or value - result.back() > 0.00001: result.append(value)
	return result

static func _vertical_interval(vertices: PackedVector2Array, x: float) -> Vector2:
	var top: float = INF
	var bottom: float = -INF
	for index: int in range(4):
		var start: Vector2 = vertices[index]
		var end: Vector2 = vertices[(index + 1) % 4]
		if absf(end.x - start.x) <= 0.000001: continue
		if x < minf(start.x, end.x) or x > maxf(start.x, end.x): continue
		var y: float = lerpf(start.y, end.y, (x - start.x) / (end.x - start.x))
		top = minf(top, y)
		bottom = maxf(bottom, y)
	return Vector2(top, bottom)

static func _add_gap(gaps: Array[Rect2], issues: Array[Dictionary], gap: Rect2, code: String) -> void:
	if gap.size.x <= 0.00001 or gap.size.y <= TOLERANCE: return
	# Joining adjacent equal slices keeps a long missing course readable in UI.
	if not gaps.is_empty():
		var previous: Rect2 = gaps.back()
		if str(issues.back().code) == code and absf(previous.end.x - gap.position.x) <= TOLERANCE and absf(previous.position.y - gap.position.y) <= TOLERANCE and absf(previous.size.y - gap.size.y) <= TOLERANCE:
			previous.size.x = gap.end.x - previous.position.x
			gaps[gaps.size() - 1] = previous
			issues[issues.size() - 1].bounds = previous
			return
	gaps.append(gap)
	issues.append({"code": code, "bounds": gap})
