class_name DrawingDocument
extends "res://scripts/core/character_document.gd"

const ARTBOARD: Rect2 = Rect2(-480.0, -300.0, 960.0, 600.0)
const Catalog = preload("res://scripts/core/drawing_catalog.gd")
const MIN_SIDE_LENGTH: float = 4.0

var background_id: String = "paper"
var drawing_mode: String = "free"
var masterpiece_id: String = ""

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

func add_shape(kind: String, position: Vector2, color: Color) -> int:
	return add_sized_shape(kind, position, Vector2(100, 80), color)

func add_sized_shape(kind: String, position: Vector2, dimensions: Vector2, color: Color) -> int:
	if not Math.KINDS.has(kind) or not position.is_finite() or not dimensions.is_finite() or not _valid_color(color) or shapes.size() >= MAX_SHAPES:
		return -1
	var extent: Vector2 = dimensions.abs().clamp(Vector2(12, 12), ARTBOARD.size)
	var vertices: PackedVector2Array = Math.create_vertices(kind, extent)
	if not _valid_vertices(vertices, kind):
		return -1
	var after: Dictionary = _snapshot()
	var new_id: int = _next_id
	after.shapes.append({"id": new_id, "slot_id": "", "kind": kind, "position": fitted_position(vertices, position), "vertices": vertices, "color": color, "group": "body"})
	after.selected_id = new_id
	after.next_id = new_id + 1
	_commit(after)
	return new_id

func move_selected(position: Vector2) -> void:
	var selected: Dictionary = get_selected()
	if not selected.is_empty() and position.is_finite():
		_edit_selected("position", fitted_position(selected.vertices, position))

func rotate_selected(degrees: float) -> void:
	var selected: Dictionary = get_selected()
	if not selected.is_empty() and is_finite(degrees):
		_transform_selected(Math.rotate_vertices(selected.vertices, degrees))

func scale_selected(factor: float) -> void:
	var selected: Dictionary = get_selected()
	if not selected.is_empty() and is_finite(factor) and factor > 0.0:
		_transform_selected(Math.scale_vertices(selected.vertices, factor))

func _transform_selected(vertices: PackedVector2Array) -> void:
	var selected: Dictionary = get_selected()
	if not selected.is_empty():
		transform_selected(vertices, Vector2(selected.position))

## A whole pointer gesture commits geometry and position in one undo operation.
func transform_selected(vertices: PackedVector2Array, position: Vector2) -> void:
	var selected: Dictionary = get_selected()
	if selected.is_empty() or not position.is_finite():
		return
	var bounds: Rect2 = Math.bounds(vertices)
	if not _valid_vertices(vertices, str(selected.kind)) or bounds.size.x > ARTBOARD.size.x or bounds.size.y > ARTBOARD.size.y:
		return
	for length: float in Math.side_lengths(vertices):
		if length < MIN_SIDE_LENGTH:
			return
	var after: Dictionary = _snapshot()
	var index: int = _shape_index(selected_id)
	after.shapes[index].vertices = vertices.duplicate()
	after.shapes[index].position = fitted_position(vertices, position)
	_commit(after)

func duplicate_selected() -> void:
	var selected: Dictionary = get_selected()
	if selected.is_empty() or shapes.size() >= MAX_SHAPES:
		return
	var after: Dictionary = _snapshot()
	selected.id = _next_id
	selected.position = fitted_position(selected.vertices, selected.position + Vector2(24, 24))
	after.shapes.append(selected)
	after.selected_id = _next_id
	after.next_id = _next_id + 1
	_commit(after)

func shift_selected_layer(direction: int) -> void:
	var index: int = _shape_index(selected_id)
	if index < 0 or direction == 0:
		return
	var target: int = clampi(index + (1 if direction > 0 else -1), 0, shapes.size() - 1)
	if index == target:
		return
	var after: Dictionary = _snapshot()
	var selected: Dictionary = after.shapes[index]
	after.shapes.remove_at(index)
	after.shapes.insert(target, selected)
	_commit(after)

func ordered_shapes() -> Array[Dictionary]:
	return shapes.duplicate(true)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data.scene = {"background_id": background_id, "drawing_mode": drawing_mode, "masterpiece_id": masterpiece_id}
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
	for part: Dictionary in checked.shapes:
		if not str(part.slot_id).is_empty():
			return false
		var bounds: Rect2 = Math.bounds(part.vertices)
		bounds.position += Vector2(part.position)
		if not ARTBOARD.grow(0.01).encloses(bounds):
			return false
		next_id = maxi(next_id, int(part.id) + 1)
	var after: Dictionary = _snapshot()
	after.template_id = checked.template_id
	after.shapes = checked.shapes.duplicate(true)
	after.selected_id = checked.selected_id
	after.next_id = next_id
	after.background_id = str(scene_data.background_id)
	after.drawing_mode = str(scene_data.drawing_mode)
	after.masterpiece_id = str(scene_data.masterpiece_id)
	_commit(after)
	return true

func _snapshot() -> Dictionary:
	var data: Dictionary = super._snapshot()
	data.background_id = background_id
	data.drawing_mode = drawing_mode
	data.masterpiece_id = masterpiece_id
	return data

func _apply_snapshot(data: Dictionary) -> void:
	super._apply_snapshot(data)
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
