class_name ButtonArt
extends RefCounted

## Shared ImageGen sprites. Runtime work only trims transparent padding, samples
## at UI resolution, and nine-slices the narrow edge; labels remain live text.
const ROOT: String = "res://assets/generated/buttons-v1/"
const INK: Color = Color("263b3d")
const MUTED: Color = Color("536360")
const STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "disabled"]
static var _textures: Dictionary = {}
static var _font: FontFile

static func _ui_font() -> FontFile:
	if _font == null:
		_font = preload("res://assets/fonts/korean_font.ttf").duplicate() as FontFile
		_font.oversampling = 1.0
	return _font

static func _sprite(filename: String, dimensions: Vector2i) -> Texture2D:
	var key: String = "%s:%s" % [filename, dimensions]
	if _textures.has(key): return _textures[key] as Texture2D
	var path: String = ROOT + filename
	var source: Texture2D = load(path) as Texture2D
	var pixels: Image = source.get_image()
	if pixels.is_compressed(): pixels.decompress()
	var mask: BitMap = BitMap.new()
	mask.create_from_image_alpha(pixels, 0.5)
	var outlines: Array[PackedVector2Array] = mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, pixels.get_size()), 1.0)
	var bounds: Rect2 = Rect2()
	for outline: PackedVector2Array in outlines:
		for point: Vector2 in outline:
			if not bounds.has_area(): bounds = Rect2(point, Vector2.ONE)
			else: bounds = bounds.expand(point)
	var used: Rect2i = Rect2i(bounds).grow(1).intersection(Rect2i(Vector2i.ZERO, pixels.get_size())) if bounds.has_area() else pixels.get_used_rect()
	if used.has_area(): pixels = pixels.get_region(used)
	pixels.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
	var result: ImageTexture = ImageTexture.create_from_image(pixels)
	result.set_meta("generated_source", path)
	_textures[key] = result
	return result

static func texture(primary: bool = false) -> Texture2D:
	return _sprite("primary.png" if primary else "secondary.png", Vector2i(384, 72))

static func indicator(checked: bool) -> Texture2D:
	return _sprite("check-on.png" if checked else "check-off.png", Vector2i(26, 26))

static func style(primary: bool = false, state: String = "normal", padding: int = 12) -> StyleBoxTexture:
	var selected: bool = state in ["pressed", "hover_pressed"]
	var result: StyleBoxTexture = StyleBoxTexture.new()
	var primary_face: bool = (primary or selected) and state != "disabled"
	var face: AtlasTexture = AtlasTexture.new()
	face.atlas = texture(primary_face)
	face.region = Rect2(10, 10, 364, 52)
	face.filter_clip = true
	face.set_meta("generated_source", ROOT + ("primary.png" if primary_face else "secondary.png"))
	result.texture = face
	for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(edge, 2.0)
		result.set_content_margin(edge, 10.0 if edge in [SIDE_TOP, SIDE_BOTTOM] else float(maxi(padding, 14)))
	if state == "hover": result.modulate_color = Color(1.08, 1.08, 1.04) if primary else Color(0.96, 1.0, 0.96)
	elif selected: result.modulate_color = Color(0.84, 0.90, 0.87)
	elif state == "disabled": result.modulate_color = Color(0.86, 0.89, 0.87)
	return result

static func focus_style() -> StyleBoxTexture:
	var result: StyleBoxTexture = StyleBoxTexture.new()
	var face: AtlasTexture = AtlasTexture.new()
	face.atlas = texture(true)
	face.region = Rect2(96, 24, 32, 24)
	face.filter_clip = true
	result.texture = face
	result.draw_center = false
	result.modulate_color = Color(0.35, 0.45, 0.40)
	for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(edge, 3.0)
		result.set_expand_margin(edge, 3.0)
	return result

static func swatch(color: Color, state: String = "normal") -> StyleBoxTexture:
	var result: StyleBoxTexture = StyleBoxTexture.new()
	result.texture = _sprite("check-off.png", Vector2i(48, 48))
	result.modulate_color = color.lightened(0.12) if state == "hover" else color
	for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(edge, 5.0)
		result.set_content_margin(edge, 0.0)
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
	theme.set_stylebox("hover", "PopupMenu", style(false, "hover", 8))
	theme.set_color("font_hover_color", "PopupMenu", INK)
