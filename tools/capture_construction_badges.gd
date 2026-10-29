extends SceneTree

const Awards = preload("res://scripts/construction/construction_awards.gd")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1500, 400)
	root.content_scale_size = Vector2i(1500, 400)
	var paper: ColorRect = ColorRect.new()
	paper.color = Color("f8f4e9")
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(paper)
	for tier: int in range(1, 6):
		var badge: TextureRect = TextureRect.new()
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.texture = load(Awards.badge_path(tier)) as Texture2D
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.position = Vector2(22 + (tier - 1) * 300, 20)
		badge.size = Vector2(256, 280)
		root.add_child(badge)
		var name_label: Label = QuadTheme.label("%d단계 · %s" % [tier, Awards.title_for_tier(tier)], 19)
		name_label.position = Vector2((tier - 1) * 300, 326)
		name_label.size = Vector2(300, 36)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(name_label)
	for frame: int in range(5): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/previews/construction-game")
	root.get_texture().get_image().save_png("res://.godot/previews/construction-game/badges-construction-preview.png")
	print("Five architectural badge tiers rendered.")
	quit()
