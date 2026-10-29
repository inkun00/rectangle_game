class_name QuadTheme
extends RefCounted

const INK: Color = Color("213b42")
const MUTED: Color = Color("3d5053")
const PAPER: Color = Color("f8faf6")
const TEAL: Color = Color("0c5548")
const BORDER: Color = Color("dce6df")
static var FONT: FontFile = _make_ui_font()
const COLORS: Array[Color] = [Color("29a995"), Color("ff966d"), Color("f1c75b"), Color("617dc7"), Color("9d7ace"), Color("e47796"), Color("354d60"), Color("f6ead1")]
const BUTTON_FONT_SIZE: int = 18
const BUTTON_MINIMUM_SIZE: Vector2 = Vector2(48.0, 48.0)

static func _make_ui_font() -> FontFile:
	var result: FontFile = preload("res://assets/fonts/korean_font.ttf").duplicate() as FontFile
	# The UI cancels the world's viewport stretch to keep its physical text size.
	# Automatic oversampling would still rasterize at the smaller world scale.
	result.oversampling = 1.0
	return result

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

static func paragraph(text: String, font_size: int = 17, color: Color = MUTED) -> Label:
	var l: Label = label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_constant_override("line_spacing", 5)
	return l

static func button(text: String, callback: Callable, primary: bool = false) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_MINIMUM_SIZE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_ALL
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 38)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	b.add_theme_color_override("font_color", Color.WHITE if primary else INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE if primary else INK)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE if primary else INK)
	b.add_theme_color_override("font_disabled_color", Color("536360"))
	ButtonArt.apply(b, primary, BUTTON_FONT_SIZE)
	if callback.is_valid(): b.pressed.connect(callback)
	return b

static func _button_style(index: int, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var result: StyleBoxTexture = ButtonArt.style(index in [1, 2])
	result.modulate_color = tint
	return result

static func _focus_style() -> StyleBoxTexture:
	return ButtonArt.focus_style()

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
