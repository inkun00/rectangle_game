class_name SpaceshipAssembly
extends RefCounted

const Catalog: GDScript = preload("res://scripts/economy/spaceship_catalog.gd")
const Math: GDScript = preload("res://scripts/core/quadrilateral_math.gd")


## Build the visible shell around shared interfaces. Each installed product
## supplies its primary quadrilateral and can have several matching panels.
## Missing products get the base geometry for the hangar's empty slot preview.
static func build(ids: Array[String], appearance: Dictionary = {}) -> Dictionary:
	var products: Dictionary = {}
	for base: Dictionary in Catalog.all_parts():
		products[base.slot_id] = base
	for id: String in ids:
		var product: Dictionary = Catalog.part(id)
		if not product.is_empty(): products[product.slot_id] = product

	var panels: Array[Dictionary] = []
	var exhausts: Array[Vector2] = []
	var port_widths: Array[float] = []
	var hull_tier: int = int(products.hull.tier)
	var engine_tier: int = int(products.engine.tier)
	var nose_tier: int = int(products.nose.tier)
	var half: float = 36.0 + 9.0 * hull_tier
	var forward_half: float = half * (0.89 if hull_tier == 2 else 1.0)
	var deck_front: float = -75.0
	var deck_end: float = 67.0 + 13.0 * hull_tier
	var neck: float = -112.0
	var tip: float = neck - 59.0 - 14.0 * nose_tier
	var neck_half: float = forward_half * 0.75
	var tip_half: float = neck_half * (0.40 - 0.065 * nose_tier)
	var tail: float = deck_end + 43.0
	var engine_half: float = 19.0 + 5.0 * engine_tier + 2.0 * hull_tier

	# Wing roots run under the deck and are close to symmetric, even with
	# mixed products. Each product still controls its own span and sweep.
	var mean_wing: float = (float(products.left_wing.tier) + float(products.right_wing.tier)) * 0.5
	for side: float in [-1.0, 1.0]:
		var wing_slot: String = "left_wing" if side < 0.0 else "right_wing"
		var tank_slot: String = "left_tank" if side < 0.0 else "right_tank"
		var wing_tier: int = int(products[wing_slot].tier)
		var wing_root: float = half - 10.0
		var span: float = 57.0 + 26.0 * mean_wing + 8.0 * wing_tier + 5.0 * hull_tier
		var tip_x: float = half + span
		var root_front: float = deck_end - 81.0 - 14.0 * mean_wing
		var tip_front: float = deck_end - 25.0 - 7.0 * wing_tier
		var tip_back: float = deck_end + 11.0 + 5.0 * wing_tier
		_add_wing(panels, wing_slot, wing_tier, side, wing_root, tip_x, Vector2(root_front, deck_end + 2.0), Vector2(tip_front, tip_back), str(appearance.get("wings", "none")))
		_add_tank(panels, tank_slot, int(products[tank_slot].tier), side, half, deck_end)
		_add_side_mount(panels, str(appearance.get("sides", "none")), side, half, deck_end)
		_add_tail_mount(panels, exhausts, port_widths, str(appearance.get("tail", "none")), side, half, tail)

	var nose: PackedVector2Array = _taper(tip, neck + 1.0, tip_half, neck_half)
	_add(panels, "nose", "shell", nose, {"seam": true, "primary": nose_tier < 2})
	_add(panels, "nose", "trim", _across(nose, 0.13, 0.25), {"detail": true})
	_add(panels, "nose", "trim", _across(nose, 0.75, 0.87), {"detail": true})
	_add(panels, "nose", "metal", _along(nose, 0.0, 0.15), {"detail": true})
	if nose_tier == 2:
		_add(panels, "nose", "metal", _shape("rhombus", Vector2(30.0, 29.0), Vector2(0.0, neck - 24.0)), {"primary": true, "seam": true})
	_add_fore_mount(panels, str(appearance.get("fore", "none")), tip, tip_half)

	var shoulders: PackedVector2Array = _taper(neck, deck_front + 1.0, neck_half, forward_half)
	_add(panels, "hull", "shell", shoulders)
	_add(panels, "hull", "metal", _across(shoulders, 0.0, 0.15), {"detail": true})
	_add(panels, "hull", "metal", _across(shoulders, 0.85, 1.0), {"detail": true})
	_add(panels, "hull", "shell", _across(shoulders, 0.17, 0.26), {"detail": true})
	_add(panels, "hull", "shell", _across(shoulders, 0.74, 0.83), {"detail": true})
	var deck: PackedVector2Array = _taper(deck_front, deck_end + 1.0, forward_half, half)
	_add(panels, "hull", "dark", deck, {"internal": true})
	_add(panels, "hull", "shell", deck, {"primary": true, "cover": true, "seam": true})
	_add(panels, "hull", "metal", _across(deck, 0.0, 0.15))
	_add(panels, "hull", "metal", _across(deck, 0.85, 1.0))
	for side: float in [-1.0, 1.0]:
		var rail_start: float = 0.07 if side < 0.0 else 0.89
		_add(panels, "hull", "shade", _along(_across(deck, rail_start, rail_start + 0.04), 0.29, 0.72), {"detail": true})
		_add(panels, "hull", "glass", _along(_across(deck, rail_start, rail_start + 0.04), 0.31, 0.39), {"detail": true})
		_add(panels, "hull", "glass", _along(_across(deck, rail_start, rail_start + 0.04), 0.61, 0.69), {"detail": true})
	_add(panels, "hull", "metal", _across(_along(deck, 0.55, 0.565), 0.15, 0.85), {"detail": true, "cover": true})
	_add(panels, "hull", "trim", _across(_along(deck, 0.75, 0.81), 0.15, 0.85), {"detail": true, "cover": true})
	_add(panels, "hull", "dark", _shape("rectangle", Vector2(18.0 + hull_tier * 6.0, 3.0), Vector2(0.0, 14.0)), {"detail": true, "cover": true})
	_add(panels, "hull", "dark", _shape("rectangle", Vector2(18.0 + hull_tier * 6.0, 3.0), Vector2(0.0, 22.0)), {"detail": true, "cover": true})

	_add_canopy(panels, int(products.window.tier), half, deck_front)
	var fairing: PackedVector2Array = _taper(deck_end, tail + 1.0, half, engine_half)
	_add(panels, "hull", "shell", fairing, {"seam": true})
	_add(panels, "hull", "metal", _across(fairing, 0.0, 0.17), {"detail": true})
	_add(panels, "hull", "metal", _across(fairing, 0.83, 1.0), {"detail": true})
	_add(panels, "hull", "shade", _across(_along(fairing, 0.55, 0.61), 0.30, 0.70), {"detail": true})
	_add_drive(panels, exhausts, port_widths, engine_tier, int(products.nozzle.tier), engine_half, tail)

	_add(panels, "hull", "metal", _shape("rectangle", Vector2(4.0, deck_end - deck_front - 30.0), Vector2(0.0, (deck_front + deck_end) * 0.5)), {"detail": true, "internal": true})
	for y: float in [deck_front + 25.0, 2.0, deck_end - 20.0]:
		_add(panels, "hull", "shade", _shape("rectangle", Vector2(half * 1.56, 4.0), Vector2(0.0, y)), {"detail": true, "internal": true})
	_add_internal(panels, products.navigation, Vector2(0.0, deck_front + 25.0), Vector2(27.0, 27.0))
	_add_internal(panels, products.core, Vector2(0.0, 2.0), Vector2(30.0, 37.0))
	_add_internal(panels, products.shield, Vector2(0.0, deck_end - 20.0), Vector2(42.0, 12.0))

	var bounds: Rect2 = Rect2()
	for panel: Dictionary in panels:
		if bool(panel.internal): continue
		var panel_bounds: Rect2 = Math.bounds(panel.vertices)
		bounds = bounds.merge(panel_bounds) if bounds.has_area() else panel_bounds
	return {"panels": panels, "bounds": bounds, "exhausts": exhausts, "port_widths": port_widths}


static func product_panel(product_id: String) -> Dictionary:
	var product: Dictionary = Catalog.part(product_id)
	if product.is_empty(): return {}
	for panel: Dictionary in build([product_id]).panels:
		if panel.slot == product.slot_id and panel.primary: return panel
	return {}


static func _add_wing(panels: Array[Dictionary], slot: String, tier: int, side: float, root_x: float, tip_x: float, root_edge: Vector2, tip_edge: Vector2, addon: String) -> void:
	var wing: PackedVector2Array = _swept(side, root_x, tip_x, root_edge, tip_edge)
	_add(panels, slot, "shade", wing, {"seam": true, "primary": tier == 1})
	var leading: PackedVector2Array = _across(wing, 0.0, 0.22)
	_add(panels, slot, "shell", leading)
	_add(panels, slot, "trim", _across(wing, 0.23, 0.32), {"detail": true})
	_add(panels, slot, "metal", _across(wing, 0.91, 1.0), {"detail": true})
	if tier != 1:
		# Match the two vertical edges of the wing skin with a swept
		# parallelogram that is recognizably the purchased shape.
		var inner: float = 0.16
		var outer: float = 0.88
		var inner_chord: Vector2 = root_edge.lerp(tip_edge, inner)
		var outer_chord: Vector2 = root_edge.lerp(tip_edge, outer)
		var chord: float = (outer_chord.y - outer_chord.x) * 0.43
		var inner_y: float = lerpf(inner_chord.x, inner_chord.y, 0.45)
		var outer_y: float = lerpf(outer_chord.x, outer_chord.y, 0.45)
		_add(panels, slot, "shade", _swept(side, lerpf(root_x, tip_x, inner), lerpf(root_x, tip_x, outer), Vector2(inner_y, inner_y + chord), Vector2(outer_y, outer_y + chord)), {"primary": true, "seam": true})
	var tip_light: PackedVector2Array = _along(_across(wing, 0.47, 0.67), 0.94, 1.0)
	_add(panels, slot, "glow", tip_light, {"detail": true})
	_add(panels, slot, "metal", _along(_across(wing, 0.32, 0.91), 0.66, 0.68), {"detail": true})
	if addon == "fins":
		var fin: PackedVector2Array = _swept(side, tip_x - 5.0, tip_x + 18.0, tip_edge + Vector2(-1.0, 1.0), tip_edge + Vector2(-18.0, -29.0))
		_add(panels, "wings", "metal", fin, {"seam": true})
		_add(panels, "wings", "trim", _across(fin, 0.55, 0.73), {"detail": true})
	elif addon == "solar":
		var solar: PackedVector2Array = _swept(side, tip_x - 4.0, tip_x + 25.0, tip_edge, tip_edge + Vector2(8.0, 7.0))
		_add(panels, "wings", "metal", solar, {"seam": true})
		for row: int in range(3):
			var offset: float = 0.12 + float(row) * 0.26
			_add(panels, "wings", "glass", _along(_across(solar, offset, offset + 0.20), 0.25, 0.85), {"detail": true})


static func _add_tank(panels: Array[Dictionary], slot: String, tier: int, side: float, half: float, deck_end: float) -> void:
	var width: float = 18.0 + 7.0 * tier
	var height: float = 52.0 + 12.0 * tier
	var center: Vector2 = Vector2(side * (half + width * 0.5 - 3.0), deck_end - height * 0.42)
	var shoulders: PackedVector2Array = _taper(center.y - height * 0.6, center.y + height * 0.53, width * 0.44, width * 0.58, center.x)
	_add(panels, slot, "metal", shoulders, {"seam": true})
	var tank: PackedVector2Array
	if tier == 0:
		tank = _shape("rectangle", Vector2(width * 0.72, height * 0.73), center)
	elif tier == 1:
		tank = _move(Math.create_parallelogram_vertices(Vector2(width * 0.75, height * 0.76), -side * 0.10), center)
	else:
		tank = _taper(center.y - height * 0.41, center.y + height * 0.41, width * 0.25, width * 0.42, center.x)
	_add(panels, slot, "shell", tank, {"primary": true})
	_add(panels, slot, "trim", _along(tank, 0.70, 0.79), {"detail": true})
	_add(panels, slot, "dark", _along(_across(tank, 0.30, 0.70), 0.84, 0.93), {"detail": true})


static func _add_canopy(panels: Array[Dictionary], tier: int, half: float, deck_front: float) -> void:
	var center: Vector2 = Vector2(0.0, deck_front + 12.0)
	var width: float = half * (1.13 + tier * 0.12)
	var length: float = 44.0 + tier * 10.0
	var housing: PackedVector2Array = _taper(center.y - length * 0.55, center.y + length * 0.56, width * 0.42, width * 0.59)
	_add(panels, "window", "metal", housing, {"cover": true})
	var window: PackedVector2Array
	match tier:
		0: window = _shape("rectangle", Vector2(width * 0.79, length * 0.83), center)
		1: window = _taper(center.y - length * 0.43, center.y + length * 0.43, width * 0.32, width * 0.48)
		_: window = _shape("rhombus", Vector2(width * 1.01, length * 0.98), center)
	_add(panels, "window", "glass", window, {"cover": true, "primary": true, "seam": true})
	var reflection: PackedVector2Array = _move(Math.create_parallelogram_vertices(Vector2(15.0 + 3.0 * tier, 25.0 + 3.0 * tier), 0.29), center + Vector2(-4.0, 0.0))
	_add(panels, "window", "glow", reflection, {"cover": true, "detail": true})


static func _add_drive(panels: Array[Dictionary], exhausts: Array[Vector2], port_widths: Array[float], tier: int, nozzle_tier: int, half: float, tail: float) -> void:
	var engine_back: float = tail + (half * 2.0 if tier == 0 else 42.0 + 7.0 * tier)
	var bottom_half: float = half * (0.87 if tier == 2 else 1.0)
	var engine: PackedVector2Array = _taper(tail, engine_back, half, bottom_half)
	_add(panels, "engine", "metal", engine, {"primary": true, "seam": true})
	for row: int in range(2 + tier):
		var offset: float = 0.24 + float(row) * 0.14
		_add(panels, "engine", "dark", _across(_along(engine, offset, offset + 0.060), 0.20, 0.80), {"detail": true})
	var nozzle_half: float = bottom_half * (0.82 + nozzle_tier * 0.09)
	var nozzle_bottom: float = engine_back + 14.0 + nozzle_tier * 4.0
	var end_half: float = nozzle_half * (0.81 if nozzle_tier == 1 else 1.0)
	var nozzle: PackedVector2Array = _taper(engine_back - 1.0, nozzle_bottom, nozzle_half, end_half)
	_add(panels, "nozzle", "dark", nozzle, {"primary": true, "seam": true})
	_add(panels, "nozzle", "metal", _along(nozzle, 0.0, 0.25), {"detail": true})
	_add(panels, "nozzle", "glow", _across(_along(nozzle, 0.64, 1.0), 0.17, 0.83), {"detail": true})
	exhausts.push_front(Vector2(0.0, nozzle_bottom))
	port_widths.push_front(end_half * 1.32)


static func _add_internal(panels: Array[Dictionary], product: Dictionary, center: Vector2, room: Vector2) -> void:
	var vertices: PackedVector2Array = product.vertices
	var bounds: Rect2 = Math.bounds(vertices)
	var scale: float = minf(room.x / bounds.size.x, room.y / bounds.size.y) * (0.72 + 0.14 * float(product.tier))
	var inset: PackedVector2Array = PackedVector2Array()
	for vertex: Vector2 in vertices:
		inset.append(center + (vertex - bounds.get_center()) * scale)
	_add(panels, str(product.slot_id), "glow" if product.slot_id == "core" else "glass" if product.slot_id == "navigation" else "metal", inset, {"internal": true, "primary": true, "seam": true})


static func _add_fore_mount(panels: Array[Dictionary], addon: String, tip: float, tip_half: float) -> void:
	if addon == "scanner":
		_add(panels, "fore", "metal", _taper(tip - 12.0, tip + 6.0, tip_half * 0.74, tip_half + 8.0), {"seam": true})
		_add(panels, "fore", "glass", _shape("rectangle", Vector2(tip_half * 1.14, 5.0), Vector2(0.0, tip - 5.0)), {"detail": true})
	elif addon == "sensor":
		for side: float in [-1.0, 1.0]:
			var x: float = side * (tip_half * 0.78 + 2.0)
			_add(panels, "fore", "metal", _taper(tip - 20.0, tip + 11.0, 3.0, 6.0, x), {"seam": true})
			_add(panels, "fore", "glow", _shape("square", Vector2(5.0, 5.0), Vector2(x, tip - 15.0)), {"detail": true})


static func _add_side_mount(panels: Array[Dictionary], addon: String, side: float, half: float, deck_end: float) -> void:
	if addon == "none": return
	var x: float = side * (half + (48.0 if addon == "cargo" else 40.0))
	var top: float = deck_end - (35.0 if addon == "cargo" else 52.0)
	var end: float = deck_end + (25.0 if addon == "cargo" else 18.0)
	if addon == "cargo":
		var cargo: PackedVector2Array = _taper(top, end, 12.0, 16.0, x)
		_add(panels, "sides", "metal", cargo, {"seam": true})
		_add(panels, "sides", "shell", _across(_along(cargo, 0.14, 0.88), 0.12, 0.88))
		_add(panels, "sides", "trim", _along(cargo, 0.65, 0.76), {"detail": true})
	elif addon == "pods":
		var pod: PackedVector2Array = _taper(top, end - 14.0, 7.0, 14.0, x)
		_add(panels, "sides", "shell", pod, {"seam": true})
		_add(panels, "sides", "shade", _taper(end - 15.0, end, 14.0, 8.0, x))
		_add(panels, "sides", "glass", _across(_along(pod, 0.22, 0.41), 0.18, 0.82), {"detail": true})


static func _add_tail_mount(panels: Array[Dictionary], exhausts: Array[Vector2], port_widths: Array[float], addon: String, side: float, half: float, tail: float) -> void:
	var x: float = side * (half + 13.0)
	if addon == "radiators":
		var radiator: PackedVector2Array = _taper(tail - 55.0, tail + 9.0, 14.0, 11.0, x)
		_add(panels, "tail", "metal", radiator, {"seam": true})
		for index: int in range(4):
			var offset: float = 0.15 + float(index) * 0.19
			_add(panels, "tail", "dark", _across(_along(radiator, offset, offset + 0.085), 0.17, 0.83), {"detail": true})
	elif addon == "boosters":
		var pod: PackedVector2Array = _taper(tail - 51.0, tail + 38.0, 10.0, 19.0, x)
		_add(panels, "tail", "shell", pod, {"seam": true})
		_add(panels, "tail", "trim", _along(pod, 0.70, 0.77), {"detail": true})
		_add(panels, "tail", "dark", _along(pod, 0.87, 1.0))
		_add(panels, "tail", "glow", _across(_along(pod, 0.93, 1.0), 0.20, 0.80), {"detail": true})
		exhausts.append(Vector2(x, tail + 38.0))
		port_widths.append(22.8)


## Construct panels from two parallel cross sections. These operations never
## change the number of sides or cut away a corner of a quadrilateral.
static func _taper(y0: float, y1: float, half0: float, half1: float, x: float = 0.0) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x - half0, y0), Vector2(x + half0, y0), Vector2(x + half1, y1), Vector2(x - half1, y1)])


static func _swept(side: float, root_x: float, tip_x: float, root_edge: Vector2, tip_edge: Vector2) -> PackedVector2Array:
	return PackedVector2Array([Vector2(side * root_x, root_edge.x), Vector2(side * root_x, root_edge.y), Vector2(side * tip_x, tip_edge.y), Vector2(side * tip_x, tip_edge.x)])


static func _along(points: PackedVector2Array, first: float, last: float) -> PackedVector2Array:
	return PackedVector2Array([points[0].lerp(points[3], first), points[1].lerp(points[2], first), points[1].lerp(points[2], last), points[0].lerp(points[3], last)])


static func _across(points: PackedVector2Array, first: float, last: float) -> PackedVector2Array:
	return PackedVector2Array([points[0].lerp(points[1], first), points[0].lerp(points[1], last), points[3].lerp(points[2], last), points[3].lerp(points[2], first)])


static func _shape(kind: String, size: Vector2, center: Vector2) -> PackedVector2Array:
	return _move(Math.create_vertices(kind, size), center)


static func _move(points: PackedVector2Array, center: Vector2) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points: result.append(point + center)
	return result


static func _add(panels: Array[Dictionary], slot: String, tone: String, vertices: PackedVector2Array, flags: Dictionary = {}) -> void:
	var families: Array[String] = Math.classifications(vertices)
	if families.is_empty(): return
	var ordered: PackedVector2Array = vertices
	if Math.signed_area(ordered) < 0.0:
		ordered = vertices.duplicate()
		ordered.reverse()
	panels.append({
		"vertices": ordered, "kind": families.back(), "slot": slot, "tone": tone,
		"primary": bool(flags.get("primary", false)), "detail": bool(flags.get("detail", false)),
		"seam": bool(flags.get("seam", false)), "internal": bool(flags.get("internal", false)), "cover": bool(flags.get("cover", false)),
	})
