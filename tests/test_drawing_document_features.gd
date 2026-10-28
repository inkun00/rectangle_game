class_name TestDrawingDocumentFeatures
extends RefCounted

const Model = preload("res://scripts/core/drawing_document.gd")
const Catalog = preload("res://scripts/core/drawing_catalog.gd")

static func run(t: Node) -> void:
	_test_atomic_transforms(t)
	_test_scene_history(t)
	_test_scene_restore(t)

static func _test_atomic_transforms(t: Node) -> void:
	for kind: String in QuadrilateralMath.KINDS:
		var document: Model = Model.new()
		document.add_sized_shape(kind, Vector2(-120, 10), Vector2(70, 60), Color.CORAL)
		var original: Dictionary = document.get_selected()
		var lengths: PackedFloat32Array = QuadrilateralMath.side_lengths(original.vertices)
		var transformed: PackedVector2Array = QuadrilateralMath.rotate_vertices(QuadrilateralMath.scale_vertices(original.vertices, 1.7), 37.0)
		var history: int = document.command_manager.undo_stack.size()
		document.transform_selected(transformed, Vector2(170, 80))
		var selected: Dictionary = document.get_selected()
		t.assert_eq(document.command_manager.undo_stack.size(), history + 1, "Resize and center movement commit once: " + kind)
		t.assert_true(QuadrilateralMath.matches_kind(selected.vertices, kind), "Pointer transform preserves chosen family: " + kind)
		t.assert_true(QuadrilateralMath.is_valid(selected.vertices), "Pointer transform stays finite, convex and nondegenerate: " + kind)
		var actual_lengths: PackedFloat32Array = QuadrilateralMath.side_lengths(selected.vertices)
		for index: int in range(4):
			t.assert_float_approx(actual_lengths[index] / lengths[index], 1.7, 0.001, "Pointer transform preserves every side ratio: " + kind)
		var angle_sum: float = 0.0
		for angle: float in QuadrilateralMath.angles_degrees(selected.vertices):
			angle_sum += angle
		t.assert_float_approx(angle_sum, 360.0, 0.01, "Transformed artwork has quadrilateral angle sum")
		document.undo()
		t.assert_eq(document.get_selected(), original, "Undo restores both geometry and position: " + kind)
		document.redo()
		t.assert_eq(document.get_selected(), selected, "Redo restores complete pointer result: " + kind)
		history = document.command_manager.undo_stack.size()
		document.transform_selected(selected.vertices, selected.position)
		t.assert_eq(document.command_manager.undo_stack.size(), history, "Zero-length gesture does not create an undo entry")
		var bad_variants: Array[PackedVector2Array] = [
			QuadrilateralMath.scale_vertices(selected.vertices, 0.001),
			QuadrilateralMath.scale_vertices(selected.vertices, 100.0),
			PackedVector2Array([Vector2(0, 0), Vector2(30, 30), Vector2(0, 30), Vector2(30, 0)]),
			PackedVector2Array([Vector2(INF, 0), Vector2(30, 0), Vector2(30, 30), Vector2(0, 30)])
		]
		for invalid: PackedVector2Array in bad_variants:
			document.transform_selected(invalid, Vector2.ZERO)
			t.assert_eq(document.get_selected(), selected, "Invalid or unreachable geometry leaves artwork unchanged: " + kind)
		document.transform_selected(selected.vertices, Vector2(NAN, 0))
		t.assert_eq(document.get_selected(), selected, "Nonfinite transformation position is rejected")
		t.assert_eq(document.command_manager.undo_stack.size(), history, "Rejected pointer transforms retain undo history")
		document.transform_selected(selected.vertices, Vector2(9000, -9000))
		var bounds: Rect2 = QuadrilateralMath.bounds(document.get_selected().vertices)
		bounds.position += Vector2(document.get_selected().position)
		t.assert_true(Model.ARTBOARD.grow(0.01).encloses(bounds), "Transform position is fitted into artboard")

static func _test_scene_history(t: Node) -> void:
	var document: Model = Model.new()
	document.add_sized_shape("square", Vector2.ZERO, Vector2(60, 60), Color.GOLD)
	var artwork: Array[Dictionary] = document.ordered_shapes()
	var background: String = str(Catalog.backgrounds()[0].id)
	var masterpiece: String = str(Catalog.masterpieces()[0].id)
	t.assert_eq(document.background_id, "paper", "New artwork starts on plain paper")
	t.assert_eq(document.drawing_mode, "free", "New artwork starts in free drawing")
	t.assert_false(document.set_mode("masterpiece"), "A masterpiece must be chosen before entering fill mode")
	var history: int = document.command_manager.undo_stack.size()
	t.assert_true(document.set_background(background), "Catalog scenery can be selected")
	t.assert_eq(document.command_manager.undo_stack.size(), history + 1, "Background selection is undoable")
	document.undo()
	t.assert_eq(document.background_id, "paper", "Undo returns to paper")
	document.redo()
	t.assert_eq(document.background_id, background, "Redo restores background selection")
	t.assert_true(document.set_masterpiece(masterpiece), "A catalog masterpiece enables fill mode")
	t.assert_eq(document.drawing_mode, "masterpiece", "Choosing an outline activates its mode")
	t.assert_eq(document.masterpiece_id, masterpiece, "Chosen outline is stored")
	t.assert_eq(document.ordered_shapes(), artwork, "Changing scene preserves the user's artwork")
	document.undo()
	t.assert_eq(document.drawing_mode, "free", "Undo restores mode and outline together")
	t.assert_eq(document.masterpiece_id, "", "Undo releases the first outline")
	document.redo()
	t.assert_true(document.set_mode("free"), "Free drawing can resume after filling")
	t.assert_eq(document.masterpiece_id, masterpiece, "Leaving fill mode retains the chosen outline")
	document.undo()
	t.assert_eq(document.drawing_mode, "masterpiece", "Mode switch is undoable")
	history = document.command_manager.undo_stack.size()
	t.assert_false(document.set_background("missing-scene"), "Unknown background is rejected")
	t.assert_false(document.set_masterpiece("missing-painting"), "Unknown outline is rejected")
	t.assert_false(document.set_mode("invalid"), "Unknown drawing mode is rejected")
	t.assert_eq(document.command_manager.undo_stack.size(), history, "Rejected scene changes do not touch history")
	document.set_masterpiece(masterpiece)
	t.assert_eq(document.command_manager.undo_stack.size(), history, "Choosing the same outline does not add duplicate history")
	document.clear()
	t.assert_eq(document.masterpiece_id, masterpiece, "Clearing shapes keeps the selected outline")
	document.undo()
	t.assert_eq(document.ordered_shapes(), artwork, "Undo clear restores shapes and scene")

static func _test_scene_restore(t: Node) -> void:
	var document: Model = Model.new()
	document.add_sized_shape("rectangle", Vector2(100, 40), Vector2(100, 70), Color.TEAL)
	document.set_background(str(Catalog.backgrounds()[1].id))
	document.set_masterpiece(str(Catalog.masterpieces()[1].id))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(document.serialize()))
	var restored: Model = Model.new()
	t.assert_true(restored.restore(saved), "Scene metadata and four-vertex artwork restore together")
	t.assert_eq(JSON.stringify(restored.serialize()), JSON.stringify(document.serialize()), "Scene save round trip preserves complete drawing")
	var history: int = restored.command_manager.undo_stack.size()
	var before: String = JSON.stringify(restored.serialize())
	var invalid_scenes: Array[Variant] = [
		null,
		[],
		{},
		{"background_id": "unknown", "drawing_mode": "free", "masterpiece_id": ""},
		{"background_id": "paper", "drawing_mode": "unknown", "masterpiece_id": ""},
		{"background_id": "paper", "drawing_mode": "masterpiece", "masterpiece_id": ""},
		{"background_id": "paper", "drawing_mode": "free", "masterpiece_id": "unknown"},
		{"background_id": 12, "drawing_mode": "free", "masterpiece_id": ""}
	]
	for invalid_scene: Variant in invalid_scenes:
		var invalid: Dictionary = saved.duplicate(true)
		invalid.scene = invalid_scene
		t.assert_false(restored.restore(invalid), "Malformed scene metadata is rejected atomically")
		t.assert_eq(JSON.stringify(restored.serialize()), before, "Rejected scene save preserves live artwork and settings")
		t.assert_eq(restored.command_manager.undo_stack.size(), history, "Rejected scene save preserves history")
	var invalid_geometry: Dictionary = saved.duplicate(true)
	invalid_geometry.shapes[0].vertices = [[0, 0], [1, 1], [2, 2], [3, 3]]
	t.assert_false(restored.restore(invalid_geometry), "Valid scene cannot hide corrupt geometry")
	t.assert_eq(JSON.stringify(restored.serialize()), before, "Geometry rejection also preserves scene settings")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("scene")
	t.assert_true(restored.restore(legacy), "Earlier v1 drawings without scenes still load")
	t.assert_eq(restored.background_id, "paper", "Earlier v1 drawings migrate to paper")
	t.assert_eq(restored.drawing_mode, "free", "Earlier v1 drawings migrate to free mode")
	t.assert_eq(restored.masterpiece_id, "", "Earlier v1 drawings have no outline")
	t.assert_eq(restored.ordered_shapes(), document.ordered_shapes(), "Earlier v1 migration preserves artwork")
	restored.undo()
	t.assert_eq(JSON.stringify(restored.serialize()), before, "Undo restore recovers artwork and scene as one operation")
