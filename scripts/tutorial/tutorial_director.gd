class_name TutorialDirector
extends Node

## Routes real player actions into a tour. It never edits artwork or game saves.
var app: QuadrilateralApp
var progress: TutorialProgress = TutorialProgress.new()
var overlay: TutorialOverlay
var active: bool = false
var mode: String = ""
var index: int = 0
var steps: Array[Dictionary] = []
var _pending: bool = false
var _focus_before: Control
var _drawing_parts: Array[Dictionary] = []
var _drawing_undo_count: int = 0
var _learning_before: Dictionary = {}
var _construction_count: int = 0
var _construction_mode: bool = false
var _world_bound: QuadrilateralWorld
var _walk_origin: float = 0.0
var _release_pending: bool = false
var _focus_action_pending: bool = false


func setup(owner_app: QuadrilateralApp) -> void:
	app = owner_app
	if not app.testing: progress.load_file()
	overlay = TutorialOverlay.new()
	overlay.name = "ModeTutorial"
	overlay.z_index = 1000
	app._ui.add_child(overlay)
	overlay.advance_requested.connect(advance)
	overlay.skip_requested.connect(skip)
	_drawing_parts = app._drawing_screen.document.shapes.duplicate(true)
	_drawing_undo_count = app._drawing_screen.document.command_manager.undo_stack.size()
	_learning_before = _learning_snapshot()
	_construction_mode = app._construction_screen.state.my_house_mode
	_construction_count = app._construction_screen.state.active_document().parts.size()
	app._drawing_screen.document.changed.connect(_drawing_changed)
	app._drawing_screen.mode_selected.connect(_drawing_mode_selected)
	app._drawing_screen.interaction_context_changed.connect(func(): refresh.call_deferred())
	app._drawing_screen.tutorial_requested.connect(func(): app._replay_tutorial(current_context()))
	app._drawing_screen._guide_toggle.toggled.connect(func(_enabled: bool): notify("masterpiece_guide"))
	app._drawing_screen._guide_opacity.value_changed.connect(func(_value: float): notify("masterpiece_guide"))
	app._drawing_screen.guide_changed.connect(func(): notify("masterpiece_guide"))
	app._construction_screen.state.changed.connect(_construction_changed)
	app._construction_screen.interaction_context_changed.connect(func(): refresh.call_deferred())
	app._construction_screen.tutorial_requested.connect(func(): app._replay_tutorial(current_context()))
	app._construction_screen.canvas.inspection_finished.connect(func(_report: Dictionary): notify("construction_inspect"))
	app._construction_screen.view_changed.connect(func():
		if app._construction_screen.canvas.presentation_mode: notify("my_house_view"))
	app._learning_screen.canvas.changed.connect(_learning_changed)
	app._learning_screen._primary.pressed.connect(func(): notify("learning_check"))
	app._learning_screen.tutorial_requested.connect(func(): app._replay_tutorial("learning"))
	app.document.changed.connect(_workshop_changed)
	overlay.dismiss()


func current_context() -> String:
	if app._learning_screen.visible: return "learning"
	if app._drawing_screen.visible:
		if active and mode == "masterpiece": return "masterpiece"
		return "masterpiece" if app._drawing_screen.document.drawing_mode == "masterpiece" else "drawing"
	if app._construction_screen.visible:
		return "my_house" if app._construction_screen.state.my_house_mode else "construction"
	if app._workshop_screen.visible: return "workshop"
	if app._in_world: return "world"
	return ""


func visit(context: String) -> void:
	if active and mode == context: return
	cancel()
	if app.testing or not progress.should_offer(context): return
	start(context)


func start(context: String) -> bool:
	if not TutorialCatalog.MODE_IDS.has(context): return false
	cancel()
	mode = context
	steps = TutorialCatalog.steps(context)
	index = 0
	active = true
	_focus_before = get_viewport().gui_get_focus_owner()
	_bind_world()
	_present()
	return true


func current_step() -> Dictionary:
	return steps[index] if active and index < steps.size() else {}


func blocks_gameplay() -> bool:
	return active and str(current_step().get("event", "")).is_empty()


func advance() -> void:
	if not active or not str(current_step().get("event", "")).is_empty(): return
	_next()


func notify(event: String) -> void:
	if not active or event.is_empty() or str(current_step().get("event", "")) != event: return
	_pending = true
	refresh.call_deferred()


func skip() -> void:
	if active: _finish("skipped")


func cancel() -> void:
	active = false
	mode = ""
	_pending = false
	_release_pending = false
	_focus_action_pending = false
	steps.clear()
	if is_instance_valid(overlay): overlay.dismiss()
	if is_instance_valid(app): _apply_gate()


func _finish(status: String) -> void:
	var finished_mode: String = mode
	var previous_focus: Control = _focus_before
	cancel()
	progress.mark(finished_mode, status)
	if not app.testing and progress.save_file() != OK:
		app._show_toast("안내 기록을 저장하지 못했어요. 다음에 안내가 다시 나타날 수 있어요.")
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree(): previous_focus.grab_focus()
	if finished_mode in ["construction", "my_house"]:
		app._construction_screen.call_deferred("_ensure_brief")


func _next() -> void:
	_pending = false
	index += 1
	if index >= steps.size():
		_finish("completed")
	else:
		_present()


func _present() -> void:
	# Existing completed work is an achievement, never a reason to reset it.
	while active and _already_satisfied(str(current_step().get("event", ""))):
		index += 1
		if index >= steps.size():
			_finish("completed")
			return
	if not active: return
	if mode == "world" and app.world != null:
		_walk_origin = app.world.player.position.x
		_release_pending = Input.is_action_pressed("ui_accept")
	if blocks_gameplay():
		app.workshop.cancel_gesture()
		app._drawing_screen.cancel_gesture()
		app._construction_screen.canvas.cancel_gesture()
		app._learning_screen.canvas._dragging = false
		app._clear_touch_inputs()
	if is_instance_valid(app._toast): app._toast.hide()
	_focus_action_pending = not blocks_gameplay()
	overlay.present(current_step(), index, steps.size())
	refresh()
	refresh.call_deferred()


func _already_satisfied(event: String) -> bool:
	match event:
		"learning_measure": return app._learning_screen.canvas.measured
		"learning_adjust", "learning_check": return app._learning_screen.phase > 0
		"masterpiece_chosen": return not app._drawing_screen.document.masterpiece_id.is_empty() and app._drawing_screen.document.drawing_mode == "masterpiece"
		"workshop_place": return int(app.document.completion().filled) > 0
		"workshop_ready": return bool(app.document.completion().ready)
		"construction_accept": return app._construction_screen.state.phase != "briefing"
		"construction_place": return app._construction_screen.state.phase == "settled" or not app._construction_screen.state.document.parts.is_empty()
		"construction_inspect": return app._construction_screen.state.phase == "settled"
		"my_house_place": return not app._construction_screen.state.my_house_document.parts.is_empty()
		"drawing_add": return app._drawing_screen.document.shapes.size() >= CharacterDocument.MAX_SHAPES
	return false


func refresh() -> void:
	if not active: return
	var foreign_modal: bool = _foreign_modal_open()
	overlay.set_suspended(foreign_modal)
	_apply_gate()
	if foreign_modal: return
	if _pending:
		_next()
		return
	var target: Control = _target(str(current_step().get("target", "")))
	overlay.set_target(target)
	if _focus_action_pending and is_instance_valid(target) and target.is_visible_in_tree():
		_focus_action_pending = false
		if target.focus_mode == Control.FOCUS_ALL and not (target is BaseButton and target.disabled): target.grab_focus()


func _foreign_modal_open() -> bool:
	if is_instance_valid(app._modal_overlay): return true
	if app._construction_screen.visible and is_instance_valid(app._construction_screen._modal): return true
	if app._drawing_screen.visible:
		var studio: DrawingStudio = app._drawing_screen
		if is_instance_valid(studio._gallery) and studio._gallery.visible: return true
		if is_instance_valid(studio._color_dialog) and studio._color_dialog.visible: return true
		if studio._color_picker.get_popup().visible: return true
		if is_instance_valid(studio._shape_context_menu) and studio._shape_context_menu.visible: return true
		if is_instance_valid(studio._sale_dialog) and studio._sale_dialog.visible: return true
	return false


func _apply_gate() -> void:
	var blocked: bool = blocks_gameplay()
	app._drawing_screen.tutorial_blocked = blocked
	app._construction_screen.tutorial_active = active and mode in ["construction", "my_house"]
	var construction_changed: bool = app._construction_screen.tutorial_blocked != blocked
	app._construction_screen.tutorial_blocked = blocked
	if construction_changed: app._construction_screen._refresh()
	if app.world != null:
		app.world.peaceful = app.learning_progress.peaceful or (active and mode == "world")
		app.world.set_controls_enabled(app._in_world and not blocked and not _release_pending and not is_instance_valid(app._modal_overlay))


func _physics_process(_delta: float) -> void:
	if not active or mode != "world" or app.world == null: return
	if _release_pending:
		if not Input.is_action_pressed("ui_accept"):
			_release_pending = false
			_apply_gate()
		return
	if str(current_step().get("event", "")) == "world_move" and app.world.controls_enabled:
		if absf(app.world.player.position.x - _walk_origin) >= 80.0: notify("world_move")


func _bind_world() -> void:
	if app.world == null or app.world == _world_bound: return
	_world_bound = app.world
	app.world.player.jumped.connect(func():
		if not _release_pending: notify("world_jump"))


func _drawing_mode_selected(selected: String) -> void:
	visit("masterpiece" if selected == "masterpiece" else "drawing")


func _drawing_changed() -> void:
	var doc: DrawingDocument = app._drawing_screen.document
	var added: bool = doc.shapes.size() > _drawing_parts.size()
	var edited: bool = false
	for part: Dictionary in doc.shapes:
		for previous: Dictionary in _drawing_parts:
			if int(part.id) == int(previous.id) and (part.position != previous.position or part.vertices != previous.vertices or part.color != previous.color):
				edited = true
	var undone: bool = doc.command_manager.undo_stack.size() < _drawing_undo_count
	_drawing_parts = doc.shapes.duplicate(true)
	_drawing_undo_count = doc.command_manager.undo_stack.size()
	if not app._drawing_screen.visible: return
	if doc.drawing_mode == "masterpiece" and (not active or mode != "masterpiece"):
		visit("masterpiece")
	if added: notify("drawing_add")
	if edited: notify("drawing_edit")
	if undone: notify("drawing_undo")
	if not doc.masterpiece_id.is_empty(): notify("masterpiece_chosen")
	refresh.call_deferred()


func _learning_snapshot() -> Dictionary:
	var canvas: LearningCanvas = app._learning_screen.canvas
	return {"value": canvas.value, "rotation": canvas.diagram_rotation, "choices": canvas.selected_choices.duplicate()}


func _learning_changed() -> void:
	var next: Dictionary = _learning_snapshot()
	var adjusted: bool = next != _learning_before
	_learning_before = next
	if not app._learning_screen.visible: return
	if app._learning_screen.canvas.measured: notify("learning_measure")
	if adjusted: notify("learning_adjust")


func _workshop_changed() -> void:
	if not app._workshop_screen.visible: return
	if int(app.document.completion().filled) > 0: notify("workshop_place")
	if bool(app.document.completion().ready): notify("workshop_ready")


func _construction_changed() -> void:
	var studio: ConstructionStudio = app._construction_screen
	var changed_mode: bool = _construction_mode != studio.state.my_house_mode
	var count: int = studio.state.active_document().parts.size()
	var added: bool = count > _construction_count and not changed_mode
	_construction_mode = studio.state.my_house_mode
	_construction_count = count
	if not studio.visible: return
	if changed_mode: visit("my_house" if _construction_mode else "construction")
	if studio.state.phase == "building": notify("construction_accept")
	if added: notify("my_house_place" if _construction_mode else "construction_place")
	refresh.call_deferred()


func _target(id: String) -> Control:
	match id:
		"learning_measure": return _find_button(app._learning_screen._tools, "재어 보기")
		"learning_adjust": return app._learning_screen._adjustments if app._learning_screen.canvas.is_line_activity() else app._learning_screen._choices
		"learning_check": return app._learning_screen._primary
		"drawing_add": return _find_button(app._drawing_screen, "가운데에 도형 추가") if app._drawing_screen._palette_scroll.visible else app._drawing_screen.canvas
		"drawing_edit": return app._drawing_screen.canvas
		"drawing_undo": return app._drawing_screen._undo
		"masterpiece_chosen": return app._drawing_screen._masterpiece_button if app._drawing_screen._masterpiece_button.is_visible_in_tree() else app._drawing_screen._mode_masterpiece
		"masterpiece_guide": return app._drawing_screen._guide_toggle if app._drawing_screen._guide_toggle.is_visible_in_tree() else app._drawing_screen._more_edits
		"construction_accept": return app._construction_screen._client_action if app._construction_screen._client_action.is_visible_in_tree() else app._construction_screen._compact_details
		"construction_place": return app._construction_screen._guide_place if app._construction_screen._guide_place.is_visible_in_tree() else app._construction_screen.canvas
		"construction_inspect": return app._construction_screen._inspect
		"my_house_place": return app._construction_screen._palette
		"my_house_view": return app._construction_screen._material_view
		"workshop_place": return app.workshop
		"workshop_ready": return app._workshop_helpers
		"world_move", "world_jump": return app._touch_row if app._touch_row.is_visible_in_tree() else app._hud_controls
		"world_inventory": return _find_button(app._hud_actions, "가방", true)
		"world_journal": return app._quest_open_button
	return null


func _find_button(parent: Node, caption: String, partial: bool = false) -> Button:
	for child: Node in parent.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button.is_visible_in_tree() and (button.text.contains(caption) if partial else button.text == caption): return button
	return null
