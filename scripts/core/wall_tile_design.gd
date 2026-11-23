class_name WallTileDesign
extends RefCounted

const Geometry = preload("res://scripts/core/quadrilateral_math.gd")
const MOTIFS: Dictionary = {
	"trapezoid_pair": "사다리꼴 한 쌍", "square_frame": "정사각형 액자", "mirror_stripe": "평행사변형 물결",
}
const LAYOUTS: Dictionary = {"straight": "나란히", "alternate": "번갈아 반 바퀴", "mirror": "번갈아 뒤집기"}
const PALETTE: Array[Color] = [
	Color("#f4e7ca"), Color("#146e78"), Color("#e76e58"), Color("#e6ae36"),
	Color("#363e73"), Color("#72ada2"), Color("#995778"), Color("#ffffff"),
]
const PALETTE_NAMES: Array[String] = ["모래색", "청록색", "산호색", "금색", "남색", "옥색", "자주색", "흰색"]
const COMMISSIONS: Dictionary = {
	"harbor": {"title": "항구 등대의 물결 벽", "brief": "한 쌍의 사다리꼴을 서로 다른 색으로 칠해요. 이 무늬를 타일 안에 두 번 이상 넣고, 타일을 가로 4장, 세로 2장 이상 놓아 주세요.", "reward": 3000000, "motif": "trapezoid_pair", "columns": 4, "rows": 2},
	"garden": {"title": "온실의 창문 벽", "brief": "액자 가운데 정사각형은 네 테두리와 다른 색으로 칠해요. 타일 안에 액자를 가로·세로 두 번 이상 넣고, 타일을 가로·세로 3장 이상 놓아 주세요.", "reward": 7000000, "motif": "square_frame", "columns": 3, "rows": 3},
	"station": {"title": "우주 정거장의 신호 벽", "brief": "위아래로 기운 두 평행사변형을 다른 색으로 칠해요. 타일 안에 무늬를 두 번 이상 넣고, 타일을 번갈아 뒤집어 가로 4장, 세로 3장 이상 놓아 주세요.", "reward": 12000000, "motif": "mirror_stripe", "columns": 4, "rows": 3},
}

var motif_id: String = "trapezoid_pair"
var layout: String = "straight"
var commission_id: String = "harbor"
var turns: int = 0
var tile_columns: int = 1
var tile_rows: int = 1
var columns: int = 3
var rows: int = 2
var completed: Array[String] = []
var _colors: Dictionary = {"trapezoid_pair": [0, 0], "square_frame": [0, 0, 0, 0, 0], "mirror_stripe": [0, 0, 0, 0, 0, 0]}


func select_motif(id: String) -> bool:
	if not MOTIFS.has(id):
		return false
	motif_id = id
	return true


func set_commission(id: String) -> bool:
	if not COMMISSIONS.has(id):
		return false
	commission_id = id
	return true


func set_color(piece_index: int, palette_index: int) -> bool:
	var colors: Array = _colors[motif_id]
	if piece_index < 0 or piece_index >= colors.size() or palette_index < 0 or palette_index >= PALETTE.size():
		return false
	colors[piece_index] = palette_index
	return true


func set_repeat(wide: int, high: int) -> bool:
	if wide < 2 or wide > 8 or high < 2 or high > 6:
		return false
	columns = wide
	rows = high
	return true


func set_tile_repeat(wide: int, high: int) -> bool:
	if wide < 1 or wide > 3 or high < 1 or high > 3:
		return false
	tile_columns = wide
	tile_rows = high
	return true


func set_layout(id: String) -> bool:
	if not LAYOUTS.has(id):
		return false
	layout = id
	return true


func rotate_tile() -> bool:
	turns = (turns + 1) % 4
	return true


func tile_size() -> Vector2:
	return Vector2(tile_columns, tile_rows) * 100.0


func wall_size() -> Vector2:
	return tile_size() * Vector2(columns, rows)


# Ordered corners share edges exactly. Each complete group fills a 100 by 100 unit.
static func _polygons(id: String) -> Array[PackedVector2Array]:
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


func unit_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var colors: Array = _colors[motif_id]
	for polygon: PackedVector2Array in _polygons(motif_id):
		for i: int in range(polygon.size()):
			var point: Vector2 = polygon[i]
			for turn: int in range(turns):
				point = Vector2(100.0 - point.y, point.x)
			polygon[i] = point
		var index: int = result.size()
		result.append({"vertices": polygon, "index": index, "color": PALETTE[int(colors[index])], "palette_index": int(colors[index])})
	return result


func motif_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var unit: Array[Dictionary] = unit_parts()
	for row: int in range(tile_rows):
		for column: int in range(tile_columns):
			var offset: Vector2 = Vector2(column, row) * 100.0
			for part: Dictionary in unit:
				var copy: Dictionary = part.duplicate()
				copy.vertices = Transform2D(0.0, offset) * PackedVector2Array(part.vertices)
				result.append(copy)
	return result


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
				copy.column = column
				copy.row = row
				result.append(copy)
	return result


func _color_goal(parts: Array[Dictionary]) -> bool:
	match commission_id:
		"harbor":
			return Geometry.parallel_pair_count(parts[0].vertices) == 1 and Geometry.parallel_pair_count(parts[1].vertices) == 1 and parts[0].color != parts[1].color
		"garden":
			if not Geometry.matches_kind(parts[0].vertices, "square"):
				return false
			for i: int in range(1, parts.size()):
				if parts[i].color == parts[0].color:
					return false
			return true
		"station":
			return Geometry.matches_kind(parts[1].vertices, "parallelogram") and Geometry.matches_kind(parts[4].vertices, "parallelogram") and parts[1].color != parts[4].color
	return false


func evaluate() -> Dictionary:
	var order: Dictionary = COMMISSIONS[commission_id]
	var feedback: String = ""
	if motif_id != str(order.motif):
		feedback = "이 주문에는 ‘%s’ 무늬가 필요해요." % str(MOTIFS[order.motif])
	elif not _color_goal(unit_parts()):
		match commission_id:
			"harbor": feedback = "맞닿은 사다리꼴 두 개를 서로 다른 색으로 칠해 보세요."
			"garden": feedback = "가운데 정사각형의 색이 네 테두리 색과 모두 다른지 살펴보세요."
			"station": feedback = "위와 아래의 기울어진 평행사변형 두 개가 서로 다른 색이어야 해요."
	elif commission_id == "garden" and (tile_columns < 2 or tile_rows < 2):
		feedback = "타일 한 장 안에 액자를 가로·세로 두 번 이상 반복해 주세요."
	elif tile_columns * tile_rows < 2:
		feedback = "타일 한 장 안에 같은 무늬를 두 번 이상 넣어 주세요."
	elif columns < int(order.columns) or rows < int(order.rows):
		feedback = "완성한 타일을 가로 %d장, 세로 %d장 이상 놓아 주세요." % [int(order.columns), int(order.rows)]
	elif commission_id == "station" and layout != "mirror":
		feedback = "벽에서 이웃한 타일이 거울처럼 마주 보게 ‘번갈아 뒤집기’를 골라 보세요."
	var eligible: bool = feedback.is_empty()
	var claimed: bool = completed.has(commission_id)
	if eligible:
		feedback = "이 주문의 보상은 이미 받았어요." if claimed else "주문에 꼭 맞는 벽을 완성했어요!"
	return {"ok": eligible, "claimed": claimed, "reward": int(order.reward), "feedback": feedback}


func claim() -> int:
	var result: Dictionary = evaluate()
	if not bool(result.ok) or bool(result.claimed):
		return 0
	completed.append(commission_id)
	return int(result.reward)


func to_dict() -> Dictionary:
	return {"version": 1, "motif": motif_id, "layout": layout, "commission": commission_id, "turns": turns, "tile_columns": tile_columns, "tile_rows": tile_rows, "columns": columns, "rows": rows, "colors": _colors.duplicate(true), "completed": completed.duplicate()}


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


func restore(data: Dictionary) -> bool:
	if not _integer_in(data.get("version"), 1, 1):
		return false
	if not MOTIFS.has(data.get("motif")) or not LAYOUTS.has(data.get("layout")) or not COMMISSIONS.has(data.get("commission")):
		return false
	if not _integer_in(data.get("columns"), 2, 8) or not _integer_in(data.get("rows"), 2, 6) or not _integer_in(data.get("turns"), 0, 3):
		return false
	if not _integer_in(data.get("tile_columns"), 1, 3) or not _integer_in(data.get("tile_rows"), 1, 3):
		return false
	if not data.get("colors") is Dictionary or not data.get("completed") is Array:
		return false
	var colors: Dictionary = data.colors
	if colors.size() != MOTIFS.size():
		return false
	for id: String in MOTIFS:
		if not colors.get(id) is Array or colors[id].size() != _polygons(id).size():
			return false
		for tone: Variant in colors[id]:
			if not _integer_in(tone, 0, PALETTE.size() - 1):
				return false
	var paid: Array[String] = []
	for id: Variant in data.completed:
		if not id is String or not COMMISSIONS.has(id) or paid.has(id):
			return false
		paid.append(id)
	motif_id = str(data.motif)
	layout = str(data.layout)
	commission_id = str(data.commission)
	turns = int(data.turns)
	tile_columns = int(data.tile_columns)
	tile_rows = int(data.tile_rows)
	columns = int(data.columns)
	rows = int(data.rows)
	_colors = colors.duplicate(true)
	completed = paid
	return true
