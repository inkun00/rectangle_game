class_name DrawingStudio
extends Control

const Model = preload("res://scripts/core/drawing_document.gd")
const Canvas = preload("res://scenes/drawing/drawing_canvas.gd")
const Catalog = preload("res://scripts/core/drawing_catalog.gd")
const DrawingExport = preload("res://scripts/export/drawing_exporter.gd")
const SAVE_PATH: String = "user://quadrilateral_drawing_v1.json"
const SHAPE_ORDER: Array[String] = ["square", "rectangle", "trapezoid", "parallelogram", "rhombus"]
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

var testing: bool = false
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
var _guide_label: Label
var _gallery: AcceptDialog
var _color_dialog: AcceptDialog
var _swatches: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_autosave = Timer.new()
	_autosave.one_shot = true
	_autosave.wait_time = 0.7
	_autosave.timeout.connect(func(): save_drawing(false))
	add_child(_autosave)
	document.changed.connect(_document_changed)
	if not testing:
		load_drawing(false)
	_refresh()

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button: Button = QuadTheme.button(text, callback, primary)
	button.focus_mode = Control.FOCUS_ALL
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = QuadTheme.TEAL
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)
	return button

func _build_ui() -> void:
	var background: TextureRect = TextureRect.new()
	background.texture = GameArt.panel_texture(0)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var home: Button = _button("← 메인", _go_home)
	home.name = "HomeButton"
	header.add_child(home)
	var title: VBoxContainer = VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	title.add_child(QuadTheme.label("사각형 그림 그리기", 26))
	title.add_child(QuadTheme.label("다섯 가지 도형으로 만드는 나만의 그림", 13, QuadTheme.MUTED))
	header.add_child(_button("불러오기", func(): load_drawing(true)))
	header.add_child(_button("저장", func(): save_drawing(true)))
	header.add_child(_button("PNG 저장", _export_png, true))
	var workspace: HBoxContainer = HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 16)
	column.add_child(workspace)
	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_scroll.custom_minimum_size.x = 224
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.add_child(left_scroll)
	var palette: VBoxContainer = QuadTheme.card(left_scroll, Color.WHITE, 14)
	palette.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette.add_child(QuadTheme.label("1. 도형 고르기", 18))
	for kind: String in SHAPE_ORDER:
		var button: Button = _button(QuadrilateralMath.kind_name(kind), func(): canvas.select_kind(kind))
		button.name = "Shape_" + kind
		button.icon = QuadTheme.icon(kind)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		palette.add_child(button)
		_shape_buttons[kind] = button
	_shape_hint = QuadTheme.paragraph("", 14, QuadTheme.INK)
	palette.add_child(_shape_hint)
	palette.add_child(HSeparator.new())
	palette.add_child(QuadTheme.label("2. 종이에 그리기", 18))
	palette.add_child(QuadTheme.paragraph("종이에서 드래그해 그려요.\n몸통: 옮기기\n변·꼭지점: 비율대로 확대·축소\n위쪽 원형 손잡이: 회전", 14, QuadTheme.INK))
	palette.add_child(_button("가운데에 도형 추가", func(): canvas.add_at_center()))
	palette.add_child(QuadTheme.paragraph("도형을 겹치면 집, 꽃, 자동차도 만들 수 있어요!", 13))
	palette.add_child(HSeparator.new())
	palette.add_child(QuadTheme.label("3. 배경과 밑그림", 18))
	_background_button = _button("배경 30종 고르기", func(): _open_gallery(false))
	_background_button.name = "BackgroundGalleryButton"
	palette.add_child(_background_button)
	_masterpiece_button = _button("명화 밑그림 10종", func(): _open_gallery(true))
	_masterpiece_button.name = "MasterpieceGalleryButton"
	palette.add_child(_masterpiece_button)
	_guide_label = QuadTheme.paragraph("배경을 고르고 나만의 장면을 꾸며요.", 13, QuadTheme.INK)
	palette.add_child(_guide_label)
	var center: VBoxContainer = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 10)
	workspace.add_child(center)
	var modes: HBoxContainer = HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	center.add_child(modes)
	_mode_free = _button("자유 그림", func(): _choose_mode("free"))
	_mode_free.name = "FreeDrawingMode"
	_mode_free.toggle_mode = true
	modes.add_child(_mode_free)
	_mode_masterpiece = _button("명화 채우기", func(): _choose_mode("masterpiece"))
	_mode_masterpiece.name = "MasterpieceMode"
	_mode_masterpiece.toggle_mode = true
	modes.add_child(_mode_masterpiece)
	var mode_help: Label = QuadTheme.paragraph("나만의 사각형으로 그리고, 겹치고, 채워요.", 14, QuadTheme.INK)
	mode_help.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	modes.add_child(mode_help)
	var toolbar: HFlowContainer = HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 6)
	toolbar.add_theme_constant_override("v_separation", 6)
	center.add_child(toolbar)
	_select_button = _button("선택·이동", func(): canvas.select_tool())
	_select_button.toggle_mode = true
	toolbar.add_child(_select_button)
	_undo = _button("되돌리기", _undo_edit)
	_redo = _button("다시", _redo_edit)
	toolbar.add_child(_undo)
	toolbar.add_child(_redo)
	_add_edit_button(toolbar, "복제", document.duplicate_selected)
	_add_edit_button(toolbar, "삭제", document.delete_selected)
	_add_edit_button(toolbar, "왼쪽 15°", func(): document.rotate_selected(-15))
	_add_edit_button(toolbar, "오른쪽 15°", func(): document.rotate_selected(15))
	_add_edit_button(toolbar, "축소", func(): document.scale_selected(0.9))
	_add_edit_button(toolbar, "확대", func(): document.scale_selected(1.1))
	_add_edit_button(toolbar, "뒤로", func(): document.shift_selected_layer(-1))
	_add_edit_button(toolbar, "앞으로", func(): document.shift_selected_layer(1))
	toolbar.add_child(_button("모두 지우기", _clear_drawing))
	_masterpiece_tools = HBoxContainer.new()
	_masterpiece_tools.add_theme_constant_override("separation", 8)
	center.add_child(_masterpiece_tools)
	var guide_toggle: CheckButton = _check("밑그림 보기", true)
	guide_toggle.toggled.connect(func(enabled: bool):
		canvas.show_masterpiece = enabled
		canvas.queue_redraw())
	_masterpiece_tools.add_child(guide_toggle)
	_masterpiece_tools.add_child(QuadTheme.label("밑그림 진하기", 13))
	var opacity: HSlider = HSlider.new()
	opacity.custom_minimum_size = Vector2(100, 44)
	opacity.min_value = 0.15
	opacity.max_value = 1.0
	opacity.step = 0.05
	opacity.value = 0.65
	opacity.tooltip_text = "밑그림을 연하게 또는 진하게 보여요."
	opacity.value_changed.connect(func(value: float):
		canvas.masterpiece_opacity = value
		canvas.queue_redraw())
	_masterpiece_tools.add_child(opacity)
	_masterpiece_tools.add_child(_button("다른 명화", func(): _open_gallery(true)))
	canvas = Canvas.new()
	canvas.name = "DrawingCanvas"
	canvas.document = document
	canvas.custom_minimum_size = Vector2(240, 200)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.hint_requested.connect(_set_status)
	canvas.tool_changed.connect(_refresh)
	center.add_child(canvas)
	var colors: HFlowContainer = HFlowContainer.new()
	colors.add_theme_constant_override("h_separation", 8)
	colors.add_theme_constant_override("v_separation", 6)
	center.add_child(colors)
	var color_label: Label = QuadTheme.label("색 고르기", 15)
	color_label.custom_minimum_size.y = 44
	colors.add_child(color_label)
	for index: int in [0, 2, 3, 6, 7, 9, 10, 12, 14, 48, 55]:
		colors.add_child(_make_swatch(PALETTE[index]))
	colors.add_child(_button("56색 팔레트", _open_colors))
	_color_picker = ColorPickerButton.new()
	_color_picker.custom_minimum_size = Vector2(52, 44)
	_color_picker.color = canvas.paint_color
	_color_picker.edit_alpha = false
	_color_picker.tooltip_text = "직접 색 고르기"
	_color_picker.color_changed.connect(_choose_color)
	colors.add_child(_color_picker)
	var grid: CheckButton = _check("점 격자", true)
	grid.toggled.connect(func(enabled: bool):
		canvas.show_grid = enabled
		canvas.queue_redraw())
	colors.add_child(grid)
	var snap: CheckButton = _check("자석 스냅", true)
	snap.name = "SnapToggle"
	snap.tooltip_text = "다른 도형의 꼭지점과 변 가까이에서 딱 붙어요."
	snap.toggled.connect(func(enabled: bool):
		canvas.snap_enabled = enabled
		canvas.queue_redraw())
	colors.add_child(snap)
	_selection = QuadTheme.paragraph("", 14, QuadTheme.INK)
	center.add_child(_selection)
	_status = QuadTheme.paragraph("도형을 골라 자유롭게 그려 보세요. 그림은 자동으로 저장돼요.", 13, QuadTheme.INK)
	column.add_child(_status)

func _add_edit_button(parent: Node, text: String, callback: Callable) -> void:
	var button: Button = _button(text, func():
		cancel_gesture()
		callback.call())
	_selection_buttons.append(button)
	parent.add_child(button)

func _check(text: String, enabled: bool) -> CheckButton:
	var control: CheckButton = CheckButton.new()
	control.text = text
	control.button_pressed = enabled
	control.custom_minimum_size.y = 44
	control.add_theme_font_override("font", QuadTheme.FONT)
	for state: String in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
		control.add_theme_color_override(state, QuadTheme.INK)
	return control

func _make_swatch(color: Color) -> Button:
	var swatch: Button = _button("", func(): _choose_color(color))
	swatch.custom_minimum_size = Vector2(44, 44)
	swatch.tooltip_text = "#" + color.to_html(false)
	swatch.set_meta("paint_color", color)
	for state: String in ["normal", "hover", "pressed"]:
		swatch.add_theme_stylebox_override(state, QuadTheme.style(color.lightened(0.12) if state == "hover" else color, 0, Color.TRANSPARENT, 0))
	_swatches.append(swatch)
	return swatch

func _refresh_swatches() -> void:
	for swatch: Button in _swatches:
		var color: Color = swatch.get_meta("paint_color")
		swatch.text = "✓" if canvas.paint_color.is_equal_approx(color) else ""
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
		_color_dialog.get_ok_button().add_theme_font_override("font", QuadTheme.FONT)
		for state: String in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			_color_dialog.get_ok_button().add_theme_color_override(state, QuadTheme.INK)
		_color_dialog.get_ok_button().add_theme_stylebox_override("normal", GameArt.panel(0, 12))
		_color_dialog.get_ok_button().add_theme_stylebox_override("hover", GameArt.panel(3, 12))
		_color_dialog.get_ok_button().add_theme_stylebox_override("pressed", GameArt.panel(3, 12))
		_color_dialog.get_ok_button().custom_minimum_size.y = 44
		add_child(_color_dialog)
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
	_gallery.get_ok_button().add_theme_font_override("font", QuadTheme.FONT)
	for state: String in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		_gallery.get_ok_button().add_theme_color_override(state, QuadTheme.INK)
	_gallery.get_ok_button().add_theme_stylebox_override("normal", GameArt.panel(0, 12))
	_gallery.get_ok_button().add_theme_stylebox_override("hover", GameArt.panel(3, 12))
	_gallery.get_ok_button().add_theme_stylebox_override("pressed", GameArt.panel(3, 12))
	_gallery.get_ok_button().custom_minimum_size.y = 44
	add_child(_gallery)
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
		var button: Button = _button(("✓ " if chosen else "") + str(entry.name), func(): _choose_scene(id, masterpieces))
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
		button.add_theme_stylebox_override("normal", GameArt.panel(3 if active else 0, 12))
	_select_button.set_pressed_no_signal(not canvas.drawing_tool)
	_select_button.add_theme_stylebox_override("normal", GameArt.panel(3 if not canvas.drawing_tool else 0, 12))
	_shape_hint.text = str(SHAPE_HELP[canvas.selected_kind])
	_undo.disabled = not document.can_undo()
	_redo.disabled = not document.can_redo()
	var selected: Dictionary = document.get_selected()
	_mode_free.set_pressed_no_signal(document.drawing_mode == "free")
	_mode_masterpiece.set_pressed_no_signal(document.drawing_mode == "masterpiece")
	_mode_free.add_theme_stylebox_override("normal", GameArt.panel(3 if document.drawing_mode == "free" else 0, 12))
	_mode_masterpiece.add_theme_stylebox_override("normal", GameArt.panel(3 if document.drawing_mode == "masterpiece" else 0, 12))
	_masterpiece_tools.visible = document.drawing_mode == "masterpiece"
	var backdrop: Dictionary = Catalog.background(document.background_id)
	_background_button.text = "배경 · " + (str(backdrop.name) if not backdrop.is_empty() else "빈 종이")
	var masterpiece: Dictionary = Catalog.masterpiece(document.masterpiece_id)
	_masterpiece_button.text = "명화 10종 고르기"
	if document.drawing_mode == "masterpiece" and not masterpiece.is_empty():
		_guide_label.text = "%s\n%s · %s\n%s" % [masterpiece.name, masterpiece.artist, masterpiece.year, masterpiece.description]
	else:
		_guide_label.text = "도시, 바다, 우주, 산, 집 등 30가지 배경으로 장면을 꾸며요."
	for button: Button in _selection_buttons:
		button.disabled = selected.is_empty()
	_selection.text = "도형 %d / 128개  ·  " % document.shapes.size()
	if selected.is_empty():
		_selection.text += "도형을 고른 뒤 종이에 그리거나, 선택·이동으로 그림을 골라요."
	else:
		_selection.text += "%s · 변/꼭지점: 크기 · 원형 손잡이: 회전 · 변 길이: 그림 단위" % QuadrilateralMath.kind_name(str(selected.kind))

func _document_changed() -> void:
	_refresh()
	if not testing and not _restoring:
		_autosave.start()

func _set_status(message: String) -> void:
	_status.text = message

func cancel_gesture() -> void:
	if canvas != null:
		canvas.cancel_gesture()

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
	cancel_gesture()
	home_requested.emit()

func save_drawing(show_feedback: bool = true) -> bool:
	var data: Dictionary = {"format": "quadrilateral-drawing", "version": 1, "document": document.serialize()}
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
	if show_feedback:
		_set_status("그림을 저장했어요. 다음에 이어서 그릴 수 있어요.")
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
	if _exporting:
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
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if (_gallery != null and _gallery.visible) or (_color_dialog != null and _color_dialog.visible) or _color_picker.get_popup().visible:
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
		document.move_selected(Vector2(document.get_selected().position) + direction * (10.0 if event.shift_pressed else 2.0))
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
