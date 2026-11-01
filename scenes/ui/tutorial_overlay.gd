class_name TutorialOverlay
extends Control
## A dialogue curtain becomes a small, click-through coach during practice.
## The director owns progress and evidence; this view never edits player data.

signal advance_requested
signal skip_requested

var _next_button: Button
var _skip_button: Button
var _scrim: ColorRect
var _panel: PanelContainer
var _speaker: Label
var _counter: Label
var _speech: Label
var _goal: Label
var _portrait: TextureRect
var _portrait_frame: PanelContainer
var _body: HBoxContainer
var _speech_scroll: ScrollContainer
var _column: VBoxContainer
var _target: Control
var _target_rect: Rect2 = Rect2()
var _highlight: StyleBoxFlat
var _blocking: bool = false
var _opened: bool = false
var _suspended: bool = false
var _built: bool = false
var _layout_pending: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	_build_ui()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_queue_layout)
	if not _opened:
		hide()
		set_process(false)


func _build_ui() -> void:
	if _built:
		return
	_built = true
	name = "TutorialOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim = ColorRect.new()
	_scrim.name = "DialogueCurtain"
	_scrim.color = Color(0.025, 0.045, 0.075, 0.62)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)
	_panel = PanelContainer.new()
	_panel.name = "TutorialDialogue"
	_panel.add_theme_stylebox_override("panel", StarfrontArt.panel(0, 18))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 12)
	_panel.add_child(_column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_column.add_child(header)
	_speaker = QuadTheme.label("길잡이", 20, StarfrontArt.AMBER)
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speaker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_speaker)
	_counter = QuadTheme.label("", 16, QuadTheme.MUTED)
	_counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_counter)
	_speech_scroll = ScrollContainer.new()
	_speech_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_speech_scroll.follow_focus = true
	_speech_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(_speech_scroll)
	_body = HBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 16)
	_speech_scroll.add_child(_body)
	_portrait_frame = PanelContainer.new()
	_portrait_frame.add_theme_stylebox_override("panel", StarfrontArt.panel(4, 8))
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_body.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.custom_minimum_size = Vector2(76, 96)
	_portrait_frame.add_child(_portrait)
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 10)
	_body.add_child(words)
	_speech = QuadTheme.paragraph("", 20, QuadTheme.INK)
	_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(_speech)
	_goal = QuadTheme.paragraph("", 17, QuadTheme.TEAL)
	_goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(_goal)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	_column.add_child(footer)
	_skip_button = QuadTheme.button("건너뛰기 Esc", _request_skip)
	_skip_button.name = "SkipTutorial"
	_skip_button.custom_minimum_size.y = 48.0
	footer.add_child(_skip_button)
	var space: Control = Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(space)
	_next_button = QuadTheme.button("다음", _request_advance, true)
	_next_button.name = "NextTutorialStep"
	_next_button.custom_minimum_size = Vector2(146, 48)
	footer.add_child(_next_button)
	_next_button.focus_next = _next_button.get_path_to(_skip_button)
	_next_button.focus_previous = _next_button.get_path_to(_skip_button)
	_skip_button.focus_next = _skip_button.get_path_to(_next_button)
	_skip_button.focus_previous = _skip_button.get_path_to(_next_button)
	_highlight = StyleBoxFlat.new()
	_highlight.bg_color = Color.TRANSPARENT
	_highlight.set_border_width_all(3)
	_highlight.border_color = QuadTheme.TEAL
	_highlight.set_corner_radius_all(0)
	_body.minimum_size_changed.connect(_queue_layout)


func present(step: Dictionary, index: int, total: int) -> void:
	_build_ui()
	_opened = true
	_blocking = str(step.get("event", "")).is_empty()
	_speaker.text = str(step.get("speaker", "길잡이"))
	_counter.text = "함께 해 보기  %d / %d" % [index + 1, maxi(1, total)]
	_speech.text = str(step.get("text", ""))
	_goal.text = str(step.get("goal", ""))
	_goal.visible = not _goal.text.is_empty()
	_portrait.texture = StarfrontArt.cell("crew", clampi(int(step.get("portrait", 3)), 0, 15), 4, 4, true)
	_next_button.disabled = not _blocking
	_next_button.text = ("시작하기" if index + 1 >= total else "다음") if _blocking else "직접 해 보기"
	_scrim.visible = _blocking
	_speech_scroll.scroll_vertical = 0
	_apply_visibility()
	_queue_layout()
	if _blocking and not _suspended:
		_next_button.grab_focus()
	elif _next_button.has_focus() or _skip_button.has_focus():
		get_viewport().gui_release_focus()
	queue_redraw()


func dismiss() -> void:
	_opened = false
	_suspended = false
	_blocking = false
	_target = null
	_target_rect = Rect2()
	_apply_visibility()
	queue_redraw()


func set_target(target: Control) -> void:
	_target = target
	_target_rect = _read_target_rect()
	_queue_layout()
	queue_redraw()


func set_suspended(suspended: bool) -> void:
	if _suspended == suspended:
		return
	_suspended = suspended
	_apply_visibility()
	if not suspended:
		_queue_layout()
		if _blocking and _opened:
			_next_button.grab_focus()


func is_blocking() -> bool:
	return _opened and _blocking and not _suspended


func _apply_visibility() -> void:
	visible = _opened and not _suspended
	set_process(visible)


func _request_advance() -> void:
	if is_blocking():
		advance_requested.emit()


func _request_skip() -> void:
	if _opened and not _suspended:
		skip_requested.emit()


func _input(event: InputEvent) -> void:
	if not _opened or _suspended or not is_visible_in_tree():
		return
	var was_blocking: bool = _blocking
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		var code: Key = key.keycode if key.keycode != KEY_NONE else key.physical_keycode
		if key.pressed and not key.echo:
			if code == KEY_ESCAPE:
				_request_skip()
				get_viewport().set_input_as_handled()
				return
			if was_blocking:
				if code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
					if _skip_button.has_focus():
						_request_skip()
					else:
						_request_advance()
				elif code in [KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
					if _skip_button.has_focus():
						_next_button.grab_focus()
					else:
						_skip_button.grab_focus()
		# Consume key releases and held shortcuts too. Mouse events must reach GUI.
		if was_blocking:
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and _blocking:
		var button: InputEventJoypadButton = event as InputEventJoypadButton
		if button.pressed:
			if button.button_index == JOY_BUTTON_B:
				_request_skip()
			elif button.button_index == JOY_BUTTON_A:
				if _skip_button.has_focus():
					_request_skip()
				else:
					_request_advance()
			elif button.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
				if _skip_button.has_focus():
					_next_button.grab_focus()
				else:
					_skip_button.grab_focus()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta, TAU)
	var target_rect: Rect2 = _read_target_rect()
	if not _target_rect.is_equal_approx(target_rect):
		_target_rect = target_rect
		_queue_layout()
	if not _blocking and _target_rect.has_area():
		queue_redraw()


func _read_target_rect() -> Rect2:
	if not is_instance_valid(_target) or not _target.is_visible_in_tree():
		return Rect2()
	var transform_to_overlay: Transform2D = get_global_transform_with_canvas().affine_inverse() * _target.get_global_transform_with_canvas()
	var bounds: Rect2 = Rect2(transform_to_overlay * Vector2.ZERO, Vector2.ZERO)
	for point: Vector2 in [Vector2(_target.size.x, 0), _target.size, Vector2(0, _target.size.y)]:
		bounds = bounds.expand(transform_to_overlay * point)
	return bounds.grow(6.0).intersection(Rect2(Vector2.ZERO, size))


func _queue_layout() -> void:
	if not _built or _layout_pending:
		return
	_layout_pending = true
	call_deferred("_layout")


func _layout() -> void:
	_layout_pending = false
	if not _built or not _opened or size.x <= 0.0 or size.y <= 0.0:
		return
	var compact: bool = size.x < 900.0 or size.y < 700.0
	var margin: float = 16.0 if compact else 24.0
	var width: float = minf(860.0, size.x - margin * 2.0)
	if not _blocking:
		width = minf(clampf(size.x * 0.42, 440.0, 560.0), size.x - margin * 2.0)
	_portrait.custom_minimum_size = Vector2(56, 76) if compact else Vector2(76, 96)
	_portrait_frame.visible = size.x >= 620.0
	_speech.add_theme_font_size_override("font_size", 18 if compact else 20)
	_goal.add_theme_font_size_override("font_size", 16 if compact else 17)
	_counter.add_theme_font_size_override("font_size", 16)
	_panel.size.x = width
	var max_speech: float = maxf(80.0, size.y - margin * 2.0 - 154.0)
	_speech_scroll.custom_minimum_size.y = clampf(_body.get_combined_minimum_size().y, 108.0, minf(260.0, max_speech))
	var height: float = minf(_panel.get_combined_minimum_size().y, size.y - margin * 2.0)
	_panel.size = Vector2(width, height)
	if _blocking:
		_panel.position = Vector2((size.x - width) * 0.5, size.y - height - margin)
	else:
		_panel.position = _practice_position(Vector2(width, height), margin)


func _practice_position(panel_size: Vector2, margin: float) -> Vector2:
	var upper_left: Vector2 = Vector2(margin, margin)
	var upper_right: Vector2 = Vector2(size.x - panel_size.x - margin, margin)
	var lower_left: Vector2 = Vector2(margin, size.y - panel_size.y - margin)
	var lower_right: Vector2 = size - panel_size - Vector2.ONE * margin
	var candidates: Array[Vector2] = [lower_right, upper_right, lower_left, upper_left]
	if not _target_rect.has_area():
		return upper_right
	var best: Vector2 = upper_right
	var score: float = INF
	for candidate: Vector2 in candidates:
		var overlap: Rect2 = Rect2(candidate, panel_size).intersection(_target_rect.grow(12.0))
		var overlap_area: float = overlap.get_area()
		if overlap_area < score:
			best = candidate
			score = overlap_area
	return best


func _draw() -> void:
	if not _opened or _suspended or _blocking or not _target_rect.has_area():
		return
	_highlight.border_color = Color(0.47, 0.89, 0.86, 0.78 + sin(_pulse * 2.0) * 0.12)
	draw_style_box(_highlight, _target_rect)
