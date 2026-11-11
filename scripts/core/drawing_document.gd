class_name DrawingDocument
extends "res://scripts/core/character_document.gd"

const ARTBOARD: Rect2 = Rect2(-480.0, -300.0, 960.0, 600.0)
const Catalog = preload("res://scripts/core/drawing_catalog.gd")
const MIN_SIDE_LENGTH: float = 4.0

var background_id: String = "paper"
var drawing_mode: String = "free"
var masterpiece_id: String = ""
var _selection: Array[int] = []
# Drawing groups are independent of the inherited character animation tags.
var _groups: Array[Array] = []

func select_shape(id: int) -> void:
	var ids: Array[int] = []
	if _shape_index(id) >= 0:
		ids.append(id)
	_set_selection(ids, id)

func select_shapes(ids: Array[int], additive: bool = false) -> void:
	var requested: Array[int] = []
	if additive:
		requested = get_selected_ids()
	requested.append_array(ids)
	var primary: int = selected_id if additive else -1
	for id: int in ids:
		if _shape_index(id) >= 0:
			primary = id
	_set_selection(requested, primary)

func toggle_shape_selection(id: int) -> void:
	if _shape_index(id) < 0:
		return
	var ids: Array[int] = get_selected_ids()
	var unit: Array[int] = _expanded_selection([id], shapes, _groups)
	if ids.has(id):
		for member: int in unit:
			ids.erase(member)
		_set_selection(ids, selected_id)
	else:
		ids.append_array(unit)
		_set_selection(ids, id)

func get_selected_ids() -> Array[int]:
	if selected_id < 0:
		return []
	if _selection.has(selected_id):
		return _selection.duplicate()
	return _expanded_selection([selected_id], shapes, _groups)

func _set_selection(ids: Array[int], primary: int) -> void:
	var expanded: Array[int] = _expanded_selection(ids, shapes, _groups)
	var next_primary: int = _primary_id(expanded, primary)
	if expanded == _selection and next_primary == selected_id:
		return
	_selection = expanded
	selected_id = next_primary
	changed.emit()

static func _primary_id(ids: Array[int], preferred: int) -> int:
	if ids.has(preferred):
		return preferred
	return ids[-1] if not ids.is_empty() else -1

static func _expanded_selection(ids: Array[int], parts: Array[Dictionary], groups: Array[Array]) -> Array[int]:
	var requested: Dictionary = _id_set(ids)
	for group: Array in groups:
		if _includes_member(group, requested):
			for id: int in group:
				requested[id] = true
	var result: Array[int] = []
	for part: Dictionary in parts:
		if requested.has(int(part.id)):
			result.append(int(part.id))
	return result

static func _includes_member(group: Array, ids: Dictionary) -> bool:
	for id: int in group:
		if ids.has(id):
			return true
	return false

static func _id_set(ids: Array[int]) -> Dictionary:
	var result: Dictionary = {}
	for id: int in ids:
		result[id] = true
	return result

func can_group_selection() -> bool:
	var ids: Array[int] = get_selected_ids()
	if ids.size() < 2:
		return false
	for group: Array in _groups:
		if group.size() == ids.size() and group.has(ids[0]):
			return false
	return true

func group_selected() -> bool:
	if not can_group_selection():
		return false
	var ids: Array[int] = get_selected_ids()
	var after: Dictionary = _snapshot()
	var groups: Array[Array] = _groups_excluding(ids)
	groups.append(ids)
	after.groups = groups
	_commit(after)
	return true

func can_ungroup_selection() -> bool:
	var ids: Dictionary = _id_set(get_selected_ids())
	for group: Array in _groups:
		if _includes_member(group, ids):
			return true
	return false

func ungroup_selected() -> bool:
	if not can_ungroup_selection():
		return false
	var after: Dictionary = _snapshot()
	after.groups = _groups_excluding(get_selected_ids())
	_commit(after)
	return true

func _groups_excluding(ids: Array[int]) -> Array[Array]:
	var excluded: Dictionary = _id_set(ids)
	var remaining: Array[Array] = []
	for group: Array in _groups:
		if not _includes_member(group, excluded):
			remaining.append(group.duplicate())
	return remaining

func selected_bounds() -> Rect2:
	return _selection_bounds(shapes, _id_set(get_selected_ids()))

static func _selection_bounds(parts: Array[Dictionary], ids: Dictionary) -> Rect2:
	var bounds: Rect2 = Rect2()
	var initialized: bool = false
	for part: Dictionary in parts:
		if not ids.has(int(part.id)):
			continue
		var part_bounds: Rect2 = Math.bounds(part.vertices)
		part_bounds.position += Vector2(part.position)
		bounds = bounds.merge(part_bounds) if initialized else part_bounds
		initialized = true
	return bounds

func constrained_selection_delta(delta: Vector2) -> Vector2:
	if not delta.is_finite() or get_selected_ids().is_empty():
		return Vector2.ZERO
	return _fitted_delta(selected_bounds(), delta)

static func _fitted_delta(bounds: Rect2, delta: Vector2) -> Vector2:
	return delta.clamp(ARTBOARD.position - bounds.position, ARTBOARD.end - bounds.end)

func move_selection(delta: Vector2) -> void:
	var movement: Vector2 = constrained_selection_delta(delta)
	if movement == Vector2.ZERO:
		return
	var ids: Dictionary = _id_set(get_selected_ids())
	var after: Dictionary = _snapshot()
	_translate_parts(after.shapes, ids, movement)
	_commit(after)

static func _translate_parts(parts: Array[Dictionary], ids: Dictionary, delta: Vector2) -> void:
	for part: Dictionary in parts:
		if ids.has(int(part.id)):
			part.position = Vector2(part.position) + delta

func set_background(id: String) -> bool:
	if id != "paper" and Catalog.background(id).is_empty():
		return false
	var after: Dictionary = _snapshot()
	after.background_id = id
	_commit(after)
	return true

func set_mode(mode: String) -> bool:
	if mode not in ["free", "masterpiece"] or (mode == "masterpiece" and masterpiece_id.is_empty()):
		return false
	var after: Dictionary = _snapshot()
	after.drawing_mode = mode
	_commit(after)
	return true

func set_masterpiece(id: String) -> bool:
	if Catalog.masterpiece(id).is_empty():
		return false
	var after: Dictionary = _snapshot()
	after.masterpiece_id = id
	after.drawing_mode = "masterpiece"
	_commit(after)
	return true

func add_shape(kind: String, position: Vector2, color: Color, trapezoid_variant: String = "symmetric") -> int:
	return add_sized_shape(kind, position, Vector2(100, 80), color, trapezoid_variant)

func add_sized_shape(kind: String, position: Vector2, dimensions: Vector2, color: Color, trapezoid_variant: String = "symmetric") -> int:
	if not Math.KINDS.has(kind) or not position.is_finite() or not dimensions.is_finite() or not _valid_color(color) or shapes.size() >= MAX_SHAPES:
		return -1
	var extent: Vector2 = dimensions.abs().clamp(Vector2(12, 12), ARTBOARD.size)
	var vertices: PackedVector2Array = Math.create_vertices(kind, extent, trapezoid_variant)
	if not _valid_vertices(vertices, kind):
		return -1
	var after: Dictionary = _snapshot()
	var new_id: int = _next_id
	after.shapes.append({"id": new_id, "slot_id": "", "kind": kind, "position": fitted_position(vertices, position), "vertices": vertices, "color": color, "group": "body"})
	after.selected_id = new_id
	after.selected_ids = [new_id]
	after.next_id = new_id + 1
	_commit(after)
	return new_id

func move_selected(position: Vector2) -> void:
	var selected: Dictionary = get_selected()
	if not selected.is_empty() and position.is_finite():
		if get_selected_ids().size() == 1:
			_edit_selected("position", fitted_position(selected.vertices, position))
		else:
			move_selection(position - Vector2(selected.position))

func rotate_selected(degrees: float) -> void:
	var selected: Dictionary = get_selected()
	if not selected.is_empty() and is_finite(degrees):
		if get_selected_ids().size() == 1:
			_transform_selected(Math.rotate_vertices(selected.vertices, degrees))
		else:
			_transform_selection(degrees, 1.0)

func scale_selected(factor: float) -> void:
	var selected: Dictionary = get_selected()
	if not selected.is_empty() and is_finite(factor) and factor > 0.0:
		if get_selected_ids().size() == 1:
			_transform_selected(Math.scale_vertices(selected.vertices, factor))
		else:
			_transform_selection(0.0, factor)

func _transform_selection(degrees: float, factor: float) -> void:
	if degrees == 0.0 and factor == 1.0:
		return
	var pivot: Vector2 = selected_bounds().get_center()
	var ids: Dictionary = _id_set(get_selected_ids())
	var radians: float = deg_to_rad(degrees)
	var after: Dictionary = _snapshot()
	for part: Dictionary in after.shapes:
		if not ids.has(int(part.id)):
			continue
		var offset: Vector2 = (Vector2(part.position) - pivot) * factor
		var position: Vector2 = pivot + offset.rotated(radians)
		var vertices: PackedVector2Array = Math.rotate_vertices(Math.scale_vertices(part.vertices, factor), degrees)
		if not position.is_finite() or not _valid_transform_vertices(vertices, str(part.kind)):
			return
		part.position = position
		part.vertices = vertices
	var bounds: Rect2 = _selection_bounds(after.shapes, ids)
	if bounds.size.x > ARTBOARD.size.x or bounds.size.y > ARTBOARD.size.y:
		return
	_translate_parts(after.shapes, ids, _fitted_delta(bounds, Vector2.ZERO))
	_commit(after)

func _transform_selected(vertices: PackedVector2Array) -> void:
	var selected: Dictionary = get_selected()
	if not selected.is_empty():
		transform_selected(vertices, Vector2(selected.position))

## A whole pointer gesture commits geometry and position in one undo operation.
func transform_selected(vertices: PackedVector2Array, position: Vector2) -> void:
	var selected: Dictionary = get_selected()
	if selected.is_empty() or get_selected_ids().size() != 1 or not position.is_finite():
		return
	if not _valid_transform_vertices(vertices, str(selected.kind)):
		return
	var after: Dictionary = _snapshot()
	var index: int = _shape_index(selected_id)
	after.shapes[index].vertices = vertices.duplicate()
	after.shapes[index].position = fitted_position(vertices, position)
	_commit(after)

static func _valid_transform_vertices(vertices: PackedVector2Array, kind: String) -> bool:
	if not _valid_vertices(vertices, kind):
		return false
	var bounds: Rect2 = Math.bounds(vertices)
	if bounds.size.x > ARTBOARD.size.x or bounds.size.y > ARTBOARD.size.y:
		return false
	for length: float in Math.side_lengths(vertices):
		if length < MIN_SIDE_LENGTH:
			return false
	return true

func set_color(color: Color) -> void:
	var ids: Dictionary = _id_set(get_selected_ids())
	if ids.is_empty() or not _valid_color(color):
		return
	var after: Dictionary = _snapshot()
	for part: Dictionary in after.shapes:
		if ids.has(int(part.id)):
			part.color = color
	_commit(after)

func duplicate_selected() -> void:
	var ids: Dictionary = _id_set(get_selected_ids())
	if ids.is_empty() or shapes.size() + ids.size() > MAX_SHAPES:
		return
	var after: Dictionary = _snapshot()
	var movement: Vector2 = constrained_selection_delta(Vector2(24, 24))
	var copies: Dictionary = {}
	var next_id: int = _next_id
	var copied_ids: Array[int] = []
	for part: Dictionary in shapes:
		var source_id: int = int(part.id)
		if not ids.has(source_id):
			continue
		var copy: Dictionary = part.duplicate(true)
		copies[source_id] = next_id
		copy.id = next_id
		copy.position = Vector2(part.position) + movement
		after.shapes.append(copy)
		copied_ids.append(next_id)
		next_id += 1
	for group: Array in _groups:
		if not copies.has(group[0]):
			continue
		var copied_group: Array[int] = []
		for id: int in group:
			copied_group.append(int(copies[id]))
		after.groups.append(copied_group)
	after.selected_ids = copied_ids
	after.selected_id = int(copies[selected_id])
	after.next_id = next_id
	_commit(after)

func delete_selected() -> void:
	var ids: Array[int] = get_selected_ids()
	if ids.is_empty():
		return
	var removed: Dictionary = _id_set(ids)
	var after: Dictionary = _snapshot()
	var remaining: Array[Dictionary] = []
	for part: Dictionary in after.shapes:
		if not removed.has(int(part.id)):
			remaining.append(part)
	after.shapes = remaining
	after.groups = _groups_excluding(ids)
	after.selected_ids = []
	after.selected_id = -1
	_commit(after)

func can_shift_selection_layer(direction: int) -> bool:
	if direction == 0:
		return false
	var ids: Dictionary = _id_set(get_selected_ids())
	var step: int = 1 if direction > 0 else -1
	for index: int in range(shapes.size()):
		var neighbor: int = index + step
		if neighbor >= 0 and neighbor < shapes.size() and ids.has(int(shapes[index].id)) and not ids.has(int(shapes[neighbor].id)):
			return true
	return false

func shift_selected_layer(direction: int) -> void:
	if not can_shift_selection_layer(direction):
		return
	var ids: Dictionary = _id_set(get_selected_ids())
	var step: int = 1 if direction > 0 else -1
	var after: Dictionary = _snapshot()
	# Scan from the destination end so adjacent selected shapes retain their order.
	for offset: int in range(1, shapes.size()):
		var index: int = shapes.size() - 1 - offset if step > 0 else offset
		var neighbor: int = index + step
		var part: Dictionary = after.shapes[index]
		var other: Dictionary = after.shapes[neighbor]
		if ids.has(int(part.id)) and not ids.has(int(other.id)):
			after.shapes[index] = other
			after.shapes[neighbor] = part
	_commit(after)

func ordered_shapes() -> Array[Dictionary]:
	return shapes.duplicate(true)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data.scene = {"background_id": background_id, "drawing_mode": drawing_mode, "masterpiece_id": masterpiece_id}
	if not _groups.is_empty():
		data.groups = _groups.duplicate(true)
	var ids: Array[int] = get_selected_ids()
	if ids.size() > 1:
		data.selected_ids = ids
	return data

func restore(data: Dictionary) -> bool:
	# Missing scene metadata is the original v1 format: restore a plain free drawing.
	var scene_data: Dictionary = {"background_id": "paper", "drawing_mode": "free", "masterpiece_id": ""}
	if data.has("scene"):
		if not data.scene is Dictionary:
			return false
		scene_data = data.scene
	if not _valid_scene(scene_data):
		return false
	var checked: CharacterDocument = CharacterDocument.new()
	if not checked.restore(data) or checked.template_id != "robot":
		return false
	var next_id: int = 1
	var known_ids: Dictionary = {}
	for part: Dictionary in checked.shapes:
		if not str(part.slot_id).is_empty():
			return false
		var bounds: Rect2 = Math.bounds(part.vertices)
		bounds.position += Vector2(part.position)
		if not ARTBOARD.grow(0.01).encloses(bounds):
			return false
		next_id = maxi(next_id, int(part.id) + 1)
		known_ids[int(part.id)] = true
	var restored_groups: Variant = _decode_groups(data.get("groups", []), known_ids)
	if restored_groups == null:
		return false
	var groups: Array[Array] = []
	groups.assign(restored_groups)
	var selection: Array[int] = []
	if data.has("selected_ids"):
		var restored_selection: Variant = _decode_ids(data.selected_ids, known_ids)
		if restored_selection == null:
			return false
		selection.assign(restored_selection)
		if selection.is_empty() != (checked.selected_id == -1):
			return false
		if not selection.is_empty() and not selection.has(checked.selected_id):
			return false
	elif checked.selected_id != -1:
		selection.append(checked.selected_id)
	var after: Dictionary = _snapshot()
	after.template_id = checked.template_id
	after.shapes = checked.shapes.duplicate(true)
	after.selected_id = checked.selected_id
	after.selected_ids = _expanded_selection(selection, checked.shapes, groups)
	after.groups = groups
	after.next_id = next_id
	after.background_id = str(scene_data.background_id)
	after.drawing_mode = str(scene_data.drawing_mode)
	after.masterpiece_id = str(scene_data.masterpiece_id)
	_commit(after)
	return true

static func _decode_ids(value: Variant, known_ids: Dictionary) -> Variant:
	if not value is Array or value.size() > known_ids.size():
		return null
	var ids: Array[int] = []
	var seen: Dictionary = {}
	for raw_id: Variant in value:
		if not _integer(raw_id):
			return null
		var id: int = int(raw_id)
		if not known_ids.has(id) or seen.has(id):
			return null
		ids.append(id)
		seen[id] = true
	return ids

static func _decode_groups(value: Variant, known_ids: Dictionary) -> Variant:
	if not value is Array or value.size() * 2 > known_ids.size():
		return null
	var groups: Array[Array] = []
	var used: Dictionary = {}
	for raw_group: Variant in value:
		var group: Variant = _decode_ids(raw_group, known_ids)
		if group == null or group.size() < 2 or _includes_member(group, used):
			return null
		for id: int in group:
			used[id] = true
		groups.append(group)
	return groups

func _snapshot() -> Dictionary:
	var data: Dictionary = super._snapshot()
	data.selected_ids = get_selected_ids()
	data.groups = _groups.duplicate(true)
	data.background_id = background_id
	data.drawing_mode = drawing_mode
	data.masterpiece_id = masterpiece_id
	return data

func _apply_snapshot(data: Dictionary) -> void:
	super._apply_snapshot(data)
	_groups.assign(data.groups.duplicate(true))
	if shapes.is_empty():
		_groups.clear()
	var ids: Array[int] = []
	if selected_id >= 0:
		ids.assign(data.selected_ids)
		if not ids.has(selected_id):
			ids.assign([selected_id])
	_selection = _expanded_selection(ids, shapes, _groups)
	selected_id = _primary_id(_selection, selected_id)
	background_id = str(data.background_id)
	drawing_mode = str(data.drawing_mode)
	masterpiece_id = str(data.masterpiece_id)

static func _valid_scene(data: Dictionary) -> bool:
	if not data.get("background_id") is String or not data.get("drawing_mode") is String or not data.get("masterpiece_id") is String:
		return false
	var background: String = str(data.background_id)
	var mode: String = str(data.drawing_mode)
	var masterpiece: String = str(data.masterpiece_id)
	if background != "paper" and Catalog.background(background).is_empty():
		return false
	if mode not in ["free", "masterpiece"]:
		return false
	if not masterpiece.is_empty() and Catalog.masterpiece(masterpiece).is_empty():
		return false
	return mode != "masterpiece" or not masterpiece.is_empty()

static func fitted_position(vertices: PackedVector2Array, position: Vector2) -> Vector2:
	var bounds: Rect2 = Math.bounds(vertices)
	return position.clamp(ARTBOARD.position - bounds.position, ARTBOARD.end - bounds.end)
