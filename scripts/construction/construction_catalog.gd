class_name ConstructionCatalog
extends RefCounted

## Prices are an explicitly dated educational snapshot, not a live quotation.
const PRICE_DATE: String = "2026-10-27"
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const GRID_UNIT: float = 20.0
const MATERIAL_IDS: Array[String] = ["brick", "wall", "wall_square", "wall_square_large", "wall_parallelogram", "wall_rhombus", "wall_rhombus_small", "door", "door_short", "window", "window_small", "window_tall", "window_wide", "window_square_large", "window_rhombus", "window_rhombus_small", "lintel", "lintel_long", "beam_trapezoid", "beam_parallelogram", "roof", "roof_medium", "roof_wide", "roof_flat", "roof_flat_wide", "roof_square", "roof_trapezoid_small", "roof_trapezoid_metal", "roof_parallelogram", "roof_parallelogram_long", "panel", "panel_long", "panel_parallelogram_small", "panel_parallelogram_metal", "panel_trapezoid", "panel_trapezoid_wide", "tile_square", "vent_square", "ornament", "ornament_large", "tile_rhombus", "panel_rhombus_copper"]
## Representative catalog families are balanced; mathematical classification
## remains inclusive and is always derived through QuadrilateralMath.
const BALANCED_SPECS: Dictionary = {
	"roof_flat": {"base": "roof", "label": "직사각형 평평한 지붕", "short": "평평한 지붕", "kind": "rectangle", "size": Vector2(200, 40), "role": "roof", "structural": true, "texture": "metal_roof", "description": "네 각이 직각인 평평한 지붕이에요. 벽이나 보 위에 빈틈없이 올려요."},
	"roof_flat_wide": {"base": "roof", "label": "넓은 직사각형 평평한 지붕", "short": "넓고 평평한 지붕", "kind": "rectangle", "size": Vector2(520, 40), "role": "roof", "structural": true, "texture": "metal_roof", "description": "길고 평평한 직사각형 지붕이에요. 네모난 첫 집의 앞면 전체를 덮을 수 있어요."},
	"wall_square_large": {"base": "brick", "label": "큰 정사각형 벽돌 벽체", "short": "큰 정사각벽", "kind": "square", "size": Vector2(80, 80), "role": "wall", "structural": true, "texture": "green_brick", "bricks": 8, "description": "벽돌 여덟 장을 정사각형으로 묶었어요. 바닥부터 벽을 쌓아요."},
	"window_square_large": {"base": "window", "label": "큰 정사각형 불투명 창", "short": "큰 정사각창", "kind": "square", "size": Vector2(120, 120), "role": "window", "structural": false, "texture": "frosted_glass", "description": "네 변이 같은 큰 창이에요. 벽을 쌓을 때 사방을 비워 두고 틀을 받쳐요."},
	"roof_square": {"base": "roof", "label": "정사각형 기와 지붕판", "short": "정사각 지붕", "kind": "square", "size": Vector2(80, 80), "role": "roof", "structural": true, "texture": "clay_roof", "description": "작은 정사각형 지붕판이에요. 벽이나 보 위에 올리고 창문 위를 덮어요."},
	"tile_square": {"base": "panel", "label": "정사각형 모자이크 타일", "short": "정사각 타일", "kind": "square", "size": Vector2(40, 40), "role": "decor", "structural": false, "texture": "mosaic", "description": "네 변이 같고 네 각이 직각인 외장 타일이에요. 실제 벽에 붙여요."},
	"vent_square": {"base": "panel", "label": "정사각형 금속 통풍 격자", "short": "통풍 격자", "kind": "square", "size": Vector2(60, 60), "role": "decor", "structural": false, "texture": "grille", "description": "정사각형 모양의 외벽 격자 장식이에요. 창문 수에는 넣지 않고 벽에 붙여요."},
	"roof_trapezoid_small": {"base": "roof", "label": "작은 사다리꼴 기와 지붕", "short": "작은 사다리지붕", "kind": "trapezoid", "size": Vector2(120, 40), "role": "roof", "structural": true, "texture": "clay_roof", "description": "위아래 변이 평행한 작은 지붕이에요. 좁은 창문 위에도 쓸 수 있어요."},
	"roof_trapezoid_metal": {"base": "roof", "label": "사다리꼴 징크 지붕", "short": "징크 사다리지붕", "kind": "trapezoid", "size": Vector2(240, 80), "role": "roof", "structural": true, "texture": "zinc_roof", "description": "윗변보다 아랫변이 긴 금속 지붕이에요. 아래에 벽이나 보를 받쳐요."},
	"beam_trapezoid": {"base": "lintel", "label": "사다리꼴 목재 처마 받침보", "short": "사다리 받침보", "kind": "trapezoid", "size": Vector2(160, 40), "role": "beam", "structural": true, "texture": "cedar", "description": "위아래 변이 평행한 받침보예요. 양쪽 벽에 걸쳐 처마를 받쳐요."},
	"panel_trapezoid": {"base": "panel", "label": "사다리꼴 미장 외장판", "short": "사다리 외장판", "kind": "trapezoid", "size": Vector2(80, 60), "role": "decor", "structural": false, "texture": "plaster", "description": "평행한 두 변을 찾을 수 있는 외장판이에요. 벽에 붙여 무늬를 만들어요."},
	"panel_trapezoid_wide": {"base": "panel", "label": "넓은 사다리꼴 구리 외장판", "short": "넓은 사다리판", "kind": "trapezoid", "size": Vector2(120, 40), "role": "decor", "structural": false, "texture": "copper", "description": "낮고 넓은 사다리꼴 금속 장식판이에요. 지붕의 하중은 받치지 않아요."},
	"roof_parallelogram": {"base": "roof", "label": "평행사변형 슬레이트 지붕", "short": "기울임 지붕", "kind": "parallelogram", "size": Vector2(200, 60), "role": "roof", "structural": true, "texture": "slate_roof", "description": "마주 보는 변이 두 쌍 모두 평행한 지붕이에요. 수평인 아래 변을 받쳐요."},
	"roof_parallelogram_long": {"base": "roof", "label": "긴 평행사변형 금속 지붕", "short": "긴 기울임지붕", "kind": "parallelogram", "size": Vector2(320, 80), "role": "roof", "structural": true, "texture": "metal_roof", "description": "길이가 다른 평행사변형 지붕이에요. 무게가 쏠리지 않게 벽과 보를 배치해요."},
	"beam_parallelogram": {"base": "lintel", "label": "평행사변형 목재 받침보", "short": "기울임 받침보", "kind": "parallelogram", "size": Vector2(160, 40), "role": "beam", "structural": true, "texture": "louver", "description": "양쪽 끝이 기울어진 목재 보예요. 위아래 평행한 변을 이용해 구조를 이어요."},
	"wall_parallelogram": {"base": "wall", "label": "평행사변형 콘크리트 벽체", "short": "기울임 벽체", "kind": "parallelogram", "size": Vector2(160, 80), "role": "wall", "structural": true, "texture": "concrete", "description": "두 쌍의 평행한 변이 있는 구조 벽체예요. 한 덩어리 벽체이며 벽돌 장수에는 넣지 않아요."},
	"panel_parallelogram_small": {"base": "panel", "label": "작은 평행사변형 삼나무판", "short": "작은 외장판", "kind": "parallelogram", "size": Vector2(60, 40), "role": "decor", "structural": false, "texture": "cedar", "description": "작은 평행사변형 목재판이에요. 다른 길이의 판과 함께 벽 무늬를 만들어요."},
	"panel_parallelogram_metal": {"base": "panel", "label": "평행사변형 금속 외장판", "short": "금속 외장판", "kind": "parallelogram", "size": Vector2(120, 60), "role": "decor", "structural": false, "texture": "copper", "description": "서로 마주 보는 변이 평행한 금속 외장판이에요. 벽에 붙여 꾸며요."},
	"wall_rhombus": {"base": "wall", "label": "마름모 석재 구조 블록", "short": "마름모 구조벽", "kind": "rhombus", "size": Vector2(80, 120), "role": "wall", "structural": true, "texture": "stone", "description": "네 변이 같은 구조 블록이에요. 같은 크기의 블록을 변끼리 이어 마름모 창 둘레와 바닥까지 연결해요. 벽돌 장수에는 넣지 않아요."},
	"wall_rhombus_small": {"base": "wall", "label": "작은 마름모 콘크리트 블록", "short": "작은 마름모벽", "kind": "rhombus", "size": Vector2(40, 60), "role": "wall", "structural": true, "texture": "concrete", "description": "네 변이 같은 작은 구조 블록이에요. 작은 마름모 창의 네 변을 받칠 수 있어요. 벽돌 장수에는 넣지 않아요."},
	"window_rhombus": {"base": "window", "label": "마름모 호박색 유리창", "short": "마름모 창", "kind": "rhombus", "size": Vector2(80, 120), "role": "window", "structural": false, "texture": "amber_glass", "description": "네 변이 같고 직각은 아닌 창이에요. 같은 크기 마름모 구조 블록을 변끼리 이어 네 둘레와 바닥까지 받쳐요."},
	"window_rhombus_small": {"base": "window", "label": "작은 마름모 격자 유리창", "short": "작은 마름모창", "kind": "rhombus", "size": Vector2(40, 60), "role": "window", "structural": false, "texture": "teal_glass", "description": "작은 마름모 창이에요. 벽에 빈자리를 남기고 같은 크기의 마름모 구조 블록으로 네 변을 받쳐요."},
	"tile_rhombus": {"base": "ornament", "label": "마름모 모자이크 외장 타일", "short": "마름모 타일", "kind": "rhombus", "size": Vector2(60, 80), "role": "decor", "structural": false, "texture": "mosaic", "description": "네 변이 같은 외장 타일이에요. 폭과 높이가 변의 길이와 다르다는 것을 살펴봐요."},
	"panel_rhombus_copper": {"base": "ornament", "label": "마름모 구리 외장판", "short": "구리 마름모판", "kind": "rhombus", "size": Vector2(80, 120), "role": "decor", "structural": false, "texture": "copper", "description": "큰 마름모 금속 외장판이에요. 구조 블록과 달리 벽에 붙이는 장식이에요."}
}
const SHORT_LABELS: Dictionary = {"brick": "벽돌 한 장", "wall": "벽돌 9장 묶음", "wall_square": "정사각 벽체", "door": "현관문", "door_short": "낮은 현관문", "window": "정사각 창", "window_small": "작은 정사각 창", "window_tall": "세로 창", "window_wide": "연결창", "lintel": "받침보", "lintel_long": "긴 받침보", "roof": "지붕", "roof_medium": "중간 지붕", "roof_wide": "넓은 지붕", "panel": "외장 패널", "panel_long": "긴 외장 패널", "ornament": "마름모 장식", "ornament_large": "큰 마름모 장식"}
const HOUSE_SOURCE: String = "https://lg.co.kr/media/release/30286"
const SMALL_HOUSE_SOURCE: String = "https://lg.co.kr/media/release/29442"
const BRICK_SOURCE: String = "https://changjobrick.cafe24.com/product/m2/22/50"
const DOOR_SOURCE: String = "https://daelimwood.com/product/제이드-현관문-스틸-팬라이트-도어-투명/45/category/742/display/1/"
const WINDOW_SOURCE: String = "https://m.tigerwood.co.kr/product/jade-이글-3중-싱글슬라이더-쿨그레이/1908/category/95/display/1/"
const ROOF_SOURCE: String = "https://daelimwood.com/product/이중그림자-슁글-지붕재-아스팔트슁글/480/"
const TRIM_SOURCE: String = "https://daelimwood.com/category/시멘트사이딩/180/"
const BEAM_SOURCE: String = "https://daelimwood.com/product/캐나다산-구조재-2x6-12자-38x140mm-목조주택-구조목-건축용/8749/"

static func materials() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in MATERIAL_IDS:
		result.append(material(id))
	return result

static func material(id: String) -> Dictionary:
	var balanced: Dictionary = _balanced_material(id)
	if not balanced.is_empty(): return balanced
	var variant: Dictionary = _variant(id)
	if not variant.is_empty(): return variant
	var item: Dictionary = {}
	match id:
		"brick":
			item = _item(id, "벽돌 한 장", "한 장씩 빈틈을 채워요.", "brick", "rectangle", Vector2(40, 20), 500, 2.5, Color("bd735b"), true)
			item.brick_count = 1
			item.source_url = BRICK_SOURCE
			item.source_note = "판매처 표시가 장당 500원 참고. 세금·운송 조건 미확인. 화면 크기는 학습용 배치 단위예요."
			item.unit = "1장"
		"wall":
			item = _item(id, "벽돌 9장 묶음", "가로 3장, 세로 3줄을 한 번에 쌓아요.", "wall", "rectangle", Vector2(120, 60), 4500, 22.5, Color("bd735b"), true)
			item.brick_count = 9
			item.source_url = BRICK_SOURCE
			item.source_note = "벽돌 500원 × 9장 = 4,500원. 붙이는 재료와 작업비는 기본 공사비에 포함해요."
			item.unit = "9장"
		"door":
			item = _item(id, "직사각형 현관문", "땅에 닿게 놓고, 문 자리를 비워 벽을 쌓아요.", "door", "rectangle", Vector2(80, 120), 572100, 32.0, Color("366c75"), false)
			item.opening = true
			item.source_url = DOOR_SOURCE
			item.source_note = "JADE 스틸 팬라이트 현관문 표시가 572,100원 참고. 손잡이·배송·설치 별도, 화면 규격은 단순화했어요."
			item.unit = "1개"
		"window", "window_wide":
			var square: bool = id == "window"
			item = _item(id, "정사각형 창문" if square else "직사각형 연결창", "창문 자리를 먼저 잡고, 아래·옆·위에 벽과 보를 놓아요.", "window", "square" if square else "rectangle", Vector2(80, 80) if square else Vector2(120, 80), 233300 if square else 466600, 15.0 if square else 30.0, Color("80bfd0"), false)
			item.opening = true
			item.source_url = WINDOW_SOURCE
			item.source_note = "JADE 창 기본 표시가 233,300원 참고. 실제 크기별 견적은 달라요. 게임 창 규격은 학습용이에요." if square else "JADE 창 기본가 233,300원 × 2개 = 466,600원. 두 창을 연결한 하나의 직사각형 창틀로 단순화했어요."
			item.unit = "1개" if square else "2개 연결창"
		"lintel":
			item = _item(id, "직사각형 받침보", "문과 창 위를 가로질러 벽을 받쳐요. 양 끝을 지지해 주세요.", "beam", "rectangle", Vector2(120, 20), 13200, 16.0, Color("c39762"), true)
			item.source_url = BEAM_SOURCE
			item.source_note = "캐나다산 구조재 2×6, 38×140×3600mm 표시가 13,200원 참고. 등급별 옵션·배송 별도. 화면 길이와 물성은 학습용으로 단순화했어요."
			item.unit = "구조목 1개"
		"roof", "roof_wide":
			var wide: bool = id == "roof_wide"
			item = _item(id, "넓은 사다리꼴 지붕" if wide else "사다리꼴 지붕", "평행한 변이 있는 지붕이에요. 벽이나 보 위에 놓아요.", "roof", "trapezoid", Vector2(520, 100) if wide else Vector2(200, 60), 354200 if wide else 177100, 56.0 if wide else 28.0, Color("4f7472"), true)
			item.source_url = ROOF_SOURCE
			item.source_note = "슁글 16장 팩 35,420원 × 10팩 = 354,200원. 열 팩을 넓은 지붕으로 단순화했어요. 가공·설치는 기본 공사비에 포함돼요." if wide else "슁글 16장 팩 35,420원 × 5팩 = 177,100원. 다섯 팩을 지붕 한 조각으로 단순화했어요. 가공·설치는 기본 공사비에 포함돼요."
			item.unit = "10팩 묶음" if wide else "5팩 묶음"
		"panel":
			item = _item(id, "평행사변형 장식판", "두 쌍의 마주 보는 변이 평행해요. 벽에 붙여 꾸며요.", "decor", "parallelogram", Vector2(80, 40), 25400, 2.0, Color("e9bd64"), false)
			item.source_url = TRIM_SOURCE
			item.source_note = "사이딩 7,700원 × 2장 + 게임용 가공비 10,000원. 맞춤 평행사변형 제품의 실제 판매가는 아니에요."
			item.unit = "학습용 가공품"
		"ornament":
			item = _item(id, "마름모 장식", "네 변의 길이가 같은 장식이에요. 벽에 붙여요.", "decor", "rhombus", Vector2(40, 60), 41900, 1.5, Color("f0c96d"), false)
			item.source_url = TRIM_SOURCE
			item.source_note = "트림 15,950원 × 2개 + 게임용 가공비 10,000원. 맞춤 마름모 제품의 실제 판매가는 아니에요."
			item.unit = "학습용 가공품"
	return item

static func _balanced_material(id: String) -> Dictionary:
	if not BALANCED_SPECS.has(id): return {}
	var spec: Dictionary = BALANCED_SPECS[id]
	var result: Dictionary = material(str(spec.base))
	var original_vertices: PackedVector2Array = Math.create_vertices(str(result.kind), result.dimensions)
	var vertices: PackedVector2Array = Math.create_vertices(str(spec.kind), spec.size)
	var area_ratio: float = absf(Math.signed_area(vertices) / Math.signed_area(original_vertices))
	var base_label: String = str(result.label)
	var base_price: int = int(result.price)
	result.id = id
	result.label = str(spec.label)
	result.description = str(spec.description)
	result.kind = str(spec.kind)
	var kinds: Array[String] = [str(spec.kind)]
	result.kinds = kinds
	result.dimensions = Vector2(spec.size)
	result.role = str(spec.role)
	result.structural = bool(spec.structural)
	result.opening = str(spec.role) == "window"
	result.brick_count = int(spec.get("bricks", 0))
	result.mass = float(result.mass) * area_ratio
	result.price = maxi(100, roundi(float(base_price) * area_ratio / 100.0) * 100)
	result.texture_key = str(spec.texture)
	result.unit = "학습용 가공 규격 1개"
	result.source_note = "기본 %s %s × 게임 도형 면적비 약 %s를 100원 단위로 반올림한 가공 추정가예요. 표면 재질별 실제 판매가나 맞춤 규격 견적이 아니에요." % [base_label, format_won(base_price), format_length(area_ratio)]
	if id == "wall_square_large":
		result.price = 4000
		result.source_note = "벽돌 500원 × 8장 = 4,000원. 여덟 장을 정사각형으로 묶은 학습용 규격이며 유약 표면의 별도 실제 판매가를 뜻하지 않아요."
	return result

static func short_label(id: String) -> String:
	if BALANCED_SPECS.has(id): return str(BALANCED_SPECS[id].short)
	return str(SHORT_LABELS.get(id, material(id).get("label", id)))

static func _variant(id: String) -> Dictionary:
	var base_id: String = ""
	var label: String = ""
	var family: String = ""
	var dimensions: Vector2 = Vector2.ZERO
	var price: int = 0
	var note: String = ""
	match id:
		"wall_square":
			base_id = "brick"; label = "정사각 벽돌 2장"; family = "square"; dimensions = Vector2(40, 40); price = 1000
			note = "벽돌 500원 × 2장 = 1,000원. 두 장을 정사각형으로 묶은 학습용 규격이에요."
		"door_short":
			base_id = "door"; label = "낮은 직사각형 문"; dimensions = Vector2(80, 100); price = 476800
			note = "기본 문 572,100원 × 5/6을 100원 단위로 반올림한 게임용 비례 추정가예요. 실제 제품의 판매가나 크기별 견적이 아니에요."
		"window_small":
			base_id = "window"; label = "작은 정사각형 창"; dimensions = Vector2(60, 60); price = 131200
			note = "기본 창 233,300원 × 9/16을 100원 단위로 반올림한 게임용 면적 비례 추정가예요. 실제 크기별 견적이 아니에요."
		"window_tall":
			base_id = "window"; label = "세로 직사각형 창"; family = "rectangle"; dimensions = Vector2(80, 120); price = 350000
			note = "기본 창 233,300원 × 1.5를 100원 단위로 반올림한 게임용 면적 비례 추정가예요. 실제 크기별 견적이 아니에요."
		"lintel_long":
			base_id = "lintel"; label = "긴 직사각형 받침보"; dimensions = Vector2(200, 20); price = 22000
			note = "기본 구조목 13,200원 × 5/3 = 22,000원인 게임용 길이 비례 추정가예요. 실제 구조재 등급·규격별 견적이 아니에요."
		"roof_medium":
			base_id = "roof"; label = "중간 사다리꼴 지붕"; dimensions = Vector2(320, 80); price = 265700
			note = "기본 지붕 묶음 177,100원 × 1.5를 100원 단위로 반올림한 게임용 자재량 추정가예요. 실제 지붕 면적별 시공 견적이 아니에요."
		"panel_long":
			base_id = "panel"; label = "긴 평행사변형 판"; dimensions = Vector2(120, 40); price = 33100
			note = "사이딩 7,700원 × 3장 + 게임용 가공비 10,000원 = 33,100원. 맞춤 평행사변형 제품의 실제 판매가가 아니에요."
		"ornament_large":
			base_id = "ornament"; label = "큰 마름모 장식"; dimensions = Vector2(72, 96); price = 73800
			note = "트림 15,950원 × 4개 + 게임용 가공비 10,000원 = 73,800원. 맞춤 마름모 제품의 실제 판매가가 아니에요. 한 변은 게임 격자 3칸이에요."
		_:
			return {}
	var base: Dictionary = material(base_id)
	var base_vertices: PackedVector2Array = Math.create_vertices(str(base.kind), base.dimensions)
	var kind: String = str(base.kind) if family.is_empty() else family
	var vertices: PackedVector2Array = Math.create_vertices(kind, dimensions)
	base.id = id
	base.label = label
	base.kind = kind
	var kinds: Array[String] = [kind]
	base.kinds = kinds
	base.dimensions = dimensions
	base.mass = float(base.mass) * absf(Math.signed_area(vertices) / Math.signed_area(base_vertices))
	base.price = price
	base.source_note = note
	base.unit = "학습용 규격 1개"
	if id == "wall_square": base.brick_count = 2
	return base

## These dimensions describe game-grid geometry, never metres or retail sizes.
static func dimensions_label(id: String) -> String:
	var item: Dictionary = material(id)
	if item.is_empty(): return ""
	var bounds: Rect2 = Math.bounds(Math.create_vertices(str(item.kind), item.dimensions))
	return "가로 %s칸 · 세로 %s칸" % [format_length(bounds.size.x / GRID_UNIT), format_length(bounds.size.y / GRID_UNIT)]

static func edge_lengths_label(id: String) -> String:
	var item: Dictionary = material(id)
	if item.is_empty(): return ""
	var lengths: PackedFloat32Array = Math.side_lengths(Math.create_vertices(str(item.kind), item.dimensions))
	var labels: Array[String] = []
	for length: float in lengths:
		var cells: float = length / GRID_UNIT
		labels.append(("약 " if absf(cells - snappedf(cells, 0.01)) > 0.0001 else "") + format_length(cells))
	return "변 길이 " + " · ".join(labels) + "칸"

static func format_length(length: float) -> String:
	return ("%.2f" % length).trim_suffix("0").trim_suffix("0").trim_suffix(".")

static func _item(id: String, label: String, description: String, role: String, kind: String, dimensions: Vector2, price: int, mass: float, color: Color, structural: bool) -> Dictionary:
	var kinds: Array[String] = [kind]
	return {"id": id, "label": label, "description": description, "role": role, "kind": kind, "kinds": kinds, "dimensions": dimensions, "price": price, "mass": mass, "color": color, "structural": structural, "opening": false, "source_url": "", "source_note": "", "unit": "1개", "brick_count": 0}

static func stages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var labels: Array[String] = ["첫 네모 집", "넓어지는 지붕", "기울어진 무늬", "다섯 도형 설계", "우리 마을 건축가"]
	var balances: Array[int] = [0, 36000000, 50000000, 75000000, 105000000]
	var profits: Array[int] = [0, 6000000, 20000000, 45000000, 75000000]
	var kinds: Array[String] = ["square", "rectangle"]
	for index: int in range(5):
		if index == 1: kinds.append("trapezoid")
		if index == 2: kinds.append("parallelogram")
		if index == 3: kinds.append("rhombus")
		result.append({"stage": index + 1, "title": labels[index], "minimum_balance": balances[index], "minimum_profit": profits[index], "previous_stage": index, "allowed_kinds": kinds.duplicate(), "minimum_families": mini(index + 2, 5)})
	return result

static func stage(number: int) -> Dictionary:
	return stages()[number - 1] if number >= 1 and number <= 5 else {}

static func contract_count() -> int:
	return 10

static func contract(index: int, grading_version: int = 5) -> Dictionary:
	if grading_version < 5:
		return _legacy_contract(index, grading_version)
	var sequence: int = maxi(index, 0)
	var choice: int = sequence % contract_count()
	var stage_number: int = choice / 2 + 1
	var info: Dictionary = stage(stage_number)
	var titles: Array[String] = ["네모난 첫 집", "햇살 드는 작은 집", "처마가 넓은 집", "포근한 쉼터", "바람을 닮은 집", "기울어진 무늬의 집", "정원이 보이는 집", "다섯 도형의 집", "가족이 모이는 집", "우리 마을 전시집"]
	var clients: Array[String] = ["지우", "민서", "도윤", "하린", "수아", "준서", "유나", "시우", "예린", "도하"]
	var windows: int = 1 if stage_number == 1 else (3 if stage_number == 5 else 2)
	var totals: Array[int] = [100000000, 130000000, 170000000, 200000000, 240000000]
	var base_costs: Array[int] = [95500000, 122000000, 159000000, 185000000, 222000000]
	var advances: Array[int] = [40000000, 50000000, 65000000, 80000000, 95000000]
	var budgets: Array[int] = [2000000, 3000000, 4000000, 5000000, 6000000]
	var bonuses: Array[int] = [500000, 800000, 1000000, 1500000, 2000000]
	var needs: Array[Dictionary] = [
		_need("현관문 1개", "role", "door", 1, true),
		_need("창문 %d개" % windows, "role", "window", windows, true),
		_need("벽돌 %d장 이상으로 벽 만들기" % (36 if stage_number == 5 else 18), "brick_count", "", 36 if stage_number == 5 else 18, true),
		_need("지붕 1개 이상", "role", "roof", 1, true),
		_need("고른 사각형 %d종류 사용하기" % int(info.minimum_families), "family_variety", "", int(info.minimum_families), true)
	]
	var roof_kinds: Array[String] = []
	roof_kinds.assign(info.allowed_kinds)
	var roof_preference: String = "rectangle" if choice % 2 == 0 else "square"
	if stage_number == 2: roof_preference = "trapezoid" if choice % 2 == 0 else "rectangle"
	if stage_number == 3: roof_preference = "parallelogram" if choice % 2 == 0 else "rectangle"
	if stage_number >= 4: roof_preference = "rectangle" if choice % 2 == 0 else "trapezoid"
	# A genuine rectangle preference is checked by the selected family. The
	# broader trapezoid classification elsewhere remains mathematically inclusive.
	needs.append(_need("%s 지붕으로 꾸미기" % Math.kind_name(roof_preference), "selected_roof_kind", roof_preference, 1, false))
	needs.append(_need("정사각형 창문 1개", "window_kind", "square", 1, false))
	needs.append(_length_need("한 변이 4칸인 정사각형 창문 1개", "window", "square", 4.0, 4.0))
	if stage_number >= 3:
		needs.append(_need("평행사변형 꾸밈판 1개", "selected_decor_kind", "parallelogram", 1, false))
	if stage_number >= 4:
		needs.append(_need("마름모 꾸밈판 1개", "selected_decor_kind", "rhombus", 1, false))
	var brief: String = "문 %d개와 창문 %d개가 있는 안전한 집을 부탁해요. 이번에는 %d종류의 사각형을 골라 써 주세요." % [1, windows, int(info.minimum_families)]
	brief += " 지붕은 평평하게 만들어도 좋아요. %s 지붕이면 더 기쁠 거예요." % Math.kind_name(roof_preference)
	if stage_number == 1: brief = "정사각형과 직사각형으로 작은 집을 부탁해요. 평평한 지붕과 문 하나, 창문 하나를 만들어 주세요."
	return {"id": "commission_%d" % sequence, "index": sequence, "choice": choice, "stage": stage_number, "title": titles[choice], "client": clients[choice], "portrait": choice % 6, "brief": brief, "total": totals[stage_number - 1], "advance": advances[stage_number - 1], "base_cost": base_costs[stage_number - 1], "material_budget": budgets[stage_number - 1], "max_bonus": bonuses[stage_number - 1], "requirements": needs, "allowed_kinds": info.allowed_kinds.duplicate(), "roof_allowed_kinds": roof_kinds, "preferred_roof_kind": roof_preference, "source_url": SMALL_HOUSE_SOURCE if stage_number == 1 else HOUSE_SOURCE, "source_note": "공개 주택 가격을 참고한 단계별 게임 계약이에요. 땅값은 제외해요. 단계별 금액과 작업비는 학습을 위한 가상 예산이며 실제 견적이 아니에요."}

static func _legacy_contract(index: int, grading_version: int = 4) -> Dictionary:
	var sequence: int = maxi(index, 0)
	var chapter: int = sequence % 6
	var titles: Array[String] = ["햇살이 드는 첫 집", "책 읽기 좋은 집", "반짝이는 정원집", "바람을 닮은 집", "가족이 모이는 집", "다섯 도형의 집"]
	var clients: Array[String] = ["지우", "민서", "도윤", "하린", "수아", "준서"]
	var briefs: Array[String] = [
		"작은 집을 부탁해요. 문 하나와 창문 하나가 필요해요. 창문은 정사각형이면 더 좋아요!",
		"책을 읽을 방이 밝았으면 좋겠어요. 창문 두 개와 현관문 하나를 만들어 주세요. 정사각형 창문을 좋아해요.",
		"정원을 보며 쉬고 싶어요. 창문 두 개와 문 하나가 필요하고, 네 변이 같은 마름모 장식이 있으면 기쁠 거예요.",
		"바람을 닮은 집을 꿈꿔요. 창문 두 개와 문 하나, 평행사변형 장식판을 넣어 주세요.",
		"가족이 모이는 넓은 집이에요. 창문 세 개와 문 하나가 필요해요. 사다리꼴 지붕을 두 조각 이상 써 주세요.",
		"다섯 종류의 사각형을 찾아볼 수 있는 집을 부탁해요. 문 하나, 창문 두 개와 두 종류의 장식을 넣어 주세요."
	]
	var total: int = 100000000 if chapter < 2 else (199500000 if chapter < 4 else 223500000)
	var base_cost: int = 95500000 if chapter < 2 else (191000000 if chapter < 4 else 213000000)
	var advance: int = 40000000 if chapter < 2 else 80000000
	var budget: int = 2000000 if chapter < 2 else 4000000
	var windows: int = 1 if chapter == 0 else (3 if chapter == 4 else 2)
	var needs: Array[Dictionary] = [
		_need("현관문 1개", "role", "door", 1, true),
		_need("창문 %d개" % windows, "role", "window", windows, true),
		_need("벽돌 18장 이상으로 벽 만들기", "brick_count", "", 18, true),
		_need("지붕 1개 이상", "role", "roof", 1, true)
	]
	match chapter:
		0: needs.append(_need("정사각형 창문 1개", "window_kind", "square", 1, false))
		1: needs.append(_need("정사각형 창문 2개", "window_kind", "square", 2, false))
		2: needs.append(_need("마름모 장식 1개", "decor_kind", "rhombus", 1, false))
		3: needs.append(_need("평행사변형 장식판 1개", "decor_kind", "parallelogram", 1, false))
		4: needs.append(_need("사다리꼴 지붕 2개", "roof_kind", "trapezoid", 2, false))
		5:
			needs.append(_need("마름모 장식 1개", "decor_kind", "rhombus", 1, false))
			needs.append(_need("평행사변형 장식판 1개", "decor_kind", "parallelogram", 1, false))
			needs.append(_need("정사각형 창문 1개", "window_kind", "square", 1, false))
	if grading_version >= 3:
		match chapter:
			0:
				needs.append(_length_need("한 변 4칸인 정사각형 창문 1개", "window", "square", 4.0, 4.0))
				needs.append(_need("긴 변의 길이가 서로 다른 자재 3가지", "length_variety", "", 3, false))
			1:
				needs.append(_length_need("긴 변 6칸인 직사각형 받침보 2개", "beam", "rectangle", 0.0, 6.0, 2))
				needs.append(_need("긴 변의 길이가 서로 다른 자재 4가지", "length_variety", "", 4, false))
			2:
				needs.append(_length_need("한 변 3칸인 마름모 장식 1개", "decor", "rhombus", 3.0, 3.0))
				needs.append(_need("긴 변의 길이가 서로 다른 자재 5가지", "length_variety", "", 5, false))
			3:
				var panel_need: Dictionary = _length_need("긴 변 4칸 이상인 평행사변형 판 1개", "decor", "parallelogram", 0.0, 4.0)
				panel_need.minimum = true
				needs.append(panel_need)
				needs.append(_need("긴 변의 길이가 서로 다른 자재 5가지", "length_variety", "", 5, false))
			4:
				needs.append(_length_need("긴 변 16칸인 사다리꼴 지붕 2개", "roof", "trapezoid", 0.0, 16.0, 2))
				needs.append(_need("긴 변의 길이가 서로 다른 자재 4가지", "length_variety", "", 4, false))
			5:
				needs.append(_length_need("한 변 3칸인 마름모 장식 1개", "decor", "rhombus", 3.0, 3.0))
				var panel_need: Dictionary = _length_need("긴 변 4칸 이상인 평행사변형 판 1개", "decor", "parallelogram", 0.0, 4.0)
				panel_need.minimum = true
				needs.append(panel_need)
				needs.append(_need("긴 변의 길이가 서로 다른 자재 6가지", "length_variety", "", 6, false))
		briefs[chapter] += " 의뢰서의 사각형 종류와 변 길이도 살펴봐 주세요. 길이의 ‘칸’은 게임 격자 단위예요."
	return {"id": "commission_%d" % sequence, "index": sequence, "title": titles[chapter], "client": clients[chapter], "portrait": chapter, "brief": briefs[chapter], "total": total, "advance": advance, "base_cost": base_cost, "material_budget": budget, "max_bonus": 500000 if chapter < 2 else 1000000, "requirements": needs, "source_url": SMALL_HOUSE_SOURCE if chapter < 2 else HOUSE_SOURCE, "source_note": "실제 모듈러 주택 공개 가격을 참고한 계약금액이에요. 토지 제외. 기본 공사비는 기초·골조·설비·실내·인건비·붙임 재료를 묶은 게임용 예산이며 실제 상세 견적이 아니에요."}

static func _need(label: String, category: String, target: String, amount: int, mandatory: bool) -> Dictionary:
	return {"label": label, "category": category, "target": target, "amount": amount, "mandatory": mandatory, "since": 3 if category in ["edge_lengths", "length_variety"] else 1}

static func _length_need(label: String, role: String, kind: String, shortest: float, longest: float, amount: int = 1) -> Dictionary:
	var need: Dictionary = _need(label, "edge_lengths", kind, amount, false)
	need.role = role
	need.shortest = shortest
	need.longest = longest
	need.minimum = false
	return need

static func format_won(amount: int) -> String:
	var digits: String = str(absi(amount))
	var result: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return ("-" if amount < 0 else "") + result + "원"

static func read_won(amount: int) -> String:
	if amount == 0: return "0원"
	var value: int = absi(amount)
	var groups: Array[String] = []
	var units: Array[String] = ["", "만", "억", "조"]
	var index: int = 0
	while value > 0 and index < units.size():
		var chunk: int = value % 10000
		if chunk > 0:
			groups.push_front(format_won(chunk).trim_suffix("원") + units[index])
		value = value / 10000
		index += 1
	return ("마이너스 " if amount < 0 else "") + " ".join(groups) + " 원"
