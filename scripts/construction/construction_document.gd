class_name ConstructionDocument
extends RefCounted

const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const History = preload("res://scripts/core/command_manager.gd")
const BOARD: Rect2 = Rect2(0, 0, 1000, 600)
const GROUND_Y: float = 560.0
const GRID: float = 20.0
const MAX_PARTS: int = 400

signal changed

var parts: Array[Dictionary] = []
var selected_id: int = -1
var revision: int = 0
var command_manager: History = History.new()
var budget_limit: int = 100000000
var editing_enabled: bool = true
var last_error: String = ""
var _next_id: int = 1

func _init() -> void:
	command_manager.state_changed.connect(_history_changed)

func _history_changed() -> void:
	changed.emit()

func select(id: int) -> void:
	selected_id = id if not part(id).is_empty() else -1
	changed.emit()

func part(id: int) -> Dictionary:
	for item: Dictionary in parts:
		if int(item.id) == id:
			return item.duplicate(true)
	return {}

func get_selected() -> Dictionary:
	return part(selected_id)

static func snapped_position(_material_id: String, point: Vector2, _kind: String = "") -> Vector2:
	return point.snapped(Vector2(GRID * 0.5, GRID * 0.5))

static func world_vertices(item: Dictionary) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for vertex: Vector2 in item.vertices:
		result.append(vertex + Vector2(item.position))
	return result

func material_cost() -> int:
	return _cost(parts)

func add_part(material_id: String, position: Vector2, kind: String = "") -> int:
	last_error = placement_error(material_id, position, kind)
	if not last_error.is_empty(): return -1
	var item: Dictionary = _new_part(material_id, position, kind, _next_id)
	var after: Dictionary = _snapshot()
	after.parts.append(item)
	after.selected_id = _next_id
	after.next_id = _next_id + 1
	_commit(after)
	return selected_id

func placement_error(material_id: String, position: Vector2, kind: String = "", ignore_id: int = -1) -> String:
	if not editing_enabled: return "의뢰를 받은 뒤 재료를 놓을 수 있어요."
	if not position.is_finite(): return "종이 안의 위치를 골라 주세요."
	if ignore_id < 0 and parts.size() >= MAX_PARTS: return "재료는 400개까지 놓을 수 있어요. 벽돌 묶음도 써 보세요."
	var item: Dictionary = _new_part(material_id, position, kind, 0)
	if item.is_empty(): return "이 재료에서 사용할 수 없는 사각형이에요."
	return _candidate_error(item, ignore_id)

func move_selected(position: Vector2) -> bool:
	var selected: Dictionary = get_selected()
	if selected.is_empty() or not editing_enabled or not position.is_finite(): return false
	selected.position = snapped_position(str(selected.material_id), position, str(selected.kind))
	last_error = _candidate_error(selected, selected_id)
	if not last_error.is_empty(): return false
	return _replace_selected(selected)

func rotate_selected(degrees: float) -> bool:
	var selected: Dictionary = get_selected()
	if selected.is_empty() or not editing_enabled or not is_finite(degrees): return false
	selected.vertices = Math.rotate_vertices(selected.vertices, degrees)
	last_error = _candidate_error(selected, selected_id)
	if not last_error.is_empty(): return false
	return _replace_selected(selected)

func delete_selected() -> void:
	if not editing_enabled or selected_id < 0: return
	var after: Dictionary = _snapshot()
	for index: int in range(after.parts.size()):
		if int(after.parts[index].id) == selected_id:
			after.parts.remove_at(index)
			after.selected_id = -1
			_commit(after)
			return

func duplicate_selected() -> int:
	var selected: Dictionary = get_selected()
	if selected.is_empty() or not editing_enabled or parts.size() >= MAX_PARTS: return -1
	var bounds: Rect2 = Math.bounds(selected.vertices)
	var offsets: Array[Vector2] = [Vector2(bounds.size.x, 0), Vector2(-bounds.size.x, 0), Vector2(0, -bounds.size.y), Vector2(0, bounds.size.y)]
	for offset: Vector2 in offsets:
		var duplicate: Dictionary = selected.duplicate(true)
		duplicate.position = snapped_position(str(selected.material_id), selected.position + offset)
		duplicate.id = _next_id
		if _candidate_error(duplicate, -1).is_empty():
			var after: Dictionary = _snapshot()
			after.parts.append(duplicate)
			after.selected_id = _next_id
			after.next_id = _next_id + 1
			_commit(after)
			return selected_id
	last_error = "주변에 복제할 빈자리가 없어요. 재료를 옮겨 주세요."
	return -1

func clear() -> void:
	if not editing_enabled or parts.is_empty(): return
	var after: Dictionary = _snapshot()
	after.parts = []
	after.selected_id = -1
	_commit(after)

func undo() -> void:
	if editing_enabled: command_manager.undo()

func redo() -> void:
	if editing_enabled: command_manager.redo()

func replace_parts(items: Array[Dictionary]) -> bool:
	if not editing_enabled: return false
	var checked: Array[Dictionary] = []
	var next_id: int = 1
	for item: Dictionary in items:
		if not item.has_all(["material_id", "position"]): return false
		if not item.material_id is String or not item.position is Vector2 or not item.position.is_finite(): return false
		if item.has("kind") and not item.kind is String: return false
		var candidate: Dictionary = _new_part(str(item.material_id), item.position, str(item.get("kind", "")), next_id)
		if candidate.is_empty(): return false
		if item.has("vertices"):
			candidate.vertices = item.vertices
		checked.append(candidate)
		next_id += 1
	if not _valid_parts(checked) or _cost(checked) > budget_limit:
		last_error = "재료가 겹치거나 예산을 넘어서 예시를 놓지 못했어요."
		return false
	_commit({"parts": checked, "selected_id": -1, "next_id": next_id})
	return true

func reset() -> void:
	parts.clear()
	selected_id = -1
	_next_id = 1
	revision += 1
	command_manager.clear()

func serialize() -> Dictionary:
	var stored: Array[Dictionary] = []
	for item: Dictionary in parts:
		var vertices: Array = []
		for vertex: Vector2 in item.vertices: vertices.append([vertex.x, vertex.y])
		stored.append({"id": item.id, "material_id": item.material_id, "kind": item.kind, "position": [item.position.x, item.position.y], "vertices": vertices})
	return {"version": 1, "parts": stored, "selected_id": selected_id, "next_id": _next_id, "revision": revision}

func restore(data: Dictionary) -> bool:
	if not data.has_all(["version", "parts", "selected_id", "next_id", "revision"]): return false
	if not _integer(data.version, 1, 1) or not data.parts is Array or data.parts.size() > MAX_PARTS: return false
	if not _integer(data.selected_id, -1, 1000000000) or not _integer(data.next_id, 1, 1000000000) or not _integer(data.revision, 0, 1000000000): return false
	var checked: Array[Dictionary] = []
	var ids: Array[int] = []
	for raw: Variant in data.parts:
		if not raw is Dictionary or not raw.has_all(["id", "material_id", "kind", "position", "vertices"]): return false
		if not _integer(raw.id, 1, 999999999) or int(raw.id) >= int(data.next_id) or ids.has(int(raw.id)): return false
		if not raw.material_id is String or not raw.kind is String or not _vector_array(raw.position): return false
		if not raw.vertices is Array or raw.vertices.size() != 4: return false
		var vertices: PackedVector2Array = PackedVector2Array()
		for raw_vertex: Variant in raw.vertices:
			if not _vector_array(raw_vertex): return false
			vertices.append(Vector2(raw_vertex[0], raw_vertex[1]))
		checked.append({"id": int(raw.id), "material_id": str(raw.material_id), "kind": str(raw.kind), "position": Vector2(raw.position[0], raw.position[1]), "vertices": vertices})
		ids.append(int(raw.id))
	if int(data.selected_id) != -1 and not ids.has(int(data.selected_id)): return false
	if not _valid_parts(checked) or _cost(checked) > budget_limit: return false
	parts = checked
	selected_id = int(data.selected_id)
	_next_id = int(data.next_id)
	revision = int(data.revision)
	command_manager.clear()
	return true

func _new_part(material_id: String, position: Vector2, kind: String, id: int) -> Dictionary:
	var material: Dictionary = Catalog.material(material_id)
	if material.is_empty(): return {}
	var family: String = str(material.kind) if kind.is_empty() else kind
	if not material.kinds.has(family): return {}
	return {"id": id, "material_id": material_id, "kind": family, "position": snapped_position(material_id, position, family), "vertices": Math.create_vertices(family, material.dimensions)}

func _candidate_error(candidate: Dictionary, ignore_id: int) -> String:
	if not _valid_part(candidate): return "땅 위의 건축 공간 안에 재료를 놓아 주세요."
	var existing_cost: int = 0
	for item: Dictionary in parts:
		if int(item.id) == ignore_id:
			existing_cost = int(Catalog.material(str(item.material_id)).price)
			continue
		if _conflict(candidate, item):
			if bool(Catalog.material(str(candidate.material_id)).opening) or bool(Catalog.material(str(item.material_id)).opening):
				return "문·창문 자리에는 벽돌을 놓을 수 없어요. 주변을 쌓아 주세요."
			return "다른 재료와 겹쳐요. 빈자리에 맞춰 주세요."
	if material_cost() - existing_cost + int(Catalog.material(str(candidate.material_id)).price) > budget_limit:
		return "자재 예산이 부족해요. 다른 재료를 고르거나 일부를 되돌려 주세요."
	return ""

func _replace_selected(selected: Dictionary) -> bool:
	var after: Dictionary = _snapshot()
	for index: int in range(after.parts.size()):
		if int(after.parts[index].id) == selected_id:
			after.parts[index] = selected
			_commit(after)
			return true
	return false

func _snapshot() -> Dictionary:
	return {"parts": parts.duplicate(true), "selected_id": selected_id, "next_id": _next_id}

func _commit(after: Dictionary) -> void:
	command_manager.push_snapshot(self, &"_apply", _snapshot(), after)

func _apply(snapshot: Dictionary) -> void:
	parts.assign(snapshot.parts)
	selected_id = int(snapshot.selected_id)
	_next_id = int(snapshot.next_id)
	revision += 1

static func _cost(items: Array[Dictionary]) -> int:
	var total: int = 0
	for item: Dictionary in items:
		var material: Dictionary = Catalog.material(str(item.material_id))
		if material.is_empty(): return 1000000000
		total += int(material.price)
	return total

static func _valid_parts(items: Array[Dictionary]) -> bool:
	if items.size() > MAX_PARTS: return false
	for index: int in range(items.size()):
		if not _valid_part(items[index]): return false
		for previous: int in range(index):
			if _conflict(items[index], items[previous]): return false
	return true

static func _valid_part(item: Dictionary) -> bool:
	if not item.has_all(["material_id", "kind", "position", "vertices"]): return false
	var material: Dictionary = Catalog.material(str(item.material_id))
	if material.is_empty() or not material.kinds.has(str(item.kind)): return false
	if not item.position is Vector2 or not item.position.is_finite() or not item.vertices is PackedVector2Array: return false
	var vertices: PackedVector2Array = item.vertices
	if not Math.matches_kind(vertices, str(item.kind)): return false
	var canonical: PackedVector2Array = Math.create_vertices(str(item.kind), material.dimensions)
	var center: Vector2 = Vector2.ZERO
	for index: int in range(4):
		center += vertices[index]
		# Distances preserve catalog dimensions under rotation; scale edits cannot buy oversized parts cheaply.
		for other: int in range(index + 1, 4):
			if absf(vertices[index].distance_to(vertices[other]) - canonical[index].distance_to(canonical[other])) > 0.05: return false
	if center.length() > 0.05: return false
	var bounds: Rect2 = Math.bounds(world_vertices(item))
	return Rect2(0, 0, BOARD.size.x, GROUND_Y).grow(0.01).encloses(bounds)

static func _conflict(first: Dictionary, second: Dictionary) -> bool:
	var a: Dictionary = Catalog.material(str(first.material_id))
	var b: Dictionary = Catalog.material(str(second.material_id))
	# Decoration is attached to real wall surfaces, never painted across a reserved aperture.
	if (str(a.role) == "decor" and bool(b.structural)) or (str(b.role) == "decor" and bool(a.structural)):
		return false
	return polygons_overlap(world_vertices(first), world_vertices(second))

static func polygons_overlap(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	# Separating-axis test for convex quadrilaterals. Shared edges are legal mortar contacts.
	for polygon: PackedVector2Array in [first, second]:
		for index: int in range(polygon.size()):
			var axis: Vector2 = (polygon[(index + 1) % polygon.size()] - polygon[index]).orthogonal().normalized()
			var min_a: float = INF
			var max_a: float = -INF
			var min_b: float = INF
			var max_b: float = -INF
			for vertex: Vector2 in first:
				min_a = minf(min_a, vertex.dot(axis))
				max_a = maxf(max_a, vertex.dot(axis))
			for vertex: Vector2 in second:
				min_b = minf(min_b, vertex.dot(axis))
				max_b = maxf(max_b, vertex.dot(axis))
			if minf(max_a, max_b) - maxf(min_a, min_b) <= 0.05: return false
	return true

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float): return false
	var number: float = float(value)
	return is_finite(number) and number == floor(number) and number >= minimum and number <= maximum

static func _vector_array(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for number: Variant in value:
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return true
