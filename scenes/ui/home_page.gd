class_name HomePage
extends Control

signal drawing_requested
signal adventure_requested
signal construction_requested
signal wall_requested
signal exhibition_board_requested(buildings: bool)
signal notebook_requested
signal tutorials_requested
signal opening_requested
signal ending_choice_requested

const Art = preload("res://scripts/construction_art.gd")
const MENU_ART: String = "res://assets/generated/home-atlas/"
const ENDING_CHOICE_TITLE: String = "최후의 선택"

var _cards: GridContainer
var _hero: Control
var _hero_copy: VBoxContainer
var _hero_picture: TextureRect
var _heading: Label
var _hero_description: Label
var _margin: MarginContainer
var _column: VBoxContainer
var _section: BoxContainer
var _footer: HFlowContainer
var _drawing_button: Button
var _exhibition_button: Button
var _exhibition_chooser: ColorRect
var _exhibit_drawing: Button
var _ending_card: PanelContainer
var _ending_progress: Label
var _ending_choice: Button
var _card_layouts: Array[BoxContainer] = []
var _previews: Array[TextureRect] = []
var _display_font: FontVariation = FontVariation.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_display_font.base_font = QuadTheme.FONT
	_display_font.variation_embolden = 0.7
	var paper: ColorRect = ColorRect.new()
	paper.color = Color("112332")
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "HomeScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	_margin = MarginContainer.new()
	_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_margin)
	_column = VBoxContainer.new()
	_margin.add_child(_column)
	_build_hero()
	_section = BoxContainer.new()
	_section.add_theme_constant_override("separation", 8)
	_column.add_child(_section)
	var activities: Label = _title("어디로 갈까요?", 25)
	activities.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section.add_child(activities)
	_ending_progress = QuadTheme.label("", 16, Color("a4e4d8"))
	_ending_progress.autowrap_mode = TextServer.AUTOWRAP_OFF
	_section.add_child(_ending_progress)
	_cards = GridContainer.new()
	_cards.name = "ActivityChoices"
	_cards.add_theme_constant_override("h_separation", 16)
	_cards.add_theme_constant_override("v_separation", 12)
	_column.add_child(_cards)
	_drawing_button = _build_mode("Drawing", "그림 작업실", "사각형으로 의뢰인의 그림을 완성해요.", _menu_texture("drawing"), "그림 그리기", func(): drawing_requested.emit())
	_build_mode("Construction", "건축 공방", "재료를 골라 의뢰인이 꿈꾸는 집을 지어요.", _menu_texture("building"), "집 짓기", func(): construction_requested.emit())
	_build_mode("Wall", "타일 공방", "사각형으로 만든 타일을 반복해 담장 의뢰를 완성해요.", preload("res://assets/generated/home-atlas/wall.svg"), "담장 꾸미기", func(): wall_requested.emit())
	_build_mode("Adventure", "사각형 마을", "여섯 지역을 탐험하며 주민의 부탁을 들어줘요.", _menu_texture("village"), "마을 주민 심부름하기", func(): adventure_requested.emit())
	_exhibition_button = _build_mode("Exhibition", "작품 전시장", "친구들이 만든 그림과 건축물을 패들릿에서 구경해요.", _menu_texture("arrival"), "전시장 보기", _open_exhibition_chooser)
	_ending_choice = _build_mode("Ending", "사각이의 내일", "지구에 살 집과 사각성으로 갈 우주선 중 하나를 골라요.", _menu_texture("choice"), ENDING_CHOICE_TITLE, func(): ending_choice_requested.emit())
	_ending_card.hide()
	_ending_choice.focus_mode = Control.FOCUS_NONE
	_footer = HFlowContainer.new()
	_footer.add_theme_constant_override("h_separation", 10)
	_footer.add_theme_constant_override("v_separation", 8)
	_column.add_child(_footer)
	for entry: Array in [
		["도형 도감", func(): notebook_requested.emit()],
		["모드 안내", func(): tutorials_requested.emit()],
		["오프닝 다시 보기", func(): opening_requested.emit()],
	]:
		_footer.add_child(QuadTheme.button(entry[0], entry[1]))
	var saved: Label = QuadTheme.label("활동 기록은 자동으로 저장돼요.", 15, Art.MUTED)
	saved.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_footer.add_child(saved)
	_build_exhibition_chooser()
	resized.connect(_responsive)
	_responsive()

func focus_primary() -> void:
	_drawing_button.grab_focus()

func _build_exhibition_chooser() -> void:
	_exhibition_chooser = ColorRect.new()
	_exhibition_chooser.name = "ExhibitChooser"
	_exhibition_chooser.color = Color(0.03, 0.07, 0.12, 0.84)
	_exhibition_chooser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_exhibition_chooser)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exhibition_chooser.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Art.panel(false, 16))
	center.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_title("어떤 전시장을 볼까요?", 23))
	column.add_child(QuadTheme.paragraph("패들릿이 새 창에서 열려요.", 16))
	_exhibit_drawing = QuadTheme.button("그림 전시장 보기", _select_board.bind(false), true)
	_exhibit_drawing.name = "ExhibitDrawing"
	var buildings: Button = QuadTheme.button("건축물 전시장 보기", _select_board.bind(true), true)
	buildings.name = "ExhibitBuilding"
	var close: Button = QuadTheme.button("닫기", _close_exhibition_chooser)
	close.name = "ExhibitClose"
	var controls: Array[Button] = [_exhibit_drawing, buildings, close]
	for button: Button in controls: column.add_child(button)
	for index: int in range(controls.size()):
		var button: Button = controls[index]
		button.focus_next = button.get_path_to(controls[(index + 1) % controls.size()])
		button.focus_previous = button.get_path_to(controls[posmod(index - 1, controls.size())])
		button.focus_neighbor_bottom = button.focus_next
		button.focus_neighbor_top = button.focus_previous
	_exhibition_chooser.hide()

func _open_exhibition_chooser() -> void:
	if not is_visible_in_tree(): return
	_margin.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_exhibition_chooser.show()
	_exhibit_drawing.grab_focus()

func _close_exhibition_chooser() -> void:
	_exhibition_chooser.hide()
	_margin.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	if _exhibition_button.is_visible_in_tree(): _exhibition_button.grab_focus()

func _select_board(buildings: bool) -> void:
	if not _exhibition_chooser.is_visible_in_tree(): return
	_close_exhibition_chooser()
	exhibition_board_requested.emit(buildings)

func _input(event: InputEvent) -> void:
	if is_instance_valid(_exhibition_chooser) and _exhibition_chooser.is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		_close_exhibition_chooser()
		get_viewport().set_input_as_handled()

func _build_hero() -> void:
	_hero = Control.new()
	_hero.clip_contents = true
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_hero)
	_hero_picture = TextureRect.new()
	_hero_picture.name = "OrbitalObservatoryBackground"
	_hero_picture.texture = _menu_texture("arrival")
	_hero_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero.add_child(_hero_picture)
	_hero_copy = VBoxContainer.new()
	_hero_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	_hero_copy.anchor_right = 0.55
	_hero_copy.anchor_bottom = 1.0
	_hero_copy.add_theme_constant_override("separation", 8)
	_hero.add_child(_hero_copy)
	_heading = _title(QuadTheme.GAME_TITLE, 48)
	_hero_copy.add_child(_heading)
	_hero_description = QuadTheme.paragraph("", 19, Color("c6e6de"))
	_hero_copy.add_child(_hero_description)

func _menu_texture(filename: String) -> Texture2D:
	return load(MENU_ART + filename + ".webp") as Texture2D

func _title(caption: String, font_size: int) -> Label:
	var result: Label = QuadTheme.label(caption, font_size, Color("fff1d6"))
	result.add_theme_font_override("font", _display_font)
	return result

func set_ending_progress(sales: int, houses: int, required: int, has_saved_ending: bool) -> void:
	var unlocked: bool = sales + houses >= required or has_saved_ending
	if _ending_card.visible != unlocked:
		_ending_card.visible = unlocked
		_ending_choice.focus_mode = Control.FOCUS_ALL if unlocked else Control.FOCUS_NONE
		_responsive()
	_ending_progress.text = "‘최후의 선택’을 열어 보세요." if unlocked else "최후의 선택까지  ·  그림과 건축 의뢰 %d/%d회" % [sales + houses, required]
	_ending_progress.tooltip_text = "완성한 그림 의뢰 %d회, 건축 의뢰 %d회" % [sales, houses]
	_ending_progress.mouse_filter = Control.MOUSE_FILTER_PASS

func _build_mode(mode: String, title: String, description: String, texture: Texture2D, action_text: String, action: Callable) -> Button:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = mode + "Choice"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Art.panel(false, 9))
	_cards.add_child(panel)
	if mode == "Ending": _ending_card = panel
	var layout: BoxContainer = BoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	layout.vertical = true
	panel.add_child(layout)
	_card_layouts.append(layout)
	var picture: TextureRect = TextureRect.new()
	picture.name = "ModePreview"
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(picture)
	_previews.append(picture)
	var details: VBoxContainer = VBoxContainer.new()
	details.add_theme_constant_override("separation", 5)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(details)
	details.add_child(_title(title, 23))
	details.add_child(QuadTheme.paragraph(description, 16, Color("d1e2e5")))
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(spacer)
	var button: Button = QuadTheme.button(action_text, action, true)
	button.name = "Open" + mode
	details.add_child(button)
	return button

func _responsive() -> void:
	if _ending_card == null: return
	var narrow: bool = size.x < 600.0
	var single_column: bool = size.x < 730.0
	var count: int = 6 if _ending_card.visible else 5
	if single_column:
		_cards.columns = 1
	else:
		_cards.columns = count if size.x >= count * 240.0 else (3 if size.x >= 1000 else 2)
	# Wrapped rows use a thumbnail beside the description so actions stay near the fold.
	var wrapped: bool = not single_column and _cards.columns < count
	var side_by_side: bool = size.x >= 345.0 and (single_column or wrapped)
	for index: int in _card_layouts.size():
		_card_layouts[index].vertical = not side_by_side
		_previews[index].custom_minimum_size.y = 96.0 if side_by_side else clampf(size.y * 0.19, 115.0, 215.0)
		_previews[index].size_flags_stretch_ratio = 0.48 if side_by_side else 1.0
	var gutter: int = int(clampf(size.x * 0.034, 12.0, 80.0))
	for edge: String in ["left", "right"]:
		_margin.add_theme_constant_override("margin_" + edge, gutter)
	_margin.add_theme_constant_override("margin_top", 12 if narrow else 22)
	_margin.add_theme_constant_override("margin_bottom", 20)
	_column.add_theme_constant_override("separation", 12 if narrow else (16 if size.y < 800.0 else 22))
	_section.vertical = narrow
	var hero_height: float = clampf(size.x * 0.183, 96.0, 330.0)
	if wrapped: hero_height = minf(hero_height, maxf(118.0, size.y * 0.22))
	_hero.custom_minimum_size.y = hero_height
	_hero_copy.anchor_right = 0.64 if narrow else 0.55
	_hero_copy.offset_left = clampf(size.x * 0.035, 12.0, 64.0)
	_heading.add_theme_font_size_override("font_size", int(clampf(size.x * 0.042, 27.0, 65.0)))
	_hero_description.text = "지구에 남을까?" if narrow else "지구에 집을 지을까, 사각성으로 돌아갈까?\n의뢰를 마치며 사각이의 미래를 준비해요."
	_hero_description.add_theme_font_size_override("font_size", 15 if narrow else (17 if single_column else 20))
