class_name TestGeneratedButtons
extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")

static func run(t: Node) -> void:
	for primary: bool in [false, true]:
		var image: Image = ButtonArt.texture(primary).get_image()
		for sample: Vector2 in [Vector2(0.5, 0.15), Vector2(0.5, 0.85), Vector2(0.15, 0.5), Vector2(0.85, 0.5)]:
			var pixel: Vector2i = Vector2i(sample * Vector2(image.get_size()))
			t.assert_ge(image.get_pixelv(pixel).a, 0.9, "Generated button face fills its label area rather than a thin stripe: " + str(sample))
	var previous_theme: Theme = t.get_window().theme
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	app._sound.sound_enabled = false
	await _frames(t)
	_assert_buttons(t, app._home_screen, "Home")
	app._show_drawing()
	await _frames(t)
	_assert_buttons(t, app._drawing_screen, "Drawing")
	# The picker lazily creates engine controls in its own popup. Their skins
	# must match as well, even before the child Window is first opened.
	var picker: ColorPicker = app._drawing_screen._color_picker.get_picker()
	_assert_picker_buttons(t, picker, "Color picker")
	var paint: Color = Color("337f9d")
	picker.color = paint
	picker.color_changed.emit(paint)
	await _frames(t)
	t.assert_true(app._drawing_screen.canvas.paint_color.is_equal_approx(paint), "Generated picker styling preserves the chosen paint color")
	_assert_picker_buttons(t, picker, "Picker after color change")
	for node: Node in picker.find_children("*", "BaseButton", true, false):
		if node is Button and (node as Button).text == "HSV":
			(node as Button).pressed.emit()
			break
	await _frames(t)
	_assert_picker_buttons(t, picker, "Picker after mode switch")
	app._drawing_screen._open_colors()
	await _frames(t)
	_assert_buttons(t, app._drawing_screen._color_dialog, "Drawing palette")
	app._drawing_screen._color_dialog.hide()
	app._drawing_screen._open_gallery(false)
	await _frames(t)
	_assert_buttons(t, app._drawing_screen._gallery, "Drawing gallery")
	app._drawing_screen._gallery.hide()
	app._show_workshop()
	await _frames(t)
	_assert_buttons(t, app._workshop_screen, "Workshop")
	app.document.fill_example()
	app._enter_world()
	app.world.set_controls_enabled(false)
	await _frames(t)
	_assert_buttons(t, app._world_hud, "World HUD")
	app._show_game_menu()
	await _frames(t)
	_assert_buttons(t, app._modal_panel, "World menu")
	app._show_construction()
	await _frames(t)
	_assert_buttons(t, app._construction_screen, "Construction")
	# Popup Windows need an explicit theme, as in the actual export creation
	# path: they do not inherit a sibling Control's theme through a Node parent.
	var dialog: FileDialog = FileDialog.new()
	dialog.theme = app._ui.theme
	app.add_child(dialog)
	_assert_skin(t, dialog.get_ok_button(), "Export dialog action")
	_assert_skin(t, dialog.get_cancel_button(), "Export dialog cancel")
	dialog.free()
	app.free()
	t.get_window().theme = previous_theme
	await _frames(t)

static func _assert_buttons(t: Node, parent: Node, context: String) -> void:
	var count: int = 0
	for node: Node in parent.find_children("*", "BaseButton", true, false):
		var button: BaseButton = node as BaseButton
		if button is LinkButton: continue
		if not button.is_visible_in_tree(): continue
		count += 1
		_assert_skin(t, button, context + " / " + str(button.name))
	t.assert_gt(count, 0, context + " exposes actual generated button controls")

static func _assert_picker_buttons(t: Node, picker: ColorPicker, context: String) -> void:
	for node: Node in picker.find_children("*", "BaseButton", true, false):
		if node is LinkButton: continue
		_assert_skin(t, node as BaseButton, context + " / " + str(node.name))

static func _assert_skin(t: Node, button: BaseButton, context: String) -> void:
	var states: Array[String] = ["normal", "hover", "pressed", "disabled"]
	if button.toggle_mode: states.append("hover_pressed")
	for state: String in states:
		var skin: StyleBoxTexture = button.get_theme_stylebox(state) as StyleBoxTexture
		t.assert_not_null(skin, context + " uses a generated raster skin for " + state)
		if skin == null or skin.texture == null: continue
		var source: String = _source(skin.texture)
		t.assert_true(source.contains("assets/generated/") and source.contains("button"), context + " retains new button-art provenance for " + state)
	if button is CheckButton:
		for icon_name: String in ["checked", "unchecked"]:
			var icon: Texture2D = button.get_theme_icon(icon_name)
			t.assert_true(_source(icon).contains("assets/generated/") and _source(icon).contains("button"), context + " uses generated toggle artwork for " + icon_name)

static func _source(texture: Texture2D) -> String:
	if texture is AtlasTexture: return _source((texture as AtlasTexture).atlas)
	return str(texture.get_meta("generated_source", texture.resource_path))

static func _frames(t: Node) -> void:
	for frame: int in range(6): await t.get_tree().process_frame
