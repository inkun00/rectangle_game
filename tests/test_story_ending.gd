class_name TestStoryEnding
extends RefCounted

const Ending: GDScript = preload("res://scenes/ui/story_ending.gd")


static func run(t: Node) -> void:
	var image: Image = Image.create_empty(960, 600, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(310, 194, 271, 173), Color.CORAL)
	var png: PackedByteArray = image.save_png_to_buffer()
	var rejected: StoryEnding = Ending.new()
	t.assert_false(rejected.configure("other", png), "Only the two authored story endings can be played")
	t.assert_false(rejected.configure("earth", PackedByteArray([1, 2, 3])), "Missing image bytes cannot open an ending")
	t.assert_false(rejected.configure("earth", Image.create_empty(24, 24, false, Image.FORMAT_RGBA8).save_png_to_buffer()), "The ending rejects an image with unexpected dimensions")
	t.assert_false(rejected.configure("space", Image.create_empty(960, 600, false, Image.FORMAT_RGBA8).save_png_to_buffer()), "Fully transparent art cannot open an ending")
	rejected.free()
	var window: Window = t.get_tree().root
	var original_size: Vector2i = window.size
	var original_scale: Vector2i = window.content_scale_size
	window.size = Vector2i(800, 600)
	window.content_scale_size = window.size
	for ending_branch: String in ["earth", "space"]:
		var ending: StoryEnding = Ending.new()
		t.assert_true(ending.configure(ending_branch, png, "내가 완성한 작품", "https://padlet.com.attacker.example/post"), "Both endings accept the finished artwork snapshot")
		t.add_child(ending)
		await t.get_tree().process_frame
		t.assert_eq(ending._stage.artwork.get_size(), Vector2(271, 173), "The visible artwork is cropped to fill its cinematic shot")
		t.assert_eq(ending._stage.artwork.get_image().get_pixel(100, 50), image.get_pixel(410, 244), "The cinematic draws actual saved pixels")
		t.assert_true(ending._pause_button.has_focus(), "Playback starts with a keyboard control focused")
		ending.toggle_pause()
		var time: float = ending.elapsed
		await t.get_tree().process_frame
		t.assert_eq(ending.elapsed, time, "Pausing the scene freezes the cinematic clock")
		ending.toggle_pause()
		ending._process(5.0)
		t.assert_true(ending._subtitle.text.contains("우주선" if ending_branch == "space" else "집을 지으면서"), "The middle scene describes the chosen path")
		ending._skip_button.pressed.emit()
		await t.get_tree().process_frame
		t.assert_true(ending.finished and ending._home_button.visible and ending._replay_button.visible, "Skipping reveals the final scene and both navigation actions")
		t.assert_true(ending._subtitle.text.contains("내가 완성한 작품"), "The completed work's own title appears in the final scene")
		t.assert_false(ending._padlet_button.visible, "An untrusted URL is not offered as a Padlet post")
		ending.set_post_url("https://padlet.com/example/board")
		await t.get_tree().process_frame
		t.assert_true(ending._padlet_button.visible, "A successful upload can enable the board action after the ending opens")
		var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(window.size))
		for button: Button in [ending._home_button, ending._replay_button, ending._padlet_button]:
			t.assert_true(bounds.encloses(button.get_global_rect()), "Each ending action remains reachable at 800×600")
		ending._replay_button.pressed.emit()
		t.assert_true(not ending.finished and is_zero_approx(ending.elapsed) and ending._skip_button.visible, "Replay starts a fresh playback of the same finished art")
		ending._process(Ending.DURATION + 1.0)
		t.assert_true(ending.finished and not ending.is_processing(), "Natural playback completion stops processing")
		var closed: Array[bool] = []
		ending.home_requested.connect(func() -> void: closed.append(true))
		ending._home_button.pressed.emit()
		t.assert_eq(closed.size(), 1, "The ending hands navigation back to the application")
		ending.free()
	window.size = original_size
	window.content_scale_size = original_scale
	await t.get_tree().process_frame
