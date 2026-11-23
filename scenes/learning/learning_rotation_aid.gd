extends VBoxContainer

const Geometry = preload("res://scripts/core/quadrilateral_math.gd")

class PaperPreview extends Control:
	var figure: String = "rectangle"
	var paper_angle: float = 0.0:
		set(value):
			paper_angle = value
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#203845"))
		var scale_factor: float = minf((size.y - 12.0) / 144.0, (size.x - 12.0) / 144.0)
		var center: Vector2 = size * 0.5
		draw_set_transform(center + Vector2(0, 2), paper_angle, Vector2.ONE * scale_factor)
		draw_rect(Rect2(-56, -40, 112, 80), Color("#102831"))
		draw_set_transform(center, paper_angle, Vector2.ONE * scale_factor)
		draw_rect(Rect2(-56, -40, 112, 80), Color("#ffefd4"))
		if figure == "parallel":
			for x: int in range(-40, 41, 10):
				draw_line(Vector2(x, -17), Vector2(x, 17), Color("#c09764"), 3.5, true)
			for y: int in [-13, 13]:
				draw_line(Vector2(-46, y), Vector2(46, y), Color("#205d70"), 3.0, true)
		else:
			var points: PackedVector2Array = Geometry.create_vertices(figure, Vector2(80, 44))
			draw_colored_polygon(points, Color("#99d4bf"))
			var outline: PackedVector2Array = points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, Color("#205d70"), 2.5, true)
			# The dot identifies the same corner as the learner turns the paper.
			draw_circle(points[0], 3.3, Color("#aa512d"), true, -1, true)
		draw_set_transform(Vector2.ZERO)

var steps: int = 0
var _figure: String = "rectangle"
var _preview: PaperPreview
var _angle_label: Label
var _turn_button: Button
var _reset_button: Button
var _motion: Tween

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview = PaperPreview.new()
	_preview.custom_minimum_size.y = 128
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview)
	var controls: HFlowContainer = HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 8)
	add_child(controls)
	_turn_button = QuadTheme.button("45° 돌리기", _turn)
	_turn_button.name = "RotatePaperTurn"
	controls.add_child(_turn_button)
	_reset_button = QuadTheme.button("처음 위치", _reset)
	_reset_button.name = "RotatePaperReset"
	controls.add_child(_reset_button)
	_angle_label = QuadTheme.label("", 15, QuadTheme.MUTED)
	_angle_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls.add_child(_angle_label)
	_reset()

func configure(question: Dictionary) -> void:
	_figure = str(question.get("paper_figure", "rectangle"))
	if is_instance_valid(_preview): _reset()

func _turn() -> void:
	steps = (steps + 1) % 8
	if is_instance_valid(_motion): _motion.kill()
	var target: float = deg_to_rad(45.0 * steps)
	# Continue clockwise as the displayed count wraps from 315° to 0°.
	var current: float = fposmod(_preview.paper_angle, TAU)
	if target < current: target += TAU
	_preview.paper_angle = current
	_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_preview, "paper_angle", target, 0.18)
	_angle_label.text = "돌린 각 %d°" % (steps * 45)

func _reset() -> void:
	if is_instance_valid(_motion): _motion.kill()
	steps = 0
	_preview.figure = _figure
	_preview.paper_angle = 0.0
	_angle_label.text = "돌린 각 0°"

func focus_controls() -> Array[Control]:
	return [_turn_button, _reset_button]
