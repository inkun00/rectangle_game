class_name LearningStudio
extends Control

const Catalog = preload("res://scripts/learning/learning_catalog.gd")
const Progress = preload("res://scripts/learning/learning_progress.gd")
const Canvas = preload("res://scenes/learning/learning_canvas.gd")
const Art = preload("res://scripts/construction_art.gd")
signal home_requested
signal drawing_requested
var progress: Progress = Progress.new()
var canvas: Canvas
var lesson_id: String = "perpendicular"
var phase: int = 0
var _picker: OptionButton
var _goal: Label
var _task: Label
var _metrics: Label
var _feedback: Label
var _record: Label
var _slider: HSlider
var _adjustments: HBoxContainer
var _choices: HFlowContainer
var _choice_buttons: Array[Button] = []
var _reasons: VBoxContainer
var _primary: Button
var _scroll: ScrollContainer
var _tools: HFlowContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: TextureRect = TextureRect.new()
	background.texture = Art.quiet_surface_texture()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_TILE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	header.add_child(QuadTheme.button("메인", func(): home_requested.emit()))
	var title: Label = QuadTheme.label("사각형 직접 해 보기", 25)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_record = QuadTheme.label("", 16, QuadTheme.TEAL)
	header.add_child(_record)
	_picker = OptionButton.new()
	ButtonArt.apply(_picker)
	_picker.custom_minimum_size.y = 44
	for id: String in Catalog.IDS: _picker.add_item(str(Catalog.lesson(id).title))
	_picker.item_selected.connect(func(index: int): open_lesson(Catalog.IDS[index]))
	column.add_child(_picker)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	_scroll.add_child(body)
	_goal = QuadTheme.paragraph("", 18, QuadTheme.TEAL)
	body.add_child(_goal)
	_task = QuadTheme.paragraph("", 18, QuadTheme.INK)
	body.add_child(_task)
	canvas = Canvas.new()
	canvas.name = "LearningCanvas"
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.changed.connect(_canvas_changed)
	body.add_child(canvas)
	var tools: HFlowContainer = HFlowContainer.new()
	_tools = tools
	tools.add_theme_constant_override("h_separation", 8)
	tools.add_theme_constant_override("v_separation", 6)
	body.add_child(tools)
	tools.add_child(QuadTheme.button("재어 보기", func(): canvas.measure(), true))
	tools.add_child(QuadTheme.button("돌려 보기", func(): canvas.turn()))
	tools.add_child(QuadTheme.button("처음부터", func(): open_lesson(lesson_id)))
	_adjustments = HBoxContainer.new()
	_adjustments.add_theme_constant_override("separation", 12)
	body.add_child(_adjustments)
	_adjustments.add_child(QuadTheme.button("- 조절", func(): canvas.set_value(canvas.value - (10.0 if lesson_id == "distance" else 5.0))))
	_slider = HSlider.new()
	_slider.custom_minimum_size = Vector2(100, 44)
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.tooltip_text = "선의 방향이나 선분의 끝점을 조절해요. 방향키로도 움직일 수 있어요."
	_slider.value_changed.connect(func(value: float): canvas.set_value(value))
	_adjustments.add_child(_slider)
	_adjustments.add_child(QuadTheme.button("+ 조절", func(): canvas.set_value(canvas.value + (10.0 if lesson_id == "distance" else 5.0))))
	_choices = HFlowContainer.new()
	_choices.add_theme_constant_override("h_separation", 8)
	_choices.add_theme_constant_override("v_separation", 6)
	body.add_child(_choices)
	for index: int in range(4):
		var choice: Button = QuadTheme.button(Canvas.LETTERS[index], func(): canvas.toggle_choice(index))
		choice.toggle_mode = true
		_choice_buttons.append(choice)
		_choices.add_child(choice)
	_metrics = QuadTheme.paragraph("", 16, QuadTheme.INK)
	body.add_child(_metrics)
	_reasons = VBoxContainer.new()
	_reasons.add_theme_constant_override("separation", 8)
	body.add_child(_reasons)
	_feedback = QuadTheme.paragraph("", 18, QuadTheme.TEAL)
	body.add_child(_feedback)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	_primary = QuadTheme.button("확인하기", check_activity, true)
	_primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_primary)
	actions.add_child(QuadTheme.button("그림으로 만들기", func(): drawing_requested.emit()))
	progress.changed.connect(_refresh_record)
	open_lesson(progress.next_lesson())

func open_lesson(id: String) -> void:
	if not Catalog.IDS.has(id): return
	lesson_id = id
	phase = 0
	var lesson: Dictionary = Catalog.lesson(id)
	_picker.select(Catalog.IDS.find(id))
	_goal.text = "오늘의 목표 · " + str(lesson.goal)
	_task.text = str(lesson.task)
	canvas.configure(id)
	_slider.min_value = -100.0 if id == "distance" else 0.0
	_slider.max_value = 100.0 if id == "distance" else 180.0
	_slider.step = 10.0 if id == "distance" else 5.0
	_slider.set_value_no_signal(canvas.value)
	_adjustments.visible = canvas.is_line_activity()
	_choices.visible = not canvas.is_line_activity()
	for child: Node in _reasons.get_children():
		_reasons.remove_child(child)
		child.queue_free()
	_reasons.add_child(QuadTheme.paragraph("왜 그렇게 생각했나요?", 20, QuadTheme.INK))
	var reasons: Array[String] = Catalog.options(id)
	# The correct position varies by topic; no fixed-position answer shortcut.
	for index: int in range(3):
		var answer: int = (index + Catalog.IDS.find(id)) % 3
		var option: Button = QuadTheme.button(reasons[answer], answer_reason.bind(answer))
		option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_reasons.add_child(option)
	_reasons.hide()
	_feedback.text = "먼저 살펴보고 재어 보세요."
	_primary.text = "확인하기"
	_primary.disabled = false
	_scroll.scroll_vertical = 0
	_canvas_changed()
	_display_phase()
	_refresh_record()
	canvas.grab_focus()

func _display_phase() -> void:
	_goal.visible = phase == 0
	_task.visible = phase == 0
	_tools.visible = phase == 0
	_adjustments.visible = phase == 0 and canvas.is_line_activity()
	_choices.visible = phase == 0 and not canvas.is_line_activity()

func _canvas_changed() -> void:
	_slider.set_value_no_signal(canvas.value)
	_metrics.text = canvas.measurement_text()
	for index: int in range(_choice_buttons.size()):
		_choice_buttons[index].set_pressed_no_signal(canvas.selected_choices.has(index))
	if phase == 1 and not canvas.construction_correct():
		phase = 0
		_reasons.hide()
		_primary.disabled = false
		_primary.text = "확인하기"
		_feedback.text = "그림을 바꿨어요. 다시 확인해 볼까요?"
		_display_phase()

func check_activity() -> void:
	if phase == 1:
		phase = 0
		_reasons.hide()
		_primary.text = "확인하기"
		_feedback.text = "변과 각을 다시 살펴보고 확인해요."
		_display_phase()
		return
	if phase == 2:
		var next: int = (Catalog.IDS.find(lesson_id) + 1) % Catalog.IDS.size()
		open_lesson(Catalog.IDS[next])
		return
	if not canvas.measured:
		_feedback.text = "‘재어 보기’로 변과 각을 먼저 확인해요."
		return
	progress.record_attempt(lesson_id, false)
	if not canvas.construction_correct():
		_feedback.text = str(Catalog.lesson(lesson_id).hint)
		return
	phase = 1
	_reasons.show()
	_display_phase()
	_feedback.text = "잘 확인했어요. 그림에서 확인한 성질로 이유를 골라요."
	_primary.text = "그림 다시 살펴보기"
	_reasons.get_child(1).grab_focus()

func answer_reason(index: int) -> void:
	if phase != 1: return
	if index != 0:
		progress.record_attempt(lesson_id, false)
		_feedback.text = str(Catalog.lesson(lesson_id).hint)
		return
	progress.record_attempt(lesson_id, true)
	phase = 2
	_reasons.hide()
	_display_phase()
	_feedback.text = "확인하고 설명했어요! " + str(Catalog.lesson(lesson_id).reason)
	_primary.text = "다음 학습" if Catalog.IDS.find(lesson_id) < Catalog.IDS.size() - 1 else "다시 골라 연습하기"
	_primary.disabled = false
	_primary.grab_focus()

func _refresh_record() -> void:
	_record.text = "활동 기록 %d / %d" % [progress.completed.size(), Catalog.IDS.size()]
	for index: int in range(Catalog.IDS.size()):
		var id: String = Catalog.IDS[index]
		_picker.set_item_text(index, ("완료 · " if progress.completed.has(id) else "") + str(Catalog.lesson(id).title))
