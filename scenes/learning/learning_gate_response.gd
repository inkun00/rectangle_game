extends VBoxContainer

const Bank = preload("res://scripts/learning/learning_question_bank.gd")
const FORM_MODES: Array[String] = ["choice", "short", "order", "match"]

signal changed
signal submit_requested

var short_input: LineEdit
var option_buttons: Array[Button] = []
var left_buttons: Array[Button] = []
var right_buttons: Array[Button] = []
var _question: Dictionary = {}
var _selected: int = -1
var _sequence: Array[int] = []
var _pairs: Array[int] = []
var _active_left: int = 0
var _options: VBoxContainer

func configure(question: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	short_input = null
	_options = null
	option_buttons.clear()
	left_buttons.clear()
	right_buttons.clear()
	_sequence.clear()
	_pairs.clear()
	_selected = -1
	_active_left = 0
	_question = question
	visible = str(question.mode) in FORM_MODES
	if not visible: return
	add_theme_constant_override("separation", 10)
	match str(question.mode):
		"short":
			short_input = LineEdit.new()
			short_input.name = "ShortAnswer"
			short_input.placeholder_text = "답을 입력하세요"
			short_input.custom_minimum_size.y = 48
			short_input.max_length = 80
			short_input.add_theme_font_override("font", QuadTheme.FONT)
			short_input.add_theme_font_size_override("font_size", 20)
			short_input.text_changed.connect(func(_value: String) -> void: changed.emit())
			short_input.text_submitted.connect(func(_value: String) -> void: submit_requested.emit())
			add_child(short_input)
		"match":
			_build_pairs()
		"choice", "order":
			var ordering: bool = question.mode == "order"
			if ordering:
				add_child(QuadTheme.paragraph("차례대로 카드를 누르세요. 고른 카드를 다시 누르면 순서에서 빠져요."))
			_options = VBoxContainer.new()
			_options.add_theme_constant_override("separation", 6)
			add_child(_options)
			for index: int in range(question.choices.size()):
				var button: Button = _card(str(question.choices[index]), _pick_option.bind(index))
				_options.add_child(button)
				option_buttons.append(button)
			_refresh_options()

func _card(label: String, callback: Callable) -> Button:
	var button: Button = QuadTheme.button(label, callback)
	button.toggle_mode = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button

func _pick_option(index: int) -> void:
	if _question.mode == "order":
		if _sequence.has(index): _sequence.erase(index)
		else: _sequence.append(index)
	else:
		_selected = index
	_refresh_options()
	changed.emit()

func _refresh_options() -> void:
	var remaining: int = _sequence.size()
	for index: int in range(option_buttons.size()):
		var button: Button = option_buttons[index]
		var label: String = str(_question.choices[index])
		if _question.mode == "order":
			var slot: int = _sequence.find(index)
			button.text = "%d. %s" % [slot + 1, label] if slot >= 0 else label
			button.set_pressed_no_signal(slot >= 0)
		else:
			button.set_pressed_no_signal(index == _selected)
			button.text = "✓  " + label if index == _selected else label
	# Keep chosen cards at the top, in the order the learner picked them.
	if _question.mode == "order":
		for slot: int in range(_sequence.size()):
			_options.move_child(option_buttons[_sequence[slot]], slot)
		for index: int in range(option_buttons.size()):
			if not _sequence.has(index):
				_options.move_child(option_buttons[index], remaining)
				remaining += 1

func _build_pairs() -> void:
	add_child(QuadTheme.paragraph("왼쪽 카드를 고른 뒤 짝이 되는 오른쪽 카드를 누르세요. 연결된 카드는 같은 번호로 표시돼요."))
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	add_child(columns)
	var left_column: VBoxContainer = VBoxContainer.new()
	var right_column: VBoxContainer = VBoxContainer.new()
	for column: VBoxContainer in [left_column, right_column]:
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 6)
		columns.add_child(column)
	for index: int in range(_question.left_items.size()):
		var button: Button = _card("%d. %s" % [index + 1, _question.left_items[index]], _pick_left.bind(index))
		left_column.add_child(button)
		left_buttons.append(button)
		_pairs.append(-1)
	for index: int in range(_question.right_items.size()):
		var button: Button = _card(str(_question.right_items[index]), _pair_right.bind(index))
		right_column.add_child(button)
		right_buttons.append(button)
	_refresh_pairs()

func _pick_left(index: int) -> void:
	_active_left = index
	_refresh_pairs()
	changed.emit()

func _pair_right(index: int) -> void:
	var previous: int = _pairs.find(index)
	if previous >= 0: _pairs[previous] = -1
	_pairs[_active_left] = index
	var unpaired: int = _pairs.find(-1)
	if unpaired >= 0: _active_left = unpaired
	_refresh_pairs()
	changed.emit()

func _refresh_pairs() -> void:
	for index: int in range(left_buttons.size()):
		left_buttons[index].set_pressed_no_signal(index == _active_left)
	for index: int in range(right_buttons.size()):
		var partner: int = _pairs.find(index)
		var label: String = str(_question.right_items[index])
		right_buttons[index].text = "%d. %s" % [partner + 1, label] if partner >= 0 else label
		right_buttons[index].set_pressed_no_signal(partner >= 0)

func focus_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if short_input != null: controls.append(short_input)
	if _options != null:
		for child: Node in _options.get_children(): controls.append(child as Control)
	for index: int in range(left_buttons.size()):
		controls.append(left_buttons[index])
		controls.append(right_buttons[index])
	return controls

func incomplete_message() -> String:
	match str(_question.mode):
		"choice":
			if _selected < 0: return "답을 하나 골라 주세요."
		"short":
			if short_input.text.strip_edges().is_empty(): return "답을 먼저 입력해 주세요."
		"order":
			if _sequence.size() != option_buttons.size(): return "남은 카드도 차례대로 골라 주세요."
		"match":
			if _pairs.has(-1): return "모든 카드의 짝을 연결해 주세요."
	return ""

func answer_correct() -> bool:
	match str(_question.mode):
		"choice": return _selected == int(_question.answer_index)
		"short": return Bank.short_answer_correct(_question, short_input.text)
		"order": return _sequence == _question.answer_order
		"match": return _pairs == _question.answer_pairs
	return false
