class_name HomePage
extends Control

signal drawing_requested
signal adventure_requested
signal construction_requested
signal notebook_requested
signal learning_requested

const Art = preload("res://scripts/construction_art.gd")

var _cards: GridContainer
var _heading: Label
var _margin: MarginContainer
var _mode_buttons: Array[Button] = []
var _column: VBoxContainer
var _learning_record: Label
var _learning_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: TextureRect = TextureRect.new()
	background.name = "QuietPaperBackground"
	background.texture = Art.quiet_surface_texture()
	background.modulate = Color("d8e6e0")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_TILE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var world_bg: TextureRect = TextureRect.new()
	world_bg.texture = GameArt.sheet("world_backdrop")
	world_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	world_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	world_bg.self_modulate = Color(1.0, 1.0, 1.0, 0.07)
	world_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(world_bg)
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
	_column.add_theme_constant_override("separation", 16)
	_margin.add_child(_column)
	_build_header(_column)
	var hero_panel: PanelContainer = PanelContainer.new()
	hero_panel.add_theme_stylebox_override("panel", Art.gold_panel(14))
	_column.add_child(hero_panel)
	var introduction: VBoxContainer = VBoxContainer.new()
	introduction.add_theme_constant_override("separation", 4)
	hero_panel.add_child(introduction)
	_heading = _label("사각형으로 무엇을 만들까요?", 30)
	introduction.add_child(_heading)
	introduction.add_child(_label("그림을 그리고, 집을 짓고, 나의 친구와 모험을 떠나요.", 17, Color("5c3a09")))
	var learn_row: HBoxContainer = HBoxContainer.new()
	learn_row.add_theme_constant_override("separation", 16)
	introduction.add_child(learn_row)
	_learning_button = _button("수학 먼저 해 보기", func(): learning_requested.emit(), true)
	learn_row.add_child(_learning_button)
	_learning_record = _label("수직부터 사각형까지 · 한 활동씩 직접 확인해요.", 16, Art.INK)
	_learning_record.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	learn_row.add_child(_learning_record)
	_cards = GridContainer.new()
	_cards.name = "ActivityChoices"
	_cards.columns = 3
	_cards.add_theme_constant_override("h_separation", 18)
	_cards.add_theme_constant_override("v_separation", 18)
	_column.add_child(_cards)
	_build_mode("Drawing", "사각형으로 표현해요", "나만의 그림", "다섯 가지 사각형으로 나만의 작품을 만들어 보세요.", Art.generated_texture("drawing-cover.png"), "그림 그리기", func(): drawing_requested.emit())
	_build_mode("Construction", "집 짓기 놀이", "뚝딱! 사각형 집 짓기", "의뢰인의 집을 짓고 수익으로 나만의 집도 완성해요.", Art.generated_texture("construction-cover.png"), "집 짓기", func(): construction_requested.emit())
	_build_mode("Adventure", "친구와 탐험", "나의 친구와 모험", "사각형 캐릭터를 조립해 여섯 지역으로 모험을 떠나요.", GameArt.sheet("world_backdrop"), "모험 시작하기", func(): adventure_requested.emit())
	var footer: HFlowContainer = HFlowContainer.new()
	footer.add_theme_constant_override("h_separation", 24)
	footer.add_theme_constant_override("v_separation", 6)
	_column.add_child(footer)
	footer.add_child(_label("그림·집·모험은 각각 자동 저장돼요.", 15, Art.INK))
	footer.add_child(_label("초등 수학 4-2 · 사각형", 15, Art.ACCENT))
	resized.connect(_responsive)
	_responsive()

func focus_primary() -> void:
	_learning_button.grab_focus()

func _build_header(parent: Node) -> void:
	var header_panel: PanelContainer = PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", Art.panel(false, 10))
	parent.add_child(header_panel)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header_panel.add_child(header)
	var mark: TextureRect = TextureRect.new()
	mark.texture = Art.generated_texture("app-icon.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.custom_minimum_size = Vector2(40, 40)
	header.add_child(mark)
	var brand: Label = _label("사각형 월드 · QUADRILATERAL WORLD", 22)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(brand)
	header.add_child(_button("도형 도감", func(): notebook_requested.emit(), false))

func set_learning_progress(count: int) -> void:
	if _learning_record != null:
		_learning_record.text = "수직부터 사각형까지 · 활동 기록 %d / 8" % count

func _build_mode(mode: String, badge_text: String, title: String, description: String, texture: Texture2D, action_text: String, action: Callable) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = mode + "Choice"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Art.panel(false, 16))
	_cards.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var badge: PanelContainer = PanelContainer.new()
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.add_theme_stylebox_override("panel", Art.gold_panel(4) if mode == "Construction" else Art.pill_style(Color("d8efe6"), 8, 3))
	content.add_child(badge)
	var badge_lbl: Label = _label("★ " + badge_text, 13, Color("663e08") if mode == "Construction" else Art.ACCENT)
	badge_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	badge.add_child(badge_lbl)
	var picture_frame: PanelContainer = PanelContainer.new()
	picture_frame.add_theme_stylebox_override("panel", Art.card_panel(3, Color("dceae4")))
	content.add_child(picture_frame)
	var picture: TextureRect = TextureRect.new()
	picture.name = "ModePreview"
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.custom_minimum_size = Vector2(0, 120)
	picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.clip_contents = true
	picture_frame.add_child(picture)
	content.add_child(_label(title, 22))
	content.add_child(_label(description, 16, Art.MUTED))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var button: Button = _button(action_text, action, true)
	button.name = "Open" + mode
	content.add_child(button)
	_mode_buttons.append(button)

func _label(text: String, font_size: int = 18, color: Color = Art.INK) -> Label:
	return QuadTheme.paragraph(text, font_size, color)

func _button(text: String, action: Callable, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", QuadTheme.FONT)
	button.add_theme_font_size_override("font_size", 18)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, Art.button_style(primary, state, 12))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE if primary else Art.INK)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("focus", ButtonArt.focus_style())
	button.pressed.connect(action)
	return button

func _responsive() -> void:
	if _cards == null: return
	_cards.columns = 3 if size.x >= 1100.0 else (2 if size.x >= 850.0 else 1)
	var gutter: int = 20 if size.x < 1100.0 else int(clampf(size.x * 0.03, 28.0, 56.0))
	for edge: String in ["left", "right"]:
		_margin.add_theme_constant_override("margin_" + edge, gutter)
	_margin.add_theme_constant_override("margin_top", 16)
	_margin.add_theme_constant_override("margin_bottom", 16)
	_heading.add_theme_font_size_override("font_size", 26 if size.x < 850.0 else 30)
	_column.add_theme_constant_override("separation", 12 if size.y < 760.0 else 16)
