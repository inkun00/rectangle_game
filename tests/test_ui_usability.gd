class_name TestUiUsability
extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(800, 600), Vector2i(783, 712), Vector2i(1280, 720)]


static func run(t: Node) -> void:
	var window: Window = t.get_window()
	var window_state: Dictionary = {
		"size": window.size,
		"content_scale_size": window.content_scale_size,
		"content_scale_mode": window.content_scale_mode,
		"content_scale_aspect": window.content_scale_aspect,
		"content_scale_factor": window.content_scale_factor,
		"min_size": window.min_size,
	}
	window.min_size = Vector2i.ZERO
	window.content_scale_size = Vector2i(1600, 900)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_factor = 1.0
	window.size = Vector2i(1280, 720)
	await _settle(t)
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	# This suite exercises UI state; audio playback has its own suite.
	app._sound.sound_enabled = false
	await _settle(t)
	app._show_workshop()
	app.document.fill_example()
	app._enter_world()
	app.world.set_controls_enabled(false)
	await _settle(t)
	await _test_window_scaling_and_focus(t, app, window)
	await _test_journal_filters(t, app)
	await _test_inventory_actions(t, app)
	app.free()
	# A resized root Window is shared by the other integration suites.
	window.content_scale_size = window_state["content_scale_size"]
	window.content_scale_mode = window_state["content_scale_mode"]
	window.content_scale_aspect = window_state["content_scale_aspect"]
	window.content_scale_factor = float(window_state["content_scale_factor"])
	window.min_size = window_state["min_size"]
	window.size = window_state["size"]
	await _settle(t)
	t.assert_eq(window.size, window_state["size"], "UI tests restore the root window size")
	t.assert_eq(window.content_scale_size, window_state["content_scale_size"], "UI tests restore the original logical viewport")
	t.assert_eq(window.content_scale_mode, window_state["content_scale_mode"], "UI tests restore the original stretch mode")
	t.assert_eq(window.content_scale_aspect, window_state["content_scale_aspect"], "UI tests restore the original stretch aspect")
	t.assert_eq(window.content_scale_factor, window_state["content_scale_factor"], "UI tests restore the original content scale factor")


static func _test_window_scaling_and_focus(t: Node, app: QuadrilateralApp, window: Window) -> void:
	var document_before: Dictionary = app.document.serialize().duplicate(true)
	var journal_before: Dictionary = app.journal.serialize().duplicate(true)
	var adventure_before: Dictionary = app.adventure.serialize().duplicate(true)
	var world_before: Dictionary = app.world.serialize().duplicate(true)
	var player_parts_before: Array[Dictionary] = app.world.player._parts.duplicate(true)
	var focus_origin: Button = QuadTheme.button("테스트 시작 위치", Callable())
	focus_origin.position = Vector2(12, 12)
	app._ui.add_child(focus_origin)
	focus_origin.grab_focus()
	t.assert_eq(app.get_viewport().gui_get_focus_owner(), focus_origin, "Keyboard test begins with an actual focused control")
	app._show_game_menu()
	await _settle(t)
	t.assert_false(app.world.controls_enabled, "The game menu pauses world input")
	t.assert_false(app.world.player.controls_enabled, "The game menu pauses the live character")
	_assert_game_menu_actions(t, app)
	for dimensions: Vector2i in WINDOW_SIZES:
		# Resize a modal that is already open: fitting only at creation is insufficient.
		window.size = dimensions
		await _settle(t)
		app._responsive()
		await _settle(t)
		var context: String = "Window %d x %d" % [dimensions.x, dimensions.y]
		t.assert_eq(window.size, dimensions, context + " uses the requested physical dimensions")
		t.assert_true(app._ui_size().is_equal_approx(app._ui.size), context + " reports the actual UI coordinate area")
		if dimensions.x <= 800:
			t.assert_true(app._compact_hud, context + " keeps secondary actions in the compact menu")
		else:
			t.assert_false(app._compact_hud, context + " uses the spacious HUD when room is available")
		t.assert_gt(app._ui_scale, 0.0, context + " has a valid UI scale")
		var ui_bounds: Rect2 = _physical_rect(app._ui)
		t.assert_float_approx(ui_bounds.position.x, 0.0, 1.1, context + " aligns the UI with the physical left edge")
		t.assert_float_approx(ui_bounds.position.y, 0.0, 1.1, context + " aligns the UI with the physical top edge")
		t.assert_float_approx(ui_bounds.size.x, float(dimensions.x), 1.1, context + " fills the physical width")
		t.assert_float_approx(ui_bounds.size.y, float(dimensions.y), 1.1, context + " fills the physical height")
		_assert_modal_fits(t, app, dimensions, context)
		_assert_hud_fits(t, app, dimensions, context)
		for label: Label in [app._active_quests, app._health_label, app._guidance, app._world_stats]:
			if label.is_visible_in_tree() and not label.text.is_empty():
				_assert_readable_text(t, label, context + " HUD")
		for button: Button in _enabled_buttons(app._modal_panel):
			_assert_readable_text(t, button, context + " menu action")
			t.assert_ge(_physical_rect(button).size.y, 40.0, context + " keeps actionable buttons physically large")
		var focused: Control = app.get_viewport().gui_get_focus_owner()
		t.assert_true(focused != null and app._modal_overlay.is_ancestor_of(focused), context + " preserves modal keyboard focus after resizing")
	# The same screen-fit calculation must handle the viewport's own scale setting.
	window.content_scale_factor = 1.25
	await _settle(t)
	app._responsive()
	await _settle(t)
	_assert_modal_fits(t, app, window.size, "Additional viewport content scale")
	_assert_hud_fits(t, app, window.size, "Additional viewport content scale")
	_assert_readable_text(t, app._modal_close, "Content-scale-adjusted close action")
	window.content_scale_factor = 1.0
	await _settle(t)
	app._responsive()
	await _settle(t)
	await _assert_keyboard_cycle(t, app)
	app._modal_close.grab_focus()
	_press_key(KEY_ENTER)
	app.world.set_controls_enabled(false)
	await _settle(t)
	t.assert_true(app._modal_overlay == null, "Enter activates the focused modal close button")
	t.assert_eq(app.get_viewport().gui_get_focus_owner(), focus_origin, "Closing a modal restores focus to its invoking control")
	app._show_game_menu()
	await _settle(t)
	_press_key(KEY_ESCAPE)
	app.world.set_controls_enabled(false)
	await _settle(t)
	t.assert_true(app._modal_overlay == null, "Escape closes the active modal through real keyboard input")
	t.assert_eq(app.get_viewport().gui_get_focus_owner(), focus_origin, "Escape restores the prior keyboard focus")
	t.assert_eq(app.document.serialize(), document_before, "UI resizing and menu navigation preserve editable four-vertex artwork")
	t.assert_eq(app.world.player._parts, player_parts_before, "UI scaling does not replace or distort the player's artwork")
	t.assert_eq(app.world.serialize(), world_before, "UI resizing preserves world position, pickups, and checkpoint")
	t.assert_eq(app.journal.serialize(), journal_before, "UI navigation does not alter quest progress or coins")
	t.assert_eq(app.adventure.serialize(), adventure_before, "UI navigation does not alter HP, XP, or discoveries")
	focus_origin.free()


static func _test_journal_filters(t: Node, app: QuadrilateralApp) -> void:
	var quests: Array[Dictionary] = QuestCatalog.all_quests()
	app._show_journal()
	await _settle(t)
	t.assert_eq(app._journal_filter, "active", "The journal opens on current objectives by default")
	t.assert_true(_has_next_action(app._modal_body), "An empty active journal offers an action toward a first objective")
	app._close_modal()
	var finished: Dictionary = quests[0]
	var active: Dictionary = quests[1]
	var available: Dictionary = quests[2]
	app.journal.accept_quest(str(finished.id))
	for item_index: int in range(int(finished.target_count)):
		app.journal.collect_item(str(finished.target))
	t.assert_true(bool(app.journal.answer_quest(str(finished.id), int(finished.answer)).get("completed", false)), "Journal filter fixture completes a real exploration-and-answer objective")
	app.journal.accept_quest(str(active.id))
	for filter_name: String in ["active", "available", "completed", "all"]:
		app._show_journal(filter_name)
		await _settle(t)
		t.assert_eq(app._journal_filter, filter_name, "Journal remembers selected " + filter_name + " filter")
		var text: String = _labels(app._modal_body)
		t.assert_eq(text.contains(str(finished.title)), filter_name in ["completed", "all"], "Completed objectives appear only in completed/all filters")
		t.assert_eq(text.contains(str(active.title)), filter_name in ["active", "all"], "Accepted objectives appear only in active/all filters")
		t.assert_eq(text.contains(str(available.title)), filter_name in ["available", "all"], "Unaccepted objectives appear only in available/all filters")
	app._show_journal("active")
	await _settle(t)
	var all_button: Button = _button_containing(app._modal_body, "전체")
	t.assert_not_null(all_button, "The journal exposes its all-objectives filter as an action")
	if all_button != null:
		all_button.pressed.emit()
		await _settle(t)
		t.assert_eq(app._journal_filter, "all", "The visible all-objectives button changes the filter")
	_assert_modal_fits(t, app, t.get_window().size, "Sixteen-objective journal")
	var scrollbar: VScrollBar = app._modal_scroll.get_v_scroll_bar()
	t.assert_gt(scrollbar.max_value, scrollbar.page, "A long journal scrolls inside its screen-fit modal")
	var body_buttons: Array[Button] = _enabled_buttons(app._modal_body)
	if not body_buttons.is_empty():
		var last_action: Button = body_buttons.back()
		last_action.grab_focus()
		await _settle(t)
		t.assert_true(_physical_rect(app._modal_scroll).intersects(_physical_rect(last_action)), "Keyboard focus scrolls a distant journal action into view")
	app._close_modal()
	app.world.set_controls_enabled(false)
	await _settle(t)


static func _test_inventory_actions(t: Node, app: QuadrilateralApp) -> void:
	app._show_inventory()
	await _settle(t)
	t.assert_true(_has_next_action(app._modal_body), "An empty objective bag offers the next useful action")
	var use_button: Button = _button_containing(app._modal_body, "회복약 사용")
	t.assert_not_null(use_button, "Inventory retains its potion action")
	if use_button != null:
		t.assert_true(use_button.disabled, "Potion action explains its unavailable state at full health")
	app.adventure.damage(20)
	app._show_inventory()
	await _settle(t)
	use_button = _button_containing(app._modal_body, "회복약 사용")
	t.assert_not_null(use_button, "Damaged character can find the potion action")
	if use_button != null:
		t.assert_false(use_button.disabled, "Potion action is enabled when it can heal")
		var potions_before: int = app.adventure.potions
		use_button.grab_focus()
		_press_key(KEY_ENTER)
		await _settle(t)
		t.assert_eq(app.adventure.hp, app.adventure.max_hp, "Keyboard potion action heals the real persistent state")
		t.assert_eq(app.adventure.potions, potions_before - 1, "Keyboard activation consumes exactly one potion")
		var focus: Control = app.get_viewport().gui_get_focus_owner()
		t.assert_true(focus != null and app._modal_overlay.is_ancestor_of(focus), "Rebuilt inventory retains focus inside the replacement modal")
	app.adventure.potions = 0
	app.adventure.damage(40)
	app._show_inventory()
	await _settle(t)
	use_button = _button_containing(app._modal_body, "회복약 사용")
	if use_button != null:
		t.assert_true(use_button.disabled, "Potion action is disabled when the bag contains none")
	var quest: Dictionary = QuestCatalog.all_quests()[1]
	app.journal.collect_item(str(quest.target))
	app._show_inventory()
	await _settle(t)
	t.assert_true(_labels(app._modal_body).contains(str(quest.item_name)), "Inventory still displays actual collected objective items")
	app._close_modal()
	app.world.set_controls_enabled(false)
	await _settle(t)


static func _assert_game_menu_actions(t: Node, app: QuadrilateralApp) -> void:
	var action_groups: Array = [["가방", "소지품"], ["부탁", "수첩"], ["지도"], ["이야기"], ["도형", "도감"], ["작업실", "공방", "그림", "꾸미"], ["도움", "조작"]]
	for alternatives: Array in action_groups:
		var found: bool = false
		for term: String in alternatives:
			if _button_containing(app._modal_body, term) != null:
				found = true
		t.assert_true(found, "Compact game menu keeps access to " + str(alternatives))


static func _assert_keyboard_cycle(t: Node, app: QuadrilateralApp) -> void:
	var buttons: Array[Button] = _enabled_buttons(app._modal_panel)
	t.assert_gt(buttons.size(), 1, "Modal has multiple keyboard-operable actions")
	if buttons.is_empty():
		return
	var first: Control = app.get_viewport().gui_get_focus_owner()
	if first == null:
		t.assert_true(false, "A modal must establish an initial keyboard focus")
		return
	var visited: Dictionary = {}
	for step: int in range(buttons.size()):
		var focus: Control = app.get_viewport().gui_get_focus_owner()
		t.assert_true(focus != null and app._modal_overlay.is_ancestor_of(focus), "Tab remains inside the active modal")
		if focus != null:
			visited[focus.get_instance_id()] = true
		_press_key(KEY_TAB)
		await _settle(t, 1)
	t.assert_eq(visited.size(), buttons.size(), "Tab reaches every enabled modal action once before wrapping")
	t.assert_eq(app.get_viewport().gui_get_focus_owner(), first, "Tab wraps from the last modal action to the first")
	_press_key(KEY_TAB, true)
	await _settle(t, 1)
	var previous: Control = app.get_viewport().gui_get_focus_owner()
	t.assert_true(previous != null and previous != first and app._modal_overlay.is_ancestor_of(previous), "Shift+Tab wraps backward without entering gameplay controls")
	_press_key(KEY_TAB)
	await _settle(t, 1)
	t.assert_eq(app.get_viewport().gui_get_focus_owner(), first, "Forward navigation returns from the backward-wrapped action")


static func _assert_modal_fits(t: Node, app: QuadrilateralApp, dimensions: Vector2i, context: String) -> void:
	t.assert_not_null(app._modal_panel, context + " has a modal panel")
	if app._modal_panel == null:
		return
	var bounds: Rect2 = _physical_rect(app._modal_panel)
	t.assert_ge(bounds.position.x, -1.0, context + " leaves the panel's left edge on screen")
	t.assert_ge(bounds.position.y, -1.0, context + " leaves the panel's top edge on screen")
	t.assert_le(bounds.end.x, float(dimensions.x) + 1.0, context + " leaves the panel's right edge on screen")
	t.assert_le(bounds.end.y, float(dimensions.y) + 1.0, context + " leaves the panel's bottom edge on screen")
	t.assert_gt(app._modal_scroll.size.y, 40.0, context + " leaves usable space for scrolling content")
	var close_bounds: Rect2 = _physical_rect(app._modal_close)
	t.assert_ge(close_bounds.size.x, 116.0, context + " gives the Korean close label and Esc shortcut enough width")
	t.assert_le(close_bounds.size.y, 64.0, context + " keeps the close label on a single comfortable row")


static func _assert_hud_fits(t: Node, app: QuadrilateralApp, dimensions: Vector2i, context: String) -> void:
	var panels: Array[PanelContainer] = [app._identity_panel, app._region_panel, app._quest_panel, app._hud_bottom]
	var names: Array[String] = ["character status", "region summary", "current objective", "action bar"]
	for index: int in range(panels.size()):
		var bounds: Rect2 = _physical_rect(panels[index])
		var panel_context: String = context + " " + names[index]
		t.assert_ge(bounds.position.x, -1.0, panel_context + " keeps its left edge on screen")
		t.assert_ge(bounds.position.y, -1.0, panel_context + " keeps its top edge on screen")
		t.assert_le(bounds.end.x, float(dimensions.x) + 1.0, panel_context + " keeps its right edge on screen")
		t.assert_le(bounds.end.y, float(dimensions.y) + 1.0, panel_context + " keeps its bottom edge on screen after text reflow")
	var quest_bounds: Rect2 = _physical_rect(app._quest_panel)
	var action_bounds: Rect2 = _physical_rect(app._hud_bottom)
	t.assert_true(quest_bounds.end.y < action_bounds.position.y, context + " keeps the objective panel clear of the bottom actions")


static func _assert_readable_text(t: Node, control: Control, context: String) -> void:
	var transform: Transform2D = control.get_viewport().get_stretch_transform() * control.get_global_transform_with_canvas()
	var physical_size: float = float(control.get_theme_font_size("font_size")) * transform.y.length()
	t.assert_ge(physical_size, 15.95, context + " keeps text at least sixteen physical pixels")


static func _physical_rect(control: Control) -> Rect2:
	var transform: Transform2D = control.get_viewport().get_stretch_transform() * control.get_global_transform_with_canvas()
	var bounds: Rect2 = Rect2(transform * Vector2.ZERO, Vector2.ZERO)
	for corner: Vector2 in [Vector2(control.size.x, 0), control.size, Vector2(0, control.size.y)]:
		bounds = bounds.expand(transform * corner)
	return bounds


static func _enabled_buttons(parent: Node) -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in parent.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.is_visible_in_tree() and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			result.append(button)
	return result


static func _button_containing(parent: Node, text: String) -> Button:
	for node: Node in parent.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text.contains(text):
			return button
	return null


static func _has_next_action(parent: Node) -> bool:
	for word: String in ["부탁", "수첩", "주민", "지도", "물건", "안내", "찾아", "만나", "가기"]:
		var action: Button = _button_containing(parent, word)
		if action != null and not action.disabled:
			return true
	return false


static func _labels(parent: Node) -> String:
	var result: String = ""
	for node: Node in parent.find_children("*", "Label", true, false):
		result += (node as Label).text + "\n"
	return result


static func _press_key(keycode: Key, shift: bool = false) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = true
	key.shift_pressed = shift
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	var release: InputEventKey = key.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


static func _settle(t: Node, frames: int = 3) -> void:
	for frame: int in range(frames):
		await t.get_tree().process_frame
