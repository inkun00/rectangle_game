class_name HomePage
extends Control

signal drawing_requested
signal adventure_requested
signal construction_requested
signal notebook_requested

const Art = preload("res://scripts/construction_art.gd")

var _cards: GridContainer
var _heading: Label
var _margin: MarginContainer
var _mode_buttons: Array[Button] = []
var _column: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: TextureRect = TextureRect.new()
	background.name = "QuietPaperBackground"
	background.texture = Art.quiet_surface_texture()
	background.modulate = Color("e9efec")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_TILE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
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
	_column.add_theme_constant_override("separation", 24)
	_margin.add_child(_column)
	_build_header(_column)
	var introduction: VBoxContainer = VBoxContainer.new()
	introduction.add_theme_constant_override("separation", 8)
	_column.add_child(introduction)
	_heading = _label("사각형으로 무엇을 만들까요?", 32)
	introduction.add_child(_heading)
	introduction.add_child(_label("그림을 그리고, 집을 짓고, 나의 친구와 모험을 떠나요.", 18, Art.MUTED))
	_cards = GridContainer.new()
	_cards.name = "ActivityChoices"
	_cards.columns = 3
	_cards.add_theme_constant_override("h_separation", 20)
	_cards.add_theme_constant_override("v_separation", 20)
	_column.add_child(_cards)
	_build_mode("Drawing", "나만의 그림", "다섯 가지 사각형을 놓고 색을 칠해요. 빈 도화지와 명화 밑그림에서 자유롭게 만들어 보세요.", Art.generated_texture("drawing-cover.png"), "그림 그리기", func(): drawing_requested.emit())
	_build_mode("Construction", "뚝딱! 사각형 집 짓기", "주민의 부탁에 맞춰 집을 지어요. 재료를 고르고, 튼튼한지 확인하며 새 단계를 열어요.", Art.generated_texture("construction-cover.png"), "집 짓기", func(): construction_requested.emit())
	_build_mode("Adventure", "나의 친구와 모험", "사각형으로 캐릭터를 만들어요. 여섯 지역의 친구들을 만나 부탁을 해결해 보세요.", GameArt.sheet("world_backdrop"), "모험 시작하기", func(): adventure_requested.emit())
	var footer: HFlowContainer = HFlowContainer.new()
	footer.add_theme_constant_override("h_separation", 24)
	footer.add_theme_constant_override("v_separation", 8)
	_column.add_child(footer)
	footer.add_child(_label("그림·집·모험은 각각 자동 저장돼요.", 16, Art.MUTED))
	footer.add_child(_label("초등 수학 4-2 · 사각형", 16, Art.MUTED))
	resized.connect(_responsive)
	_responsive()

func _build_header(parent: Node) -> void:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	parent.add_child(header)
	var mark: TextureRect = TextureRect.new()
	mark.texture = Art.generated_texture("app-icon.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.custom_minimum_size = Vector2(42, 42)
	header.add_child(mark)
	var brand: Label = _label("사각형 월드", 24)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(brand)
	header.add_child(_button("도형 도감", func(): notebook_requested.emit(), false))

func _build_mode(mode: String, title: String, description: String, texture: Texture2D, action_text: String, action: Callable) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = mode + "Choice"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Art.panel(false, 20))
	_cards.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	var picture: TextureRect = TextureRect.new()
	picture.name = "ModePreview"
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.custom_minimum_size = Vector2(0, 132)
	picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.clip_contents = true
	content.add_child(picture)
	content.add_child(_label(title, 23))
	content.add_child(_label(description, 17, Art.MUTED))
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
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, Art.button_style(primary, state, 12))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE if primary else Art.INK)
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Art.ACCENT
	focus.set_border_width_all(3)
	for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		focus.set_expand_margin(edge, 3)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	return button

func _responsive() -> void:
	if _cards == null: return
	_cards.columns = 3 if size.x >= 1100.0 else (2 if size.x >= 850.0 else 1)
	var gutter: int = 24 if size.x < 1100.0 else int(clampf(size.x * 0.035, 32.0, 64.0))
	for edge: String in ["left", "right"]:
		_margin.add_theme_constant_override("margin_" + edge, gutter)
	_margin.add_theme_constant_override("margin_top", 24)
	_margin.add_theme_constant_override("margin_bottom", 24)
	_heading.add_theme_font_size_override("font_size", 28 if size.x < 850.0 else 32)
	_column.add_theme_constant_override("separation", 20 if size.y < 760.0 else 24)
