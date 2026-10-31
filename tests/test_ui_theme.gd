class_name TestUiTheme
extends RefCounted

static func run(t: Node) -> void:
	_test_text_contrast(t)
	_test_button_states(t)
	await _test_construction_gizmo(t)
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
			t.assert_true(_generated_source(style.texture).contains("assets/generated/") and _generated_source(style.texture).contains("button"), "State texture retains its generated button artwork provenance: " + state)
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
		t.assert_ge(_frame_contrast(focus), 3.0, "Focus frame contrasts against surrounding paper")
		button.free()

static func _test_construction_gizmo(t: Node) -> void:
	var canvas: ConstructionCanvas = ConstructionCanvas.new()
	canvas.document = ConstructionDocument.new()
	canvas.size = Vector2(320, 240)
	t.add_child(canvas)
	var part_id: int = canvas.document.add_part("wall", Vector2(500, 300))
	canvas.document.select(part_id)
	canvas.select_tool()
	for frame: int in range(3): await t.get_tree().process_frame
	canvas._update_gizmo()
	t.assert_true(canvas._part_gizmo.visible, "Selecting a building part exposes its contextual actions")
	for button: Button in [canvas._gizmo_rotate, canvas._gizmo_duplicate, canvas._gizmo_delete]:
		t.assert_ge(button.get_theme_font_size("font_size"), 15, "Contextual action text stays legible: " + button.text)
		t.assert_ge(button.custom_minimum_size.y, 44.0, "Contextual actions retain a usable touch height")
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			var color_key: String = "font_color" if state == "normal" else "font_%s_color" % state
			var style: StyleBoxTexture = button.get_theme_stylebox(state) as StyleBoxTexture
			t.assert_ge(_minimum_contrast(button.get_theme_color(color_key), style), 4.5, "Contextual text contrasts with its actual generated background: %s / %s" % [button.text, state])
	t.assert_true(Rect2(Vector2.ZERO, canvas.size).encloses(canvas._part_gizmo.get_rect()), "Enlarged contextual controls stay inside a narrow canvas")
	canvas.free()
	await t.get_tree().process_frame

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
	# Button text sits on the central face. Its transparent outer corners and
	# narrow decorative rim are not behind the label and use the surrounding UI.
	var is_button: bool = _generated_source(style.texture).contains("button")
	var first: Vector2i = Vector2i(floori(float(image.get_width()) * 0.3), floori(float(image.get_height()) * 0.3)) if is_button else Vector2i.ZERO
	var last: Vector2i = Vector2i(ceili(float(image.get_width()) * 0.7), ceili(float(image.get_height()) * 0.7)) if is_button else image.get_size()
	for y: int in range(first.y, last.y, 6):
		for x: int in range(first.x, last.x, 6):
			var background: Color = _compose(image.get_pixel(x, y), style.modulate_color)
			minimum = minf(minimum, _contrast(text_color, background))
	return minimum

static func _generated_source(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		return _generated_source((texture as AtlasTexture).atlas)
	return str(texture.get_meta("generated_source", texture.resource_path))

static func _frame_contrast(style: StyleBoxTexture) -> float:
	var image: Image = style.texture.get_image()
	if image.is_compressed(): image.decompress()
	var contrast: float = 1.0
	# The opaque parts of the generated frame must be visible over paper. PNG
	# padding stays transparent and must not be mistaken for the actual frame.
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var in_center: bool = float(x) >= style.get_texture_margin(SIDE_LEFT) and float(x) < float(image.get_width()) - style.get_texture_margin(SIDE_RIGHT) and float(y) >= style.get_texture_margin(SIDE_TOP) and float(y) < float(image.get_height()) - style.get_texture_margin(SIDE_BOTTOM)
			if in_center: continue
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a * style.modulate_color.a < 0.9: continue
			contrast = maxf(contrast, _contrast(_compose(pixel, style.modulate_color), QuadTheme.PAPER))
	return contrast

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
