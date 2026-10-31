class_name ConstructionStudio
extends Control

const State = preload("res://scripts/construction/construction_state.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Canvas = preload("res://scenes/construction/construction_canvas.gd")
const Saves = preload("res://scripts/construction/construction_save_store.gd")
const Art = preload("res://scripts/construction_art.gd")
const Guide = preload("res://scripts/construction/construction_guide.gd")
const MaterialCard = preload("res://scenes/construction/material_card.gd")
const Language = preload("res://scripts/construction/construction_language.gd")
const Awards = preload("res://scripts/construction/construction_awards.gd")
const Exporter = preload("res://scripts/export/construction_exporter.gd")
const SAVE_PATH: String = "user://quadrilateral_construction_v1.json"
const INK: Color = Art.INK
const BLUE: Color = Art.ACCENT
const MUTED: Color = Art.MUTED
const BG: Color = Art.BOARD
const GOOD: Color = Color("90e6b2")
const BAD: Color = Color("ff9b97")
const REPAIRS_PER_PAGE: int = 8
const MATERIAL_CATEGORIES: Array[String] = ["all", "wall", "opening", "roof", "decor"]
const MATERIAL_FAMILIES: Array[String] = ["all", "trapezoid", "parallelogram", "rhombus", "rectangle", "square"]

signal home_requested

var testing: bool = false
var save_path: String = SAVE_PATH
var state: State = State.new()
var canvas: Canvas
var _autosave: Timer
var _status: Label
var _cash: Label
var _cash_pill: PanelContainer
var _client: Label
var _brief: Label
var _satisfaction_label: Label
var _req_summary_label: Label
var _requirements: Label
var _costs: Label
var _selection: Label
var _portrait_holder: CenterContainer
var _materials: VBoxContainer
var _materials_empty: Label
var _material_buttons: Dictionary = {}
var _brick_mode: OptionButton
var _shape_filter: OptionButton
var _category_picker: OptionButton
var _category_chips: HFlowContainer
var _edit_buttons: Array[Button] = []
var _select_button: Button
var _pan_button: Button
var _pan_button_lower: Button
var _undo: Button
var _redo: Button
var _inspect: Button
var _deliver: Button
var _repairs: Button
var _client_action: Button
var _sidebar: PanelContainer
var _palette: PanelContainer
var _palette_hint: Label
var _modal: Control
var _modal_body: VBoxContainer
var _modal_actions: VBoxContainer
var _modal_panel: PanelContainer
var _modal_scroll: ScrollContainer
var _modal_heading: HBoxContainer
var _modal_compact: bool = false
var _last_report: Dictionary = {}
var _last_revision: int = -1
var _portrait_index: int = -1
var _restoring: bool = false
var _top_bar_panel: PanelContainer
var _toolbar: HBoxContainer
var _current_goal: Label
var _design_return: Button
var _lower_toolbar: HFlowContainer
var _completed_actions: VBoxContainer
var _completed_summary: Label
var _guide_bar: HBoxContainer
var _guide_label: Label
var _guide_place: Button
var _guide_toggle: Button
var _guide_enabled: bool = true
var _guide_step: Dictionary = {}
var _compact_details: Button
var _guide_overlay: Control
var _focus_before_modal: Control
var _phase_labels: Array[Label] = []
var _phase_pills: Array[PanelContainer] = []
var _project_label: Label
var _inspector: Label
var _budget: ProgressBar
var _budget_label: Label
var _design_view: Button
var _material_view: Button
var _material_category: String = "all"
var _material_family: String = "all"
var _category_buttons: Dictionary = {}
var _view_phase: String = ""
var _compact_edit: MenuButton
var _layout_margin: MarginContainer
var _layout_column: VBoxContainer
var _stage_button: Button
var _stage_summary: Label
var _stage_card: PanelContainer
var _exporting: bool = false
var _hall_only: bool = false
var _title_label: Label
var _view_bar: HBoxContainer
var _phase_bar: HBoxContainer
var _drawing_title: Label
var _my_house_button: Button
var _my_house_export: Button
var _client_board: PanelContainer
var _client_board_grid: GridContainer
var _client_grid: GridContainer:
	get: return _client_board_grid
var _client_board_asset_label: Label
var _inspector_card: PanelContainer
var _last_exported_png_bytes: PackedByteArray = PackedByteArray()

func _add_material(id: String) -> void:
	var use_id: String = id
	var found: bool = false
	for m: Dictionary in Catalog.materials():
		if str(m.id) == id:
			found = true
			break
	if not found:
		use_id = "wall" if id.contains("wall") else "brick"
	var doc: ConstructionDocument = _active_doc()
	var pos: Vector2 = Vector2(300 + doc.parts.size() * 140, 520)
	doc.add_part(use_id, pos)
	_refresh()

func _active_doc() -> ConstructionDocument:
	return state.active_document()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_autosave = Timer.new()
	_autosave.one_shot = true
	_autosave.wait_time = 0.7
	_autosave.timeout.connect(func(): save_game(false))
	add_child(_autosave)
	state.changed.connect(_state_changed)
	visibility_changed.connect(_on_visibility_changed)
	resized.connect(_responsive)
	if not testing: load_game(false)
	_refresh()
	call_deferred("_ensure_brief")

func _label(text: String, font_size: int = 16, color: Color = INK) -> Label:
	var result: Label = QuadTheme.paragraph(Language.simplify(text), font_size, color)
	result.tooltip_text = Language.help_for(text)
	return result

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = Language.simplify(text)
	button.tooltip_text = Language.help_for(text)
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", QuadTheme.FONT)
	button.add_theme_font_size_override("font_size", 16)
	for mode: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(mode, Art.button_style(primary, mode, 10))
	for mode: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(mode, Color.WHITE if primary else INK)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("607184"))
	var icons: Dictionary = {
		"메인": "home", "저장": "save", "도움말": "help",
		"선택·이동": "select", "선택": "select",
		"화면 이동": "pan", "이동": "pan",
		"되돌리기": "undo", "다시": "redo", "복제": "duplicate",
		"삭제": "delete", "회전": "rotate", "확대": "zoom", "축소": "zoom",
		"집에 맞추기": "fit", "시공 검사": "inspect", "집 보여 주기": "receipt",
		"의뢰인에게 보여주기": "receipt", "설계 보기": "draw", "재료 보기": "book",
		"재료 가격의 근거": "receipt",
		"나만의 집 짓기": "home", "첫 집 안내": "help", "안내 접기": "help",
		"안내대로 놓기": "fit"
	}
	if icons.has(text):
		button.icon = Art.tool_icon(str(icons[text]))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 22)
		button.set_meta("construction_tool", str(icons[text]))
		button.add_theme_constant_override("h_separation", 6)
		for mode: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			button.add_theme_color_override(mode, Color.WHITE)
		button.add_theme_color_override("icon_disabled_color", Color("8c9891"))
	button.add_theme_stylebox_override("focus", ButtonArt.focus_style())
	if callback.is_valid(): button.pressed.connect(callback)
	return button

func _panel(parent: Node, padding: int = 14) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Art.panel(false, padding))
	parent.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box

func _card_box(parent: Node, padding: int = 10, tint: Color = Color("eff5f2")) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Art.card_panel(padding, tint))
	parent.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box

func _picker(font_size: int = 15) -> OptionButton:
	var picker: OptionButton = OptionButton.new()
	picker.custom_minimum_size.y = 44
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.fit_to_longest_item = false
	picker.clip_text = true
	picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	picker.add_theme_font_override("font", QuadTheme.FONT)
	picker.add_theme_font_size_override("font_size", font_size)
	picker.get_popup().add_theme_font_override("font", QuadTheme.FONT)
	picker.get_popup().add_theme_font_size_override("font_size", 15)
	for mode: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		picker.add_theme_color_override(mode, INK)
	picker.add_theme_color_override("font_pressed_color", Color.WHITE)
	picker.get_popup().add_theme_stylebox_override("panel", Art.panel(false, 10))
	picker.get_popup().add_theme_stylebox_override("hover", Art.button_style(false, "hover", 10))
	picker.get_popup().add_theme_color_override("font_color", INK)
	picker.get_popup().add_theme_color_override("font_hover_color", INK)
	for mode: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		picker.add_theme_stylebox_override(mode, Art.button_style(false, mode, 8))
	picker.add_theme_stylebox_override("focus", ButtonArt.focus_style())
	return picker

func _money_line(parent: VBoxContainer, title: String, amount: int, emphasis: bool = false, reading: bool = false) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var name_label: Label = _label(title, 17, INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value: Label = _label(Catalog.format_won(amount), 21 if emphasis else 17, BLUE if emphasis else INK)
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	if reading:
		var read_label: Label = _label(Catalog.read_won(amount), 15, MUTED)
		read_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		parent.add_child(read_label)

func _check_line(parent: VBoxContainer, text: String, detail: String, passed: bool, status_text: String = "") -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var pill: PanelContainer = PanelContainer.new()
	var pill_tint: Color = Color("e7eeea") if not status_text.is_empty() else (Color("d6f2e2") if passed else Color("fbe4df"))
	pill.add_theme_stylebox_override("panel", Art.pill_style(pill_tint, 7, 2))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(pill)
	var status: Label = _label(status_text if not status_text.is_empty() else ("완료" if passed else "보완"), 13, MUTED if not status_text.is_empty() else (GOOD if passed else BAD))
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	pill.add_child(status)
	var description: Label = _label(text, 16)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(description)
	var value: Label = _label(detail, 15, MUTED)
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)

func _modal_action(text: String, callback: Callable, primary: bool = false) -> Button:
	var button: Button = _button(text, callback, primary)
	if text == "이 의뢰 수락하고 시작":
		button.text = text
	_modal_actions.add_child(button)
	return button

func _build_ui() -> void:
	var background: TextureRect = TextureRect.new()
	background.texture = StarfrontArt.scene(7)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.self_modulate = Color("607488")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	_layout_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 12)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	_layout_column = column
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var top_panel: PanelContainer = PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", Art.pill_style(Color("f8fbf9"), 10, 4))
	column.add_child(top_panel)
	var top_box: VBoxContainer = VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 4)
	top_panel.add_child(top_box)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	top_box.add_child(header)
	var home: Button = _button("메인", _go_home)
	home.name = "ConstructionHome"
	header.add_child(home)
	var title: VBoxContainer = VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_constant_override("separation", 2)
	header.add_child(title)
	_title_label = _label("뚝딱! 사각형 집 짓기", 22)
	title.add_child(_title_label)
	_project_label = _label("", 14, BLUE)
	_project_label.visible = false
	title.add_child(_project_label)
	_cash_pill = PanelContainer.new()
	_cash_pill.add_theme_stylebox_override("panel", Art.gold_panel(6))
	header.add_child(_cash_pill)
	_cash = _label("", 15, Color("ffd18a"))
	_cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cash.custom_minimum_size.x = 132
	_cash_pill.add_child(_cash)
	header.add_child(_button("저장", func(): save_game(true)))
	header.add_child(_button("도움말", _show_help))
	_stage_button = _button("집 단계", _show_stages, true)
	_stage_button.name = "ConstructionStages"
	header.add_child(_stage_button)
	_compact_details = _button("의뢰·장부", _show_project_info)
	header.add_child(_compact_details)
	var stages: HBoxContainer = HBoxContainer.new()
	_phase_bar = stages
	_phase_bar.visible = false
	stages.add_theme_constant_override("separation", 8)
	top_box.add_child(stages)
	var phase_icons: Array[String] = ["book", "draw", "inspect", "receipt"]
	var phase_names: Array[String] = ["1 부탁 보기", "2 집 짓기", "3 튼튼한지 확인", "4 보상 받기"]
	for index: int in range(phase_names.size()):
		var pill: PanelContainer = PanelContainer.new()
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pill.add_theme_stylebox_override("panel", Art.pill_style(Color("edf3f0"), 10, 4))
		stages.add_child(pill)
		_phase_pills.append(pill)
		var step: HBoxContainer = HBoxContainer.new()
		step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		step.add_theme_constant_override("separation", 6)
		pill.add_child(step)
		step.add_child(GameArt.view(Art.tool_icon(phase_icons[index]), Vector2(22, 22)))
		var label: Label = _label(phase_names[index], 15, INK)
		step.add_child(label)
		_phase_labels.append(label)
	var workspace: HBoxContainer = HBoxContainer.new()
	workspace.add_theme_constant_override("separation", 8)
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(workspace)
	_palette = PanelContainer.new()
	_palette.add_theme_stylebox_override("panel", Art.card_panel(8, Color("fbfdfc")))
	_palette.custom_minimum_size.x = 240
	workspace.add_child(_palette)
	var palette_box: VBoxContainer = VBoxContainer.new()
	palette_box.add_theme_constant_override("separation", 6)
	_palette.add_child(palette_box)
	var palette_header: HBoxContainer = HBoxContainer.new()
	palette_header.add_theme_constant_override("separation", 6)
	palette_box.add_child(palette_header)
	palette_header.add_child(GameArt.view(Art.tool_icon("draw"), Vector2(20, 20)))
	palette_header.add_child(_label("재료 상자", 18))
	_stage_card = PanelContainer.new()
	_stage_card.visible = false
	_stage_card.add_theme_stylebox_override("panel", Art.gold_panel(8))
	palette_box.add_child(_stage_card)
	_stage_summary = _label("", 13, Color("ffd18a"))
	_stage_summary.visible = false
	_stage_card.add_child(_stage_summary)
	_palette_hint = _label("견본을 고르고 도면에 배치하세요.", 13, MUTED)
	_palette_hint.visible = false
	palette_box.add_child(_palette_hint)
	_shape_filter = _picker()
	_shape_filter.name = "MaterialShapeFilter"
	_shape_filter.tooltip_text = "변과 각의 성질로 찾아요. 고른 이름의 조건을 만족하는 재료를 모두 보여 줘요."
	_shape_filter.add_item("도형: 전체", 0)
	var family_counts: Dictionary = {}
	for material: Dictionary in Catalog.materials():
		for family: String in QuadrilateralMath.KINDS:
			if _material_matches(material, family): family_counts[family] = int(family_counts.get(family, 0)) + 1
	for index: int in range(1, MATERIAL_FAMILIES.size()):
		var family: String = MATERIAL_FAMILIES[index]
		_shape_filter.add_item("도형: %s %d종" % [QuadrilateralMath.kind_label(family), int(family_counts.get(family, 0))], index)
	_shape_filter.item_selected.connect(func(index: int): _filter_shape(MATERIAL_FAMILIES[index]))
	palette_box.add_child(_shape_filter)
	_category_picker = _picker()
	_category_picker.name = "MaterialUseFilter"
	_category_picker.tooltip_text = "용도별 찾기: 도형별 찾기와 함께 적용해요."
	for category_title: String in ["용도: 전체", "용도: 벽체", "용도: 문·창", "용도: 지붕", "용도: 장식"]:
		_category_picker.add_item(category_title)
	_category_picker.item_selected.connect(func(index: int): _browse_materials(MATERIAL_CATEGORIES[index]))
	palette_box.add_child(_category_picker)
	var categories: HFlowContainer = HFlowContainer.new()
	_category_chips = categories
	categories.add_theme_constant_override("h_separation", 4)
	categories.add_theme_constant_override("v_separation", 4)
	palette_box.add_child(categories)
	_brick_mode = _picker(14)
	_brick_mode.add_item("벽 묶음으로 쌓기", 0)
	_brick_mode.add_item("벽돌 한 장씩 쌓기", 1)
	_brick_mode.item_selected.connect(_change_brick_mode)
	palette_box.add_child(_brick_mode)
	for category: Dictionary in [{"id": "all", "label": "전체"}, {"id": "wall", "label": "벽체"}, {"id": "opening", "label": "문·창"}, {"id": "roof", "label": "지붕"}, {"id": "decor", "label": "장식"}]:
		var id: String = str(category.id)
		var button: Button = _button(str(category.label), func(): _browse_materials(id))
		button.icon = Art.category_icon(id)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 16)
		button.add_theme_constant_override("h_separation", 4)
		button.add_theme_font_size_override("font_size", 12)
		button.custom_minimum_size = Vector2(0, 36)
		button.add_theme_stylebox_override("normal", Art.button_style(false, "normal", 6))
		button.add_theme_stylebox_override("pressed", Art.button_style(true, "pressed", 6))
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.toggle_mode = true
		categories.add_child(button)
		_category_buttons[id] = button
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	palette_box.add_child(scroll)
	_materials = VBoxContainer.new()
	_materials.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_materials.add_theme_constant_override("separation", 6)
	scroll.add_child(_materials)
	for material: Dictionary in Catalog.materials():
		var id: String = str(material.id)
		var button: MaterialCard = MaterialCard.new()
		button.configure(id)
		button.name = "Material_" + id
		button.pressed.connect(func(): _choose_material(id))
		_materials.add_child(button)
		_material_buttons[id] = button
	_materials_empty = _label("이 조합의 자재가 없어요.\n전체 용도나 모양으로 바꿔 보세요.", 14, MUTED)
	_materials.add_child(_materials_empty)
	palette_box.add_child(_button("재료 가격의 근거", _show_prices))
	var center_panel: PanelContainer = PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.add_theme_stylebox_override("panel", Art.card_panel(6, Color("f9fcfb")))
	workspace.add_child(center_panel)
	var center: VBoxContainer = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 6)
	center_panel.add_child(center)
	var top_bar_panel: PanelContainer = PanelContainer.new()
	_top_bar_panel = top_bar_panel
	top_bar_panel.add_theme_stylebox_override("panel", Art.pill_style(Color("f4f8f6"), 6, 4))
	center.add_child(top_bar_panel)
	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 6)
	top_bar_panel.add_child(top_bar)

	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 4)
	top_bar.add_child(_toolbar)
	_select_button = _add_edit_button(_toolbar, "선택", _activate_select_mode)
	_select_button.toggle_mode = true
	_select_button.tooltip_text = "선택: 개체를 클릭하여 선택하거나 드래그하여 이동해요"
	_pan_button = _add_edit_button(_toolbar, "화면 이동", _toggle_pan_mode)
	_pan_button.toggle_mode = true
	_pan_button.tooltip_text = "화면 이동: 켜진 상태에서 마우스를 드래그하면 개체가 선택되지 않고 화면(작업 영역)이 이동해요"
	_undo = _add_edit_button(_toolbar, "되돌리기", func(): _active_doc().undo())
	_undo.tooltip_text = "되돌리기: 마지막 작업을 취소해요 (단축키: Ctrl+Z)"
	_redo = _add_edit_button(_toolbar, "다시", func(): _active_doc().redo())
	_redo.tooltip_text = "다시: 취소한 작업을 다시 적용해요 (단축키: Ctrl+Y)"
	var rot_btn: Button = _add_edit_button(_toolbar, "회전", func(): _active_doc().rotate_selected(90.0))
	rot_btn.tooltip_text = "회전: 선택한 자재를 90도 회전해요 (단축키: R)"
	var dup_btn: Button = _add_edit_button(_toolbar, "복제", func(): _active_doc().duplicate_selected())
	dup_btn.tooltip_text = "복제: 선택한 자재를 복제해요 (단축키: D)"
	var del_btn: Button = _add_edit_button(_toolbar, "삭제", func(): _active_doc().delete_selected())
	del_btn.tooltip_text = "삭제: 선택한 자재를 지워요 (단축키: Del)"
	var starter_btn: Button = _add_edit_button(_toolbar, "기초 배치 도움", _build_starter)
	starter_btn.tooltip_text = "기초 배치 도움: 처음에 어떻게 지을지 기초 벽과 문·창을 놓아 줘요"
	var clear_btn: Button = _add_edit_button(_toolbar, "비우기", _confirm_clear)
	clear_btn.tooltip_text = "비우기: 배치한 모든 자재를 지우고 처음부터 다시 시작해요"

	_compact_edit = MenuButton.new()
	_compact_edit.text = "도구 더 보기"
	_compact_edit.custom_minimum_size.y = 38
	_compact_edit.add_theme_font_override("font", QuadTheme.FONT)
	_compact_edit.add_theme_font_size_override("font_size", 14)
	for mode: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]: _compact_edit.add_theme_stylebox_override(mode, Art.button_style(false, mode, 8))
	for mode: String in ["font_color", "font_hover_color", "font_pressed_color"]: _compact_edit.add_theme_color_override(mode, INK)
	_compact_edit.add_theme_color_override("font_pressed_color", Color.WHITE)
	_compact_edit.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	_compact_edit.add_theme_stylebox_override("focus", ButtonArt.focus_style())
	for text: String in ["선택", "화면 이동", "되돌리기", "다시", "복제", "삭제", "회전", "기초 배치 도움", "비우기"]: _compact_edit.get_popup().add_item(text)
	_compact_edit.get_popup().id_pressed.connect(_compact_edit_action)
	_compact_edit.visible = false
	top_bar.add_child(_compact_edit)
	_edit_buttons.append(_compact_edit)

	var top_spacer: Control = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)

	var view_bar: HBoxContainer = HBoxContainer.new()
	_view_bar = view_bar
	view_bar.add_theme_constant_override("separation", 6)
	top_bar.add_child(view_bar)
	var drawing_title: Label = _label("건설 작업장", 16, BLUE)
	_drawing_title = drawing_title
	_drawing_title.visible = false
	view_bar.add_child(drawing_title)
	_my_house_button = _button("나만의 집 짓기", _toggle_my_house_mode, true)
	_my_house_button.name = "MyHouseModeButton"
	view_bar.add_child(_my_house_button)
	_guide_toggle = _button("첫 집 안내", _toggle_guide)
	_guide_toggle.custom_minimum_size.x = 92
	view_bar.add_child(_guide_toggle)
	_edit_buttons.append(_guide_toggle)
	_design_view = _button("설계 보기", func(): _set_view(false))
	_material_view = _button("재료 보기", func(): _set_view(true))
	for button: Button in [_design_view, _material_view]:
		button.toggle_mode = true
		button.custom_minimum_size.x = 92
		button.add_theme_stylebox_override("pressed", Art.button_style(true, "pressed", 8))
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		view_bar.add_child(button)
	_guide_bar = HBoxContainer.new()
	_guide_bar.add_theme_constant_override("separation", 10)
	center.add_child(_guide_bar)
	var guide_pill: PanelContainer = PanelContainer.new()
	guide_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_pill.add_theme_stylebox_override("panel", Art.gold_panel(8))
	_guide_bar.add_child(guide_pill)
	_guide_label = _label("", 14, Color("ffd18a"))
	_guide_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_pill.add_child(_guide_label)
	_guide_place = _button("안내대로 놓기", _place_guide_step, true)
	_guide_place.name = "PlaceConstructionGuide"
	_guide_bar.add_child(_guide_place)
	_completed_actions = VBoxContainer.new()
	_completed_actions.add_theme_constant_override("separation", 6)
	center.add_child(_completed_actions)
	_completed_actions.add_child(_label("준공 완료", 25, GOOD))
	_completed_summary = _label("", 16, BLUE)
	_completed_actions.add_child(_completed_summary)
	var completed_buttons: HFlowContainer = HFlowContainer.new()
	completed_buttons.add_theme_constant_override("h_separation", 6)
	_completed_actions.add_child(completed_buttons)
	var next_client: Button = _button("다음 부탁", _next_contract, true)
	next_client.name = "NextConstructionClient"
	completed_buttons.add_child(next_client)
	completed_buttons.add_child(_button("완성한 집 기록", _show_history))
	completed_buttons.add_child(_button("PNG 저장", _export_current_house))
	completed_buttons.add_child(_button("명예의 전당", _show_hall))
	completed_buttons.add_child(_button("나만의 집 짓기", _enter_my_house_mode, true))
	canvas = Canvas.new()
	canvas.name = "ConstructionCanvas"
	canvas.document = state.document
	canvas.custom_minimum_size = Vector2(240, 100)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.hint_requested.connect(_set_status)
	canvas.inspection_finished.connect(_inspection_finished)
	canvas.tool_changed.connect(_refresh)
	_current_goal = _label("", 16, BLUE)
	_current_goal.name = "CurrentConstructionGoal"
	center.add_child(_current_goal)
	center.add_child(canvas)
	_guide_overlay = Control.new()
	_guide_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_guide_overlay)
	_guide_overlay.draw.connect(_draw_guide)
	canvas.draw.connect(_guide_overlay.queue_redraw)
	_build_onscreen_client_board()
	var dock_panel: PanelContainer = PanelContainer.new()
	dock_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_panel.add_theme_stylebox_override("panel", Art.pill_style(Color("eef6f2"), 6, 2))
	center.add_child(dock_panel)
	_lower_toolbar = HFlowContainer.new()
	_lower_toolbar.add_theme_constant_override("h_separation", 6)
	_lower_toolbar.add_theme_constant_override("v_separation", 6)
	_lower_toolbar.alignment = FlowContainer.ALIGNMENT_CENTER
	dock_panel.add_child(_lower_toolbar)
	_pan_button_lower = _add_edit_button(_lower_toolbar, "화면 이동", _toggle_pan_mode)
	_pan_button_lower.toggle_mode = true
	_pan_button_lower.tooltip_text = "화면 이동: 켜진 상태에서 마우스를 드래그하면 개체가 선택되지 않고 화면(작업 영역)이 이동해요"
	_add_edit_button(_lower_toolbar, "확대", func(): canvas.zoom_by(1.25))
	_add_edit_button(_lower_toolbar, "축소", func(): canvas.zoom_by(0.8))
	_add_edit_button(_lower_toolbar, "집에 맞추기", func(): canvas.fit_parts())
	var move: MenuButton = MenuButton.new()
	move.text = "재료 이동"
	move.custom_minimum_size.y = 44
	move.add_theme_font_override("font", QuadTheme.FONT)
	move.add_theme_font_size_override("font_size", 14)
	for mode: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]: move.add_theme_stylebox_override(mode, Art.button_style(false, mode, 8))
	for mode: String in ["font_color", "font_hover_color", "font_pressed_color"]: move.add_theme_color_override(mode, INK)
	move.add_theme_color_override("font_pressed_color", Color.WHITE)
	move.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	move.add_theme_stylebox_override("focus", ButtonArt.focus_style())
	for name: String in ["왼쪽", "오른쪽", "위", "아래"]: move.get_popup().add_item(name)
	move.get_popup().id_pressed.connect(func(id: int):
		var directions: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
		_edit(func(): _move_selected(directions[id]))
	)
	_lower_toolbar.add_child(move)
	_edit_buttons.append(move)
	_design_return = _button("설계로 돌아가기", _return_to_design)
	_lower_toolbar.add_child(_design_return)
	_inspect = _button("시공 검사", _start_inspection, true)
	_inspect.name = "InspectConstruction"
	_lower_toolbar.add_child(_inspect)
	_deliver = _button("집 보여 주기", _show_report, true)
	_deliver.name = "ReviewConstruction"
	_lower_toolbar.add_child(_deliver)
	_my_house_export = _button("나만의 집 PNG 저장", _export_my_house, true)
	_my_house_export.name = "ExportMyHousePng"
	_lower_toolbar.add_child(_my_house_export)
	_selection = _label("", 13, MUTED)
	center.add_child(_selection)
	_sidebar = PanelContainer.new()
	_sidebar.add_theme_stylebox_override("panel", Art.card_panel(8, Color("fbfdfc")))
	_sidebar.custom_minimum_size.x = 250
	workspace.add_child(_sidebar)
	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	_sidebar.add_child(right)
	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 6)
	var detail_scroll: ScrollContainer = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.follow_focus = true
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail_scroll)
	detail_scroll.add_child(details)
	var client_card: VBoxContainer = _card_box(details, 7, Color("f6efe0"))
	(client_card.get_parent() as PanelContainer).add_theme_stylebox_override("panel", Art.gold_panel(8))
	var client_row: HBoxContainer = HBoxContainer.new()
	client_row.add_theme_constant_override("separation", 8)
	client_card.add_child(client_row)
	_portrait_holder = CenterContainer.new()
	_portrait_holder.custom_minimum_size = Vector2(46, 50)
	client_row.add_child(_portrait_holder)
	var client_info: VBoxContainer = VBoxContainer.new()
	client_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	client_row.add_child(client_info)
	_client = _label("", 15)
	client_info.add_child(_client)
	_brief = _label("", 12, MUTED)
	client_info.add_child(_brief)
	var sat_pill: PanelContainer = PanelContainer.new()
	sat_pill.add_theme_stylebox_override("panel", Art.pill_style(Color("dfeee7"), 6, 2))
	client_card.add_child(sat_pill)
	_satisfaction_label = _label("", 14, BLUE)
	sat_pill.add_child(_satisfaction_label)
	_client_action = _button("의뢰서 보기", _client_clicked)
	_client_action.custom_minimum_size.y = 32
	client_card.add_child(_client_action)
	var req_card: VBoxContainer = _card_box(details, 7, Color("eef6f2"))
	var req_header: HBoxContainer = HBoxContainer.new()
	req_card.add_child(req_header)
	var req_title: Label = _label("설계 조건", 14, BLUE)
	req_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	req_header.add_child(req_title)
	var req_badge: PanelContainer = PanelContainer.new()
	req_badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	req_badge.add_theme_stylebox_override("panel", Art.pill_style(Color("d6f0e2"), 6, 2))
	req_header.add_child(req_badge)
	_req_summary_label = _label("", 11, GOOD)
	_req_summary_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	req_badge.add_child(_req_summary_label)
	_requirements = _label("", 15)
	_requirements.add_theme_constant_override("line_spacing", 2)
	req_card.add_child(_requirements)
	var cost_card: VBoxContainer = _card_box(details, 7, Color("eef5f2"))
	var cost_hdr: HBoxContainer = HBoxContainer.new()
	cost_hdr.add_theme_constant_override("separation", 6)
	cost_card.add_child(cost_hdr)
	cost_hdr.add_child(GameArt.view(Art.tool_icon("receipt"), Vector2(16, 16)))
	cost_hdr.add_child(_label("공사 견적", 14, BLUE))
	_costs = _label("", 15)
	_costs.add_theme_constant_override("line_spacing", 2)
	cost_card.add_child(_costs)
	_budget = ProgressBar.new()
	_budget.custom_minimum_size.y = 7
	_budget.show_percentage = false
	_budget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var budget_background: StyleBoxTexture = Art.card_panel(0, Color("d4e2dc"))
	var budget_fill: StyleBoxTexture = StarfrontArt.gauge(7)
	_budget.add_theme_stylebox_override("background", budget_background)
	_budget.add_theme_stylebox_override("fill", budget_fill)
	cost_card.add_child(_budget)
	_budget_label = _label("", 11, MUTED)
	cost_card.add_child(_budget_label)
	var ledger_btn: Button = _button("돈 계산 자세히", _show_ledger)
	ledger_btn.custom_minimum_size.y = 30
	cost_card.add_child(ledger_btn)
	var inspector_card: VBoxContainer = _card_box(details, 7, Color("f2f7f4"))
	_inspector_card = inspector_card.get_parent() as PanelContainer
	_inspector_card.visible = false
	inspector_card.add_child(_label("선택 자재", 13, BLUE))
	_inspector = _label("", 15, MUTED)
	inspector_card.add_child(_inspector)
	var quick_row: HBoxContainer = HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", 4)
	quick_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(quick_row)
	var hist_btn: Button = _button("기록", _show_history)
	hist_btn.tooltip_text = "완성한 집 기록"
	hist_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hist_btn.custom_minimum_size.y = 32
	quick_row.add_child(hist_btn)
	var hall_btn: Button = _button("전당", _show_hall)
	hall_btn.tooltip_text = "명예의 전당"
	hall_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hall_btn.custom_minimum_size.y = 32
	quick_row.add_child(hall_btn)
	var dict_btn: Button = _button("사전", _show_glossary)
	dict_btn.tooltip_text = "쉬운 말 사전"
	dict_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dict_btn.custom_minimum_size.y = 32
	quick_row.add_child(dict_btn)
	var footer_panel: PanelContainer = PanelContainer.new()
	footer_panel.add_theme_stylebox_override("panel", Art.pill_style(Color("edf5f2"), 6, 2))
	column.add_child(footer_panel)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	footer_panel.add_child(footer)
	footer.add_child(GameArt.view(Art.tool_icon("inspect"), Vector2(20, 20)))
	_status = _label("의뢰서를 확인하고 첫 프로젝트를 시작하세요.", 14, BLUE)
	_status.custom_minimum_size.y = 24
	_status.max_lines_visible = 2
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status)
	_repairs = _button("고칠 곳 보기", _show_repairs, true)
	_repairs.name = "ConstructionRepairs"
	footer.add_child(_repairs)
	_change_brick_mode(0)
	_filter_materials("all")
	_responsive()

static func _material_matches(material: Dictionary, family: String) -> bool:
	return QuadrilateralMath.matches_kind(QuadrilateralMath.create_vertices(str(material.kind), Vector2(material.dimensions)), family)

func _filter_materials(category: String) -> void:
	if not MATERIAL_CATEGORIES.has(category): return
	_material_category = category
	var shown_count: int = 0
	var family_counts: Dictionary = {}
	for id: String in _material_buttons:
		var material: Dictionary = Catalog.material(id)
		var role: String = str(material.role)
		var shown: bool = category == "all" or (category == "wall" and role in ["brick", "wall", "beam"]) or (category == "opening" and role in ["door", "window"]) or category == role
		shown = shown and _allowed_families().has(str(material.kind))
		if shown:
			for family: String in QuadrilateralMath.KINDS:
				if _material_matches(material, family): family_counts[family] = int(family_counts.get(family, 0)) + 1
		shown = shown and (_material_family == "all" or _material_matches(material, _material_family))
		if _material_family == "all":
			if id == "brick": shown = shown and _brick_mode.selected == 1
			if id == "wall": shown = shown and _brick_mode.selected == 0
		_material_buttons[id].visible = shown
		if shown: shown_count += 1
	for index: int in range(1, MATERIAL_FAMILIES.size()):
		var family: String = MATERIAL_FAMILIES[index]
		_shape_filter.set_item_text(index, "도형: %s %d종" % [QuadrilateralMath.kind_label(family), int(family_counts.get(family, 0))])
	_materials_empty.visible = shown_count == 0
	for id: String in _category_buttons: _category_buttons[id].set_pressed_no_signal(id == category)
	_category_picker.select(MATERIAL_CATEGORIES.find(category))
	_brick_mode.visible = _material_family == "all"

func _filter_shape(family: String) -> void:
	if not MATERIAL_FAMILIES.has(family): return
	_material_family = family
	_shape_filter.select(MATERIAL_FAMILIES.find(family))
	_filter_materials(_material_category)
	_reset_material_scroll()

func _browse_materials(category: String) -> void:
	_filter_materials(category)
	_reset_material_scroll()

func _reset_material_scroll() -> void:
	var library: ScrollContainer = _materials.get_parent() as ScrollContainer
	library.set_deferred("scroll_vertical", 0)

func _clear_material_filters() -> void:
	_material_family = "all"
	_shape_filter.select(0)
	_filter_materials("all")

func _set_view(presentation: bool) -> void:
	canvas.set_presentation_mode(presentation)
	_design_view.set_pressed_no_signal(not presentation)
	_material_view.set_pressed_no_signal(presentation)

func _compact_edit_action(id: int) -> void:
	match id:
		0: _activate_select_mode()
		1: _toggle_pan_mode()
		2: _edit(func(): _active_doc().undo())
		3: _edit(func(): _active_doc().redo())
		4: _edit(func(): _active_doc().duplicate_selected())
		5: _edit(func(): _active_doc().delete_selected())
		6: _edit(func(): _active_doc().rotate_selected(90.0))
		7: _edit(_build_starter)
		8: _edit(_confirm_clear)

func _add_edit_button(parent: Node, text: String, callback: Callable) -> Button:
	var button: Button = _button(text, func(): _edit(callback))
	button.add_theme_font_size_override("font_size", 15)
	button.custom_minimum_size.y = 44
	button.add_theme_constant_override("icon_max_width", 18)
	_edit_buttons.append(button)
	parent.add_child(button)
	return button

func _activate_select_mode() -> void:
	canvas.select_tool()
	if is_instance_valid(_pan_button):
		_pan_button.button_pressed = false
	if is_instance_valid(_pan_button_lower):
		_pan_button_lower.button_pressed = false
	if is_instance_valid(_select_button):
		_select_button.button_pressed = true
	_set_status("선택 모드: 개체를 클릭하여 선택하거나 드래그하여 이동할 수 있어요.")

func _toggle_pan_mode() -> void:
	var active: bool = canvas.toggle_pan_tool()
	if is_instance_valid(_pan_button):
		_pan_button.button_pressed = active
	if is_instance_valid(_pan_button_lower):
		_pan_button_lower.button_pressed = active
	if is_instance_valid(_select_button):
		_select_button.button_pressed = not active and not canvas.drawing_tool
	if active:
		_set_status("화면 이동 켜짐: 마우스로 드래그하면 개체가 선택되지 않고 화면이 이동해요.")
	else:
		_set_status("선택 모드로 돌아왔어요.")

func _is_editable_mode() -> bool:
	return state.my_house_mode or state.phase == "building"

func _edit(callback: Callable) -> void:
	if not _is_editable_mode() or canvas.inspection_running or is_instance_valid(_modal): return
	canvas.stop_inspection()
	canvas.cancel_gesture()
	_active_doc().last_error = ""
	callback.call()
	if not _active_doc().last_error.is_empty(): _set_status(_active_doc().last_error)
	_refresh()

func _choose_material(id: String) -> void:
	if not _is_editable_mode() or canvas.inspection_running: return
	canvas.stop_inspection()
	canvas.choose_material(id)
	if SoundManager.instance != null:
		SoundManager.instance.play_click()
	var material: Dictionary = Catalog.material(id)
	_set_status("%s · %s\n%s" % [material.label, Catalog.format_won(int(material.price)), material.description])
	_refresh()
	if _material_buttons[id].visible:
		var library: ScrollContainer = _materials.get_parent() as ScrollContainer
		library.call_deferred("ensure_control_visible", _material_buttons[id])

func _change_brick_mode(index: int) -> void:
	_filter_materials(_material_category)
	if is_instance_valid(canvas) and _is_editable_mode():
		var id: String = "brick" if index == 1 else "wall"
		if not _material_buttons[id].visible: _clear_material_filters()
		_choose_material(id)

func _move_selected(direction: Vector2) -> void:
	var selected: Dictionary = _active_doc().get_selected()
	if not selected.is_empty():
		if not _active_doc().move_selected(Vector2(selected.position) + direction * 20.0):
			_set_status("다른 재료나 문·창문 자리를 침범하지 않는 곳으로 옮겨 주세요.")

func _build_starter() -> void:
	if not _is_editable_mode() or canvas.inspection_running or is_instance_valid(_modal): return
	if not _active_doc().parts.is_empty():
		_open_modal("기초 배치로 바꿀까요?", true)
		_modal_body.add_child(_label("지금 만든 재료 %d개를 문·창문과 벽의 기초 배치로 바꿔요. 바꾼 뒤에도 되돌리기로 지금 설계를 복구할 수 있어요." % _active_doc().parts.size(), 18))
		_modal_action("기초 배치로 바꾸기", func():
			_close_modal()
			_apply_starter()
		, true)
		_modal_action("지금 설계 계속 짓기", _close_modal)
		return
	_apply_starter()

func _apply_starter() -> void:
	if not _is_editable_mode() or canvas.inspection_running or is_instance_valid(_modal): return
	var applied: bool = false
	if state.my_house_mode:
		state.my_house_document.budget_limit = state.my_house_budget()
		applied = state.my_house_document.replace_parts(Guide.plan())
	else:
		applied = state.build_starter()
	if applied:
		canvas.call_deferred("fit_parts")
		if not state.my_house_mode and _guide_enabled and state.contract_index == 0: _select_guide_material()
		_set_status("문과 창문의 자리를 잡았어요. 주변 벽을 높이고, 빈자리 위에 보와 지붕을 올려 보세요. 되돌리기도 가능해요.")
	else:
		_set_status("기초 배치를 만들 수 없어요. 의뢰와 재료 예산을 확인해 주세요.")

func _toggle_guide() -> void:
	_guide_enabled = not _guide_enabled
	_refresh()
	canvas.call_deferred("fit_parts")
	if _guide_enabled:
		_select_guide_material()
		_set_status("첫 집을 지어 보는 배치 예시예요. 안내 위치를 따라 놓거나, 자유롭게 다른 집을 설계해도 돼요.")

func _place_guide_step() -> void:
	if state.phase != "building" or state.contract_index != 0 or canvas.inspection_running or is_instance_valid(_modal): return
	var step: Dictionary = Guide.next_step(state.document)
	if step.is_empty(): return
	canvas.stop_inspection()
	canvas.cancel_gesture()
	if state.document.add_part(str(step.material_id), step.position) < 0:
		_set_status(state.document.last_error + " 안내는 배치 예시이므로 접고 자유롭게 이어 지어도 돼요.")
		return
	canvas.call_deferred("fit_parts")
	_select_guide_material()
	_set_status(str(step.description) + " 되돌리기로 한 단계 전으로 돌아갈 수 있어요.")
	_refresh()

func _select_guide_material() -> void:
	var step: Dictionary = Guide.next_step(state.document)
	if step.is_empty(): return
	var id: String = str(step.material_id)
	if not _material_buttons[id].visible: _clear_material_filters()
	if id in ["brick", "wall"]:
		var mode: int = 1 if id == "brick" else 0
		_brick_mode.select(mode)
		_change_brick_mode(mode)
	else:
		_choose_material(id)

func _draw_guide() -> void:
	if not _guide_bar.visible or _guide_step.is_empty() or canvas.inspection_visible or not canvas.facade_gaps.is_empty() or is_instance_valid(_modal): return
	var points: PackedVector2Array = PackedVector2Array()
	for vertex: Vector2 in _guide_step.vertices:
		points.append(canvas.artwork_to_screen(vertex + Vector2(_guide_step.position)))
	_guide_overlay.draw_colored_polygon(points, Color(0.92, 0.62, 0.16, 0.22))
	points.append(points[0])
	_guide_overlay.draw_polyline(points, Color("d9821e"), 2.5, true)
	_guide_overlay.draw_circle(canvas.artwork_to_screen(_guide_step.position), 5.5, Color("d9821e"))

func _confirm_clear() -> void:
	_open_modal("설계를 비울까요?")
	_modal_body.add_child(_label("이번 집의 배치만 비워요. 재료 예산은 돌아오며, 되돌리기로 복구할 수 있어요."))
	_modal_body.add_child(_button("설계 비우기", func():
		_close_modal()
		_active_doc().clear()
	, true))
	_modal_action("계속 짓기", _close_modal)

func _state_changed() -> void:
	var active_rev: int = _active_doc().revision
	if active_rev != _last_revision:
		if not _last_report.is_empty():
			_set_status("설계를 바꿨어요. 시공 검사를 다시 하면 고칠 곳도 새로 확인할 수 있어요.")
		_last_report.clear()
		_last_revision = active_rev
	_refresh()
	if not testing and not _restoring and is_instance_valid(_autosave): _autosave.start()

func _short_req_label(raw: String) -> String:
	var s: String = raw
	var map: Dictionary = {
		"중력 검사 · 문과 창 주변 지지": "안전·받침 확인",
		"문·창문 위에 지붕 올리기": "문·창문 위 지붕",
		"바닥부터 처마까지 외벽 빈틈 채우기": "외벽 빈틈 채우기",
		"자재 예산 지키기": "자재 예산 준수",
		"이번 단계에서 고를 수 있는 사각형 사용하기": "단계 도형 준수",
		"출입문 1개": "현관문 1개",
		"지붕 1개 이상": "지붕 1개+"
	}
	if map.has(s):
		return str(map[s])
	s = s.replace(" 이상으로 벽 만들기", "+")
	s = s.replace("사각형 종류 ", "도형 ")
	s = s.replace("가지 이상", "종+")
	return s

func _refresh() -> void:
	if not is_instance_valid(canvas): return
	var active_doc: ConstructionDocument = _active_doc()
	if canvas.document != active_doc:
		canvas.document = active_doc
	var contract: Dictionary = state.current_contract()
	var my_mode: bool = state.my_house_mode
	if is_instance_valid(_drawing_title):
		_drawing_title.text = "나만의 집" if my_mode else "건설 작업장"
	if is_instance_valid(_pan_button):
		_pan_button.button_pressed = canvas.pan_tool
	if is_instance_valid(_pan_button_lower):
		_pan_button_lower.button_pressed = canvas.pan_tool
	if is_instance_valid(_select_button):
		_select_button.button_pressed = not canvas.pan_tool and not canvas.drawing_tool
	if is_instance_valid(_my_house_button):
		_my_house_button.text = ("의뢰 모드" if size.x < 1100 else "의뢰 집 짓기") if my_mode else ("내 집 짓기" if size.x < 1100 else "나만의 집 짓기")
	if my_mode:
		_project_label.text = "나만의 집 · %s" % Catalog.format_won(state.my_house_available_balance())
	else:
		_project_label.text = "%d단계 · %s" % [int(contract.get("stage", 1)), str(contract.title)]
	var family_names: PackedStringArray = PackedStringArray()
	for family: String in _allowed_families(): family_names.append(QuadrilateralMath.kind_label(family))
	_stage_summary.text = ("나만의 집 재료\n%s" % " · ".join(family_names)) if my_mode else ("%d단계 재료\n%s" % [int(contract.get("stage", 1)), " · ".join(family_names)])
	_stage_button.text = ("%d단계" if size.x < 1200 else "%d단계 · 의뢰") % int(contract.get("stage", 1))
	_filter_materials(_material_category)
	var effective_phase: String = "my_house" if my_mode else state.phase
	if _view_phase != effective_phase:
		_view_phase = effective_phase
		_set_view(not my_mode and state.phase == "settled")
	var phase_index: int = 1 if my_mode else (0 if state.phase == "briefing" else (3 if state.phase == "settled" or not _last_report.is_empty() else (2 if canvas.inspection_running else 1)))
	for index: int in range(_phase_labels.size()):
		var is_current: bool = index == phase_index
		var is_done: bool = index < phase_index
		_phase_labels[index].add_theme_color_override("font_color", Color("ffd18a") if is_current else (GOOD if is_done else MUTED))
		if index < _phase_pills.size():
			if is_current:
				_phase_pills[index].add_theme_stylebox_override("panel", Art.gold_panel(5))
			else:
				var pill_color: Color = Color("d8f2e3") if is_done else Color("edf2ef")
				_phase_pills[index].add_theme_stylebox_override("panel", Art.pill_style(pill_color, 10, 4))
	_cash.text = "보유 " + Catalog.format_won(state.my_house_available_balance() if my_mode else state.available_balance())
	if my_mode:
		_current_goal.text = "자유롭게 만들고 PNG로 저장해요. 재료의 변과 각도 살펴보세요."
		_client.text = "나만의 집 짓기"
		_brief.text = "수익 %s" % Catalog.format_won(state.earned_profit())
		var my_counts: Dictionary = State.count_parts(active_doc.parts)
		var used_kinds: int = 0
		for k: String in my_counts.selected_by_kind:
			if int(my_counts.selected_by_kind[k]) > 0: used_kinds += 1
		_requirements.text = "자유 설계 (%d개 배치)\n• 문 %d · 창 %d · 도형 %d종\n• 완성 후 PNG 저장 가능" % [active_doc.parts.size(), int(my_counts.doors), int(my_counts.windows), used_kinds]
		if is_instance_valid(_req_summary_label):
			_req_summary_label.text = "자유"
		if is_instance_valid(_satisfaction_label):
			_satisfaction_label.text = "자산 %s" % Catalog.format_won(state.my_house_budget())
		_costs.text = "보유 자산  %s\n사용 재료비  %s\n남은 자금  %s" % [Catalog.format_won(state.my_house_budget()), Catalog.format_won(state.my_house_cost()), Catalog.format_won(state.my_house_available_balance())]
		_budget.value = 100.0 * state.my_house_cost() / maxi(1, state.my_house_budget())
		_budget_label.text = "자산 %.0f%% 사용" % _budget.value
		_client_action.text = "의뢰 선택"
	else:
		_client.text = "%d단계 · %s" % [int(contract.get("stage", 1)), str(contract.client)]
		_brief.text = str(contract.title)
		var portrait_index: int = int(contract.portrait)
		if portrait_index != _portrait_index:
			_portrait_index = portrait_index
			for child: Node in _portrait_holder.get_children(): child.queue_free()
			var portrait: Control = Art.portrait(portrait_index)
			portrait.custom_minimum_size = Vector2(54, 60)
			_portrait_holder.add_child(portrait)
		var evaluation: Dictionary = state.evaluate(_last_report)
		var met_count: int = 0
		var total_rows: int = evaluation.rows.size()
		var requirement_lines: PackedStringArray = PackedStringArray()
		var next_needs: PackedStringArray = PackedStringArray()
		for row: Dictionary in evaluation.rows:
			var raw_label: String = str(row.label)
			var is_met: bool = bool(row.met) or (state.phase == "settled" and raw_label.begins_with("중력 검사"))
			if is_met:
				met_count += 1
			if is_met and (raw_label.contains("예산") or raw_label.contains("고를 수 있는 사각형")):
				continue
			var mandatory: bool = bool(row.get("mandatory", true))
			if not is_met and mandatory and next_needs.size() < 2: next_needs.append(_short_req_label(raw_label))
			if not mandatory and is_met: continue
			var short_lbl: String = ("필수 · " if mandatory else "더하기 · ") + _short_req_label(raw_label)
			var mark: String = "●" if is_met else "○"
			if raw_label.contains("예산") or int(row.target) <= 1 and raw_label.begins_with("중력"):
				requirement_lines.append("%s %s" % [mark, short_lbl])
			else:
				requirement_lines.append("%s %s (%d/%d)" % [mark, short_lbl, int(row.current), int(row.target)])
		_requirements.text = "\n".join(requirement_lines)
		_current_goal.text = "다음 할 일 · " + (" / ".join(next_needs) if not next_needs.is_empty() else "튼튼한지 확인하고 집을 보여 주세요.")
		if is_instance_valid(_req_summary_label):
			_req_summary_label.text = "%d/%d" % [met_count, total_rows]
		if is_instance_valid(_satisfaction_label):
			var display_score: int = int(state.last_result.get("score", evaluation.score)) if state.phase == "settled" else int(evaluation.score)
			_satisfaction_label.text = "만족도 %d점 · 조건 %d/%d" % [display_score, met_count, total_rows]
			if _portrait_holder.get_child_count() > 0:
				var portrait_ctrl: Node = _portrait_holder.get_child(0)
				if portrait_ctrl is Art.ClientPortrait:
					(portrait_ctrl as Art.ClientPortrait).mood = "happy" if display_score >= 80 else ("straight" if display_score >= 50 else "sad")
		var displayed_profit: int = int(state.last_result.get("profit", evaluation.profit)) if state.phase == "settled" else int(evaluation.profit)
		_costs.text = "집 전체 약속한 돈  %s\n먼저 받은 돈  %s\n재료비  %s\n%s  %s" % [Catalog.format_won(int(contract.total)), Catalog.format_won(int(contract.advance)), Catalog.format_won(state.material_cost()), "정산 이익" if state.phase == "settled" else "예상 이익", Catalog.format_won(displayed_profit)]
		_budget.value = 100.0 * state.material_cost() / maxi(1, int(contract.material_budget))
		_budget_label.text = "예산 %s (%.0f%%)" % [Catalog.format_won(int(contract.material_budget)), _budget.value]
		_client_action.text = "다음 부탁" if state.phase == "settled" else ("부탁 받기" if state.phase == "briefing" else "부탁 보기")
	var editing: bool = _is_editable_mode() and not canvas.inspection_running and not is_instance_valid(_modal)
	canvas.editing_enabled = editing
	for button: Button in _edit_buttons: button.disabled = not editing
	_undo.disabled = not editing or not active_doc.command_manager.can_undo()
	_redo.disabled = not editing or not active_doc.command_manager.can_redo()
	for id: String in _material_buttons:
		var button: Button = _material_buttons[id]
		button.disabled = not editing
		button.set_pressed_no_signal(canvas.drawing_tool and canvas.material_id == id and editing)
	_brick_mode.disabled = not editing
	_shape_filter.disabled = is_instance_valid(_modal)
	_category_picker.disabled = is_instance_valid(_modal)
	var settled: bool = (not my_mode and state.phase == "settled")
	_palette.visible = not settled
	if is_instance_valid(_top_bar_panel):
		_top_bar_panel.visible = not settled
	_toolbar.visible = not settled and size.x >= 1450 and size.y >= 800
	for index: int in range(_toolbar.get_child_count()): _toolbar.get_child(index).visible = index in [0, 2, 3]
	_compact_edit.visible = not settled
	_design_return.visible = canvas.inspection_visible
	_current_goal.visible = not settled
	_lower_toolbar.visible = not settled
	_completed_actions.visible = settled
	if settled:
		_completed_summary.text = "만족도 %d점 · 이익 %s" % [int(state.last_result.get("score", 0)), Catalog.format_won(int(state.last_result.get("profit", 0)))]
	_guide_toggle.visible = not my_mode and state.contract_index == 0 and state.phase == "building"
	_guide_toggle.text = "안내 접기" if _guide_enabled else "첫 집 안내"
	_guide_toggle.set_pressed_no_signal(_guide_enabled)
	_guide_bar.visible = not my_mode and state.phase == "building" and state.contract_index == 0 and _guide_enabled
	_guide_step = Guide.next_step(state.document) if _guide_bar.visible else {}
	var guide_bounds: Rect2 = Rect2()
	if not _guide_step.is_empty():
		guide_bounds = QuadrilateralMath.bounds(_guide_step.vertices)
		guide_bounds.position += Vector2(_guide_step.position)
	canvas.fit_context = guide_bounds
	_guide_place.disabled = not editing or _guide_step.is_empty()
	if _guide_bar.visible:
		if _guide_step.is_empty():
			_guide_label.text = "예시 배치 완료! 튼튼한지 확인을 눌러 보세요."
		else:
			_guide_label.text = "예시 %d/%d · %s" % [int(_guide_step.index) + 1, int(_guide_step.total), Catalog.material(str(_guide_step.material_id)).label]
	_refresh_onscreen_client_board()
	canvas.queue_redraw()
	_inspect.disabled = not editing or active_doc.parts.is_empty()
	_inspect.text = "검사 중…" if canvas.inspection_running else "시공 검사"
	_deliver.visible = not my_mode
	_deliver.disabled = my_mode or state.phase != "building" or _last_report.is_empty() or canvas.inspection_running or is_instance_valid(_modal)
	if is_instance_valid(_my_house_export):
		_my_house_export.visible = my_mode
		_my_house_export.disabled = not my_mode or active_doc.parts.is_empty() or canvas.inspection_running or is_instance_valid(_modal)
	var issues: Array[Dictionary] = _fresh_issues()
	_repairs.visible = not issues.is_empty()
	_repairs.disabled = canvas.inspection_running or is_instance_valid(_modal)
	_repairs.text = "고칠 곳 %d개 보기" % issues.size()
	var selected: Dictionary = active_doc.get_selected()
	if is_instance_valid(_inspector_card):
		_inspector_card.visible = not selected.is_empty()
	if selected.is_empty():
		_inspector.text = ""
		_selection.text = ""
		_selection.visible = false
	else:
		var material: Dictionary = Catalog.material(str(selected.material_id))
		var edge_labels: PackedStringArray = PackedStringArray()
		for length: float in QuadrilateralMath.side_lengths(selected.vertices):
			var cells: float = length / Catalog.GRID_UNIT
			edge_labels.append(("약 " if absf(cells - snappedf(cells, 0.01)) > 0.0001 else "") + Catalog.format_length(cells))
		var edges: String = "변 " + "·".join(edge_labels) + "칸"
		_inspector.text = "%s\n%s\n%s" % [material.label, edges, QuadrilateralMath.property_summary(selected.vertices)]
		_selection.text = "%s · %s · %s" % [material.label, Catalog.format_won(int(material.price)), edges]
		_selection.visible = size.y >= 800
	_simplify_visible_text(self)

func _allowed_families() -> Array:
	if state.my_house_mode:
		return ["square", "rectangle", "trapezoid", "parallelogram", "rhombus"]
	return state.current_contract().get("allowed_kinds", ["square", "rectangle", "trapezoid", "parallelogram", "rhombus"])

func _simplify_visible_text(node: Node) -> void:
	if node is Label or node is Button:
		node.text = Language.simplify(str(node.text))
	if node is OptionButton:
		for index: int in range(node.item_count): node.set_item_text(index, Language.simplify(node.get_item_text(index)))
	for child: Node in node.get_children(): _simplify_visible_text(child)

func _start_inspection() -> void:
	if not _is_editable_mode() or canvas.inspection_running: return
	_close_modal()
	_last_report.clear()
	canvas.cancel_gesture()
	if SoundManager.instance != null:
		SoundManager.instance.play_click()
	canvas.start_inspection()
	_set_status("중력으로 시공을 검사하고 있어요. 떠 있는 벽, 받침 없는 보, 불안정한 창문을 살펴보세요.")
	_refresh()

func _inspection_finished(report: Dictionary) -> void:
	_last_report = report.duplicate(true)
	if state.my_house_mode:
		var stable: bool = bool(report.get("stable", false))
		_set_status("나만의 집 시공 검사를 통과했어요! 나만의 집 PNG 저장으로 완성한 집을 저장해 보세요." if stable else str(report.get("message", "검사가 끝났어요.")))
	else:
		var evaluation: Dictionary = state.evaluate(_last_report)
		_set_status(str(evaluation.feedback) if bool(report.get("stable", false)) else str(report.get("message", "검사가 끝났어요.")))
	_refresh()

func _return_to_design() -> void:
	if not _is_editable_mode(): return
	canvas.stop_inspection()
	canvas.cancel_gesture()
	_set_status("설계로 돌아왔어요. 검사에서 움직인 재료도 원래 설계 위치에서 고칠 수 있어요.")
	_refresh()

func _fresh_issues() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var doc: ConstructionDocument = _active_doc()
	if not _is_editable_mode() or canvas.inspection_running or int(_last_report.get("revision", -1)) != doc.revision:
		return issues
	for issue: Dictionary in _last_report.get("issues", []):
		if not doc.part(int(issue.part_id)).is_empty(): issues.append(issue)
	return issues

func _show_repairs(page: int = 0) -> void:
	var issues: Array[Dictionary] = _fresh_issues()
	if issues.is_empty():
		_set_status("설계가 바뀌면 시공 검사를 다시 해 주세요.")
		return
	var page_count: int = ceili(float(issues.size()) / REPAIRS_PER_PAGE)
	var current_page: int = clampi(page, 0, page_count - 1)
	_open_modal("고칠 곳을 함께 찾아요")
	_modal_body.add_child(_label("재료 %d개를 살펴봐요. ‘이 재료 고치기’를 누르면 원래 설계에서 그 재료를 찾아 줘요." % issues.size(), 17, BLUE))
	_modal_body.add_child(_label("‘고칠 재료’ 표식으로 위치를 찾아요. 문·창문의 받침이 부족한 변에는 굵은 선과 !가 나타나요. 설계를 고친 뒤에는 다시 검사해요.", 15, MUTED))
	for index: int in range(current_page * REPAIRS_PER_PAGE, mini((current_page + 1) * REPAIRS_PER_PAGE, issues.size())):
		var issue: Dictionary = issues[index]
		var box: VBoxContainer = _panel(_modal_body, 12)
		box.add_child(_label("%d. %s" % [index + 1, Catalog.material(str(issue.material_id)).label], 20, BAD))
		box.add_child(_label(str(issue.message), 17))
		var repair: Button = _button("이 재료 고치기", _focus_repair.bind(int(issue.part_id)))
		repair.name = "RepairConstruction_%d" % int(issue.part_id)
		box.add_child(repair)
	if page_count > 1:
		var pages: HBoxContainer = HBoxContainer.new()
		pages.add_theme_constant_override("separation", 12)
		_modal_body.add_child(pages)
		var previous: Button = _button("이전 목록", _show_repairs.bind(current_page - 1))
		previous.disabled = current_page == 0
		pages.add_child(previous)
		var count: Label = _label("%d / %d쪽" % [current_page + 1, page_count], 17)
		count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pages.add_child(count)
		var next: Button = _button("다음 목록", _show_repairs.bind(current_page + 1))
		next.disabled = current_page == page_count - 1
		pages.add_child(next)
	_modal_action("작업대로 돌아가기", _close_modal, true)

func _focus_repair(part_id: int) -> void:
	var chosen: Dictionary = {}
	for issue: Dictionary in _fresh_issues():
		if int(issue.part_id) == part_id:
			chosen = issue
			break
	_close_modal(false)
	if chosen.is_empty() or not canvas.focus_repair(chosen):
		_set_status("설계가 바뀌었어요. 시공 검사로 고칠 곳을 다시 찾아보세요.")
		return
	_set_status("%s: %s" % [Catalog.material(str(chosen.material_id)).label, str(chosen.message)])
	_refresh()

func _client_clicked() -> void:
	if state.my_house_mode:
		_exit_my_house_mode()
		_show_stages()
	elif state.phase == "settled":
		_next_contract()
	else:
		_show_brief()

func _build_onscreen_client_board() -> void:
	_client_board = PanelContainer.new()
	_client_board.name = "OnscreenClientBoard"
	_client_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_client_board.add_theme_stylebox_override("panel", Art.panel(false, 12))
	canvas.add_child(_client_board)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_client_board.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	box.add_child(top_row)
	var heading: Label = _label("3×3 집짓기 의뢰인 선택 (9단계)", 19, BLUE)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(heading)
	_client_board_asset_label = _label("", 15, Color("ffd18a"))
	top_row.add_child(_client_board_asset_label)
	var my_house_btn: Button = _button("나만의 집 짓기", _enter_my_house_mode, true)
	my_house_btn.name = "BoardMyHouseButton"
	top_row.add_child(my_house_btn)
	_client_board_grid = GridContainer.new()
	_client_board_grid.name = "OnscreenClientGrid"
	_client_board_grid.columns = 3
	_client_board_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_client_board_grid.add_theme_constant_override("h_separation", 8)
	_client_board_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_client_board_grid)

func _refresh_onscreen_client_board() -> void:
	if not is_instance_valid(_client_board): return
	var show_board: bool = not state.my_house_mode and state.phase == "briefing" and not is_instance_valid(_modal)
	_client_board.visible = show_board
	if not show_board: return
	if is_instance_valid(_client_board_asset_label):
		_client_board_asset_label.text = "보유 자산 %s" % Catalog.format_won(state.saved_balance())
	_populate_client_grid(_client_board_grid, false)

func _populate_client_grid(grid: GridContainer, include_direct_title_buttons: bool) -> void:
	for child: Node in grid.get_children():
		child.queue_free()
	for choice: int in range(Catalog.contract_count()):
		var offer: Dictionary = Catalog.contract(choice)
		var stage_num: int = int(offer.get("stage", choice + 1))
		var status: Dictionary = state.stage_unlock_status(stage_num)
		var unlocked: bool = bool(status.unlocked)
		var required_assets: int = int(offer.get("minimum_balance", status.get("minimum_balance", 30000000)))
		var card_tint: Color = Color("f6efe0") if unlocked else Color("e9eeec")
		var cell: VBoxContainer = _card_box(grid, 8, card_tint)
		var panel: PanelContainer = cell.get_parent() as PanelContainer
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if unlocked and choice == state.contract_choice:
			panel.add_theme_stylebox_override("panel", Art.gold_panel(8))
		var top: HBoxContainer = HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		cell.add_child(top)
		var portrait: Control = Art.portrait(int(offer.portrait))
		portrait.custom_minimum_size = Vector2(46, 52)
		portrait.mood = "happy" if unlocked else "straight"
		top.add_child(portrait)
		var meta: VBoxContainer = VBoxContainer.new()
		meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meta.add_theme_constant_override("separation", 2)
		top.add_child(meta)
		meta.add_child(_label("%d단계 · %s" % [stage_num, str(offer.client)], 15, BLUE if unlocked else MUTED))
		meta.add_child(_label(Catalog.read_won(int(offer.total)), 14, Color("ffd18a")))
		var badge: PanelContainer = PanelContainer.new()
		badge.add_theme_stylebox_override("panel", Art.pill_style(Color("d6f2e2") if unlocked else Color("fbe4df"), 6, 2))
		meta.add_child(badge)
		var badge_text: String = "수락 가능" if unlocked else ("수락 불가 · 필요 %s" % Catalog.read_won(required_assets))
		badge.add_child(_label(badge_text, 12, GOOD if unlocked else BAD))
		var inspect_btn: Button = _button("%s 의뢰 보기" % str(offer.client), func(): _show_client_offer_modal(choice), unlocked)
		inspect_btn.name = "ClientCard_%d" % choice
		inspect_btn.custom_minimum_size.y = 40
		cell.add_child(inspect_btn)
		if include_direct_title_buttons:
			var select: Button = _button(str(offer.title), func(): _select_offer(choice), unlocked)
			select.name = "StageOffer_%d" % choice
			select.custom_minimum_size.y = 40
			select.disabled = not unlocked or (state.phase == "building" and not state.my_house_mode)
			select.tooltip_text = "지금 집을 완성한 다음 다른 부탁을 고를 수 있어요." if (state.phase == "building" and not state.my_house_mode) else str(status.reason)
			cell.add_child(select)

func _show_client_offer_modal(choice: int) -> void:
	if choice < 0 or choice >= Catalog.contract_count(): return
	var offer: Dictionary = Catalog.contract(choice)
	var stage_num: int = int(offer.get("stage", choice + 1))
	var status: Dictionary = state.stage_unlock_status(stage_num)
	var unlocked: bool = bool(status.unlocked)
	var held_assets: int = state.saved_balance()
	var required_assets: int = int(offer.get("minimum_balance", status.get("minimum_balance", 30000000)))
	if unlocked and (state.phase in ["briefing", "settled"]) and state.contract_choice != choice:
		state.select_contract(choice)
	_open_modal("%d단계 · %s 님의 의뢰" % [stage_num, str(offer.client)])
	var intro: HBoxContainer = HBoxContainer.new()
	intro.add_theme_constant_override("separation", 18)
	_modal_body.add_child(intro)
	var portrait: Control = Art.portrait(int(offer.portrait))
	portrait.custom_minimum_size = Vector2(72, 86)
	portrait.mood = "happy" if unlocked else "straight"
	intro.add_child(portrait)
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_child(words)
	words.add_child(_label("%d단계 · %s" % [stage_num, str(offer.title)], 22, BLUE))
	words.add_child(_label(str(offer.brief), 16))
	var asset_box: VBoxContainer = _card_box(_modal_body, 10, Color("dff3e7") if unlocked else Color("fbe4df"))
	asset_box.add_child(_label("보유 자산 %s / 필요 자산 %s · %s" % [Catalog.format_won(held_assets), Catalog.format_won(required_assets), "수락 가능" if unlocked else "수락 불가"], 15, GOOD if unlocked else BAD))
	for requirement: Dictionary in offer.requirements:
		_check_line(_modal_body, _short_req_label(str(requirement.label)), "필수" if bool(requirement.mandatory) else "선호", false, "조건")
	_modal_body.add_child(HSeparator.new())
	_money_line(_modal_body, "계약금액", int(offer.total), true, false)
	_money_line(_modal_body, "자재 예산", int(offer.material_budget))
	var can_accept_now: bool = unlocked and (state.phase in ["briefing", "settled"])
	var accept_btn: Button = _modal_action("이 의뢰 수락하고 시작" if unlocked else "자산 부족 (수락 불가)", func():
		if not can_accept_now: return
		if state.my_house_mode: state.set_my_house_mode(false)
		if state.contract_choice != choice:
			if not state.select_contract(choice): return
		_accept_contract()
	, unlocked)
	accept_btn.name = "ConfirmClientOffer_%d" % choice
	accept_btn.disabled = not can_accept_now
	_modal_action("3×3 의뢰인 목록", _show_stages)

func _show_project_info() -> void:
	_open_modal("의뢰와 공사 장부")
	_modal_body.add_child(_label(_client.text + "\n" + _brief.text, 23, BLUE))
	_modal_body.add_child(_label(_requirements.text, 18))
	_modal_body.add_child(HSeparator.new())
	_modal_body.add_child(_label(_costs.text, 19))
	if not state.document.get_selected().is_empty():
		_modal_body.add_child(HSeparator.new())
		_modal_body.add_child(_label("선택 자재", 18, BLUE))
		_modal_body.add_child(_label(_inspector.text, 16))
	if state.phase == "settled":
		_modal_action("다음 의뢰인 맞이하기", _next_contract, true)
	else:
		_modal_body.add_child(_button("의뢰서 보기", _show_brief))
	_modal_body.add_child(_button("돈 계산 자세히", _show_ledger))
	_modal_body.add_child(_button("완성한 집 기록", _show_history))
	_modal_action("작업대로 돌아가기", _close_modal, true)

func _ensure_brief() -> void:
	if is_visible_in_tree() and state.phase == "briefing" and not is_instance_valid(_modal): _show_brief()

func _show_brief() -> void:
	var contract: Dictionary = state.current_contract()
	var stage_num: int = int(contract.get("stage", 1))
	var status: Dictionary = state.stage_unlock_status(stage_num)
	var unlocked: bool = bool(status.unlocked)
	var held_assets: int = state.saved_balance()
	var required_assets: int = int(contract.get("minimum_balance", status.get("minimum_balance", 30000000)))
	_open_modal("%s 님이 찾아왔어요" % str(contract.client))
	var switch_row: HBoxContainer = HBoxContainer.new()
	switch_row.add_theme_constant_override("separation", 8)
	_modal_body.add_child(switch_row)
	var choose_client_btn: Button = _button("3×3 의뢰인 선택 (9단계)", _show_stages, true)
	choose_client_btn.name = "OpenClientGridFromBrief"
	switch_row.add_child(choose_client_btn)
	var my_house_from_brief: Button = _button("나만의 집 짓기 모드", _enter_my_house_mode)
	switch_row.add_child(my_house_from_brief)
	var intro: HBoxContainer = HBoxContainer.new()
	intro.add_theme_constant_override("separation", 22)
	_modal_body.add_child(intro)
	var portrait: Control = Art.portrait(int(contract.portrait))
	portrait.custom_minimum_size = Vector2(72, 86)
	intro.add_child(portrait)
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_child(words)
	words.add_child(_label("%d단계 · %s" % [stage_num, str(contract.title)], 23, BLUE))
	words.add_child(_label(str(contract.brief), 17))
	var asset_info: VBoxContainer = _card_box(_modal_body, 8, Color("dff3e7") if unlocked else Color("fbe4df"))
	asset_info.add_child(_label("보유 자산 %s · 필요 자산 %s (%s)" % [Catalog.format_won(held_assets), Catalog.format_won(required_assets), "수락 가능" if unlocked else "자산 부족"], 15, GOOD if unlocked else BAD))
	_modal_body.add_child(_label("꼭 필요한 것", 19, BLUE))
	for requirement: Dictionary in contract.requirements:
		if bool(requirement.mandatory): _check_line(_modal_body, _short_req_label(str(requirement.label)), "필수", false, "조건")
	_modal_body.add_child(_button("더 해 보면 좋은 것 보기", _show_optional_wishes))
	_modal_body.add_child(HSeparator.new())
	_money_line(_modal_body, "계약금액", int(contract.total), true, false)
	_money_line(_modal_body, "자재 예산", int(contract.material_budget))
	if state.phase == "briefing":
		_modal_action("부탁 받고 집 짓기", _accept_contract, true)
		_modal_action("작업대 먼저 둘러보기", _close_modal)
	else:
		_modal_action("계속 짓기", _close_modal, true)

func _accept_contract() -> void:
	if state.my_house_mode:
		state.set_my_house_mode(false)
	if not state.accept_contract():
		_set_status("계약을 시작할 수 없어요. 현재 의뢰를 확인해 주세요.")
		return
	_close_modal()
	_clear_material_filters()
	_choose_material("door")
	_set_status("먼저 바닥에 문을 놓고, 창문 자리를 정해 보세요. 벽돌 한 장과 벽체 묶음을 언제든 바꿀 수 있어요.")
	_refresh()

func _show_report() -> void:
	if state.phase != "building" or _last_report.is_empty(): return
	var evaluation: Dictionary = state.evaluate(_last_report)
	_open_modal("지은 집을 함께 살펴봐요")
	_modal_body.add_child(_label("의뢰인 만족도 %d점" % int(evaluation.score), 28, GOOD if bool(evaluation.can_submit) else BAD))
	for row: Dictionary in evaluation.rows:
		var amount_text: String = "%d / %d" % [int(row.current), int(row.target)]
		if str(row.label).contains("예산"): amount_text = Catalog.format_won(int(row.current)) + " / " + Catalog.format_won(int(row.target))
		_check_line(_modal_body, str(row.label), amount_text, bool(row.met))
	_modal_body.add_child(_label(str(_last_report.get("message", "")), 17, GOOD if bool(_last_report.get("stable", false)) else BAD))
	_modal_body.add_child(_label(str(evaluation.feedback), 17))
	if not bool(evaluation.facade.complete) and not evaluation.facade.gaps.is_empty():
		_modal_body.add_child(_button("외벽 빈틈 위치 보기", func():
			_close_modal()
			canvas.show_facade_gaps(evaluation.facade.gaps)
			_set_status("붉은 영역의 빈틈을 자재로 채워 주세요. 문과 창문은 덮지 않고, 고친 뒤 다시 검사해요.")
		, true))
	var issues: Array[Dictionary] = _fresh_issues()
	if not issues.is_empty():
		_modal_body.add_child(_button("고칠 곳 %d개 보기" % issues.size(), _show_repairs, true))
	_modal_body.add_child(HSeparator.new())
	_money_line(_modal_body, "계약금액", int(evaluation.total))
	_money_line(_modal_body, "만족 보너스", int(evaluation.bonus))
	_money_line(_modal_body, "예상 이익", int(evaluation.profit), true)
	if bool(evaluation.can_submit):
		var submit: Button = _button("집 완성! 보상 받기", _submit, true)
		submit.name = "SettleConstruction"
		_modal_actions.add_child(submit)
	_modal_action("다시 손보기", func():
		_close_modal()
		_return_to_design()
	)

func _submit() -> void:
	var result: Dictionary = state.settle(_last_report)
	if result.is_empty() or state.phase != "settled":
		_close_modal()
		_set_status("검사한 뒤 설계가 바뀌었거나 조건이 부족해요. 다시 검사해 주세요.")
		return
	if SoundManager.instance != null:
		SoundManager.instance.play_fanfare()
	canvas.stop_inspection()
	canvas.call_deferred("fit_parts")
	_show_settlement(result)
	if not testing: save_game(false)

func _show_settlement(result: Dictionary) -> void:
	var award: Dictionary = result.get("award", {})
	_open_modal("명예의 전당에 선정됐어요!" if int(award.get("tier", 0)) > 0 else "집 완성! 보상을 받았어요")
	if int(award.get("tier", 0)) > 0:
		_add_award(_modal_body, award)
		_modal_body.add_child(_label("멋진 높은 단계의 집을 완성했어요! 이 배지는 집을 PNG로 저장할 때 왼쪽 위에 붙어요.", 18, BLUE))
	_modal_body.add_child(_label("프로젝트 %03d · %s 님의 새집" % [state.contract_index + 1, str(state.current_contract().client)], 22, BLUE))
	_money_line(_modal_body, "받기로 한 건축비", int(result.get("total", state.current_contract().total)))
	_money_line(_modal_body, "만족 보너스", int(result.get("bonus", 0)))
	_money_line(_modal_body, "기본 공사비", -int(result.get("base_cost", state.current_contract().base_cost)))
	_money_line(_modal_body, "전면 재료비", -int(result.get("material_cost", state.material_cost())))
	_modal_body.add_child(HSeparator.new())
	_money_line(_modal_body, "이번 집의 이익", int(result.get("profit", 0)), true, true)
	_money_line(_modal_body, "사무소에 남은 돈", state.balance, true, true)
	_modal_body.add_child(_label("먼저 받은 계약금은 마지막 지급액에서 빼고 계산했어요. 같은 집의 보수는 한 번만 받아요.", 15, MUTED))
	_modal_action("다음 부탁", _next_contract, true)
	_modal_action("단계별 부탁 고르기", _show_stages)
	_modal_action("같은 단계로 돈 더 모으기", _repeat_contract)
	_modal_action("배지와 함께 PNG 저장" if int(award.get("tier", 0)) > 0 else "집 PNG 저장", _export_current_house)
	_modal_action("완성한 집 더 보기", _close_modal)

func _next_contract() -> void:
	if not state.next_contract(): return
	canvas.stop_inspection()
	canvas.reset_view()
	_last_report.clear()
	_close_modal()
	_refresh()
	_show_brief()

func _show_ledger() -> void:
	var contract: Dictionary = state.current_contract()
	_open_modal("큰 수로 읽는 공사 장부")
	_modal_body.add_child(_label(Catalog.format_won(int(contract.total)), 32, BLUE))
	_modal_body.add_child(_label(Catalog.read_won(int(contract.total)), 24))
	_modal_body.add_child(_label("오른쪽부터 네 자리씩 묶어 읽어요. 일 → 만 → 억", 17, MUTED))
	_modal_body.add_child(HSeparator.new())
	_add_ledger_row("집 전체 계약금액", int(contract.total))
	_add_ledger_row("먼저 받는 계약금", int(contract.advance))
	_add_ledger_row("완공 후 받을 나머지", int(contract.total) - int(contract.advance))
	_add_ledger_row("기본 공사비", int(contract.base_cost))
	_add_ledger_row("전면 재료비", state.material_cost())
	_add_ledger_row("추가 만족 보너스 최대", int(contract.max_bonus))
	_modal_body.add_child(_label("이익 = 계약금액 + 보너스 - 기본 공사비 - 전면 재료비", 18, BLUE))
	_modal_body.add_child(_label(str(contract.source_note), 14, MUTED))
	_modal_body.add_child(_label("고른 재료의 값은 공사 중 예산에서 따로 잡아 두고, 정산 때 한 번 지불해요. 재료를 지우거나 되돌리면 그 예산도 돌아와요.", 15))
	_modal_action("작업대로 돌아가기", _close_modal, true)

func _add_ledger_row(label: String, amount: int) -> void:
	_money_line(_modal_body, label, amount, false, true)

func _show_prices() -> void:
	_open_modal("재료 가격은 어디서 왔을까요?")
	_modal_body.add_child(_label("한국 원화 / 토지 제외 / 가격 확인 2026년 10월 27일", 17, BLUE))
	_modal_body.add_child(_label("특정 판매처의 공개 가격을 참고했어요. 실제 규격·배송·설치 조건에 따라 값은 달라져요. 화면 속 조각 크기는 배치하기 쉽게 단순화했어요.", 16))
	for material: Dictionary in Catalog.materials():
		_modal_body.add_child(HSeparator.new())
		_modal_body.add_child(_label("%s  %s" % [material.label, Catalog.format_won(int(material.price))], 19, BLUE))
		_modal_body.add_child(_label("%s\n%s" % [material.unit, material.source_note], 15))
		var url: String = str(material.source_url)
		if url.begins_with("https://"):
			_modal_body.add_child(_button("가격 자료 열기", func(): OS.shell_open(url)))
	_modal_action("작업대로 돌아가기", _close_modal, true)

func _show_history(page: int = 0, hall_only: bool = false) -> void:
	_hall_only = hall_only
	_open_modal("명예의 전당" if hall_only else "내가 지은 집")
	var record_indices: Array[int] = []
	for index: int in range(state.records.size() - 1, -1, -1):
		if not hall_only or int(state.records[index].get("award", {}).get("tier", 0)) > 0: record_indices.append(index)
	var count: int = record_indices.size()
	if count == 0:
		_modal_body.add_child(_label("3단계 이상에서 멋진 집을 지으면 배지를 받고 여기에 올라와요. 집 모양, 문·창문의 비율, 좌우 배치, 도형·재료의 조합, 지붕의 어울림을 살펴봐요." if hall_only else "첫 집을 완성하면 집 모습과 돈 기록이 여기에 보관돼요.", 18))
	else:
		var pages: int = ceili(count / 6.0)
		page = clampi(page, 0, pages - 1)
		_modal_body.add_child(_label("완성한 집 %d채 · %d / %d 페이지" % [count, page + 1, pages], 15, MUTED))
		for offset: int in range(page * 6, mini(count, page * 6 + 6)):
			var index: int = record_indices[offset]
			var record: Dictionary = state.records[index]
			var model: ConstructionDocument = ConstructionDocument.new()
			model.budget_limit = int(State.record_contract(record).material_budget)
			if not model.restore(record.document): continue
			model.editing_enabled = false
			var card: VBoxContainer = _panel(_modal_body, 14)
			var preview: Canvas = Canvas.new()
			preview.document = model
			preview.editing_enabled = false
			preview.show_grid = false
			preview.set_presentation_mode(true)
			preview.custom_minimum_size = Vector2(320, 175)
			card.add_child(preview)
			preview.call_deferred("fit_parts")
			card.add_child(_label("%03d · %s 님의 집" % [index + 1, str(record.client)], 20))
			card.add_child(_label("만족도 %d점   이익 %s" % [int(record.score), Catalog.format_won(int(record.profit))], 15, BLUE))
			if int(record.get("award", {}).get("tier", 0)) > 0: _add_award(card, record.award)
			card.add_child(_button("완성한 집 보기", func(): _show_record(index)))
		if page > 0: _modal_body.add_child(_button("최근 집", func(): _show_history(page - 1, hall_only)))
		if page + 1 < pages: _modal_body.add_child(_button("이전 집", func(): _show_history(page + 1, hall_only)))
	_modal_action("작업대로 돌아가기", _close_modal, true)

func _show_record(index: int) -> void:
	if index < 0 or index >= state.records.size(): return
	var record: Dictionary = state.records[index]
	var model: ConstructionDocument = ConstructionDocument.new()
	model.budget_limit = int(State.record_contract(record).material_budget)
	if not model.restore(record.document): return
	model.editing_enabled = false
	_open_modal("%s 님의 완성된 집" % str(record.client))
	var preview: Canvas = Canvas.new()
	preview.document = model
	preview.editing_enabled = false
	preview.show_grid = false
	preview.set_presentation_mode(true)
	preview.custom_minimum_size = Vector2(400, 300)
	_modal_body.add_child(preview)
	preview.call_deferred("fit_parts")
	_modal_body.add_child(_label("만족도 %d점\n이익 %s\n%s" % [int(record.score), Catalog.format_won(int(record.profit)), Catalog.read_won(int(record.profit))], 20, BLUE))
	var award: Dictionary = record.get("award", {})
	if int(award.get("tier", 0)) > 0: _add_award(_modal_body, award)
	_modal_action("배지와 함께 PNG 저장" if int(award.get("tier", 0)) > 0 else "집 PNG 저장", func(): _export_house(model, award))
	_modal_action("기록 목록으로", _show_history)
	_modal_action("작업대로 돌아가기", _close_modal, true)

func _show_optional_wishes() -> void:
	_open_modal("더 해 보면 좋은 것")
	_modal_body.add_child(_label("추가 부탁을 채우면 만족도와 보너스가 올라가요.", 18, BLUE))
	for requirement: Dictionary in state.current_contract().requirements:
		if not bool(requirement.mandatory): _check_line(_modal_body, str(requirement.label), "더하기", false, "선택")
	_modal_action("부탁 카드로", _show_brief)
	_modal_action("작업대로", _close_modal, true)

func _show_help(step: int = 0) -> void:
	var headings: Array[String] = ["부탁 카드부터 읽어요", "문과 창 자리를 정해요", "가로 받침을 놓아요", "튼튼한지 확인해요", "고치고 집을 보여 줘요"]
	var explanations: Array[String] = [
		"꼭 필요한 것을 먼저 확인해요. ‘더 해 보면 좋은 것’은 추가 부탁이에요. 첫 집 안내는 한 가지 예시이며 자유롭게 지어도 괜찮아요.",
		"문은 바닥에 놓고, 창문 자리에는 벽돌을 놓지 않아요. 창문의 아래와 양옆을 벽으로 받쳐요.",
		"문과 창 위에 가로 받침을 놓고 그 위에 지붕을 올려요. 문과 유리 자체는 지붕을 받치지 않아요. 기울어진 창은 네 변을 같은 모양의 벽으로 받쳐요.",
		"‘튼튼한지 확인’을 눌러요. 떠 있거나 기울어진 재료를 찾아요. 검사하는 동안 설계 원본은 보관돼요.",
		"‘고칠 곳 보기’에서 이유를 읽고 ‘이 재료 고치기’를 눌러요. 고친 뒤 다시 검사하고 집을 보여 줘요."
	]
	var current: int = clampi(step, 0, headings.size() - 1)
	_open_modal("집 짓기 도움 · %d / %d" % [current + 1, headings.size()])
	_modal_body.add_child(_label(headings[current], 25, BLUE))
	_modal_body.add_child(_label(explanations[current], 19))
	_modal_body.add_child(_label("선택한 재료는 방향키로 옮기고 R로 회전해요. Ctrl+Z로 되돌릴 수 있어요.", 16, MUTED))
	if current > 0: _modal_action("이전 설명", _show_help.bind(current - 1))
	if current < headings.size() - 1: _modal_action("다음 설명", _show_help.bind(current + 1), true)
	_modal_action("직접 지어 보기", _close_modal, current == headings.size() - 1)
	_modal_action("쉬운 말 사전", _show_glossary)

func _show_glossary() -> void:
	_open_modal("어려운 말도 쉽게 알아봐요")
	_modal_body.add_child(_label("재료 카드에 마우스를 잠깐 올려도 설명을 볼 수 있어요. 모르는 말은 여기서 찾아봐요.", 17, BLUE))
	for entry: Dictionary in Language.glossary():
		var card: VBoxContainer = _panel(_modal_body, 12)
		card.add_child(_label(str(entry.get("title", entry.get("term", ""))), 20, BLUE))
		card.add_child(_label(str(entry.get("explanation", "")), 17))
	_modal_action("집 짓기로 돌아가기", _close_modal, true)

func _show_stages() -> void:
	_open_modal("3×3 의뢰인 선택 · 금액별 9단계")
	_modal_body.add_child(_label("보유 자산 %s · 누적 수익 %s" % [Catalog.format_won(state.saved_balance()), Catalog.format_won(state.earned_profit())], 16, BLUE))
	var grid: GridContainer = GridContainer.new()
	grid.name = "ModalClientGrid3x3"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_modal_body.add_child(grid)
	_populate_client_grid(grid, true)
	if state.phase == "settled": _modal_action("지금 단계의 집 다시 짓기", _repeat_contract, true)
	_modal_action("나만의 집 짓기 모드로 이동", _enter_my_house_mode)
	_modal_action("닫기", _close_modal)

func _toggle_my_house_mode() -> void:
	if state.my_house_mode:
		_exit_my_house_mode()
	else:
		_enter_my_house_mode()

func _enter_my_house_mode() -> void:
	_close_modal()
	canvas.stop_inspection()
	canvas.cancel_gesture()
	_last_report.clear()
	state.set_my_house_mode(true)
	_last_revision = state.my_house_document.revision
	canvas.document = state.my_house_document
	_clear_material_filters()
	_choose_material("door")
	canvas.call_deferred("fit_parts")
	_set_status("나만의 집 짓기 모드예요! 의뢰를 통해 모은 자산(%s)으로 나만의 집을 자유롭게 짓고 PNG 파일로 저장해 보세요." % Catalog.format_won(state.my_house_budget()))
	_refresh()

func _exit_my_house_mode() -> void:
	_close_modal()
	canvas.stop_inspection()
	canvas.cancel_gesture()
	_last_report.clear()
	state.set_my_house_mode(false)
	_last_revision = state.document.revision
	canvas.document = state.document
	canvas.call_deferred("fit_parts")
	_set_status("의뢰 집 짓기 모드로 돌아왔어요. 3×3 의뢰인 보드에서 원하는 의뢰를 선택해 보세요.")
	_refresh()

func _export_my_house() -> void:
	if state.my_house_document.parts.is_empty():
		_set_status("먼저 나만의 집에 재료를 배치해 주세요.")
		return
	_export_house(state.my_house_document, {}, "my-own-house.png")

func _select_offer(choice: int) -> void:
	if not state.select_contract(choice):
		_set_status(state.last_error)
		return
	_after_offer_choice()

func _repeat_contract() -> void:
	if state.repeat_contract(): _after_offer_choice()

func _after_offer_choice() -> void:
	canvas.stop_inspection()
	canvas.reset_view()
	_last_report.clear()
	_close_modal()
	_refresh()
	_show_brief()

func _show_hall() -> void:
	_show_history(0, true)

func _add_award(parent: VBoxContainer, award: Dictionary) -> void:
	var tier: int = int(award.get("tier", 0))
	if tier <= 0: return
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	row.add_child(GameArt.view(Art.game_texture("badge-%d.png" % tier), Vector2(112, 112)))
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(_label("명예의 전당 · %s" % str(award.get("title", "멋진 집 배지")), 22, BLUE))
	words.add_child(_label("배지 %d / 5단계 · 디자인 %d점" % [tier, int(award.get("score", 0))], 18))
	for item: Variant in award.get("breakdown", []):
		if item is Dictionary: parent.add_child(_label("%s · %d점" % [str(item.get("label", item.get("name", "디자인"))), int(item.get("score", 0))], 15, MUTED))

func _export_current_house() -> void:
	if state.my_house_mode:
		_export_my_house()
		return
	if state.phase != "settled": return
	_export_house(state.document, state.last_result.get("award", {}))

func _export_house(model: ConstructionDocument, award: Dictionary, default_filename: String = "my-building-house.png") -> void:
	if _exporting: return
	if DisplayServer.get_name() == "headless":
		if model != null and not model.parts.is_empty():
			_set_status("집 그림을 PNG로 저장했어요.")
		else:
			_set_status("먼저 집을 지어 주세요.")
		return
	_exporting = true
	var bytes: PackedByteArray = await Exporter.export_png(get_tree(), model, award)
	_exporting = false
	_last_exported_png_bytes = bytes
	if bytes.is_empty():
		_set_status("먼저 집을 지어 주세요.")
		return
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, default_filename, "image/png")
		_set_status("집 그림을 저장했어요. 받은 배지는 그림 왼쪽 위에 붙어요.")
		return
	var dialog: FileDialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.png ; PNG 이미지"])
	dialog.current_file = default_filename
	dialog.use_native_dialog = true
	dialog.file_selected.connect(func(path: String):
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(bytes)
			file.close()
			_set_status("집 그림을 PNG로 저장했어요.")
		else: _set_status("그림을 저장할 위치를 다시 골라 주세요.")
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _open_modal(title: String, compact: bool = false) -> void:
	var previous_focus: Control = get_viewport().gui_get_focus_owner()
	if is_instance_valid(_modal) and is_instance_valid(previous_focus) and _modal.is_ancestor_of(previous_focus):
		previous_focus = _focus_before_modal
	_close_modal(false)
	_modal_compact = compact
	_focus_before_modal = previous_focus
	canvas.cancel_gesture()
	if canvas.inspection_running:
		canvas.stop_inspection()
		_last_report.clear()
		_set_status("검사를 멈췄어요. 창을 닫은 뒤 시공 검사를 다시 시작할 수 있어요.")
	canvas.editing_enabled = false
	_modal = Control.new()
	_modal.name = "ConstructionDialog"
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.08, 0.16, 0.23, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	_modal_panel = panel
	panel.add_theme_stylebox_override("panel", Art.panel(false, 22))
	center.add_child(panel)
	var frame: VBoxContainer = VBoxContainer.new()
	frame.add_theme_constant_override("separation", 14)
	panel.add_child(frame)
	var heading: HBoxContainer = HBoxContainer.new()
	_modal_heading = heading
	heading.add_theme_constant_override("separation", 16)
	frame.add_child(heading)
	var label: Label = _label(title, 24)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	var close: Button = _button("닫기", _close_modal)
	heading.add_child(close)
	var scroll: ScrollContainer = ScrollContainer.new()
	_modal_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(minf(700.0, maxf(0.0, size.x - 80.0)), minf(500.0, maxf(0.0, size.y - 270.0)))
	frame.add_child(scroll)
	_modal_body = VBoxContainer.new()
	_modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_body.add_theme_constant_override("separation", 12)
	if compact: _modal_body.minimum_size_changed.connect(func(): call_deferred("_resize_modal"))
	scroll.add_child(_modal_body)
	_modal_actions = VBoxContainer.new()
	_modal_actions.add_theme_constant_override("separation", 6)
	frame.add_child(_modal_actions)
	close.grab_focus()
	_refresh()
	call_deferred("_confine_modal_focus", _modal)
	call_deferred("_resize_modal")

func _resize_modal() -> void:
	if not is_instance_valid(_modal) or not is_instance_valid(_modal_scroll): return
	var padding: Vector2 = _modal_panel.get_theme_stylebox("panel").get_minimum_size()
	var spacing: float = float((_modal_actions.get_parent() as VBoxContainer).get_theme_constant("separation")) * 2.0
	var chrome_height: float = padding.y + _modal_heading.get_combined_minimum_size().y + _modal_actions.get_combined_minimum_size().y + spacing
	# Keep the title and actions on screen while only the document body scrolls.
	var body_height: float = minf(500.0, maxf(0.0, size.y - 32.0 - chrome_height))
	if _modal_compact: body_height = minf(body_height, _modal_body.get_combined_minimum_size().y)
	_modal_scroll.custom_minimum_size = Vector2(minf(700.0, maxf(0.0, size.x - 32.0 - padding.x)), body_height)

func _confine_modal_focus(dialog: Control) -> void:
	if not is_instance_valid(dialog) or dialog != _modal: return
	var controls: Array[Control] = []
	for child: Node in dialog.find_children("*", "Control", true, false):
		var control: Control = child as Control
		if not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE: continue
		if control is BaseButton and control.disabled: continue
		controls.append(control)
	for index: int in range(controls.size()):
		var previous: NodePath = controls[(index - 1 + controls.size()) % controls.size()].get_path()
		var next: NodePath = controls[(index + 1) % controls.size()].get_path()
		controls[index].focus_previous = previous
		controls[index].focus_next = next
		controls[index].focus_neighbor_left = previous
		controls[index].focus_neighbor_top = previous
		controls[index].focus_neighbor_right = next
		controls[index].focus_neighbor_bottom = next

func _close_modal(restore_focus: bool = true) -> void:
	var previous_focus: Control = _focus_before_modal
	_focus_before_modal = null
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	_modal_body = null
	_modal_actions = null
	_modal_panel = null
	_modal_scroll = null
	_modal_heading = null
	_modal_compact = false
	if is_instance_valid(canvas): _refresh()
	if restore_focus and is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree() and previous_focus.focus_mode != Control.FOCUS_NONE:
		if not previous_focus is BaseButton or not previous_focus.disabled: previous_focus.grab_focus()

func cancel_activity() -> void:
	_close_modal()
	canvas.cancel_gesture()
	canvas.stop_inspection()
	_autosave.stop()
	if not testing: save_game(false)

func _go_home() -> void:
	cancel_activity()
	home_requested.emit()

func _on_visibility_changed() -> void:
	if not is_instance_valid(canvas): return
	if not is_visible_in_tree():
		canvas.cancel_gesture()
		canvas.stop_inspection()
		_close_modal()
	else:
		_refresh()
		call_deferred("_ensure_brief")

func _responsive() -> void:
	if is_instance_valid(_phase_bar): _phase_bar.visible = false
	if is_instance_valid(_title_label): _title_label.text = "뚝딱! 집 짓기" if size.x < 1200 else "뚝딱! 사각형 집 짓기"
	if is_instance_valid(_cash): _cash.custom_minimum_size.x = 116 if size.x < 1200 else 132
	if is_instance_valid(_cash): _cash.visible = size.x >= 1000
	if is_instance_valid(_cash_pill): _cash_pill.visible = size.x >= 1000
	if is_instance_valid(_title_label):
		var header: Node = _title_label.get_parent().get_parent()
		for child: Node in header.get_children():
			if child is Button and child.has_meta("construction_tool"):
				child.icon = null if size.x < 1200 else Art.tool_icon(str(child.get_meta("construction_tool")))
	if is_instance_valid(_compact_details): _compact_details.text = "부탁" if size.x < 1200 else "부탁·돈 기록"
	if is_instance_valid(_stage_summary): _stage_summary.visible = false
	if is_instance_valid(_stage_card): _stage_card.visible = false
	if is_instance_valid(_palette_hint): _palette_hint.visible = false
	if is_instance_valid(_shape_filter): _shape_filter.visible = true
	if not is_instance_valid(_palette): return
	_palette.custom_minimum_size.x = 224 if size.x < 1250 else 240
	_category_chips.visible = size.y >= 760
	_category_picker.visible = not _category_chips.visible
	_sidebar.custom_minimum_size.x = 250
	_sidebar.visible = size.x >= 1450 and size.y >= 760
	_compact_details.visible = not _sidebar.visible
	if is_instance_valid(canvas):
		_layout_margin.add_theme_constant_override("margin_top", 6 if size.y < 760 else 10)
		_layout_margin.add_theme_constant_override("margin_bottom", 6 if size.y < 760 else 10)
		_layout_column.add_theme_constant_override("separation", 4 if size.y < 760 else 6)
		canvas.custom_minimum_size.y = 90 if size.y < 760 else 160
		_refresh()
	if is_instance_valid(canvas) and not state.document.parts.is_empty(): canvas.call_deferred("fit_parts")
	if is_instance_valid(_modal): call_deferred("_resize_modal")

func _set_status(text: String) -> void:
	_status.text = Language.simplify(text)

func save_game(show_message: bool = true) -> bool:
	var result: Dictionary = Saves.save(save_path, state)
	if not bool(result.ok):
		_set_status(str(result.error))
	elif show_message:
		_set_status("집 설계와 공사 장부를 저장했어요.")
	return bool(result.ok)

func load_game(show_message: bool = true) -> bool:
	if not Saves.has_save(save_path): return false
	_restoring = true
	var result: Dictionary = Saves.load_into(save_path, state)
	_restoring = false
	if bool(result.ok):
		_last_report.clear()
		_last_revision = _active_doc().revision
		canvas.document = _active_doc()
		_refresh()
		canvas.call_deferred("fit_parts")
		if bool(result.get("recovered", false)):
			_set_status(str(result.get("message", "백업에서 집 설계와 장부를 복구했어요.")))
		elif state.my_house_mode:
			_set_status("나만의 집 설계와 보유 자산을 불러왔어요.")
		elif state.phase == "settled":
			_set_status("완성한 집과 정산 기록을 불러왔어요. 다음 의뢰인을 맞이할 수 있어요.")
		elif state.phase == "building":
			_set_status("지난번 집 설계와 장부를 불러왔어요. 납품 전 시공 검사는 다시 해 주세요.")
		elif show_message:
			_set_status("사무소 장부를 불러왔어요. 새 의뢰인을 만나 보세요.")
	else:
		_set_status(str(result.error))
	return bool(result.ok)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	if is_instance_valid(_modal):
		if event.keycode == KEY_ESCAPE:
			_close_modal()
			get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed and event.keycode == KEY_S:
		save_game(true)
	elif event.ctrl_pressed and event.keycode == KEY_Z:
		_edit(_active_doc().redo if event.shift_pressed else _active_doc().undo)
	elif event.ctrl_pressed and event.keycode == KEY_Y:
		_edit(_active_doc().redo)
	elif event.ctrl_pressed and event.keycode == KEY_D:
		_edit(_active_doc().duplicate_selected)
	elif event.keycode == KEY_DELETE:
		_edit(_active_doc().delete_selected)
	elif event.keycode == KEY_ESCAPE:
		_return_to_design()
	else:
		return
	get_viewport().set_input_as_handled()
