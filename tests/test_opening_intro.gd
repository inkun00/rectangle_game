class_name TestOpeningIntro
extends RefCounted

const AppScene: PackedScene = preload("res://scenes/main/main.tscn")
const TEST_PATH: String = "user://test_opening_preference.cfg"


static func run(t: Node) -> void:
	_test_preferences(t)
	await _test_navigation(t)
	await _test_playback(t)


static func _test_preferences(t: Node) -> void:
	var preferences: OpeningPreferences = OpeningPreferences.new()
	t.assert_true(preferences.should_offer(false, PackedStringArray()), "A first-time visitor is offered the opening")
	t.assert_false(preferences.should_offer(true, PackedStringArray()), "Testing never opens the introduction automatically")
	for flag: String in ["--quad-preview-world", "--quad-preview-drawing", "--quad-preview-construction", "--quad-preview-opening"]:
		t.assert_false(preferences.should_offer(false, PackedStringArray([flag])), "Rendering previews bypass the automatic introduction")
	preferences.seen = true
	t.assert_false(preferences.should_offer(false, PackedStringArray()), "A dismissed or watched opening is not automatically repeated")
	t.assert_eq(preferences.save_file(TEST_PATH), OK, "Opening preferences can be stored separately from gameplay saves")
	var restored: OpeningPreferences = OpeningPreferences.new()
	t.assert_true(restored.load_file(TEST_PATH), "Opening preferences load from their own config file")
	t.assert_true(restored.seen, "Viewing preference survives a round trip")
	var invalid: ConfigFile = ConfigFile.new()
	invalid.set_value("opening", "version", 1)
	invalid.set_value("opening", "seen", "true")
	invalid.save(TEST_PATH)
	t.assert_false(restored.load_file(TEST_PATH), "A string cannot replace the boolean viewing preference")
	t.assert_true(restored.seen, "Invalid preferences preserve the current state")
	invalid.set_value("opening", "version", 2)
	invalid.set_value("opening", "seen", false)
	invalid.save(TEST_PATH)
	t.assert_false(restored.load_file(TEST_PATH), "Unsupported opening preference versions are rejected")
	DirAccess.remove_absolute(TEST_PATH)
	t.assert_false(restored.load_file(TEST_PATH), "Missing opening preferences are safe")


static func _test_navigation(t: Node) -> void:
	var saved_preference: String = _preference_contents()
	var app: QuadrilateralApp = AppScene.instantiate()
	app.testing = true
	t.add_child(app)
	await t.get_tree().process_frame
	t.assert_true(app._home_screen.visible, "Testing still starts on the established home page")
	t.assert_false(is_instance_valid(app._opening_screen), "Test startup does not create an opening overlay")
	var replay: Button = _find_button(app._home_screen, "오프닝 다시 보기")
	t.assert_not_null(replay, "Home offers an opening replay action")
	app.document.fill_example()
	app.document.select_shape(int(app.document.shapes[0].id))
	var character: Dictionary = app.document.serialize()
	var history: int = app.document.command_manager.undo_stack.size()
	app._show_drawing()
	app._drawing_screen.document.add_shape("rectangle", Vector2.ZERO, Color.CORAL)
	app._drawing_screen.canvas.select_kind("square")
	app._drawing_screen.canvas._press(Vector2(-200, -120))
	var drawing: Dictionary = app._drawing_screen.document.serialize()
	var building: Dictionary = app._construction_screen.state.serialize()
	t.assert_true(app._drawing_screen.canvas._creating, "Opening navigation is exercised during an unfinished drawing gesture")
	app._show_opening()
	await t.get_tree().process_frame
	t.assert_false(app._drawing_screen.canvas._creating, "Entering the opening cancels a pending drawing gesture")
	t.assert_false(app._drawing_screen.visible, "The opening hides the active drawing studio")
	t.assert_false(app._home_screen.visible, "The introduction owns the screen")
	t.assert_false(app._tutorial.active, "Mode tutorials are dismissed while the opening owns input")
	t.assert_eq(app._opening_screen.playback_state, OpeningIntro.PlaybackState.READY, "Replay waits for a user gesture instead of autoplaying audio")
	t.assert_eq(app._opening_screen._player.stream, null, "The movie is loaded only when the viewer chooses to begin")
	t.assert_true(app._opening_screen._start_button.has_focus(), "The opening starts with keyboard focus on the play action")
	var delete_key: InputEventKey = InputEventKey.new()
	delete_key.keycode = KEY_DELETE
	delete_key.pressed = true
	app._unhandled_key_input(delete_key)
	t.assert_eq(app.document.serialize(), character, "Opening input cannot delete hidden character parts")
	app._opening_screen._sound_button.pressed.emit()
	t.assert_false(app._sound.sound_enabled, "Opening sound controls respect the shared audio setting")
	app._opening_screen._skip_button.pressed.emit()
	t.assert_true(app._home_screen.visible, "Skipping the opening returns to home")
	t.assert_false(is_instance_valid(app._opening_screen), "Skipping releases the opening player")
	t.assert_true(app._home_screen._learning_button.has_focus(), "Home focus is restored after the opening")
	t.assert_true(app._opening_preferences.seen, "Explicit skipping counts as dismissing the first-use offer")
	t.assert_eq(_preference_contents(), saved_preference, "Testing never modifies the real viewing preference")
	t.assert_eq(app.document.serialize(), character, "Skipping does not change assembled character data")
	t.assert_eq(app.document.command_manager.undo_stack.size(), history, "Opening navigation adds no artwork undo commands")
	t.assert_eq(app._drawing_screen.document.serialize(), drawing, "Opening navigation preserves free artwork")
	t.assert_eq(app._construction_screen.state.serialize(), building, "Opening navigation preserves construction progress")
	if replay != null: replay.pressed.emit()
	t.assert_true(is_instance_valid(app._opening_screen), "The actual home replay button opens a fresh introduction")
	t.assert_false(app._opening_screen.sound_enabled, "Replay preserves the previous sound choice")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	app._input(escape)
	t.assert_true(app._home_screen.visible, "Escape safely dismisses the first-use play gate")
	app._opening_preferences.seen = false
	app._show_opening()
	app._opening_screen.video_path = "res://assets/video/missing-opening-test.ogv"
	app._opening_screen._start_button.pressed.emit()
	t.assert_true(app._home_screen.visible, "Unavailable video returns safely to home")
	t.assert_false(app._opening_preferences.seen, "An unavailable video is not marked as watched")
	t.assert_false(is_instance_valid(app._opening_screen), "Unavailable video releases the playback controls")
	t.assert_eq(_preference_contents(), saved_preference, "Missing-video fallback in tests writes no real preferences")
	app._show_workshop()
	app._enter_world()
	app._show_opening()
	t.assert_false(app._in_world, "Opening replay leaves active gameplay")
	t.assert_false(app.world.controls_enabled, "Opening replay disables world controls")
	t.assert_eq(app.world.process_mode, Node.PROCESS_MODE_DISABLED, "The world remains paused during opening playback")
	t.assert_false(app.world.camera.enabled, "Opening UI is independent of the world camera")
	app._show_home()
	t.assert_false(is_instance_valid(app._opening_screen), "Direct navigation also releases any opening player")
	t.assert_false(app.world.controls_enabled, "Returning home after replay cannot resume hidden gameplay")
	app.free()
	await t.get_tree().process_frame


static func _test_playback(t: Node) -> void:
	if not ResourceLoader.exists(OpeningIntro.VIDEO_PATH, "VideoStream"):
		print("[Opening] Playback checks await the rendered .ogv; missing-video fallback was verified.")
		return
	var intro: OpeningIntro = OpeningIntro.new()
	var closing: Array[String] = []
	intro.closed.connect(func(reason: String): closing.append(reason))
	t.add_child(intro)
	intro._start_button.pressed.emit()
	await t.get_tree().process_frame
	t.assert_eq(intro.playback_state, OpeningIntro.PlaybackState.PLAYING, "The actual movie starts after pressing the play button")
	t.assert_not_null(intro._player.stream, "The rendered movie is loaded as a native Godot video resource")
	t.assert_true(intro._player.is_playing(), "The native VideoStreamPlayer starts playback")
	t.assert_false(intro._gate.visible, "The start gate clears from the movie image")
	intro._pause_button.pressed.emit()
	t.assert_eq(intro.playback_state, OpeningIntro.PlaybackState.PAUSED, "Pause changes the playback state")
	t.assert_true(intro._player.paused, "Pause reaches the actual video player")
	var space: InputEventKey = InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	t.assert_true(intro.handle_key(space), "Space is consumed by the opening controls")
	t.assert_false(intro._player.paused, "Space resumes paused video")
	intro._sound_button.pressed.emit()
	t.assert_lt(intro._player.volume_db, -60.0, "Mute changes the actual movie audio volume")
	intro._player.finished.emit()
	t.assert_eq(closing, ["completed"], "Natural video completion emits its completion reason")
	t.assert_eq(intro.playback_state, OpeningIntro.PlaybackState.CLOSED, "Natural completion ends the player")
	t.assert_eq(intro._player.stream, null, "Completed video releases its stream")
	intro.finish("skipped")
	t.assert_eq(closing.size(), 1, "Repeated finish events cannot close the opening twice")
	intro.free()
	await t.get_tree().process_frame


static func _preference_contents() -> String:
	return FileAccess.get_file_as_string(OpeningPreferences.SAVE_PATH) if FileAccess.file_exists(OpeningPreferences.SAVE_PATH) else "<absent>"


static func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child: Node in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null: return found
	return null
