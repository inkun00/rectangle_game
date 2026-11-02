class_name TestConstructionSpaceAndPan
extends RefCounted

const Document = preload("res://scripts/construction/construction_document.gd")
const State = preload("res://scripts/construction/construction_state.gd")
const Facade = preload("res://scripts/construction/construction_facade.gd")
const Canvas = preload("res://scenes/construction/construction_canvas.gd")
const Studio = preload("res://scenes/construction/construction_studio.gd")
const Simulation = preload("res://scenes/construction/construction_physics.gd")

static func run(t: Node) -> void:
	_test_expanded_geometry_and_saves(t)
	await _test_canvas_cancellation(t)
	await _test_studio_escape(t)
	await _test_extended_foundation(t)

static func _test_expanded_geometry_and_saves(t: Node) -> void:
	t.assert_eq(Document.BUILD_AREA.size, Vector2(2000, 1120), "Buildable width and foundation-to-roof height both double")
	t.assert_eq(Document.BOARD.size, Vector2(2000, 1200), "The visual work surface doubles in both dimensions")
	t.assert_eq(Document.GROUND_Y, 560.0, "Expansion keeps the existing foundation and earlier saves in place")
	var document: Document = Document.new()
	t.assert_gt(document.add_part("brick", Vector2(1980, -550)), 0, "The newly reachable upper-right corner accepts valid geometry")
	t.assert_gt(document.add_part("brick", Vector2(1980, 550)), 0, "The expanded right-hand foundation accepts materials")
	for position: Vector2 in [Vector2(2000, 550), Vector2(1980, -560), Vector2(1980, 570), Vector2(0, 550)]:
		t.assert_eq(document.add_part("brick", position), -1, "Actual vertices still cannot extend beyond the expanded building boundary")
	var snapshot: Dictionary = document.serialize()
	var restored: Document = Document.new()
	t.assert_true(restored.restore(JSON.parse_string(JSON.stringify(snapshot))), "Negative-height and far-right coordinates survive validated v1 saves")
	t.assert_eq(restored.serialize(), snapshot, "Saving the larger lot preserves geometry and positions exactly")
	var bad: Dictionary = snapshot.duplicate(true)
	bad.parts[0].position[1] = -570
	t.assert_false(restored.restore(bad), "A saved part outside the new upper boundary is rejected")
	t.assert_eq(restored.serialize(), snapshot, "Rejected out-of-bounds saves leave the larger design intact")
	var pieces: Array[Dictionary] = []
	for row: int in range(18):
		pieces.append({"material_id": "wall", "position": Vector2(1900, 530 - row * 60)})
	pieces.append({"material_id": "roof_flat", "position": Vector2(1900, -540)})
	var company: State = State.new()
	company.set_my_house_mode(true)
	t.assert_true(company.my_house_document.replace_parts(pieces), "A full-height house can be assembled in the expanded right-hand region")
	t.assert_true(Facade.inspect(company.my_house_document.parts).complete, "Facade checks cover all 56 cells from the new top to the original foundation")
	var loaded: State = State.new()
	t.assert_true(loaded.restore(JSON.parse_string(JSON.stringify(company.serialize()))), "A tall expanded-lot house survives complete state restoration")
	t.assert_eq(loaded.my_house_document.parts, company.my_house_document.parts, "State restoration retains every expanded-lot part")
	company.my_house_document.select(int(company.my_house_document.parts.back().id))
	company.my_house_document.delete_selected()
	var roofless: Dictionary = Facade.inspect(company.my_house_document.parts)
	t.assert_false(roofless.complete, "An elevated facade still requires its actual roof")
	t.assert_true(not roofless.gaps.is_empty() and Rect2(roofless.gaps[0]).position.y < 0.0, "Repair markers identify the actual elevated missing roof")
	var earlier: State = State.new()
	t.assert_true(earlier.accept_contract() and earlier.build_starter(), "Existing first-house coordinates remain valid on the larger site")
	var old_snapshot: Dictionary = earlier.serialize()
	t.assert_true(loaded.restore(JSON.parse_string(JSON.stringify(old_snapshot))), "Earlier v1 drawings load without coordinate migration")
	t.assert_eq(loaded.serialize(), old_snapshot, "Loading an earlier drawing preserves its original ledger and arrangement")

static func _test_canvas_cancellation(t: Node) -> void:
	var canvas: Canvas = Canvas.new()
	canvas.document = Document.new()
	canvas.size = Vector2(800, 500)
	t.add_child(canvas)
	await _settle(t)
	for point: Vector2 in [Document.BUILD_AREA.position, Document.BUILD_AREA.end, Vector2(1980, -550), Vector2(1000, 40)]:
		t.assert_true(canvas.screen_to_artwork(canvas.artwork_to_screen(point)).distance_to(point) < 0.001, "Expanded coordinates map correctly through the workbench camera")
	t.assert_true(canvas.artwork_to_screen(Document.BOARD.get_center()).is_equal_approx(canvas.size * 0.5), "The enlarged board is centered with its negative upper extent")
	canvas.choose_material("door")
	_pointer(canvas, Vector2(500, 500), MOUSE_BUTTON_LEFT, true)
	t.assert_true(canvas._pending_place, "A material can have a pending placement before cancellation")
	_pointer(canvas, Vector2(500, 500), MOUSE_BUTTON_RIGHT, true)
	t.assert_true(canvas.pan_tool and not canvas.drawing_tool, "Right click cancels the material and enables lasting screen movement")
	t.assert_false(canvas._pending_place or canvas._dragging, "Right click also cancels any unfinished placement or drag")
	t.assert_eq(canvas.document.selected_id, -1, "Right click clears part selection")
	var before_pan: Vector2 = canvas.pan
	_motion(canvas, Vector2(500, 500), Vector2(80, -40))
	t.assert_eq(canvas.pan, before_pan + Vector2(80, -40), "The same right-button gesture immediately pans the screen")
	_pointer(canvas, Vector2(500, 500), MOUSE_BUTTON_RIGHT, false)
	_pointer(canvas, Vector2(500, 500), MOUSE_BUTTON_LEFT, false)
	t.assert_eq(canvas.document.parts.size(), 0, "Releasing an earlier left press cannot place the canceled material")
	t.assert_true(canvas.pan_tool and not canvas._panning, "Releasing right click leaves pan mode available for the next drag")
	t.assert_eq(canvas.mouse_default_cursor_shape, Control.CURSOR_DRAG, "Cancellation displays the screen-movement cursor")
	canvas.choose_material("brick")
	t.assert_true(canvas.drawing_tool and not canvas.pan_tool, "Choosing a new material resumes placement")
	canvas.cursor_position = Vector2(990, -540)
	_key(canvas, KEY_RIGHT)
	t.assert_eq(canvas.cursor_position, Vector2(1010, -540), "Keyboard placement can cross the former right boundary")
	_key(canvas, KEY_UP)
	t.assert_eq(canvas.cursor_position, Vector2(1010, -560), "Keyboard placement can reach the doubled height")
	_pointer(canvas, Vector2(1200, -250), MOUSE_BUTTON_LEFT, true)
	_key(canvas, KEY_ESCAPE)
	t.assert_true(canvas.pan_tool and not canvas.drawing_tool and not canvas._pending_place, "Canvas-focused Esc cancels material placement and enables screen movement")
	_pointer(canvas, Vector2(1200, -250), MOUSE_BUTTON_LEFT, false)
	t.assert_eq(canvas.document.parts.size(), 0, "Esc cancellation also discards a pending pointer release")
	canvas.document.add_part("brick", Vector2(1500, 550))
	canvas.cancel_selection_for_pan()
	t.assert_eq(canvas.document.selected_id, -1, "Repeated cancellation clears a selection even if pan mode was already active")
	var geometry: Array[Dictionary] = canvas.document.parts.duplicate(true)
	var history: int = canvas.document.command_manager.undo_stack.size()
	before_pan = canvas.pan
	_pointer(canvas, Vector2(1500, 550), MOUSE_BUTTON_LEFT, true)
	_motion(canvas, Vector2(1500, 550), Vector2(-60, 25))
	_pointer(canvas, Vector2(1500, 550), MOUSE_BUTTON_LEFT, false)
	t.assert_eq(canvas.pan, before_pan + Vector2(-60, 25), "Left dragging after cancellation moves the viewport")
	t.assert_eq(canvas.document.parts, geometry, "Panning over an existing material cannot move or replace it")
	t.assert_eq(canvas.document.command_manager.undo_stack.size(), history, "Camera movement does not add artwork commands or charge materials")
	canvas.free()
	await _settle(t)

static func _test_studio_escape(t: Node) -> void:
	var studio: Studio = Studio.new()
	studio.testing = true
	t.add_child(studio)
	await _settle(t)
	studio._close_modal()
	studio._enter_my_house_mode()
	studio._choose_material("door")
	t.assert_true(studio._material_buttons.door.button_pressed, "Selecting a material highlights its card")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	studio._unhandled_key_input(escape)
	t.assert_true(studio.canvas.pan_tool and not studio.canvas.drawing_tool, "Esc works when focus is outside the canvas")
	t.assert_false(studio._material_buttons.door.button_pressed, "Esc removes the selected-material card highlight")
	t.assert_true(studio._pan_button_lower.button_pressed, "The screen-movement button reflects Esc cancellation")
	studio._choose_material("brick")
	t.assert_true(studio.canvas.drawing_tool and not studio.canvas.pan_tool, "Selecting another card resumes building after Esc")
	studio._show_help()
	studio._unhandled_key_input(escape)
	t.assert_false(is_instance_valid(studio._modal), "Esc still closes an open construction dialog first")
	t.assert_true(studio.canvas.drawing_tool and not studio.canvas.pan_tool, "Closing a dialog does not also cancel the user's material")
	studio.free()
	await _settle(t)

static func _test_extended_foundation(t: Node) -> void:
	var document: Document = Document.new()
	var id: int = document.add_part("brick", Vector2(1980, 550))
	var original: Dictionary = document.serialize()
	var simulation: Simulation = Simulation.new()
	t.add_child(simulation)
	simulation.start(document.parts, document.revision)
	var frames: int = 0
	while simulation.running and frames < 240:
		await t.get_tree().physics_frame
		frames += 1
	await t.get_tree().process_frame
	t.assert_true(simulation.report.stable_ids.has(id), "The real collision foundation supports the expanded right edge")
	t.assert_float_approx(simulation.pose(id).origin.y, 550.0, 2.0, "Far-right materials rest on the foundation instead of falling past the former floor")
	t.assert_eq(document.serialize(), original, "Physics on the larger site preserves authoritative artwork")
	simulation.free()
	await _settle(t)

static func _pointer(canvas: Canvas, position: Vector2, button: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = canvas.artwork_to_screen(position)
	event.button_index = button
	event.pressed = pressed
	canvas._gui_input(event)

static func _motion(canvas: Canvas, position: Vector2, relative: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = canvas.artwork_to_screen(position)
	event.relative = relative
	canvas._gui_input(event)

static func _key(canvas: Canvas, keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	canvas._gui_input(event)

static func _settle(t: Node) -> void:
	for frame: int in range(5): await t.get_tree().process_frame
