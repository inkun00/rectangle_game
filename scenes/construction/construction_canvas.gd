class_name ConstructionCanvas
extends Control

const Model = preload("res://scripts/construction/construction_document.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Language = preload("res://scripts/construction/construction_language.gd")
const Art = preload("res://scripts/construction_art.gd")
const Simulation = preload("res://scenes/construction/construction_physics.gd")
const BOARD: Rect2 = Rect2(0, 0, 1000, 600)
const INK: Color = Color("1b2d30")
const PAPER: Color = Color("fbfcfa")
const GRID_COLOR: Color = Color(0.14, 0.30, 0.28, 0.16)
const MAJOR_GRID_COLOR: Color = Color(0.11, 0.26, 0.24, 0.32)
const SURROUND: Color = Color("bfd2cc")
const ACCENT: Color = Color("1f5d52")
const COPPER: Color = Color("d48c32")
const REPAIR_COLOR: Color = Color("b83b2a")
const GUIDE_AMBER: Color = Color("d9821e")
const CRANE_STEEL: Color = Color("e09028")
const CRANE_DARK: Color = Color("7d4610")
const SCAFFOLD_PIPE: Color = Color("4f6660")
const SCAFFOLD_PLANK: Color = Color("c28848")

signal hint_requested(message: String)
signal tool_changed
signal inspection_finished(report: Dictionary)

var document: Model:
	set(value):
		if document == value:
			return
		if document != null and document.changed.is_connected(_document_changed):
			document.changed.disconnect(_document_changed)
		document = value
		_sync_known_parts(false)
		if document != null and is_node_ready():
			document.changed.connect(_document_changed)
		cancel_gesture()
		stop_inspection()
		_clear_repair_report()
var editing_enabled: bool = true
var material_id: String = "wall"
var selected_kind: String = "rectangle"
var drawing_tool: bool = true
var inspection_running: bool = false
var inspection_visible: bool = false
var show_grid: bool = true
var presentation_mode: bool = false
var use_2d_background: bool = true
var fit_context: Rect2 = Rect2():
	set(value):
		if fit_context == value:
			return
		fit_context = value
		_schedule_fit()
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO
var cursor_position: Vector2 = Vector2(500, 500)
var last_report: Dictionary = {}
var repair_issue: Dictionary = {}
var facade_gaps: Array[Rect2] = []
var pan_tool: bool = false:
	set(value):
		if pan_tool == value:
			return
		pan_tool = value
		if pan_tool:
			cancel_gesture()
			drawing_tool = false
			if document != null:
				document.select(-1)
		_update_cursor()
		_update_gizmo()
		tool_changed.emit()
		queue_redraw()
var _simulation: Simulation
var _hovered: bool = false
var _dragging: bool = false
var _panning: bool = false
var _pending_place: bool = false
var _drag_painted: bool = false
var _last_paint_snapped: Vector2 = Vector2(-9999, -9999)
var _drag_id: int = -1
var _drag_origin: Vector2 = Vector2.ZERO
var _press_position: Vector2 = Vector2.ZERO
var _drag_position: Vector2 = Vector2.ZERO
var _auto_fit: bool = false
var _fit_pending: bool = false
var _known_part_ids: Dictionary = {}
var _place_anims: Dictionary = {}
var _particles: Array[Dictionary] = []
var _popups: Array[Dictionary] = []
var _crane_x: float = 500.0
var _part_gizmo: PanelContainer
var _gizmo_rotate: Button
var _gizmo_duplicate: Button
var _gizmo_delete: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	if document == null:
		document = Model.new()
	_sync_known_parts(false)
	document.changed.connect(_document_changed)
	resized.connect(_canvas_resized)
	visibility_changed.connect(_visibility_changed)
	mouse_entered.connect(func(): _hovered = true; _update_cursor(); queue_redraw())
	mouse_exited.connect(func(): _hovered = false; queue_redraw())
	_simulation = Simulation.new()
	_simulation.advanced.connect(queue_redraw)
	_simulation.finished.connect(_inspection_finished)
	add_child(_simulation)
	_setup_gizmo()
	set_process(false)
	_schedule_fit()

func _process(delta: float) -> void:
	var active: bool = false
	var finished_ids: Array[int] = []
	for part_id_var: Variant in _place_anims.keys():
		var part_id: int = int(part_id_var)
		var elapsed: float = float(_place_anims[part_id]) + delta
		if elapsed >= 0.20:
			finished_ids.append(part_id)
		else:
			_place_anims[part_id] = elapsed
			active = true
	for part_id: int in finished_ids:
		_place_anims.erase(part_id)
	for index: int in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[index]
		var age: float = float(p.get("age", 0.0)) + delta
		var life: float = float(p.get("life", 0.45))
		if age >= life:
			_particles.remove_at(index)
		else:
			p["age"] = age
			p["pos"] = Vector2(p.get("pos", Vector2.ZERO)) + Vector2(p.get("vel", Vector2.ZERO)) * delta
			_particles[index] = p
			active = true
	for index: int in range(_popups.size() - 1, -1, -1):
		var pop: Dictionary = _popups[index]
		var age: float = float(pop.get("age", 0.0)) + delta
		var life: float = float(pop.get("life", 0.75))
		if age >= life:
			_popups.remove_at(index)
		else:
			pop["age"] = age
			_popups[index] = pop
			active = true
	var target_crane_x: float = clampf(cursor_position.x, 110.0, 900.0)
	if absf(_crane_x - target_crane_x) > 0.5:
		_crane_x = lerpf(_crane_x, target_crane_x, minf(1.0, delta * 14.0))
		active = true
	else:
		_crane_x = target_crane_x
	queue_redraw()
	if not active:
		set_process(false)

func _sync_known_parts(spawn_effects: bool) -> void:
	if document == null:
		_known_part_ids.clear()
		return
	var current_ids: Dictionary = {}
	var newly_added: Array[Dictionary] = []
	for part: Dictionary in document.parts:
		var id: int = int(part.id)
		current_ids[id] = true
		if spawn_effects and not _known_part_ids.has(id):
			newly_added.append(part)
	var removed_count: int = 0
	for old_id_var: Variant in _known_part_ids.keys():
		if not current_ids.has(int(old_id_var)):
			removed_count += 1
	_known_part_ids = current_ids
	if not spawn_effects or not is_inside_tree() or not is_visible_in_tree():
		return
	if not newly_added.is_empty():
		var play_sound: bool = newly_added.size() <= 3
		for index: int in range(newly_added.size()):
			var part: Dictionary = newly_added[index]
			_spawn_part_juice(part, index == newly_added.size() - 1, play_sound and index == 0)
		if newly_added.size() > 3 and SoundManager.instance != null:
			SoundManager.instance.play_wood_hammer()
		set_process(true)
	elif removed_count > 0 and SoundManager.instance != null:
		SoundManager.instance.play_delete()

func _spawn_part_juice(part: Dictionary, show_callout: bool, play_audio: bool) -> void:
	var part_id: int = int(part.id)
	_place_anims[part_id] = 0.0
	var world_verts: PackedVector2Array = document.world_vertices(part)
	var bounds: Rect2 = QuadrilateralMath.bounds(world_verts)
	var material: Dictionary = Catalog.material(str(part.material_id))
	var role: String = str(material.get("role", "wall"))
	var dust_color: Color = Color("e8dfd1")
	if role == "roof":
		dust_color = Color("e5c4a8")
	elif role == "window":
		dust_color = Color("d8f0f8")
	elif role == "door" or role == "beam":
		dust_color = Color("e3cba8")
	for i: int in range(7):
		var ratio: float = float(i) / 6.0
		var spawn_pt: Vector2 = Vector2(lerpf(bounds.position.x, bounds.end.x, ratio), bounds.end.y - 2.0)
		var vx: float = (ratio - 0.5) * 75.0 + float((i % 3) - 1) * 12.0
		var vy: float = -18.0 - float(i % 4) * 9.0
		_particles.append({
			"pos": spawn_pt,
			"vel": Vector2(vx, vy),
			"radius": 4.5 + float(i % 3) * 1.8,
			"color": dust_color,
			"age": 0.0,
			"life": 0.38 + float(i % 3) * 0.06
		})
	if show_callout:
		var verb: String = "뚝딱!"
		match role:
			"roof": verb = "착! 지붕 시공"
			"window": verb = "반짝! 창문 설치"
			"door": verb = "쿵! 현관 시공"
			"beam": verb = "든든! 받침보 설치"
			"decor": verb = "멋지게 장식!"
			_: verb = "뚝딱! %s" % str(material.get("label", "벽 시공"))
		if _popups.size() >= 3:
			_popups.remove_at(0)
		_popups.append({
			"pos": Vector2(bounds.get_center().x, bounds.position.y - 8.0),
			"text": Language.simplify(verb),
			"age": 0.0,
			"life": 0.72
		})
	if play_audio and SoundManager.instance != null:
		SoundManager.instance.play_for_material_role(role)

func canvas_scale() -> float:
	return maxf(0.01, minf((size.x - 20.0) / BOARD.size.x, (size.y - 20.0) / BOARD.size.y)) * zoom

func _hint(message: String) -> void:
	hint_requested.emit(Language.simplify(message))

func artwork_to_screen(point: Vector2) -> Vector2:
	return (size - BOARD.size * canvas_scale()) * 0.5 + pan + point * canvas_scale()

func screen_to_artwork(point: Vector2) -> Vector2:
	return (point - (size - BOARD.size * canvas_scale()) * 0.5 - pan) / canvas_scale()

func set_presentation_mode(value: bool) -> void:
	presentation_mode = value
	queue_redraw()

func choose_material(id: String) -> void:
	var material: Dictionary = Catalog.material(id)
	if material.is_empty():
		return
	cancel_gesture()
	pan_tool = false
	material_id = id
	selected_kind = str(material.kind)
	drawing_tool = true
	if document != null:
		document.select(-1)
	_update_cursor()
	tool_changed.emit()
	queue_redraw()

func select_tool() -> void:
	cancel_gesture()
	drawing_tool = false
	pan_tool = false
	_update_cursor()
	_update_gizmo()
	tool_changed.emit()
	queue_redraw()

func toggle_pan_tool() -> bool:
	pan_tool = not pan_tool
	return pan_tool

func set_pan_tool(enabled: bool) -> void:
	pan_tool = enabled

func pan_by(delta_pan: Vector2) -> void:
	_auto_fit = false
	pan += delta_pan
	_limit_pan()
	_update_gizmo()
	queue_redraw()

func cancel_gesture() -> void:
	_dragging = false
	_pending_place = false
	_drag_painted = false
	_panning = false
	_update_gizmo()
	queue_redraw()

func zoom_by(factor: float, screen_anchor: Vector2 = Vector2(-1, -1)) -> void:
	_auto_fit = false
	var anchor: Vector2 = size * 0.5 if screen_anchor.x < 0.0 else screen_anchor
	var before: Vector2 = screen_to_artwork(anchor)
	zoom = clampf(zoom * factor, 1.0, 3.0)
	pan += anchor - artwork_to_screen(before)
	_limit_pan()
	_update_gizmo()
	queue_redraw()

func reset_view() -> void:
	_auto_fit = false
	zoom = 1.0
	pan = Vector2.ZERO
	_update_gizmo()
	queue_redraw()

func fit_parts() -> void:
	_auto_fit = true
	_apply_fit_parts()
	_schedule_fit()

func _canvas_resized() -> void:
	_update_gizmo()
	queue_redraw()
	_schedule_fit()

func _setup_gizmo() -> void:
	_part_gizmo = PanelContainer.new()
	_part_gizmo.visible = false
	_part_gizmo.mouse_filter = Control.MOUSE_FILTER_STOP
	_part_gizmo.add_theme_stylebox_override("panel", Art.pill_style(Color("162d2b"), 6, 2))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	_part_gizmo.add_child(row)
	_gizmo_rotate = _create_gizmo_button("회전", "rotate", "회전 (R 키)")
	_gizmo_rotate.pressed.connect(func():
		if document != null and editing_enabled and not inspection_running:
			if not document.rotate_selected(90.0):
				_hint(document.last_error)
			elif SoundManager.instance != null:
				SoundManager.instance.play_rotate_tick()
			_update_gizmo()
			queue_redraw()
	)
	row.add_child(_gizmo_rotate)
	_gizmo_duplicate = _create_gizmo_button("복제", "duplicate", "복제 (D 키)")
	_gizmo_duplicate.pressed.connect(func():
		if document != null and editing_enabled and not inspection_running:
			var dup_id: int = document.duplicate_selected()
			if dup_id < 0:
				_hint(document.last_error)
			elif SoundManager.instance != null:
				SoundManager.instance.play_snap()
			_update_gizmo()
			queue_redraw()
	)
	row.add_child(_gizmo_duplicate)
	_gizmo_delete = _create_gizmo_button("삭제", "delete", "삭제 (Del 키)")
	_gizmo_delete.pressed.connect(func():
		if document != null and editing_enabled and not inspection_running:
			document.delete_selected()
			if SoundManager.instance != null:
				SoundManager.instance.play_delete()
			_update_gizmo()
			queue_redraw()
	)
	row.add_child(_gizmo_delete)
	add_child(_part_gizmo)

func _create_gizmo_button(text: String, icon_name: String, tooltip: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.tooltip_text = tooltip
	btn.icon = Art.tool_icon(icon_name)
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 16)
	btn.add_theme_constant_override("h_separation", 4)
	btn.add_theme_font_override("font", QuadTheme.FONT)
	btn.add_theme_font_size_override("font_size", 12)
	btn.custom_minimum_size = Vector2(0, 30)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for mode: String in ["normal", "hover", "pressed", "disabled"]:
		var s: StyleBoxTexture = Art.button_style(mode == "pressed", mode, 2)
		s.content_margin_left = 6.0
		s.content_margin_right = 6.0
		s.content_margin_top = 2.0
		s.content_margin_bottom = 2.0
		btn.add_theme_stylebox_override(mode, s)
	for mode: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(mode, Color.WHITE)
	return btn

func _update_gizmo() -> void:
	if not is_instance_valid(_part_gizmo):
		return
	if document == null or document.selected_id < 0 or inspection_running or not editing_enabled or pan_tool:
		_part_gizmo.visible = false
		return
	var selected: Dictionary = document.get_selected()
	if selected.is_empty():
		_part_gizmo.visible = false
		return
	var min_p: Vector2 = Vector2(INF, INF)
	var max_p: Vector2 = Vector2(-INF, -INF)
	for v: Vector2 in selected.vertices:
		var world_v: Vector2 = v + Vector2(selected.position)
		var screen_v: Vector2 = artwork_to_screen(world_v)
		min_p.x = minf(min_p.x, screen_v.x)
		min_p.y = minf(min_p.y, screen_v.y)
		max_p.x = maxf(max_p.x, screen_v.x)
		max_p.y = maxf(max_p.y, screen_v.y)
	if min_p.x == INF:
		_part_gizmo.visible = false
		return
	var gizmo_size: Vector2 = _part_gizmo.get_combined_minimum_size()
	var gx: float = (min_p.x + max_p.x) * 0.5 - gizmo_size.x * 0.5
	var gy: float = min_p.y - gizmo_size.y - 8.0
	if gy < 8.0:
		gy = max_p.y + 8.0
	_part_gizmo.position = Vector2(
		clampf(gx, 8.0, maxf(8.0, size.x - gizmo_size.x - 8.0)),
		clampf(gy, 8.0, maxf(8.0, size.y - gizmo_size.y - 8.0))
	)
	_part_gizmo.visible = true

func _schedule_fit() -> void:
	if _auto_fit and not _fit_pending and is_inside_tree():
		_fit_pending = true
		_refit_after_layout.call_deferred()

func _refit_after_layout() -> void:
	_fit_pending = false
	if _auto_fit:
		_apply_fit_parts()

func _apply_fit_parts() -> void:
	cancel_gesture()
	var has_parts: bool = document != null and not document.parts.is_empty()
	if (not has_parts and not fit_context.has_area()) or size.x <= 32.0 or size.y <= 32.0:
		zoom = 1.0
		pan = Vector2.ZERO
		queue_redraw()
		return
	var bounds: Rect2 = fit_context
	if has_parts:
		var first_bounds: Rect2 = QuadrilateralMath.bounds(document.world_vertices(document.parts[0]))
		bounds = bounds.merge(first_bounds) if bounds.has_area() else first_bounds
		for index: int in range(1, document.parts.size()):
			bounds = bounds.merge(QuadrilateralMath.bounds(document.world_vertices(document.parts[index])))
	var framed: Rect2 = bounds.grow(24.0)
	var base_scale: float = maxf(0.01, minf((size.x - 20.0) / BOARD.size.x, (size.y - 20.0) / BOARD.size.y))
	var desired_scale: float = minf((size.x - 32.0) / maxf(framed.size.x, 1.0), (size.y - 32.0) / maxf(framed.size.y, 1.0))
	zoom = clampf(desired_scale / base_scale, 1.0, 3.0)
	pan = (BOARD.get_center() - framed.get_center()) * canvas_scale()
	_limit_pan()
	queue_redraw()

func _limit_pan() -> void:
	var limit: Vector2 = BOARD.size * canvas_scale() * 0.8 + size * 0.4
	pan = pan.clamp(-limit, limit)

func start_inspection() -> bool:
	if document == null or document.parts.is_empty() or _simulation == null:
		_hint("먼저 벽과 문, 창문을 놓아 주세요.")
		return false
	cancel_gesture()
	inspection_running = true
	inspection_visible = true
	_clear_repair_report()
	_simulation.start(document.parts, document.revision)
	_hint("무게와 받침을 확인하고 있어요. 문·창문 위에는 가로 받침이 필요해요.")
	tool_changed.emit()
	queue_redraw()
	return true

func stop_inspection() -> void:
	if _simulation != null:
		_simulation.stop()
	inspection_running = false
	inspection_visible = false
	_update_gizmo()
	queue_redraw()

func focus_repair(issue: Dictionary) -> bool:
	if not _has_fresh_report() or not last_report.get("issues", []).has(issue):
		return false
	var part_id: int = int(issue.get("part_id", -1))
	var part: Dictionary = document.part(part_id)
	if part.is_empty() or not last_report.get("unsupported_ids", []).has(part_id):
		return false
	stop_inspection()
	select_tool()
	document.select(part_id)
	repair_issue = issue.duplicate(true)
	_auto_fit = false
	var bounds: Rect2 = QuadrilateralMath.bounds(document.world_vertices(part)).grow(28.0)
	var base_scale: float = maxf(0.01, minf((size.x - 20.0) / BOARD.size.x, (size.y - 20.0) / BOARD.size.y))
	var desired_scale: float = minf(maxf(size.x - 64.0, 1.0) / bounds.size.x, maxf(size.y - 88.0, 1.0) / bounds.size.y)
	zoom = clampf(desired_scale / base_scale, 1.0, 3.0)
	pan = (BOARD.get_center() - bounds.get_center()) * canvas_scale()
	_limit_pan()
	cursor_position = Vector2(part.position)
	grab_focus()
	_hint(str(issue.get("message", "표시한 재료의 받침을 살펴보세요.")))
	queue_redraw()
	return true

func _has_fresh_report() -> bool:
	return document != null and not last_report.is_empty() and int(last_report.get("revision", -1)) == document.revision

func _clear_repair_report() -> void:
	last_report.clear()
	repair_issue.clear()
	facade_gaps.clear()

func show_facade_gaps(gaps: Array) -> void:
	stop_inspection()
	select_tool()
	facade_gaps.clear()
	for gap: Variant in gaps:
		if gap is Rect2: facade_gaps.append(gap)
	fit_parts()
	grab_focus()
	queue_redraw()

func add_at_cursor() -> void:
	if not _can_edit():
		return
	var position: Vector2 = document.snapped_position(material_id, cursor_position, selected_kind)
	var reason: String = document.placement_error(material_id, position, selected_kind)
	if not reason.is_empty():
		_hint(reason)
		return
	var id: int = document.add_part(material_id, position, selected_kind)
	if id < 0:
		_hint(document.last_error)
	else:
		_hint("%s 놓기 · %s" % [str(Catalog.material(material_id).label), Catalog.format_won(int(Catalog.material(material_id).price))])
	queue_redraw()

func _can_edit() -> bool:
	return editing_enabled and document != null and document.editing_enabled and not inspection_visible and is_visible_in_tree()

func _document_changed() -> void:
	_sync_known_parts(true)
	if _dragging and document.selected_id != _drag_id:
		_dragging = false
	if inspection_visible and _simulation != null and document.revision != _simulation.revision:
		stop_inspection()
	if not _has_fresh_report():
		_clear_repair_report()
	elif not repair_issue.is_empty() and document.selected_id != int(repair_issue.get("part_id", -1)):
		repair_issue.clear()
	_update_gizmo()
	queue_redraw()

func _inspection_finished(report: Dictionary) -> void:
	inspection_running = false
	last_report = report.duplicate(true)
	_hint(str(report.message))
	if SoundManager.instance != null:
		if bool(report.get("stable", false)):
			SoundManager.instance.play_snap()
		else:
			SoundManager.instance.play_delete()
	inspection_finished.emit(report)
	tool_changed.emit()
	_update_gizmo()
	queue_redraw()

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_gesture()
		stop_inspection()

func _gui_input(event: InputEvent) -> void:
	if document == null or not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2, event.position)
			accept_event()
			return
		if event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				_auto_fit = false
			_panning = event.pressed
			_update_cursor()
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and pan_tool:
			if event.pressed:
				_auto_fit = false
				_panning = true
			else:
				_panning = false
			_update_cursor()
			accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT or not _can_edit():
			return
		var point: Vector2 = screen_to_artwork(event.position)
		if event.pressed:
			if not BOARD.has_point(point):
				return
			grab_focus()
			_press(point)
		else:
			_release(point)
		accept_event()
	elif event is InputEventMouseMotion:
		if _panning:
			pan += event.relative
			_limit_pan()
			_update_cursor()
			queue_redraw()
			accept_event()
			return
		var point: Vector2 = screen_to_artwork(event.position)
		cursor_position = point
		set_process(true)
		if _pending_place and drawing_tool and material_id == "brick" and _can_edit() and BOARD.has_point(point):
			var snapped: Vector2 = document.snapped_position(material_id, point, selected_kind)
			if snapped != _last_paint_snapped and point.distance_to(_press_position) >= 18.0:
				if not _drag_painted:
					if document.placement_error(material_id, _last_paint_snapped, selected_kind).is_empty():
						document.add_part(material_id, _last_paint_snapped, selected_kind)
					_drag_painted = true
				if document.placement_error(material_id, snapped, selected_kind).is_empty():
					document.add_part(material_id, snapped, selected_kind)
					_hint("%s 연속 놓기 · %s" % [str(Catalog.material(material_id).label), Catalog.format_won(int(Catalog.material(material_id).price))])
				_last_paint_snapped = snapped
		elif _dragging:
			var selected: Dictionary = document.get_selected()
			if not selected.is_empty():
				_drag_position = document.snapped_position(str(selected.material_id), _drag_origin + point - _press_position, str(selected.kind), selected.vertices)
		_update_cursor()
		queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and not event.meta_pressed:
		if not _can_edit():
			return
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER] and drawing_tool and not pan_tool:
			add_at_cursor()
			accept_event()
		elif event.keycode == KEY_R and not document.get_selected().is_empty():
			cancel_gesture()
			if not document.rotate_selected(90.0):
				_hint(document.last_error)
			elif SoundManager.instance != null:
				SoundManager.instance.play_rotate_tick()
			queue_redraw()
			accept_event()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			cancel_gesture()
			var direction: Vector2 = Vector2.ZERO
			match event.keycode:
				KEY_LEFT: direction = Vector2.LEFT
				KEY_RIGHT: direction = Vector2.RIGHT
				KEY_UP: direction = Vector2.UP
				KEY_DOWN: direction = Vector2.DOWN
			var step: float = 10.0 if event.shift_pressed else 20.0
			if pan_tool:
				pan_by(direction * (step * 4.0))
			elif drawing_tool:
				cursor_position = (cursor_position + direction * step).clamp(BOARD.position, Vector2(1000, 560))
				set_process(true)
			elif not document.get_selected().is_empty():
				if not document.move_selected(Vector2(document.get_selected().position) + direction * step):
					_hint(document.last_error)
				elif SoundManager.instance != null:
					SoundManager.instance.play_snap()
			queue_redraw()
			accept_event()

func _press(point: Vector2) -> void:
	cancel_gesture()
	_press_position = point
	cursor_position = point
	if drawing_tool:
		_pending_place = true
		_drag_painted = false
		_last_paint_snapped = document.snapped_position(material_id, point, selected_kind)
	else:
		var id: int = _part_at(point)
		document.select(id)
		if id >= 0:
			_dragging = true
			_drag_id = id
			_drag_origin = Vector2(document.get_selected().position)
			_drag_position = _drag_origin
	_update_gizmo()
	queue_redraw()

func _release(point: Vector2) -> void:
	if _pending_place:
		var was_painted: bool = _drag_painted
		_pending_place = false
		_drag_painted = false
		if not was_painted:
			cursor_position = point
			add_at_cursor()
	elif _dragging:
		_dragging = false
		if not document.move_selected(_drag_origin + point - _press_position):
			_hint(document.last_error)
		elif SoundManager.instance != null:
			SoundManager.instance.play_snap()
	_update_gizmo()
	cancel_gesture()

func _part_at(point: Vector2) -> int:
	for index: int in range(document.parts.size() - 1, -1, -1):
		var part: Dictionary = document.parts[index]
		if QuadrilateralMath.contains_point(part.vertices, point - Vector2(part.position)):
			return int(part.id)
	return -1

func _draw() -> void:
	var board: Rect2 = Rect2(artwork_to_screen(Vector2.ZERO), BOARD.size * canvas_scale())
	_draw_work_surface(board)
	if show_grid and not presentation_mode:
		for x: int in range(0, 1001, 20):
			var first: Vector2 = artwork_to_screen(Vector2(x, 0))
			var last: Vector2 = artwork_to_screen(Vector2(x, Model.GROUND_Y))
			var pixel_x: float = floorf(first.x) + 0.5
			draw_line(Vector2(pixel_x, first.y), Vector2(pixel_x, last.y), MAJOR_GRID_COLOR if x % 100 == 0 else GRID_COLOR, 1.0)
		for y: int in range(0, 561, 20):
			var first: Vector2 = artwork_to_screen(Vector2(0, y))
			var last: Vector2 = artwork_to_screen(Vector2(1000, y))
			var pixel_y: float = floorf(first.y) + 0.5
			draw_line(Vector2(first.x, pixel_y), Vector2(last.x, pixel_y), MAJOR_GRID_COLOR if y % 100 == 0 else GRID_COLOR, 1.0)
	var show_preview: bool = document != null and not inspection_visible and drawing_tool and not pan_tool and _can_edit() and (_hovered or has_focus()) and BOARD.has_point(cursor_position)
	var preview_pos: Vector2 = Vector2.ZERO
	var preview_part: Dictionary = {}
	var preview_invalid: bool = false
	if show_preview:
		var material: Dictionary = Catalog.material(material_id)
		preview_pos = document.snapped_position(material_id, cursor_position, selected_kind)
		var reason: String = document.placement_error(material_id, preview_pos, selected_kind)
		preview_invalid = not reason.is_empty()
		preview_part = {"id": -1, "material_id": material_id, "kind": selected_kind, "position": preview_pos, "vertices": QuadrilateralMath.create_vertices(selected_kind, Vector2(material.dimensions))}
	if not presentation_mode and not inspection_visible:
		_draw_tower_crane(show_preview, preview_part)
		if document != null and not document.parts.is_empty():
			_draw_scaffolding()
	_draw_foundation()
	if document == null:
		return
	if inspection_visible and _simulation != null:
		for part: Dictionary in _simulation.rendered_parts():
			var bad: bool = last_report.get("unsupported_ids", []).has(int(part.id))
			_draw_part(part, _simulation.pose(int(part.id)), false, Color.WHITE, bad)
	else:
		for part: Dictionary in document.parts:
			var part_id: int = int(part.id)
			var position: Vector2 = _drag_position if _dragging and part_id == _drag_id else Vector2(part.position)
			if _place_anims.has(part_id):
				var progress: float = clampf(float(_place_anims[part_id]) / 0.20, 0.0, 1.0)
				var bounce: float = (1.0 - progress) * (1.0 - progress) * -14.0 + sin(progress * PI) * 3.0
				position.y += bounce
			_draw_part(part, Transform2D(0.0, position), editing_enabled and not presentation_mode and part_id == document.selected_id)
		if editing_enabled and not presentation_mode:
			_draw_opening_support_hints()
		if _has_fresh_report():
			_draw_repair_outlines()
		if show_preview:
			_draw_part(preview_part, Transform2D(0.0, preview_pos), false, Color(1, 1, 1, 0.68), preview_invalid)
	_draw_effects()
	if not presentation_mode:
		_draw_dimensions()
	for gap: Rect2 in facade_gaps:
		var area: Rect2 = Rect2(artwork_to_screen(gap.position), gap.size * canvas_scale())
		draw_rect(area, Color(0.75, 0.25, 0.15, 0.35))
		draw_rect(area, REPAIR_COLOR, false, 3.0)
	if not facade_gaps.is_empty():
		var label_position: Vector2 = artwork_to_screen(facade_gaps[0].position) - Vector2(0, 25)
		label_position = label_position.clamp(Vector2(6, 6), Vector2(maxf(6, size.x - 98), maxf(6, size.y - 30)))
		draw_rect(Rect2(label_position, Vector2(92, 24)), Color("fff6d5"))
		draw_rect(Rect2(label_position, Vector2(92, 24)), REPAIR_COLOR, false, 1.5)
		draw_string(QuadTheme.FONT, label_position + Vector2(6, 17), "벽 빈틈", HORIZONTAL_ALIGNMENT_LEFT, 80, 14, REPAIR_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), Color("284843"), false, 2.0)
	if has_focus():
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("e09b35"), false, 2.0)
	if inspection_running:
		var progress: float = clampf(_simulation.elapsed / Simulation.INSPECTION_SECONDS, 0.0, 1.0)
		draw_rect(Rect2(Vector2(14, 14), Vector2(size.x - 28, 9)), Color("1d3438"))
		draw_rect(Rect2(Vector2(14, 14), Vector2((size.x - 28) * progress, 9)), Color("f0aa3c"))
		draw_rect(Rect2(Vector2(14, 14), Vector2(size.x - 28, 9)), Color("fff4d4"), false, 1.0)

func _draw_work_surface(board: Rect2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("cde3df"))
	var sky_bands: Array[Color] = [
		Color("b5dff4"),
		Color("c6e7f6"),
		Color("d6eff7"),
		Color("e5f5f2"),
		Color("f1f8ec")
	]
	for band_i: int in range(sky_bands.size()):
		var y0: float = size.y * float(band_i) / float(sky_bands.size())
		var y1: float = size.y * float(band_i + 1) / float(sky_bands.size())
		draw_rect(Rect2(Vector2(0.0, y0), Vector2(size.x, y1 - y0 + 1.0)), sky_bands[band_i])
	draw_rect(Rect2(board.position + Vector2(0, 4), board.size), Color(0.06, 0.14, 0.13, 0.18))
	draw_rect(board, Color("e6f4f6") if presentation_mode else Color("edf7f8"))
	var ground_screen_y: float = artwork_to_screen(Vector2(0, Model.GROUND_Y)).y
	var sky_height: float = clampf(ground_screen_y - board.position.y, 0.0, board.size.y)
	if sky_height > 4.0:
		var sky_rect: Rect2 = Rect2(board.position, Vector2(board.size.x, sky_height))
		for band_i: int in range(sky_bands.size()):
			var by0: float = sky_rect.position.y + sky_rect.size.y * float(band_i) / float(sky_bands.size())
			var by1: float = sky_rect.position.y + sky_rect.size.y * float(band_i + 1) / float(sky_bands.size())
			draw_rect(Rect2(Vector2(sky_rect.position.x, by0), Vector2(sky_rect.size.x, by1 - by0 + 1.0)), sky_bands[band_i])
		_draw_2d_elevation_backdrop(board, ground_screen_y)
		if not presentation_mode:
			draw_rect(sky_rect, Color(0.95, 0.98, 0.99, 0.14))
	draw_rect(board, Color("294e46"), false, 2.0)
	if not presentation_mode:
		var corner_len: float = 14.0
		var corner_col: Color = Color("e09b35")
		for corner: Vector2 in [board.position, Vector2(board.end.x, board.position.y), board.end, Vector2(board.position.x, board.end.y)]:
			var dx: float = corner_len if corner.x == board.position.x else -corner_len
			var dy: float = corner_len if corner.y == board.position.y else -corner_len
			draw_line(corner, corner + Vector2(dx, 0), corner_col, 3.0)
			draw_line(corner, corner + Vector2(0, dy), corner_col, 3.0)

func _draw_2d_elevation_backdrop(_board: Rect2, _ground_screen_y: float) -> void:
	var scale_f: float = canvas_scale()
	# 2D Sun in upper right sky
	var sun_center: Vector2 = artwork_to_screen(Vector2(860, 92))
	draw_circle(sun_center, 34.0 * scale_f, Color(1.0, 0.94, 0.68, 0.55))
	draw_circle(sun_center, 24.0 * scale_f, Color("ffe27a"))
	# 2D Flat geometric clouds (trapezoid + rectangle layers)
	for cloud: Dictionary in [
		{"x": 165.0, "y": 88.0, "w": 110.0, "h": 26.0},
		{"x": 430.0, "y": 66.0, "w": 136.0, "h": 30.0},
		{"x": 690.0, "y": 108.0, "w": 96.0, "h": 24.0}
	]:
		var cx: float = float(cloud.x)
		var cy: float = float(cloud.y)
		var cw: float = float(cloud.w)
		var ch: float = float(cloud.h)
		var top_poly: PackedVector2Array = PackedVector2Array([
			artwork_to_screen(Vector2(cx - cw * 0.30, cy - ch)),
			artwork_to_screen(Vector2(cx + cw * 0.30, cy - ch)),
			artwork_to_screen(Vector2(cx + cw * 0.46, cy)),
			artwork_to_screen(Vector2(cx - cw * 0.46, cy))
		])
		draw_colored_polygon(top_poly, Color(1.0, 1.0, 1.0, 0.88))
		var base_rect: Rect2 = Rect2(artwork_to_screen(Vector2(cx - cw * 0.5, cy - ch * 0.35)), Vector2(cw, ch * 0.55) * scale_f)
		draw_rect(base_rect, Color(1.0, 1.0, 1.0, 0.92))
		draw_line(base_rect.position + Vector2(0, base_rect.size.y), base_rect.end, Color(0.76, 0.88, 0.93, 0.75), maxf(1.0, 2.0 * scale_f))
	# Far 2D quadrilateral mountain/hill ridge
	for hill: Array in [
		[Vector2(0, 560), Vector2(90, 420), Vector2(290, 420), Vector2(410, 560), Color("b8dccb")],
		[Vector2(280, 560), Vector2(420, 445), Vector2(630, 445), Vector2(770, 560), Color("c2e2d2")],
		[Vector2(620, 560), Vector2(750, 412), Vector2(920, 412), Vector2(1000, 560), Color("b4d8c7")]
	]:
		var pts: PackedVector2Array = PackedVector2Array([
			artwork_to_screen(hill[0]),
			artwork_to_screen(hill[1]),
			artwork_to_screen(hill[2]),
			artwork_to_screen(hill[3])
		])
		draw_colored_polygon(pts, hill[4])
	# Midground 2D gentle meadow hills
	for mid_hill: Array in [
		[Vector2(0, 560), Vector2(60, 486), Vector2(240, 486), Vector2(340, 560), Color("9eceb2")],
		[Vector2(660, 560), Vector2(760, 482), Vector2(940, 482), Vector2(1000, 560), Color("9eceb2")]
	]:
		var mpts: PackedVector2Array = PackedVector2Array([
			artwork_to_screen(mid_hill[0]),
			artwork_to_screen(mid_hill[1]),
			artwork_to_screen(mid_hill[2]),
			artwork_to_screen(mid_hill[3])
		])
		draw_colored_polygon(mpts, mid_hill[4])
	# 2D Front-elevation distant neighbor cottages on left & right margins
	for cottage: Dictionary in [
		{"x": 86.0, "w": 56.0, "h": 46.0, "wall": Color("efe6d5"), "roof": Color("d47b5a")},
		{"x": 884.0, "w": 62.0, "h": 50.0, "wall": Color("e8efe2"), "roof": Color("5b8fa8")}
	]:
		var hx: float = float(cottage.x)
		var hw: float = float(cottage.w)
		var hh: float = float(cottage.h)
		var wall_rect: Rect2 = Rect2(artwork_to_screen(Vector2(hx, Model.GROUND_Y - hh)), Vector2(hw, hh) * scale_f)
		draw_rect(wall_rect, cottage.wall)
		draw_rect(wall_rect, Color("5a6e68"), false, maxf(1.0, 1.4 * scale_f))
		var roof_pts: PackedVector2Array = PackedVector2Array([
			artwork_to_screen(Vector2(hx - 6.0, Model.GROUND_Y - hh)),
			artwork_to_screen(Vector2(hx + 8.0, Model.GROUND_Y - hh - 22.0)),
			artwork_to_screen(Vector2(hx + hw - 8.0, Model.GROUND_Y - hh - 22.0)),
			artwork_to_screen(Vector2(hx + hw + 6.0, Model.GROUND_Y - hh))
		])
		draw_colored_polygon(roof_pts, cottage.roof)
		var win_rect: Rect2 = Rect2(artwork_to_screen(Vector2(hx + hw * 0.34, Model.GROUND_Y - hh * 0.68)), Vector2(14.0, 14.0) * scale_f)
		draw_rect(win_rect, Color("bce6f4"))
		draw_rect(win_rect, Color("5a6e68"), false, 1.0)
	# 2D Front-elevation fence & lawn strip along the ground horizon
	var lawn_top: Vector2 = artwork_to_screen(Vector2(0, Model.GROUND_Y - 12.0))
	draw_rect(Rect2(lawn_top, Vector2(BOARD.size.x * scale_f, 12.0 * scale_f)), Color("7ab883"))
	for post_x: int in range(80, 940, 40):
		if post_x > 190 and post_x < 810:
			continue
		var post_rect: Rect2 = Rect2(artwork_to_screen(Vector2(post_x, Model.GROUND_Y - 26.0)), Vector2(6.0, 26.0) * scale_f)
		draw_rect(post_rect, Color("d8c3a5"))
		draw_rect(post_rect, Color("7d684d"), false, 1.0)
	for rail_y: float in [Model.GROUND_Y - 20.0, Model.GROUND_Y - 11.0]:
		for span: Vector2 in [Vector2(76, 186), Vector2(816, 932)]:
			var r0: Vector2 = artwork_to_screen(Vector2(span.x, rail_y))
			var r1: Vector2 = artwork_to_screen(Vector2(span.y, rail_y))
			draw_line(r0, r1, Color("cdb492"), maxf(1.5, 2.5 * scale_f))
	# 2D Quadrilateral trees standing on the ground line
	for tree_x: float in [168.0, 832.0]:
		var trunk_rect: Rect2 = Rect2(artwork_to_screen(Vector2(tree_x - 6.0, Model.GROUND_Y - 34.0)), Vector2(12.0, 34.0) * scale_f)
		draw_rect(trunk_rect, Color("8c6239"))
		draw_rect(trunk_rect, Color("593c1f"), false, 1.0)
		var lower_canopy: PackedVector2Array = PackedVector2Array([
			artwork_to_screen(Vector2(tree_x - 26.0, Model.GROUND_Y - 30.0)),
			artwork_to_screen(Vector2(tree_x - 16.0, Model.GROUND_Y - 64.0)),
			artwork_to_screen(Vector2(tree_x + 16.0, Model.GROUND_Y - 64.0)),
			artwork_to_screen(Vector2(tree_x + 26.0, Model.GROUND_Y - 30.0))
		])
		draw_colored_polygon(lower_canopy, Color("4da067"))
		var upper_canopy: PackedVector2Array = PackedVector2Array([
			artwork_to_screen(Vector2(tree_x - 19.0, Model.GROUND_Y - 56.0)),
			artwork_to_screen(Vector2(tree_x - 10.0, Model.GROUND_Y - 84.0)),
			artwork_to_screen(Vector2(tree_x + 10.0, Model.GROUND_Y - 84.0)),
			artwork_to_screen(Vector2(tree_x + 19.0, Model.GROUND_Y - 56.0))
		])
		draw_colored_polygon(upper_canopy, Color("63b87a"))

func _draw_tower_crane(show_hoist: bool, preview_part: Dictionary) -> void:
	var scale_f: float = canvas_scale()
	var mast_left: float = artwork_to_screen(Vector2(36, 0)).x
	var mast_right: float = artwork_to_screen(Vector2(62, 0)).x
	var jib_top: float = artwork_to_screen(Vector2(0, 22)).y
	var jib_bottom: float = artwork_to_screen(Vector2(0, 40)).y
	var ground_y: float = artwork_to_screen(Vector2(0, Model.GROUND_Y)).y
	var mast_col: Color = Color(CRANE_STEEL.r, CRANE_STEEL.g, CRANE_STEEL.b, 0.86)
	var brace_col: Color = Color(CRANE_DARK.r, CRANE_DARK.g, CRANE_DARK.b, 0.72)
	draw_line(Vector2(mast_left, jib_top), Vector2(mast_left, ground_y), mast_col, maxf(2.4, 3.2 * scale_f))
	draw_line(Vector2(mast_right, jib_top), Vector2(mast_right, ground_y), mast_col, maxf(2.4, 3.2 * scale_f))
	for y_art: int in range(40, int(Model.GROUND_Y), 36):
		var y0: float = artwork_to_screen(Vector2(0, y_art)).y
		var y1: float = artwork_to_screen(Vector2(0, minf(y_art + 36, Model.GROUND_Y))).y
		draw_line(Vector2(mast_left, y0), Vector2(mast_right, y0), brace_col, 1.6)
		draw_line(Vector2(mast_left, y0), Vector2(mast_right, y1), brace_col, 1.4)
	var jib_start_x: float = artwork_to_screen(Vector2(10, 0)).x
	var jib_end_x: float = artwork_to_screen(Vector2(965, 0)).x
	draw_line(Vector2(jib_start_x, jib_top), Vector2(jib_end_x, jib_top), mast_col, maxf(2.4, 3.0 * scale_f))
	draw_line(Vector2(jib_start_x, jib_bottom), Vector2(jib_end_x, jib_bottom), mast_col, maxf(2.6, 3.4 * scale_f))
	for x_art: int in range(20, 950, 40):
		var x0: float = artwork_to_screen(Vector2(x_art, 0)).x
		var x1: float = artwork_to_screen(Vector2(x_art + 20, 0)).x
		var x2: float = artwork_to_screen(Vector2(x_art + 40, 0)).x
		draw_line(Vector2(x0, jib_bottom), Vector2(x1, jib_top), brace_col, 1.4)
		draw_line(Vector2(x1, jib_top), Vector2(x2, jib_bottom), brace_col, 1.4)
	var counter_rect: Rect2 = Rect2(artwork_to_screen(Vector2(8, 26)), Vector2(24, 18) * scale_f)
	draw_rect(counter_rect, Color("485c5a"))
	draw_rect(counter_rect, Color("263634"), false, 1.4)
	var cab_rect: Rect2 = Rect2(artwork_to_screen(Vector2(54, 42)), Vector2(30, 24) * scale_f)
	draw_rect(cab_rect, Color("f4b644"))
	draw_rect(cab_rect, CRANE_DARK, false, 1.6)
	draw_rect(Rect2(cab_rect.position + Vector2(8, 4) * scale_f, Vector2(18, 11) * scale_f), Color("d5f4fc"))
	var trolley_x: float = _crane_x
	if show_hoist and not preview_part.is_empty():
		var preview_bounds: Rect2 = QuadrilateralMath.bounds(document.world_vertices(preview_part))
		trolley_x = clampf(preview_bounds.get_center().x, 90.0, 930.0)
	var trolley_screen: Vector2 = artwork_to_screen(Vector2(trolley_x, 40))
	var trolley_size: Vector2 = Vector2(30, 11) * scale_f
	var trolley_rect: Rect2 = Rect2(trolley_screen - Vector2(trolley_size.x * 0.5, trolley_size.y * 0.5), trolley_size)
	draw_rect(trolley_rect, Color("2e4440"))
	draw_rect(trolley_rect, Color("f7bc48"), false, 1.8)
	if show_hoist and not preview_part.is_empty():
		var preview_bounds: Rect2 = QuadrilateralMath.bounds(document.world_vertices(preview_part))
		var target_top: Vector2 = artwork_to_screen(Vector2(preview_bounds.get_center().x, preview_bounds.position.y))
		var hook_y: float = maxf(trolley_rect.end.y + 8.0 * scale_f, target_top.y - 6.0 * scale_f)
		draw_line(Vector2(trolley_screen.x - 3.0 * scale_f, trolley_rect.end.y), Vector2(target_top.x - 3.0 * scale_f, hook_y), Color(0.16, 0.25, 0.23, 0.80), 1.6)
		draw_line(Vector2(trolley_screen.x + 3.0 * scale_f, trolley_rect.end.y), Vector2(target_top.x + 3.0 * scale_f, hook_y), Color(0.16, 0.25, 0.23, 0.80), 1.6)
		var pulley: Rect2 = Rect2(Vector2(target_top.x - 7.5 * scale_f, hook_y - 5.0 * scale_f), Vector2(15.0, 10.0) * scale_f)
		draw_rect(pulley, Color("f6b238"))
		draw_rect(pulley, CRANE_DARK, false, 1.4)

func _draw_scaffolding() -> void:
	var bounds: Rect2 = _document_bounds()
	var scale_f: float = canvas_scale()
	var ground_y: float = Model.GROUND_Y
	var top_y: float = clampf(bounds.position.y - 20.0, 80.0, ground_y - 60.0)
	var pipe_col: Color = Color(SCAFFOLD_PIPE.r, SCAFFOLD_PIPE.g, SCAFFOLD_PIPE.b, 0.72)
	var brace_col: Color = Color(SCAFFOLD_PIPE.r, SCAFFOLD_PIPE.g, SCAFFOLD_PIPE.b, 0.48)
	var plank_col: Color = Color(SCAFFOLD_PLANK.r, SCAFFOLD_PLANK.g, SCAFFOLD_PLANK.b, 0.85)
	for side: int in [-1, 1]:
		var inner_x: float = (bounds.position.x - 14.0) if side < 0 else (bounds.end.x + 14.0)
		var outer_x: float = inner_x + float(side) * 28.0
		if minf(inner_x, outer_x) < 68.0 or maxf(inner_x, outer_x) > 975.0:
			continue
		var s_inner_top: Vector2 = artwork_to_screen(Vector2(inner_x, top_y))
		var s_inner_bot: Vector2 = artwork_to_screen(Vector2(inner_x, ground_y))
		var s_outer_top: Vector2 = artwork_to_screen(Vector2(outer_x, top_y))
		var s_outer_bot: Vector2 = artwork_to_screen(Vector2(outer_x, ground_y))
		draw_line(s_inner_top, s_inner_bot, pipe_col, maxf(1.8, 2.2 * scale_f))
		draw_line(s_outer_top, s_outer_bot, pipe_col, maxf(1.8, 2.2 * scale_f))
		var y_cursor: float = ground_y
		while y_cursor > top_y + 10.0:
			var next_y: float = maxf(top_y, y_cursor - 60.0)
			var p_in_0: Vector2 = artwork_to_screen(Vector2(inner_x, y_cursor))
			var p_out_0: Vector2 = artwork_to_screen(Vector2(outer_x, y_cursor))
			var p_in_1: Vector2 = artwork_to_screen(Vector2(inner_x, next_y))
			var p_out_1: Vector2 = artwork_to_screen(Vector2(outer_x, next_y))
			draw_line(p_in_1, p_out_1, plank_col, maxf(2.5, 3.5 * scale_f))
			draw_line(p_in_0, p_out_1, brace_col, 1.3)
			draw_line(p_out_0, p_in_1, brace_col, 1.3)
			y_cursor = next_y
		var flag_pole_top: Vector2 = s_outer_top - Vector2(0, 14.0 * scale_f)
		draw_line(s_outer_top, flag_pole_top, pipe_col, 1.8)
		var flag_pts: PackedVector2Array = PackedVector2Array([
			flag_pole_top,
			flag_pole_top + Vector2(float(side) * 14.0 * scale_f, 4.5 * scale_f),
			flag_pole_top + Vector2(0, 9.0 * scale_f)
		])
		draw_colored_polygon(flag_pts, Color("f07d26"))

func _draw_foundation() -> void:
	var start: Vector2 = artwork_to_screen(Vector2(0, Model.GROUND_Y))
	var width: float = BOARD.size.x * canvas_scale()
	var depth: float = 40.0 * canvas_scale()
	var scale_f: float = canvas_scale()
	draw_rect(Rect2(start, Vector2(width, depth)), Color("c5b49e"))
	var surface: Texture2D = Art.material_icon("wall")
	if surface != null:
		for offset: int in range(0, 1000, 80):
			var tile_start: Vector2 = start + Vector2(float(offset) * scale_f, 0)
			var tile_width: float = minf(80.0, 1000.0 - float(offset)) * scale_f
			draw_texture_rect(surface, Rect2(tile_start, Vector2(tile_width, depth)), false, Color("d4c7b4"))
	var curb_height: float = clampf(8.0 * scale_f, 5.0, 11.0)
	draw_rect(Rect2(start, Vector2(width, curb_height)), Color("5c7368"))
	for joint_x: int in range(0, 1000, 40):
		var sx: float = start.x + float(joint_x) * scale_f
		var stripe_w: float = minf(20.0, 1000.0 - float(joint_x)) * scale_f
		if not presentation_mode:
			draw_rect(Rect2(Vector2(sx, start.y), Vector2(stripe_w, minf(3.0, curb_height * 0.45))), Color(0.92, 0.72, 0.25, 0.55))
		draw_line(Vector2(sx, start.y), Vector2(sx, start.y + curb_height), Color(0.20, 0.30, 0.26, 0.55), 1.0)
	var baseline_y: float = floorf(start.y) + 0.5
	draw_line(Vector2(start.x, baseline_y), Vector2(start.x + width, baseline_y), Color("2d6e46"), 3.0)

func _draw_effects() -> void:
	var scale_f: float = canvas_scale()
	for p: Dictionary in _particles:
		var age: float = float(p.get("age", 0.0))
		var life: float = maxf(0.01, float(p.get("life", 0.4)))
		var ratio: float = clampf(age / life, 0.0, 1.0)
		var pos: Vector2 = artwork_to_screen(Vector2(p.get("pos", Vector2.ZERO)))
		var radius: float = float(p.get("radius", 5.0)) * (1.0 + ratio * 0.6) * scale_f
		var col: Color = Color(p.get("color", Color("e8dfd1")))
		col.a = (1.0 - ratio) * 0.78
		draw_circle(pos, radius, col)
	for pop: Dictionary in _popups:
		var age: float = float(pop.get("age", 0.0))
		var life: float = maxf(0.01, float(pop.get("life", 0.72)))
		var ratio: float = clampf(age / life, 0.0, 1.0)
		var base_pos: Vector2 = artwork_to_screen(Vector2(pop.get("pos", Vector2.ZERO)))
		var screen_pos: Vector2 = base_pos - Vector2(0.0, ratio * 22.0)
		var text: String = str(pop.get("text", "뚝딱!"))
		var text_w: float = QuadTheme.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var alpha: float = clampf((1.0 - ratio) * 1.4, 0.0, 1.0)
		var pill: Rect2 = Rect2(screen_pos - Vector2(text_w * 0.5 + 9.0, 17.0), Vector2(text_w + 18.0, 24.0))
		draw_rect(pill, Color(0.12, 0.34, 0.31, 0.94 * alpha))
		draw_rect(pill, Color(0.95, 0.72, 0.28, 0.92 * alpha), false, 1.5)
		draw_string(QuadTheme.FONT, Vector2(pill.position.x + 9.0, pill.position.y + 17.0), text, HORIZONTAL_ALIGNMENT_LEFT, text_w + 4.0, 13, Color(1.0, 0.98, 0.90, alpha))

func _draw_opening_support_hints() -> void:
	if document == null or document.parts.is_empty():
		return
	for part: Dictionary in document.parts:
		var material: Dictionary = Catalog.material(str(part.material_id))
		if not bool(material.get("opening", false)):
			continue
		var support: Dictionary = Simulation.opening_support(part, document.parts)
		if bool(support.get("supported", true)):
			continue
		var position: Vector2 = _drag_position if _dragging and int(part.id) == _drag_id else Vector2(part.position)
		var points: PackedVector2Array = _screen_points(part.vertices, Transform2D(0.0, position))
		for edge_index: int in support.get("missing_edges", []):
			if edge_index < 0 or edge_index >= points.size():
				continue
			var first: Vector2 = points[edge_index]
			var second: Vector2 = points[(edge_index + 1) % points.size()]
			draw_line(first, second, Color(1.0, 0.96, 0.84, 0.78), 5.0, true)
			draw_line(first, second, GUIDE_AMBER, 2.2, true)
		if int(part.id) == document.selected_id:
			var bounds: Rect2 = QuadrilateralMath.bounds(points)
			var tag_pos: Vector2 = Vector2(clampf(bounds.position.x, 28.0, maxf(28.0, size.x - 140.0)), clampf(bounds.position.y - 26.0, 26.0, maxf(26.0, size.y - 54.0)))
			var tag_rect: Rect2 = Rect2(tag_pos, Vector2(132.0, 22.0))
			draw_rect(tag_rect, Color("fff7df"))
			draw_rect(tag_rect, GUIDE_AMBER, false, 1.2)
			draw_string(QuadTheme.FONT, tag_pos + Vector2(6.0, 16.0), "둘레 벽·받침보 필요", HORIZONTAL_ALIGNMENT_LEFT, 120.0, 12, Color("7d460d"))

func _document_bounds() -> Rect2:
	var bounds: Rect2 = QuadrilateralMath.bounds(document.world_vertices(document.parts[0]))
	for index: int in range(1, document.parts.size()):
		bounds = bounds.merge(QuadrilateralMath.bounds(document.world_vertices(document.parts[index])))
	return bounds

func _draw_rulers() -> void:
	if not show_grid:
		return
	var board_top: float = clampf(artwork_to_screen(Vector2.ZERO).y, 4.0, size.y - 36.0)
	var board_left: float = clampf(artwork_to_screen(Vector2.ZERO).x, 4.0, size.x - 36.0)
	for x: int in range(100, 1000, 100):
		var screen_x: float = floorf(artwork_to_screen(Vector2(x, 0)).x) + 0.5
		if screen_x < 34.0 or screen_x > size.x - 24.0:
			continue
		var pill: Rect2 = Rect2(Vector2(screen_x - 13.0, board_top + 4.0), Vector2(26.0, 16.0))
		draw_rect(pill, Color(0.12, 0.24, 0.25, 0.74))
		draw_string(QuadTheme.FONT, Vector2(screen_x - 11.0, board_top + 16.0), str(int(float(x) / 20.0)), HORIZONTAL_ALIGNMENT_CENTER, 22.0, 10, Color("f6f1df"))
	for y: int in range(100, 501, 100):
		var screen_y: float = floorf(artwork_to_screen(Vector2(0, y)).y) + 0.5
		if screen_y < 32.0 or screen_y > size.y - 38.0:
			continue
		var pill: Rect2 = Rect2(Vector2(board_left + 4.0, screen_y - 8.0), Vector2(24.0, 16.0))
		draw_rect(pill, Color(0.12, 0.24, 0.25, 0.74))
		draw_string(QuadTheme.FONT, Vector2(board_left + 5.0, screen_y + 4.0), str(int(float(y) / 20.0)), HORIZONTAL_ALIGNMENT_CENTER, 22.0, 10, Color("f6f1df"))

func _draw_dimensions() -> void:
	if document.parts.is_empty() or inspection_visible: return
	var bounds: Rect2 = _document_bounds()
	var first: Vector2 = artwork_to_screen(bounds.position)
	var last: Vector2 = artwork_to_screen(bounds.end)
	if last.x - first.x < 80.0 or first.y < 60.0: return
	var dimension_y: float = first.y - 22.0
	var label: String = "가로 %s칸" % _format_dimension(bounds.size.x / Model.GRID)
	var text_width: float = QuadTheme.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var midpoint: float = (first.x + last.x) * 0.5
	draw_line(Vector2(first.x, first.y - 4), Vector2(first.x, dimension_y - 5), Color("4e6b62"), 1.0)
	draw_line(Vector2(last.x, first.y - 4), Vector2(last.x, dimension_y - 5), Color("4e6b62"), 1.0)
	draw_line(Vector2(first.x, dimension_y), Vector2(midpoint - text_width * 0.5 - 8, dimension_y), Color("36594f"), 1.2)
	draw_line(Vector2(midpoint + text_width * 0.5 + 8, dimension_y), Vector2(last.x, dimension_y), Color("36594f"), 1.2)
	for x: float in [first.x, last.x]: draw_line(Vector2(x - 3, dimension_y + 3), Vector2(x + 3, dimension_y - 3), ACCENT, 1.4, true)
	var pill_rect: Rect2 = Rect2(Vector2(midpoint - text_width * 0.5 - 8.0, dimension_y - 11.0), Vector2(text_width + 16.0, 22.0))
	draw_rect(pill_rect, Color("1d3c37"))
	draw_rect(pill_rect, Color("e6a23c"), false, 1.4)
	draw_string(QuadTheme.FONT, Vector2(midpoint - text_width * 0.5, dimension_y + 5), label, HORIZONTAL_ALIGNMENT_LEFT, text_width + 2, 13, Color("fff8e6"))
	if first.x < 48.0 or last.y - first.y < 90.0: return
	var height_x: float = first.x - 22.0
	var height_label: String = "높이 %s칸" % _format_dimension(bounds.size.y / Model.GRID)
	var height_text: float = QuadTheme.FONT.get_string_size(height_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var middle_y: float = (first.y + last.y) * 0.5
	draw_line(Vector2(height_x, first.y), Vector2(height_x, middle_y - height_text * 0.5 - 6.0), Color("36594f"), 1.2)
	draw_line(Vector2(height_x, middle_y + height_text * 0.5 + 6.0), Vector2(height_x, last.y), Color("36594f"), 1.2)
	for y: float in [first.y, last.y]:
		draw_line(Vector2(height_x - 5, y), Vector2(first.x - 4, y), Color("4e6b62"), 1.0)
		draw_line(Vector2(height_x - 3, y + 3), Vector2(height_x + 3, y - 3), ACCENT, 1.4, true)
	draw_set_transform(Vector2(height_x + 4.0, middle_y + height_text * 0.5), -PI * 0.5)
	draw_string(QuadTheme.FONT, Vector2.ZERO, height_label, HORIZONTAL_ALIGNMENT_LEFT, height_text + 2.0, 13, ACCENT)
	draw_set_transform(Vector2.ZERO)

func _format_dimension(value: float) -> String:
	return str(int(roundf(value))) if is_equal_approx(value, roundf(value)) else "%.1f" % value

func _draw_repair_outlines() -> void:
	for part: Dictionary in document.parts:
		var part_id: int = int(part.id)
		if not last_report.get("unsupported_ids", []).has(part_id):
			continue
		var position: Vector2 = _drag_position if _dragging and part_id == _drag_id else Vector2(part.position)
		var points: PackedVector2Array = _screen_points(part.vertices, Transform2D(0.0, position))
		_draw_outline(points, REPAIR_COLOR, 2.2)
		if repair_issue.is_empty() or part_id != int(repair_issue.get("part_id", -1)) or part_id != document.selected_id:
			continue
		for edge_index: int in repair_issue.get("missing_edges", []):
			if edge_index < 0 or edge_index >= points.size():
				continue
			var first: Vector2 = points[edge_index]
			var second: Vector2 = points[(edge_index + 1) % points.size()]
			draw_line(first, second, Color("fff6d5"), 8.0, true)
			draw_line(first, second, REPAIR_COLOR, 4.0, true)
			var midpoint: Vector2 = first.lerp(second, 0.5)
			draw_circle(midpoint, 9.0, Color("fff6d5"))
			draw_arc(midpoint, 9.0, 0.0, TAU, 20, REPAIR_COLOR, 2.0, true)
			draw_string(QuadTheme.FONT, midpoint + Vector2(-7.0, 4.0), "!", HORIZONTAL_ALIGNMENT_CENTER, 14.0, 12, INK)
		var bounds: Rect2 = QuadrilateralMath.bounds(points)
		var label_position: Vector2 = Vector2(clampf(bounds.position.x, 6.0, maxf(6.0, size.x - 94.0)), clampf(bounds.position.y - 27.0, 6.0, maxf(6.0, size.y - 52.0)))
		draw_rect(Rect2(label_position, Vector2(88.0, 23.0)), Color("fff6d5"))
		draw_rect(Rect2(label_position, Vector2(88.0, 23.0)), REPAIR_COLOR, false, 1.5)
		draw_string(QuadTheme.FONT, label_position + Vector2(6.0, 16.0), "고칠 재료", HORIZONTAL_ALIGNMENT_LEFT, 76.0, 14, INK)

func _draw_part(part: Dictionary, pose: Transform2D, selected: bool, tint: Color = Color.WHITE, invalid: bool = false) -> void:
	var vertices: PackedVector2Array = part.vertices
	var points: PackedVector2Array = _screen_points(vertices, pose)
	var material: Dictionary = Catalog.material(str(part.material_id))
	var role: String = str(material.get("role", "wall"))
	var scale_f: float = canvas_scale()
	if tint.a > 0.85 and points.size() == 4:
		var depth_offset: Vector2 = Vector2(4.0, 4.5) * scale_f
		var shadow_points: PackedVector2Array = PackedVector2Array()
		for pt: Vector2 in points:
			shadow_points.append(pt + depth_offset)
		draw_colored_polygon(shadow_points, Color(0.06, 0.14, 0.13, 0.22))
	var material_texture: Texture2D = Art.material_icon(str(part.material_id))
	var paint: Color = Color("e89083") * tint if invalid else tint
	if material_texture != null:
		if int(material.get("brick_count", 0)) > 1:
			_draw_wall_texture(vertices, pose, material_texture, paint)
		else:
			draw_polygon(points, PackedColorArray([paint]), Art.texture_uvs(material_texture), Art.texture_source(material_texture))
	if points.size() == 4 and tint.a > 0.85:
		draw_line(points[0], points[1], Color(1.0, 1.0, 0.94, 0.42), maxf(1.4, 2.0 * scale_f), true)
		if role == "roof":
			draw_line(points[3] + Vector2(0, 2.5 * scale_f), points[2] + Vector2(0, 2.5 * scale_f), Color(0.07, 0.14, 0.12, 0.32), maxf(2.2, 3.4 * scale_f), true)
		elif role == "window":
			var glint_a: Vector2 = points[0].lerp(points[2], 0.22)
			var glint_b: Vector2 = points[1].lerp(points[3], 0.32)
			draw_line(glint_a, glint_b, Color(1.0, 1.0, 1.0, 0.48), maxf(1.6, 2.5 * scale_f), true)
			draw_line(points[3], points[2], Color("5a4636"), maxf(2.2, 3.0 * scale_f), true)
		elif role == "door":
			draw_line(points[3], points[2], Color("4d3d30"), maxf(2.6, 3.8 * scale_f), true)
	_draw_outline(points, REPAIR_COLOR if invalid else ( Color("f0a830") if selected else Color("283b36")), 2.8 if selected or invalid else 1.4)
	if selected:
		for point: Vector2 in points:
			draw_circle(point, 5.0, Color("fff8e2"))
			draw_arc(point, 5.0, 0, TAU, 12, Color("d9861e"), 1.8, true)

func _draw_wall_texture(vertices: PackedVector2Array, pose: Transform2D, texture: Texture2D, paint: Color) -> void:
	# Repeat the generated single-brick pixels, so the visible count stays equal
	# to each counted catalog module, including rotation.
	var columns: int = maxi(1, roundi((vertices[1] - vertices[0]).length() / 40.0))
	var rows: int = maxi(1, roundi((vertices[2] - vertices[1]).length() / 20.0))
	for row: int in range(rows):
		for column: int in range(columns):
			var area: Rect2 = Rect2(float(column) / columns, float(row) / rows, 1.0 / columns, 1.0 / rows)
			var corners: PackedVector2Array = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
			var local: PackedVector2Array = PackedVector2Array()
			for corner: Vector2 in corners: local.append(_uv_point(vertices, corner))
			draw_polygon(_screen_points(local, pose), PackedColorArray([paint]), Art.texture_uvs(texture), Art.texture_source(texture))

func _uv_point(vertices: PackedVector2Array, uv: Vector2) -> Vector2:
	return vertices[0].lerp(vertices[1], uv.x).lerp(vertices[3].lerp(vertices[2], uv.x), uv.y)

func _screen_points(vertices: PackedVector2Array, pose: Transform2D) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for vertex: Vector2 in vertices:
		points.append(artwork_to_screen(pose * vertex))
	return points

func _draw_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, color, width, true)

func _update_cursor() -> void:
	if _panning or pan_tool:
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	elif drawing_tool:
		mouse_default_cursor_shape = Control.CURSOR_CROSS
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
