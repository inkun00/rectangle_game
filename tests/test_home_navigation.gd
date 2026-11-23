class_name TestHomeNavigation
extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")


static func run(t: Node) -> void:
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	await t.get_tree().process_frame
	t.assert_true(app._home_screen.visible, "Application starts on the new home page")
	t.assert_eq(app.get_window().title, "사각이의 모험", "The normal game window uses the Korean title")
	t.assert_eq(ProjectSettings.get_setting("application/config/name"), "Quadrilateral World", "Existing saves retain their project directory")
	var has_title: bool = false
	for label: Label in app._home_screen.find_children("*", "Label", true, false):
		if label.text == "사각이의 모험": has_title = true
	t.assert_true(has_title, "The home page displays the exact Korean game title")
	var hero_picture: TextureRect = app._home_screen.find_child("OrbitalObservatoryBackground", true, false)
	t.assert_true(hero_picture != null and hero_picture.texture != null, "The home opens with the illustrated Sagaki panorama")
	var menu_sources: Array[String] = []
	for card: Node in app._home_screen._cards.get_children():
		var preview: TextureRect = card.find_child("ModePreview", true, false)
		t.assert_true(preview != null and preview.texture != null, "Every home destination has an illustration, including the unlocked ending")
		if preview == null or preview.texture == null: continue
		var source: String = preview.texture.resource_path
		t.assert_true(source.begins_with("res://assets/generated/home-atlas/"), "Menu cards use the original paper illustrations")
		t.assert_false(menu_sources.has(source), "Each destination can be recognized by its own artwork")
		menu_sources.append(source)
	t.assert_false(app._drawing_screen.visible, "Drawing studio is hidden before choosing it")
	t.assert_eq(_button(app._home_screen, "캐릭터 공방"), null, "Home has no custom character workshop entry")
	t.assert_false(app._world_hud.visible, "World HUD does not overlap the home page")
	t.assert_false(app._in_world, "Home page starts outside gameplay")
	t.assert_eq(_button(app._home_screen, "전시하기"), null, "Exhibitions are accessed inside their respective studios")
	var draw_button: Button = _button(app._home_screen, "그림 그리기")
	var adventure_button: Button = _button(app._home_screen, "마을 주민 심부름하기")
	var guide_button: Button = _button(app._home_screen, "도형 도감")
	t.assert_not_null(draw_button, "Home page offers the requested drawing entry button")
	t.assert_not_null(adventure_button, "Home page preserves a route to the existing adventure")
	t.assert_not_null(guide_button, "Home page provides the geometry reference")
	var initial_drawing: Dictionary = app._drawing_screen.document.serialize()
	_key(app, KEY_D, true)
	_key(app, KEY_DELETE)
	_key(app, KEY_Z, true)
	_key(app, KEY_Y, true)
	t.assert_eq(app._drawing_screen.document.serialize(), initial_drawing, "Home shortcuts cannot edit the drawing studio behind it")
	if draw_button != null:
		draw_button.pressed.emit()
	t.assert_true(app._drawing_screen.visible, "Actual drawing button opens the studio")
	t.assert_false(app._home_screen.visible, "Home page hides behind the drawing studio")
	t.assert_false(app._in_world, "Drawing studio is independent from RPG gameplay")
	t.assert_eq(app._drawing_screen.document.shapes.size(), 0, "Free drawing opens a blank document instead of the character template")
	var drawing_id: int = app._drawing_screen.document.add_shape("rectangle", Vector2(300, 220), Color("ef886c"))
	t.assert_gt(drawing_id, 0, "Independent drawing document accepts a quadrilateral")
	app._drawing_screen.canvas.select_kind("square")
	app._drawing_screen.canvas._press(Vector2(-200, -120))
	var drawing_data: Dictionary = app._drawing_screen.document.serialize()
	t.assert_true(app._drawing_screen.canvas._creating, "A drawing gesture can be pending when navigation is requested")
	app._drawing_screen.home_requested.emit()
	t.assert_true(app._home_screen.visible, "Drawing home action returns to the home page")
	t.assert_false(app._drawing_screen.visible, "Returning home hides the drawing screen")
	t.assert_false(app._drawing_screen.canvas._creating, "Leaving the drawing studio cancels an unfinished creation gesture")
	if adventure_button != null:
		adventure_button.pressed.emit()
	t.assert_false(app._home_screen.visible, "Adventure entry hides the home page")
	t.assert_false(app._drawing_screen.visible, "Adventure entry keeps the free drawing screen hidden")
	t.assert_eq(app._drawing_screen.document.serialize(), drawing_data, "Adventure entry preserves independent free artwork")
	t.assert_true(app._in_world, "The primary village button enters the world immediately")
	t.assert_true(app._level_label.text.contains("사각이"), "The village HUD identifies the story protagonist")
	t.assert_true(app.world.visible, "Entering gameplay shows the world")
	t.assert_false(app._home_screen.visible, "Home page is hidden during gameplay")
	t.assert_false(app._drawing_screen.visible, "Drawing studio is hidden during gameplay")
	t.assert_true(app.world.camera.enabled, "Gameplay uses the world camera")
	app.world.player.position = Vector2(700, QuadrilateralWorld.GROUND_Y)
	app.world.player.velocity = Vector2.ZERO
	app.world.player.begin_attack()
	app._show_inventory()
	app._show_home()
	await t.get_tree().process_frame
	t.assert_false(is_instance_valid(app._modal_overlay), "Navigating home closes an existing gameplay modal")
	t.assert_true(app._home_screen.visible, "Gameplay can return to the home page")
	t.assert_false(app._in_world, "Returning home leaves active gameplay")
	t.assert_false(app.world.visible, "World is hidden behind the home page")
	t.assert_false(app._world_hud.visible, "World HUD is hidden behind the home page")
	t.assert_false(app.world.controls_enabled, "Home page disables hidden world controls")
	t.assert_false(app.world.player.controls_enabled, "Home page disables hidden player controls")
	t.assert_false(app.world.camera.enabled, "World camera is disabled so the home page stays in UI coordinates")
	var paused_position: Vector2 = app.world.player.position
	var paused_cooldown: float = app.world.player.attack_cooldown
	for frame: int in range(3):
		await t.get_tree().physics_frame
	t.assert_eq(app.world.player.position, paused_position, "Hidden world physics stay paused while home is open")
	t.assert_eq(app.world.player.attack_cooldown, paused_cooldown, "Hidden world combat timers stay paused while home is open")
	if guide_button != null:
		guide_button.pressed.emit()
	t.assert_true(is_instance_valid(app._modal_overlay), "Actual home reference button opens the geometry guide")
	app._close_modal()
	t.assert_false(app.world.controls_enabled, "Closing a home reference modal cannot resume hidden gameplay")
	app._show_drawing()
	app._drawing_screen.canvas._release(Vector2(-100, -50))
	t.assert_eq(app._drawing_screen.document.serialize(), drawing_data, "Drawing survives a home and adventure round trip")
	t.assert_eq(app._drawing_screen.document.shapes.size(), 1, "A release after reopening cannot commit the cancelled drawing gesture")
	t.assert_false(app.world.camera.enabled, "Drawing screen also leaves the hidden gameplay camera disabled")
	t.assert_false(app.world.controls_enabled, "Drawing screen also leaves the hidden world paused")
	app._enter_world()
	t.assert_true(app.world.controls_enabled, "Returning to the village restores gameplay controls")
	t.assert_true(app.world.player.controls_enabled, "Returning to gameplay restores live player controls")
	t.assert_true(app.world.camera.enabled, "Returning to gameplay restores the world camera")
	t.assert_eq(app.world.player.position, paused_position, "Returning to gameplay preserves the player's prior location")
	t.assert_eq(app._drawing_screen.document.serialize(), drawing_data, "Gameplay reentry still preserves the independent free drawing")
	app.free()
	await t.get_tree().process_frame


static func _button(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == text:
			return button
	return null


static func _key(app: QuadrilateralApp, keycode: Key, control: bool = false) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.ctrl_pressed = control
	key.pressed = true
	app._unhandled_key_input(key)
