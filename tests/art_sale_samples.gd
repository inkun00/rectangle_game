extends RefCounted

const COMMISSION_ID: String = "park_poster"

static func house(alternate: bool = false) -> DrawingDocument:
	var drawing: DrawingDocument = DrawingDocument.new()
	var wall_color: Color = Color("80cbd0") if alternate else Color("f1c36d")
	var roof_color: Color = Color("9f78ca") if alternate else Color.CORAL
	var trim_color: Color = Color("2867a0")
	drawing.add_sized_shape("rectangle", Vector2(0, 77), Vector2(710, 335), wall_color)
	drawing.add_sized_shape("trapezoid", Vector2(0, -145), Vector2(780, 125), roof_color)
	drawing.add_sized_shape("rectangle", Vector2(0, 120), Vector2(64, 120), trim_color)
	for x: float in [-95.0, 95.0]:
		drawing.add_sized_shape("square", Vector2(x, 38), Vector2(64, 64), trim_color)
	drawing.add_sized_shape("rectangle", Vector2(90, -200), Vector2(44, 80), roof_color)
	drawing.work_msec = DrawingDocument.REQUIRED_WORK_MSEC
	return drawing

static func poster(include_square: bool = true) -> DrawingDocument:
	var drawing: DrawingDocument = DrawingDocument.new()
	drawing.add_sized_shape("rectangle", Vector2.ZERO, Vector2(800, 440), Color.CORAL)
	for index: int in range(5):
		var square: bool = include_square and index == 0
		var size: Vector2 = Vector2(80, 80) if square else Vector2(100, 80)
		drawing.add_sized_shape("square" if square else "rectangle", Vector2(-240 + 120 * index, 0), size, Color.DARK_BLUE)
	drawing.work_msec = DrawingDocument.REQUIRED_WORK_MSEC
	return drawing
