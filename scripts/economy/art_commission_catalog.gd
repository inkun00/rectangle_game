class_name ArtCommissionCatalog
extends RefCounted

# Saved reward receipts refer to these IDs and targets. Portraits use the shared Starfront crew atlas.
const COMMISSIONS: Array[Dictionary] = [
	{
		"id": "park_poster", "title": "동네 공원", "client": "공원지기", "portrait": 2,
		"brief": "공원에는 뭐가 있나요? 길은 긴 직사각형으로 그리고, 옆에 벤치를 놓아 보세요.",
		"reply": "공원에 놀러 오는 친구들에게 이 그림을 보여 줄게요.",
		"coverage_percent": 55, "visible_shapes": 6, "families": 2,
	},
	{
		"id": "space_mural", "title": "산과 하늘", "client": "등산 안내원", "portrait": 11,
		"brief": "산과 하늘을 그려 주세요. 넓은 직사각형 위에 사다리꼴을 이어서 산을 만들어 보세요.",
		"reply": "산에 오르기 전에 친구들과 이 그림부터 살펴볼게요.",
		"coverage_percent": 45, "visible_shapes": 12, "families": 3,
	},
	{
		"id": "village_map", "title": "우리 집", "client": "이웃 주민", "portrait": 1,
		"brief": "우리 집을 그려 주세요. 벽과 문을 그린 뒤 정사각형 창문을 달아 보세요.",
		"reply": "우리 집에 손님이 오면 이 그림부터 보여 줄 거예요.",
		"coverage_percent": 48, "visible_shapes": 7, "families": 4,
	},
	{
		"id": "library_cover", "title": "친구 얼굴", "client": "책 읽는 친구", "portrait": 6,
		"brief": "친구 얼굴을 그려 주세요. 큰 사각형 얼굴에 작은 사각형으로 눈과 입을 넣어 보세요.",
		"reply": "이 그림을 책 사이에 끼워 두고 오래 보고 싶어요.",
		"coverage_percent": 60, "visible_shapes": 5, "families": 2,
	},
	{
		"id": "harbor_view", "title": "바닷가", "client": "바닷가 안내원", "portrait": 8,
		"brief": "바닷가를 그려 주세요. 긴 직사각형으로 바다를, 사다리꼴로 배를 그려 보세요.",
		"reply": "바닷가에 처음 온 친구들에게 이 그림을 보여 줄게요.",
		"coverage_percent": 50, "visible_shapes": 10, "families": 3,
	},
	{
		"id": "market_banner", "title": "동네 빵집", "client": "빵집 주인", "portrait": 0,
		"brief": "동네 빵집을 그려 주세요. 큰 직사각형 창문 안에 작은 사각형 빵을 놓아 보세요.",
		"reply": "빵을 사러 오는 손님들이 볼 수 있게 창가에 걸어 둘게요.",
		"coverage_percent": 65, "visible_shapes": 8, "families": 2,
	},
	{
		"id": "station_window", "title": "우리 학교", "client": "학교 선생님", "portrait": 14,
		"brief": "학교를 그려 주세요. 긴 사각형으로 건물을 만들고 교실 창문을 줄지어 넣어 보세요.",
		"reply": "학교 복도에 걸어 두고 친구들과 함께 볼게요.",
		"coverage_percent": 43, "visible_shapes": 14, "families": 4,
	},
	{
		"id": "insect_poster", "title": "꽃밭", "client": "정원사", "portrait": 5,
		"brief": "여러 색의 꽃을 그려 주세요. 마름모로 꽃잎을, 긴 직사각형으로 줄기를 만들어 보세요.",
		"reply": "꽃이 피면 이 그림을 들고 꽃밭에 가 보고 싶어요.",
		"coverage_percent": 46, "visible_shapes": 9, "families": 5,
	},
	{
		"id": "festival_stage", "title": "비 오는 날", "client": "동네 친구", "portrait": 3,
		"brief": "창문 밖의 비 오는 모습을 그려 주세요. 사각형 창문과 길쭉한 빗줄기를 넣어 보세요.",
		"reply": "다음에 비가 오면 우리 같이 창밖을 보며 이 그림을 떠올려요.",
		"coverage_percent": 58, "visible_shapes": 16, "families": 4,
	},
]

static func all() -> Array[Dictionary]:
	return COMMISSIONS.duplicate(true)

static func get_commission(id: String) -> Dictionary:
	for commission: Dictionary in COMMISSIONS:
		if id == commission.id: return commission.duplicate()
	return {}

static func requirements(id: String) -> Array[Dictionary]:
	var commission: Dictionary = get_commission(id)
	if commission.is_empty(): return []
	return [
		{"id": "coverage", "label": "도화지의 %d%% 이상 채우기" % int(commission.coverage_percent), "target": int(commission.coverage_percent)},
		{"id": "pieces", "label": "보이는 사각형 %d개 이상 넣기" % int(commission.visible_shapes), "target": int(commission.visible_shapes)},
		{"id": "families", "label": "서로 다른 사각형 %d종류 이상 넣기" % int(commission.families), "target": int(commission.families)},
	]
