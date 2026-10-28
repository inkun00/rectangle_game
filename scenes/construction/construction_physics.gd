class_name ConstructionPhysics
extends Node

## Runs a copy of the design in its own physics world. Touching masonry is
## mortar-bonded; every constituent polygon remains its original quadrilateral.
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const GROUND_Y: float = 560.0
const INSPECTION_SECONDS: float = 3.0
const CONTACT_EPSILON: float = 1.1

signal finished(report: Dictionary)
signal advanced

var running: bool = false
var revision: int = -1
var elapsed: float = 0.0
var report: Dictionary = {}
var _viewport: SubViewport
var _parts: Array[Dictionary] = []
var _poses: Dictionary = {}
var _bodies: Array[RigidBody2D] = []
var _mass_parts: Dictionary = {}
var _frame_anchors: Dictionary = {}
var _uninstalled: Array[int] = []
var _initial_origins: Dictionary = {}

func _ready() -> void:
	set_physics_process(false)

func start(parts: Array[Dictionary], design_revision: int) -> void:
	stop()
	_parts = parts.duplicate(true)
	revision = design_revision
	report = {}
	elapsed = 0.0
	_viewport = SubViewport.new()
	_viewport.name = "ConstructionPhysicsWorld"
	_viewport.size = Vector2i(1000, 600)
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.transparent_bg = true
	add_child(_viewport)
	var floor_body: StaticBody2D = StaticBody2D.new()
	floor_body.position = Vector2(500, GROUND_Y + 40)
	var floor_shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(1600, 80)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	_viewport.add_child(floor_body)
	var structural: Array[Dictionary] = []
	var fittings: Array[Dictionary] = []
	for part: Dictionary in _parts:
		if bool(Catalog.material(str(part.material_id)).get("structural", false)):
			structural.append(part)
		else:
			fittings.append(part)
	for group: Array in _masonry_groups(structural):
		var typed_group: Array[Dictionary] = []
		for member: Dictionary in group:
			typed_group.append(member)
		_create_body(typed_group, true)
	for part: Dictionary in fittings:
		_install_fitting(part, structural)
	for body: RigidBody2D in _bodies:
		_update_mass_properties(body)
	running = true
	set_physics_process(true)
	advanced.emit()

func stop() -> void:
	running = false
	set_physics_process(false)
	if is_instance_valid(_viewport):
		remove_child(_viewport)
		_viewport.queue_free()
	_viewport = null
	_parts.clear()
	_poses.clear()
	_bodies.clear()
	_mass_parts.clear()
	_frame_anchors.clear()
	_uninstalled.clear()
	_initial_origins.clear()

func _physics_process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	advanced.emit()
	if elapsed >= INSPECTION_SECONDS:
		_finish()

func pose(part_id: int) -> Transform2D:
	if not _poses.has(part_id):
		return Transform2D.IDENTITY
	var data: Dictionary = _poses[part_id]
	var body: RigidBody2D = data.body
	return Transform2D(body.rotation, body.to_global(Vector2(data.offset)))

func rendered_parts() -> Array[Dictionary]:
	return _parts

func _create_body(group: Array[Dictionary], structural: bool) -> RigidBody2D:
	var body: RigidBody2D = RigidBody2D.new()
	var origin: Vector2 = Vector2.ZERO
	var total_mass: float = 0.0
	for part: Dictionary in group:
		var mass: float = maxf(0.1, float(Catalog.material(str(part.material_id)).get("mass", 1.0)))
		origin += Vector2(part.position) * mass
		total_mass += mass
	origin /= maxf(total_mass, 0.1)
	body.position = origin
	body.mass = maxf(total_mass, 0.1)
	body.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector2.ZERO
	body.collision_layer = 1 if structural else 2
	body.collision_mask = 1
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.linear_damp = 1.5
	body.angular_damp = 2.5
	var surface: PhysicsMaterial = PhysicsMaterial.new()
	surface.friction = 0.9
	surface.bounce = 0.0
	body.physics_material_override = surface
	for part: Dictionary in group:
		var collider: CollisionShape2D = CollisionShape2D.new()
		var polygon: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
		polygon.points = part.vertices
		collider.shape = polygon
		collider.position = Vector2(part.position) - origin
		body.add_child(collider)
		_poses[int(part.id)] = {"body": body, "offset": collider.position}
		_initial_origins[int(part.id)] = Vector2(part.position)
	_viewport.add_child(body)
	_bodies.append(body)
	_mass_parts[body.get_instance_id()] = group.duplicate(true)
	return body

func _install_fitting(part: Dictionary, structural: Array[Dictionary]) -> void:
	var material: Dictionary = Catalog.material(str(part.material_id))
	var anchor_ids: Array[int] = []
	if bool(material.get("opening", false)):
		anchor_ids = _opening_anchors(part, structural)
	else:
		for support: Dictionary in structural:
			if _polygons_touch_or_overlap(_world_vertices(part), _world_vertices(support)):
				anchor_ids.append(int(support.id))
				break
	if not anchor_ids.is_empty():
		var anchor: Dictionary = _poses[anchor_ids[0]]
		var body: RigidBody2D = anchor.body
		_poses[int(part.id)] = {"body": body, "offset": Vector2(part.position) - body.position}
		_initial_origins[int(part.id)] = Vector2(part.position)
		_frame_anchors[int(part.id)] = anchor_ids
		# Fittings add their real offset weight and inertia, but no collision shape
		# that could hold up masonry. Mass properties are finalized after attachment.
		_mass_parts[body.get_instance_id()].append(part.duplicate(true))
	else:
		_uninstalled.append(int(part.id))
		var isolated: Array[Dictionary] = [part]
		_create_body(isolated, false)

func _update_mass_properties(body: RigidBody2D) -> void:
	var pieces: Array = _mass_parts[body.get_instance_id()]
	var mass_sum: float = 0.0
	var weighted_center: Vector2 = Vector2.ZERO
	var properties: Array[Dictionary] = []
	for part: Dictionary in pieces:
		var mass: float = maxf(0.1, float(Catalog.material(str(part.material_id)).get("mass", 1.0)))
		var polygon: Dictionary = _polygon_mass_properties(part.vertices, mass)
		var local_center: Vector2 = Vector2(part.position) - body.position + Vector2(polygon.center)
		properties.append({"mass": mass, "center": local_center, "inertia": float(polygon.inertia)})
		mass_sum += mass
		weighted_center += local_center * mass
	var center: Vector2 = weighted_center / mass_sum
	var inertia: float = 0.0
	for piece: Dictionary in properties:
		inertia += float(piece.inertia) + float(piece.mass) * Vector2(piece.center).distance_squared_to(center)
	body.mass = mass_sum
	body.center_of_mass = center
	body.inertia = maxf(inertia, 0.1)

static func _polygon_mass_properties(vertices: PackedVector2Array, mass: float) -> Dictionary:
	var cross_sum: float = 0.0
	var center_sum: Vector2 = Vector2.ZERO
	var inertia_sum: float = 0.0
	for index: int in range(vertices.size()):
		var first: Vector2 = vertices[index]
		var second: Vector2 = vertices[(index + 1) % vertices.size()]
		var cross: float = first.cross(second)
		cross_sum += cross
		center_sum += (first + second) * cross
		inertia_sum += cross * (first.dot(first) + first.dot(second) + second.dot(second))
	var center: Vector2 = center_sum / (3.0 * cross_sum)
	var inertia: float = mass * inertia_sum / (6.0 * cross_sum) - mass * center.length_squared()
	return {"center": center, "inertia": maxf(inertia, 0.1)}

func _opening_anchors(opening: Dictionary, structural: Array[Dictionary]) -> Array[int]:
	var diagnosis: Dictionary = opening_support(opening, structural)
	var anchors: Array[int] = []
	if bool(diagnosis.supported):
		anchors.assign(diagnosis.anchor_ids)
	return anchors

## Edges use the same order as the four authoritative vertices. Coverage is
## measured on real shared segments, so a rotated corner is never a frame.
static func opening_support(opening: Dictionary, structural: Array[Dictionary]) -> Dictionary:
	var vertices: PackedVector2Array = _world_vertices(opening)
	var anchor_ids: Array[int] = []
	var missing_edges: Array[int] = []
	var edge_coverage: PackedFloat32Array = PackedFloat32Array()
	var is_door: bool = str(Catalog.material(str(opening.material_id)).get("role", "")) == "door"
	for edge_index: int in range(4):
		var start: Vector2 = vertices[edge_index]
		var end: Vector2 = vertices[(edge_index + 1) % 4]
		var length: float = start.distance_to(end)
		var intervals: Array[Vector2] = []
		if is_door and absf(start.y - GROUND_Y) <= CONTACT_EPSILON and absf(end.y - GROUND_Y) <= CONTACT_EPSILON:
			intervals.append(Vector2(0.0, length))
		for support: Dictionary in structural:
			if not bool(Catalog.material(str(support.material_id)).get("structural", false)):
				continue
			var other: PackedVector2Array = _world_vertices(support)
			for other_edge: int in range(4):
				var contact: Vector2 = _edge_contact_interval(start, end, other[other_edge], other[(other_edge + 1) % 4])
				if contact.x < 0.0:
					continue
				intervals.append(contact)
				if not anchor_ids.has(int(support.id)):
					anchor_ids.append(int(support.id))
		var covered: float = _interval_union_length(intervals)
		edge_coverage.append(clampf(covered / length, 0.0, 1.0))
		if covered + 0.01 < minf(20.0, length * 0.25):
			missing_edges.append(edge_index)
	return {"supported": missing_edges.is_empty(), "anchor_ids": anchor_ids, "missing_edges": missing_edges, "edge_coverage": edge_coverage}

static func _edge_contact_interval(start: Vector2, end: Vector2, other_start: Vector2, other_end: Vector2) -> Vector2:
	var length: float = start.distance_to(end)
	var direction: Vector2 = (end - start).normalized()
	if absf(direction.cross((other_end - other_start).normalized())) > 0.02:
		return Vector2(-1, -1)
	if absf(direction.cross(other_start - start)) > CONTACT_EPSILON or absf(direction.cross(other_end - start)) > CONTACT_EPSILON:
		return Vector2(-1, -1)
	var first_projection: float = direction.dot(other_start - start)
	var second_projection: float = direction.dot(other_end - start)
	var low: float = maxf(0.0, minf(first_projection, second_projection))
	var high: float = minf(length, maxf(first_projection, second_projection))
	return Vector2(low, high) if high - low >= 0.1 else Vector2(-1, -1)

static func _interval_union_length(intervals: Array[Vector2]) -> float:
	if intervals.is_empty():
		return 0.0
	intervals.sort_custom(func(first: Vector2, second: Vector2) -> bool: return first.x < second.x)
	var total: float = 0.0
	var low: float = intervals[0].x
	var high: float = intervals[0].y
	for index: int in range(1, intervals.size()):
		var interval: Vector2 = intervals[index]
		if interval.x <= high:
			high = maxf(high, interval.y)
		else:
			total += high - low
			low = interval.x
			high = interval.y
	return total + high - low

func _finish() -> void:
	running = false
	set_physics_process(false)
	var stable_ids: Array[int] = []
	var unsupported_ids: Array[int] = []
	for part: Dictionary in _parts:
		var id: int = int(part.id)
		var transform: Transform2D = pose(id)
		var data: Dictionary = _poses[id]
		var body: RigidBody2D = data.body
		var unchanged: bool = transform.origin.distance_to(Vector2(part.position)) <= 8.0 and absf(wrapf(body.rotation, -PI, PI)) <= deg_to_rad(5.0)
		var settled: bool = body.linear_velocity.length() <= 12.0 and absf(body.angular_velocity) <= 0.12
		if unchanged and settled and not _uninstalled.has(id):
			stable_ids.append(id)
		else:
			unsupported_ids.append(id)
	for id: int in _frame_anchors:
		for anchor_id: int in _frame_anchors[id]:
			if unsupported_ids.has(anchor_id):
				stable_ids.erase(id)
				if not unsupported_ids.has(id):
					unsupported_ids.append(id)
	var stable: bool = unsupported_ids.is_empty() and not _parts.is_empty()
	var message: String = "중력 검사를 통과했어요. 구조재와 문·창틀이 제자리를 지켰어요. 외벽과 의뢰 조건도 확인해 주세요." if stable else "움직이거나 틀이 없는 재료 %d개를 확인했어요. 벽을 받치고 문·창문의 네 둘레를 완성해 주세요." % unsupported_ids.size()
	if _parts.is_empty():
		message = "먼저 벽과 문, 창문으로 집을 지어 주세요."
	var issues: Array[Dictionary] = _inspection_issues(unsupported_ids)
	report = {"stable": stable, "passed": stable, "stable_ids": stable_ids, "unsupported_ids": unsupported_ids, "fallen_ids": unsupported_ids.duplicate(), "stable_count": stable_ids.size(), "total": _parts.size(), "message": message, "revision": revision, "issues": issues}
	for body: RigidBody2D in _bodies:
		body.freeze = true
	advanced.emit()
	finished.emit(report.duplicate(true))

## Diagnostics describe the original design, never the fallen simulation pose.
## Keep one row per failing part in design order so the UI can locate it reliably.
func _inspection_issues(unsupported_ids: Array[int]) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var structural: Array[Dictionary] = []
	for part: Dictionary in _parts:
		if bool(Catalog.material(str(part.material_id)).get("structural", false)):
			structural.append(part)
	for part: Dictionary in _parts:
		var id: int = int(part.id)
		if not unsupported_ids.has(id):
			continue
		var material: Dictionary = Catalog.material(str(part.material_id))
		var missing_edges: Array[int] = []
		var code: String = "fitting_moved"
		var message: String = "붙인 재료가 흔들렸어요. 주변 틀이나 벽이 움직이지 않도록 받침을 보강해 주세요."
		if bool(material.get("opening", false)):
			var frame: Dictionary = opening_support(part, structural)
			missing_edges.assign(frame.missing_edges)
		if not missing_edges.is_empty():
			code = "opening_frame_missing"
			var directions: Array[String] = []
			var vertices: PackedVector2Array = _world_vertices(part)
			for edge_index: int in missing_edges:
				directions.append(_edge_direction(vertices, edge_index) + " 변")
			message = "%s의 받침이 부족해요. 벽돌이나 받침보를 맞대어 틀을 완성해 주세요." % "·".join(directions)
		elif _uninstalled.has(id):
			code = "decoration_unattached"
			message = "장식이 벽에 붙어 있지 않아요. 벽돌이나 지붕 면에 닿도록 옮겨 주세요."
		elif bool(material.get("structural", false)):
			var data: Dictionary = _poses[id]
			var body: RigidBody2D = data.body
			if absf(wrapf(body.rotation, -PI, PI)) > deg_to_rad(5.0):
				code = "structure_tilted"
				message = "재료가 기울어졌어요. 아래쪽 받침을 넓히고 양쪽 무게가 고르게 놓이도록 고쳐 주세요."
			else:
				code = "structure_moved"
				message = "재료가 움직였어요. 아래에 벽돌이나 보를 놓아 바닥까지 받침을 이어 주세요."
		else:
			var anchor_ids: Array = _frame_anchors.get(id, [])
			for anchor_id: int in anchor_ids:
				if unsupported_ids.has(anchor_id):
					code = "fitting_support_moved"
					message = "틀이나 붙어 있는 벽이 움직였어요. 주변 벽과 받침을 먼저 튼튼하게 고쳐 주세요."
					break
		issues.append({"part_id": id, "material_id": str(part.material_id), "code": code, "message": message, "missing_edges": missing_edges})
	return issues

static func _edge_direction(vertices: PackedVector2Array, edge_index: int) -> String:
	var center: Vector2 = Vector2.ZERO
	for vertex: Vector2 in vertices:
		center += vertex
	center /= float(vertices.size())
	var midpoint: Vector2 = (vertices[edge_index] + vertices[(edge_index + 1) % vertices.size()]) * 0.5
	var direction: Vector2 = midpoint - center
	var octant: int = posmod(roundi(direction.angle() / (PI * 0.25)), 8)
	var names: Array[String] = ["오른쪽", "오른쪽 아래", "아래쪽", "왼쪽 아래", "왼쪽", "왼쪽 위", "위쪽", "오른쪽 위"]
	return names[octant]

static func _masonry_groups(parts: Array[Dictionary]) -> Array[Array]:
	var groups: Array[Array] = []
	var seen: Array[int] = []
	for index: int in range(parts.size()):
		if seen.has(index):
			continue
		var group: Array[Dictionary] = []
		var pending: Array[int] = [index]
		seen.append(index)
		while not pending.is_empty():
			var current: int = pending.pop_back()
			group.append(parts[current])
			for other: int in range(parts.size()):
				if not seen.has(other) and _bonded(_world_vertices(parts[current]), _world_vertices(parts[other])):
					seen.append(other)
					pending.append(other)
		groups.append(group)
	return groups

static func _bonded(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	if not QuadrilateralMath.bounds(first).grow(CONTACT_EPSILON).intersects(QuadrilateralMath.bounds(second)):
		return false
	for a: int in range(4):
		for b: int in range(4):
			var contact: Vector2 = _edge_contact_interval(first[a], first[(a + 1) % 4], second[b], second[(b + 1) % 4])
			if contact.x >= 0.0 and contact.y - contact.x >= 4.0:
				return true
	return false

static func _polygons_touch_or_overlap(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	if not Geometry2D.intersect_polygons(first, second).is_empty():
		return true
	return _bonded(first, second)

static func _world_vertices(part: Dictionary) -> PackedVector2Array:
	var vertices: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in part.vertices:
		vertices.append(Vector2(part.position) + point)
	return vertices
