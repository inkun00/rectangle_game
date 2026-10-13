class_name QuadrilateralMath
extends RefCounted

## Four local vertices are the only geometric state. All properties are derived.
const KINDS: Array[String] = ["trapezoid", "parallelogram", "rhombus", "rectangle", "square"]
const LABELS: Dictionary = {"trapezoid": "사다리꼴", "parallelogram": "평행사변형", "rhombus": "마름모", "rectangle": "직사각형", "square": "정사각형"}
const TOLERANCE: float = 0.001

static func kind_name(kind: String) -> String:
	return str(LABELS.get(kind, kind))

static func kind_label(kind: String) -> String:
	return kind_name(kind)

static func angles(vertices: PackedVector2Array) -> PackedFloat32Array:
	return angles_degrees(vertices)

static func classifications(vertices: PackedVector2Array) -> Array[String]:
	var result: Array[String] = []
	var properties: Dictionary = classification(vertices)
	for kind: String in KINDS:
		if bool(properties[kind]):
			result.append(kind)
	return result

static func create_vertices(kind: String, dimensions: Vector2 = Vector2(92.0, 68.0)) -> PackedVector2Array:
	var half: Vector2 = dimensions.abs() * 0.5
	if half.x < 2.0 or half.y < 2.0 or not KINDS.has(kind):
		return PackedVector2Array()
	match kind:
		"trapezoid":
			return PackedVector2Array([Vector2(-half.x * 0.62, -half.y), Vector2(half.x * 0.62, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])
		"parallelogram":
			return PackedVector2Array([Vector2(-half.x * 0.55, -half.y), Vector2(half.x, -half.y), Vector2(half.x * 0.55, half.y), Vector2(-half.x, half.y)])
		"rhombus":
			return PackedVector2Array([Vector2(0.0, -half.y), Vector2(half.x, 0.0), Vector2(0.0, half.y), Vector2(-half.x, 0.0)])
		"square":
			var side: float = minf(half.x, half.y)
			return PackedVector2Array([Vector2(-side, -side), Vector2(side, -side), Vector2(side, side), Vector2(-side, side)])
		_:
			return PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])

static func signed_area(vertices: PackedVector2Array) -> float:
	if vertices.size() != 4:
		return 0.0
	var result: float = 0.0
	for index: int in range(4):
		result += vertices[index].cross(vertices[(index + 1) % 4])
	return result * 0.5

static func is_valid(vertices: PackedVector2Array, minimum_area: float = 4.0) -> bool:
	if vertices.size() != 4:
		return false
	for vertex: Vector2 in vertices:
		if not vertex.is_finite():
			return false
	if absf(signed_area(vertices)) < minimum_area:
		return false
	var winding: float = 0.0
	for index: int in range(4):
		var first: Vector2 = vertices[(index + 1) % 4] - vertices[index]
		var second: Vector2 = vertices[(index + 2) % 4] - vertices[(index + 1) % 4]
		if first.length() < 1.0 or second.length() < 1.0:
			return false
		var turn: float = first.normalized().cross(second.normalized())
		if absf(turn) < TOLERANCE:
			return false
		if index == 0:
			winding = signf(turn)
		elif signf(turn) != winding:
			return false
	return true

static func side_lengths(vertices: PackedVector2Array) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	if vertices.size() != 4:
		return result
	for index: int in range(4):
		result.append(vertices[index].distance_to(vertices[(index + 1) % 4]))
	return result

static func angles_degrees(vertices: PackedVector2Array) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	if not is_valid(vertices):
		return result
	for index: int in range(4):
		var previous: Vector2 = (vertices[(index + 3) % 4] - vertices[index]).normalized()
		var next: Vector2 = (vertices[(index + 1) % 4] - vertices[index]).normalized()
		result.append(rad_to_deg(acos(clampf(previous.dot(next), -1.0, 1.0))))
	return result

static func display_angles(vertices: PackedVector2Array) -> PackedInt32Array:
	var angles: PackedFloat32Array = angles_degrees(vertices)
	var result: PackedInt32Array = PackedInt32Array()
	if angles.size() != 4:
		return result
	var total: int = 0
	for index: int in range(3):
		var value: int = roundi(angles[index])
		result.append(value)
		total += value
	result.append(360 - total)
	return result

static func parallel_pair_count(vertices: PackedVector2Array) -> int:
	if not is_valid(vertices):
		return 0
	var count: int = 0
	for index: int in range(2):
		var first: Vector2 = (vertices[(index + 1) % 4] - vertices[index]).normalized()
		var opposite: Vector2 = (vertices[(index + 3) % 4] - vertices[(index + 2) % 4]).normalized()
		if absf(first.cross(opposite)) <= TOLERANCE:
			count += 1
	return count

static func classification(vertices: PackedVector2Array) -> Dictionary:
	var result: Dictionary = {"valid": false, "trapezoid": false, "parallelogram": false, "rhombus": false, "rectangle": false, "square": false, "parallel_pairs": 0}
	if not is_valid(vertices):
		return result
	result.valid = true
	var pairs: int = parallel_pair_count(vertices)
	var lengths: PackedFloat32Array = side_lengths(vertices)
	var angles: PackedFloat32Array = angles_degrees(vertices)
	var equal_sides: bool = true
	var right_angles: bool = true
	for index: int in range(4):
		equal_sides = equal_sides and absf(lengths[index] - lengths[0]) <= maxf(lengths[0] * TOLERANCE, 0.001)
		right_angles = right_angles and absf(angles[index] - 90.0) <= 0.1
	result.parallel_pairs = pairs
	# The curriculum uses the inclusive definition: at least one parallel pair.
	result.trapezoid = pairs >= 1
	result.parallelogram = pairs == 2
	result.rhombus = pairs == 2 and equal_sides
	result.rectangle = pairs == 2 and right_angles
	result.square = pairs == 2 and equal_sides and right_angles
	return result

static func matches_kind(vertices: PackedVector2Array, kind: String) -> bool:
	return KINDS.has(kind) and bool(classification(vertices).get(kind, false))

static func rotate_vertices(vertices: PackedVector2Array, degrees: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for vertex: Vector2 in vertices:
		result.append(vertex.rotated(deg_to_rad(degrees)))
	return result

static func scale_vertices(vertices: PackedVector2Array, factor: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for vertex: Vector2 in vertices:
		result.append(vertex * factor)
	return result

static func contains_point(vertices: PackedVector2Array, point: Vector2) -> bool:
	return is_valid(vertices) and Geometry2D.is_point_in_polygon(point, vertices)

static func bounds(vertices: PackedVector2Array) -> Rect2:
	if vertices.is_empty():
		return Rect2()
	var result: Rect2 = Rect2(vertices[0], Vector2.ZERO)
	for vertex: Vector2 in vertices:
		result = result.expand(vertex)
	return result
