class_name QuadTheme
extends RefCounted

const INK: Color = Color("213b42")
const MUTED: Color = Color("6e8386")
const PAPER: Color = Color("f8faf6")
const TEAL: Color = Color("168979")
const BORDER: Color = Color("dce6df")
const FONT: Font = preload("res://assets/fonts/korean_font.ttf")
const COLORS: Array[Color] = [Color("29a995"), Color("ff966d"), Color("f1c75b"), Color("617dc7"), Color("9d7ace"), Color("e47796"), Color("354d60"), Color("f6ead1")]

static func style(color: Color, _radius: int = 0, border: Color = Color.TRANSPARENT, padding: int = 16) -> StyleBoxTexture:
	var index: int = 1 if color.get_luminance() < 0.35 else (3 if border.is_equal_approx(TEAL) else 0)
	var s: StyleBoxTexture = GameArt.panel(index, padding)
	s.modulate_color.a = color.a
	if padding == 0:
		s.texture = GameArt.panel_texture(0)
		s.modulate_color = color
	return s

static func label(text: String, font_size: int = 16, color: Color = INK) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

static func paragraph(text: String, font_size: int = 15, color: Color = MUTED) -> Label:
	var l: Label = label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func button(text: String, callback: Callable, primary: bool = false) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size.y = 44.0
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 38)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color.WHITE if primary else INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE if primary else INK)
	b.add_theme_color_override("font_pressed_color", Color.WHITE if primary else INK)
	b.add_theme_color_override("font_disabled_color", Color("9bafad"))
	b.add_theme_stylebox_override("normal", GameArt.panel(2 if primary else 0, 12))
	b.add_theme_stylebox_override("hover", GameArt.panel(1 if primary else 3, 12))
	b.add_theme_stylebox_override("pressed", GameArt.panel(1 if primary else 3, 12))
	b.add_theme_stylebox_override("disabled", style(Color("e5ece7"), 11, Color.TRANSPARENT, 12))
	if callback.is_valid(): b.pressed.connect(callback)
	return b

static func card(parent: Node, color: Color = Color.WHITE, padding: int = 20) -> VBoxContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(color, 18, BORDER, padding))
	parent.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	return v

static func icon(kind: String) -> Texture2D:
	return GameArt.item(int({"trapezoid": 2, "parallelogram": 3, "rhombus": 0, "rectangle": 4, "square": 7}.get(kind, 7)))
