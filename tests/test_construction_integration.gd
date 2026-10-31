class_name TestConstructionIntegration
extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")
const Studio = preload("res://scenes/construction/construction_studio.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Document = preload("res://scripts/construction/construction_document.gd")
const Language = preload("res://scripts/construction/construction_language.gd")

static func run(t: Node) -> void:
	await _test_navigation_and_modals(t)
	await _test_save_and_complete_contract(t)
	await _test_guided_house_and_recovery(t)
	await _test_inspection_repairs(t)
	await _test_worksite_layout(t)
	await _test_dialog_resizing_and_focus(t)
	await _test_starter_replacement(t)
	await _test_material_family_filters(t)
	await _test_facade_repair_feedback(t)

static func _test_facade_repair_feedback(t: Node) -> void:
	var studio: Studio = Studio.new()
	studio.testing = true
	t.add_child(studio)
	await t.get_tree().process_frame
	studio._accept_contract()
	t.assert_true(studio.state.document.replace_parts(ConstructionGuide.plan()), "The full guide creates a closed facade")
	for part: Dictionary in studio.state.document.parts:
		if Vector2(part.position) == Vector2(240, 530):
			studio.state.document.select(int(part.id))
			break
	studio.state.document.delete_selected()
	studio._start_inspection()
	for frame: int in range(240):
		await t.get_tree().physics_frame
		if not studio.canvas.inspection_running: break
	await t.get_tree().process_frame
	t.assert_true(bool(studio._last_report.get("stable", false)), "Bonded masonry can physically bridge a missing lower outer wall")
	t.assert_false(bool(studio.state.evaluate(studio._last_report).can_submit), "A stable facade with a missing wall cannot be handed over")
	t.assert_true(studio._status.text.contains("빈틈"), "The inspection status explains an incomplete facade even when gravity passes")
	studio._show_report()
	t.assert_true(_button_named(studio, "SettleConstruction") == null, "A facade gap never exposes settlement")
	var locate: Button = _button(studio._modal, "외벽 빈틈 위치 보기")
	t.assert_not_null(locate, "The report offers a visible way to locate facade gaps")
	var before: Dictionary = studio.state.serialize()
	if locate != null: locate.pressed.emit()
	t.assert_gt(studio.canvas.facade_gaps.size(), 0, "Locating gaps highlights their real geometry on the worksite")
	t.assert_false(studio.canvas.inspection_visible, "Gap repair returns to editable design coordinates")
	t.assert_eq(studio.state.serialize(), before, "Locating a gap does not buy or move materials")
	t.assert_gt(studio.state.document.add_part("wall", Vector2(240, 530)), 0, "The missing wall can be restored without covering the door or window")
	t.assert_true(studio.canvas.facade_gaps.is_empty(), "Editing invalidates the previous facade gap overlay")
	studio._start_inspection()
	for frame: int in range(240):
		await t.get_tree().physics_frame
		if not studio.canvas.inspection_running: break
	await t.get_tree().process_frame
	t.assert_true(bool(studio.state.evaluate(studio._last_report).can_submit), "The repaired closed facade passes a fresh actual gravity inspection")
	studio.free()
	await t.get_tree().process_frame

static func _test_material_family_filters(t: Node) -> void:
	var studio: Studio = Studio.new()
	studio.testing = true
	t.add_child(studio)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	studio._close_modal()
	studio._filter_shape("rhombus")
	studio._filter_materials("decor")
	studio._accept_contract()
	t.assert_eq(studio._material_family, "all", "Accepting a commission clears a browsing filter that would hide the entrance")
	t.assert_true(studio._material_buttons.door.visible, "The first suggested door is visible when a new commission begins")
	var before_filters: Dictionary = studio.state.serialize()
	for frame: int in range(5): await t.get_tree().process_frame
	var material_scroll: ScrollContainer = studio._materials.get_parent() as ScrollContainer
	material_scroll.scroll_vertical = int(material_scroll.get_v_scroll_bar().max_value)
	await t.get_tree().process_frame
	t.assert_gt(material_scroll.scroll_vertical, 0, "The material list can be scrolled before switching catalog families")
	studio._filter_shape("rhombus")
	for frame: int in range(5): await t.get_tree().process_frame
	t.assert_eq(material_scroll.scroll_vertical, 0, "Switching a material family starts at its first item instead of showing only the final decorations")
	t.assert_true(studio._material_buttons.wall_rhombus.visible, "The first stage exposes structural rhombus materials")
	t.assert_false(studio._materials_empty.visible, "Choosing rhombus shows available rhombus materials")
	var allowed_families: Array[String] = ["square", "rectangle", "trapezoid", "parallelogram", "rhombus"]
	for family: String in Studio.MATERIAL_FAMILIES:
		if family == "all": continue
		var index: int = Studio.MATERIAL_FAMILIES.find(family)
		studio._shape_filter.select(index)
		studio._shape_filter.item_selected.emit(index)
		var expected_count: int = 0
		var visible_count: int = 0
		var wrong_family: bool = false
		for id: String in Catalog.MATERIAL_IDS:
			var material: Dictionary = Catalog.material(id)
			var vertices: PackedVector2Array = QuadrilateralMath.create_vertices(str(material.kind), Vector2(material.dimensions))
			var same_family: bool = QuadrilateralMath.matches_kind(vertices, family) and allowed_families.has(str(material.kind))
			if same_family: expected_count += 1
			if studio._material_buttons[id].visible:
				visible_count += 1
				if not same_family: wrong_family = true
		t.assert_eq(visible_count, expected_count, "The %s catalog filter exposes exactly the materials approved for the current stage" % family)
		t.assert_false(wrong_family, "The %s property filter accepts only actual matching geometry" % family)
		t.assert_true(studio._shape_filter.get_item_text(index).contains("%d종" % expected_count), "The %s picker displays the number of materials it can show" % family)
		t.assert_false(studio._brick_mode.visible, "A representative shape displays both single and bundled materials without a hidden brick-mode restriction")
	studio._filter_shape("rectangle")
	t.assert_true(studio._material_buttons.brick.visible and studio._material_buttons.wall.visible, "Rectangle browsing includes both the single brick and the nine-brick module")
	studio._category_picker.select(2)
	studio._category_picker.item_selected.emit(2)
	var wrong_use: bool = false
	var opening_count: int = 0
	for id: String in Catalog.MATERIAL_IDS:
		if not studio._material_buttons[id].visible: continue
		opening_count += 1
		var material: Dictionary = Catalog.material(id)
		if not Studio._material_matches(material, "rectangle") or not str(material.role) in ["door", "window"]: wrong_use = true
	t.assert_gt(opening_count, 0, "The shape and compact use filters can find rectangular doors and windows")
	t.assert_false(wrong_use, "Shape and use filters are intersected rather than replacing one another")
	t.assert_true(studio._material_buttons.window.visible, "A square window satisfies the four-right-angle rectangle filter")
	studio._filter_shape("trapezoid")
	var empty_count: int = 0
	for id: String in studio._material_buttons:
		if studio._material_buttons[id].visible: empty_count += 1
	t.assert_eq(studio._materials_empty.visible, empty_count == 0, "An empty combined filter explains how to find materials again")
	t.assert_eq(studio.state.serialize(), before_filters, "Browsing all five families and uses never changes a house or its ledger")
	studio._filter_materials("decor")
	studio._filter_shape("rhombus")
	studio._select_guide_material()
	t.assert_eq(studio._material_family, "all", "The first-house guide clears a shape filter that hides its next material")
	t.assert_eq(studio._material_category, "all", "The first-house guide also clears an incompatible use filter")
	t.assert_true(studio._material_buttons.door.visible, "The guided door is visibly available after both filters are cleared")
	for frame: int in range(5): await t.get_tree().process_frame
	var library: ScrollContainer = studio._materials.get_parent() as ScrollContainer
	t.assert_true(library.get_global_rect().encloses(studio._material_buttons.door.get_global_rect()), "Guide selection also scrolls its next material into the visible library")
	studio._show_help()
	t.assert_true(studio._shape_filter.disabled and studio._category_picker.disabled, "Modal input ownership disables the background filter dropdowns")
	studio.free()
	await t.get_tree().process_frame

static func _test_dialog_resizing_and_focus(t: Node) -> void:
	var window: Window = t.get_tree().root
	var original_size: Vector2i = window.size
	var original_scale: Vector2i = window.content_scale_size
	window.size = Vector2i(1600, 900)
	window.content_scale_size = window.size
	var studio: Studio = Studio.new()
	studio.testing = true
	t.add_child(studio)
	for frame: int in range(5): await t.get_tree().process_frame
	for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1024, 720), Vector2i(846, 886)]:
		window.size = dimensions
		window.content_scale_size = dimensions
		for frame: int in range(5): await t.get_tree().process_frame
		var viewport: Rect2 = Rect2(Vector2.ZERO, Vector2(dimensions))
		t.assert_true(viewport.encloses(studio._modal_panel.get_global_rect()), "The open client document resizes inside %s" % str(dimensions))
		var accept: Button = _button(studio._modal, "의뢰를 받고 집 짓기")
		t.assert_true(accept != null and viewport.encloses(accept.get_global_rect()), "Accepting a contract stays reachable after resizing to %s" % str(dimensions))
	studio._accept_contract()
	window.size = Vector2i(800, 600)
	window.content_scale_size = window.size
	for frame: int in range(5): await t.get_tree().process_frame
	var material_scroll: ScrollContainer = studio._materials.get_parent() as ScrollContainer
	var visible_materials: Array[Button] = _visible_materials(studio)
	t.assert_gt(visible_materials.size(), 0, "The accepted stage exposes focusable material choices")
	var last_material: Button = visible_materials.back()
	last_material.grab_focus()
	for frame: int in range(5): await t.get_tree().process_frame
	t.assert_gt(material_scroll.scroll_vertical, 0, "Keyboard focus scrolls the material library to its offscreen last sample")
	t.assert_true(material_scroll.get_global_rect().encloses(last_material.get_global_rect()), "The focused material sample is visible without using the mouse wheel")
	studio._show_prices()
	for frame: int in range(5): await t.get_tree().process_frame
	var price_buttons: Array[Node] = studio._modal_body.find_children("*", "Button", true, false)
	var last_price: Button = price_buttons.back() as Button
	last_price.grab_focus()
	for frame: int in range(5): await t.get_tree().process_frame
	t.assert_gt(studio._modal_scroll.scroll_vertical, 0, "Keyboard focus scrolls the long price document to its last source action")
	t.assert_true(studio._modal_scroll.get_global_rect().encloses(last_price.get_global_rect()), "The focused source action is visible inside the document body")
	studio._show_help()
	for frame: int in range(5): await t.get_tree().process_frame
	window.size = Vector2i(846, 886)
	window.content_scale_size = window.size
	for frame: int in range(5): await t.get_tree().process_frame
	window.size = Vector2i(800, 600)
	window.content_scale_size = window.size
	for frame: int in range(5): await t.get_tree().process_frame
	var small_viewport: Rect2 = Rect2(Vector2.ZERO, Vector2(window.size))
	t.assert_true(small_viewport.encloses(studio._modal_panel.get_global_rect()), "Help remains inside the smaller browser after an open-dialog resize")
	t.assert_true(small_viewport.encloses(_button(studio._modal, "직접 지어 보기").get_global_rect()), "Help's fixed return action stays visible after shrinking the browser")
	studio.free()
	window.size = original_size
	window.content_scale_size = original_scale
	await t.get_tree().process_frame

static func _test_starter_replacement(t: Node) -> void:
	var studio: Studio = Studio.new()
	studio.testing = true
	t.add_child(studio)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	studio._accept_contract()
	studio._build_starter()
	t.assert_gt(studio.state.document.parts.size(), 0, "An empty design receives the starter directly")
	t.assert_false(is_instance_valid(studio._modal), "An empty design needs no replacement confirmation")
	studio.state.document.add_part("brick", Vector2(740, 550))
	var before: Dictionary = studio.state.serialize()
	var original_parts: Array[Dictionary] = studio.state.document.parts.duplicate(true)
	studio._build_starter()
	t.assert_true(is_instance_valid(studio._modal), "Starter help explains replacing an existing design before it changes")
	t.assert_eq(studio.state.serialize(), before, "Opening replacement help preserves the existing house and its ledger")
	for frame: int in range(5): await t.get_tree().process_frame
	t.assert_lt(studio._modal_panel.size.y, 400.0, "The short replacement explanation uses a compact confirmation panel")
	var viewport: Rect2 = Rect2(Vector2.ZERO, studio.size)
	t.assert_true(viewport.encloses(studio._modal_body.get_global_rect()), "The complete replacement explanation is on screen")
	for text: String in ["기초 배치로 바꾸기", "지금 설계 계속 짓기"]:
		var action: Button = _button(studio._modal, text)
		t.assert_true(action != null and viewport.encloses(action.get_global_rect()), "The compact confirmation keeps its %s action on screen" % text)
	var cancel: Button = _button(studio._modal, "지금 설계 계속 짓기")
	t.assert_not_null(cancel, "Starter replacement always offers a visible way to keep the current design")
	if cancel != null: cancel.pressed.emit()
	t.assert_false(is_instance_valid(studio._modal), "Cancelling starter replacement closes the confirmation")
	t.assert_eq(studio.state.serialize(), before, "Cancelling starter replacement preserves every existing part and the ledger")
	studio._build_starter()
	var replace: Button = _button(studio._modal, "기초 배치로 바꾸기")
	t.assert_not_null(replace, "Existing designs offer an explicit starter replacement action")
	if replace != null: replace.pressed.emit()
	t.assert_eq(studio.state.document.parts.size(), original_parts.size() - 1, "Accepting starter replacement replaces the custom parts once")
	t.assert_false(is_instance_valid(studio._modal), "Applying the starter returns to the editable worksite")
	studio.state.document.undo()
	t.assert_eq(studio.state.document.parts, original_parts, "Undo restores the complete design from before starter replacement")
	t.assert_eq(studio.state.balance, int(before.balance), "Starter replacement and Undo never pay another advance or change cash")
	studio.free()
	await t.get_tree().process_frame

static func _test_worksite_layout(t: Node) -> void:
	var window: Window = t.get_tree().root
	var original_size: Vector2i = window.size
	var original_scale: Vector2i = window.content_scale_size
	var studio: Studio = Studio.new()
	studio.testing = true
	t.add_child(studio)
	await t.get_tree().process_frame
	studio._accept_contract()
	for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1024, 720), Vector2i(1266, 712), Vector2i(846, 886)]:
		studio._filter_shape("all")
		window.size = dimensions
		window.content_scale_size = dimensions
		for frame: int in range(5): await t.get_tree().process_frame
		var viewport: Rect2 = Rect2(Vector2.ZERO, Vector2(dimensions))
		for control: Control in [studio._inspect, studio._deliver, studio._status]:
			t.assert_true(viewport.encloses(control.get_global_rect()), "Inspection, delivery and feedback remain visible at %s: %s %s" % [str(dimensions), str(control.name), str(control.get_global_rect())])
		t.assert_true(viewport.encloses(studio._shape_filter.get_global_rect()), "The shape picker remains reachable at %s" % str(dimensions))
		var material_scroll: ScrollContainer = studio._materials.get_parent() as ScrollContainer
		var visible_materials: Array[Button] = _visible_materials(studio)
		t.assert_gt(visible_materials.size(), 0, "The current stage has visible materials at %s" % str(dimensions))
		if not visible_materials.is_empty():
			var first_card: Button = visible_materials[0]
			t.assert_true(material_scroll.size.y >= first_card.get_combined_minimum_size().y, "The catalog leaves room for the complete material card at %s" % str(dimensions))
			t.assert_true(material_scroll.get_global_rect().encloses(first_card.get_global_rect()), "The first material card is fully visible at %s" % str(dimensions))
		t.assert_eq(studio._category_picker.visible, dimensions.y < 760, "Small viewports use a compact use picker without losing the use filter")
		studio._filter_shape("parallelogram")
		for frame: int in range(5): await t.get_tree().process_frame
		var picker: OptionButton = studio._shape_filter
		var text_width: float = picker.get_theme_font("font").get_string_size(picker.text, HORIZONTAL_ALIGNMENT_LEFT, -1, picker.get_theme_font_size("font_size")).x
		var available_width: float = picker.size.x - picker.get_theme_stylebox("normal").get_minimum_size().x - picker.get_theme_icon("arrow").get_width() - picker.get_theme_constant("arrow_margin")
		t.assert_true(text_width <= available_width, "The longest representative family label stays readable at %s" % str(dimensions))
	studio.free()
	window.size = original_size
	window.content_scale_size = original_scale
	await t.get_tree().process_frame

static func _test_navigation_and_modals(t: Node) -> void:
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	var entry: Button = _button(app._home_screen, "집 짓기")
	t.assert_not_null(entry, "Home offers a working housebuilding entry")
	t.assert_false(app._construction_screen.visible, "Construction does not cover the initial home page")
	app.document.fill_example()
	var character_before: Dictionary = app.document.serialize()
	app._show_drawing()
	app._drawing_screen.document.add_shape("square", Vector2.ZERO, Color.BLUE)
	var drawing_before: Dictionary = app._drawing_screen.document.serialize()
	app._show_workshop()
	app._enter_world()
	app.world.player.begin_attack()
	app._show_home()
	if entry != null: entry.pressed.emit()
	await t.get_tree().process_frame
	var studio: Studio = app._construction_screen
	t.assert_true(studio.visible, "The actual home button opens the construction studio")
	t.assert_false(app._home_screen.visible, "Housebuilding hides the home page")
	t.assert_false(app._drawing_screen.visible, "Housebuilding hides the free drawing studio")
	t.assert_false(app._workshop_screen.visible, "Housebuilding hides the character workshop")
	t.assert_false(app._in_world, "Housebuilding does not leave RPG gameplay active")
	t.assert_false(app.world.controls_enabled, "Housebuilding disables hidden RPG movement and combat")
	t.assert_false(app.world.camera.enabled, "RPG camera cannot offset the construction canvas")
	var player_position: Vector2 = app.world.player.position
	var attack_cooldown: float = app.world.player.attack_cooldown
	for frame: int in range(3): await t.get_tree().physics_frame
	t.assert_eq(app.world.player.position, player_position, "Hidden RPG physics remain paused during construction")
	t.assert_eq(app.world.player.attack_cooldown, attack_cooldown, "Hidden RPG attack timers remain paused during construction")
	t.assert_true(is_instance_valid(studio._modal), "The first client visits when entering the new mode")
	t.assert_false(studio.canvas.editing_enabled, "Client dialogue owns the construction input")
	var accept: Button = _button(studio, "의뢰를 받고 집 짓기")
	t.assert_not_null(accept, "The client's contract can be accepted through the visible dialogue")
	if accept != null: accept.pressed.emit()
	await t.get_tree().process_frame
	t.assert_eq(studio.state.phase, "building", "Accepting the client starts construction")
	t.assert_true(studio.canvas.editing_enabled, "Accepting closes dialogue and enables the worksite")
	t.assert_eq(studio.canvas.material_id, "door", "The first suggested placement is a door opening")
	var before_view: Dictionary = studio.state.serialize()
	var opening_filter: Button = _button(studio, "문·창")
	if opening_filter != null: opening_filter.pressed.emit()
	t.assert_true(studio._material_buttons.door.visible and studio._material_buttons.window.visible, "Opening category exposes the door and window materials together")
	t.assert_false(studio._material_buttons.wall.visible, "Opening category hides unrelated wall modules")
	var all_filter: Button = _button(studio, "전체")
	if all_filter != null: all_filter.pressed.emit()
	t.assert_true(studio._material_buttons.wall.visible, "The full library restores the active wall-building mode")
	var material_view: Button = _button(studio, "재료 보기")
	if material_view != null: material_view.pressed.emit()
	t.assert_true(studio.canvas.presentation_mode, "The visible material-view action changes the drawing presentation")
	t.assert_eq(studio.state.serialize(), before_view, "Catalog filters and material presentation preserve house geometry and its ledger")
	var design_view: Button = _button(studio, "설계 보기")
	if design_view != null: design_view.pressed.emit()
	t.assert_false(studio.canvas.presentation_mode, "The design-view action returns to the drafting board")
	_pointer(studio, Vector2(500, 500), true)
	_pointer(studio, Vector2(500, 500), false)
	t.assert_eq(studio.state.document.parts.size(), 1, "Actual pointer placement installs a door before walls")
	var window_button: Button = _button_named(studio, "Material_window")
	if window_button != null: window_button.pressed.emit()
	_pointer(studio, Vector2(340, 480), true)
	_pointer(studio, Vector2(340, 480), false)
	t.assert_eq(studio.state.document.parts.size(), 2, "A window reserves its space during wall construction")
	studio._brick_mode.select(0)
	studio._brick_mode.item_selected.emit(0)
	t.assert_eq(studio.canvas.material_id, "wall", "Wall bundle mode selects nine-brick wall modules")
	t.assert_true(studio._material_buttons.wall.visible, "Bundle mode displays the wall material")
	t.assert_false(studio._material_buttons.brick.visible, "Bundle mode keeps the single-brick palette unambiguous")
	_pointer(studio, Vector2(340, 480), true)
	_pointer(studio, Vector2(340, 480), false)
	t.assert_eq(studio.state.document.parts.size(), 2, "Wall placement cannot fill a reserved window opening")
	_pointer(studio, Vector2(500, 500), true)
	_pointer(studio, Vector2(500, 500), false)
	t.assert_eq(studio.state.document.parts.size(), 2, "Wall placement cannot fill the reserved entrance")
	studio._brick_mode.select(1)
	studio._brick_mode.item_selected.emit(1)
	t.assert_eq(studio.canvas.material_id, "brick", "Individual mode selects one real priced brick")
	t.assert_true(studio._material_buttons.brick.visible, "Individual mode exposes the single brick material")
	t.assert_false(studio._material_buttons.wall.visible, "Individual mode hides the alternative wall bundle")
	_pointer(studio, Vector2(740, 550), true)
	_pointer(studio, Vector2(740, 550), false)
	t.assert_eq(studio.state.document.parts.size(), 3, "Single-brick mode places a separate construction part")
	studio._show_brief()
	var before_modal: Dictionary = studio.state.document.serialize()
	_pointer(studio, Vector2(820, 550), true)
	_pointer(studio, Vector2(820, 550), false)
	_key(studio, KEY_DELETE)
	_key(studio, KEY_Z, true)
	t.assert_eq(studio.state.document.serialize(), before_modal, "Dialogue blocks pointer placement and editing shortcuts")
	studio._close_modal()
	studio._choose_material("brick")
	_pointer(studio, Vector2(820, 550), true)
	t.assert_true(studio.canvas._pending_place, "A construction placement can be pending before navigation")
	studio.home_requested.emit()
	t.assert_true(app._home_screen.visible, "Construction's home action returns to the shared home")
	t.assert_false(studio.canvas._pending_place, "Leaving construction cancels unfinished placement")
	var before_hidden_key: Dictionary = studio.state.document.serialize()
	_key(studio, KEY_DELETE)
	_key(app, KEY_D, true)
	_key(app, KEY_DELETE)
	t.assert_eq(studio.state.document.serialize(), before_hidden_key, "Hidden construction does not handle keyboard shortcuts")
	app._show_construction()
	_pointer(studio, Vector2(820, 550), false)
	t.assert_eq(studio.state.document.parts.size(), 3, "Reopening cannot commit the cancelled mouse release")
	t.assert_eq(app.document.serialize(), character_before, "Construction preserves the assembled RPG character")
	t.assert_eq(app._drawing_screen.document.serialize(), drawing_before, "Construction preserves the independent free drawing")
	studio._start_inspection()
	t.assert_true(studio.canvas.inspection_running, "Construction starts its actual physics inspection")
	var before_help: Dictionary = studio.state.document.serialize()
	studio._show_help()
	t.assert_false(studio.canvas.inspection_running, "Opening help cancels the running gravity inspection")
	t.assert_false(studio.canvas.inspection_visible, "Help removes the cancelled simulation overlay")
	t.assert_true(studio._last_report.is_empty(), "An interrupted inspection cannot leave a deliverable report")
	t.assert_true(is_instance_valid(studio._modal), "Help remains visible after stopping construction physics")
	t.assert_false(studio.canvas.editing_enabled, "Help owns input after cancelling an inspection")
	_pointer(studio, Vector2(820, 550), true)
	_pointer(studio, Vector2(820, 550), false)
	_key(studio, KEY_DELETE)
	t.assert_eq(studio.state.document.serialize(), before_help, "Help prevents placement and deletion while physics is cancelled")
	studio._close_modal()
	t.assert_true(studio.canvas.editing_enabled, "Closing help restores editable design mode")
	studio._start_inspection()
	t.assert_true(studio.canvas.inspection_running, "Inspection can restart after a help interruption")
	studio.home_requested.emit()
	t.assert_false(studio.canvas.inspection_running, "Leaving the mode stops active construction physics")
	t.assert_false(studio.canvas.inspection_visible, "A cancelled hidden simulation does not remain on the next screen")
	app._show_workshop()
	app._enter_world()
	t.assert_true(app.world.controls_enabled, "Returning to the adventure restores RPG controls")
	t.assert_true(app.world.camera.enabled, "Returning to the adventure restores its own camera")
	app.free()
	await t.get_tree().process_frame

static func _test_save_and_complete_contract(t: Node) -> void:
	var save_path: String = "res://.godot/construction_integration_%d.json" % Time.get_ticks_usec()
	var studio: Studio = Studio.new()
	studio.testing = true
	studio.save_path = save_path
	t.add_child(studio)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	studio._accept_contract()
	studio._build_starter()
	var original: Dictionary = studio.state.serialize()
	var original_document: Document = studio.state.document
	t.assert_true(studio.save_game(false), "Construction explicitly saves its separate design and ledger")
	t.assert_true(Studio.SAVE_PATH != DrawingStudio.SAVE_PATH, "Construction never overwrites the free drawing save")
	t.assert_false(Studio.SAVE_PATH.ends_with("quadrilateral_world_v1.json"), "Construction never overwrites the RPG save")
	studio.state.document.add_part("brick", Vector2(740, 550))
	t.assert_true(studio.load_game(false), "Construction restores the saved design and ledger together")
	t.assert_eq(studio.state.serialize(), original, "Construction JSON round trip preserves the entire contract state")
	t.assert_true(studio.state.document != original_document, "Validated restoration swaps the old document atomically")
	t.assert_true(studio.canvas.document == studio.state.document, "The worksite follows the restored live document")
	t.assert_true(studio.state.document.changed.is_connected(studio.canvas._document_changed), "Restored canvas subscribes to the new document's changes")
	var stale_snapshot: Dictionary = original_document.serialize()
	var restored_count: int = studio.state.document.parts.size()
	studio.state.document.select(int(studio.state.document.parts[0].id))
	var delete_button: Button = _button(studio, "삭제")
	var undo_button: Button = _button(studio, "되돌리기")
	var redo_button: Button = _button(studio, "다시")
	if delete_button != null: delete_button.pressed.emit()
	t.assert_eq(studio.state.document.parts.size(), restored_count - 1, "Delete button operates on the restored document")
	t.assert_eq(original_document.serialize(), stale_snapshot, "UI callbacks do not mutate a discarded document after load")
	if undo_button != null: undo_button.pressed.emit()
	t.assert_eq(studio.state.document.parts.size(), restored_count, "Undo button works after a document replacement")
	if redo_button != null: redo_button.pressed.emit()
	t.assert_eq(studio.state.document.parts.size(), restored_count - 1, "Redo button works after a document replacement")
	if undo_button != null: undo_button.pressed.emit()
	studio._choose_material("brick")
	_pointer(studio, Vector2(740, 550), true)
	_pointer(studio, Vector2(740, 550), false)
	t.assert_eq(studio.state.document.parts.size(), restored_count + 1, "Pointer editing also targets the restored document")
	var before_invalid: Dictionary = studio.state.serialize()
	var invalid_file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	invalid_file.store_string('{"version":1,"construction":{"balance":123}}')
	invalid_file.close()
	t.assert_false(studio.load_game(false), "Malformed construction saves are rejected through the UI loader")
	t.assert_eq(studio.state.serialize(), before_invalid, "A rejected file leaves the active house and money intact")
	studio._build_starter()
	var replace_starter: Button = _button(studio._modal, "기초 배치로 바꾸기")
	if replace_starter != null: replace_starter.pressed.emit()
	for position: Vector2 in [Vector2(240, 430), Vector2(360, 430), Vector2(480, 430), Vector2(600, 430)]:
		t.assert_gt(studio.state.document.add_part("lintel", position), 0, "A real lintel bridges each reserved opening")
	t.assert_gt(studio.state.document.add_part("roof_flat_wide", Vector2(420, 400)), 0, "A flat rectangular roof covers both supported openings")
	var design_before_physics: Dictionary = studio.state.document.serialize()
	var inspection_button: Button = _button_named(studio, "InspectConstruction")
	if inspection_button != null: inspection_button.pressed.emit()
	t.assert_true(studio.canvas.inspection_running, "The visible inspect button runs real physics")
	t.assert_false(studio.canvas.editing_enabled, "Editing is locked during the physics check")
	for frame: int in range(240):
		await t.get_tree().physics_frame
		if not studio.canvas.inspection_running: break
	await t.get_tree().process_frame
	t.assert_false(studio.canvas.inspection_running, "Physics inspection finishes within its bounded time")
	t.assert_false(studio._last_report.is_empty(), "The studio receives a real physics report")
	t.assert_true(bool(studio._last_report.get("stable", false)), "The completed first house passes actual opening-aware physics")
	t.assert_eq(studio.state.document.serialize(), design_before_physics, "Simulation never corrupts the saved construction design")
	var evaluation: Dictionary = studio.state.evaluate(studio._last_report)
	t.assert_true(bool(evaluation.can_submit), "A supported house meeting the first client's conditions can be delivered")
	if bool(evaluation.can_submit):
		var offer: Dictionary = studio.state.current_contract()
		var expected_balance: int = studio.state.balance + int(offer.total) - int(offer.advance) + int(evaluation.bonus) - int(offer.base_cost) - studio.state.material_cost()
		var review: Button = _button_named(studio, "ReviewConstruction")
		if review != null: review.pressed.emit()
		t.assert_true(is_instance_valid(studio._modal), "Showing the house opens the client satisfaction report")
		var settle: Button = _button_named(studio, "SettleConstruction")
		t.assert_not_null(settle, "A passing report offers the actual settlement action")
		if settle != null: settle.pressed.emit()
		t.assert_eq(studio.state.phase, "settled", "The visible settlement action completes the first contract")
		t.assert_eq(studio.state.records.size(), 1, "The completed house is recorded once")
		t.assert_eq(studio.state.balance, expected_balance, "Settlement deducts costs and previously paid advance exactly once")
		t.assert_true(studio._costs.text.contains(Catalog.format_won(int(evaluation.profit))), "The completed project's estimate panel shows the actual settled profit")
		t.assert_false(studio.canvas.editing_enabled, "A settled house cannot be edited to alter its paid invoice")
		t.assert_false(studio._palette.visible, "Completing a house collapses the inactive material shelf")
		t.assert_false(studio._toolbar.visible, "Completing a house collapses its inactive edit controls")
		t.assert_true(studio._completed_actions.visible, "The completed house has prominent next-client actions")
		var before_gallery: Dictionary = studio.state.serialize()
		studio._show_record(0)
		t.assert_true(is_instance_valid(studio._modal), "A completed house opens in the gallery dialogue")
		var gallery: ConstructionCanvas = null
		for child: Node in studio._modal_body.get_children():
			if child is ConstructionCanvas: gallery = child as ConstructionCanvas
		t.assert_not_null(gallery, "The completed house record includes a rendered canvas")
		if gallery != null:
			t.assert_true(gallery.document != studio.state.document, "The gallery uses an independent document")
			t.assert_false(gallery.editing_enabled, "The gallery canvas cannot edit a completed invoice")
			t.assert_false(gallery.document.editing_enabled, "The gallery document is also read-only")
			t.assert_eq(gallery.document.parts.size(), studio.state.document.parts.size(), "The gallery displays every part of the completed house")
		t.assert_eq(studio.state.serialize(), before_gallery, "Viewing the completed house leaves construction and ledger data unchanged")
		studio._close_modal()
		studio._submit()
		t.assert_eq(studio.state.balance, expected_balance, "Repeated UI submission cannot pay for the same house twice")
		t.assert_eq(studio.state.records.size(), 1, "Repeated submission cannot create duplicate house records")
		t.assert_true(studio.save_game(false), "Completed design and paid ledger save together")
		var reopened: Studio = Studio.new()
		reopened.testing = true
		reopened.save_path = save_path
		studio.hide()
		t.add_child(reopened)
		await t.get_tree().process_frame
		await t.get_tree().process_frame
		t.assert_true(reopened.load_game(false), "A fresh studio resumes the paid house from the same file")
		reopened._close_modal()
		t.assert_eq(reopened.state.balance, expected_balance, "Reloading a paid house preserves its earned money")
		t.assert_eq(reopened.state.phase, "settled", "Reloading does not reopen a settled commission")
		var next_client: Button = _button_named(reopened, "NextConstructionClient")
		t.assert_not_null(next_client, "A restored completed house offers a central next-client button")
		if next_client != null: next_client.pressed.emit()
		t.assert_eq(reopened.state.contract_index, 1, "The actual client action welcomes the next customer")
		t.assert_eq(reopened.state.phase, "briefing", "The next customer presents a new brief before construction")
		t.assert_eq(reopened.state.document.parts.size(), 0, "A new commission starts with its own empty worksite")
		t.assert_eq(reopened.state.records.size(), 1, "The previous house remains in the completed house history")
		t.assert_eq(reopened.state.balance, expected_balance, "Welcoming a customer alone does not award another advance")
		t.assert_true(is_instance_valid(reopened._modal), "The next customer's dialogue opens after settlement")
		reopened.free()
	studio.free()
	await t.get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))

static func _test_guided_house_and_recovery(t: Node) -> void:
	var path: String = "res://.godot/construction_guide_%d.json" % Time.get_ticks_usec()
	var studio: Studio = Studio.new()
	studio.testing = true
	studio.save_path = path
	t.add_child(studio)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	studio._accept_contract()
	t.assert_true(studio._guide_bar.visible, "The first accepted commission has an optional placement guide")
	t.assert_eq(studio._guide_step.material_id, "door", "The guide reserves the door opening before adding walls")
	var place: Button = _button_named(studio, "PlaceConstructionGuide")
	if place != null: place.pressed.emit()
	t.assert_eq(studio.state.document.parts.size(), 1, "The guide action places exactly one paid material")
	t.assert_eq(studio.state.document.parts[0].position, Vector2(500, 500), "Guided door rests on the ground instead of crossing below it")
	t.assert_eq(studio.canvas.material_id, "window", "The next suggested material is selected after guided placement")
	studio.state.document.undo()
	t.assert_eq(studio.state.document.parts.size(), 0, "Guided placement participates in ordinary Undo")
	t.assert_eq(studio._guide_step.material_id, "door", "Undo also restores the previous guide step")
	studio._toggle_guide()
	t.assert_false(studio._guide_bar.visible, "The placement example can be dismissed for free construction")
	t.assert_true(studio.canvas.editing_enabled, "Dismissing the example leaves normal construction enabled")
	studio._toggle_guide()
	place.grab_focus()
	studio._show_help()
	for frame: int in range(3): await t.get_tree().process_frame
	var modal_first: Button = _button(studio._modal, "닫기")
	var modal_actions: Array[Node] = studio._modal_actions.find_children("*", "Button", true, false)
	t.assert_gt(modal_actions.size(), 0, "Help exposes visible actions inside its modal")
	var modal_last: Button = modal_actions.back() as Button
	t.assert_true(modal_last.find_next_valid_focus() == modal_first, "Tab from the final dialog action wraps inside the modal")
	t.assert_true(modal_first.find_prev_valid_focus() == modal_last, "Shift-Tab from close cannot focus background actions")
	t.assert_eq(modal_first.focus_neighbor_left, modal_last.get_path(), "Directional focus also stays in the modal")
	studio._place_guide_step()
	t.assert_eq(studio.state.document.parts.size(), 0, "Guide shortcuts cannot bypass modal input ownership")
	studio._close_modal()
	t.assert_true(place.has_focus(), "Closing the dialog restores focus to its previous editing action")
	studio._filter_materials("opening")
	for index: int in range(ConstructionGuide.plan().size()):
		if place != null: place.pressed.emit()
		t.assert_eq(studio.state.document.parts.size(), index + 1, "Each guided step adds one valid nonoverlapping material")
		if index == 1:
			t.assert_true(studio._material_buttons.wall.visible, "Guidance reveals the next wall material even when openings were filtered")
			t.assert_eq(studio._material_category, "all", "Guidance restores a visible catalog category for its next material")
	t.assert_true(studio._guide_step.is_empty(), "The example ends after all planned parts are present")
	t.assert_true(place.disabled, "A completed example cannot add or charge for duplicate parts")
	var before_inspection: Dictionary = studio.state.document.serialize()
	studio._start_inspection()
	for frame: int in range(240):
		await t.get_tree().physics_frame
		if not studio.canvas.inspection_running: break
	await t.get_tree().process_frame
	t.assert_true(bool(studio._last_report.get("stable", false)), "The entire guided facade passes real gravity and opening support inspection")
	t.assert_true(bool(studio.state.evaluate(studio._last_report).can_submit), "Following the optional guide produces a deliverable first house")
	t.assert_eq(studio.state.document.serialize(), before_inspection, "Guide inspection preserves the authoritative editable geometry")
	t.assert_true(studio.save_game(false), "The guided first house saves normally")
	studio.state.document.add_part("brick", Vector2(780, 550))
	t.assert_true(studio.save_game(false), "A second valid save creates a recoverable previous revision")
	var invalid: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	invalid.store_string("{interrupted")
	invalid.close()
	t.assert_true(studio.load_game(false), "The UI loader recovers a valid backup when the main save is corrupt")
	t.assert_eq(studio.state.document.parts.size(), ConstructionGuide.plan().size(), "Backup recovery restores the coherent earlier house")
	t.assert_true(studio._status.text.contains("복구"), "Recovery is explicitly explained in the visible status")
	t.assert_true(studio.canvas.document == studio.state.document, "Recovery rebinds the interactive canvas to its restored document")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	t.assert_true(studio.load_game(false), "The UI loader checks backup files even when the primary file is absent")
	studio.free()
	await t.get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp", ".invalid"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))

static func _test_inspection_repairs(t: Node) -> void:
	var studio: Studio = Studio.new()
	studio.testing = true
	t.add_child(studio)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	studio._accept_contract()
	studio._toggle_guide()
	for index: int in range(10):
		studio.state.document.add_part("brick", Vector2(40 + index * 80, 300))
	var window_id: int = studio.state.document.add_part("window", Vector2(900, 300))
	var original_parts: Array[Dictionary] = studio.state.document.parts.duplicate(true)
	var revision: int = studio.state.document.revision
	var cash: int = studio.state.balance
	studio._start_inspection()
	for frame: int in range(240):
		await t.get_tree().physics_frame
		if not studio.canvas.inspection_running: break
	await t.get_tree().process_frame
	t.assert_eq(studio._fresh_issues().size(), 11, "Inspection provides actionable feedback for every failed part")
	t.assert_true(studio._repairs.visible, "Failed inspection exposes a visible repair action")
	t.assert_false(studio._repairs.disabled, "Completed inspection enables the repair action")
	studio._repairs.pressed.emit()
	await t.get_tree().process_frame
	t.assert_true(is_instance_valid(studio._modal), "Repair action opens its explanation list")
	t.assert_false(studio.canvas.editing_enabled, "Repair explanations keep background editing disabled")
	t.assert_true(_button_named(studio._modal, "RepairConstruction_%d" % window_id) == null, "Large failure lists show a bounded first page")
	var next: Button = _button(studio._modal, "다음 목록")
	t.assert_not_null(next, "More failed materials can be reached using the next page action")
	if next != null: next.pressed.emit()
	await t.get_tree().process_frame
	var repair: Button = _button_named(studio._modal, "RepairConstruction_%d" % window_id)
	t.assert_not_null(repair, "The last failed window is reachable on the second page")
	if repair != null: repair.pressed.emit()
	await t.get_tree().process_frame
	t.assert_false(is_instance_valid(studio._modal), "Choosing a repair closes the explanation list")
	t.assert_false(studio.canvas.inspection_visible, "Repair navigation returns to the original design")
	t.assert_false(studio.canvas.drawing_tool, "Repair navigation selects the material instead of placing duplicates")
	t.assert_false(studio._material_buttons.door.button_pressed, "Repair selection does not highlight an unrelated placement material")
	t.assert_eq(studio.state.document.selected_id, window_id, "Repair navigation selects the requested original window")
	t.assert_true(studio.canvas.has_focus(), "Keyboard input follows the selected repair target")
	t.assert_eq(studio.canvas.repair_issue.get("missing_edges", []).size(), 4, "All four missing opening supports remain available for visual edge markers")
	for point: Vector2 in Document.world_vertices(studio.state.document.part(window_id)):
		t.assert_true(Rect2(Vector2.ZERO, studio.canvas.size).has_point(studio.canvas.artwork_to_screen(point)), "Repair target is fully visible even near the board edge")
	t.assert_eq(studio.state.document.parts, original_parts, "Repair navigation never changes authoritative geometry")
	t.assert_eq(studio.state.document.revision, revision, "Repair navigation does not create an edit command")
	t.assert_eq(studio.state.balance, cash, "Reading inspection feedback never changes the ledger")
	t.assert_true(studio._repairs.visible, "Inspection reasons stay available while examining the unchanged design")
	var stale_issue: Dictionary = studio.canvas.repair_issue.duplicate(true)
	studio.state.document.move_selected(Vector2(900, 400))
	t.assert_true(studio._last_report.is_empty(), "Editing invalidates the studio's previous inspection")
	t.assert_true(studio.canvas.last_report.is_empty(), "Editing invalidates the canvas report after returning to design")
	t.assert_true(studio.canvas.repair_issue.is_empty(), "Old edge markers disappear as soon as geometry changes")
	t.assert_false(studio._repairs.visible, "The repair list hides until the changed design is inspected")
	t.assert_true(studio._status.text.contains("다시"), "Editing replaces the old repair diagnosis with a reinspection reminder")
	t.assert_false(studio.canvas.focus_repair(stale_issue), "A stale repair action cannot select or zoom an obsolete diagnosis")
	studio._focus_repair(window_id)
	t.assert_true(studio._status.text.contains("다시"), "A stale studio action requests a fresh inspection")
	studio.state.document.undo()
	t.assert_true(studio._fresh_issues().is_empty(), "Undo does not resurrect an obsolete inspection report")
	studio.free()
	await t.get_tree().process_frame

static func _pointer(studio: Studio, point: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = studio.canvas.artwork_to_screen(point)
	studio.canvas._gui_input(event)

static func _key(receiver: Node, keycode: Key, control: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.ctrl_pressed = control
	event.pressed = true
	receiver.call("_unhandled_key_input", event)

static func _button(root: Node, text: String) -> Button:
	if not is_instance_valid(root): return null
	var renamed: Dictionary = {"의뢰를 받고 집 짓기": "부탁 받고 집 짓기", "집을 완성하고 정산하기": "집 완성! 보상 받기", "의뢰인에게 보여주기": "집 보여 주기"}
	var expected: String = Language.simplify(str(renamed.get(text, text)))
	for node: Node in root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == expected: return button
	return null

static func _visible_materials(studio: Studio) -> Array[Button]:
	var result: Array[Button] = []
	for id: String in Catalog.MATERIAL_IDS:
		var button: Button = studio._material_buttons[id]
		if button.is_visible_in_tree() and not button.disabled: result.append(button)
	return result

static func _button_named(root: Node, button_name: String) -> Button:
	return root.find_child(button_name, true, false) as Button
