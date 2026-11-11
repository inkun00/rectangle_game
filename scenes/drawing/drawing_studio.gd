class_name DrawingStudio
extends Control

const Model = preload("res://scripts/core/drawing_document.gd")
const Canvas = preload("res://scenes/drawing/drawing_canvas.gd")
const Catalog = preload("res://scripts/core/drawing_catalog.gd")
const DrawingExport = preload("res://scripts/export/drawing_exporter.gd")
const Buttons = preload("res://scripts/ui/button_art.gd")
const Market = preload("res://scripts/economy/art_market.gd")
const Money = preload("res://scripts/construction/construction_catalog.gd")
const SAVE_PATH: String = "user://quadrilateral_drawing_v1.json"
const SHAPE_ORDER: Array[String] = ["square", "rectangle", "trapezoid", "parallelogram", "rhombus"]
const TRAPEZOID_VARIANT_LABELS: Array[String] = ["양옆이 기울어진 모양", "왼쪽 두 각이 직각", "오른쪽 두 각이 직각"]
const SHAPE_ACTION_LABELS: Dictionary = {6: "뒤로 보내기", 7: "앞으로 보내기", 2: "왼쪽 15° 회전", 3: "오른쪽 15° 회전", 4: "축소", 5: "확대", 0: "복제", 1: "삭제"}
const GROUP_ACTION: int = 12
const UNGROUP_ACTION: int = 13
const SHAPE_HELP: Dictionary = {
	"square": "네 변의 길이가 같고, 네 각이 직각이에요.",
	"rectangle": "네 각이 모두 직각이에요. 길쭉한 벽이나 창문을 그려 봐요.",
	"trapezoid": "평행한 변이 한 쌍 이상 있어요. 지붕이나 화분을 만들어 봐요.",
	"parallelogram": "마주 보는 두 쌍의 변이 평행해요. 기울어진 길을 그려 봐요.",
	"rhombus": "네 변의 길이가 모두 같아요. 반짝이는 보석을 만들어 봐요."
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
signal interaction_context_changed
signal guide_changed
signal art_sale_requested(document_data: Dictionary)

var testing: bool = false
var tutorial_blocked: bool = false
var save_path: String = SAVE_PATH
var document: Model = Model.new()
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
var _drawing_header: HBoxContainer
var _drawing_title: Label
var _drawing_tagline: Label
var _drawing_load: Button
var _shape_tools: HFlowContainer
var _tool_scroll: ScrollContainer
var _shape_context_menu: PopupMenu
var _context_shape_id: int = -1
var _main_colors: Array[Button] = []
var economy: ConstructionState
var _sale_button: Button
var _sale_dialog: ConfirmationDialog
var _sale_offer: Dictionary = {}
var _sale_pending: bool = false
var _sale_title: LineEdit
var _sale_details: Label
var _sale_busy: ColorRect
var sold_art_directory: String = ""
var sale_png_renderer: Callable = DrawingExport.export_png

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_autosave = Timer.new()
	_autosave.one_shot = true
	_autosave.wait_time = 0.7
	_autosave.timeout.connect(func(): save_drawing(false))
	add_child(_autosave)
	document.changed.connect(_document_changed)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			cancel_gesture()
			if is_instance_valid(_sale_dialog): _sale_dialog.hide())
	if not testing:
		load_drawing(false)
	_refresh()

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button: Button = QuadTheme.button(text, callback, primary)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("focus", Buttons.focus_style())
	return button

func _build_ui() -> void:
	var background: TextureRect = TextureRect.new()
	background.texture = StarfrontArt.scene(6)
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	_drawing_header = HBoxContainer.new()
	_drawing_header.add_theme_constant_override("separation", 10)
	column.add_child(_drawing_header)
	var home: Button = _button("← 메인", _go_home)
	home.name = "HomeButton"
	_drawing_header.add_child(home)
	var title: VBoxContainer = VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawing_header.add_child(title)
	_drawing_title = QuadTheme.label("사각형 그림 그리기", 25)
	title.add_child(_drawing_title)
	_drawing_tagline = QuadTheme.label("변과 각을 살피며 나만의 작품을 만들어요", 15, QuadTheme.MUTED)
	title.add_child(_drawing_tagline)
	_drawing_load = _button("불러오기", func(): load_drawing(true))
	_drawing_header.add_child(_drawing_load)
	_drawing_header.add_child(_button("튜토리얼", func(): tutorial_requested.emit()))
	_drawing_header.add_child(_button("저장", func(): save_drawing(true)))
	_drawing_header.add_child(_button("PNG 저장", _export_png, true))
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
	palette.add_child(QuadTheme.paragraph("종이에서 드래그해 그려요. 선택한 도형의 변·꼭짓점으로 크기를, 원형 손잡이로 방향을 바꿔요.", 15, QuadTheme.INK))
	_masterpiece_button = _button("명화 밑그림 고르기", func(): _open_gallery(true))
	_masterpiece_button.name = "MasterpieceGalleryButton"
	palette.add_child(_masterpiece_button)
	_guide_label = QuadTheme.paragraph("", 15, QuadTheme.INK)
	palette.add_child(_guide_label)
	var center: VBoxContainer = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	workspace.add_child(center)
	_shape_tools = HFlowContainer.new()
	_shape_tools.add_theme_constant_override("h_separation", 8)
	_shape_tools.add_theme_constant_override("v_separation", 6)
	center.add_child(_shape_tools)
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
	_tool_scroll = ScrollContainer.new()
	_tool_scroll.name = "DrawingToolbarScroll"
	_tool_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_tool_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tool_scroll.follow_focus = true
	center.add_child(_tool_scroll)
	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.name = "DrawingToolbar"
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_theme_constant_override("separation", 8)
	_tool_scroll.add_child(toolbar)
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
	Buttons.apply(_more_edits)
	_more_edits.focus_mode = Control.FOCUS_ALL
	_more_edits.custom_minimum_size.y = 44
	for caption: String in ["복제", "삭제", "왼쪽 15°", "오른쪽 15°", "축소", "확대", "뒤로 보내기", "앞으로 보내기", "모두 지우기", "불러오기", "밑그림 표시 전환", "밑그림 진하기 바꾸기"]:
		_more_edits.get_popup().add_item(caption)
	_more_edits.get_popup().id_pressed.connect(_more_edit_action)
	toolbar.add_child(_more_edits)
	var group_tools: HFlowContainer = HFlowContainer.new()
	group_tools.name = "DrawingGroupTools"
	group_tools.add_theme_constant_override("h_separation", 8)
	group_tools.add_theme_constant_override("v_separation", 6)
	center.add_child(group_tools)
	_multiple_selection_button = _button("여러 선택", _toggle_multiple_selection)
	_multiple_selection_button.name = "MultipleSelectionToggle"
	_multiple_selection_button.toggle_mode = true
	_multiple_selection_button.tooltip_text = "도형을 하나씩 누르거나 빈 곳에서 끌어 여러 도형을 골라요. Shift를 누르고 도형을 눌러도 돼요."
	group_tools.add_child(_multiple_selection_button)
	_group_button = _button("묶기", _change_shape_group.bind(true))
	_group_button.name = "GroupSelectedShapes"
	_group_button.tooltip_text = "선택한 도형을 묶어 함께 움직여요. (Ctrl+G)"
	group_tools.add_child(_group_button)
	_ungroup_button = _button("묶음 풀기", _change_shape_group.bind(false))
	_ungroup_button.name = "UngroupSelectedShapes"
	_ungroup_button.tooltip_text = "선택한 묶음을 풀어 도형을 따로 움직여요. (Ctrl+Shift+G)"
	group_tools.add_child(_ungroup_button)
	_masterpiece_tools = HBoxContainer.new()
	_masterpiece_tools.add_theme_constant_override("separation", 8)
	center.add_child(_masterpiece_tools)
	var guide_toggle: CheckButton = _check("밑그림 보기", true)
	_guide_toggle = guide_toggle
	guide_toggle.toggled.connect(func(enabled: bool):
		canvas.show_masterpiece = enabled
		canvas.queue_redraw())
	_masterpiece_tools.add_child(guide_toggle)
	_masterpiece_tools.add_child(QuadTheme.label("진하기", 15))
	var opacity: HSlider = HSlider.new()
	_guide_opacity = opacity
	opacity.custom_minimum_size = Vector2(120, 44)
	opacity.min_value = 0.15
	opacity.max_value = 1.0
	opacity.step = 0.05
	opacity.value = 0.65
	opacity.tooltip_text = "밑그림 진하기"
	opacity.value_changed.connect(func(value: float):
		canvas.masterpiece_opacity = value
		canvas.queue_redraw())
	_masterpiece_tools.add_child(opacity)
	_masterpiece_tools.add_child(_button("다른 명화", func(): _open_gallery(true)))
	canvas = Canvas.new()
	canvas.name = "DrawingCanvas"
	canvas.document = document
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
	var footer: HBoxContainer = HBoxContainer.new()
	footer.name = "DrawingSaleFooter"
	footer.add_theme_constant_override("separation", 14)
	_sale_button = _button("그림 판매", _open_sale, true)
	_sale_button.name = "SellDrawingButton"
	_sale_button.custom_minimum_size = Vector2(130, 48)
	_sale_button.tooltip_text = "판매 기준: 도형 6개·구별되는 2색·종이의 12% 이상, 사물의 구조 또는 정렬된 기하 구성"
	footer.add_child(_sale_button)
	_status = QuadTheme.paragraph("도형을 골라 종이에 그려요. 자동으로 저장돼요.", 14, QuadTheme.INK)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status)
	column.add_child(footer)
	_refresh_sale_button()
	resized.connect(_responsive_drawing)
	_responsive_drawing()

func _responsive_drawing() -> void:
	if not is_instance_valid(canvas): return
	var spacious: bool = size.x >= 1250 and size.y >= 760
	_palette_scroll.visible = spacious
	_shape_picker.visible = not spacious
	_shape_tools.visible = not spacious or canvas.selected_kind == "trapezoid"
	for button: Button in [_mode_free, _mode_masterpiece, _background_button, _select_button, _undo, _redo, _more_edits, _multiple_selection_button, _group_button, _ungroup_button]:
		button.add_theme_font_size_override("font_size", 16 if size.x < 1000 else 18)
	_drawing_tagline.visible = size.y >= 760
	_drawing_load.visible = size.x >= 1000
	_drawing_title.add_theme_font_size_override("font_size", 22 if size.x < 1000 else 25)
	for index: int in range(_main_colors.size()): _main_colors[index].visible = index < (9 if spacious else 6)
	_masterpiece_tools.visible = document.drawing_mode == "masterpiece" and size.y >= 760
	if _background_button != null: _background_button.text = "배경 고르기"

func _more_edit_action(id: int) -> void:
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
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		swatch.add_theme_stylebox_override(state, Buttons.swatch(color, state))
	_swatches.append(swatch)
	return swatch

func _refresh_swatches() -> void:
	for swatch: Button in _swatches:
		var color: Color = swatch.get_meta("paint_color")
		swatch.text = "●" if canvas.paint_color.is_equal_approx(color) else ""
		var ink: Color = Color.WHITE if color.get_luminance() < 0.4 else QuadTheme.INK
		for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			swatch.add_theme_color_override(state, ink)

func _open_colors() -> void:
	cancel_gesture()
	if _color_dialog == null:
		_color_dialog = AcceptDialog.new()
		_color_dialog.title = "56색 팔레트 · 고른 색이 선택 도형에도 적용돼요"
		_color_dialog.get_ok_button().text = "닫기"
		_color_dialog.add_theme_stylebox_override("panel", GameArt.panel(0, 16))
		Buttons.apply(_color_dialog.get_ok_button())
		_color_dialog.get_ok_button().custom_minimum_size.y = 44
		add_child(_color_dialog)
		_color_dialog.visibility_changed.connect(func(): interaction_context_changed.emit())
		# A scroll viewport keeps wrapped text's initial minimum height from
		# enlarging the Window before its containers have their first layout.
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(430, 430)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_color_dialog.add_child(scroll)
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 12)
		scroll.add_child(column)
		column.add_child(QuadTheme.paragraph("선명한 색 · 파스텔 · 깊은 색 · 무채색\n더 많은 색은 그림 화면의 직접 색 고르기를 사용해요.", 15, QuadTheme.INK))
		var grid: GridContainer = GridContainer.new()
		grid.columns = 8
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		column.add_child(grid)
		for color: Color in PALETTE:
			grid.add_child(_make_swatch(color))
	_refresh_swatches()
	_color_dialog.popup_centered_clamped(Vector2i(470, 530), 0.9)

func _choose_mode(mode: String) -> void:
	cancel_gesture()
	mode_selected.emit(mode)
	if mode == "masterpiece" and document.masterpiece_id.is_empty():
		_open_gallery(true)
		return
	document.set_mode(mode)
	_set_status("밑그림 위에 여러 사각형을 겹쳐 명화를 완성해 보세요." if mode == "masterpiece" else "자유 그림 모드예요. 배경과 도형으로 나만의 작품을 만들어요.")

func _open_gallery(masterpieces: bool) -> void:
	cancel_gesture()
	if _gallery != null:
		remove_child(_gallery)
		_gallery.queue_free()
	_gallery = AcceptDialog.new()
	_gallery.name = "DrawingGallery"
	_gallery.title = "명화 채우기 · 밑그림 10종" if masterpieces else "그림 배경 · 30가지 장면"
	_gallery.get_ok_button().text = "닫기"
	_gallery.min_size = Vector2i(500, 400)
	_gallery.add_theme_stylebox_override("panel", GameArt.panel(0, 16))
	Buttons.apply(_gallery.get_ok_button())
	_gallery.get_ok_button().custom_minimum_size.y = 44
	add_child(_gallery)
	_gallery.visibility_changed.connect(func(): interaction_context_changed.emit())
	# Scroll the entire choice list so both its first wrapped description and
	# all rows can fit in a short window without pushing its close button offscreen.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_gallery.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	column.add_child(QuadTheme.paragraph("마음에 드는 명화를 골라요. 연한 밑그림 위를 사각형으로 자유롭게 채울 수 있어요." if masterpieces else "배경을 골라 나만의 그림을 꾸며요. 그린 도형은 그대로 이어서 사용할 수 있어요.", 15, QuadTheme.INK))
	if not masterpieces:
		column.add_child(_button("빈 종이로 그리기", func(): _choose_scene("paper", false)))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
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
	cancel_gesture()
	if masterpiece:
		if not document.set_masterpiece(id):
			return
		_set_status("명화 채우기 · %s: 다섯 가지 사각형으로 밑그림을 채워 보세요." % Catalog.masterpiece(id).name)
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
	var toolbar_font_size: int = 16 if size.x < 1000 else 18
	_select_button.set_pressed_no_signal(select_active)
	Buttons.apply(_select_button, select_active, toolbar_font_size)
	_multiple_selection_button.set_pressed_no_signal(canvas.multiple_selection)
	Buttons.apply(_multiple_selection_button, canvas.multiple_selection, toolbar_font_size)
	_group_button.disabled = not document.can_group_selection()
	_ungroup_button.disabled = not document.can_ungroup_selection()
	_shape_hint.text = str(SHAPE_HELP[canvas.selected_kind])
	_undo.disabled = not document.can_undo()
	_redo.disabled = not document.can_redo()
	var selected: Dictionary = document.get_selected()
	_mode_free.set_pressed_no_signal(document.drawing_mode == "free")
	_mode_masterpiece.set_pressed_no_signal(document.drawing_mode == "masterpiece")
	Buttons.apply(_mode_free, document.drawing_mode == "free")
	Buttons.apply(_mode_masterpiece, document.drawing_mode == "masterpiece")
	_masterpiece_tools.visible = document.drawing_mode == "masterpiece" and size.y >= 760
	var backdrop: Dictionary = Catalog.background(document.background_id)
	_background_button.text = "배경 고르기"
	_background_button.tooltip_text = "현재 배경: " + str(backdrop.get("name", "빈 종이"))
	_shape_picker.select(SHAPE_ORDER.find(canvas.selected_kind))
	_trapezoid_variant_picker.visible = canvas.selected_kind == "trapezoid"
	_shape_tools.visible = not _palette_scroll.visible or _trapezoid_variant_picker.visible
	_trapezoid_variant_picker.select(QuadrilateralMath.TRAPEZOID_VARIANTS.find(canvas.selected_trapezoid_variant))
	var masterpiece: Dictionary = Catalog.masterpiece(document.masterpiece_id)
	_masterpiece_button.text = "명화 10종 고르기"
	if document.drawing_mode == "masterpiece" and not masterpiece.is_empty():
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
	elif selected.is_empty():
		_selection.text += "도형을 고른 뒤 종이에 그리거나, 선택·이동으로 그림을 골라요."
	else:
		_selection.text += "%s · 길이 단위: cm · 손잡이로 크기·방향 조절" % QuadrilateralMath.kind_name(str(selected.kind))

func _document_changed() -> void:
	_hide_shape_context_menu()
	_refresh()
	if is_instance_valid(_sale_dialog) and _sale_dialog.visible: _refresh_sale_dialog()
	if not testing and not _restoring:
		_autosave.start()

func _set_status(message: String) -> void:
	_status.text = message

func configure_economy(value: ConstructionState) -> void:
	if economy != null and economy.changed.is_connected(_economy_changed):
		economy.changed.disconnect(_economy_changed)
	economy = value
	if economy != null: economy.changed.connect(_economy_changed)
	_economy_changed()

func _economy_changed() -> void:
	_refresh_sale_button()
	if is_instance_valid(_sale_dialog) and _sale_dialog.visible: _refresh_sale_dialog()

func _refresh_sale_button() -> void:
	if not is_instance_valid(_sale_button): return
	_sale_button.disabled = economy == null or _sale_pending

func _open_sale() -> void:
	if economy == null or _sale_pending or tutorial_blocked or _exporting or not is_visible_in_tree(): return
	if (_gallery != null and _gallery.visible) or (_color_dialog != null and _color_dialog.visible) or _color_picker.get_popup().visible: return
	cancel_gesture()
	if _sale_dialog == null:
		_sale_dialog = ConfirmationDialog.new()
		_sale_dialog.name = "ArtSaleDialog"
		_sale_dialog.title = "그림 판매 · 마을 화랑"
		_sale_dialog.dialog_hide_on_ok = false
		_sale_dialog.exclusive = true
		_sale_dialog.add_theme_stylebox_override("panel", GameArt.panel(0, 16))
		_sale_dialog.get_label().hide()
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(480, 340)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		_sale_dialog.add_child(scroll)
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 10)
		scroll.add_child(column)
		column.add_child(QuadTheme.paragraph("그림 제목 · 최대 80자", 18, QuadTheme.INK))
		_sale_title = LineEdit.new()
		_sale_title.name = "SoldArtTitle"
		_sale_title.placeholder_text = "내 그림의 제목을 적어 주세요"
		_sale_title.max_length = Market.MAX_TITLE_LENGTH
		_sale_title.custom_minimum_size.y = 46
		_sale_title.add_theme_font_override("font", QuadTheme.FONT)
		_sale_title.add_theme_font_size_override("font_size", 20)
		_sale_title.text_changed.connect(func(_text: String): _refresh_sale_dialog(false))
		_sale_title.text_submitted.connect(func(_text: String): _confirm_sale())
		column.add_child(_sale_title)
		_sale_details = QuadTheme.paragraph("", 17, QuadTheme.INK)
		column.add_child(_sale_details)
		_sale_dialog.get_cancel_button().text = "계속 그리기"
		for button: Button in [_sale_dialog.get_ok_button(), _sale_dialog.get_cancel_button()]:
			Buttons.apply(button)
			button.custom_minimum_size.y = 48
		_sale_dialog.confirmed.connect(_confirm_sale)
		_sale_dialog.visibility_changed.connect(func(): interaction_context_changed.emit())
		add_child(_sale_dialog)
	if _sale_title.text.strip_edges().is_empty():
		_sale_title.text = "나의 작품 %d" % (economy.art_sales.size() + 1)
	_refresh_sale_dialog()
	_sale_dialog.popup_centered_clamped(Vector2i(580, 450), 0.9)
	_sale_title.grab_focus()
	_sale_title.select_all()
	interaction_context_changed.emit()

func _refresh_sale_dialog(refresh_offer: bool = true) -> void:
	if economy == null or not is_instance_valid(_sale_dialog): return
	if refresh_offer or _sale_offer.is_empty(): _sale_offer = Market.quote(document, economy.art_sales)
	var lines: PackedStringArray = PackedStringArray()
	for check: Dictionary in _sale_offer.get("checks", []):
		lines.append("%s %s · %s" % ["[완료]" if bool(check.met) else "[보완]", str(check.label), str(check.detail)])
	var details: String = "판매 기준\n" + "\n".join(lines)
	var offer_text: String = "판매 가격  " + Money.format_won(int(_sale_offer.price)) if bool(_sale_offer.can_sell) else "아직 판매할 수 없어요"
	var title_valid: bool = Market.valid_title(_sale_title.text)
	var reason: String = str(_sale_offer.reason) if title_valid else "그림 제목을 1~80자로 입력해 주세요."
	_sale_details.text = "%s\n\n%s\n\n%s\n\n구성 예: 집·나무·로봇·우주선 또는 크기와 구획이 있는 기하 구성\n\n통과하면 제목으로 PNG를 저장하고 새 그림을 시작해요.\n같거나 아주 비슷한 작품은 한 번만 판매해요." % [offer_text, details, reason]
	_sale_dialog.get_ok_button().text = "PNG 저장하고 판매" if bool(_sale_offer.can_sell) else "판매 준비 중"
	_sale_dialog.get_ok_button().disabled = not bool(_sale_offer.can_sell) or not title_valid or _sale_pending

func _confirm_sale() -> void:
	if economy == null or _sale_pending or tutorial_blocked or _exporting or not is_visible_in_tree(): return
	if not is_instance_valid(_sale_dialog) or not _sale_dialog.visible: return
	# Recheck at confirmation: the displayed offer can never authorize a stale sale.
	var current: Dictionary = Market.quote(document, economy.art_sales)
	if not bool(current.can_sell) or current != _sale_offer or not Market.valid_title(_sale_title.text):
		_refresh_sale_dialog()
		return
	_sale_pending = true
	_refresh_sale_button()
	_sale_dialog.get_ok_button().disabled = true
	_sale_dialog.get_ok_button().text = "PNG 저장 중…"
	_sale_dialog.get_cancel_button().disabled = true
	_sale_title.editable = false
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
	art_sale_requested.emit({"document": document.serialize(), "title": _sale_title.text.strip_edges()})

func render_sale_png(data: Dictionary) -> PackedByteArray:
	var snapshot: Model = Model.new()
	if not snapshot.restore(data): return PackedByteArray()
	return await sale_png_renderer.call(get_tree(), snapshot)

func show_sale_result(result: Dictionary) -> void:
	_sale_pending = false
	_refresh_sale_button()
	if is_instance_valid(_sale_busy): _sale_busy.hide()
	if is_instance_valid(_sale_dialog):
		_sale_dialog.get_cancel_button().disabled = false
		_sale_title.editable = true
		_sale_dialog.dialog_close_on_escape = true
		_sale_dialog.hide()
	if bool(result.get("ok", false)):
		var path: String = str(result.get("png_path", ""))
		if not path.is_empty():
			var blank: Dictionary = Model.new().serialize()
			if not testing and not _write_drawing_snapshot(blank):
				_set_status("판매와 PNG 저장은 완료했어요. 도화지 저장이 어려워 그림을 그대로 두었어요. PNG: " + path)
				_autosave.start()
				return
			cancel_gesture()
			_restoring = true
			document.restore(blank)
			_restoring = false
			_autosave.stop()
			canvas.select_kind("square")
			canvas.selected_trapezoid_variant = "symmetric"
			canvas.queue_redraw()
			_sale_title.text = ""
			var title: String = str(result.get("receipt", {}).get("title", "내 그림"))
			if title.length() > 28: title = title.left(28) + "…"
			_set_status("‘%s’을(를) %s에 판매했어요. PNG 저장 완료 · 새 그림을 시작해요." % [title, Money.format_won(int(result.get("price", 0)))])
			_sale_button.tooltip_text = "저장한 그림: " + ProjectSettings.globalize_path(path)
		else:
			_set_status("작품을 %s에 판매했어요!" % Money.format_won(int(result.get("price", 0))))
	else:
		_set_status(str(result.get("error", "판매를 마치지 못했어요. 그림을 그대로 두었어요.")))
		if not testing: _autosave.start()

func cancel_gesture() -> void:
	if canvas != null:
		canvas.cancel_gesture()
	_hide_shape_context_menu()
	if is_instance_valid(_sale_dialog): _sale_dialog.hide()

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
	var temporary: String = save_path + ".tmp"
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
	var backup: String = save_path + ".bak"
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(save_path, backup) != OK:
			_set_status("기존 그림을 보관하지 못했어요. 다시 시도해 주세요.")
			return false
	if DirAccess.rename_absolute(temporary, save_path) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, save_path)
		_set_status("그림을 저장하지 못했어요. 다시 시도해 주세요.")
		return false
	_autosave.stop()
	return true

func load_drawing(show_feedback: bool = true) -> bool:
	if not FileAccess.file_exists(save_path):
		if show_feedback:
			_set_status("아직 저장한 그림이 없어요. 새 그림을 그려 보세요.")
		return false
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_set_status("저장한 그림을 열지 못했어요.")
		return false
	if file.get_length() > 2000000:
		file.close()
		_set_status("저장한 그림을 읽을 수 없어요. 현재 그림은 그대로 두었어요.")
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or parsed.get("format") != "quadrilateral-drawing" or parsed.get("version") != 1 or not parsed.get("document") is Dictionary:
		_set_status("저장한 그림을 읽을 수 없어요. 현재 그림은 그대로 두었어요.")
		return false
	cancel_gesture()
	_restoring = true
	var restored: bool = document.restore(parsed.document)
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
	if (_gallery != null and _gallery.visible) or (_color_dialog != null and _color_dialog.visible) or (_sale_dialog != null and _sale_dialog.visible) or _color_picker.get_popup().visible or _shape_context_menu.visible:
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
