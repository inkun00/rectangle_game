class_name ConstructionExporter
extends RefCounted

const Document = preload("res://scripts/construction/construction_document.gd")
const Awards = preload("res://scripts/construction/construction_awards.gd")
const IMAGE_SIZE: Vector2i = Vector2i(1200, 800)

## The award must come from a validated completed record. Unsettled drafts pass {}.
## Only actual house parts, a quiet paper ground and its earned badge are rendered.
static func export_png(tree: SceneTree, document: Document, award: Dictionary = {}) -> PackedByteArray:
	if DisplayServer.get_name() == "headless" or document == null or document.parts.is_empty() or not Document._valid_parts(document.parts):
		return PackedByteArray()
	var awarded: bool = Awards.is_awarded(award)
	var badge_asset: String = Awards.badge_path(int(award.tier)) if awarded else ""
	if awarded and not ResourceLoader.exists(badge_asset):
		return PackedByteArray()
	var viewport: SubViewport = SubViewport.new()
	viewport.size = IMAGE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var paper: ColorRect = ColorRect.new()
	paper.color = Color("f8f9f5")
	paper.size = Vector2(IMAGE_SIZE)
	viewport.add_child(paper)
	var plate: HousePlate = HousePlate.new()
	plate.document = Document.new()
	plate.document.parts = document.parts.duplicate(true)
	plate.document.selected_id = -1
	plate.editing_enabled = false
	plate.presentation_mode = true
	plate.show_grid = false
	plate.drawing_tool = false
	plate.position = Vector2(180, 24) if awarded else Vector2(24, 24)
	plate.size = Vector2(996, 752) if awarded else Vector2(1152, 752)
	viewport.add_child(plate)
	plate.fit_parts()
	if awarded:
		var badge: TextureRect = TextureRect.new()
		# Ignore the large source bitmap's natural minimum before assigning it.
		# Otherwise size is clamped to the native pixels before shrink is enabled.
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.texture = load(badge_asset) as Texture2D
		badge.position = Vector2(18, 18)
		badge.size = Vector2(148, 148)
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		viewport.add_child(badge)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var bytes: PackedByteArray = viewport.get_texture().get_image().save_png_to_buffer()
	viewport.queue_free()
	return bytes

class HousePlate extends "res://scenes/construction/construction_canvas.gd":
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		clip_contents = true

	func _draw() -> void:
		if document == null:
			return
		for part: Dictionary in document.parts:
			_draw_part(part, Transform2D(0.0, Vector2(part.position)), false)
