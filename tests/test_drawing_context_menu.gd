class_name TestDrawingContextMenu
extends RefCounted

const Studio = preload("res://scenes/drawing/drawing_studio.gd")
const Canvas = preload("res://scenes/drawing/drawing_canvas.gd")
const Document = preload("res://scripts/core/drawing_document.gd")

static func run(t: Node) -> void:
	await _test_layer_actions(t)
	await _test_target_and_cancellation(t)

static func _test_layer_actions(t: Node) -> void:
	var studio: Studio = await _studio(t)
	var ids: Array[int] = _overlapping_shapes(studio.document)
	studio.document.select_shape(ids[1])
	studio.canvas.select_tool()
	var original: Array[Dictionary] = studio.document.ordered_shapes()
	var history: int = studio.document.command_manager.undo_stack.size()
	_pointer(studio.canvas, Vector2.ZERO, MOUSE_BUTTON_RIGHT, true)
	t.assert_true(studio._shape_context_menu.visible, "Right clicking a selected quadrilateral opens its manipulation menu")
	t.assert_eq(studio.document.selected_id, ids[1], "A covered selected shape remains the context target")
	t.assert_eq(studio.document.ordered_shapes(), original, "Opening the context menu preserves all artwork")
	t.assert_eq(studio.document.command_manager.undo_stack.size(), history, "Opening a menu does not create an undo command")
	for action: int in [0, 1, 2, 3, 4, 5, 6, 7]:
		t.assert_ge(studio._shape_context_menu.get_item_index(action), 0, "Context menu exposes manipulation action " + str(action))
		t.assert_false(studio._shape_context_menu.is_item_separator(studio._shape_context_menu.get_item_index(action)), "Every action ID resolves to its command rather than a separator")
	t.assert_false(_disabled(studio, 6) or _disabled(studio, 7), "A middle layer can move in either direction")
	studio._shape_context_menu.id_pressed.emit(6)
	t.assert_eq(_order(studio.document), [ids[1], ids[0], ids[2]], "Send backward moves exactly one layer")
	t.assert_eq(studio.document.selected_id, ids[1], "Changing layers keeps the same shape selected")
	t.assert_eq(studio.document.get_selected(), original[1], "Changing layers preserves geometry, color, and identity")
	t.assert_eq(studio.document.command_manager.undo_stack.size(), history + 1, "One layer action creates one undo command")
	t.assert_false(studio._shape_context_menu.visible, "Choosing an action closes the menu")
	_pointer(studio.canvas, Vector2.ZERO, MOUSE_BUTTON_RIGHT, true)
	t.assert_true(_disabled(studio, 6), "The bottom layer disables send backward")
	studio._shape_context_menu.id_pressed.emit(6)
	t.assert_eq(studio.document.command_manager.undo_stack.size(), history + 1, "A disabled layer action cannot create an empty command")
	studio._shape_context_menu.id_pressed.emit(7)
	t.assert_eq(_order(studio.document), ids, "Send forward moves one layer toward the front")
	studio.document.undo()
	t.assert_eq(_order(studio.document), [ids[1], ids[0], ids[2]], "Undo restores the previous overlap order")
	studio.document.redo()
	t.assert_eq(_order(studio.document), ids, "Redo restores the layer change")
	_pointer(studio.canvas, Vector2.ZERO, MOUSE_BUTTON_RIGHT, true)
	studio._shape_context_menu.id_pressed.emit(7)
	t.assert_eq(_order(studio.document), [ids[0], ids[2], ids[1]], "Repeated forward action reaches the top")
	t.assert_eq(studio.canvas._shape_at(Vector2.ZERO), ids[1], "Hit testing follows the changed visual layer order")
	_pointer(studio.canvas, Vector2.ZERO, MOUSE_BUTTON_RIGHT, true)
	t.assert_true(_disabled(studio, 7), "The top layer disables send forward")
	var snapshot: Dictionary = studio.document.serialize()
	var restored: Document = Document.new()
	t.assert_true(restored.restore(JSON.parse_string(JSON.stringify(snapshot))), "Layer changes survive the validated drawing save format")
	t.assert_eq(restored.ordered_shapes(), studio.document.ordered_shapes(), "Restored rendering order matches the chosen layers")
	studio._shape_context_menu.id_pressed.emit(0)
	t.assert_eq(studio.document.shapes.size(), 4, "Context duplicate operates on the selected shape rather than the menu heading")
	t.assert_eq(studio.document.get_selected().vertices, original[1].vertices, "Context duplicate preserves the selected shape's actual vertices")
	studio.document.undo()
	_pointer(studio.canvas, Vector2.ZERO, MOUSE_BUTTON_RIGHT, true)
	studio._shape_context_menu.id_pressed.emit(1)
	t.assert_eq(studio.document.shapes.size(), 2, "Context delete removes only the selected shape")
	studio.document.undo()
	t.assert_eq(studio.document.serialize(), snapshot, "Undoing context deletion restores order, selection, and artwork")
	_pointer(studio.canvas, Vector2.ZERO, MOUSE_BUTTON_RIGHT, true)
	studio._shape_context_menu.id_pressed.emit(3)
	var rotated: Dictionary = studio.document.get_selected()
	t.assert_true(QuadrilateralMath.matches_kind(rotated.vertices, str(rotated.kind)), "Context rotation preserves the selected family")
	t.assert_true(rotated.vertices != original[1].vertices, "Context rotation uses the existing geometry command")
	studio.document.undo()
	t.assert_eq(studio.document.serialize(), snapshot, "Rotation is undone as a single operation")
	studio.free()
	await _settle(t)

static func _test_target_and_cancellation(t: Node) -> void:
	var studio: Studio = await _studio(t)
	var ids: Array[int] = _overlapping_shapes(studio.document)
	studio.canvas.select_tool()
	var before: Dictionary = studio.document.serialize()
	var history: int = studio.document.command_manager.undo_stack.size()
	_pointer(studio.canvas, Vector2.ZERO, MOUSE_BUTTON_LEFT, true)
	_motion(studio.canvas, Vector2(60, 30))
	t.assert_true(studio.canvas._dragging, "A body gesture can be in progress before right click")
	_pointer(studio.canvas, Vector2(60, 30), MOUSE_BUTTON_RIGHT, true)
	t.assert_false(studio.canvas._has_transform_gesture(), "Opening the context menu cancels an unfinished transform preview")
	_pointer(studio.canvas, Vector2(60, 30), MOUSE_BUTTON_LEFT, false)
	t.assert_eq(studio.document.serialize(), before, "A stale left release cannot commit the canceled move")
	studio.document.select_shape(ids[0])
	t.assert_false(studio._shape_context_menu.visible, "Changing the selection closes the previous shape's menu")
	before = studio.document.serialize()
	studio._shape_context_menu.id_pressed.emit(1)
	t.assert_eq(studio.document.serialize(), before, "A stale action cannot delete the newly selected shape")
	_pointer(studio.canvas, Vector2.ZERO, MOUSE_BUTTON_RIGHT, true)
	studio._shape_context_menu.hide()
	await _settle(t)
	t.assert_eq(studio._context_shape_id, -1, "Dismissing a popup invalidates its target")
	_pointer(studio.canvas, Vector2.ZERO, MOUSE_BUTTON_RIGHT, false)
	t.assert_false(studio._shape_context_menu.visible, "Right-button release does not reopen a dismissed menu")
	t.assert_eq(studio.document.command_manager.undo_stack.size(), history, "Selection and menu dismissal never add artwork commands")
	studio.canvas.select_kind("square")
	_pointer(studio.canvas, Vector2(-300, -200), MOUSE_BUTTON_LEFT, true)
	t.assert_true(studio.canvas._creating, "A pending drawing can also be canceled")
	_pointer(studio.canvas, Vector2(-300, -200), MOUSE_BUTTON_RIGHT, true)
	_pointer(studio.canvas, Vector2(-300, -200), MOUSE_BUTTON_LEFT, false)
	t.assert_false(studio._shape_context_menu.visible, "Right click on empty paper with no selection does not open shape actions")
	t.assert_eq(studio.document.shapes.size(), 3, "Canceled drawing cannot place a shape on release")
	_pointer(studio.canvas, Vector2.ZERO, MOUSE_BUTTON_RIGHT, true)
	t.assert_true(studio._shape_context_menu.visible, "Right click can select an existing shape directly from drawing mode")
	t.assert_false(studio.canvas.drawing_tool, "Context selection switches to manipulation mode")
	studio.hide()
	t.assert_false(studio._shape_context_menu.visible, "Leaving the drawing page closes its popup")
	studio.show()
	studio.tutorial_blocked = true
	_pointer(studio.canvas, Vector2.ZERO, MOUSE_BUTTON_RIGHT, true)
	t.assert_false(studio._shape_context_menu.visible, "A blocking tutorial cannot open context editing")
	studio.free()
	await _settle(t)

static func _studio(t: Node) -> Studio:
	var studio: Studio = Studio.new()
	studio.testing = true
	t.add_child(studio)
	await _settle(t)
	return studio

static func _overlapping_shapes(document: Document) -> Array[int]:
	var ids: Array[int] = []
	for index: int in range(3):
		ids.append(document.add_sized_shape("rectangle", Vector2(-40 + index * 40, 0), Vector2(160, 100), Color("29a995") if index % 2 == 0 else Color.CORAL))
	return ids

static func _order(document: Document) -> Array[int]:
	var ids: Array[int] = []
	for part: Dictionary in document.ordered_shapes(): ids.append(int(part.id))
	return ids

static func _disabled(studio: Studio, action: int) -> bool:
	return studio._shape_context_menu.is_item_disabled(studio._shape_context_menu.get_item_index(action))

static func _pointer(canvas: Canvas, point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = canvas.artwork_to_screen(point)
	event.button_index = button
	event.pressed = pressed
	canvas._gui_input(event)

static func _motion(canvas: Canvas, point: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = canvas.artwork_to_screen(point)
	canvas._gui_input(event)

static func _settle(t: Node) -> void:
	for frame: int in range(3): await t.get_tree().process_frame
