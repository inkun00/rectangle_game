class_name DrawingStudio
extends Control

const Model = preload("res://scripts/core/drawing_document.gd")
const Canvas = preload("res://scenes/drawing/drawing_canvas.gd")
const Catalog = preload("res://scripts/core/drawing_catalog.gd")
const DrawingExport = preload("res://scripts/export/drawing_exporter.gd")
const SubmissionMetadata = preload("res://scripts/export/art_submission_metadata.gd")
const Buttons = preload("res://scripts/ui/button_art.gd")
const Commissions = preload("res://scripts/economy/art_commission_catalog.gd")
const Money = preload("res://scripts/construction/construction_catalog.gd")
const SAVE_PATH: String = "user://quadrilateral_drawing_v1.json"
const PERSONAL_SAVE_PATH: String = "user://quadrilateral_personal_drawing_v1.json"
const PADLET_BOARD_URL: String = "https://padlet.com/inkun02/padlet-s025d52oqqhj786g8cry"
const DRAWING_IDLE_MSEC: int = 15000
const TOOLBAR_FONT_SIZE: int = 16
const SHAPE_ORDER: Array[String] = ["square", "rectangle", "trapezoid", "parallelogram", "rhombus", "freeform"]
const TRAPEZOID_VARIANT_LABELS: Array[String] = ["양옆이 기울어진 모양", "왼쪽 두 각이 직각", "오른쪽 두 각이 직각"]
const SHAPE_ACTION_LABELS: Dictionary = {6: "뒤로 보내기", 7: "앞으로 보내기", 2: "왼쪽 15° 회전", 3: "오른쪽 15° 회전", 4: "축소", 5: "확대", 0: "복제", 1: "삭제"}
const GROUP_ACTION: int = 12
const UNGROUP_ACTION: int = 13
const SHAPE_HELP: Dictionary = {
	"square": "네 변의 길이가 같고, 네 각이 직각이에요.",
	"rectangle": "네 각이 모두 직각이에요. 길쭉한 벽이나 창문을 그려 봐요.",
	"trapezoid": "평행한 변이 한 쌍 이상 있어요. 지붕이나 화분을 만들어 봐요.",
	"parallelogram": "마주 보는 두 쌍의 변이 평행해요. 기울어진 길을 그려 봐요.",
	"rhombus": "네 변의 길이가 모두 같아요. 반짝이는 보석을 만들어 봐요.",
	"freeform": "종이에서 끌어 그려요. 그린 뒤에는 청록색 꼭짓점을 하나씩 움직여요."
}
const PALETTE: Array[Color] = [
	Color("ef5350"), Color("ff7043"), Color("ff9800"), Color("ffca28"), Color("ffee58"), Color("c0ca33"), Color("66bb6a"), Color("26a69a"),
	Color("26c6da"), Color("29b6f6"), Color("4285e1"), Color("5c6bc0"), Color("7e57c2"), Color("ab47bc"), Color("ec407a"), Color("f48fb1"),
	Color("ffcdd2"), Color("ffccbc"), Color("ffe0b2"), Color("fff3b0"), Color("f0f4c3"), Color("dcedc8"), Color("b9e4c9"), Color("b2dfdb"),
	Color("b2ebf2"), Color("b3e5fc"), Color("bbd5fb"), Color("c5cae9"), Color("d1c4e9"), Color("e1bee7"), Color("f8bbd0"), Color("ffe4ec"),
	Color("b71c1c"), Color("bf360c"), Color("b86b16"), Color("8d6e25"), Color("827717"), Color("4b752b"), Color("256b44"), Color("00695c"),
	Color("006978"), Color("155d87"), Color("234b8b"), Color("383b77"), Color("5b367f"), Color("7a3b67"), Color("ad4568"), Color("6d4c41"),
	Color("ffffff"), Color("fff8ed"), Color("e5e7eb"), Color("b0bec5"), Color("78909c"), Color("455a64"), Color("263238"), Color("121820")
]

signal home_requested
signal tutorial_requested
signal mode_selected(mode: String)
signal drawing_document_changed
signal interaction_context_changed
signal guide_changed
signal art_commission_requested(commission_id: String)
signal art_sale_requested(document_data: Dictionary)
signal drawing_exhibition_requested(data: Dictionary)
signal exhibition_board_requested
signal art_upload_retry_requested

var testing: bool = false
var tutorial_blocked: bool = false
var save_path: String = SAVE_PATH
var personal_save_path: String = PERSONAL_SAVE_PATH
var _commission_document: Model = Model.new()
var _personal_document: Model
var document: Model = _commission_document
var _personal_workspace: bool = false
var is_personal_drawing: bool:
	get: return _personal_workspace
var canvas: Canvas
var _autosave: Timer
var _status: Label
var _selection: Label
var _shape_hint: Label
var _undo: Button
var _redo: Button
var _select_button: Button
var _multiple_selection_button: Button
var _group_button: Button
var _ungroup_button: Button
var _shape_buttons: Dictionary = {}
var _selection_buttons: Array[Button] = []
var _color_picker: ColorPickerButton
var _restoring: bool = false
var _exporting: bool = false
var _mode_free: Button
var _mode_masterpiece: Button
var _background_button: Button
var _masterpiece_button: Button
var _masterpiece_tools: HBoxContainer
var _guide_toggle: CheckButton
var _guide_opacity: HSlider
var _guide_label: Label
var _gallery: AcceptDialog
var _color_dialog: AcceptDialog
var _swatches: Array[Button] = []
var _palette_scroll: ScrollContainer
var _shape_picker: OptionButton
var _trapezoid_variant_picker: OptionButton
var _more_edits: MenuButton
var _drawing_header: BoxContainer
var _sale_footer: BoxContainer
var _drawing_title: Label
var _drawing_tagline: Label
var _drawing_load: Button
var _shape_tools: HBoxContainer
var _tool_scroll: ScrollContainer
var _shape_context_menu: PopupMenu
var _context_shape_id: int = -1
var _main_colors: Array[Button] = []
var economy: ConstructionState
var _commission_dialog: AcceptDialog
var _commission_body: VBoxContainer
var _commission_player_reply: Label
var _commission_brief: Button
var _commission_summary: Label
var _work_commission_revision: int = 0
var _sale_button: Button
var _sale_dialog: ConfirmationDialog
var _sale_offer: Dictionary = {}
var _sale_pending: bool = false
var _exhibition: bool = false
var _publication_note: Label
var _exhibition_button: Button
var _submit_drawing_button: Button
var _form_key: String = ""
var _metadata_drafts: Dictionary = {}
var _sale_author: LineEdit
var _sale_title: LineEdit
var _sale_description: TextEdit
var _sale_description_count: Label
var _sale_price: Label
var _sale_validation: Label
var _sale_details: Label
var _sale_busy: ColorRect
var _upload_row: HFlowContainer
var _upload_status: Label
var _upload_retry: Button
var _upload_board: Button
var _upload_message: String = ""
var _upload_pending_count: int = 0
var _upload_post_url: String = PADLET_BOARD_URL
var _upload_busy: bool = false
var sold_art_directory: String = ""
var sale_author_name: String = ""
var sale_png_renderer: Callable = DrawingExport.export_png
var _drawing_work_until: int = 0
var _drawing_work_sample: int = 0

func _ready() -> void:
	set_process(false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_autosave = Timer.new()
	_autosave.one_shot = true
	_autosave.wait_time = 0.7
	_autosave.timeout.connect(func(): save_drawing(false))
	add_child(_autosave)
	document.changed.connect(_document_changed)
	document.artwork_edited.connect(_on_artwork_edited)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			_stop_drawing_work()
			cancel_gesture())
	if not testing:
		load_drawing(false)
	_refresh()

func open_workspace(personal: bool) -> bool:
	if is_personal_drawing == personal: return true
	if _sale_pending or _exporting: return false
	if personal and _personal_document == null:
		var candidate: Model = Model.new()
		if not testing and FileAccess.file_exists(personal_save_path):
			var saved: Dictionary = _read_drawing_snapshot(personal_save_path, false)
			if saved.is_empty() or not candidate.restore(saved.document):
				_set_status("저장한 그림을 읽을 수 없어요. 현재 그림은 그대로 두었어요.")
				return false
		_personal_document = candidate
	_record_drawing_work(Time.get_ticks_msec())
	if not testing and not _autosave.is_stopped() and not save_drawing(false): return false
	cancel_gesture()
	_stop_drawing_work()
	document.changed.disconnect(_document_changed)
	document.artwork_edited.disconnect(_on_artwork_edited)
	_personal_workspace = personal
	document = _personal_document if personal else _commission_document
	canvas.bind_document(document)
	document.changed.connect(_document_changed)
	document.artwork_edited.connect(_on_artwork_edited)
	canvas.show_masterpiece = personal and _guide_toggle.button_pressed
	if document.selected_id >= 0: canvas.select_tool()
	else: canvas.select_kind(canvas.selected_kind)
	_update_outline_menu()
	_set_status("원하는 배경과 도형을 골라 그림을 그려요." if personal else "의뢰인의 부탁을 살펴보고 그림을 그려요.")
	_refresh()
	_refresh_sale_button()
	drawing_document_changed.emit()
	return true

func _on_artwork_edited() -> void:
	if not testing: _begin_drawing_work(Time.get_ticks_msec())

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button: Button = QuadTheme.button(text, callback, primary)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("focus", Buttons.focus_style())
	return button

func _build_ui() -> void:
	var background: TextureRect = TextureRect.new()
	background.texture = load("res://assets/generated/drawing/artist-desk-v2.webp") as Texture2D
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 12)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	_drawing_header = BoxContainer.new()
	_drawing_header.add_theme_constant_override("separation", 10)
	column.add_child(_drawing_header)
	var identity: HBoxContainer = HBoxContainer.new()
	identity.add_theme_constant_override("separation", 10)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawing_header.add_child(identity)
	var home: Button = _button("← 메인", _go_home)
	home.name = "HomeButton"
	identity.add_child(home)
	var title: VBoxContainer = VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(title)
	_drawing_title = QuadTheme.label("사각형 그림 그리기", 25)
	title.add_child(_drawing_title)
	_drawing_tagline = QuadTheme.label("변과 각을 살피며 나만의 작품을 만들어요", 15, QuadTheme.MUTED)
	title.add_child(_drawing_tagline)
	_drawing_load = _button("불러오기", func(): load_drawing(true))
	var file_actions: HBoxContainer = HBoxContainer.new()
	file_actions.add_theme_constant_override("separation", 8)
	file_actions.size_flags_horizontal = Control.SIZE_SHRINK_END
	_drawing_header.add_child(file_actions)
	file_actions.add_child(_drawing_load)
	file_actions.add_child(_button("튜토리얼", func(): tutorial_requested.emit()))
	file_actions.add_child(_button("저장", func(): save_drawing(true)))
	file_actions.add_child(_button("PNG 저장", _export_png, true))
	_tool_scroll = ScrollContainer.new()
	_tool_scroll.name = "DrawingToolbarScroll"
	_tool_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_tool_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tool_scroll.follow_focus = true
	column.add_child(_tool_scroll)
	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.name = "DrawingToolbar"
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_theme_constant_override("separation", 6)
	_tool_scroll.add_child(toolbar)
	_exhibition_button = _button("그림 전시장 보기 ↗", func() -> void: exhibition_board_requested.emit())
	_exhibition_button.name = "OpenDrawingExhibition"
	_exhibition_button.tooltip_text = "새 창에서 패들릿 그림 전시장을 열어요."
	toolbar.add_child(_exhibition_button)
	var workspace: HBoxContainer = HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 12)
	column.add_child(workspace)
	_palette_scroll = ScrollContainer.new()
	_palette_scroll.custom_minimum_size.x = 220
	_palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_palette_scroll.follow_focus = true
	workspace.add_child(_palette_scroll)
	var palette: VBoxContainer = QuadTheme.card(_palette_scroll, Color.WHITE, 12)
	palette.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette.add_child(QuadTheme.label("도형 고르기", 19))
	for kind: String in SHAPE_ORDER:
		var button: Button = _button(QuadrilateralMath.kind_name(kind), func(): canvas.select_kind(kind))
		button.name = "Shape_" + kind
		button.icon = QuadTheme.icon(kind)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		palette.add_child(button)
		_shape_buttons[kind] = button
	_shape_hint = QuadTheme.paragraph("", 16, QuadTheme.INK)
	palette.add_child(_shape_hint)
	palette.add_child(_button("가운데에 도형 추가", func(): canvas.add_at_center()))
	palette.add_child(QuadTheme.paragraph("변 가운데의 손잡이를 끌면 크기가 바뀌어요. 둥근 화살표를 끌면 도형이 돌아가요.", 15, QuadTheme.INK))
	_masterpiece_button = _button("명화 밑그림 고르기", func(): _open_gallery(true))
	_masterpiece_button.name = "MasterpieceGalleryButton"
	palette.add_child(_masterpiece_button)
	_guide_label = QuadTheme.paragraph("", 15, QuadTheme.INK)
	palette.add_child(_guide_label)
	var center: VBoxContainer = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	workspace.add_child(center)
	_shape_tools = HBoxContainer.new()
	_shape_tools.add_theme_constant_override("separation", 6)
	toolbar.add_child(_shape_tools)
	_shape_picker = OptionButton.new()
	Buttons.apply(_shape_picker)
	_shape_picker.custom_minimum_size = Vector2(170, 44)
	for kind: String in SHAPE_ORDER: _shape_picker.add_icon_item(QuadTheme.icon(kind), QuadrilateralMath.kind_name(kind))
	_shape_picker.item_selected.connect(func(index: int): canvas.select_kind(SHAPE_ORDER[index]))
	_shape_tools.add_child(_shape_picker)
	_trapezoid_variant_picker = OptionButton.new()
	_trapezoid_variant_picker.name = "TrapezoidVariantPicker"
	Buttons.apply(_trapezoid_variant_picker)
	_trapezoid_variant_picker.custom_minimum_size = Vector2(220, 44)
	_trapezoid_variant_picker.tooltip_text = "새로 그릴 사다리꼴의 모양을 골라요. 한쪽 변의 두 각이 직각인 모양도 있어요."
	for label: String in TRAPEZOID_VARIANT_LABELS: _trapezoid_variant_picker.add_item(label)
	_trapezoid_variant_picker.item_selected.connect(func(index: int): canvas.select_trapezoid_variant(QuadrilateralMath.TRAPEZOID_VARIANTS[index]))
	_shape_tools.add_child(_trapezoid_variant_picker)
	_mode_free = _button("자유 그림", func(): _choose_mode("free"))
	_mode_free.name = "FreeDrawingMode"
	_mode_free.toggle_mode = true
	toolbar.add_child(_mode_free)
	_mode_masterpiece = _button("명화 채우기", func(): _choose_mode("masterpiece"))
	_mode_masterpiece.name = "MasterpieceMode"
	_mode_masterpiece.toggle_mode = true
	toolbar.add_child(_mode_masterpiece)
	_background_button = _button("배경 고르기", func(): _open_gallery(false))
	_background_button.name = "BackgroundGalleryButton"
	toolbar.add_child(_background_button)
	_select_button = _button("선택·이동", func(): canvas.select_tool())
	_select_button.toggle_mode = true
	toolbar.add_child(_select_button)
	_undo = _button("되돌리기", _undo_edit)
	_redo = _button("다시", _redo_edit)
	toolbar.add_child(_undo)
	toolbar.add_child(_redo)
	_more_edits = MenuButton.new()
	_more_edits.text = "편집 더 보기"
	_more_edits.flat = false
	Buttons.apply(_more_edits)
	_more_edits.focus_mode = Control.FOCUS_ALL
	_more_edits.custom_minimum_size.y = 44
	for caption: String in ["복제", "삭제", "왼쪽 15°", "오른쪽 15°", "축소", "확대", "뒤로 보내기", "앞으로 보내기", "모두 지우기", "불러오기"]:
		_more_edits.get_popup().add_item(caption)
	_more_edits.get_popup().id_pressed.connect(_more_edit_action)
	toolbar.add_child(_more_edits)
	_multiple_selection_button = _button("여러 선택", _toggle_multiple_selection)
	_multiple_selection_button.name = "MultipleSelectionToggle"
	_multiple_selection_button.toggle_mode = true
	_multiple_selection_button.tooltip_text = "도형을 하나씩 누르거나 빈 곳에서 끌어 여러 도형을 골라요. Shift를 누르고 도형을 눌러도 돼요."
	toolbar.add_child(_multiple_selection_button)
	_group_button = _button("묶기", _change_shape_group.bind(true))
	_group_button.name = "GroupSelectedShapes"
	_group_button.tooltip_text = "선택한 도형을 묶어 함께 움직여요. (Ctrl+G)"
	toolbar.add_child(_group_button)
	_ungroup_button = _button("묶음 풀기", _change_shape_group.bind(false))
	_ungroup_button.name = "UngroupSelectedShapes"
	_ungroup_button.tooltip_text = "선택한 묶음을 풀어 도형을 따로 움직여요. (Ctrl+Shift+G)"
	toolbar.add_child(_ungroup_button)
	_masterpiece_tools = HBoxContainer.new()
	_masterpiece_tools.add_theme_constant_override("separation", 6)
	toolbar.add_child(_masterpiece_tools)
	var guide_toggle: CheckButton = _check("밑그림 보기", true)
	_guide_toggle = guide_toggle
	guide_toggle.focus_mode = Control.FOCUS_ALL
	guide_toggle.toggled.connect(func(enabled: bool):
		canvas.show_masterpiece = enabled
		canvas.queue_redraw())
	_masterpiece_tools.add_child(guide_toggle)
	_masterpiece_tools.add_child(QuadTheme.label("진하기", 15))
	var opacity: HSlider = HSlider.new()
	_guide_opacity = opacity
	opacity.custom_minimum_size = Vector2(96, 44)
	opacity.focus_mode = Control.FOCUS_ALL
	opacity.min_value = 0.15
	opacity.max_value = 1.0
	opacity.step = 0.05
	opacity.value = 0.65
	opacity.tooltip_text = "밑그림 진하기"
	opacity.value_changed.connect(func(value: float):
		canvas.masterpiece_opacity = value
		canvas.queue_redraw())
	_masterpiece_tools.add_child(opacity)
	var another_masterpiece: Button = _button("다른 명화", func(): _open_gallery(true))
	_masterpiece_tools.add_child(another_masterpiece)
	for button: Button in [_mode_free, _mode_masterpiece, _background_button, _select_button, _undo, _redo, _more_edits, _multiple_selection_button, _group_button, _ungroup_button, another_masterpiece]:
		button.add_theme_font_size_override("font_size", TOOLBAR_FONT_SIZE)
	canvas = Canvas.new()
	canvas.name = "DrawingCanvas"
	canvas.document = document
	canvas.show_masterpiece = false
	canvas.custom_minimum_size = Vector2(240, 160)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.hint_requested.connect(_set_status)
	canvas.tool_changed.connect(_refresh)
	canvas.context_menu_requested.connect(_show_shape_context_menu)
	center.add_child(canvas)
	_shape_context_menu = PopupMenu.new()
	_shape_context_menu.name = "ShapeContextMenu"
	_shape_context_menu.add_theme_font_override("font", QuadTheme.FONT)
	_shape_context_menu.add_theme_font_size_override("font_size", 18)
	_shape_context_menu.add_theme_constant_override("v_separation", 10)
	_shape_context_menu.add_theme_stylebox_override("panel", GameArt.panel(0, 10))
	_shape_context_menu.add_theme_stylebox_override("hover", Buttons.style(false, "hover", 8))
	_shape_context_menu.add_theme_color_override("font_color", QuadTheme.INK)
	_shape_context_menu.add_theme_color_override("font_hover_color", Color.WHITE)
	_shape_context_menu.add_theme_color_override("font_disabled_color", QuadTheme.MUTED)
	_shape_context_menu.id_pressed.connect(_shape_context_action)
	_shape_context_menu.popup_hide.connect(func():
		interaction_context_changed.emit()
		_clear_context_target.call_deferred())
	add_child(_shape_context_menu)
	var colors: HFlowContainer = HFlowContainer.new()
	colors.add_theme_constant_override("h_separation", 6)
	colors.add_theme_constant_override("v_separation", 6)
	center.add_child(colors)
	for index: int in [0, 2, 6, 9, 48, 55, 3, 12, 14]:
		var swatch: Button = _make_swatch(PALETTE[index])
		colors.add_child(swatch)
		_main_colors.append(swatch)
	colors.add_child(_button("56색", _open_colors))
	_color_picker = ColorPickerButton.new()
	Buttons.apply(_color_picker)
	_color_picker.custom_minimum_size = Vector2(48, 44)
	_color_picker.color = canvas.paint_color
	_color_picker.edit_alpha = false
	_color_picker.tooltip_text = "직접 색 고르기"
	_color_picker.color_changed.connect(_choose_color)
	_color_picker.get_popup().visibility_changed.connect(func(): interaction_context_changed.emit())
	colors.add_child(_color_picker)
	var grid: CheckButton = _check("격자", true)
	grid.toggled.connect(func(enabled: bool):
		canvas.show_grid = enabled
		canvas.queue_redraw())
	colors.add_child(grid)
	var snap: CheckButton = _check("자석", true)
	snap.name = "SnapToggle"
	snap.tooltip_text = "다른 도형의 꼭짓점과 변 가까이에서 딱 붙어요."
	snap.toggled.connect(func(enabled: bool):
		canvas.snap_enabled = enabled
		canvas.queue_redraw())
	colors.add_child(snap)
	_selection = QuadTheme.paragraph("", 15, QuadTheme.INK)
	center.add_child(_selection)
	_sale_footer = BoxContainer.new()
	_sale_footer.name = "DrawingSaleFooter"
	var commission_actions: HFlowContainer = HFlowContainer.new()
	commission_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commission_actions.add_theme_constant_override("h_separation", 8)
	commission_actions.add_theme_constant_override("v_separation", 4)
	_sale_footer.add_child(commission_actions)
	_sale_button = _button("그림 의뢰 받기", _open_commission_action, true)
	_sale_button.name = "SellDrawingButton"
	_sale_button.custom_minimum_size = Vector2(156, 48)
	commission_actions.add_child(_sale_button)
	_submit_drawing_button = _button("내 그림 등록", open_exhibition)
	_submit_drawing_button.name = "SubmitDrawingToPadlet"
	commission_actions.add_child(_submit_drawing_button)
	_commission_brief = _button("의뢰서 보기", _open_commissions)
	_commission_brief.name = "OpenArtCommissionBrief"
	commission_actions.add_child(_commission_brief)
	var status_panel: PanelContainer = PanelContainer.new()
	status_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_panel.add_theme_stylebox_override("panel", GameArt.panel(0, 6))
	_sale_footer.add_child(status_panel)
	var footer_text: VBoxContainer = VBoxContainer.new()
	footer_text.alignment = BoxContainer.ALIGNMENT_CENTER
	status_panel.add_child(footer_text)
	_commission_summary = QuadTheme.label("", 15, QuadTheme.TEAL)
	_commission_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer_text.add_child(_commission_summary)
	_status = QuadTheme.paragraph("의뢰인의 부탁을 살펴보고 그림을 그려요.", 14, QuadTheme.INK)
	footer_text.add_child(_status)
	column.add_child(_sale_footer)
	_upload_row = HFlowContainer.new()
	_upload_row.name = "ArtUploadStatus"
	_upload_row.add_theme_constant_override("h_separation", 10)
	_upload_row.add_theme_constant_override("v_separation", 4)
	column.add_child(_upload_row)
	_upload_status = QuadTheme.paragraph("", 14, QuadTheme.TEAL)
	_upload_status.custom_minimum_size = Vector2(220, 36)
	_upload_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_upload_row.add_child(_upload_status)
	_upload_retry = _button("등록 다시 시도", _request_art_upload_retry)
	_upload_retry.name = "RetryArtUploadButton"
	_upload_row.add_child(_upload_retry)
	_upload_board = _button("패들릿 보기", _open_art_board)
	_upload_board.name = "OpenArtPadletButton"
	_upload_row.add_child(_upload_board)
	_refresh_upload_status()
	_refresh_sale_button()
	resized.connect(_responsive_drawing)
	_responsive_drawing()

func _responsive_drawing() -> void:
	if not is_instance_valid(canvas): return
	var narrow: bool = size.x < 620.0
	_drawing_header.vertical = narrow
	_sale_footer.vertical = narrow
	_sale_footer.add_theme_constant_override("separation", 5 if narrow else 14)
	var spacious: bool = size.x >= 1250 and size.y >= 760
	_palette_scroll.visible = spacious
	_shape_picker.visible = not spacious
	_shape_tools.visible = not spacious or canvas.selected_kind == "trapezoid"
	_drawing_tagline.visible = not narrow and size.y >= 760
	_drawing_load.visible = size.x >= 1000
	_drawing_title.add_theme_font_size_override("font_size", 22 if size.x < 1000 else 25)
	for index: int in range(_main_colors.size()): _main_colors[index].visible = index < (9 if spacious else 6)
	if _background_button != null: _background_button.text = "배경 고르기"

func _update_outline_menu() -> void:
	var menu: PopupMenu = _more_edits.get_popup()
	if is_personal_drawing and menu.item_count == 10:
		menu.add_item("밑그림 표시 전환", 10)
		menu.add_item("밑그림 진하기 바꾸기", 11)
	elif not is_personal_drawing:
		menu.item_count = 10

func _more_edit_action(id: int) -> void:
	if id >= 10 and not is_personal_drawing: return
	cancel_gesture()
	if id < 8 and document.get_selected().is_empty():
		_set_status("먼저 선택·이동으로 도형을 골라 주세요.")
		return
	match id:
		0: document.duplicate_selected()
		1: document.delete_selected()
		2: document.rotate_selected(-15.0)
		3: document.rotate_selected(15.0)
		4: document.scale_selected(0.9)
		5: document.scale_selected(1.1)
		6: document.shift_selected_layer(-1)
		7: document.shift_selected_layer(1)
		8: _clear_drawing()
		9: load_drawing(true)
		10:
			canvas.show_masterpiece = not canvas.show_masterpiece
			_guide_toggle.set_pressed_no_signal(canvas.show_masterpiece)
			canvas.queue_redraw()
			guide_changed.emit()
		11:
			canvas.masterpiece_opacity = 0.25 if canvas.masterpiece_opacity >= 0.9 else minf(canvas.masterpiece_opacity + 0.2, 1.0)
			_guide_opacity.set_value_no_signal(canvas.masterpiece_opacity)
			canvas.queue_redraw()
			guide_changed.emit()

func _toggle_multiple_selection() -> void:
	if tutorial_blocked or _sale_pending or _exporting:
		_refresh()
		return
	cancel_gesture()
	canvas.set_multiple_selection(not canvas.multiple_selection)
	_set_status("도형을 하나씩 누르거나 빈 곳에서 끌어 여러 도형을 골라요." if canvas.multiple_selection else "선택한 도형을 끌어 움직여요.")

func _change_shape_group(make_group: bool) -> void:
	if tutorial_blocked or _sale_pending or _exporting: return
	cancel_gesture()
	var changed: bool = document.group_selected() if make_group else document.ungroup_selected()
	if not changed:
		_set_status("묶을 도형을 두 개 이상 골라 주세요." if make_group else "풀고 싶은 묶음을 골라 주세요.")
		return
	canvas.set_multiple_selection(false)
	canvas.grab_focus()
	_set_status("도형을 묶었어요. 끌어서 함께 움직여 보세요." if make_group else "묶음을 풀었어요. 도형을 하나씩 골라 움직일 수 있어요.")

func _show_shape_context_menu(canvas_position: Vector2) -> void:
	if tutorial_blocked or not is_visible_in_tree() or _exporting: return
	if (_gallery != null and _gallery.visible) or (_color_dialog != null and _color_dialog.visible) or (_sale_dialog != null and _sale_dialog.visible) or _color_picker.get_popup().visible: return
	cancel_gesture()
	var point: Vector2 = canvas.screen_to_artwork(canvas_position)
	var selected_ids: Array[int] = document.get_selected_ids()
	# Keep the selection when any of its shapes contains the click. This also
	# preserves a selected lower layer where another shape covers it.
	var clicked_selection: bool = false
	for part: Dictionary in document.shapes:
		if selected_ids.has(int(part.id)) and QuadrilateralMath.contains_point(part.vertices, point - Vector2(part.position)):
			clicked_selection = true
			break
	if not clicked_selection:
		var hit_id: int = canvas._shape_at(point)
		if hit_id >= 0: document.select_shape(hit_id)
	var selected: Dictionary = document.get_selected()
	if selected.is_empty(): return
	selected_ids = document.get_selected_ids()
	if canvas.drawing_tool: canvas.select_tool()
	canvas.grab_focus()
	_context_shape_id = document.selected_id
	var layer: int = document._shape_index(_context_shape_id)
	_shape_context_menu.clear()
	var heading: String = "%s · 레이어 %d / %d" % [QuadrilateralMath.kind_name(str(selected.kind)), layer + 1, document.shapes.size()]
	if selected_ids.size() > 1: heading = "도형 %d개 선택" % selected_ids.size()
	_shape_context_menu.add_item(heading, 100)
	_shape_context_menu.set_item_disabled(0, true)
	_shape_context_menu.add_separator("", 100 + _shape_context_menu.item_count)
	for action: int in SHAPE_ACTION_LABELS:
		_shape_context_menu.add_item(str(SHAPE_ACTION_LABELS[action]), action)
		if action in [7, 5]: _shape_context_menu.add_separator("", 100 + _shape_context_menu.item_count)
	_shape_context_menu.set_item_disabled(_shape_context_menu.get_item_index(6), not document.can_shift_selection_layer(-1))
	_shape_context_menu.set_item_disabled(_shape_context_menu.get_item_index(7), not document.can_shift_selection_layer(1))
	if selected_ids.size() > 1:
		_shape_context_menu.add_separator("", 100 + _shape_context_menu.item_count)
		_shape_context_menu.add_item("묶기", GROUP_ACTION)
		_shape_context_menu.add_item("묶음 풀기", UNGROUP_ACTION)
		_shape_context_menu.set_item_disabled(_shape_context_menu.get_item_index(GROUP_ACTION), not document.can_group_selection())
		_shape_context_menu.set_item_disabled(_shape_context_menu.get_item_index(UNGROUP_ACTION), not document.can_ungroup_selection())
	var popup_position: Vector2 = canvas.get_global_transform_with_canvas() * canvas_position
	var popup_bounds: Rect2 = get_viewport().get_visible_rect()
	if not _shape_context_menu.is_embedded():
		popup_position = canvas.get_screen_transform() * canvas_position
		popup_bounds = Rect2(Vector2(get_window().position), Vector2(get_window().size))
	_shape_context_menu.popup(Rect2i(Vector2i(popup_position), Vector2i.ZERO))
	var maximum: Vector2 = (popup_bounds.end - Vector2(_shape_context_menu.size)).max(popup_bounds.position)
	_shape_context_menu.position = Vector2i(popup_position.clamp(popup_bounds.position, maximum))
	interaction_context_changed.emit()

func _shape_context_action(id: int) -> void:
	if tutorial_blocked or not is_visible_in_tree(): return
	if not SHAPE_ACTION_LABELS.has(id) and id not in [GROUP_ACTION, UNGROUP_ACTION]: return
	if _context_shape_id < 0 or document.selected_id != _context_shape_id or document.get_selected().is_empty(): return
	var index: int = _shape_context_menu.get_item_index(id)
	if index < 0 or _shape_context_menu.is_item_disabled(index): return
	if id in [GROUP_ACTION, UNGROUP_ACTION]:
		_change_shape_group(id == GROUP_ACTION)
		return
	_more_edit_action(id)
	if id == 6: _set_status("선택한 도형을 한 단계 뒤로 보냈어요. Ctrl+Z로 되돌릴 수 있어요.")
	elif id == 7: _set_status("선택한 도형을 한 단계 앞으로 보냈어요. Ctrl+Z로 되돌릴 수 있어요.")

func _clear_context_target() -> void:
	if not _shape_context_menu.visible: _context_shape_id = -1

func _add_edit_button(parent: Node, text: String, callback: Callable) -> void:
	var button: Button = _button(text, func():
		cancel_gesture()
		callback.call())
	_selection_buttons.append(button)
	parent.add_child(button)

func _check(text: String, enabled: bool) -> CheckButton:
	var control: CheckButton = CheckButton.new()
	Buttons.apply(control, false, 16)
	control.text = text
	control.button_pressed = enabled
	control.custom_minimum_size.y = 44
	control.add_theme_font_override("font", QuadTheme.FONT)
	return control

func _make_swatch(color: Color) -> Button:
	var swatch: Button = _button("", func(): _choose_color(color))
	swatch.custom_minimum_size = Vector2(44, 44)
	swatch.tooltip_text = "#" + color.to_html(false)
	swatch.set_meta("paint_color", color)
	swatch.accessibility_name = "물감 " + swatch.tooltip_text
	var sample: ColorRect = ColorRect.new()
	sample.name = "PaintSample"
	sample.color = color
	sample.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.add_child(sample)
	sample.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sample.offset_left = 7.0
	sample.offset_top = 7.0
	sample.offset_right = -7.0
	sample.offset_bottom = -7.0
	var marker: Label = QuadTheme.label("●", 15, Color.WHITE if color.srgb_to_linear().get_luminance() < 0.18 else Color("101b25"))
	marker.name = "Selected"
	marker.visible = canvas.paint_color.is_equal_approx(color)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sample.add_child(marker)
	marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_swatches.append(swatch)
	return swatch

func _refresh_swatches() -> void:
	for swatch: Button in _swatches:
		var color: Color = swatch.get_meta("paint_color")
		var marker: Label = swatch.get_node("PaintSample/Selected")
		marker.visible = canvas.paint_color.is_equal_approx(color)

func _open_colors() -> void:
	cancel_gesture()
	if _color_dialog == null:
		_color_dialog = AcceptDialog.new()
		_color_dialog.title = "56색 팔레트"
		_color_dialog.get_ok_button().text = "닫기"
		_color_dialog.add_theme_stylebox_override("panel", GameArt.panel(0, 16))
		Buttons.apply(_color_dialog.get_ok_button())
		_color_dialog.get_ok_button().custom_minimum_size.y = 44
		add_child(_color_dialog)
		_color_dialog.visibility_changed.connect(func(): interaction_context_changed.emit())
		# A scroll viewport keeps wrapped text's initial minimum height from
		# enlarging the Window before its containers have their first layout.
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 120)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_color_dialog.add_child(scroll)
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 12)
		scroll.add_child(column)
		column.add_child(QuadTheme.paragraph("고른 색은 선택한 도형에도 적용돼요. 원하는 색이 없으면 직접 색 고르기를 사용해요.", 15, QuadTheme.INK))
		var grid: HFlowContainer = HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		column.add_child(grid)
		for color: Color in PALETTE:
			grid.add_child(_make_swatch(color))
	_refresh_swatches()
	_color_dialog.popup_centered_clamped(Vector2i(470, 530), 0.9)

func _choose_mode(mode: String) -> void:
	if not is_personal_drawing: return
	cancel_gesture()
	mode_selected.emit(mode)
	if mode == "masterpiece" and document.masterpiece_id.is_empty():
		_open_gallery(true)
		return
	document.set_mode(mode)
	_set_status("밑그림 위에 여러 사각형을 겹쳐 명화를 완성해 보세요." if mode == "masterpiece" else "자유 그림 모드예요. 배경과 도형으로 나만의 작품을 만들어요.")

func _open_gallery(masterpieces: bool) -> void:
	if masterpieces and not is_personal_drawing: return
	if is_instance_valid(_commission_dialog) and _commission_dialog.visible: return
	cancel_gesture()
	if _gallery != null:
		remove_child(_gallery)
		_gallery.queue_free()
	_gallery = AcceptDialog.new()
	_gallery.name = "DrawingGallery"
	_gallery.title = "명화 채우기 · 밑그림 10종" if masterpieces else "그림 배경 · 30가지 장면"
	_gallery.get_ok_button().text = "닫기"
	_gallery.min_size = Vector2i(240, 190)
	_gallery.add_theme_stylebox_override("panel", GameArt.panel(0, 16))
	Buttons.apply(_gallery.get_ok_button())
	_gallery.get_ok_button().custom_minimum_size.y = 44
	add_child(_gallery)
	_gallery.visibility_changed.connect(func(): interaction_context_changed.emit())
	# Scroll the entire choice list so both its first wrapped description and
	# all rows can fit in a short window without pushing its close button offscreen.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_gallery.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	column.add_child(QuadTheme.paragraph("마음에 드는 명화를 골라요. 연한 밑그림 위를 사각형으로 자유롭게 채울 수 있어요." if masterpieces else "배경을 골라 나만의 그림을 꾸며요. 그린 도형은 그대로 이어서 사용할 수 있어요.", 15, QuadTheme.INK))
	if not masterpieces:
		column.add_child(_button("빈 종이로 그리기", func(): _choose_scene("paper", false)))
	var grid: HFlowContainer = HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	var entries: Array[Dictionary] = Catalog.masterpieces() if masterpieces else Catalog.backgrounds()
	for entry: Dictionary in entries:
		var card: VBoxContainer = QuadTheme.card(grid, Color.WHITE, 10)
		var panel: Control = card.get_parent() as Control
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var path: String = str(entry.get("reference_path", entry.path)) if masterpieces else str(entry.path)
		var preview: TextureRect = GameArt.view(load(path) as Texture2D, Vector2(205, 124))
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		card.add_child(preview)
		var id: String = str(entry.id)
		var chosen: bool = document.masterpiece_id == id if masterpieces else document.background_id == id
		var button: Button = _button(("● " if chosen else "") + str(entry.name), func(): _choose_scene(id, masterpieces))
		button.tooltip_text = "%s · %s\n%s" % [entry.artist, entry.year, entry.description] if masterpieces else str(entry.name)
		card.add_child(button)
		if masterpieces:
			card.add_child(QuadTheme.label("%s · %s" % [entry.artist, entry.year], 12, QuadTheme.INK))
	_gallery.popup_centered_clamped(Vector2i(850, 700), 0.92)

func _choose_scene(id: String, masterpiece: bool) -> void:
	if masterpiece and not is_personal_drawing: return
	cancel_gesture()
	if masterpiece:
		if not document.set_masterpiece(id):
			return
		_set_status("명화 채우기 · %s · 여러 가지 사각형으로 밑그림을 채워 보세요." % Catalog.masterpiece(id).name)
	else:
		if not document.set_background(id):
			return
		_set_status("배경을 골랐어요. 저장하거나 되돌릴 수 있어요.")
	if _gallery != null:
		_gallery.hide()

func _choose_color(color: Color) -> void:
	cancel_gesture()
	canvas.paint_color = color
	_color_picker.color = color
	document.set_color(color)
	canvas.queue_redraw()
	_refresh_swatches()

func _refresh() -> void:
	if canvas == null:
		return
	for kind: String in _shape_buttons:
		var button: Button = _shape_buttons[kind]
		var active: bool = canvas.drawing_tool and canvas.selected_kind == kind
		button.set_pressed_no_signal(active)
		Buttons.apply(button, active)
	var select_active: bool = not canvas.drawing_tool and not canvas.multiple_selection
	_select_button.set_pressed_no_signal(select_active)
	Buttons.apply(_select_button, select_active, TOOLBAR_FONT_SIZE)
	_multiple_selection_button.set_pressed_no_signal(canvas.multiple_selection)
	Buttons.apply(_multiple_selection_button, canvas.multiple_selection, TOOLBAR_FONT_SIZE)
	_group_button.disabled = not document.can_group_selection()
	_ungroup_button.disabled = not document.can_ungroup_selection()
	_undo.disabled = not document.can_undo()
	_redo.disabled = not document.can_redo()
	var selected: Dictionary = document.get_selected()
	var hint_kind: String = canvas.selected_kind if selected.is_empty() else str(selected.kind)
	_shape_hint.text = str(SHAPE_HELP[hint_kind])
	_mode_free.set_pressed_no_signal(document.drawing_mode == "free")
	_mode_masterpiece.set_pressed_no_signal(document.drawing_mode == "masterpiece")
	Buttons.apply(_mode_free, document.drawing_mode == "free", TOOLBAR_FONT_SIZE)
	Buttons.apply(_mode_masterpiece, document.drawing_mode == "masterpiece", TOOLBAR_FONT_SIZE)
	_drawing_title.text = "나만의 그림" if is_personal_drawing else "사각형 그림 의뢰"
	_drawing_tagline.text = "변과 각을 살피며 나만의 작품을 만들어요" if is_personal_drawing else "의뢰인의 부탁에 맞는 작품을 만들어요"
	_mode_free.visible = is_personal_drawing
	_mode_masterpiece.visible = is_personal_drawing
	_masterpiece_button.visible = is_personal_drawing
	_masterpiece_tools.visible = is_personal_drawing and document.drawing_mode == "masterpiece"
	var backdrop: Dictionary = Catalog.background(document.background_id)
	_background_button.text = "배경 고르기"
	_background_button.tooltip_text = "현재 배경: " + str(backdrop.get("name", "빈 종이"))
	_shape_picker.select(SHAPE_ORDER.find(canvas.selected_kind))
	_trapezoid_variant_picker.visible = canvas.selected_kind == "trapezoid"
	_shape_tools.visible = not _palette_scroll.visible or _trapezoid_variant_picker.visible
	_trapezoid_variant_picker.select(QuadrilateralMath.TRAPEZOID_VARIANTS.find(canvas.selected_trapezoid_variant))
	var masterpiece: Dictionary = Catalog.masterpiece(document.masterpiece_id)
	_masterpiece_button.text = "명화 10종 고르기"
	if is_personal_drawing and document.drawing_mode == "masterpiece" and not masterpiece.is_empty():
		_guide_label.text = "%s\n%s · %s\n%s" % [masterpiece.name, masterpiece.artist, masterpiece.year, masterpiece.description]
	else:
		_guide_label.text = "도시, 바다, 우주, 산, 집 등 30가지 배경으로 장면을 꾸며요."
	for button: Button in _selection_buttons:
		button.disabled = selected.is_empty()
	var selection_count: int = document.get_selected_ids().size()
	_selection.text = "도형 %d / %d개  ·  " % [document.shapes.size(), Model.MAX_SHAPES]
	if canvas.multiple_selection or selection_count > 1:
		_selection.text += "%d개 선택" % selection_count
		if document.can_ungroup_selection(): _selection.text += " · 묶음 포함"
	elif selected.is_empty() and canvas.drawing_tool and canvas.selected_kind == "freeform":
		_selection.text += str(SHAPE_HELP["freeform"])
	elif selected.is_empty():
		_selection.text += "도형을 고른 뒤 종이에 그리거나, 선택·이동으로 그림을 골라요."
	elif selected.kind == "freeform":
		_selection.text += "자유형 사각형 · 청록색 꼭짓점을 끌어 모양을 바꿔요."
	else:
		_selection.text += "%s · 길이 단위: cm · 손잡이로 크기·방향 조절" % QuadrilateralMath.kind_name(str(selected.kind))

func _document_changed() -> void:
	if document.shapes.is_empty():
		_stop_drawing_work()
	_hide_shape_context_menu()
	_refresh()
	if is_instance_valid(_sale_dialog) and _sale_dialog.visible: _refresh_sale_dialog()
	if not testing and not _restoring:
		_autosave.start()
	drawing_document_changed.emit()

func _begin_drawing_work(now: int) -> void:
	if _restoring or is_personal_drawing or tutorial_blocked or not is_visible_in_tree() or economy == null or economy.art_commission_id.is_empty():
		return
	_record_drawing_work(now)
	if document.work_msec < Model.REQUIRED_WORK_MSEC:
		_drawing_work_sample = now
		_drawing_work_until = now + DRAWING_IDLE_MSEC
		set_process(true)

func _process(_delta: float) -> void:
	_record_drawing_work(Time.get_ticks_msec())

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_stop_drawing_work()

func _record_drawing_work(now: int) -> void:
	if _drawing_work_until == 0:
		return
	if _restoring or is_personal_drawing or tutorial_blocked or not is_visible_in_tree() or _exporting or _sale_pending \
		or economy == null or economy.art_commission_id.is_empty() \
		or (is_instance_valid(_commission_dialog) and _commission_dialog.visible) \
		or (is_instance_valid(_sale_dialog) and _sale_dialog.visible) \
		or (is_instance_valid(_gallery) and _gallery.visible) \
		or (is_instance_valid(_color_dialog) and _color_dialog.visible):
		_stop_drawing_work()
		return
	var elapsed: int = maxi(0, mini(now, _drawing_work_until) - _drawing_work_sample)
	var previous_work: int = document.work_msec
	document.work_msec = mini(previous_work + elapsed, Model.REQUIRED_WORK_MSEC)
	_drawing_work_sample = now
	if not testing and _autosave.is_stopped() and floori(float(document.work_msec) / 5000.0) > floori(float(previous_work) / 5000.0):
		_autosave.start()
	if now >= _drawing_work_until or document.work_msec >= Model.REQUIRED_WORK_MSEC:
		_stop_drawing_work()

func _stop_drawing_work() -> void:
	_drawing_work_until = 0
	set_process(false)

func _set_status(message: String) -> void:
	_status.text = message

func configure_economy(value: ConstructionState) -> void:
	if economy != null and economy.changed.is_connected(_economy_changed):
		economy.changed.disconnect(_economy_changed)
	economy = value
	if economy != null: economy.changed.connect(_economy_changed)
	_economy_changed()

func _economy_changed() -> void:
	_sync_work_commission()
	_refresh_sale_button()
	if is_instance_valid(_sale_dialog) and _sale_dialog.visible: _refresh_sale_dialog()

func _sync_work_commission() -> void:
	if economy == null or _work_commission_revision == economy.art_commission_revision: return
	_work_commission_revision = economy.art_commission_revision
	_stop_drawing_work()
	_commission_document.work_msec = 0
	# Old snapshots can hold elapsed work for the previous commission.
	_commission_document.command_manager.clear()

func _refresh_sale_button() -> void:
	if not is_instance_valid(_sale_button): return
	var commission: Dictionary = _active_commission()
	var active: bool = not commission.is_empty()
	_submit_drawing_button.disabled = _sale_pending
	_sale_button.visible = not is_personal_drawing
	_sale_button.disabled = economy == null or _sale_pending
	_sale_button.text = "완성작 제출" if active else "그림 의뢰 받기"
	_sale_button.tooltip_text = "제출 조건과 의뢰인의 만족도를 확인해요." if active else "그림을 부탁한 의뢰인을 골라요."
	_commission_brief.visible = active
	_commission_brief.disabled = _sale_pending
	_commission_summary.visible = active
	_commission_summary.text = "진행 중 · %s" % str(commission.title) if active else ""
	_commission_summary.tooltip_text = _commission_summary.text
	_refresh_upload_status()

func _active_commission() -> Dictionary:
	return {} if economy == null or is_personal_drawing else Commissions.get_commission(economy.art_commission_id)

func _open_commission_action() -> void:
	if _active_commission().is_empty():
		_open_commissions()
	else:
		_open_sale()

func open_exhibition() -> void:
	if not _can_open_submission_dialog(true): return
	if document.shapes.is_empty():
		_set_status("도화지에 사각형을 그린 뒤 ‘내 그림 등록’을 눌러 주세요.")
		return
	_open_submission_form(true)

func _can_open_submission_dialog(exhibit: bool = false) -> bool:
	return (exhibit or (economy != null and not is_personal_drawing)) and not _sale_pending and not tutorial_blocked and not _exporting and is_visible_in_tree() \
		and not (is_instance_valid(_sale_dialog) and _sale_dialog.visible) \
		and not (is_instance_valid(_commission_player_reply) and _commission_dialog.visible) \
		and not (is_instance_valid(_gallery) and _gallery.visible) \
		and not (is_instance_valid(_color_dialog) and _color_dialog.visible) and not _color_picker.get_popup().visible

func _open_commissions() -> void:
	if not _can_open_submission_dialog(): return
	_record_drawing_work(Time.get_ticks_msec())
	_stop_drawing_work()
	cancel_gesture()
	var commission: Dictionary = _active_commission()
	if commission.is_empty():
		_show_commissions()
	else:
		_show_commission_brief(commission)

func _prepare_commission_dialog(title: String) -> void:
	if not is_instance_valid(_commission_dialog):
		_commission_dialog = AcceptDialog.new()
		_commission_dialog.name = "ArtCommissionDialog"
		_commission_dialog.exclusive = true
		_commission_dialog.get_label().hide()
		_commission_dialog.add_theme_stylebox_override("panel", GameArt.panel(0, 16))
		var close: Button = _commission_dialog.get_ok_button()
		close.text = "닫기"
		close.custom_minimum_size.y = 48
		Buttons.apply(close)
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(340, 210)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		_commission_dialog.add_child(scroll)
		_commission_body = VBoxContainer.new()
		_commission_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_commission_body.add_theme_constant_override("separation", 10)
		scroll.add_child(_commission_body)
		_commission_dialog.confirmed.connect(_reply_to_commission_client)
		_commission_dialog.visibility_changed.connect(func():
			interaction_context_changed.emit()
			if not _commission_dialog.visible and is_instance_valid(_commission_player_reply) and is_visible_in_tree():
				_sale_button.grab_focus())
		add_child(_commission_dialog)
	_commission_dialog.title = title
	_commission_dialog.dialog_hide_on_ok = true
	_commission_dialog.get_ok_button().text = "닫기"
	_commission_player_reply = null
	for child: Node in _commission_body.get_children():
		_commission_body.remove_child(child)
		child.queue_free()
	(_commission_body.get_parent() as ScrollContainer).scroll_vertical = 0

func _show_commissions() -> void:
	if is_instance_valid(_commission_dialog) and _commission_dialog.visible: _commission_dialog.hide()
	_prepare_commission_dialog("그림 의뢰 고르기")
	var active: Dictionary = _active_commission()
	var has_active: bool = not active.is_empty()
	var detail: String = "다른 의뢰를 받으면 그린 그림은 이어서 그릴 수 있어요. 작업 시간은 다시 시작해요." if has_active else "그리고 싶은 그림을 골라요. 도화지의 40% 이상을 채우고 5분 이상 작업하면 작품을 보여 줄 수 있어요."
	_commission_body.add_child(QuadTheme.paragraph(detail, 16, QuadTheme.INK))
	var first_action: Button
	for commission: Dictionary in Commissions.all():
		var id: String = str(commission.id)
		var card: VBoxContainer = QuadTheme.card(_commission_body, QuadTheme.PAPER, 10)
		card.add_theme_constant_override("separation", 6)
		var current: bool = has_active and str(active.id) == id
		var action_text: String = "진행 중" if current else ("이 의뢰로 바꾸기" if has_active else "이 의뢰 받기")
		var accept: Button = _button(action_text, _accept_commission.bind(id), not current)
		accept.name = "AcceptArtCommission_" + id
		accept.disabled = current
		_add_commission_brief(card, commission, accept)
		if first_action == null and not current: first_action = accept
	_commission_dialog.popup_centered_clamped(Vector2i(660, 650), 0.9)
	if first_action != null: first_action.grab_focus()

func _show_commission_brief(commission: Dictionary) -> void:
	_prepare_commission_dialog("진행 중인 그림 의뢰")
	var card: VBoxContainer = QuadTheme.card(_commission_body, QuadTheme.PAPER, 12)
	_add_commission_brief(card, commission)
	var others: Button = _button("다른 의뢰 보기", _show_commissions)
	others.name = "ShowOtherArtCommissions"
	others.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_commission_body.add_child(others)
	_commission_dialog.popup_centered_clamped(Vector2i(610, 410), 0.9)
	_commission_dialog.get_ok_button().grab_focus()

func _add_commission_brief(parent: VBoxContainer, commission: Dictionary, action: Button = null) -> void:
	var intro: HBoxContainer = HBoxContainer.new()
	intro.add_theme_constant_override("separation", 10)
	parent.add_child(intro)
	intro.add_child(_commission_portrait(commission, Vector2(68, 76) if action == null else Vector2(50, 60)))
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	intro.add_child(text)
	var heading: Label = QuadTheme.paragraph("%s · %s 님" % [commission.title, commission.client], 20, QuadTheme.TEAL)
	if action == null:
		text.add_child(heading)
	else:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		text.add_child(row)
		heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(heading)
		row.add_child(action)
	text.add_child(QuadTheme.paragraph(str(commission.brief), 16, QuadTheme.INK))
	var labels: PackedStringArray = []
	for requirement: Dictionary in Commissions.requirements(str(commission.id)):
		labels.append(str(requirement.label))
	parent.add_child(QuadTheme.paragraph(" · ".join(labels), 15, QuadTheme.MUTED))

func _commission_portrait(commission: Dictionary, dimensions: Vector2) -> PanelContainer:
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", GameArt.panel(1, 4))
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var atlas: Texture2D = StarfrontArt.cell("crew", int(commission.portrait), 4, 4, true)
	var portrait: TextureRect = GameArt.view(atlas, dimensions)
	portrait.name = "CommissionPortrait_" + str(commission.id)
	frame.add_child(portrait)
	return frame

func _show_commission_completion(receipt: Dictionary, score: int, reward: String) -> void:
	var commission: Dictionary = Commissions.get_commission(str(receipt.get("commission_id", "")))
	if commission.is_empty() or not is_visible_in_tree(): return
	_prepare_commission_dialog("그림을 받은 의뢰인")
	var card: VBoxContainer = QuadTheme.card(_commission_body, QuadTheme.PAPER, 12)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(_commission_portrait(commission, Vector2(84, 98)))
	var speech: VBoxContainer = VBoxContainer.new()
	speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech.add_theme_constant_override("separation", 8)
	row.add_child(speech)
	speech.add_child(QuadTheme.paragraph(str(commission.client), 21, QuadTheme.TEAL))
	var line: String = "부탁한 조건을 모두 채웠네요. 고마워요! " if score == 100 else "그림을 가져와 줘서 고마워요! "
	line += str(commission.reply)
	if score < 100:
		line += "\n" + _commission_feedback(commission, receipt)
	var message: Label = QuadTheme.paragraph(line, 18, QuadTheme.INK)
	message.name = "CommissionClientReply"
	speech.add_child(message)
	var summary: Label = QuadTheme.paragraph("%s · 만족도 %d%% · 받은 보상 %s" % [commission.title, score, reward], 16, QuadTheme.TEAL)
	summary.name = "CommissionRewardSummary"
	_commission_body.add_child(summary)
	_commission_player_reply = QuadTheme.paragraph("나 · 그림을 맡겨 주셔서 고마워요!", 16, QuadTheme.INK)
	_commission_player_reply.name = "CommissionPlayerReply"
	_commission_body.add_child(_commission_player_reply)
	_commission_player_reply.hide()
	_commission_dialog.dialog_hide_on_ok = false
	_commission_dialog.get_ok_button().text = "대답하기"
	_commission_dialog.popup_centered_clamped(Vector2i(610, 365), 0.9)
	_commission_dialog.get_ok_button().grab_focus()

func _commission_feedback(commission: Dictionary, receipt: Dictionary) -> String:
	if float(receipt.get("coverage", 0.0)) < float(commission.coverage_percent) / 100.0:
		return "다음에는 도화지를 조금 더 넓게 채워 봐요."
	if int(receipt.get("visible_shapes", 0)) < int(commission.visible_shapes):
		return "다음에는 사각형을 조금 더 많이 넣어 봐요."
	return "다음에는 서로 다른 종류의 사각형을 더 넣어 봐요."

func _reply_to_commission_client() -> void:
	if not is_instance_valid(_commission_player_reply) or _commission_player_reply.visible: return
	_commission_player_reply.show()
	_commission_dialog.get_ok_button().text = "작업실로 돌아가기"
	_commission_dialog.dialog_hide_on_ok = true

func _accept_commission(commission_id: String) -> void:
	if not _can_open_submission_dialog() or Commissions.get_commission(commission_id).is_empty(): return
	if commission_id == economy.art_commission_id: return
	art_commission_requested.emit(commission_id)

func show_art_commission_result(result: Dictionary) -> void:
	if is_instance_valid(_commission_dialog): _commission_dialog.hide()
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("error", "의뢰를 받지 못했어요. 다시 시도해 주세요.")))
		_sale_button.grab_focus()
		return
	canvas.grab_focus()
	if not testing and not save_drawing(false): return
	_set_status("의뢰를 받았어요. 부탁을 살피며 그림을 그려 보세요.")
func set_upload_status(message: String, pending_count: int = 0, post_url: String = "", busy: bool = false) -> void:
	_upload_message = message
	_upload_pending_count = maxi(0, pending_count)
	_upload_post_url = _safe_padlet_url(post_url)
	_upload_busy = busy
	_refresh_upload_status()

func _refresh_upload_status() -> void:
	if not is_instance_valid(_upload_row): return
	_upload_row.visible = not _upload_message.is_empty() or _upload_pending_count > 0 or _upload_busy
	_upload_status.text = _upload_message
	if _upload_status.text.is_empty() and _upload_pending_count > 0:
		_upload_status.text = "패들릿에 등록할 그림이 %d개 있어요." % _upload_pending_count
	_upload_retry.visible = _upload_pending_count > 0
	_upload_retry.disabled = _upload_busy or _sale_pending
	_upload_retry.text = "등록 중…" if _upload_busy else "등록 다시 시도"
	_upload_board.disabled = _sale_pending
	_upload_board.text = "그림 전시장 보기 ↗" if _upload_post_url == PADLET_BOARD_URL else "등록한 그림 보기 ↗"

func _request_art_upload_retry() -> void:
	if _upload_busy or _upload_pending_count < 1 or _sale_pending or tutorial_blocked or not is_visible_in_tree(): return
	_upload_busy = true
	_refresh_upload_status()
	art_upload_retry_requested.emit()

func _open_art_board() -> void:
	if _sale_pending or tutorial_blocked or not is_visible_in_tree(): return
	if _upload_post_url == PADLET_BOARD_URL: exhibition_board_requested.emit()
	else: OS.shell_open(_upload_post_url)

static func _safe_padlet_url(value: String) -> String:
	if not value.begins_with("https://padlet.com/") or value.contains("\\"): return PADLET_BOARD_URL
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if codepoint <= 32 or (codepoint >= 127 and codepoint <= 159): return PADLET_BOARD_URL
	return value

func _open_sale() -> void:
	if not _can_open_submission_dialog() or _active_commission().is_empty(): return
	_open_submission_form()

func _open_submission_form(exhibit: bool = false) -> void:
	if is_instance_valid(_commission_dialog) and _commission_dialog.visible: return
	_exhibition = exhibit
	_record_drawing_work(Time.get_ticks_msec())
	_stop_drawing_work()
	cancel_gesture()
	if _sale_dialog == null:
		_sale_dialog = ConfirmationDialog.new()
		_sale_dialog.name = "ArtSaleDialog"
		_sale_dialog.title = "그림 의뢰 · 완성작 제출"
		_sale_dialog.dialog_hide_on_ok = false
		_sale_dialog.exclusive = true
		_sale_dialog.add_theme_stylebox_override("panel", GameArt.panel(0, 16))
		_sale_dialog.get_label().hide()
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(300, 240)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		_sale_dialog.add_child(scroll)
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 10)
		scroll.add_child(column)
		_sale_price = QuadTheme.paragraph("", 22, QuadTheme.TEAL)
		_sale_price.name = "SoldArtPrice"
		column.add_child(_sale_price)
		_sale_details = QuadTheme.paragraph("", 17, QuadTheme.INK)
		column.add_child(_sale_details)
		_publication_note = QuadTheme.paragraph("", 16, QuadTheme.INK)
		column.add_child(_publication_note)
		column.add_child(QuadTheme.paragraph("작성자 이름 · 최대 40자", 18, QuadTheme.INK))
		_sale_author = LineEdit.new()
		_sale_author.name = "SoldArtAuthor"
		_sale_author.placeholder_text = "작가 이름이나 별명을 적어 주세요"
		_sale_author.max_length = SubmissionMetadata.MAX_AUTHOR_LENGTH
		_sale_author.text = sale_author_name
		_sale_author.custom_minimum_size.y = 46
		_sale_author.add_theme_font_override("font", QuadTheme.FONT)
		_sale_author.add_theme_font_size_override("font_size", 20)
		_sale_author.text_changed.connect(func(text: String):
			sale_author_name = text.strip_edges()
			_refresh_sale_dialog(false))
		_sale_author.text_submitted.connect(func(_text: String): _sale_title.grab_focus())
		column.add_child(_sale_author)
		column.add_child(QuadTheme.paragraph("그림 제목 · 최대 80자", 18, QuadTheme.INK))
		_sale_title = LineEdit.new()
		_sale_title.name = "SoldArtTitle"
		_sale_title.placeholder_text = "내 그림의 제목을 적어 주세요"
		_sale_title.max_length = SubmissionMetadata.MAX_TITLE_LENGTH
		_sale_title.custom_minimum_size.y = 46
		_sale_title.add_theme_font_override("font", QuadTheme.FONT)
		_sale_title.add_theme_font_size_override("font_size", 20)
		_sale_title.text_changed.connect(func(_text: String): _refresh_sale_dialog(false))
		_sale_title.text_submitted.connect(func(_text: String): _sale_description.grab_focus())
		column.add_child(_sale_title)
		_sale_description_count = QuadTheme.paragraph("그림 설명 · 최대 1000자", 18, QuadTheme.INK)
		column.add_child(_sale_description_count)
		_sale_description = TextEdit.new()
		_sale_description.name = "SoldArtDescription"
		_sale_description.placeholder_text = "무엇을 그렸나요? 어떤 사각형과 색을 썼는지 소개해 주세요."
		_sale_description.custom_minimum_size.y = 120
		_sale_description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		_sale_description.add_theme_font_override("font", QuadTheme.FONT)
		_sale_description.add_theme_font_size_override("font_size", 19)
		_sale_description.text_changed.connect(func(): _refresh_sale_dialog(false))
		column.add_child(_sale_description)
		_sale_validation = QuadTheme.paragraph("", 16, QuadTheme.TEAL)
		_sale_validation.name = "SoldArtMetadataFeedback"
		column.add_child(_sale_validation)
		column.add_child(QuadTheme.paragraph("제출하면 그림을 PNG로 저장한 뒤 패들릿에 등록해요. 등록이 안 되면 저장한 그림으로 다시 시도할 수 있어요.", 16, QuadTheme.INK))
		_sale_dialog.get_cancel_button().text = "계속 그리기"
		for button: Button in [_sale_dialog.get_ok_button(), _sale_dialog.get_cancel_button()]:
			Buttons.apply(button)
			button.custom_minimum_size.y = 48
		_sale_dialog.confirmed.connect(_confirm_sale)
		_sale_dialog.visibility_changed.connect(func():
			if not _sale_dialog.visible and not _sale_pending:
				_exhibition = false
			interaction_context_changed.emit())
		add_child(_sale_dialog)
	_sale_dialog.title = "내 그림 등록" if _exhibition else "그림 의뢰 · 완성작 제출"
	_publication_note.text = "작가 이름, 제목, 설명, 그림이 패들릿에 올라가요." if _exhibition else "이름, 제목, 설명, 받은 보상과 그림 이미지가 패들릿에 함께 올라가요."
	var key: String = ("personal_exhibit" if is_personal_drawing else "regular_exhibit") if _exhibition else "commission"
	if key != _form_key:
		if not _form_key.is_empty(): _metadata_drafts[_form_key] = [_sale_title.text, _sale_description.text]
		_form_key = key
		var draft: Array = _metadata_drafts.get(key, ["", ""])
		_sale_title.text = str(draft[0])
		_sale_description.text = str(draft[1])
	_refresh_sale_dialog()
	_sale_dialog.popup_centered_clamped(Vector2i(620, 660), 0.9)
	if _sale_author.text.strip_edges().is_empty():
		_sale_author.grab_focus()
	else:
		_sale_title.grab_focus()
		_sale_title.select_all()
	interaction_context_changed.emit()

func _refresh_sale_dialog(refresh_offer: bool = true) -> void:
	if not is_instance_valid(_sale_dialog): return
	var metadata_error: String = SubmissionMetadata.validation_error(_sale_author.text, _sale_title.text, _sale_description.text)
	_sale_description_count.text = "그림 설명 · %d / %d자" % [_sale_description.text.strip_edges().length(), SubmissionMetadata.MAX_DESCRIPTION_LENGTH]
	_sale_validation.text = metadata_error
	_sale_validation.visible = not metadata_error.is_empty()
	_sale_details.visible = not _exhibition
	if _exhibition:
		_sale_price.text = "나만의 그림" if is_personal_drawing else "내가 그린 사각형 그림"
		_sale_dialog.get_ok_button().text = "패들릿에 전시하기"
		_sale_dialog.get_ok_button().disabled = _sale_pending or document.shapes.is_empty() or not metadata_error.is_empty()
		return
	if economy == null: return
	if refresh_offer or _sale_offer.is_empty(): _sale_offer = economy.quote_art_commission(document)
	var commission: Dictionary = _active_commission()
	var lines: PackedStringArray = ["제출 조건"]
	for check: Dictionary in _sale_offer.get("checks", []):
		lines.append("%s %s · %s" % ["[완료]" if bool(check.met) else "[보완]", str(check.label), str(check.detail)])
	if not commission.is_empty():
		lines.append("\n%s · 의뢰인의 만족도 %d%%" % [commission.title, int(_sale_offer.get("score", 0))])
		for requirement: Dictionary in _sale_offer.get("requirements", []):
			lines.append("%s %s · %s" % ["[완료]" if bool(requirement.met) else "[보완]", str(requirement.label), str(requirement.detail)])
	var can_submit: bool = bool(_sale_offer.get("can_sell", false))
	_sale_price.text = "받을 보상 " + Money.format_won(int(_sale_offer.price)) if can_submit else "아직 제출할 수 없어요"
	var reason: String = str(_sale_offer.get("reason", ""))
	if not reason.is_empty(): lines.append("\n" + reason)
	_sale_details.text = "\n".join(lines)
	_sale_dialog.get_ok_button().text = "PNG 저장하고 제출" if can_submit else "제출 조건 채우기"
	_sale_dialog.get_ok_button().disabled = not can_submit or not metadata_error.is_empty() or _sale_pending

func _confirm_sale() -> void:
	if _sale_pending or tutorial_blocked or _exporting or not is_visible_in_tree(): return
	if not is_instance_valid(_sale_dialog) or not _sale_dialog.visible: return
	var metadata_error: String = SubmissionMetadata.validation_error(_sale_author.text, _sale_title.text, _sale_description.text)
	if not metadata_error.is_empty() or (_exhibition and document.shapes.is_empty()):
		_refresh_sale_dialog()
		return
	if not _exhibition:
		if economy == null or is_personal_drawing: return
		var current: Dictionary = economy.quote_art_commission(document)
		if not bool(current.get("can_sell", false)) or current != _sale_offer:
			_refresh_sale_dialog()
			return
	_sale_pending = true
	_refresh_sale_button()
	_sale_dialog.get_ok_button().disabled = true
	_sale_dialog.get_ok_button().text = "PNG 저장 중…"
	_sale_dialog.get_cancel_button().disabled = true
	_sale_author.editable = false
	_sale_title.editable = false
	_sale_description.editable = false
	_sale_dialog.dialog_close_on_escape = false
	_autosave.stop()
	if _sale_busy == null:
		_sale_busy = ColorRect.new()
		_sale_busy.color = Color(0.025, 0.07, 0.11, 0.9)
		_sale_busy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sale_busy.focus_mode = Control.FOCUS_ALL
		_sale_busy.gui_input.connect(func(event: InputEvent):
			if event is InputEventKey: _sale_busy.accept_event())
		add_child(_sale_busy)
		var notice: Label = QuadTheme.paragraph("그림을 PNG로 저장하고 있어요…", 22, Color.WHITE)
		notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sale_busy.add_child(notice)
	_sale_busy.show()
	# The exclusive dialog keeps edits and navigation blocked while rendering.
	sale_author_name = _sale_author.text.strip_edges()
	var submission: Dictionary = {
		"document": document.serialize(),
		"author": sale_author_name, "title": _sale_title.text.strip_edges(), "description": _sale_description.text.strip_edges(),
	}
	if _exhibition:
		drawing_exhibition_requested.emit(submission)
	else:
		submission["commission_revision"] = economy.art_commission_revision
		art_sale_requested.emit(submission)

func render_sale_png(data: Dictionary) -> PackedByteArray:
	var snapshot: Model = Model.new()
	if not snapshot.restore(data): return PackedByteArray()
	return await sale_png_renderer.call(get_tree(), snapshot)

func _release_submission_controls() -> void:
	_sale_pending = false
	_refresh_sale_button()
	if is_instance_valid(_sale_busy): _sale_busy.hide()
	if is_instance_valid(_sale_dialog):
		_sale_dialog.get_cancel_button().disabled = false
		_sale_author.editable = true
		_sale_title.editable = true
		_sale_description.editable = true
		_sale_dialog.dialog_close_on_escape = true

func show_exhibition_result(result: Dictionary) -> void:
	if not _exhibition or not _sale_pending: return
	_release_submission_controls()
	if not testing: _autosave.start()
	if bool(result.get("ok", false)):
		_sale_dialog.hide()
		_sale_title.text = ""
		_sale_description.text = ""
		_set_status(str(result.get("message", "전시할 그림을 저장했어요.")))
		_submit_drawing_button.grab_focus()
	else:
		_refresh_sale_dialog()
		_sale_validation.text = str(result.get("error", "전시할 그림을 저장하지 못했어요. 다시 시도해 주세요."))
		_sale_validation.show()
		_sale_dialog.get_ok_button().grab_focus()

func show_sale_result(result: Dictionary) -> void:
	if is_personal_drawing or _exhibition: return
	_release_submission_controls()
	if is_instance_valid(_sale_dialog):
		_sale_dialog.hide()
	if bool(result.get("ok", false)):
		if is_instance_valid(_sale_title): _sale_title.text = ""
		if is_instance_valid(_sale_description): _sale_description.text = ""
		if is_instance_valid(_sale_author): _sale_author.text = _sale_author.text.strip_edges()
		var receipt: Dictionary = result.get("receipt", {})
		var score: int = int(receipt.get("score", result.get("score", 0)))
		var reward: String = Money.format_won(int(result.get("price", 0)))
		var path: String = str(result.get("png_path", ""))
		if not path.is_empty():
			var blank: Dictionary = Model.new().serialize()
			if not testing and not _write_drawing_snapshot(blank):
				_set_status("의뢰를 마치고 %s을 받았어요. 도화지 저장이 어려워 그림은 그대로 두었어요." % reward)
				_autosave.start()
				_show_commission_completion(receipt, score, reward)
				return
			cancel_gesture()
			_restoring = true
			document.work_msec = 0
			document.restore(blank)
			_restoring = false
			_autosave.stop()
			canvas.select_kind("square")
			canvas.selected_trapezoid_variant = "symmetric"
			canvas.queue_redraw()
			var title: String = str(receipt.get("title", "내 그림"))
			if title.length() > 28: title = title.left(28) + "…"
			_set_status("‘%s’ 의뢰 완료 · 만족도 %d%% · 받은 보상 %s · PNG 저장 완료" % [title, score, reward])
			_sale_button.tooltip_text = "저장한 그림: " + ProjectSettings.globalize_path(path)
		else:
			_set_status("그림 의뢰 완료 · 만족도 %d%% · 받은 보상 %s" % [score, reward])
		_show_commission_completion(receipt, score, reward)
	else:
		_set_status(str(result.get("error", "그림 의뢰를 마치지 못했어요. 다시 시도해 주세요.")))
		if not testing: _autosave.start()

func cancel_gesture() -> void:
	if canvas != null:
		canvas.cancel_gesture()
	_hide_shape_context_menu()
	if is_instance_valid(_sale_dialog): _sale_dialog.hide()
	if is_instance_valid(_commission_dialog): _commission_dialog.hide()

func _hide_shape_context_menu() -> void:
	_context_shape_id = -1
	if is_instance_valid(_shape_context_menu): _shape_context_menu.hide()

func _undo_edit() -> void:
	cancel_gesture()
	document.undo()

func _redo_edit() -> void:
	cancel_gesture()
	document.redo()

func _clear_drawing() -> void:
	cancel_gesture()
	document.clear()
	_set_status("종이를 비웠어요. 되돌리기로 그림을 다시 가져올 수 있어요.")

func _go_home() -> void:
	if _sale_pending: return
	cancel_gesture()
	home_requested.emit()

func save_drawing(show_feedback: bool = true) -> bool:
	if not _write_drawing_snapshot(document.serialize()): return false
	if show_feedback:
		_set_status("그림을 저장했어요. 다음에 이어서 그릴 수 있어요.")
	return true

func _write_drawing_snapshot(snapshot: Dictionary) -> bool:
	var data: Dictionary = {"format": "quadrilateral-drawing", "version": 1, "document": snapshot}
	if not is_personal_drawing and _work_commission_revision > 0: data["commission_revision"] = _work_commission_revision
	var path: String = personal_save_path if is_personal_drawing else save_path
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		_set_status("그림을 저장하지 못했어요. 저장 위치를 확인해 주세요.")
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		_set_status("그림을 저장하지 못했어요. 다시 시도해 주세요.")
		return false
	var backup: String = path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(path, backup) != OK:
			_set_status("기존 그림을 보관하지 못했어요. 다시 시도해 주세요.")
			return false
	if DirAccess.rename_absolute(temporary, path) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, path)
		_set_status("그림을 저장하지 못했어요. 다시 시도해 주세요.")
		return false
	_autosave.stop()
	return true

func load_drawing(show_feedback: bool = true) -> bool:
	var path: String = personal_save_path if is_personal_drawing else save_path
	var saved: Dictionary = _read_drawing_snapshot(path, show_feedback)
	if saved.is_empty(): return false
	cancel_gesture()
	_stop_drawing_work()
	_restoring = true
	var restored: bool = document.restore(saved.document)
	if restored and not is_personal_drawing:
		_work_commission_revision = int(saved.get("commission_revision", 0))
		_sync_work_commission()
	_restoring = false
	if not restored:
		_set_status("저장한 그림을 읽을 수 없어요. 현재 그림은 그대로 두었어요.")
		return false
	if document.selected_id >= 0:
		canvas.select_tool()
	_autosave.stop()
	if show_feedback:
		_set_status("저장한 그림을 불러왔어요.")
	return true

func _read_drawing_snapshot(path: String, show_feedback: bool) -> Dictionary:
	if not FileAccess.file_exists(path):
		if show_feedback:
			_set_status("아직 저장한 그림이 없어요. 새 그림을 그려 보세요.")
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("저장한 그림을 열지 못했어요.")
		return {}
	if file.get_length() > 2000000:
		file.close()
		_set_status("저장한 그림을 읽을 수 없어요. 현재 그림은 그대로 두었어요.")
		return {}
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	var parsed: Variant = parser.data
	if parse_error != OK or not parsed is Dictionary or parsed.get("format") != "quadrilateral-drawing" or parsed.get("version") != 1 or not parsed.get("document") is Dictionary:
		_set_status("저장한 그림을 읽을 수 없어요. 현재 그림은 그대로 두었어요.")
		return {}
	var work_revision: Variant = parsed.get("commission_revision", 0)
	if not Model._integer(work_revision) or float(work_revision) < 0.0 or float(work_revision) > ConstructionState.MAX_ART_COMMISSION_REVISION:
		_set_status("저장한 그림을 읽을 수 없어요. 현재 그림은 그대로 두었어요.")
		return {}
	return parsed

func _export_png() -> void:
	if _exporting or _sale_pending:
		return
	if document.shapes.is_empty():
		_set_status("먼저 종이에 사각형을 그려 주세요.")
		return
	if DisplayServer.get_name() == "headless":
		return
	cancel_gesture()
	_exporting = true
	var bytes: PackedByteArray = await DrawingExport.export_png(get_tree(), document)
	_exporting = false
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, "my-quadrilateral-art.png", "image/png")
		_set_status("배경과 그림을 PNG로 내려받았어요. 밑그림과 조작 안내는 제외했어요.")
	else:
		var dialog: FileDialog = FileDialog.new()
		dialog.theme = Theme.new()
		Buttons.install(dialog.theme)
		dialog.theme.default_font = QuadTheme.FONT
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dialog.filters = PackedStringArray(["*.png ; PNG 이미지"])
		dialog.current_file = "my-quadrilateral-art.png"
		dialog.use_native_dialog = true
		dialog.file_selected.connect(func(path: String):
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(bytes)
				file.close()
				_set_status("배경과 그림을 PNG로 저장했어요. 밑그림과 조작 안내는 제외했어요.")
			else:
				_set_status("이미지 저장 위치를 확인해 주세요.")
			dialog.queue_free())
		dialog.canceled.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered(Vector2i(800, 600))

func _unhandled_key_input(event: InputEvent) -> void:
	if tutorial_blocked or _sale_pending: return
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if (_gallery != null and _gallery.visible) or (_color_dialog != null and _color_dialog.visible) or (_sale_dialog != null and _sale_dialog.visible) or (_commission_dialog != null and _commission_dialog.visible) or _color_picker.get_popup().visible or _shape_context_menu.visible:
		return
	var handled: bool = true
	if event.ctrl_pressed and event.keycode == KEY_S:
		save_drawing(true)
	elif event.ctrl_pressed and event.keycode == KEY_Z:
		if event.shift_pressed:
			_redo_edit()
		else:
			_undo_edit()
	elif event.ctrl_pressed and event.keycode == KEY_Y:
		_redo_edit()
	elif event.ctrl_pressed and event.keycode == KEY_D:
		cancel_gesture()
		document.duplicate_selected()
	elif event.ctrl_pressed and event.keycode == KEY_G:
		_change_shape_group(not event.shift_pressed)
	elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
		cancel_gesture()
		document.delete_selected()
	elif event.keycode == KEY_ESCAPE:
		canvas.select_tool()
		document.select_shape(-1)
	elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and not document.get_selected().is_empty():
		cancel_gesture()
		var direction: Vector2 = Vector2.ZERO
		match event.keycode:
			KEY_LEFT: direction = Vector2.LEFT
			KEY_RIGHT: direction = Vector2.RIGHT
			KEY_UP: direction = Vector2.UP
			KEY_DOWN: direction = Vector2.DOWN
		document.move_selection(direction * (10.0 if event.shift_pressed else 2.0))
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
