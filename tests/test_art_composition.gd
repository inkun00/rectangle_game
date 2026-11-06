class_name TestArtComposition
extends RefCounted

const Composition = preload("res://scripts/economy/art_composition.gd")
const Drawing = preload("res://scripts/core/drawing_document.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")

static func house(alternate: bool = false) -> DrawingDocument:
	var drawing: DrawingDocument = Drawing.new()
	_add(drawing, "rectangle", Vector2(0, 60), Vector2(320, 240), Color("80cbd0") if alternate else Color("f1c36d"))
	_add(drawing, "trapezoid", Vector2(0, -110), Vector2(380, 100), Color("9f78ca") if alternate else Color.CORAL)
	_add(drawing, "rectangle", Vector2(0, 120), Vector2(64, 120), Color("2867a0"))
	for x: float in [-95.0, 95.0]: _add(drawing, "square", Vector2(x, 38), Vector2(64, 64), Color("2867a0"))
	_add(drawing, "rectangle", Vector2(90, -200), Vector2(44, 80), Color("9f78ca") if alternate else Color.CORAL)
	return drawing

static func tree() -> DrawingDocument:
	var drawing: DrawingDocument = Drawing.new()
	_add(drawing, "rectangle", Vector2(0, 105), Vector2(70, 230), Color("986238"))
	_add(drawing, "rhombus", Vector2(0, -70), Vector2(240, 200), Color("2f9257"))
	_add(drawing, "rhombus", Vector2(-115, -60), Vector2(220, 180), Color("2f9257"))
	_add(drawing, "rhombus", Vector2(115, -60), Vector2(220, 180), Color("2f9257"))
	_add(drawing, "square", Vector2(-90, -60), Vector2(42, 42), Color.CORAL)
	_add(drawing, "square", Vector2(90, -60), Vector2(42, 42), Color.CORAL)
	return drawing

static func robot() -> DrawingDocument:
	var drawing: DrawingDocument = Drawing.new()
	_add(drawing, "rectangle", Vector2(0, 35), Vector2(180, 210), Color("6cadd3"))
	_add(drawing, "rectangle", Vector2(0, -120), Vector2(160, 100), Color("6cadd3"))
	for x: float in [-120.0, 120.0]: _add(drawing, "rectangle", Vector2(x, 35), Vector2(60, 150), Color("6cadd3"))
	for x: float in [-55.0, 55.0]: _add(drawing, "rectangle", Vector2(x, 190), Vector2(60, 100), Color("6cadd3"))
	for x: float in [-42.0, 42.0]: _add(drawing, "square", Vector2(x, -120), Vector2(36, 36), Color("18394c"))
	return drawing

static func rocket() -> DrawingDocument:
	var drawing: DrawingDocument = Drawing.new()
	_add(drawing, "rectangle", Vector2.ZERO, Vector2(150, 250), Color("e3c074"))
	_add(drawing, "trapezoid", Vector2(0, -170), Vector2(165, 90), Color.CORAL)
	for x: float in [-112.0, 112.0]: _add(drawing, "parallelogram", Vector2(x, 65), Vector2(105, 170), Color("4a9fb0"))
	_add(drawing, "rectangle", Vector2(0, 160), Vector2(120, 70), Color.CORAL)
	_add(drawing, "square", Vector2(0, -50), Vector2(70, 70), Color("357d9d"))
	return drawing

static func geometric() -> DrawingDocument:
	# A rectangular subdivision: large left panel and five differently sized
	# right panels with shared horizontal and vertical boundaries.
	var drawing: DrawingDocument = Drawing.new()
	_add(drawing, "rectangle", Vector2(-100, 0), Vector2(240, 360), Color("c13f49"))
	_add(drawing, "rectangle", Vector2(140, -120), Vector2(240, 120), Color("eec94b"))
	_add(drawing, "rectangle", Vector2(80, 0), Vector2(120, 120), Color("f6f0dc"))
	_add(drawing, "rectangle", Vector2(200, 0), Vector2(120, 120), Color("29629a"))
	_add(drawing, "rectangle", Vector2(60, 120), Vector2(80, 120), Color("29629a"))
	_add(drawing, "rectangle", Vector2(180, 120), Vector2(160, 120), Color("f6f0dc"))
	return drawing

static func assess(drawing: DrawingDocument) -> Dictionary:
	return Composition.assess(drawing.ordered_shapes(), visible(drawing))

static func visible(drawing: DrawingDocument) -> Dictionary:
	var counts: Dictionary = {}
	var parts: Array[Dictionary] = drawing.ordered_shapes()
	for y: int in range(30):
		for x: int in range(48):
			var point: Vector2 = Drawing.ARTBOARD.position + Vector2(x * 20 + 10, y * 20 + 10)
			for index: int in range(parts.size() - 1, -1, -1):
				var part: Dictionary = parts[index]
				if Color(part.color).a < 0.5: continue
				if Math.contains_point(part.vertices, point - Vector2(part.position)):
					counts[index] = int(counts.get(index, 0)) + 1
					break
	return counts

static func run(t: Node) -> void:
	for pair: Array in [[house(), "집"], [tree(), "나무"], [robot(), "로봇"], [rocket(), "우주선"], [geometric(), "기하 구성"]]:
		var drawing: DrawingDocument = pair[0]
		var before: Dictionary = drawing.serialize()
		var history: int = drawing.command_manager.undo_stack.size()
		var result: Dictionary = assess(drawing)
		t.assert_true(bool(result.has_form), "Completed " + str(pair[1]) + " meets the construction rubric: " + str(result.reason))
		t.assert_true(str(result.subject).contains(str(pair[1])), "The rubric explains which structure was found: " + str(pair[1]))
		t.assert_eq(drawing.serialize(), before, "Assessment preserves the actual four-vertex artwork")
		t.assert_eq(drawing.command_manager.undo_stack.size(), history, "Assessment never changes Undo history")
		t.assert_true(not result.criteria.is_empty(), "Assessment exposes understandable requirements")
	var tiles: DrawingDocument = Drawing.new()
	for index: int in range(6): _add(tiles, "square", Vector2(-200 + (index % 3) * 200, -100 if index < 3 else 100), Vector2(140, 140), Color.CORAL if index % 2 == 0 else Color.BLUE)
	t.assert_false(bool(assess(tiles).has_form), "Six detached tiles do not form a saleable subject")
	var grid: DrawingDocument = Drawing.new()
	for index: int in range(6): _add(grid, "square", Vector2(-140 + (index % 3) * 140, -70 if index < 3 else 70), Vector2(140, 140), Color.CORAL if index % 2 == 0 else Color.BLUE)
	t.assert_false(bool(assess(grid).has_form), "Even touching equal tiles lack a large-medium-small composition")
	var row: DrawingDocument = Drawing.new()
	for index: int in range(6): _add(row, "rectangle", Vector2(-350 + index * 130, 0), Vector2(120, 150 - index * 15), Color.CORAL if index % 2 == 0 else Color.BLUE)
	t.assert_false(bool(assess(row).has_form), "One-dimensional rows cannot qualify as composed subdivisions")
	var blank_details: DrawingDocument = house()
	for index: int in [2, 3, 4]:
		blank_details.select_shape(int(blank_details.shapes[index].id))
		blank_details.set_color(Color(blank_details.shapes[0].color))
	t.assert_false(bool(assess(blank_details).has_form), "Same-color door and windows are not visible detail roles")
	var no_eyes: DrawingDocument = robot()
	for index: int in [6, 7]:
		no_eyes.select_shape(int(no_eyes.shapes[index].id))
		no_eyes.set_color(Color(no_eyes.shapes[1].color))
	t.assert_false(bool(assess(no_eyes).has_form), "Robot eyes need visible contrast with its head")
	var two_leaves: DrawingDocument = tree()
	two_leaves.select_shape(int(two_leaves.shapes[1].id))
	two_leaves.delete_selected()
	t.assert_false(bool(assess(two_leaves).has_form), "One leaf cannot fill both the middle and a side role")
	var leafy_tree: DrawingDocument = Drawing.new()
	_add(leafy_tree, "rectangle", Vector2(0, 105), Vector2(70, 230), Color("986238"))
	_add(leafy_tree, "rhombus", Vector2(0, -30), Vector2(240, 180), Color("2f9257"))
	for x: float in [-150.0, 150.0]: _add(leafy_tree, "rhombus", Vector2(x, -60), Vector2(220, 160), Color("2f9257"))
	for x: float in [-70.0, 70.0]: _add(leafy_tree, "rhombus", Vector2(x, -155), Vector2(200, 150), Color("2f9257"))
	t.assert_true(bool(assess(leafy_tree).has_form), "A full five-part canopy does not need fruit to form a tree")
	var shifted_roof: DrawingDocument = house()
	shifted_roof.select_shape(int(shifted_roof.shapes[1].id))
	shifted_roof.move_selected(Vector2(230, -110))
	t.assert_false(bool(assess(shifted_roof).has_form), "A disconnected roof no longer completes the house")
	var hidden: DrawingDocument = house()
	var counts: Dictionary = visible(hidden)
	counts[0] = 3
	t.assert_false(bool(Composition.assess(hidden.ordered_shapes(), counts).has_form), "A mostly obscured body cannot anchor a structure")
	counts = visible(hidden)
	counts[1] = 3
	t.assert_false(bool(Composition.assess(hidden.ordered_shapes(), counts).has_form), "Three exposed samples cannot turn a mostly hidden roof into a full role")
	var scattered: DrawingDocument = house()
	for index: int in range(10): _add(scattered, "square", Vector2(-400 + (index % 2) * 800, -240 + (index >> 1) * 115), Vector2(150, 100), Color.GREEN)
	t.assert_false(bool(assess(scattered).has_form), "A small completed house cannot justify dominant scattered fragments")
	var confetti_counts: Dictionary = visible(house())
	# Sub-threshold fragments cannot earn roles but must still contribute to the
	# picture's total visible area, otherwise hundreds of specks evade focus.
	for index: int in range(128): confetti_counts[index + 1000] = 2
	var confetti: Dictionary = Composition.assess(house().ordered_shapes(), confetti_counts)
	t.assert_false(bool(confetti.has_form), "Visible sub-threshold fragments remain in the focus denominator")
	var before_legacy: DrawingDocument = house()
	var malformed: Array[Dictionary] = before_legacy.ordered_shapes()
	malformed[0].vertices = PackedVector2Array()
	t.assert_false(bool(Composition.assess(malformed, visible(before_legacy)).has_form), "Invalid geometry never becomes a body role")
	var village: DrawingDocument = Drawing.new()
	for offset: Vector2 in [Vector2(-230, 70), Vector2(230, 70)]:
		for part: Dictionary in house().ordered_shapes():
			var bounds: Rect2 = Math.bounds(part.vertices)
			_add(village, str(part.kind), Vector2(part.position) * 0.65 + offset, bounds.size * 0.65, part.color)
	t.assert_true(bool(assess(village).has_form), "Two complete houses contribute their structural regions together")
	var forest: DrawingDocument = Drawing.new()
	for offset: Vector2 in [Vector2(-300, 40), Vector2(0, 40), Vector2(300, 40)]:
		for part: Dictionary in tree().ordered_shapes():
			var bounds: Rect2 = Math.bounds(part.vertices)
			_add(forest, str(part.kind), Vector2(part.position) * 0.65 + offset, bounds.size * 0.65, part.color)
	t.assert_true(bool(assess(forest).has_form), "Three legible smaller trees contribute their structural regions together")

static func _add(drawing: DrawingDocument, kind: String, position: Vector2, dimensions: Vector2, color: Color) -> void:
	drawing.add_sized_shape(kind, position, dimensions, color)
