class_name CharacterPreview
extends Control
var parts: Array = []
var animated: bool = true
var _clock: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(150, 220)

func set_character(data: Dictionary) -> void:
	parts = data.get("parts", [])
	queue_redraw()

func _process(delta: float) -> void:
	if animated:
		_clock += delta
		queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * Vector2(0.5, 0.48)
	draw_texture_rect(GameArt.panel_texture(3), Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.3))
	if parts.is_empty():
		draw_string(QuadTheme.FONT, center + Vector2(-49, 5), "나만의 친구", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, QuadTheme.MUTED)
		return
	var bounds: Rect2 = _bounds()
	var fit: float = minf((size.x - 42.0) / maxf(bounds.size.x, 1.0), (size.y - 42.0) / maxf(bounds.size.y, 1.0))
	for part: Dictionary in parts:
		var poly: PackedVector2Array = PackedVector2Array()
		var pos: Vector2 = part.get("position", Vector2.ZERO)
		var group: String = part.get("group", "body")
		var phase: float = -1.0 if group.ends_with("left") else 1.0
		var angle: float = sin(_clock * 3.5) * 0.06 * phase if "arm" in group or "leg" in group else 0.0
		for vertex: Vector2 in part.get("vertices", PackedVector2Array()):
			poly.append(center + (pos + vertex.rotated(angle) - bounds.get_center()) * fit + Vector2(0, sin(_clock * 2.0) * 2.0))
		if poly.size() != 4: continue
		draw_colored_polygon(poly, part.get("color", QuadTheme.TEAL))
		var outline: PackedVector2Array = poly.duplicate()
		outline.append(poly[0])
		draw_polyline(outline, Color("294b50"), 1.8, true)

func _bounds() -> Rect2:
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for part: Dictionary in parts:
		var pos: Vector2 = part.get("position", Vector2.ZERO)
		for v: Vector2 in part.get("vertices", PackedVector2Array()):
			if first:
				bounds = Rect2(pos + v, Vector2.ZERO)
				first = false
			else: bounds = bounds.expand(pos + v)
	return bounds
