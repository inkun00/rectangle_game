class_name TestUiTheme
extends RefCounted

static func run(t: Node) -> void:
	_test_text_contrast(t)
	_test_button_states(t)
	await _test_keyboard_activation(t)

static func _test_text_contrast(t: Node) -> void:
	var world_font: FontFile = load("res://assets/fonts/korean_font.ttf") as FontFile
	t.assert_eq(QuadTheme.FONT.oversampling, 1.0, "UI glyphs retain full resolution when their layer cancels viewport stretch")
	t.assert_true(QuadTheme.FONT != world_font, "UI font sampling does not change the world's automatic font resolution")
	t.assert_eq(world_font.oversampling, 0.0, "World text keeps automatic sampling for zoomed gameplay")
	var paper: StyleBoxTexture = GameArt.panel(0)
	for color: Color in [QuadTheme.INK, QuadTheme.MUTED, QuadTheme.TEAL]:
		t.assert_ge(_minimum_contrast(color, paper), 4.5, "Body and accent text remain readable over generated paper texture")
	var paragraph: Label = QuadTheme.paragraph("도형의 네 변과 네 각을 살펴보아요.")
	t.assert_ge(paragraph.get_theme_font_size("font_size"), 17, "Default learning paragraphs use readable type")
	t.assert_eq(paragraph.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "Paragraphs reflow instead of clipping instructions")
	paragraph.free()
	var palette: Array[Color] = [Color("29a995"), Color("ff966d"), Color("f1c75b"), Color("617dc7"), Color("9d7ace"), Color("e47796"), Color("354d60"), Color("f6ead1")]
	t.assert_eq(QuadTheme.COLORS, palette, "UI contrast changes preserve the player's artwork palette")

static func _test_button_states(t: Node) -> void:
	for primary: bool in [false, true]:
		var button: Button = QuadTheme.button("모험 계속하기", Callable(), primary)
		t.assert_ge(button.custom_minimum_size.x, 44.0, "Short button labels retain a usable hit width")
		t.assert_ge(button.custom_minimum_size.y, 48.0, "Buttons retain a comfortable hit height")
		t.assert_ge(button.get_theme_font_size("font_size"), 18, "Button actions are legible for young readers")
		t.assert_eq(button.focus_mode, Control.FOCUS_ALL, "Workshop and modal buttons support keyboard focus")
		var styles: Dictionary = {}
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style: StyleBoxTexture = button.get_theme_stylebox(state) as StyleBoxTexture
			t.assert_not_null(style, "Each button state uses the generated texture theme: " + state)
			if style == null: continue
			styles[state] = style
			var atlas: AtlasTexture = style.texture as AtlasTexture
			t.assert_not_null(atlas, "State texture comes from an atlas: " + state)
			if atlas != null:
				t.assert_true(atlas.atlas.resource_path.ends_with("assets/generated/ui_atlas.png"), "Button styling preserves generated artwork provenance")
		for state: String in ["normal", "hover", "pressed"]:
			var color_key: String = "font_color" if state == "normal" else "font_%s_color" % state
			t.assert_ge(_minimum_contrast(button.get_theme_color(color_key), styles[state]), 4.5, "Button text is readable in interactive state: " + state)
		var normal: StyleBoxTexture = styles["normal"]
		var hover: StyleBoxTexture = styles["hover"]
		var pressed: StyleBoxTexture = styles["pressed"]
		var disabled: StyleBoxTexture = styles["disabled"]
		var focus: StyleBoxTexture = styles["focus"]
		t.assert_true(normal.texture != hover.texture or normal.modulate_color != hover.modulate_color, "Hover is visibly different from the resting button")
		t.assert_true(hover.texture != pressed.texture or hover.modulate_color != pressed.modulate_color, "Press gives feedback distinct from hovering")
		t.assert_true(normal.texture != disabled.texture or normal.modulate_color != disabled.modulate_color, "Disabled action is visually distinguishable")
		t.assert_eq(normal.get_minimum_size(), pressed.get_minimum_size(), "Press feedback does not shift neighboring controls")
		t.assert_false(focus.draw_center, "Keyboard focus frame does not cover the current button state")
		for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			t.assert_ge(focus.get_texture_margin(side), 3.0, "Focus indicator has a clearly visible frame")
			t.assert_ge(focus.get_expand_margin(side), 3.0, "Focus indicator remains outside the label and artwork")
		t.assert_ge(_minimum_contrast(_sample(focus, 0, 0), GameArt.panel(0)), 3.0, "Focus frame contrasts against surrounding paper")
		button.free()

static func _test_keyboard_activation(t: Node) -> void:
	var layout: VBoxContainer = VBoxContainer.new()
	layout.position = Vector2(60.0, 60.0)
	layout.add_theme_constant_override("separation", 12)
	t.add_child(layout)
	var activations: Array[int] = [0]
	var button: Button = QuadTheme.button("선택한 도형 사용", func(): activations[0] += 1)
	layout.add_child(button)
	await t.get_tree().process_frame
	button.grab_focus()
	t.assert_true(button.has_focus(), "Themed button accepts actual viewport keyboard focus")
	_accept()
	t.assert_eq(activations[0], 1, "Keyboard acceptance activates the action exactly once without an animation delay")
	button.disabled = true
	_accept()
	t.assert_eq(activations[0], 1, "Disabled button cannot be activated with the keyboard")
	layout.free()
	await t.get_tree().process_frame

static func _accept() -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = "ui_accept"
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

static func _minimum_contrast(text_color: Color, style: StyleBoxTexture) -> float:
	var image: Image = style.texture.get_image()
	if image.is_compressed(): image.decompress()
	var minimum: float = INF
	# Sample the whole source, including texture variation near its edges.
	for y: int in range(0, image.get_height(), 6):
		for x: int in range(0, image.get_width(), 6):
			var background: Color = _compose(image.get_pixel(x, y), style.modulate_color)
			minimum = minf(minimum, _contrast(text_color, background))
	return minimum

static func _sample(style: StyleBoxTexture, x: int, y: int) -> Color:
	var image: Image = style.texture.get_image()
	if image.is_compressed(): image.decompress()
	return _compose(image.get_pixel(x, y), style.modulate_color)

static func _compose(pixel: Color, tint: Color) -> Color:
	var color: Color = pixel * tint
	color.r = clampf(color.r, 0.0, 1.0)
	color.g = clampf(color.g, 0.0, 1.0)
	color.b = clampf(color.b, 0.0, 1.0)
	return QuadTheme.PAPER.blend(color)

static func _contrast(a: Color, b: Color) -> float:
	var light_a: float = a.srgb_to_linear().get_luminance()
	var light_b: float = b.srgb_to_linear().get_luminance()
	return (maxf(light_a, light_b) + 0.05) / (minf(light_a, light_b) + 0.05)
