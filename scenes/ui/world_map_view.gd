class_name WorldMapView
extends Control

var points: Array[Dictionary] = []
var player_x: float = 0.0
var target_x: float = -1.0

func _ready() -> void:
	custom_minimum_size = Vector2(500, 308)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var width: float = size.x - 44.0
	for row: int in range(2):
		var top: float = float(row) * 156.0
		var start: float = 0.0 if row == 0 else 5200.0
		var finish: float = 5200.0 if row == 0 else QuadrilateralWorld.WORLD_WIDTH
		var x_scale: float = width / (finish - start)
		draw_texture_rect(GameArt.sheet("world_backdrop" if row == 0 else "expansion_backdrop"), Rect2(0, top, size.x, 146), false, Color(1, 1, 1, 0.85))
		draw_texture_rect(GameArt.cell("environment_atlas", 9, 4, 3), Rect2(22, top + 82, width, 10), false)
		for p: Dictionary in points:
			var px: float = Vector2(p["position"]).x
			if px < start or px >= finish: continue
			var x: float = 22 + (px - start) * x_scale
			draw_texture_rect(GameArt.item(7), Rect2(x - 6, top + 78, 12, 12), false)
		for region: Dictionary in QuadrilateralWorld.REGION_DATA:
			var region_start: float = float(region["start"])
			if region_start < start or region_start >= finish: continue
			var center: float = (region_start + float(region["end"])) * 0.5
			var name_text: String = str(region["name"])
			var text_width: float = QuadTheme.FONT.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(QuadTheme.FONT, Vector2(22 + (center - start) * x_scale - text_width * 0.5, top + 128), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("fff0cb"))
		if player_x >= start and player_x < finish:
			_draw_marker(22 + (player_x - start) * x_scale, top + 54, "나", 15)
		if target_x >= start and target_x < finish:
			_draw_marker(22 + (target_x - start) * x_scale, top + 82, "목표", 9)

func _draw_marker(x: float, y: float, text: String, icon: int) -> void:
	draw_texture_rect(GameArt.item(icon), Rect2(x - 12, y - 12, 24, 24), false)
	draw_string_outline(QuadTheme.FONT, Vector2(x - 12, y - 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, QuadTheme.INK)
	draw_string(QuadTheme.FONT, Vector2(x - 12, y - 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("fff0cb"))
