class_name ArtCommissionCatalog
extends RefCounted

# Saved reward receipts refer to these IDs and targets. Add new IDs for future revisions.
const COMMISSIONS: Array[Dictionary] = [
	{
		"id": "park_poster", "title": "공원 안내 그림", "client": "공원지기",
		"brief": "공원에 걸 안내 그림이 필요해요. 빈 도화지를 넓게 채워 멀리서도 잘 보이는 그림을 그려 주세요.",
		"coverage_percent": 55, "visible_shapes": 6, "families": 2,
	},
	{
		"id": "space_mural", "title": "우주 관측소 벽화", "client": "관측소 연구원",
		"brief": "관측소 벽을 장식할 그림을 그려 주세요. 여러 사각형을 조합해 별이나 우주 정거장처럼 꾸며 보세요.",
		"coverage_percent": 45, "visible_shapes": 12, "families": 3,
	},
	{
		"id": "village_map", "title": "우리 마을 지도", "client": "마을 안내원",
		"brief": "마을에 처음 온 친구가 볼 지도예요. 길이나 건물, 쉼터를 여러 종류의 사각형으로 표현해 주세요.",
		"coverage_percent": 48, "visible_shapes": 7, "families": 4,
	},
	{
		"id": "library_cover", "title": "도서관 책 표지", "client": "사서",
		"brief": "새 책에 붙일 표지가 필요해요. 큼직한 사각형으로 바탕을 채우고 책 내용을 떠올리게 하는 작은 도형을 넣어 주세요.",
		"coverage_percent": 60, "visible_shapes": 5, "families": 2,
	},
	{
		"id": "harbor_view", "title": "항구 풍경 그림", "client": "등대지기",
		"brief": "등대에 찾아온 친구들에게 보여 줄 그림이에요. 배와 파도, 부두를 여러 사각형으로 나누어 표현해 보세요.",
		"coverage_percent": 50, "visible_shapes": 10, "families": 3,
	},
	{
		"id": "market_banner", "title": "장터 현수막", "client": "장터지기",
		"brief": "장터 입구에 걸 현수막이에요. 멀리서도 잘 보이게 양쪽 끝까지 넓게 채우고 물건이나 가게를 그려 주세요.",
		"coverage_percent": 65, "visible_shapes": 8, "families": 2,
	},
	{
		"id": "station_window", "title": "기차역 창문 무늬", "client": "역무원",
		"brief": "기차역 유리창을 꾸미고 싶어요. 작은 사각형을 여러 개 이어 붙여 저마다 다른 모양이 보이게 해 주세요.",
		"coverage_percent": 43, "visible_shapes": 14, "families": 4,
	},
	{
		"id": "insect_poster", "title": "생태관 곤충 포스터", "client": "생태 해설사",
		"brief": "생태관에 걸 곤충 그림이에요. 몸, 날개, 더듬이에 서로 다른 사각형을 골라 써 보세요.",
		"coverage_percent": 46, "visible_shapes": 9, "families": 5,
	},
	{
		"id": "festival_stage", "title": "축제 무대 배경", "client": "축제 진행자",
		"brief": "마을 축제 무대를 꾸밀 그림이에요. 넓은 배경을 채우고 깃발과 조명은 여러 사각형을 이어 그려 주세요.",
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
