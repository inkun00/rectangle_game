class_name WallTileDesign
extends RefCounted

const History = preload("res://scripts/core/command_manager.gd")
const Geometry = preload("res://scripts/core/quadrilateral_math.gd")
const LAYOUTS: Dictionary = {"straight": "나란히", "alternate": "번갈아 반 바퀴", "mirror": "번갈아 뒤집기"}
const PALETTE: Array[Color] = [
	Color("#f4e7ca"), Color("#146e78"), Color("#e76e58"), Color("#e6ae36"),
	Color("#363e73"), Color("#72ada2"), Color("#995778"), Color("#ffffff"),
]
const PALETTE_NAMES: Array[String] = ["모래색", "청록색", "산호색", "금색", "남색", "옥색", "자주색", "흰색"]
const GRID_STEP: float = 5.0
const MAX_PIECES: int = 64
const DEFAULT_TILE_SIZE: Vector2 = Vector2(150, 100)
const COMMISSIONS: Dictionary = {
	"harbor": {"title": "항구 등대의 물결 벽", "brief": "등대로 돌아오는 배들이 멀리서도 알아볼 수 있게 물결을 닮은 타일을 부탁해요. 사각형 2개 이상, 색 2가지 이상으로 꾸민 타일을 가로 4장, 세로 2장 이상 놓아요.", "reward": 3000000, "min_pieces": 2, "min_colors": 2, "columns": 4, "rows": 2},
	"garden": {"title": "온실의 창문 벽", "brief": "햇빛이 비치는 정원에 놓을 벽이에요. 조각을 이어 나만의 작은 창문을 만들어 주세요. 사각형 3개 이상, 색 2가지 이상으로 꾸민 타일을 가로 3장, 세로 3장 이상 놓아요.", "reward": 7000000, "min_pieces": 3, "min_colors": 2, "columns": 3, "rows": 3},
	"station": {"title": "우주 정거장의 신호 벽", "brief": "우주선 창밖에서도 눈에 띄는 신호 무늬가 필요해요. 조각에 색을 담아 주세요. 사각형 5개 이상, 색 3가지 이상으로 꾸민 타일을 가로 4장, 세로 3장 이상 놓아요.", "reward": 12000000, "min_pieces": 5, "min_colors": 3, "columns": 4, "rows": 3},
	"library": {"title": "도서관 책길 담장", "brief": "책을 읽으러 오는 친구들을 맞이하고 싶어요. 책등을 떠올리며 무늬를 꾸며 보세요. 사각형 2개 이상, 색 2가지 이상으로 꾸민 타일을 가로 3장, 세로 3장 이상 놓아요.", "reward": 4000000, "min_pieces": 2, "min_colors": 2, "columns": 3, "rows": 3},
	"bakery": {"title": "빵집의 아침 담장", "brief": "빵 굽는 냄새가 나는 골목이에요. 가게 앞을 따뜻한 무늬로 꾸며 주세요. 사각형 3개 이상, 색 2가지 이상으로 꾸민 타일을 가로 5장, 세로 2장 이상 놓아요.", "reward": 5000000, "min_pieces": 3, "min_colors": 2, "columns": 5, "rows": 2},
	"playground": {"title": "놀이터의 놀이길", "brief": "친구들이 뛰놀다 숨을 고르는 자리예요. 즐거운 움직임이 느껴지는 무늬를 부탁해요. 사각형 3개 이상, 색 3가지 이상으로 꾸민 타일을 가로 4장, 세로 3장 이상 놓아요.", "reward": 6000000, "min_pieces": 3, "min_colors": 3, "columns": 4, "rows": 3},
	"forest": {"title": "숲길의 쉼터", "brief": "숲속 쉼터에 계절을 담은 담장을 세워요. 나뭇잎과 그늘을 떠올려 보세요. 사각형 4개 이상, 색 2가지 이상으로 꾸민 타일을 가로 5장, 세로 3장 이상 놓아요.", "reward": 8000000, "min_pieces": 4, "min_colors": 2, "columns": 5, "rows": 3},
	"museum": {"title": "박물관의 입구", "brief": "오래된 유물을 만나기 전 지나가는 벽이에요. 조각을 조합해 새로운 문양을 지어 주세요. 사각형 4개 이상, 색 3가지 이상으로 꾸민 타일을 가로 4장, 세로 4장 이상 놓아요.", "reward": 9000000, "min_pieces": 4, "min_colors": 3, "columns": 4, "rows": 4},
	"orchard": {"title": "과수원의 수확 길", "brief": "열매를 나르는 수레가 지나가요. 알록달록한 수확 풍경을 담장에 담아 주세요. 사각형 5개 이상, 색 3가지 이상으로 꾸민 타일을 가로 6장, 세로 3장 이상 놓아요.", "reward": 10000000, "min_pieces": 5, "min_colors": 3, "columns": 6, "rows": 3},
	"observatory": {"title": "별빛 관측소", "brief": "밤하늘을 보러 오는 길을 장식해요. 여러 조각으로 나만의 별자리를 만들어 주세요. 사각형 6개 이상, 색 4가지 이상으로 꾸민 타일을 가로 6장, 세로 4장 이상 놓아요.", "reward": 14000000, "min_pieces": 6, "min_colors": 4, "columns": 6, "rows": 4},
}

var layout: String = "straight"
var commission_id: String = "harbor"
var columns: int = 4
var rows: int = 2
var completed: Array[String] = []
var finished: bool = false

var _size: Vector2 = DEFAULT_TILE_SIZE
var _parts: Array[Dictionary] = []
var _history: History = History.new()


func set_commission(id: String) -> bool:
	if not COMMISSIONS.has(id):
		return false
	if commission_id != id:
		commission_id = id
		columns = int(COMMISSIONS[id].columns)
		rows = int(COMMISSIONS[id].rows)
		finished = false
	return true


func start_tile(id: String) -> bool:
	if not COMMISSIONS.has(id):
		return false
	var commission: Dictionary = COMMISSIONS[id]
	commission_id = id
	columns = int(commission.columns)
	rows = int(commission.rows)
	layout = "straight"
	_size = DEFAULT_TILE_SIZE
	_parts.clear()
	_history.clear()
	finished = false
	return true


func clear_pieces() -> bool:
	return _record([])


func _apply_parts(state: Dictionary) -> void:
	_parts.assign(state.parts.duplicate(true))
	finished = false


func finish_tile() -> bool:
	if _parts.size() < 2:
		return false
	finished = true
	return true


func _record(parts: Array[Dictionary]) -> bool:
	if parts == _parts:
		return false
	_history.push_snapshot(self, &"_apply_parts", {"parts": _parts}, {"parts": parts})
	return true


func can_undo() -> bool:
	return _history.can_undo()


func can_redo() -> bool:
	return _history.can_redo()


func undo() -> bool:
	if not can_undo():
		return false
	_history.undo()
	return true


func redo() -> bool:
	if not can_redo():
		return false
	_history.redo()
	return true


func _index_valid(index: int) -> bool:
	return index >= 0 and index < _parts.size()


func expand_selection(indices: Array[int]) -> Array[int]:
	var selected: Dictionary[int, bool] = {}
	var groups: Dictionary[int, bool] = {}
	for index: int in indices:
		if not _index_valid(index):
			return []
		selected[index] = true
		var group_id: int = int(_parts[index].get("group_id", 0))
		if group_id > 0:
			groups[group_id] = true
	var expanded: Array[int] = []
	for index: int in range(_parts.size()):
		if selected.has(index) or groups.has(int(_parts[index].get("group_id", 0))):
			expanded.append(index)
	return expanded


func selection_group(indices: Array[int]) -> int:
	var selection: Array[int] = expand_selection(indices)
	if selection.size() < 2:
		return 0
	var group_id: int = int(_parts[selection[0]].get("group_id", 0))
	if group_id == 0:
		return 0
	for index: int in selection:
		if int(_parts[index].get("group_id", 0)) != group_id:
			return 0
	return group_id


func _used_groups() -> Dictionary[int, bool]:
	var used: Dictionary[int, bool] = {}
	for part: Dictionary in _parts:
		var group_id: int = int(part.get("group_id", 0))
		if group_id > 0:
			used[group_id] = true
	return used


static func _allocate_group(used: Dictionary[int, bool]) -> int:
	for group_id: int in range(1, MAX_PIECES + 1):
		if not used.has(group_id):
			used[group_id] = true
			return group_id
	return 0


func group_pieces(indices: Array[int]) -> bool:
	var selection: Array[int] = expand_selection(indices)
	if selection.size() < 2 or selection_group(selection) > 0:
		return false
	var group_id: int = _allocate_group(_used_groups())
	var next: Array[Dictionary] = _parts.duplicate(true)
	for index: int in selection:
		next[index]["group_id"] = group_id
	return _record(next)


func ungroup_pieces(indices: Array[int]) -> bool:
	var selection: Array[int] = expand_selection(indices)
	if selection_group(selection) == 0:
		return false
	var next: Array[Dictionary] = _parts.duplicate(true)
	for index: int in selection:
		next[index].erase("group_id")
	return _record(next)


func _selection_bounds(selection: Array[int]) -> Rect2:
	var bounds: Rect2 = Geometry.bounds(_world_vertices(_parts[selection[0]]))
	for index: int in selection:
		bounds = bounds.merge(Geometry.bounds(_world_vertices(_parts[index])))
	return bounds


func _nearby_polygons(excluded: Array[int], area: Rect2) -> Array[PackedVector2Array]:
	var nearby: Array[PackedVector2Array] = []
	for index: int in range(_parts.size()):
		if index in excluded:
			continue
		var points: PackedVector2Array = _world_vertices(_parts[index])
		if area.intersects(Geometry.bounds(points), true):
			nearby.append(points)
	return nearby


static func _border_delta(low_gap: float, high_gap: float, tolerance: float) -> float:
	if minf(low_gap, high_gap) > tolerance:
		return INF
	return -low_gap if low_gap <= high_gap else high_gap


func _border_alignment(bounds: Rect2, tolerance: float) -> Vector2:
	return Vector2(
		_border_delta(bounds.position.x, _size.x - bounds.end.x, tolerance),
		_border_delta(bounds.position.y, _size.y - bounds.end.y, tolerance)
	)


static func _snap_projection(point: Vector2, start: Vector2, end: Vector2, lock_x: bool, lock_y: bool) -> Vector2:
	if not lock_x and not lock_y:
		return Geometry2D.get_closest_point_to_segment(point, start, end)
	var axis: int = 0 if lock_x else 1
	var span: float = end[axis] - start[axis]
	if is_zero_approx(span):
		return Geometry2D.get_closest_point_to_segment(point, start, end) if is_equal_approx(point[axis], start[axis]) else Vector2.INF
	var progress: float = (point[axis] - start[axis]) / span
	if progress < 0.0 or progress > 1.0:
		return Vector2.INF
	var projected: Vector2 = start.lerp(end, progress)
	projected[axis] = point[axis]
	return projected


static func _closer_snap(best: Vector2, candidate: Vector2, low: Vector2, high: Vector2, limit: float) -> Vector2:
	if not candidate.is_finite():
		return best
	var distance: float = candidate.length_squared()
	if distance > limit or distance >= best.length_squared() or not candidate.is_equal_approx(candidate.clamp(low, high)):
		return best
	return candidate.clamp(low, high)


func _snap_polygons(pieces: Array[PackedVector2Array], excluded: Array[int], bounds: Rect2, offset: Vector2, tolerance: float) -> Vector2:
	var clamped: Vector2 = offset.clamp(-bounds.position, _size - bounds.end)
	if not is_finite(tolerance) or tolerance <= 0.0:
		return clamped
	var border: Vector2 = _border_alignment(Rect2(bounds.position + clamped, bounds.size), tolerance)
	var lock_x: bool = is_finite(border.x)
	var lock_y: bool = is_finite(border.y)
	clamped += Vector2(border.x if lock_x else 0.0, border.y if lock_y else 0.0)
	if lock_x and lock_y:
		return clamped
	var moved_bounds: Rect2 = Rect2(bounds.position + clamped, bounds.size)
	var low: Vector2 = Vector2(0.0 if lock_x else -moved_bounds.position.x, 0.0 if lock_y else -moved_bounds.position.y)
	var high: Vector2 = Vector2(0.0 if lock_x else _size.x - moved_bounds.end.x, 0.0 if lock_y else _size.y - moved_bounds.end.y)
	var closest: Vector2 = Vector2.INF
	var corner_snap: Vector2 = Vector2.INF
	var limit: float = tolerance * tolerance
	var corner_limit: float = limit * 0.25
	var fixed: Array[PackedVector2Array] = _nearby_polygons(excluded, moved_bounds.grow(tolerance))
	for points: PackedVector2Array in pieces:
		var moving: PackedVector2Array = Transform2D(0.0, clamped) * points
		var near_moving: Rect2 = Geometry.bounds(moving).grow(tolerance)
		for target: PackedVector2Array in fixed:
			if not near_moving.intersects(Geometry.bounds(target), true):
				continue
			for first: int in range(moving.size()):
				var point: Vector2 = moving[first]
				var next_point: Vector2 = moving[(first + 1) % moving.size()]
				for second: int in range(target.size()):
					var vertex: Vector2 = target[second]
					corner_snap = _closer_snap(corner_snap, vertex - point, low, high, corner_limit)
					var edge_point: Vector2 = _snap_projection(point, vertex, target[(second + 1) % target.size()], lock_x, lock_y)
					closest = _closer_snap(closest, edge_point - point, low, high, limit)
					# Check both directions so a short neighboring edge can align
					# against the middle of a longer edge even when their corners differ.
					var moved_edge_point: Vector2 = _snap_projection(vertex, point, next_point, lock_x, lock_y)
					closest = _closer_snap(closest, vertex - moved_edge_point, low, high, limit)
	if corner_snap.is_finite():
		return clamped + corner_snap
	return clamped + closest if closest.is_finite() else clamped


func snap_translation(indices: Array[int], offset: Vector2, tolerance: float) -> Vector2:
	var selection: Array[int] = expand_selection(indices)
	if selection.is_empty() or not offset.is_finite():
		return Vector2.ZERO
	var pieces: Array[PackedVector2Array] = []
	for index: int in selection:
		pieces.append(_world_vertices(_parts[index]))
	return _snap_polygons(pieces, selection, _selection_bounds(selection), offset, tolerance)


func snap_vertex(index: int, point: Vector2, tolerance: float) -> Vector2:
	if not point.is_finite():
		return Vector2.ZERO
	var clamped: Vector2 = point.clamp(Vector2.ZERO, _size)
	if not _index_valid(index) or not is_finite(tolerance) or tolerance <= 0.0:
		return clamped
	var border: Vector2 = _border_alignment(Rect2(clamped, Vector2.ZERO), tolerance)
	var lock_x: bool = is_finite(border.x)
	var lock_y: bool = is_finite(border.y)
	clamped += Vector2(border.x if lock_x else 0.0, border.y if lock_y else 0.0)
	if lock_x and lock_y:
		return clamped
	var low: Vector2 = Vector2(0.0 if lock_x else -clamped.x, 0.0 if lock_y else -clamped.y)
	var high: Vector2 = Vector2(0.0 if lock_x else _size.x - clamped.x, 0.0 if lock_y else _size.y - clamped.y)
	var closest: Vector2 = Vector2.INF
	var corner_snap: Vector2 = Vector2.INF
	var limit: float = tolerance * tolerance
	var selection: Array[int] = expand_selection([index])
	for target: PackedVector2Array in _nearby_polygons(selection, Rect2(clamped, Vector2.ZERO).grow(tolerance)):
		for cursor: int in range(target.size()):
			var vertex: Vector2 = target[cursor]
			corner_snap = _closer_snap(corner_snap, vertex - clamped, low, high, limit * 0.25)
			var edge_point: Vector2 = _snap_projection(clamped, vertex, target[(cursor + 1) % target.size()], lock_x, lock_y)
			closest = _closer_snap(closest, edge_point - clamped, low, high, limit)
	if corner_snap.is_finite():
		return clamped + corner_snap
	return clamped + closest if closest.is_finite() else clamped


func duplicate_pieces(indices: Array[int]) -> Array[int]:
	var selection: Array[int] = expand_selection(indices)
	if selection.is_empty() or _parts.size() + selection.size() > MAX_PIECES:
		return []
	var bounds: Rect2 = _selection_bounds(selection)
	var shift: Vector2 = Vector2.ONE * GRID_STEP
	var positive: Vector2 = shift.clamp(-bounds.position, _size - bounds.end)
	var negative: Vector2 = (-shift).clamp(-bounds.position, _size - bounds.end)
	var offset: Vector2 = positive if positive.length_squared() >= negative.length_squared() else negative
	var used: Dictionary[int, bool] = _used_groups()
	var replacements: Dictionary[int, int] = {}
	var next: Array[Dictionary] = _parts.duplicate()
	var copies: Array[int] = []
	for index: int in selection:
		var copy: Dictionary = _parts[index].duplicate()
		copy.position = Vector2(copy.position) + offset
		if not _valid(copy, _size):
			return []
		var group_id: int = int(copy.get("group_id", 0))
		if group_id > 0:
			if not replacements.has(group_id):
				replacements[group_id] = _allocate_group(used)
			copy["group_id"] = replacements[group_id]
		copies.append(next.size())
		next.append(copy)
	_record(next)
	return copies


func remove_pieces(indices: Array[int]) -> bool:
	var selection: Array[int] = expand_selection(indices)
	if selection.is_empty():
		return false
	var next: Array[Dictionary] = _parts.duplicate()
	for cursor: int in range(selection.size() - 1, -1, -1):
		next.remove_at(selection[cursor])
	return _record(next)


func _transformed(selection: Array[int], motion: Transform2D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var basis: Transform2D = Transform2D(motion.x, motion.y, Vector2.ZERO)
	for index: int in selection:
		var part: Dictionary = _parts[index].duplicate()
		part.position = motion * Vector2(part.position)
		part.vertices = basis * PackedVector2Array(part.vertices)
		if not _valid(part, _size):
			return []
		result.append(part)
	return result


func _similarity(selection: Array[int], pivot: Vector2, degrees: float, scale: float, offset: Vector2) -> Array[Dictionary]:
	if not pivot.is_finite() or not offset.is_finite() or not is_finite(degrees) or not is_finite(scale) or scale <= 0.0:
		return []
	var motion: Transform2D = Transform2D(deg_to_rad(fmod(degrees, 360.0)), Vector2.ONE * scale, 0.0, Vector2.ZERO)
	motion.origin = pivot + offset - motion.basis_xform(pivot)
	return _transformed(selection, motion)


func _replace_selection(selection: Array[int], replacements: Array[Dictionary]) -> bool:
	if replacements.is_empty():
		return false
	var next: Array[Dictionary] = _parts.duplicate()
	for cursor: int in range(selection.size()):
		next[selection[cursor]] = replacements[cursor]
	return _record(next)


func transform_pieces(indices: Array[int], pivot: Vector2, degrees: float, scale: float, offset: Vector2 = Vector2.ZERO) -> bool:
	var selection: Array[int] = expand_selection(indices)
	return _replace_selection(selection, _similarity(selection, pivot, degrees, scale, offset))


func preview_transform(indices: Array[int], pivot: Vector2, degrees: float, scale: float, offset: Vector2 = Vector2.ZERO) -> Array[Dictionary]:
	var selection: Array[int] = expand_selection(indices)
	var transformed: Array[Dictionary] = _similarity(selection, pivot, degrees, scale, offset)
	var result: Array[Dictionary] = []
	for cursor: int in range(transformed.size()):
		result.append(_rendered_part(transformed[cursor], selection[cursor]))
	return result


func mirror_pieces(indices: Array[int]) -> bool:
	var selection: Array[int] = expand_selection(indices)
	if selection.is_empty():
		return false
	if selection.size() == 1:
		return mirror_piece(selection[0])
	var pivot: Vector2 = _selection_bounds(selection).get_center()
	var motion: Transform2D = Transform2D(Vector2.LEFT, Vector2.DOWN, Vector2(pivot.x * 2.0, 0.0))
	return _replace_selection(selection, _transformed(selection, motion))


func color_pieces(indices: Array[int], palette_index: int) -> bool:
	var selection: Array[int] = expand_selection(indices)
	if selection.is_empty() or not _integer_in(palette_index, 0, PALETTE.size() - 1):
		return false
	var next: Array[Dictionary] = _parts.duplicate(true)
	for index: int in selection:
		next[index].palette_index = palette_index
	return _record(next)


static func _known_kind(kind: Variant) -> bool:
	return kind is String and (kind == Geometry.FREEFORM or Geometry.KINDS.has(kind))


static func _world_vertices(part: Dictionary) -> PackedVector2Array:
	return Transform2D(0.0, part.position) * PackedVector2Array(part.vertices)


static func _valid(part: Dictionary, extent: Vector2) -> bool:
	var vertices: PackedVector2Array = part.vertices
	if not Geometry.is_valid(vertices) or (part.kind != Geometry.FREEFORM and not Geometry.matches_kind(vertices, part.kind)):
		return false
	for p: Vector2 in _world_vertices(part):
		if not p.is_finite() or p.x < -0.0001 or p.y < -0.0001 or p.x > extent.x + 0.0001 or p.y > extent.y + 0.0001:
			return false
	return true


static func _from_world(points: PackedVector2Array, kind: String, palette_index: int) -> Dictionary:
	var center: Vector2 = Vector2.ZERO
	for p: Vector2 in points:
		center += p * 0.25
	return {"position": center, "vertices": Transform2D(0.0, -center) * points, "kind": kind, "palette_index": palette_index}


func _clamped_center(local: PackedVector2Array, at: Vector2) -> Vector2:
	var bounds: Rect2 = Geometry.bounds(local)
	return at.snappedf(GRID_STEP).clamp(-bounds.position, _size - bounds.end)


func add_piece(kind: String, at: Vector2, palette_index: int = 0, snap_tolerance: float = 0.0) -> int:
	if not _known_kind(kind) or not at.is_finite() or _parts.size() >= MAX_PIECES or not _integer_in(palette_index, 0, PALETTE.size() - 1):
		return -1
	var part: Dictionary = _from_world(Geometry.create_vertices(kind, Vector2(34, 25)), kind, palette_index)
	part.position = _clamped_center(part.vertices, at)
	if snap_tolerance > 0.0 and is_finite(snap_tolerance):
		var points: PackedVector2Array = _world_vertices(part)
		var pieces: Array[PackedVector2Array] = [points]
		part.position = Vector2(part.position) + _snap_polygons(pieces, [], Geometry.bounds(points), Vector2.ZERO, snap_tolerance)
	if not _valid(part, _size):
		return -1
	var next: Array[Dictionary] = _parts.duplicate()
	next.append(part)
	_record(next)
	return next.size() - 1


func _replace(index: int, part: Dictionary) -> bool:
	if not _valid(part, _size):
		return false
	var next: Array[Dictionary] = _parts.duplicate()
	next[index] = part
	return _record(next)


func move_piece(index: int, center: Vector2) -> bool:
	if not _index_valid(index) or not center.is_finite():
		return false
	var part: Dictionary = _parts[index].duplicate()
	part.position = _clamped_center(part.vertices, center)
	return _replace(index, part)


func rotate_piece(index: int, degrees: float) -> bool:
	if not _index_valid(index) or not is_finite(degrees):
		return false
	var part: Dictionary = _parts[index].duplicate()
	part.vertices = Geometry.rotate_vertices(part.vertices, fmod(degrees, 360.0))
	return _replace(index, part)


func mirror_piece(index: int) -> bool:
	if not _index_valid(index):
		return false
	var part: Dictionary = _parts[index].duplicate()
	var mirror: Transform2D = Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2.ZERO)
	part.vertices = mirror * PackedVector2Array(part.vertices)
	return _replace(index, part)


func resize_piece(index: int, factor: float) -> bool:
	if not _index_valid(index) or factor <= 0 or not is_finite(factor):
		return false
	var part: Dictionary = _parts[index].duplicate()
	part.vertices = Geometry.scale_vertices(part.vertices, factor)
	return _replace(index, part)


func set_vertex(index: int, corner: int, point_on_tile: Vector2, snap_grid: bool = true) -> bool:
	if not _index_valid(index) or _parts[index].kind != Geometry.FREEFORM or corner < 0 or corner > 3 or not point_on_tile.is_finite():
		return false
	var points: PackedVector2Array = _world_vertices(_parts[index])
	points[corner] = point_on_tile.snappedf(GRID_STEP) if snap_grid else point_on_tile
	var piece: Dictionary = _from_world(points, Geometry.FREEFORM, int(_parts[index].palette_index))
	if _parts[index].has("group_id"):
		piece["group_id"] = _parts[index].group_id
	return _replace(index, piece)


func set_color(index: int, palette_index: int) -> bool:
	if not _index_valid(index) or not _integer_in(palette_index, 0, PALETTE.size() - 1):
		return false
	var part: Dictionary = _parts[index].duplicate()
	part.palette_index = palette_index
	return _replace(index, part)


func remove_piece(index: int) -> bool:
	return remove_pieces([index])


func hit_test(at: Vector2) -> int:
	for i: int in range(_parts.size() - 1, -1, -1):
		if Geometry.contains_point(_world_vertices(_parts[i]), at):
			return i
	return -1


func set_repeat(wide: int, high: int) -> bool:
	if wide < 2 or wide > 8 or high < 2 or high > 6:
		return false
	columns = wide
	rows = high
	return true


func set_layout(id: String) -> bool:
	if not LAYOUTS.has(id):
		return false
	layout = id
	return true


func tile_size() -> Vector2:
	return _size


func wall_size() -> Vector2:
	return tile_size() * Vector2(columns, rows)


func motif_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for part: Dictionary in _parts:
		result.append(_rendered_part(part, result.size()))
	return result


static func _rendered_part(part: Dictionary, index: int) -> Dictionary:
	return {
		"index": index, "position": part.position, "vertices": _world_vertices(part), "kind": part.kind,
		"palette_index": part.palette_index, "color": PALETTE[int(part.palette_index)], "group_id": part.get("group_id", 0)
	}


func wall_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var tile: Array[Dictionary] = motif_parts()
	var size: Vector2 = tile_size()
	for row: int in range(rows):
		for column: int in range(columns):
			var scale: Vector2 = Vector2.ONE
			var offset: Vector2 = size * Vector2(column, row)
			if layout == "alternate" and (row + column) % 2 == 1:
				scale = Vector2(-1, -1)
				offset += size
			elif layout == "mirror" and column % 2 == 1:
				scale.x = -1
				offset.x += size.x
			var transform: Transform2D = Transform2D(Vector2(scale.x, 0), Vector2(0, scale.y), offset)
			for part: Dictionary in tile:
				var copy: Dictionary = part.duplicate()
				copy.vertices = transform * PackedVector2Array(part.vertices)
				copy.position = transform * Vector2(part.position)
				copy.column = column
				copy.row = row
				result.append(copy)
	return result


func evaluate() -> Dictionary:
	var order: Dictionary = COMMISSIONS[commission_id]
	var tones: Dictionary = {}
	for part: Dictionary in _parts:
		tones[part.palette_index] = true
	var feedback: String = ""
	if _parts.size() < int(order.min_pieces):
		feedback = "타일 한 장에 원하는 사각형을 %d개 더 놓아 주세요." % (int(order.min_pieces) - _parts.size())
	elif tones.size() < int(order.min_colors):
		feedback = "사각형을 서로 다른 색 %d가지 이상으로 칠해 주세요." % int(order.min_colors)
	elif columns < int(order.columns) or rows < int(order.rows):
		feedback = "타일을 가로 %d장, 세로 %d장 이상 놓아 주세요." % [int(order.columns), int(order.rows)]
	elif not finished:
		feedback = "타일 한 장을 완성해 담장을 채워 주세요."
	var eligible: bool = feedback.is_empty()
	var paid: bool = completed.has(commission_id)
	if eligible:
		feedback = "이 주문의 대금은 이미 받았어요." if paid else "주문에 맞는 나만의 담장을 완성했어요!"
	return {"ok": eligible, "claimed": paid, "reward": int(order.reward), "feedback": feedback}


func claim() -> int:
	var result: Dictionary = evaluate()
	if not bool(result.ok) or bool(result.claimed):
		return 0
	completed.append(commission_id)
	return int(result.reward)


func total_income() -> int:
	var income: int = 0
	for id: String in COMMISSIONS:
		if completed.has(id):
			income += int(COMMISSIONS[id].reward)
	return income


static func _integer_in(value: Variant, low: int, high: int) -> bool:
	if not (value is float or value is int):
		return false
	var number: float = float(value)
	return is_finite(number) and number == floorf(number) and number >= low and number <= high


func to_dict() -> Dictionary:
	var encoded: Array[Dictionary] = []
	for part: Dictionary in _parts:
		var points: Array = []
		for p: Vector2 in part.vertices:
			points.append([p.x, p.y])
		var center: Vector2 = part.position
		var record: Dictionary = {"kind": part.kind, "position": [center.x, center.y], "vertices": points, "palette_index": part.palette_index}
		if part.has("group_id"):
			record["group_id"] = part.group_id
		encoded.append(record)
	return {"version": 2, "commission": commission_id, "columns": columns, "rows": rows, "layout": layout, "completed": completed.duplicate(), "finished": finished, "tile_size": [int(_size.x), int(_size.y)], "parts": encoded}


static func _point_pair(raw: Variant) -> bool:
	if not raw is Array or raw.size() != 2:
		return false
	for coord: Variant in raw:
		if not (coord is int or coord is float) or not is_finite(float(coord)) or absf(float(coord)) > 300.001:
			return false
	return true


static func _read_part(raw: Variant, extent: Vector2) -> Dictionary:
	if not raw is Dictionary or not _known_kind(raw.get("kind")) or not _point_pair(raw.get("position")):
		return {}
	if not _integer_in(raw.get("palette_index"), 0, PALETTE.size() - 1) or not raw.get("vertices") is Array or raw.vertices.size() != 4:
		return {}
	var local: PackedVector2Array = PackedVector2Array()
	var sum: Vector2 = Vector2.ZERO
	for pt: Variant in raw.vertices:
		if not _point_pair(pt):
			return {}
		var point: Vector2 = Vector2(pt[0], pt[1])
		local.append(point)
		sum += point
	if sum.length() > 0.01:
		return {}
	var part: Dictionary = {"kind": str(raw.kind), "position": Vector2(raw.position[0], raw.position[1]), "vertices": local, "palette_index": int(raw.palette_index)}
	if raw.has("group_id"):
		if not _integer_in(raw.group_id, 1, MAX_PIECES):
			return {}
		part["group_id"] = int(raw.group_id)
	return part if _valid(part, extent) else {}


# Version 1 stored a palette and repeat parameters, rather than individual pieces.
# Expanding its active motif at the original scale retains every visible shape.
static func _legacy_polygons(id: String) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	match id:
		"trapezoid_pair":
			result.append(PackedVector2Array([Vector2(0, 0), Vector2(70, 0), Vector2(30, 100), Vector2(0, 100)]))
			result.append(PackedVector2Array([Vector2(70, 0), Vector2(100, 0), Vector2(100, 100), Vector2(30, 100)]))
		"square_frame":
			var outside: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
			var inside: PackedVector2Array = PackedVector2Array([Vector2(25, 25), Vector2(75, 25), Vector2(75, 75), Vector2(25, 75)])
			result.append(inside)
			for edge: int in range(4):
				var next: int = (edge + 1) % 4
				result.append(PackedVector2Array([outside[edge], outside[next], inside[next], inside[edge]]))
		"mirror_stripe":
			# The middle pieces are oblique parallelograms with opposite slopes.
			for band: int in range(2):
				var top: float = band * 50.0
				var bottom: float = top + 50.0
				var a: float = 15.0 if band == 0 else 35.0
				var b: float = 35.0 if band == 0 else 15.0
				result.append(PackedVector2Array([Vector2(0, top), Vector2(a, top), Vector2(b, bottom), Vector2(0, bottom)]))
				result.append(PackedVector2Array([Vector2(a, top), Vector2(a + 50, top), Vector2(b + 50, bottom), Vector2(b, bottom)]))
				result.append(PackedVector2Array([Vector2(a + 50, top), Vector2(100, top), Vector2(100, bottom), Vector2(b + 50, bottom)]))
	return result


static func _read_legacy(data: Dictionary) -> Dictionary:
	var names: Array[String] = ["trapezoid_pair", "square_frame", "mirror_stripe"]
	if not names.has(data.get("motif")) or not _integer_in(data.get("turns"), 0, 3):
		return {}
	if not _integer_in(data.get("tile_columns"), 1, 3) or not _integer_in(data.get("tile_rows"), 1, 3):
		return {}
	if not data.get("colors") is Dictionary or data.colors.size() != names.size():
		return {}
	for id: String in names:
		var tones: Variant = data.colors.get(id)
		if not tones is Array or tones.size() != _legacy_polygons(id).size():
			return {}
		for tone: Variant in tones:
			if not _integer_in(tone, 0, PALETTE.size() - 1):
				return {}
	var polygons: Array[PackedVector2Array] = _legacy_polygons(str(data.motif))
	var parts: Array[Dictionary] = []
	for y: int in range(int(data.tile_rows)):
		for x: int in range(int(data.tile_columns)):
			for i: int in range(polygons.size()):
				var points: PackedVector2Array = polygons[i].duplicate()
				for j: int in range(4):
					var p: Vector2 = points[j]
					for turn: int in range(int(data.turns)):
						p = Vector2(100.0 - p.y, p.x)
					points[j] = p + Vector2(x, y) * 100.0
				var families: Array[String] = Geometry.classifications(points)
				var kind: String = str(families.back()) if not families.is_empty() else Geometry.FREEFORM
				parts.append(_from_world(points, kind, int(data.colors[data.motif][i])))
	return {"parts": parts, "size": Vector2(int(data.tile_columns), int(data.tile_rows)) * 100.0}


func restore(data: Dictionary) -> bool:
	if not _integer_in(data.get("version"), 1, 2):
		return false
	var legacy: bool = int(data.version) == 1
	var order_ids: Array = ["harbor", "garden", "station"] if legacy else COMMISSIONS.keys()
	if not order_ids.has(data.get("commission")) or not LAYOUTS.has(data.get("layout")):
		return false
	if not _integer_in(data.get("columns"), 2, 8) or not _integer_in(data.get("rows"), 2, 6):
		return false
	if not data.get("completed") is Array or data.completed.size() > order_ids.size():
		return false
	var paid: Array[String] = []
	for id: Variant in data.completed:
		if not id is String or not order_ids.has(id) or paid.has(id):
			return false
		paid.append(id)
	var extent: Vector2
	var checked: Array[Dictionary] = []
	if legacy:
		var converted: Dictionary = _read_legacy(data)
		if converted.is_empty():
			return false
		extent = converted["size"]
		checked.assign(converted.parts)
	else:
		var raw_size: Variant = data.get("tile_size")
		if not data.get("finished") is bool:
			return false
		if not _point_pair(raw_size) or not _integer_in(raw_size[0], 100, 300) or not _integer_in(raw_size[1], 100, 300):
			return false
		extent = Vector2(raw_size[0], raw_size[1])
		if extent != DEFAULT_TILE_SIZE and (int(extent.x) % 100 != 0 or int(extent.y) % 100 != 0):
			return false
		if not data.get("parts") is Array or data.parts.size() > MAX_PIECES:
			return false
		var group_sizes: Dictionary[int, int] = {}
		for raw: Variant in data.parts:
			var part: Dictionary = _read_part(raw, extent)
			if part.is_empty():
				return false
			if part.has("group_id"):
				var group_id: int = int(part.group_id)
				group_sizes[group_id] = group_sizes.get(group_id, 0) + 1
			checked.append(part)
		for count: int in group_sizes.values():
			if count < 2:
				return false
		if bool(data.finished) and checked.size() < 2:
			return false
	_size = extent
	_parts = checked
	commission_id = str(data.commission)
	columns = int(data.columns)
	rows = int(data.rows)
	layout = str(data.layout)
	completed = paid
	finished = paid.has(commission_id) if legacy else bool(data.finished)
	_history.clear()
	return true
