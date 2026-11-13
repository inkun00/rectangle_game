class_name StoryCompletionDialog
extends ConfirmationDialog

signal submission_requested(metadata: Dictionary)

var _author: LineEdit
var _title: LineEdit
var _description: TextEdit
var _form: VBoxContainer
var _price: Label
var _feedback: Label
var _resume: bool = false
var _busy: bool = false
var _work: String = ""

func _ready() -> void:
	exclusive = true
	dialog_hide_on_ok = false
	get_label().hide()
	get_cancel_button().text = "닫기"
	for button: Button in [get_ok_button(), get_cancel_button()]:
		ButtonArt.apply(button)
		button.custom_minimum_size.y = 44
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(300, 225)
	add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	_price = QuadTheme.paragraph("", 20, QuadTheme.TEAL)
	column.add_child(_price)
	_form = VBoxContainer.new()
	_form.add_theme_constant_override("separation", 8)
	column.add_child(_form)
	_form.add_child(QuadTheme.paragraph("이름, 제목, 설명, 금액과 완성 PNG가 패들릿 전시관에 함께 올라가요.", 16, QuadTheme.INK))
	_author = _line("사용자 이름", ArtSubmissionMetadata.MAX_AUTHOR_LENGTH)
	_title = _line("작품 제목", ArtSubmissionMetadata.MAX_TITLE_LENGTH)
	_form.add_child(QuadTheme.paragraph("작품 설명", 16, QuadTheme.INK))
	_description = TextEdit.new()
	_description.placeholder_text = "어떤 사각형과 색을 사용했는지 소개해 주세요."
	_description.custom_minimum_size.y = 106
	_description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_description.add_theme_font_override("font", QuadTheme.FONT)
	_description.add_theme_font_size_override("font_size", 18)
	_form.add_child(_description)
	_author.text_submitted.connect(func(_text: String): _title.grab_focus())
	_title.text_submitted.connect(func(_text: String): _description.grab_focus())
	_description.text_changed.connect(_refresh)
	_feedback = QuadTheme.paragraph("", 16, QuadTheme.INK)
	column.add_child(_feedback)
	confirmed.connect(_submit)

func open_project(branch: String, price: int, author: String, resume: bool = false) -> void:
	_work = "우리 집" if branch == "earth" else "귀향선"
	title = "우리 집에서 새 출발" if branch == "earth" else "귀향선과 함께 출발"
	_price.text = ("재료비 " if branch == "earth" else "부품 제작비 ") + ConstructionCatalog.format_won(price)
	_resume = resume
	_busy = false
	_form.visible = not resume
	_author.text = author
	_title.clear()
	_description.clear()
	_refresh()
	popup_centered_clamped(Vector2i(610, 600 if not resume else 335), 0.9)
	if resume: get_ok_button().grab_focus()
	elif author.is_empty(): _author.grab_focus()
	else: _title.grab_focus()

func show_progress(message: String) -> void:
	_busy = true
	_refresh()
	_feedback.text = message

func show_failure(message: String, saved: bool) -> void:
	_busy = false
	_resume = saved
	_form.visible = not saved
	_refresh()
	_feedback.text = message

func _line(label: String, max_length: int) -> LineEdit:
	_form.add_child(QuadTheme.paragraph(label, 16, QuadTheme.INK))
	var line: LineEdit = LineEdit.new()
	line.max_length = max_length
	line.custom_minimum_size.y = 42
	line.add_theme_font_override("font", QuadTheme.FONT)
	line.add_theme_font_size_override("font_size", 18)
	line.text_changed.connect(func(_text: String): _refresh())
	_form.add_child(line)
	return line

func _validation_error() -> String:
	return ArtSubmissionMetadata.validation_error(_author.text, _title.text, _description.text, true).replace("건물 ", "작품 ")

func _refresh() -> void:
	if not is_instance_valid(_feedback): return
	var error: String = "" if _resume else _validation_error()
	get_ok_button().disabled = _busy or not error.is_empty()
	get_ok_button().text = "등록 중…" if _busy else ("등록 다시 시도" if _resume else "PNG 저장하고 엔딩 보기")
	get_cancel_button().disabled = _busy
	dialog_close_on_escape = not _busy
	_author.editable = not _busy
	_title.editable = not _busy
	_description.editable = not _busy
	_feedback.text = "%s PNG가 저장돼 있어요. 등록을 마치면 엔딩을 볼 수 있어요." % _work if _resume else error

func _submit() -> void:
	if _busy or (not _resume and not _validation_error().is_empty()): return
	submission_requested.emit({"author": _author.text, "title": _title.text, "description": _description.text})
