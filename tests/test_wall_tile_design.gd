extends RefCounted

const Design = preload("res://scripts/core/wall_tile_design.gd")
const Geometry = preload("res://scripts/core/quadrilateral_math.gd")


static func run(t: Node) -> void:
	_test_free_editor(t)
	_test_group_editor(t)
	_test_snapping(t)
	_test_repetition(t)
	_test_commissions(t)
	_test_custom_palette(t)
	_test_legacy(t)
	_test_invalid_saves(t)
	_test_free_draft_ledger(t)


static func _test_custom_palette(t: Node) -> void:
	var design: Design = Design.new()
	var built_in_count: int = Design.PALETTE.size()
	design.add_piece("rectangle", Vector2(40, 40), 0)
	var old_save: Dictionary = design.to_dict()
	t.assert_false(old_save.has("custom_colors"), "Built-in-only saves keep the previous shape")
	t.assert_eq(design.add_palette_color(Design.PALETTE[0]), 0, "Adding a built-in shade reuses its original index")
	t.assert_eq(design.add_palette_color(Color(INF, 0.0, 0.0)), -1, "Nonfinite channels cannot be added")
	var color: Color = Color("#112233")
	var custom: int = design.add_palette_color(color)
	t.assert_eq(custom, built_in_count, "Picked colors append after the existing swatches")
	t.assert_eq(design.add_palette_color(Color(color.r + 0.001, color.g, color.b, 0.5)), custom, "Same RGB8 shade reuses one opaque swatch")
	var second: int = design.add_piece("rectangle", Vector2(90, 40), custom)
	t.assert_eq(design.wall_parts()[1].color, color, "New tile colors reach every repeated wall drawing")
	t.assert_true(design.color_pieces([0], custom), "Existing pieces can be painted with custom colors")
	design.finish_tile()
	t.assert_false(design.evaluate().ok, "Repeated use of a custom swatch counts as one shade")
	t.assert_true(design.undo(), "Undo restores the piece's prior paint")
	t.assert_eq(design.motif_parts()[0].color, Design.PALETTE[0], "Undo keeps the original built-in color")
	t.assert_eq(design.palette_index(color), custom, "Undo keeps the custom swatch available")
	design.finish_tile()
	t.assert_true(design.evaluate().ok, "A custom shade counts toward commission color requirements")
	t.assert_true(design.redo(), "Redo reapplies custom paint")
	t.assert_eq(design.motif_parts()[0].color, color, "Redo resolves the same custom shade")
	t.assert_true(design.set_color(second, 1), "Custom paint can be replaced with a built-in shade")

	var saved: Dictionary = JSON.parse_string(JSON.stringify(design.to_dict()))
	t.assert_eq(saved.custom_colors, ["112233"], "The custom palette stores opaque RGB hex strings")
	var loaded: Design = Design.new()
	t.assert_true(loaded.restore(saved), "A custom-color tile survives the JSON round trip")
	t.assert_eq(loaded.motif_parts(), design.motif_parts(), "Restored tiles retain their exact colors and indices")
	for invalid_palette: Variant in [null, ["112233ff"], ["zzzzzz"], ["112233", "112233"], ["F4E7CA"]]:
		var invalid: Dictionary = saved.duplicate(true)
		invalid.custom_colors = invalid_palette
		t.assert_false(loaded.restore(invalid), "Malformed or duplicate swatches cannot enter a live palette")
	var invalid_index: Dictionary = saved.duplicate(true)
	invalid_index.parts[0].palette_index = custom + 1
	t.assert_false(loaded.restore(invalid_index), "Saved pieces must reference an existing swatch")
	t.assert_eq(loaded.to_dict(), design.to_dict(), "Failed restores retain the artwork and its palette")
	t.assert_true(loaded.start_tile("garden"), "The player can start another commission tile")
	t.assert_eq(loaded.palette_index(color), custom, "A new tile reuses the draft's custom swatches")
	t.assert_true(loaded.restore(old_save), "Older V2 saves still restore without a custom palette")
	t.assert_eq(loaded.to_dict(), old_save, "Loading an older draft restores its original data")

	var full: Design = Design.new()
	for channel: int in range(Design.MAX_CUSTOM_COLORS):
		full.add_palette_color(Color8(channel, 0, 1))
	t.assert_eq(full.palette_size(), built_in_count + Design.MAX_CUSTOM_COLORS, "The palette holds the full number of custom shades")
	t.assert_eq(full.add_palette_color(Color8(42, 0, 1)), built_in_count + 42, "Existing custom colors stay selectable at capacity")
	t.assert_eq(full.add_palette_color(Color8(1, 0, 2)), -1, "At capacity the palette rejects an additional new swatch")
	var oversized: Dictionary = full.to_dict()
	oversized.custom_colors.append("010002")
	t.assert_false(loaded.restore(oversized), "A save cannot exceed the same custom-color limit")


static func _test_free_draft_ledger(t: Node) -> void:
	var ledger := ConstructionState.new()
	var old_save: Dictionary = ledger.serialize()
	var sites: Dictionary = ledger.free_wall_designs
	var first := Design.new()
	first.add_piece("square", Vector2(30, 40), 1)
	sites.harbor = first
	var second := Design.new()
	second.set_commission("garden")
	second.add_piece("trapezoid", Vector2(60, 50), 3)
	sites.garden = second
	t.assert_eq(ledger.saved_balance(), ConstructionState.INITIAL_BALANCE, "Free drafts never add commission income")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(ledger.serialize()))
	var loaded := ConstructionState.new()
	t.assert_true(loaded.restore(saved), "Separate free designs survive the JSON ledger round trip")
	t.assert_eq(loaded.free_wall_designs.harbor.to_dict(), first.to_dict(), "Harbor keeps its own shape and color")
	t.assert_eq(loaded.free_wall_designs.garden.to_dict(), second.to_dict(), "Garden keeps its distinct design")
	first.remove_piece(0)
	t.assert_true(ledger.restore(saved), "An in-place restore refreshes the open free tile and its location list")
	t.assert_true(sites.harbor == first and first.motif_parts().size() == 1, "The active free-editor model identity survives a full load")
	for invalid_field: String in ["site", "paid", "geometry", "type"]:
		var invalid: Dictionary = saved.duplicate(true)
		match invalid_field:
			"site": invalid.free_wall_designs.garden.commission = "library"
			"paid": invalid.free_wall_designs.garden.completed = ["garden"]
			"geometry": invalid.free_wall_designs.garden.parts[0].vertices = []
			"type": invalid.free_wall_designs = []
		t.assert_false(ledger.restore(invalid), "Broken or paid free designs are rejected")
		t.assert_eq(ledger.serialize(), loaded.serialize(), "A bad free draft does not modify either editor or wallet")
	first.add_piece("rectangle", Vector2(85, 60), 4)
	ledger.wall_design.add_piece("square", Vector2(25, 40), 2)
	ledger.wall_design.add_piece("square", Vector2(85, 40), 3)
	ledger.wall_design.finish_tile()
	t.assert_true(ProgressionTransactions.commit(ledger, "claim_wall_commission", null, "", false).ok, "Paid delivery can commit with two independent free sites")
	t.assert_true(first.can_undo() and ledger.wall_design.can_undo(), "A financial transaction preserves paid and free editor undo")
	t.assert_eq(ledger.saved_balance(), ConstructionState.INITIAL_BALANCE + int(Design.COMMISSIONS.harbor.reward), "Only the paid wall is credited")
	t.assert_true(ledger.restore(old_save) and sites.is_empty(), "Earlier saves without the free-draft collection start with an empty free studio")


static func _test_free_editor(t: Node) -> void:
	var design := Design.new()
	t.assert_eq(design.tile_size(), Vector2(150, 100), "New artists start with a blank rectangular tile")
	t.assert_true(design.motif_parts().is_empty(), "No shape or pattern is prescribed")
	t.assert_false(design.finish_tile(), "An empty tile is still a draft")
	for kind: String in Geometry.KINDS:
		var i: int = design.add_piece(kind, Vector2(60, 50), 1)
		t.assert_true(i >= 0, "All five quadrilateral families can be placed independently")
		t.assert_true(design.rotate_piece(i, 30), "A placed piece rotates around its own center")
		t.assert_true(design.mirror_piece(i), "A piece can be reflected independently")
		t.assert_true(design.resize_piece(i, 1.2), "Uniform resizing preserves the chosen family")
		t.assert_true(Geometry.matches_kind(design.motif_parts()[i].vertices, kind), "Transformed family is determined by actual vertices")
	var free: int = design.add_piece("freeform", Vector2(100, 60), 3)
	var before: PackedVector2Array = design.motif_parts()[free].vertices
	t.assert_true(design.set_vertex(free, 0, Vector2(80, 40)), "A freeform corner moves to a selected grid point")
	var changed: PackedVector2Array = design.motif_parts()[free].vertices
	for corner: int in [1, 2, 3]:
		t.assert_true(changed[corner].is_equal_approx(before[corner]), "The other three corners stay in place")
	t.assert_false(design.set_vertex(free, 0, changed[2]), "A crossed or collapsed freeform shape is rejected")
	t.assert_false(design.set_vertex(0, 0, Vector2.ZERO), "Family-constrained shapes cannot become irregular through vertex editing")
	t.assert_false(design.resize_piece(free, 100.0), "An oversized shape does not escape its tile")
	t.assert_eq(design.add_piece("triangle", Vector2.ZERO), -1, "Only quadrilateral pieces can be placed")
	t.assert_false(design.move_piece(free, Vector2(INF, NAN)), "Nonfinite movements are rejected")
	t.assert_true(design.move_piece(free, Vector2(888, 615)), "Dragging to an edge stops at the tile boundary")
	var moved: Dictionary = design.motif_parts()[free]
	t.assert_eq(design.hit_test(moved.position), free, "Hit testing finds the selected topmost piece")
	t.assert_true(Geometry.bounds(moved.vertices).end.is_equal_approx(design.tile_size()), "The full piece stays inside the right and bottom edges")
	t.assert_true(design.finish_tile(), "Two or more pieces can make a finished tile")
	t.assert_true(design.remove_piece(free), "Only the selected piece is removed")
	t.assert_false(design.finished, "Editing a completed tile makes it a draft again")
	t.assert_true(design.undo(), "Undo restores the removed piece")
	t.assert_eq(design.motif_parts()[free].vertices, moved.vertices, "Undo restores the same geometry")
	t.assert_true(design.redo(), "Redo removes it again")
	t.assert_true(design.undo(), "Undo is available after redo")
	t.assert_true(design.set_color(free, 2), "Paint only the chosen piece")
	t.assert_false(design.can_redo(), "A new edit starts a new history branch")
	var copy: Array[Dictionary] = design.motif_parts()
	copy[free].vertices[0] = Vector2(-100, -100)
	t.assert_true(Geometry.is_valid(design.motif_parts()[free].vertices), "Reference geometries cannot mutate the live drawing")
	t.assert_eq(design.motif_parts()[free].vertices, moved.vertices, "Rendering receives a detached polygon")


static func _test_group_editor(t: Node) -> void:
	var design: Design = Design.new()
	var first: int = design.add_piece("square", Vector2(40, 35), 1)
	var second: int = design.add_piece("trapezoid", Vector2(70, 45), 3)
	var outsider: int = design.add_piece("rhombus", Vector2(120, 75), 5)
	var members: Array[int] = [first, second]
	var ungrouped: Dictionary = design.to_dict()
	t.assert_true(design.group_pieces(members), "A pair of tile pieces can be grouped")
	var group: int = design.selection_group([first])
	t.assert_gt(group, 0, "Selecting either member finds the whole group")
	t.assert_eq(design.expand_selection([second]), members, "Group selection preserves the original drawing order")
	t.assert_eq(design.expand_selection([outsider, first]), [first, second, outsider], "A wider selection includes all the affected group members")
	t.assert_eq(design.selection_group([first, outsider]), 0, "A mixed selection is not identified as one group")
	t.assert_true(design.undo(), "One undo dissolves the newly created group")
	t.assert_eq(design.to_dict(), ungrouped, "Grouping changes no positions, vertices, or colors")
	t.assert_true(design.redo(), "Redo restores group membership")

	var grouped: Dictionary = design.to_dict()
	var original: Array[Dictionary] = design.motif_parts()
	var pivot: Vector2 = Vector2(55, 40)
	var offset: Vector2 = Vector2(3, 1)
	var preview: Array[Dictionary] = design.preview_transform(members, pivot, 37.0, 1.17, offset)
	t.assert_eq(preview.size(), members.size(), "The group transform previews every selected member")
	t.assert_eq(design.to_dict(), grouped, "A live preview never changes the motif or save data")
	if preview.size() != members.size(): return
	var transform: Transform2D = Transform2D(deg_to_rad(37.0), Vector2.ONE * 1.17, 0.0, Vector2.ZERO)
	for preview_part: Dictionary in preview:
		var old: Dictionary = original[int(preview_part.index)]
		for corner: int in range(4):
			var expected: Vector2 = pivot + transform * (Vector2(old.vertices[corner]) - pivot) + offset
			t.assert_true(Vector2(preview_part.vertices[corner]).is_equal_approx(expected), "Every corner follows the same group pivot, angle and size")
		t.assert_true(Geometry.matches_kind(preview_part.vertices, str(old.kind)), "All previewed outlines preserve their selected families")
	t.assert_true(design.transform_pieces(members, pivot, 37.0, 1.17, offset), "An arbitrary in-bounds group transform commits")
	t.assert_eq(design.motif_parts()[outsider], original[outsider], "The group transform leaves the third piece alone")
	var adjusted: Dictionary = design.to_dict()
	t.assert_true(design.preview_transform(members, pivot, 0.0, 100.0).is_empty(), "Oversized groups cannot preview outside the tile")
	t.assert_false(design.transform_pieces(members, pivot, 0.0, 100.0), "Oversized group transforms fail without a partial edit")
	t.assert_eq(design.to_dict(), adjusted, "An invalid group transform preserves all geometry and the save")
	t.assert_true(design.undo(), "One undo restores all transformed group members")
	t.assert_eq(design.to_dict(), grouped, "Undo restores the exact geometry and IDs for the whole group")
	t.assert_true(design.redo(), "One redo restores the complete transform")
	t.assert_eq(design.to_dict(), adjusted, "Redo reapplies the complete group transform")

	var copies: Array[int] = design.duplicate_pieces([first])
	t.assert_eq(copies, [3, 4], "Duplicating one group member copies the group to the top of the tile")
	if copies.size() != members.size(): return
	var copy_group: int = design.selection_group(copies)
	t.assert_true(copy_group > 0 and copy_group != group, "The duplicated pair has independent group membership")
	var pieces: Array[Dictionary] = design.motif_parts()
	for i: int in range(copies.size()):
		var source: Dictionary = pieces[members[i]]
		var copy: Dictionary = pieces[copies[i]]
		t.assert_eq(copy.kind, source.kind, "A duplicate keeps its authored family")
		t.assert_eq(copy.color, source.color, "A duplicate keeps its original color")
		var translation: Vector2 = Vector2(copy.position) - Vector2(source.position)
		for corner: int in range(4):
			t.assert_true(Vector2(copy.vertices[corner]).is_equal_approx(Vector2(source.vertices[corner]) + translation), "Duplicating translates every authored corner intact")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(design.to_dict()))
	var restored: Design = Design.new()
	t.assert_true(restored.restore(saved), "Saved groups survive an actual JSON round trip")
	t.assert_eq(restored.expand_selection([4]), copies, "A loaded copy retains its own group")
	t.assert_eq(restored.expand_selection([0]), members, "A loaded original retains its own group")
	var malformed: Dictionary = saved.duplicate(true)
	malformed.parts[1].erase("group_id")
	t.assert_false(restored.restore(malformed), "A dangling one-member group is rejected during restore")
	t.assert_eq(restored.to_dict(), design.to_dict(), "A malformed group fails before changing the loaded tile")
	t.assert_true(restored.ungroup_pieces(copies), "The copied group can be dissolved independently")
	t.assert_eq(restored.expand_selection([4]), [4], "Ungrouped pieces are independently selectable")
	t.assert_eq(restored.expand_selection([0]), members, "Dissolving the copy leaves the old group alone")
	t.assert_true(restored.undo(), "Undo restores the copied group membership")
	t.assert_true(restored.remove_pieces([4]), "Removing a selected group member removes its whole group")
	t.assert_eq(restored.motif_parts().size(), original.size(), "Deleting a group leaves the three original shapes")
	t.assert_true(restored.undo(), "One undo restores the entire removed group")
	t.assert_eq(restored.to_dict(), design.to_dict(), "Deletion undo restores group membership and drawing order")

	var old_design: Design = Design.new()
	t.assert_true(old_design.restore(ungrouped), "A v2 save without group fields remains loadable")
	t.assert_eq(old_design.expand_selection([second]), [second], "A historical shape with no group fields stays independent")


static func _test_snapping(t: Node) -> void:
	t.assert_eq(Design.GRID_STEP, 5.0, "The visible wall grid uses half-size five-unit cells")
	var design: Design = Design.new()
	var moving: int = design.add_piece("square", Vector2(35, 45), 1)
	var neighbor: int = design.add_piece("square", Vector2(90, 45), 3)
	var before: Dictionary = design.to_dict()
	var selected: Array[int] = [moving]
	var original: Array[Dictionary] = design.motif_parts()
	var moving_bounds: Rect2 = Geometry.bounds(original[moving].vertices)
	var neighbor_bounds: Rect2 = Geometry.bounds(original[neighbor].vertices)
	var contact: float = neighbor_bounds.position.x - moving_bounds.end.x
	var almost_touching: Vector2 = Vector2(contact - 2.0, 0.0)
	var attached: Vector2 = design.snap_translation(selected, almost_touching, 3.0)
	t.assert_true(attached.is_equal_approx(Vector2(contact, 0.0)), "A nearby pair of sides magnetically meet without a gap")
	var near_corner: Vector2 = Vector2(contact - 0.5, 0.5)
	t.assert_true(design.snap_translation(selected, near_corner, 3.0).is_equal_approx(Vector2(contact, 0.0)), "Very close corners line up on both axes")
	t.assert_eq(design.snap_translation(selected, almost_touching, 0.0), almost_touching, "Disabling the magnet allows the original in-bounds motion")
	t.assert_eq(design.to_dict(), before, "Moving close to a snap target changes no saved geometry")
	t.assert_true(design.transform_pieces(selected, Vector2.ZERO, 0.0, 1.0, attached), "Snap translation can commit without grid rounding")
	t.assert_float_approx(Geometry.bounds(design.motif_parts()[moving].vertices).end.x, neighbor_bounds.position.x, 0.001, "Committed polygon edges still touch exactly")
	t.assert_true(design.undo(), "Undo restores the exact geometry before snapping")
	t.assert_eq(design.to_dict(), before, "Snapping is part of one movement command")
	var tile_edge: float = -moving_bounds.position.x
	var aligned: Vector2 = design.snap_translation(selected, Vector2(tile_edge + 2.0, 0.0), 3.0)
	t.assert_true(aligned.is_equal_approx(Vector2(tile_edge, 0.0)), "A nearby outside edge snaps the whole piece to the tile border")

	var free: int = design.add_piece("freeform", Vector2(65, 65), 5)
	var original_free: PackedVector2Array = design.motif_parts()[free].vertices
	var contact_point: Vector2 = Vector2(neighbor_bounds.position.x, neighbor_bounds.get_center().y + 2.5)
	var corner: Vector2 = design.snap_vertex(free, contact_point + Vector2(1.6, 0.0), 3.0)
	t.assert_true(corner.is_equal_approx(contact_point), "A freeform corner snaps to the nearby piece edge")
	t.assert_true(design.set_vertex(free, 1, corner, false), "An attached freeform corner stays on the other edge after release")
	var changed: PackedVector2Array = design.motif_parts()[free].vertices
	t.assert_true(changed[1].is_equal_approx(contact_point), "A snapped vertex preserves its exact non-grid position")
	for i: int in [0, 2, 3]:
		t.assert_true(changed[i].is_equal_approx(original_free[i]), "The other freeform corners remain fixed during a snap")
	t.assert_true(Geometry.is_valid(changed), "Vertex snapping preserves a valid convex quadrilateral")
	var edge_point: Vector2 = Vector2(design.tile_size().x, 88)
	t.assert_true(design.snap_vertex(free, edge_point - Vector2(2, 0), 3.0).is_equal_approx(edge_point), "A freeform corner can also attach to the outside border")


static func _test_repetition(t: Node) -> void:
	var design := Design.new()
	design.add_piece("trapezoid", Vector2(20, 40), 0)
	design.add_piece("freeform", Vector2(100, 65), 2)
	design.set_repeat(4, 3)
	var tile: Array[Dictionary] = design.motif_parts()
	for layout: String in Design.LAYOUTS:
		design.set_layout(layout)
		var wall: Array[Dictionary] = design.wall_parts()
		t.assert_eq(wall.size(), 24, "Completing a wall automatically copies every authored quadrilateral into every cell")
		t.assert_eq(design.wall_size(), Vector2(600, 300), "Tile cells exactly fill the requested rectangular wall")
		for i: int in range(wall.size()):
			var copy: Dictionary = wall[i]
			var original: Dictionary = tile[int(copy.index)]
			var offset: Vector2 = design.tile_size() * Vector2(copy.column, copy.row)
			for j: int in range(4):
				var target: Vector2 = original.vertices[j]
				if layout == "mirror" and int(copy.column) % 2 == 1:
					target.x = design.tile_size().x - target.x
				elif layout == "alternate" and (int(copy.column) + int(copy.row)) % 2 == 1:
					target = design.tile_size() - target
				t.assert_true(copy.vertices[j].is_equal_approx(target + offset), "Copies preserve the authored corners in the selected layout")
			t.assert_eq(copy.color, original.color, "Wall transformations preserve the artist's palette")
	t.assert_false(design.set_repeat(100, 1), "An invalid repetition count cannot allocate an unbounded wall")


static func _test_commissions(t: Node) -> void:
	t.assert_eq(Design.COMMISSIONS.size(), 10, "All ten commission clients are available")
	var design := Design.new()
	t.assert_eq(design.claim(), 0, "An empty tile cannot earn a reward")
	var total: int = 0
	for id: String in Design.COMMISSIONS:
		design.set_commission(id)
		var order: Dictionary = Design.COMMISSIONS[id]
		# A different free constellation of squares satisfies every commission.
		for i: int in range(design.motif_parts().size() - 1, -1, -1):
			design.remove_piece(i)
		for i: int in range(int(order.min_pieces)):
			design.add_piece("square", Vector2(20 + 45 * (i % 3), 25 + 45 * floori(i / 3.0)), i % int(order.min_colors))
		t.assert_false(design.evaluate().ok, "A complete-looking draft still needs the finish step before delivery")
		t.assert_eq(design.claim(), 0, "An eligible draft cannot be delivered until its tile is finished")
		t.assert_true(design.finish_tile(), "A child can finish an independently composed tile")
		t.assert_true(design.evaluate().ok, "Commission accepts a wall made from only the child's chosen family")
		t.assert_eq(design.claim(), order.reward, "Fulfilled commission pays the exact catalog price")
		total += int(order.reward)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(design.to_dict()))
		var reloaded := Design.new()
		t.assert_true(reloaded.restore(saved), "V2 design and receipts survive JSON")
		t.assert_true(reloaded.finished, "A finished tile can be reopened in ready state")
		t.assert_eq(reloaded.total_income(), total, "The wallet aggregate is based on distinct valid receipts")
		t.assert_eq(reloaded.claim(), 0, "Reloading never allows another payment for the same client")
		t.assert_false(reloaded.can_undo(), "Transient undo snapshots are excluded from saves")


static func _old_save(motif: String = "trapezoid_pair") -> Dictionary:
	return {
		"version": 1, "motif": motif, "commission": "harbor", "layout": "mirror", "turns": 1,
		"tile_columns": 2, "tile_rows": 3, "columns": 5, "rows": 4,
		"colors": {"trapezoid_pair": [1, 2], "square_frame": [0, 3, 2, 1, 2], "mirror_stripe": [0, 1, 2, 3, 4, 5]},
		"completed": ["garden", "station", "harbor"],
	}


static func _test_legacy(t: Node) -> void:
	var shapes: Dictionary = {"trapezoid_pair": 2, "square_frame": 5, "mirror_stripe": 6}
	for id: String in shapes:
		var design := Design.new()
		t.assert_true(design.restore(_old_save(id)), "Previously released motifs migrate")
		t.assert_eq(design.palette_size(), Design.PALETTE.size(), "Legacy motifs use the original fixed palette")
		t.assert_eq(design.total_income(), 22000000, "Old paid clients retain their exact wallet values")
		t.assert_eq(design.claim(), 0, "Legacy receipt cannot be paid again")
		t.assert_eq(design.tile_size(), Vector2(200, 300), "Legacy rectangular aspect ratio is preserved")
		var pieces: Array[Dictionary] = design.motif_parts()
		t.assert_eq(pieces.size(), int(shapes[id]) * 6, "Every former repeated motif expands into independently editable pieces")
		t.assert_eq(design.wall_parts().size(), pieces.size() * 20, "Full legacy wall dimensions are preserved")
		if id == "trapezoid_pair":
			t.assert_eq(pieces[0].vertices, PackedVector2Array([Vector2(100, 0), Vector2(100, 70), Vector2(0, 30), Vector2(0, 0)]), "Legacy rotation and ordered corners are exact")
			t.assert_eq(pieces[2].position, pieces[0].position + Vector2(100, 0), "Adjacent legacy groups keep their position")
			t.assert_eq(pieces[2].palette_index, 1, "The legacy color survives expansion")
			design.set_color(0, 7)
			t.assert_eq(design.motif_parts()[2].palette_index, 1, "Old copies are now independently editable")
		var again := Design.new()
		t.assert_true(again.restore(design.to_dict()), "Migrated geometry can be saved again in V2")
		t.assert_eq(again.motif_parts(), design.motif_parts(), "Migrated V2 artwork is unchanged after reloading")


static func _test_invalid_saves(t: Node) -> void:
	var design := Design.new()
	design.add_piece("square", Vector2(30, 40), 2)
	var before: Dictionary = design.to_dict()
	for field: String in ["position", "vertices", "kind", "palette_index"]:
		var malformed: Dictionary = before.duplicate(true)
		malformed.parts[0][field] = null
		t.assert_false(design.restore(malformed), "Invalid part fields are rejected")
	var invalid: Dictionary = before.duplicate(true)
	invalid.parts[0].vertices[0][0] = INF
	t.assert_false(design.restore(invalid), "Nonfinite source vertices cannot become geometry")
	invalid = before.duplicate(true)
	invalid.parts[0].position = [0, 0]
	t.assert_false(design.restore(invalid), "Restore rejects clipped geometry even on tile boundaries")
	invalid = before.duplicate(true)
	invalid.completed = ["harbor", "harbor"]
	t.assert_false(design.restore(invalid), "A duplicated receipt is rejected")
	invalid = _old_save()
	invalid.completed = ["observatory"]
	t.assert_false(design.restore(invalid), "An old save cannot manufacture a new-client receipt")
	invalid = before.duplicate(true)
	invalid.finished = true
	t.assert_false(design.restore(invalid), "One-piece finished snapshots are rejected")
	t.assert_eq(design.to_dict(), before, "Invalid saves never partially overwrite live work")
	t.assert_true(design.can_undo(), "Invalid restore preserves undo history")
