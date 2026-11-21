class_name ButtonArt
extends RefCounted

## Pre-cropped ImageGen sprites keep their original edges at any control size.
const ROOT: String = "res://assets/generated/adventure-ui-v2/"
const PETROL: Texture2D = preload(ROOT + "button-petrol.webp")
const CORAL: Texture2D = preload(ROOT + "button-coral.webp")
const JADE: Texture2D = preload(ROOT + "button-jade.webp")
const SLATE: Texture2D = preload(ROOT + "button-slate.webp")
const CHECKED: Texture2D = preload(ROOT + "checked.webp")
const UNCHECKED: Texture2D = preload(ROOT + "unchecked.webp")
const INK: Color = Color("edf5fc")
const MUTED: Color = Color("9eb1c1")
const STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "disabled"]
static var _font: FontFile

static func _ui_font() -> FontFile:
	if _font == null:
		_font = preload("res://assets/fonts/korean_font.ttf").duplicate() as FontFile
		_font.oversampling = 1.0
	return _font

static func texture(primary: bool = false) -> Texture2D:
	return CORAL if primary else PETROL

static func indicator(checked: bool) -> Texture2D:
	return CHECKED if checked else UNCHECKED

static func style(primary: bool = false, state: String = "normal", padding: int = 12) -> StyleBoxTexture:
	var result: StyleBoxTexture = StyleBoxTexture.new()
	result.texture = texture(primary)
	match state:
		"hover":
			result.modulate_color = Color(1.20, 1.16, 1.10)
			if not primary: result.texture = JADE
		"pressed", "hover_pressed":
			result.texture = JADE
			result.modulate_color = Color(0.82, 0.92, 0.90)
		"disabled":
			result.texture = SLATE
			result.modulate_color = Color(0.78, 0.83, 0.87)
	for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(edge, 8.0)
	result.content_margin_top = 10.0
	result.content_margin_bottom = 10.0
	result.content_margin_left = float(maxi(padding, 14))
	result.content_margin_right = float(maxi(padding, 14))
	return result

static func focus_style() -> StyleBoxTexture:
	var result: StyleBoxTexture = StyleBoxTexture.new()
	result.texture = JADE
	result.draw_center = false
	for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(edge, 4.0)
		result.set_expand_margin(edge, 4.0)
	return result

static func apply(button: BaseButton, primary: bool = false, font_size: int = 18) -> void:
	for state: String in STATES: button.add_theme_stylebox_override(state, style(primary, state))
	button.add_theme_stylebox_override("focus", focus_style())
	button.add_theme_font_size_override("font_size", font_size)
	for state: String in ["font_color", "font_hover_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE if primary else INK)
	for state: String in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if button is CheckButton or button is CheckBox:
		_apply_indicators(button)
	if button is ColorPickerButton:
		if button.is_node_ready():
			_configure_picker(button as ColorPickerButton)
		elif not button.has_meta("generated_picker_ready"):
			button.set_meta("generated_picker_ready", true)
			button.ready.connect(func(): _configure_picker(button as ColorPickerButton), CONNECT_ONE_SHOT)

static func _configure_picker(button: ColorPickerButton) -> void:
	var picker: ColorPicker = button.get_picker()
	skin_tree(picker)
	skin_tree.call_deferred(picker)
	if picker.has_meta("generated_skin_connected"): return
	picker.set_meta("generated_skin_connected", true)
	# Native ColorPicker mode switches rebuild their own button overrides.
	# Reapply after those engine updates, while leaving all color values intact.
	picker.color_changed.connect(func(_color: Color): skin_tree.call_deferred(picker))
	picker.theme_changed.connect(func(): skin_tree.call_deferred(picker))
	for node: Node in picker.find_children("*", "BaseButton", true, false):
		(node as BaseButton).pressed.connect(func(): skin_tree.call_deferred(picker))

static func skin_tree(parent: Node) -> void:
	if not is_instance_valid(parent): return
	for node: Node in parent.find_children("*", "BaseButton", true, false):
		if node is LinkButton: continue
		var button: BaseButton = node as BaseButton
		apply(button, false, button.get_theme_font_size("font_size"))

static func _apply_indicators(button: BaseButton) -> void:
	for icon: String in ["checked", "checked_disabled", "radio_checked", "radio_checked_disabled"]:
		button.add_theme_icon_override(icon, indicator(true))
	for icon: String in ["unchecked", "unchecked_disabled", "radio_unchecked", "radio_unchecked_disabled"]:
		button.add_theme_icon_override(icon, indicator(false))

static func install(theme: Theme) -> void:
	for type: String in ["Button", "OptionButton", "MenuButton", "ColorPickerButton", "CheckButton", "CheckBox"]:
		for state: String in STATES: theme.set_stylebox(state, type, style(false, state))
		theme.set_stylebox("focus", type, focus_style())
		theme.set_font("font", type, _ui_font())
		theme.set_font_size("font_size", type, 18)
		for state: String in ["font_color", "font_hover_color", "font_focus_color"]: theme.set_color(state, type, INK)
		for state: String in ["font_pressed_color", "font_hover_pressed_color"]: theme.set_color(state, type, Color.WHITE)
		theme.set_color("font_disabled_color", type, MUTED)
	for type: String in ["CheckButton", "CheckBox"]:
		for icon: String in ["checked", "checked_disabled", "radio_checked", "radio_checked_disabled"]: theme.set_icon(icon, type, indicator(true))
		for icon: String in ["unchecked", "unchecked_disabled", "radio_unchecked", "radio_unchecked_disabled"]: theme.set_icon(icon, type, indicator(false))
	for type: String in ["PopupMenu", "PopupPanel", "AcceptDialog", "TooltipPanel"]:
		theme.set_stylebox("panel", type, StarfrontArt.panel(0, 10))
	# Embedded windows draw their draggable title and resize handles outside the
	# content rectangle. Keep the engine's metrics when replacing that frame.
	for state: String in ["embedded_border", "embedded_unfocused_border"]:
		var frame: StyleBoxTexture = StarfrontArt.panel(3 if state == "embedded_border" else 0)
		var native: StyleBoxFlat = ThemeDB.get_default_theme().get_stylebox(state, "Window") as StyleBoxFlat
		for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			frame.set_expand_margin(edge, native.get_expand_margin(edge))
			frame.set_content_margin(edge, native.get_content_margin(edge))
		theme.set_stylebox(state, "Window", frame)
	theme.set_stylebox("normal", "LineEdit", StarfrontArt.panel(0, 6))
	theme.set_stylebox("focus", "LineEdit", focus_style())
	theme.set_stylebox("hover", "PopupMenu", style(false, "hover", 8))
	theme.set_constant("v_separation", "PopupMenu", 8)
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
