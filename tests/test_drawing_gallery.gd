class_name TestDrawingGallery
extends RefCounted

const Studio = preload("res://scenes/drawing/drawing_studio.gd")
const Catalog = preload("res://scripts/core/drawing_catalog.gd")

static func run(t: Node) -> void:
	_test_catalog_resources(t)
	_test_palette(t)
	await _test_gallery_workflow(t)

static func _test_catalog_resources(t: Node) -> void:
	var backgrounds: Array[Dictionary] = Catalog.backgrounds()
	var masterpieces: Array[Dictionary] = Catalog.masterpieces()
	t.assert_eq(backgrounds.size(), 30, "Drawing offers thirty selectable scene backgrounds")
	t.assert_eq(masterpieces.size(), 10, "Drawing offers ten selectable masterpiece studies")
	var ids: Dictionary = {}
	var paths: Dictionary = {}
	var categories: Dictionary = {}
	for entry: Dictionary in backgrounds:
		var id: String = str(entry.id)
		var path: String = str(entry.path)
		t.assert_false(ids.has(id), "Background ids are unique: " + id)
		t.assert_false(paths.has(path), "Each background has its own source image: " + id)
		t.assert_false(str(entry.name).is_empty(), "Background choices have Korean labels")
		ids[id] = true
		paths[path] = true
		categories[str(entry.category)] = true
		_assert_texture(t, path, "Background " + id)
	for category: String in ["도시", "바다", "우주", "산", "집"]:
		t.assert_true(categories.has(category), "Requested background category is available: " + category)
	ids.clear()
	paths.clear()
	for entry: Dictionary in masterpieces:
		var id: String = str(entry.id)
		var path: String = str(entry.path)
		var reference_path: String = str(entry.reference_path)
		t.assert_false(ids.has(id), "Masterpiece ids are unique: " + id)
		t.assert_false(paths.has(path), "Each masterpiece has an independent outline")
		t.assert_false(path == reference_path, "Outline and colored reference are separate resources")
		ids[id] = true
		paths[path] = true
		t.assert_true(str(entry.source_url).begins_with("https://"), "Masterpiece provenance has a source link")
		for field: String in ["name", "artist", "year", "description"]:
			t.assert_false(str(entry[field]).is_empty(), "Masterpiece has visible learning metadata: " + field)
		_assert_texture(t, path, "Masterpiece outline " + id)
		_assert_texture(t, reference_path, "Masterpiece reference " + id)
	t.assert_true(Catalog.background("missing-background").is_empty(), "Unknown background has no resource fallback")
	t.assert_true(Catalog.masterpiece("missing-painting").is_empty(), "Unknown masterpiece has no resource fallback")
	# Consumers can annotate returned metadata without changing future choices.
	backgrounds[0].name = "test mutation"
	t.assert_false(str(Catalog.backgrounds()[0].name) == "test mutation", "Catalog callers cannot mutate the shared scene labels")

static func _assert_texture(t: Node, path: String, message: String) -> void:
	var exists: bool = ResourceLoader.exists(path)
	t.assert_true(FileAccess.file_exists(path), message + " source is packaged")
	t.assert_true(exists, message + " imports as a resource")
	if not exists:
		return
	var texture: Texture2D = load(path) as Texture2D
	t.assert_not_null(texture, message + " loads as a texture")
	if texture != null:
		t.assert_gt(texture.get_width(), 0, message + " has visible width")
		t.assert_gt(texture.get_height(), 0, message + " has visible height")

static func _test_palette(t: Node) -> void:
	var distinct: Dictionary = {}
	for color: Color in Studio.PALETTE:
		distinct[color.to_html(true)] = true
		t.assert_float_approx(color.a, 1.0, 0.001, "Preset paint colors stay opaque")
	t.assert_ge(distinct.size(), 48, "Expanded palette includes at least forty-eight distinct colors")
	t.assert_true(distinct.has(Color.WHITE.to_html(true)), "Palette includes white for highlights")
	var brightest: float = 0.0
	var darkest: float = 1.0
	for color: Color in Studio.PALETTE:
		brightest = maxf(brightest, color.get_luminance())
		darkest = minf(darkest, color.get_luminance())
	t.assert_lt(darkest, 0.2, "Palette includes a dark shade for outlines and shadows")
	t.assert_gt(brightest - darkest, 0.5, "Palette spans contrasting light and dark paint choices")

static func _test_gallery_workflow(t: Node) -> void:
	var root: Window = t.get_tree().root
	var original_size: Vector2i = root.size
	var original_scale: Vector2i = root.content_scale_size
	root.size = Vector2i(1024, 720)
	root.content_scale_size = Vector2i(1024, 720)
	var studio: Studio = Studio.new()
	studio.testing = true
	var path: String = "res://.godot/drawing_gallery_test_%d.json" % Time.get_ticks_usec()
	studio.save_path = path
	t.add_child(studio)
	await _frames(t)
	studio.document.add_sized_shape("rectangle", Vector2(-120, -20), Vector2(140, 90), Color.TEAL)
	studio.document.add_sized_shape("rhombus", Vector2(90, 25), Vector2(80, 100), Color.GOLD)
	var artwork: Array[Dictionary] = studio.document.ordered_shapes()
	studio._open_gallery(false)
	await _frames(t)
	t.assert_true(studio._gallery.visible, "Background chooser opens as a visible dialog")
	_assert_preview_resources(t, studio._gallery, Catalog.backgrounds(), false)
	_assert_window_fits(t, studio._gallery, root.size, "Background chooser fits a 1024 by 720 window")
	_assert_modal_delete_blocked(t, studio)
	var background: Dictionary = Catalog.backgrounds()[0]
	var background_button: Button = _entry_button(studio._gallery, str(background.name))
	t.assert_not_null(background_button, "Scene preview has a labeled selection button")
	if background_button != null:
		background_button.pressed.emit()
	t.assert_false(studio._gallery.visible, "Choosing a background closes its dialog")
	t.assert_eq(studio.document.background_id, str(background.id), "Gallery button applies the chosen background")
	t.assert_eq(studio.document.ordered_shapes(), artwork, "Background choices preserve all user geometry and colors")
	studio._undo_edit()
	t.assert_eq(studio.document.background_id, "paper", "Studio undo restores the previous scene")
	studio._redo_edit()
	t.assert_eq(studio.document.background_id, str(background.id), "Studio redo restores selected scene")
	studio._choose_mode("masterpiece")
	await _frames(t)
	t.assert_true(studio._gallery.visible, "First entry to masterpiece mode asks for an outline")
	_assert_preview_resources(t, studio._gallery, Catalog.masterpieces(), true)
	_assert_window_fits(t, studio._gallery, root.size, "Masterpiece chooser fits a 1024 by 720 window")
	var gallery_scrolls: Array[Node] = studio._gallery.find_children("*", "ScrollContainer", true, false)
	t.assert_gt(gallery_scrolls.size(), 0, "Masterpiece choices remain scrollable in a short window")
	if not gallery_scrolls.is_empty():
		var gallery_scroll: ScrollContainer = gallery_scrolls[0] as ScrollContainer
		t.assert_gt(gallery_scroll.get_v_scroll_bar().max_value, gallery_scroll.get_v_scroll_bar().page, "Scrolling reaches masterpiece rows below the visible dialog")
	var masterpiece: Dictionary = Catalog.masterpieces()[0]
	var masterpiece_button: Button = _entry_button(studio._gallery, str(masterpiece.name))
	t.assert_not_null(masterpiece_button, "Masterpiece preview has a labeled selection button")
	if masterpiece_button != null:
		masterpiece_button.pressed.emit()
	t.assert_eq(studio.document.masterpiece_id, str(masterpiece.id), "Masterpiece gallery stores the selected study")
	t.assert_eq(studio.document.drawing_mode, "masterpiece", "Selecting a study enters masterpiece fill mode")
	t.assert_false(studio._masterpiece_tools.visible, "A short window keeps the drawing surface free of an extra outline-control row")
	t.assert_true(studio._more_edits.get_popup().get_item_text(10).contains("밑그림") and studio._more_edits.get_popup().get_item_text(11).contains("진하기"), "Compact editing keeps both outline controls in its labeled menu")
	var guide_visible: bool = studio.canvas.show_masterpiece
	var opacity: float = studio.canvas.masterpiece_opacity
	studio._more_edits.get_popup().id_pressed.emit(10)
	studio._more_edits.get_popup().id_pressed.emit(11)
	t.assert_eq(studio.canvas.show_masterpiece, not guide_visible, "The compact outline menu changes visibility")
	t.assert_true(studio.canvas.masterpiece_opacity != opacity, "The compact outline menu changes opacity")
	t.assert_eq(studio._guide_toggle.button_pressed, studio.canvas.show_masterpiece, "Wide and compact outline visibility controls stay synchronized")
	t.assert_float_approx(studio._guide_opacity.value, studio.canvas.masterpiece_opacity, 0.001, "Resizing retains the true outline opacity")
	t.assert_eq(studio.document.ordered_shapes(), artwork, "Entering fill mode preserves the player's four-vertex artwork")
	studio._choose_mode("free")
	t.assert_false(studio._masterpiece_tools.visible, "Free drawing hides fill-specific controls")
	studio._choose_mode("masterpiece")
	t.assert_false(studio._gallery.visible, "Returning to fill mode reuses the chosen study")
	studio._open_colors()
	await _frames(t)
	t.assert_true(studio._color_dialog.visible, "Expanded color chooser opens")
	_assert_window_fits(t, studio._color_dialog, root.size, "Expanded palette fits a 1024 by 720 window")
	_assert_modal_delete_blocked(t, studio)
	var swatch_count: int = 0
	for candidate: Node in studio._color_dialog.find_children("*", "Button", true, false):
		if candidate.has_meta("paint_color"):
			swatch_count += 1
	t.assert_eq(swatch_count, Studio.PALETTE.size(), "Expanded palette exposes every preset as a button")
	var color: Color = Studio.PALETTE[35]
	studio._choose_color(color)
	t.assert_eq(studio.canvas.paint_color, color, "Chosen expanded color becomes the drawing color")
	t.assert_eq(studio.document.get_selected().color, color, "Chosen expanded color recolors the selected artwork")
	studio._color_dialog.hide()
	var saved: String = JSON.stringify(studio.document.serialize())
	t.assert_true(studio.save_drawing(false), "Studio saves the chosen scene, study and artwork together")
	studio._choose_scene("paper", false)
	studio._choose_mode("free")
	studio.document.clear()
	studio.canvas.select_kind("square")
	t.assert_true(studio.load_drawing(false), "Studio reloads a drawing with gallery settings")
	t.assert_false(studio.canvas.drawing_tool, "Restored selected artwork is ready for movement, resizing and rotation rather than creation")
	t.assert_eq(JSON.stringify(studio.document.serialize()), saved, "Studio save round trip restores artwork, colors, order, scene and mode")
	var invalid: Dictionary = studio.document.serialize()
	invalid.scene.masterpiece_id = "missing-study"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	t.assert_not_null(file, "Malformed scene test can open its isolated file")
	if file != null:
		file.store_string(JSON.stringify({"format": "quadrilateral-drawing", "version": 1, "document": invalid}))
		file.close()
		t.assert_false(studio.load_drawing(false), "Studio rejects unknown scene metadata")
		t.assert_eq(JSON.stringify(studio.document.serialize()), saved, "Rejected scene file leaves visible drawing and scene unchanged")
	studio.free()
	root.size = original_size
	root.content_scale_size = original_scale
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	await t.get_tree().process_frame

static func _entry_button(dialog: Window, text: String) -> Button:
	for node: Node in dialog.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text.ends_with(text):
			return button
	return null

static func _assert_preview_resources(t: Node, dialog: Window, entries: Array[Dictionary], masterpieces: bool) -> void:
	var shown: Dictionary = {}
	for node: Node in dialog.find_children("*", "TextureRect", true, false):
		var preview: TextureRect = node as TextureRect
		if preview.texture == null:
			continue
		var path: String = preview.texture.resource_path
		if path.begins_with("res://assets/generated/drawing/"):
			shown[path] = int(shown.get(path, 0)) + 1
	t.assert_eq(shown.size(), entries.size(), "Gallery displays one distinct artwork preview for every catalog choice")
	for entry: Dictionary in entries:
		var expected: String = str(entry.reference_path) if masterpieces else str(entry.path)
		t.assert_eq(shown.get(expected, 0), 1, "Gallery displays the correct preview exactly once: " + str(entry.id))

static func _assert_window_fits(t: Node, dialog: Window, window_size: Vector2i, message: String) -> void:
	t.assert_true(dialog.size.x <= window_size.x and dialog.size.y <= window_size.y, message)
	t.assert_true(dialog.position.x >= 0 and dialog.position.y >= 0, message + " without negative placement")
	t.assert_true(dialog.position.x + dialog.size.x <= window_size.x and dialog.position.y + dialog.size.y <= window_size.y, message + " including its bottom and right edges")

static func _assert_modal_delete_blocked(t: Node, studio: Studio) -> void:
	var before: String = JSON.stringify(studio.document.serialize())
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_DELETE
	key.pressed = true
	studio._unhandled_key_input(key)
	t.assert_eq(JSON.stringify(studio.document.serialize()), before, "Editing shortcuts cannot delete artwork behind an open chooser")

static func _frames(t: Node) -> void:
	for frame: int in range(3):
		await t.get_tree().process_frame
