class_name ArtComposition
extends RefCounted

## A transparent construction rubric, not semantic image recognition. Geometry
## comes from the four real vertices; only finally visible pieces earn roles.
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const CELL_AREA: float = 400.0
const MIN_ROLE_SAMPLES: int = 3
const MIN_ANCHOR_SAMPLES: int = 12
const MIN_ANCHOR_VISIBILITY: float = 0.25
const MIN_FOCUS: float = 0.70
const COLOR_DISTANCE: float = 0.18

static func assess(parts: Array[Dictionary], visible_samples: Dictionary) -> Dictionary:
	var items: Array[Dictionary] = _items(parts, visible_samples)
	var total: int = 0
	for count: Variant in visible_samples.values(): total += maxi(0, int(count))
	var accepted: Dictionary = {}
	var subjects: PackedStringArray = PackedStringArray()
	var best: Dictionary = {}
	for body: Dictionary in items:
		if not _anchor(body): continue
		for result: Dictionary in [_house(body, items), _tree(body, items), _robot(body, items), _rocket(body, items)]:
			if result.is_empty(): continue
			if best.is_empty() or float(result.score) > float(best.score): best = result
			if bool(result.complete): _accept(result, accepted, subjects)
	for result: Dictionary in _geometric(items):
		if best.is_empty() or float(result.score) > float(best.score): best = result
		if bool(result.complete): _accept(result, accepted, subjects)
	var focused: int = 0
	for item: Dictionary in items:
		if accepted.has(int(item.index)): focused += int(item.visible)
	var ratio: float = float(focused) / float(maxi(1, total))
	var has_form: bool = not subjects.is_empty() and ratio + 0.000001 >= MIN_FOCUS
	var criteria: Array[Dictionary] = []
	var reason: String = "몸체와 세부를 연결해 집·나무·로봇·우주선을 만들거나, 크기가 다른 구획을 가로·세로로 맞춰 기하 구성을 만들어 주세요."
	if not subjects.is_empty():
		criteria.append(_criterion("structure", "알아볼 수 있는 구조 또는 기하 구획", true, " · ".join(subjects) + " 구조를 갖췄어요."))
		reason = "완성된 형태가 그림의 중심이 되도록 흩어진 조각을 줄이거나 다른 사물도 완성해 주세요."
	elif not best.is_empty():
		criteria.assign(best.criteria)
		var missing: PackedStringArray = PackedStringArray()
		for row: Dictionary in criteria:
			if not bool(row.met): missing.append(str(row.detail))
		reason = "%s 기준: %s" % [str(best.subject), " · ".join(missing)]
	else:
		criteria.append(_criterion("structure", "알아볼 수 있는 구조 또는 기하 구획", false, reason))
	criteria.append(_criterion("focus", "완성된 형태가 보이는 그림의 70% 이상", has_form, "현재 %.1f%% · 여러 집이나 나무도 함께 인정해요." % (floorf(ratio * 1000.0) / 10.0)))
	if has_form: reason = " · ".join(subjects) + "의 구조와 중심 구성이 갖춰졌어요."
	return {"has_form": has_form, "subject": " · ".join(subjects), "reason": reason, "criteria": criteria, "focus": ratio}

static func _items(parts: Array[Dictionary], counts: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(parts.size()):
		var samples: int = int(counts.get(index, 0))
		if samples < MIN_ROLE_SAMPLES: continue
		var part: Dictionary = parts[index]
		if not part.has_all(["vertices", "position", "color"]) or not Math.is_valid(part.vertices): continue
		var polygon: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in part.vertices: polygon.append(point + Vector2(part.position))
		var rect: Rect2 = Math.bounds(polygon)
		var area: float = absf(Math.signed_area(polygon))
		var rectangular: bool = Math.matches_kind(part.vertices, "rectangle")
		var axis_aligned: bool = rectangular and absf(area - rect.get_area()) <= maxf(1.0, area * 0.005)
		result.append({"index": index, "visible": samples, "polygon": polygon, "rect": rect, "area": area, "rectangle": rectangular, "axis_aligned": axis_aligned, "color": part.color})
	return result

static func _anchor(item: Dictionary) -> bool:
	return bool(item.rectangle) and int(item.visible) >= MIN_ANCHOR_SAMPLES and float(item.visible) * CELL_AREA >= float(item.area) * MIN_ANCHOR_VISIBILITY and float(item.area) >= CELL_AREA * float(MIN_ANCHOR_SAMPLES)

static func _house(body: Dictionary, items: Array[Dictionary]) -> Dictionary:
	var box: Rect2 = body.rect
	if box.size.x < box.size.y * 0.7 or box.size.x > box.size.y * 2.8: return {}
	var roof: Dictionary = {}
	var door: Dictionary = {}
	var left: Dictionary = {}
	var right: Dictionary = {}
	for item: Dictionary in items:
		if int(item.index) == int(body.index): continue
		if not _role_visible(item): continue
		var rect: Rect2 = item.rect
		if _above(item, body, 0.12) and _between(rect.size.x / box.size.x, 0.80, 1.65) and _between(rect.size.y / box.size.y, 0.15, 0.65): roof = item
		if not _inside(body, item) or not _contrast(body, item): continue
		if _between(rect.size.x / box.size.x, 0.12, 0.34) and _between(rect.size.y / box.size.y, 0.30, 0.72) and absf(rect.end.y - box.end.y) <= box.size.y * 0.13 and absf(rect.get_center().x - box.get_center().x) <= box.size.x * 0.20: door = item
		if _between(rect.size.x / box.size.x, 0.10, 0.29) and _between(rect.size.y / box.size.y, 0.12, 0.34) and rect.end.y <= box.position.y + box.size.y * 0.68:
			if rect.get_center().x < box.get_center().x - box.size.x * 0.12: left = item
			if rect.get_center().x > box.get_center().x + box.size.x * 0.12: right = item
	var rows: Array[Dictionary] = [
		_criterion("house_body", "집의 몸체", true, "넓은 몸체가 보여요."),
		_criterion("house_roof", "몸체 위를 덮는 지붕", not roof.is_empty(), "몸체 위에 닿는 넓은 지붕을 놓아요."),
		_criterion("house_door", "아래쪽 문", not door.is_empty(), "몸체와 색이 구별되는 문을 아래쪽에 놓아요."),
		_criterion("house_windows", "몸체 안 양쪽 창문", not left.is_empty() and not right.is_empty(), "몸체와 색이 구별되는 창문을 왼쪽과 오른쪽에 놓아요.")]
	return _report("집", rows, [body, roof, door, left, right])

static func _tree(trunk: Dictionary, items: Array[Dictionary]) -> Dictionary:
	var box: Rect2 = trunk.rect
	if not _between(box.size.y / box.size.x, 1.8, 7.5): return {}
	var central: Dictionary = {}
	var leaves: Array[Dictionary] = []
	for item: Dictionary in items:
		if int(item.index) == int(trunk.index): continue
		if not _role_visible(item): continue
		var rect: Rect2 = item.rect
		if rect.get_center().y > box.position.y + box.size.y * 0.20: continue
		if not _between(rect.size.x / box.size.x, 1.5, 8.0) or not _between(rect.size.y / box.size.y, 0.25, 1.1): continue
		leaves.append(item)
		if absf(rect.get_center().x - box.get_center().x) <= box.size.x * 0.70 and _touch(item, trunk, box.size.x * 0.20): central = item
	var left: Dictionary = {}
	var right: Dictionary = {}
	var connected: Array[Dictionary] = []
	if not central.is_empty():
		for item: Dictionary in leaves:
			if not _touch(central, item, box.size.x * 0.20): continue
			connected.append(item)
			if int(item.index) == int(central.index): continue
			var center: Vector2 = Rect2(item.rect).get_center()
			if center.x < box.get_center().x - box.size.x * 0.60: left = item
			if center.x > box.get_center().x + box.size.x * 0.60: right = item
	var fruit: Dictionary = {}
	for item: Dictionary in items:
		if not _role_visible(item): continue
		for leaf: Dictionary in connected:
			var rect: Rect2 = item.rect
			var crown: Rect2 = leaf.rect
			if _inside(leaf, item) and _contrast(leaf, item) and _between(rect.size.x / crown.size.x, 0.10, 0.35) and _between(rect.size.y / crown.size.y, 0.10, 0.35): fruit = item
	var rows: Array[Dictionary] = [
		_criterion("tree_trunk", "나무의 세로 줄기", true, "세로 줄기가 보여요."),
		_criterion("tree_crown", "줄기 위에 연결된 잎 세 부분", not central.is_empty() and not left.is_empty() and not right.is_empty(), "줄기 위의 잎과 양옆 잎을 연결해요."),
		_criterion("tree_detail", "열매 또는 풍성한 잎", not fruit.is_empty() or connected.size() >= 5, "잎 안에 색이 다른 열매를 넣거나 연결된 잎을 다섯 부분 이상 만들어요.")]
	var group: Array[Dictionary] = [trunk, fruit]
	group.append_array(connected)
	return _report("나무", rows, group)

static func _robot(body: Dictionary, items: Array[Dictionary]) -> Dictionary:
	var box: Rect2 = body.rect
	if not _between(box.size.y / box.size.x, 0.8, 2.0): return {}
	var head: Dictionary = {}
	var left_arm: Dictionary = {}
	var right_arm: Dictionary = {}
	var left_leg: Dictionary = {}
	var right_leg: Dictionary = {}
	for item: Dictionary in items:
		if int(item.index) == int(body.index): continue
		if not _role_visible(item): continue
		var rect: Rect2 = item.rect
		if _above(item, body, 0.13) and _between(rect.size.x / box.size.x, 0.45, 1.20) and _between(rect.size.y / box.size.y, 0.25, 0.70): head = item
		if _between(rect.size.x / box.size.x, 0.12, 0.50) and _between(rect.size.y / box.size.y, 0.35, 1.10) and _touch(item, body, box.size.x * 0.08) and _between((rect.get_center().y - box.position.y) / box.size.y, 0.2, 0.85):
			if rect.get_center().x < box.position.x: left_arm = item
			if rect.get_center().x > box.end.x: right_arm = item
		if _between(rect.size.x / box.size.x, 0.16, 0.45) and _between(rect.size.y / box.size.y, 0.25, 0.8) and absf(rect.position.y - box.end.y) <= box.size.y * 0.12 and _touch(item, body, box.size.y * 0.08):
			if rect.get_center().x < box.get_center().x - box.size.x * 0.08: left_leg = item
			if rect.get_center().x > box.get_center().x + box.size.x * 0.08: right_leg = item
	var left_eye: Dictionary = {}
	var right_eye: Dictionary = {}
	if not head.is_empty():
		var face: Rect2 = head.rect
		for item: Dictionary in items:
			if not _role_visible(item): continue
			var rect: Rect2 = item.rect
			if not _inside(head, item) or not _contrast(head, item): continue
			if not _between(rect.size.x / face.size.x, 0.10, 0.32) or not _between(rect.size.y / face.size.y, 0.10, 0.45): continue
			if rect.get_center().x < face.get_center().x - face.size.x * 0.08: left_eye = item
			if rect.get_center().x > face.get_center().x + face.size.x * 0.08: right_eye = item
	var rows: Array[Dictionary] = [
		_criterion("robot_body", "로봇의 몸통", true, "몸통이 보여요."),
		_criterion("robot_head", "몸통 위의 머리", not head.is_empty(), "몸통 위에 닿는 머리를 놓아요."),
		_criterion("robot_arms", "몸통 양옆의 팔", not left_arm.is_empty() and not right_arm.is_empty(), "몸통 양쪽에 팔을 연결해요."),
		_criterion("robot_legs", "몸통 아래의 두 다리", not left_leg.is_empty() and not right_leg.is_empty(), "몸통 아래에 떨어진 두 다리를 연결해요."),
		_criterion("robot_face", "머리 안의 두 눈", not left_eye.is_empty() and not right_eye.is_empty(), "머리와 색이 구별되는 두 눈을 넣어요.")]
	return _report("로봇", rows, [body, head, left_arm, right_arm, left_leg, right_leg, left_eye, right_eye])

static func _rocket(body: Dictionary, items: Array[Dictionary]) -> Dictionary:
	var box: Rect2 = body.rect
	if not _between(box.size.y / box.size.x, 1.3, 4.2): return {}
	var nose: Dictionary = {}
	var left: Dictionary = {}
	var right: Dictionary = {}
	var nozzle: Dictionary = {}
	var window: Dictionary = {}
	for item: Dictionary in items:
		if int(item.index) == int(body.index): continue
		if not _role_visible(item): continue
		var rect: Rect2 = item.rect
		if _above(item, body, 0.12) and _between(rect.size.x / box.size.x, 0.70, 1.35) and _between(rect.size.y / box.size.y, 0.20, 0.80): nose = item
		if not bool(item.rectangle) and _between(rect.size.x / box.size.x, 0.35, 1.0) and _between(rect.size.y / box.size.y, 0.35, 0.95) and _touch(item, body, box.size.x * 0.12) and _between((rect.get_center().y - box.position.y) / box.size.y, 0.45, 1.1):
			if rect.get_center().x < box.position.x: left = item
			if rect.get_center().x > box.end.x: right = item
		if absf(rect.position.y - box.end.y) <= box.size.y * 0.12 and absf(rect.get_center().x - box.get_center().x) <= box.size.x * 0.12 and _between(rect.size.x / box.size.x, 0.40, 1.15) and _between(rect.size.y / box.size.y, 0.10, 0.40) and _touch(item, body, box.size.x * 0.12): nozzle = item
		if _inside(body, item) and _contrast(body, item) and _between(float(item.area) / float(body.area), 0.05, 0.35) and rect.get_center().y < box.get_center().y: window = item
	var rows: Array[Dictionary] = [
		_criterion("rocket_body", "우주선의 긴 몸체", true, "긴 몸체가 보여요."),
		_criterion("rocket_nose", "몸체 위의 기수", not nose.is_empty(), "몸체 위에 기수를 연결해요."),
		_criterion("rocket_wings", "몸체 양옆의 기울어진 날개", not left.is_empty() and not right.is_empty(), "몸체 양쪽에 기울어진 사각형 날개를 연결해요."),
		_criterion("rocket_nozzle", "몸체 아래의 분사구", not nozzle.is_empty(), "몸체 바로 아래에 분사구를 연결해요."),
		_criterion("rocket_window", "몸체 안의 조종석 창", not window.is_empty(), "몸체와 색이 구별되는 창을 위쪽 안에 넣어요.")]
	return _report("우주선", rows, [body, nose, left, right, nozzle, window])

static func _geometric(items: Array[Dictionary]) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for item: Dictionary in items:
		if bool(item.axis_aligned) and float(item.visible) * CELL_AREA >= float(item.area) * 0.75: eligible.append(item)
	var visited: Dictionary = {}
	var results: Array[Dictionary] = []
	for first: Dictionary in eligible:
		if visited.has(int(first.index)): continue
		var component: Array[Dictionary] = [first]
		visited[int(first.index)] = true
		var cursor: int = 0
		while cursor < component.size():
			var current: Dictionary = component[cursor]
			cursor += 1
			for other: Dictionary in eligible:
				if visited.has(int(other.index)): continue
				if _shared_edge(current, other) == 0: continue
				visited[int(other.index)] = true
				component.append(other)
		if component.size() < 3: continue
		results.append(_geometric_component(component))
	return results

static func _geometric_component(items: Array[Dictionary]) -> Dictionary:
	var box: Rect2 = items[0].rect
	var areas: Array[float] = []
	var sum_area: float = 0.0
	var horizontal: int = 0
	var vertical: int = 0
	var contrasted: int = 0
	for i: int in range(items.size()):
		var item: Dictionary = items[i]
		box = box.merge(item.rect)
		areas.append(float(item.area))
		sum_area += float(item.area)
		for j: int in range(i):
			var edge: int = _shared_edge(item, items[j])
			if edge == 1: horizontal += 1
			if edge == 2: vertical += 1
			if edge != 0 and _contrast(item, items[j]): contrasted += 1
	areas.sort()
	var levels: int = 1
	var last_area: float = areas[0]
	for area: float in areas:
		if area >= last_area * 1.7:
			levels += 1
			last_area = area
	var distinct_sizes: bool = levels >= 3 and areas.back() >= areas.front() * 5.0
	var filled: float = sum_area / maxf(1.0, box.get_area())
	var rows: Array[Dictionary] = [
		_criterion("geometric_regions", "서로 맞닿은 여섯 구획", items.size() >= 6, "직사각형 구획 여섯 개 이상을 서로 맞춰요."),
		_criterion("geometric_sizes", "큰 면·중간 면·작은 면", distinct_sizes, "같은 타일을 반복하지 말고 세 단계 크기의 구획을 만들어요."),
		_criterion("geometric_axes", "가로와 세로로 나뉜 화면", horizontal >= 2 and vertical >= 2 and box.size.x >= 160.0 and box.size.y >= 120.0 and _between(box.size.x / box.size.y, 0.35, 3.2), "한 줄 대신 가로와 세로 양쪽으로 구획을 나눠요."),
		_criterion("geometric_fill", "빈틈과 겹침이 적은 구획", _between(filled, 0.70, 1.08), "큰 틀 안을 서로 심하게 겹치지 않는 구획으로 채워요."),
		_criterion("geometric_contrast", "색으로 구별되는 구획선", contrasted >= 3, "이웃한 구획 세 곳 이상에서 색이 분명히 달라야 해요.")]
	return _report("기하 구성", rows, items)

static func _shared_edge(a: Dictionary, b: Dictionary) -> int:
	var first: Rect2 = a.rect
	var second: Rect2 = b.rect
	if first.intersection(second).get_area() > minf(float(a.area), float(b.area)) * 0.04: return 0
	var tolerance: float = 7.0
	var overlap_y: float = minf(first.end.y, second.end.y) - maxf(first.position.y, second.position.y)
	var overlap_x: float = minf(first.end.x, second.end.x) - maxf(first.position.x, second.position.x)
	if minf(absf(first.end.x - second.position.x), absf(second.end.x - first.position.x)) <= tolerance and overlap_y >= minf(first.size.y, second.size.y) * 0.35: return 1
	if minf(absf(first.end.y - second.position.y), absf(second.end.y - first.position.y)) <= tolerance and overlap_x >= minf(first.size.x, second.size.x) * 0.35: return 2
	return 0

static func _above(item: Dictionary, body: Dictionary, gap: float) -> bool:
	var rect: Rect2 = item.rect
	var box: Rect2 = body.rect
	return rect.get_center().y < box.position.y and absf(rect.end.y - box.position.y) <= box.size.y * gap and absf(rect.get_center().x - box.get_center().x) <= box.size.x * 0.15 and _touch(item, body, box.size.y * gap)

static func _inside(outer: Dictionary, inner: Dictionary) -> bool:
	if int(outer.index) == int(inner.index): return false
	if not Rect2(outer.rect).grow(1.0).encloses(inner.rect): return false
	for point: Vector2 in inner.polygon:
		if not Math.contains_point(outer.polygon, point): return false
	return true

static func _touch(a: Dictionary, b: Dictionary, tolerance: float) -> bool:
	if not Rect2(a.rect).grow(tolerance + 0.01).intersects(b.rect, true): return false
	var first: PackedVector2Array = a.polygon
	var second: PackedVector2Array = b.polygon
	for point: Vector2 in first:
		if Math.contains_point(second, point): return true
		for edge: int in range(4):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, second[edge], second[(edge + 1) % 4])) <= tolerance + 0.01: return true
	for point: Vector2 in second:
		if Math.contains_point(first, point): return true
		for edge: int in range(4):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, first[edge], first[(edge + 1) % 4])) <= tolerance + 0.01: return true
	return false

static func _contrast(a: Dictionary, b: Dictionary) -> bool:
	var first: Color = a.color
	var second: Color = b.color
	return Vector3(first.r - second.r, first.g - second.g, first.b - second.b).length() >= COLOR_DISTANCE

static func _role_visible(item: Dictionary) -> bool:
	# A hidden large door or roof cannot earn a full spatial role through a few
	# exposed pixels. Smaller details still need the common three samples.
	return float(item.visible) * CELL_AREA >= float(item.area) * 0.35

static func _between(value: float, minimum: float, maximum: float) -> bool:
	return value >= minimum and value <= maximum

static func _criterion(id: String, label: String, met: bool, detail: String) -> Dictionary:
	return {"id": id, "label": label, "met": met, "detail": detail}

static func _report(subject: String, rows: Array[Dictionary], group: Array[Dictionary]) -> Dictionary:
	var met: int = 0
	for row: Dictionary in rows:
		if bool(row.met): met += 1
	var indices: Array[int] = []
	for item: Dictionary in group:
		if not item.is_empty() and not indices.has(int(item.index)): indices.append(int(item.index))
	return {"subject": subject, "complete": met == rows.size(), "score": float(met) / float(rows.size()), "criteria": rows, "indices": indices}

static func _accept(result: Dictionary, accepted: Dictionary, subjects: PackedStringArray) -> void:
	for index: int in result.indices: accepted[index] = true
	if not subjects.has(str(result.subject)): subjects.append(str(result.subject))
