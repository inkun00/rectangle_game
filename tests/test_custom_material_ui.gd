class_name TestCustomMaterialUi
extends RefCounted

const Studio = preload("res://scenes/construction/construction_studio.gd")
const Custom = preload("res://scripts/construction/custom_material_catalog.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const Document = preload("res://scripts/construction/construction_document.gd")
const Simulation = preload("res://scenes/construction/construction_physics.gd")
const SAVE: String = "user://test_custom_material_ui.json"

static func run(t: Node) -> void:
	_cleanup()
	var studio: Studio = Studio.new()
	studio.testing = true
	studio.save_path = SAVE
	t.add_child(studio)
	await _settle(t)
	studio._close_modal()
	studio._enter_my_house_mode()
	var original: Dictionary = studio.state.serialize()
	studio._custom_material_button.pressed.emit()
	await _settle(t)
	t.assert_true(is_instance_valid(studio._custom_material_form), "The actual order button opens a custom material form")
	t.assert_false(studio.canvas.editing_enabled, "Ordering owns input instead of placing materials behind the dialog")
	t.assert_true(studio._custom_material_button.disabled and studio._custom_material_filter.disabled, "The open maker disables background custom material controls")
	var form: CustomMaterialForm = studio._custom_material_form
	_pick(form._kind_picker, "trapezoid")
	await _settle(t)
	t.assert_eq(form._kind_picker.focus_next, form._trapezoid_picker.get_path(), "A newly revealed trapezoid choice joins the modal keyboard focus order")
	_pick(form._trapezoid_picker, "right_left")
	form._width_spin.value = 6.0
	form._height_spin.value = 4.0
	_pick(form._surface_picker, "wood")
	_pick(form._role_picker, "wall")
	var plain_price: int = int(form.current_quote.total)
	_pick(form._pattern_picker, "checks")
	t.assert_gt(int(form.current_quote.total), plain_price, "Selecting a patterned finish updates the real unit-price quote")
	var wood_price: int = int(form.current_quote.total)
	_pick(form._surface_picker, "metal")
	t.assert_gt(int(form.current_quote.total), wood_price, "Changing the surface updates its material rate immediately")
	_pick(form._surface_picker, "wood")
	var id: String = form.current_material_id
	var price: int = int(form.current_quote.total)
	t.assert_eq(form._preview.material_id, id, "The live preview uses exactly the quoted geometry, surface and pattern")
	t.assert_eq(Math.trapezoid_variant(Catalog.material_vertices(id)), "right_left", "The maker preserves the chosen two-right-angle variant")
	t.assert_eq(studio.state.serialize(), original, "Changing every order option does not spend money or alter either house")
	form._register_button.pressed.emit()
	await _settle(t)
	t.assert_false(is_instance_valid(studio._modal), "Registering the recipe returns to the building workspace")
	t.assert_true(studio.state.custom_material_ids.has(id), "The form action registers the chosen recipe in its owning state")
	t.assert_true(studio._material_buttons.has(id), "The newly registered recipe becomes a reusable material card")
	t.assert_true(studio._material_buttons[id]._dimensions.visible and studio._material_buttons[id]._dimensions.text.contains(Custom.pattern_label("checks")), "Registered cards identify their chosen pattern for reuse")
	t.assert_eq(studio.canvas.material_id, id, "The registered material is selected for ordinary placement")
	t.assert_true(studio._custom_only and studio._custom_material_filter.button_pressed, "Registration opens the dedicated personal-material list")
	t.assert_false(studio._material_buttons.wall.visible, "Personal-material browsing hides the built-in inventory")
	t.assert_eq(studio.state.balance, int(original.balance), "Registering a reusable design is free")
	studio._add_material(id)
	t.assert_eq(studio._active_doc().parts.size(), 1, "The normal add-material route recognizes custom recipes without a brick fallback")
	t.assert_eq(studio._active_doc().parts[0].material_id, id, "Ordinary placement retains the custom material ID")
	t.assert_eq(studio._active_doc().material_cost(), price, "Using one custom material reserves exactly the quoted unit price")
	studio._active_doc().undo()
	t.assert_eq(studio._active_doc().material_cost(), 0, "Undo returns the reserved custom-material cost")
	t.assert_true(studio.state.custom_material_ids.has(id), "Undoing placement keeps the reusable registered design")
	studio._active_doc().redo()
	t.assert_eq(studio._active_doc().material_cost(), price, "Redo restores the original price and custom artwork")
	t.assert_true(studio.save_game(false), "Registered recipes and custom placements save through the normal store")
	studio._show_custom_material_form()
	await _settle(t)
	form = studio._custom_material_form
	_pick(form._kind_picker, "trapezoid")
	_pick(form._trapezoid_picker, "right_left")
	_pick(form._pattern_picker, "checks")
	t.assert_eq(form.current_material_id, id, "Reopening the maker can identify an identical registered specification")
	t.assert_true(form._register_button.disabled, "An identical design cannot create duplicate library cards")
	_pick(form._kind_picker, "square")
	form._width_spin.value = 7.5
	t.assert_float_approx(form._height_spin.value, 7.5, 0.001, "Changing a square side synchronizes both dimensions")
	form._height_spin.value = 4.0
	t.assert_float_approx(form._width_spin.value, 4.0, 0.001, "Editing the other square side keeps four equal sides")
	studio._close_modal()
	await _assert_modal_layouts(t, studio)
	studio.free()
	await _settle(t)
	var restored: Studio = Studio.new()
	restored.testing = true
	restored.save_path = SAVE
	t.add_child(restored)
	await _settle(t)
	restored._close_modal()
	t.assert_true(restored.load_game(false), "A fresh studio reloads the saved personal material library")
	t.assert_true(restored._material_buttons.has(id), "Reloading rebuilds the registered material cards")
	t.assert_true(restored.state.custom_material_ids.has(id), "The reusable recipe survives a fresh UI session")
	t.assert_eq(restored.state.my_house_document.parts[0].material_id, id, "Reloading keeps the custom material already used in a house")
	t.assert_eq(restored.state.my_house_document.material_cost(), price, "Reloaded custom geometry uses the same deterministic price")
	restored._exit_my_house_mode()
	t.assert_true(restored.state.accept_contract(), "A registered recipe survives accepting a new commission")
	restored._browse_custom_materials(true)
	restored._choose_material(id)
	restored._add_material(id)
	t.assert_eq(restored.state.document.parts[0].material_id, id, "The same personal material can be reused in a separate commissioned house")
	t.assert_eq(restored.state.document.material_cost(), price, "Reusing the recipe charges its unit cost for each new placement")
	restored._select_guide_material()
	t.assert_false(restored._custom_only, "The first-house guide can reveal its built-in material after custom browsing")
	restored.free()
	await _settle(t)
	_cleanup()
	await _test_custom_material_physics(t)

static func _test_custom_material_physics(t: Node) -> void:
	var id: String = Custom.make_id("trapezoid", Vector2(120, 40), "metal", "diamond", "roof", "right_right")
	var simulation: Simulation = Simulation.new()
	t.add_child(simulation)
	for supported: bool in [true, false]:
		var document: Document = Document.new()
		var pieces: Array[Dictionary] = []
		if supported: pieces.append({"material_id": "wall", "position": Vector2(500, 530)})
		pieces.append({"material_id": id, "position": Vector2(500, 480 if supported else 220)})
		t.assert_true(document.replace_parts(pieces), "A custom patterned roof enters the actual physics inspection")
		var snapshot: Dictionary = document.serialize()
		simulation.start(document.parts, document.revision)
		var frames: int = 0
		while simulation.running and frames < 240:
			await t.get_tree().physics_frame
			frames += 1
		await t.get_tree().process_frame
		var roof_id: int = int(document.parts.back().id)
		t.assert_true(simulation.report.stable_ids.has(roof_id) if supported else simulation.report.unsupported_ids.has(roof_id), "Custom material geometry and mass obey the same real support rules as standard materials")
		t.assert_eq(document.serialize(), snapshot, "Custom material inspection preserves the original saved geometry")
		simulation.stop()
	simulation.free()
	await _settle(t)

static func _assert_modal_layouts(t: Node, studio: Studio) -> void:
	for dimensions: Vector2 in [Vector2(800, 600), Vector2(1366, 768)]:
		studio.size = dimensions
		studio._show_custom_material_form()
		await _settle(t)
		studio._resize_modal()
		await _settle(t)
		for id: String in studio.state.custom_material_ids:
			var card: ConstructionMaterialCard = studio._material_buttons[id]
			t.assert_true(card.get_global_rect().grow(1.0).encloses(card._price_pill.get_global_rect()), "A registered material's complete price stays inside its card on small screens")
		var form: CustomMaterialForm = studio._custom_material_form
		t.assert_true(studio.get_global_rect().grow(1.0).encloses(studio._modal_panel.get_global_rect()), "The complete custom order dialog fits the requested viewport")
		t.assert_true(form._fields.size.x <= studio._modal_body.size.x + 1.0, "Custom choices do not overflow the scrollable dialog width")
		t.assert_true(studio._modal_scroll.follow_focus, "Keyboard focus scrolls every custom option and the register action into view")
		t.assert_true(form._width_spin.get_line_edit().get_theme_font("font") == QuadTheme.FONT, "Custom numeric controls use the readable Korean UI font")
		studio._close_modal()
		await _settle(t)

static func _pick(picker: OptionButton, id: String) -> void:
	for index: int in range(picker.item_count):
		if str(picker.get_item_metadata(index)) == id:
			picker.select(index)
			picker.item_selected.emit(index)
			return

static func _settle(t: Node) -> void:
	for frame: int in range(5): await t.get_tree().process_frame

static func _cleanup() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(SAVE + suffix)
