class_name LearningGate
extends Control

const Canvas = preload("res://scenes/learning/learning_canvas.gd")
const GridCanvas = preload("res://scenes/learning/learning_grid_canvas.gd")

const Response = preload("res://scenes/learning/learning_gate_response.gd")

signal answer_submitted(correct: bool)

var question: Dictionary = {}
var canvas: Canvas
var grid_canvas: GridCanvas
var _mode: String = ""
var _response: Response
var _answer: int = -1
var _clear_feedback_on_edit: bool = false
var _panel: PanelContainer
var _scroll: ScrollContainer
var _progress: Label
var _progress_bar: ProgressBar
var _footer: BoxContainer
var _title: Label
var _prompt: Label
var _metrics: Label
var _feedback: Label
var _tools: HFlowContainer
var _measure: Button
var _measure_buttons: Array[Button] = []
var _turn: Button
var _undo: Button
var _reset: Button
var _adjustments: HBoxContainer
var _minus: Button
var _slider: HSlider
var _plus: Button
var _choices: HFlowContainer
var _choice_buttons: Array[Button] = []
var _check: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var workbench: TextureRect = TextureRect.new()
	workbench.texture = load("res://assets/generated/geometry-desk-v1/geometry-desk.webp") as Texture2D
	workbench.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	workbench.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	workbench.mouse_filter = Control.MOUSE_FILTER_IGNORE
	workbench.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(workbench)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", GameArt.panel(0, 24))
	center.add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var heading: Label = QuadTheme.paragraph("오늘의 수학 문제", 16, QuadTheme.TEAL)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(heading)
	_progress = QuadTheme.label("", 16, QuadTheme.INK)
	_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_progress)
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(76, 6)
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_bar.show_percentage = false
	var progress_track: StyleBoxTexture = StarfrontArt.gauge(7)
	progress_track.modulate_color = Color("505565")
	_progress_bar.add_theme_stylebox_override("background", progress_track)
	_progress_bar.add_theme_stylebox_override("fill", StarfrontArt.gauge(7))
	header.add_child(_progress_bar)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	_scroll.add_child(body)
	_title = QuadTheme.paragraph("", 29, QuadTheme.INK)
	body.add_child(_title)
	_prompt = QuadTheme.paragraph("", 18, QuadTheme.INK)
	body.add_child(_prompt)
	canvas = Canvas.new()
	canvas.name = "GateLearningCanvas"
	canvas.changed.connect(_interaction_changed)
	body.add_child(canvas)
	grid_canvas = GridCanvas.new()
	grid_canvas.name = "GateLearningGrid"
	grid_canvas.changed.connect(_interaction_changed)
	body.add_child(grid_canvas)
	_build_tools(body)
	_response = Response.new()
	_response.hide()
	_response.changed.connect(_interaction_changed)
	_response.submit_requested.connect(submit_answer)
	body.add_child(_response)
	_metrics = QuadTheme.paragraph("", 16, QuadTheme.MUTED)
	body.add_child(_metrics)
	_footer = BoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.add_theme_constant_override("separation", 14)
	column.add_child(_footer)
	_feedback = QuadTheme.paragraph("", 16, StarfrontArt.AMBER)
	_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer.add_child(_feedback)
	_check = QuadTheme.button("정답 확인하기", submit_answer, true)
	_check.name = "CheckMathGateAnswer"
	_check.custom_minimum_size.x = 164
	_check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_footer.add_child(_check)
	resized.connect(_layout)
	_layout()

func _build_tools(body: VBoxContainer) -> void:
	_tools = HFlowContainer.new()
	_tools.add_theme_constant_override("h_separation", 8)
	_tools.add_theme_constant_override("v_separation", 6)
	body.add_child(_tools)
	_measure_buttons = canvas.add_measure_buttons(_tools)
	_measure = _measure_buttons[0]
	_turn = QuadTheme.button("돌려 보기", canvas.turn)
	_undo = QuadTheme.button("되돌리기", grid_canvas.undo_last)
	_reset = QuadTheme.button("처음부터", grid_canvas.reset)
	for button: Button in [_turn, _undo, _reset]: _tools.add_child(button)
	_adjustments = HBoxContainer.new()
	_adjustments.add_theme_constant_override("separation", 8)
	body.add_child(_adjustments)
	_minus = QuadTheme.button("- 조절", _adjust.bind(-1))
	_adjustments.add_child(_minus)
	_slider = HSlider.new()
	_slider.custom_minimum_size = Vector2(60, 44)
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.tooltip_text = "방향키로 선의 방향이나 끝점을 움직일 수 있어요."
	_slider.value_changed.connect(canvas.set_value)
	_adjustments.add_child(_slider)
	_plus = QuadTheme.button("+ 조절", _adjust.bind(1))
	_adjustments.add_child(_plus)
	_choices = HFlowContainer.new()
	_choices.add_theme_constant_override("h_separation", 8)
	_choices.add_theme_constant_override("v_separation", 6)
	body.add_child(_choices)

func _layout() -> void:
	var width: float = minf(808.0, maxf(0.0, size.x - 24.0))
	var height: float = minf(680.0, maxf(0.0, size.y - 24.0))
	_footer.vertical = width < 540.0
	_progress_bar.visible = width >= 470.0
	var content_width: float = width - _panel.get_theme_stylebox("panel").get_minimum_size().x
	canvas.custom_minimum_size.y = clampf(minf(height * 0.43, content_width * 0.60), 150.0, 290.0)
	grid_canvas.custom_minimum_size.y = clampf(minf(height * 0.43, content_width * 0.70), 170.0, 290.0)
	_panel.custom_minimum_size = Vector2(width, height)

func present(value: Dictionary, step: int, total: int, feedback: String = "") -> void:
	question = value
	_mode = str(question.mode)
	_answer = -1
	_progress.text = "문제 %d / %d" % [step, total]
	_progress_bar.max_value = total
	_progress_bar.value = step
	_title.text = str(question.title)
	_prompt.text = str(question.prompt)
	_show_feedback(feedback)
	var drawing: bool = _mode == "draw"
	_response.configure(question)
	canvas.visible = not drawing and not _response.visible
	if not canvas.visible: canvas.close_measure_tools()
	grid_canvas.visible = drawing
	_tools.visible = not _response.visible
	_metrics.visible = not _response.visible
	_measure.visible = canvas.visible
	_turn.visible = canvas.visible
	_undo.visible = drawing
	_reset.visible = drawing
	_adjustments.visible = _mode == "line"
	_build_choices()
	if drawing:
		grid_canvas.configure(question)
	elif canvas.visible:
		var distance: bool = str(question.lesson_id) == "distance"
		_slider.min_value = -100.0 if distance else 0.0
		_slider.max_value = 100.0 if distance else 180.0
		_slider.step = 10.0 if distance else 5.0
		canvas.configure_activity(question)
	_check.disabled = false
	show()
	_interaction_changed()
	_scroll.set_deferred("scroll_vertical", 0)
	if _response.visible:
		_response.focus_controls()[0].grab_focus()
	elif drawing:
		grid_canvas.grab_focus()
	else:
		canvas.grab_focus()

func _build_choices() -> void:
	for button: Button in _choice_buttons:
		_choices.remove_child(button)
		button.queue_free()
	_choice_buttons.clear()
	_choices.visible = _mode in ["select", "measure"]
	if not _choices.visible: return
	var labels: Array = Canvas.LETTERS if _mode == "select" else question.choices
	for index: int in range(labels.size()):
		var button: Button = QuadTheme.button(str(labels[index]), _choose.bind(index))
		button.toggle_mode = true
		button.custom_minimum_size.x = 80
		_choices.add_child(button)
		_choice_buttons.append(button)

func _adjust(direction: int) -> void:
	canvas.set_value(canvas.value + _slider.step * direction)

func _choose(index: int) -> void:
	if _mode == "select":
		canvas.toggle_choice(index)
	else:
		_answer = index
		_interaction_changed()

func _interaction_changed() -> void:
	if question.is_empty(): return
	if _clear_feedback_on_edit: _show_feedback("")
	if _mode == "draw":
		_metrics.text = grid_canvas.measurement_text()
		_undo.disabled = not grid_canvas.has_edits()
		_reset.disabled = _undo.disabled
	elif canvas.visible:
		_slider.set_value_no_signal(canvas.value)
		_metrics.text = canvas.measurement_text()
		for index: int in range(_choice_buttons.size()):
			var selected: bool = canvas.selected_choices.has(index) if _mode == "select" else _answer == index
			_choice_buttons[index].set_pressed_no_signal(selected)
	_set_focus_order()

func _set_focus_order() -> void:
	var controls: Array[Control] = []
	if _response.visible:
		controls = _response.focus_controls()
	elif _mode == "draw":
		controls.append(grid_canvas)
		if not _undo.disabled: controls.append_array([_undo, _reset])
	else:
		controls.append(canvas)
		for button: Button in _measure_buttons:
			if button.visible: controls.append(button)
		controls.append(_turn)
		if _adjustments.visible: controls.append_array([_minus, _slider, _plus])
		controls.append_array(_choice_buttons)
	controls.append(_check)
	for index: int in range(controls.size()):
		var control: Control = controls[index]
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = control.get_path_to(controls[posmod(index - 1, controls.size())])
		control.focus_neighbor_left = control.focus_previous
		control.focus_neighbor_top = control.focus_previous
		control.focus_neighbor_right = control.focus_next
		control.focus_neighbor_bottom = control.focus_next

func _show_feedback(message: String, clear_on_edit: bool = false) -> void:
	_clear_feedback_on_edit = clear_on_edit
	_feedback.text = message
	_feedback.visible = not message.is_empty()

func submit_answer() -> void:
	if question.is_empty() or _check.disabled or not is_visible_in_tree(): return
	if _mode == "draw" and not grid_canvas.is_complete():
		_show_feedback("격자에서 꼭짓점 네 개를 이어 사각형을 완성해 주세요.", true)
		return
	if canvas.visible and not canvas.measured:
		_show_feedback("‘재어 보기’에서 자나 각도기를 꺼내 확인해 주세요.", true)
		return
	if _mode == "select" and canvas.selected_choices.is_empty():
		_show_feedback("조건에 맞는 도형을 모두 골라 주세요.", true)
		return
	if _mode == "measure" and _answer < 0:
		_show_feedback("재어 본 뒤 답을 하나 골라 주세요.", true)
		return
	var correct: bool
	if _response.visible:
		var incomplete: String = _response.incomplete_message()
		if not incomplete.is_empty():
			_show_feedback(incomplete, true)
			return
		correct = _response.answer_correct()
	elif _mode == "draw": correct = grid_canvas.construction_correct()
	elif _mode == "measure": correct = _answer == int(question.answer_index)
	else: correct = canvas.construction_correct()
	_check.disabled = true
	answer_submitted.emit(correct)

func _unhandled_key_input(_event: InputEvent) -> void:
	if is_visible_in_tree(): get_viewport().set_input_as_handled()
