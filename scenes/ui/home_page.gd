class_name HomePage
extends Control

signal drawing_requested
signal adventure_requested
signal construction_requested
signal notebook_requested

const Art = preload("res://scripts/construction_art.gd")

const INK: Color = Color("243136")
const MUTED: Color = Color("65746f")
const PAPER: Color = Color("f6f7f3")
const LINE: Color = Color("d4dcd5")
const TEAL: Color = Color("315f65")
const COPPER: Color = Color("b57246")

var _cards: GridContainer
var _heading: Label
var _margin: MarginContainer
var _hero_grid: GridContainer
var _hero_heading: Label
var _hero_picture: TextureRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: TextureRect = TextureRect.new()
	background.texture = Art.surface_texture(false)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_margin = MarginContainer.new()
	_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	_margin.add_child(column)
	_build_header(column)
	var introduction: VBoxContainer = VBoxContainer.new()
	introduction.add_theme_constant_override("separation", 8)
	column.add_child(introduction)
	_heading = _label("사각형으로 설계하는 나만의 공간", 34)
	introduction.add_child(_heading)
	introduction.add_child(_label("형태를 이해하고, 재료를 고르고, 하나의 작품을 완성하세요.", 16, MUTED))
	_build_construction_card(column)
	_cards = GridContainer.new()
	_cards.columns = 2
	_cards.add_theme_constant_override("h_separation", 18)
	_cards.add_theme_constant_override("v_separation", 18)
	column.add_child(_cards)
	_build_drawing_card()
	_build_adventure_card()
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	var save_note: Label = _label("작업은 모드마다 자동 저장됩니다. 언제든 이어서 시작할 수 있어요.", 14, MUTED)
	save_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(save_note)
	footer.add_child(_label("초등 수학 4-2 · 사각형", 14, TEAL))
	resized.connect(_responsive)
	_responsive()

func _build_header(parent: Node) -> void:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	parent.add_child(header)
	var mark: TextureRect = TextureRect.new()
	mark.texture = Art.generated_texture("app-icon.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.custom_minimum_size = Vector2(38, 38)
	header.add_child(mark)
	var brand: VBoxContainer = VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_theme_constant_override("separation", 2)
	header.add_child(brand)
	brand.add_child(_label("사각형 월드", 24))
	brand.add_child(_label("설계 · 창작 · 모험", 13, MUTED))
	header.add_child(_button("도형 도감", func(): notebook_requested.emit()))

func _build_construction_card(parent: Node) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _surface(26))
	parent.add_child(panel)
	_hero_grid = GridContainer.new()
	_hero_grid.columns = 2
	_hero_grid.add_theme_constant_override("h_separation", 28)
	_hero_grid.add_theme_constant_override("v_separation", 18)
	panel.add_child(_hero_grid)
	var copy: VBoxContainer = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 14)
	_hero_grid.add_child(copy)
	copy.add_child(_label("뚝딱! 집 짓기", 16, TEAL))
	_hero_heading = _label("한 채의 집을,\n처음부터 완성까지.", 31)
	copy.add_child(_hero_heading)
	copy.add_child(_label("작은 네모 집부터 멋진 집까지! 부탁을 들어주고 돈을 모아 새 단계를 열어요. 멋진 집을 지으면 반짝이는 배지도 받을 수 있어요.", 16, MUTED))
	var steps: HFlowContainer = HFlowContainer.new()
	steps.add_theme_constant_override("h_separation", 16)
	steps.add_theme_constant_override("v_separation", 6)
	copy.add_child(steps)
	for step: String in ["01  부탁 보기", "02  집 짓기", "03  확인하고 보상 받기"]:
		steps.add_child(_label(step, 13, MUTED))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.add_child(spacer)
	var start: Button = _button("집 짓기", func(): construction_requested.emit(), true)
	start.name = "OpenConstruction"
	start.custom_minimum_size = Vector2(190, 50)
	start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	copy.add_child(start)
	_hero_picture = _picture("construction-cover.png", 306)
	_hero_picture.custom_minimum_size = Vector2(0, 306)
	_hero_picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hero_grid.add_child(_hero_picture)

func _build_drawing_card() -> void:
	var content: VBoxContainer = _card()
	var art: TextureRect = _picture("drawing-cover.png", 140)
	content.add_child(art)
	content.add_child(_label("형태를 조합하는 드로잉 스튜디오", 21))
	content.add_child(_label("다섯 종류의 사각형을 배치하고 색과 크기를 조절해 나만의 그림을 만드세요.", 15, MUTED))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	content.add_child(_button("그림 그리기", func(): drawing_requested.emit()))

func _build_adventure_card() -> void:
	var content: VBoxContainer = _card()
	var picture: TextureRect = GameArt.view(GameArt.sheet("world_backdrop"), Vector2(0, 140))
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	content.add_child(picture)
	content.add_child(_label("직접 만든 캐릭터와 떠나는 모험", 21))
	content.add_child(_label("캐릭터 공방에서 친구를 만들고 여섯 지역을 탐험하며 주민들의 부탁을 해결하세요.", 15, MUTED))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	content.add_child(_button("모험 시작하기", func(): adventure_requested.emit()))

func _card() -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _surface(20))
	_cards.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	return content

func _picture(filename: String, height: float) -> TextureRect:
	var picture: TextureRect = TextureRect.new()
	picture.texture = Art.generated_texture(filename)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.custom_minimum_size.y = height
	picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.clip_contents = true
	return picture

func _surface(padding: int) -> StyleBoxTexture:
	return Art.panel(false, padding)

func _label(text: String, font_size: int = 16, color: Color = INK) -> Label:
	return QuadTheme.paragraph(text, font_size, color)

func _button(text: String, action: Callable, primary: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", QuadTheme.FONT)
	button.add_theme_font_size_override("font_size", 16)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, Art.button_style(primary, state, 12))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE if primary else INK)
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = COPPER
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	return button

func _responsive() -> void:
	if _cards == null: return
	var narrow: bool = size.x < 1000.0
	_cards.columns = 1 if size.x < 760.0 else 2
	_hero_grid.columns = 1 if narrow else 2
	_heading.add_theme_font_size_override("font_size", 28 if narrow else 34)
	_hero_heading.add_theme_font_size_override("font_size", 28 if narrow else 31)
	_hero_picture.custom_minimum_size.y = 280 if narrow else 306
	var gutter: int = 24 if narrow else int(clampf(size.x * 0.045, 36, 80))
	for edge: String in ["left", "right"]:
		_margin.add_theme_constant_override("margin_" + edge, gutter)
	_margin.add_theme_constant_override("margin_top", 24)
	_margin.add_theme_constant_override("margin_bottom", 24)
