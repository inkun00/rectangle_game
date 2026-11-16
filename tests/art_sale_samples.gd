extends RefCounted

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
