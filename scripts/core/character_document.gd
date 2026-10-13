class_name CharacterDocument
extends RefCounted

const Math = preload("res://scripts/core/quadrilateral_math.gd")
const Templates = preload("res://scripts/core/character_templates.gd")
const History = preload("res://scripts/core/command_manager.gd")
const MAX_SHAPES: int = 128
const GROUPS: Array[String] = ["body", "head", "arm_left", "arm_right", "leg_left", "leg_right"]

signal changed

var template_id: String = "robot"
var shapes: Array[Dictionary] = []
var selected_id: int = -1
var command_manager: History = History.new()
var _next_id: int = 1

func _init() -> void:
	command_manager.state_changed.connect(_on_history_changed)

func _on_history_changed() -> void:
	changed.emit()

func set_template(id: String) -> void:
	if Templates.get_template(id).is_empty() or id == template_id:
		return
	var after: Dictionary = _snapshot()
	after.template_id = id
	after.shapes = []
	after.selected_id = -1
	_commit(after)

func fill_slot(slot_id: String, kind: String, color: Color) -> bool:
	var slot: Dictionary = get_slot(slot_id)
	if slot.is_empty() or str(slot.kind) != kind or not _valid_color(color):
		return false
	var existing: Dictionary = shape_for_slot(slot_id)
	if not existing.is_empty():
		select_shape(int(existing.id))
		set_color(color)
		return true
	if shapes.size() >= MAX_SHAPES:
		return false
	var after: Dictionary = _snapshot()
	var shape: Dictionary = _shape_from_slot(slot, _next_id, color)
	after.shapes.append(shape)
	after.selected_id = _next_id
	after.next_id = _next_id + 1
	_commit(after)
	return true

func add_shape(kind: String, position: Vector2, color: Color) -> int:
	if not Math.KINDS.has(kind) or not _valid_position(position) or not _valid_color(color) or shapes.size() >= MAX_SHAPES:
		return -1
	var dimensions: Vector2 = Vector2(70, 70)
	if kind == "rhombus":
		dimensions = Vector2(72, 98)
	elif kind == "rectangle":
		dimensions = Vector2(92, 58)
	elif kind == "trapezoid" or kind == "parallelogram":
		dimensions = Vector2(88, 64)
	var after: Dictionary = _snapshot()
	var new_id: int = _next_id
	after.shapes.append({"id": new_id, "slot_id": "", "kind": kind, "position": position, "vertices": Math.create_vertices(kind, dimensions), "color": color, "group": "body"})
	after.selected_id = new_id
	after.next_id = new_id + 1
	_commit(after)
	return new_id

func select_shape(id: int) -> void:
	var valid_id: int = id if _shape_index(id) >= 0 else -1
	if selected_id != valid_id:
		selected_id = valid_id
		changed.emit()

func get_selected() -> Dictionary:
	var index: int = _shape_index(selected_id)
	return shapes[index].duplicate(true) if index >= 0 else {}

func set_color(color: Color) -> void:
	if not _valid_color(color):
		return
	_edit_selected("color", color)

func move_selected(position: Vector2) -> void:
	if _valid_position(position):
		_edit_selected("position", position)

func rotate_selected(degrees: float) -> void:
	var selected: Dictionary = get_selected()
	if selected.is_empty() or not is_finite(degrees):
		return
	_edit_selected("vertices", Math.rotate_vertices(selected.vertices, degrees))

func scale_selected(factor: float) -> void:
	var selected: Dictionary = get_selected()
	if selected.is_empty() or not is_finite(factor) or factor <= 0.0:
		return
	var vertices: PackedVector2Array = Math.scale_vertices(selected.vertices, factor)
	if _valid_vertices(vertices, str(selected.kind)):
		_edit_selected("vertices", vertices)

func duplicate_selected() -> void:
	var selected: Dictionary = get_selected()
	if selected.is_empty() or shapes.size() >= MAX_SHAPES:
		return
	var duplicated_position: Vector2 = selected.position + Vector2(24, 24)
	if not _valid_position(duplicated_position):
		return
	var after: Dictionary = _snapshot()
	selected.id = _next_id
	selected.slot_id = ""
	selected.position = duplicated_position
	after.shapes.append(selected)
	after.selected_id = _next_id
	after.next_id = _next_id + 1
	_commit(after)

func delete_selected() -> void:
	var index: int = _shape_index(selected_id)
	if index < 0:
		return
	var after: Dictionary = _snapshot()
	after.shapes.remove_at(index)
	after.selected_id = -1
	_commit(after)

func attach_selected(slot_id: String) -> bool:
	var selected: Dictionary = get_selected()
	var slot: Dictionary = get_slot(slot_id)
	if selected.is_empty() or slot.is_empty() or str(selected.kind) != str(slot.kind):
		return false
	var occupied: Dictionary = shape_for_slot(slot_id)
	if not occupied.is_empty() and int(occupied.id) != selected_id:
		return false
	var after: Dictionary = _snapshot()
	var index: int = _shape_index(selected_id)
	after.shapes[index] = _shape_from_slot(slot, selected_id, selected.color)
	_commit(after)
	return true

func fill_example() -> void:
	var after: Dictionary = _snapshot()
	var next_id: int = _next_id
	var template: Dictionary = Templates.get_template(template_id)
	for slot: Dictionary in template.parts:
		if shape_for_slot(str(slot.id)).is_empty():
			if after.shapes.size() >= MAX_SHAPES:
				break
			after.shapes.append(_shape_from_slot(slot, next_id, slot.color))
			next_id += 1
		after.next_id = next_id
	after.selected_id = -1
	_commit(after)

func clear() -> void:
	if shapes.is_empty():
		return
	var after: Dictionary = _snapshot()
	after.shapes = []
	after.selected_id = -1
	_commit(after)

func undo() -> void:
	command_manager.undo()

func redo() -> void:
	command_manager.redo()

func can_undo() -> bool:
	return command_manager.can_undo()

func can_redo() -> bool:
	return command_manager.can_redo()

func completion() -> Dictionary:
	var template: Dictionary = Templates.get_template(template_id)
	var filled: int = 0
	for slot: Dictionary in template.parts:
		var shape: Dictionary = shape_for_slot(str(slot.id))
		if not shape.is_empty() and _fits_slot(shape, slot):
			filled += 1
	var total: int = template.parts.size()
	return {"filled": filled, "total": total, "ready": total > 0 and filled == total}

func character_data() -> Dictionary:
	return {"template_id": template_id, "parts": ordered_shapes()}

func ordered_shapes() -> Array[Dictionary]:
	# Preserve skeleton draw order regardless of the order in which slots are painted.
	var result: Array[Dictionary] = []
	var template: Dictionary = Templates.get_template(template_id)
	for slot: Dictionary in template.parts:
		var shape: Dictionary = shape_for_slot(str(slot.id))
		if not shape.is_empty():
			result.append(shape)
	for shape: Dictionary in shapes:
		if str(shape.slot_id).is_empty():
			result.append(shape.duplicate(true))
	return result

func get_slot(slot_id: String) -> Dictionary:
	var template: Dictionary = Templates.get_template(template_id)
	for slot: Dictionary in template.parts:
		if str(slot.id) == slot_id:
			return slot.duplicate(true)
	return {}

func shape_for_slot(slot_id: String) -> Dictionary:
	for shape: Dictionary in shapes:
		if str(shape.slot_id) == slot_id:
			return shape.duplicate(true)
	return {}

func serialize() -> Dictionary:
	var encoded: Array[Dictionary] = []
	for shape: Dictionary in shapes:
		var points: Array[Array] = []
		for vertex: Vector2 in shape.vertices:
			points.append([vertex.x, vertex.y])
		var position: Vector2 = shape.position
		var color: Color = shape.color
		encoded.append({"id": shape.id, "slot_id": shape.slot_id, "kind": shape.kind, "position": [position.x, position.y], "vertices": points, "color": [color.r, color.g, color.b, color.a], "group": shape.group})
	return {"version": 1, "template_id": template_id, "shapes": encoded, "selected_id": selected_id}

func restore(data: Dictionary) -> bool:
	# Decode every value before touching the live document or its undo history.
	if not _integer(data.get("version", null)) or int(data.version) != 1:
		return false
	if not data.get("template_id", null) is String or not data.get("shapes", null) is Array:
		return false
	var template: Dictionary = Templates.get_template(str(data.template_id))
	if template.is_empty() or data.shapes.size() > MAX_SHAPES:
		return false
	var decoded: Array[Dictionary] = []
	var used_ids: Dictionary = {}
	var used_slots: Dictionary = {}
	var next_id: int = 1
	for value: Variant in data.shapes:
		if not value is Dictionary:
			return false
		var raw: Dictionary = value
		if not _integer(raw.get("id", null)) or int(raw.id) <= 0 or int(raw.id) > 1000000 or used_ids.has(int(raw.id)):
			return false
		if not raw.get("kind", null) is String or not Math.KINDS.has(str(raw.kind)):
			return false
		if not raw.get("slot_id", null) is String or not raw.get("group", null) is String or not GROUPS.has(str(raw.group)):
			return false
		if not _number_array(raw.get("position", null), 2) or not _number_array(raw.get("color", null), 4):
			return false
		var position: Vector2 = Vector2(float(raw.position[0]), float(raw.position[1]))
		var color: Color = Color(float(raw.color[0]), float(raw.color[1]), float(raw.color[2]), float(raw.color[3]))
		if not _valid_position(position) or not _valid_color(color):
			return false
		if not raw.get("vertices", null) is Array or raw.vertices.size() != 4:
			return false
		var vertices: PackedVector2Array = PackedVector2Array()
		for point: Variant in raw.vertices:
			if not _number_array(point, 2):
				return false
			vertices.append(Vector2(float(point[0]), float(point[1])))
		if not _valid_vertices(vertices, str(raw.kind)):
			return false
		var slot_id: String = str(raw.slot_id)
		if not slot_id.is_empty():
			if used_slots.has(slot_id):
				return false
			var matching_slot: Dictionary = {}
			for slot: Dictionary in template.parts:
				if str(slot.id) == slot_id:
					matching_slot = slot
			if matching_slot.is_empty() or str(matching_slot.kind) != str(raw.kind) or str(matching_slot.group) != str(raw.group):
				return false
			used_slots[slot_id] = true
		used_ids[int(raw.id)] = true
		next_id = maxi(next_id, int(raw.id) + 1)
		decoded.append({"id": int(raw.id), "slot_id": slot_id, "kind": str(raw.kind), "position": position, "vertices": vertices, "color": color, "group": str(raw.group)})
	if not _integer(data.get("selected_id", -1)):
		return false
	var selected: int = int(data.get("selected_id", -1))
	if selected != -1 and not used_ids.has(selected):
		return false
	_commit({"template_id": str(data.template_id), "shapes": decoded, "selected_id": selected, "next_id": next_id})
	return true

func _edit_selected(property: String, value: Variant) -> void:
	var index: int = _shape_index(selected_id)
	if index < 0 or shapes[index][property] == value:
		return
	var after: Dictionary = _snapshot()
	after.shapes[index][property] = value
	_commit(after)

func _shape_index(id: int) -> int:
	for index: int in range(shapes.size()):
		if int(shapes[index].id) == id:
			return index
	return -1

func _snapshot() -> Dictionary:
	return {"template_id": template_id, "shapes": shapes.duplicate(true), "selected_id": selected_id, "next_id": _next_id}

func _commit(after: Dictionary) -> void:
	var before: Dictionary = _snapshot()
	if before == after:
		return
	command_manager.push_snapshot(self, &"_apply_snapshot", before, after)

func _apply_snapshot(data: Dictionary) -> void:
	template_id = str(data.template_id)
	shapes.assign(data.shapes.duplicate(true))
	selected_id = int(data.selected_id)
	_next_id = int(data.next_id)

static func _shape_from_slot(slot: Dictionary, id: int, color: Color) -> Dictionary:
	return {"id": id, "slot_id": str(slot.id), "kind": str(slot.kind), "position": slot.position, "vertices": slot.vertices.duplicate(), "color": color, "group": str(slot.group)}

static func _fits_slot(shape: Dictionary, slot: Dictionary) -> bool:
	var shape_position: Vector2 = shape.position
	var slot_position: Vector2 = slot.position
	var area_ratio: float = absf(Math.signed_area(shape.vertices)) / absf(Math.signed_area(slot.vertices))
	return shape_position.distance_to(slot_position) <= 28.0 and area_ratio >= 0.3 and area_ratio <= 3.0 and Math.matches_kind(shape.vertices, str(slot.kind))

static func _valid_position(position: Vector2) -> bool:
	return position.is_finite() and absf(position.x) <= 1500.0 and absf(position.y) <= 1500.0

static func _valid_color(color: Color) -> bool:
	return is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a) and color.r >= 0.0 and color.r <= 1.0 and color.g >= 0.0 and color.g <= 1.0 and color.b >= 0.0 and color.b <= 1.0 and color.a >= 0.25 and color.a <= 1.0

static func _valid_vertices(vertices: PackedVector2Array, kind: String) -> bool:
	if not Math.matches_kind(vertices, kind):
		return false
	for vertex: Vector2 in vertices:
		if absf(vertex.x) > 600.0 or absf(vertex.y) > 600.0:
			return false
	return true

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

static func _number_array(value: Variant, length: int) -> bool:
	if not value is Array or value.size() != length:
		return false
	for item: Variant in value:
		if not (item is int or item is float) or not is_finite(float(item)):
			return false
	return true
