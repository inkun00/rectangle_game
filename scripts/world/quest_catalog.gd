class_name QuestCatalog
extends RefCounted

## Original adventures based on the supplied Grade 4-2 quadrilateral curriculum.
## Geometric classifications stay inclusive; pupil questions use observable
## sides and angles, not memorised inclusion chains. See PRD curriculum mapping.

static func all_quests() -> Array[Dictionary]:
	var quests: Array[Dictionary] = [
		{
			"id": "rhombus_chocolates", "npc_id": "baker", "npc_name": "초코 제빵사",
			"item_name": "마름모 초콜릿", "item_icon": 0, "item_sheet": "items_atlas", "npc_icon": 0, "npc_sheet": "npc_atlas",
			"title": "달콤한 마름모 4개", "region": "market", "kind": "collect",
			"description": "별빛 축제에 쓸 마름모 초콜릿 4개가 숲으로 가는 길에 떨어졌어요. 네 변의 길이를 살펴 찾아 주세요! 올해는 항구 등대의 별빛이 보이지 않아 걱정이에요.",
			"objective": "마름모 초콜릿 4개 모으기", "target": "rhombus_chocolate", "target_count": 4,
			"question": "마름모 초콜릿은 어떤 성질로 골랐나요?",
			"options": ["네 각이 반드시 직각이에요", "네 변의 길이가 모두 같아요", "평행한 변이 없어요"],
			"answer": 1,
			"explanation": "마름모는 네 변의 길이가 모두 같은 사각형이에요. 방향이나 뾰족해 보이는 정도보다 네 변의 길이를 확인해요.",
			"reward": 20
		},
		{
			"id": "square_puppy", "npc_id": "ranger", "npc_name": "숲지기 나래",
			"item_name": "정사각형 강아지 두부", "item_icon": 1, "item_sheet": "items_atlas", "npc_icon": 2, "npc_sheet": "npc_atlas",
			"title": "네모 강아지 두부를 찾아라", "region": "forest", "kind": "rescue",
			"description": "축제 손님을 마중 나간 강아지 두부가 숲에서 길을 잃었어요. 몸통이 정사각형인 두부를 찾아 주세요. 기울어져 있어도 성질은 같아요. 두부를 데려오면 함께 항구 소식을 기다릴 수 있어요.",
			"objective": "정사각형 강아지 두부 찾기", "target": "square_puppy", "target_count": 1,
			"question": "두부의 몸통이 정사각형인 까닭은 무엇인가요?",
			"options": ["네 변의 길이가 같고 네 각이 모두 직각이에요", "네 변의 길이만 같으면 돼요", "가로로 길게 생겼어요"],
			"answer": 0,
			"explanation": "정사각형은 네 변의 길이가 같고 네 각이 모두 직각이에요. 돌려 놓아도 정사각형이에요. 네 변만 같으면 마름모일 수 있으므로 각도 확인해야 해요.",
			"reward": 30
		},
		{
			"id": "trapezoid_roofs", "npc_id": "roofer", "npc_name": "지붕 장인 모루",
			"item_name": "사다리꼴 기와", "item_icon": 2, "item_sheet": "items_atlas", "npc_icon": 1, "npc_sheet": "npc_atlas",
			"title": "사다리꼴 지붕 수리", "region": "market", "kind": "collect",
			"description": "별빛 축제 손님들이 쉴 지붕을 고치고 있어요. 바람에 날아간 사다리꼴 기와 3개를 모아 주세요. 평행한 변이 한 쌍이라도 있는지 확인하면 돼요. 먼 항구에서 올 손님에게도 따뜻한 자리가 필요해요.",
			"objective": "사다리꼴 기와 3개 모으기", "target": "trapezoid_tile", "target_count": 3,
			"question": "이 마을에서 배우는 사다리꼴에 대한 설명은 무엇인가요?",
			"options": ["평행한 변이 정확히 한 쌍만 있어야 해요", "네 변의 길이가 반드시 같아요", "평행한 변이 있는 사각형이에요"],
			"answer": 2,
			"explanation": "마주 보는 변 중 평행한 변이 있는지 살펴봐요. 평행한 변이 한 쌍이든 두 쌍이든 사다리꼴의 조건에 맞아요.",
			"reward": 20
		},
		{
			"id": "parallelogram_bridge", "npc_id": "carpenter", "npc_name": "목수 평이",
			"item_name": "평행사변형 널빤지", "item_icon": 3, "item_sheet": "items_atlas", "npc_icon": 4, "npc_sheet": "npc_atlas",
			"title": "평행사변형 다리 놓기", "region": "forest", "kind": "collect",
			"description": "축제 손님과 등대를 살피러 가는 탐험가를 위해 계곡 다리를 손보려 해요. 평행사변형 널빤지 3개를 찾아 주세요. 마주 보는 두 쌍의 변이 평행한지 살펴보세요. 탐험길은 언제든 자유롭게 갈 수 있어요.",
			"objective": "평행사변형 널빤지 3개 모으기", "target": "parallelogram_plank", "target_count": 3,
			"question": "널빤지의 한 각이 65°예요. 마주 보는 각과 이웃한 각은 각각 얼마인가요?",
			"options": ["115°, 65°", "65°, 115°", "65°, 65°"],
			"answer": 1,
			"explanation": "평행사변형은 마주 보는 각의 크기가 같아요. 이웃한 두 각의 합은 180°이므로 180° - 65° = 115°예요. 마주 보는 변의 길이도 같고 네 각의 합은 360°예요.",
			"reward": 25
		},
		{
			"id": "rectangle_library", "npc_id": "librarian", "npc_name": "사서 네리",
			"item_name": "직사각형 책", "item_icon": 4, "item_sheet": "items_atlas", "npc_icon": 6, "npc_sheet": "npc_atlas",
			"title": "직사각형 책 배달", "region": "valley", "kind": "collect",
			"description": "오래된 별빛 등대 기록이 담긴 직사각형 책 2권이 산책길에 놓였어요. 네 각이 모두 직각인 책을 찾아 주세요. 기록에는 항구의 빛이 설원의 거울을 거쳐 성곽까지 이어진다고 쓰여 있대요.",
			"objective": "직사각형 책 2권 모으기", "target": "rectangle_book", "target_count": 2,
			"question": "직사각형 책에 대해 언제나 옳은 설명은 무엇인가요?",
			"options": ["네 변의 길이가 반드시 같아요", "반드시 옆으로 길쭉해요", "네 각이 모두 90°예요"],
			"answer": 2,
			"explanation": "직사각형은 네 각이 모두 직각인 사각형이에요. 마주 보는 변의 길이가 같아요. 돌려 놓아도 네 직각은 그대로예요.",
			"reward": 20
		},
		{
			"id": "parallel_rails", "npc_id": "surveyor", "npc_name": "측량사 자로",
			"item_name": "평행선 표식", "item_icon": 5, "item_sheet": "items_atlas", "npc_icon": 5, "npc_sheet": "npc_atlas",
			"title": "평행한 길의 폭 재기", "region": "valley", "kind": "explore",
			"description": "사다리 항구로 이어지는 계곡길을 점검하고 있어요. 평행선 표식 2개를 찾아 주세요. 길의 폭은 두 평행선에 수직으로 재야 정확해요. 축제 손님과 등대 수리 물자가 함께 오갈 길이에요.",
			"objective": "계곡의 평행선 표식 2개 조사하기", "target": "parallel_marker", "target_count": 2,
			"question": "평행선 사이에 수직으로 잰 길이는 4칸, 비스듬히 잰 길이는 5칸이에요. 평행선 사이의 거리는?",
			"options": ["4칸", "5칸", "두 길이 모두 맞아요"],
			"answer": 0,
			"explanation": "평행선 사이의 거리는 두 평행선에 수직인 선분의 길이예요. 비스듬한 선분의 길이를 고르면 안 돼요. 평행한 두 직선을 평행선이라고 불러요.",
			"reward": 25
		},
		{
			"id": "right_angle_sign", "npc_id": "guide", "npc_name": "길잡이 직이",
			"item_name": "직각 도구", "item_icon": 6, "item_sheet": "items_atlas", "npc_icon": 3, "npc_sheet": "npc_atlas",
			"title": "수직 표지판을 세워요", "region": "forest", "kind": "explore",
			"description": "항구의 꺼진 등대를 살피러 갈 친구들이 길을 찾기 쉽게 표지판을 세우려 해요. 숲 언덕의 직각 도구를 찾아 주세요. 두 막대가 수직으로 만나도록 고쳐 볼 거예요.",
			"objective": "숲 언덕의 직각 도구 찾기", "target": "right_angle_tool", "target_count": 1,
			"question": "표지판의 두 직선이 만나 90°를 이루어요. 두 직선의 관계는?",
			"options": ["서로 평행해요", "서로 수직이에요", "길이가 같아요"],
			"answer": 1,
			"explanation": "두 직선이 만나 이루는 각이 직각이면 두 직선은 서로 수직이에요. 직각은 90°예요. 도구를 돌려 놓아도 직각의 크기는 바뀌지 않아요.",
			"reward": 20
		},
		{
			"id": "square_festival", "npc_id": "mayor", "npc_name": "촌장 도담",
			"item_name": "정사각형 축제 배지", "item_icon": 7, "item_sheet": "items_atlas", "npc_icon": 7, "npc_sheet": "npc_atlas",
			"title": "사각형 가족 축제", "region": "valley", "kind": "collect",
			"description": "별빛 축제의 정사각형 배지 3개를 찾아 주세요. 그런데 축제를 비추던 항구 등대가 꺼졌다는 소식이 왔어요. 사다리 항구의 선장 바루를 만나면 그 뒤의 이야기를 들을 수 있을 거예요.",
			"objective": "정사각형 배지 3개 모으기", "target": "square_badge", "target_count": 3,
			"question": "배지가 정사각형인지 확인하려면 무엇을 살펴야 하나요?",
			"options": ["네 변의 길이만 같으면 돼요", "네 각이 직각이기만 하면 돼요", "네 변의 길이가 같고 네 각이 모두 직각인지 확인해요"],
			"answer": 2,
			"explanation": "정사각형은 네 변의 길이가 같고 네 각이 모두 직각이에요. 변과 각, 두 가지 조건을 함께 확인해요.",
			"reward": 40
		},
		{
			"id": "harbor_sails", "npc_id": "sailor", "npc_name": "선장 바루",
			"item_name": "사다리꼴 돛", "item_icon": 0, "item_sheet": "expansion_items", "npc_icon": 0, "npc_sheet": "expansion_npcs",
			"title": "등대로 향하는 사다리꼴 돛", "region": "harbor", "kind": "collect",
			"description": "별빛 축제에 맞춰 켜져야 할 등대가 잠들었어요. 수리 배의 사다리꼴 돛 3개를 모아 주세요. 평행한 변이 있는지 살펴보면 돼요. 항구 사람들의 이야기를 모으면 빛이 끊긴 곳을 찾을 수 있어요.",
			"objective": "사다리꼴 돛 3개 모으기", "target": "trapezoid_sail", "target_count": 3,
			"question": "그림의 돛에서 평행한 변이 있는지 확인했어요. 사다리꼴을 고른 까닭은?",
			"options": ["위쪽 변이 짧아 보여서예요", "평행한 변이 있는 사각형이기 때문이에요", "네 각이 모두 직각이어야 해서예요"],
			"answer": 1,
			"explanation": "사다리꼴은 평행한 변이 있는 사각형이에요. 겉모양이나 방향보다 마주 보는 변이 평행한지 확인해요.",
			"reward": 30
		},
		{
			"id": "harbor_crates", "npc_id": "keeper", "npc_name": "창고지기 네모",
			"item_name": "직사각형 상자", "item_icon": 1, "item_sheet": "expansion_items", "npc_icon": 1, "npc_sheet": "expansion_npcs",
			"title": "직각을 지키는 등대 상자", "region": "harbor", "kind": "collect",
			"description": "등대 수리 도구를 담은 직사각형 상자 2개가 부두에 흩어졌어요. 앞면의 네 각이 직각인지 보고 모아 주세요. 설원에서 온 편지에는 빛을 보내는 거울 창이 눈보라에 흩어졌다고 해요.",
			"objective": "직사각형 상자 2개 모으기", "target": "rectangle_crate", "target_count": 2,
			"question": "상자 앞면의 네 각이 모두 직각이에요. 어떤 설명이 항상 맞나요?",
			"options": ["네 변의 길이도 반드시 같아요", "기울이면 직사각형이 아니에요", "직사각형이고 마주 보는 변의 길이가 같아요"],
			"answer": 2,
			"explanation": "네 각이 모두 직각이면 직사각형이에요. 직사각형은 마주 보는 변의 길이가 같아요. 네 변이 모두 같아야 하는 것은 아니며, 돌려 놓아도 성질은 유지돼요.",
			"reward": 30
		},
		{
			"id": "snow_lanterns", "npc_id": "lamplighter", "npc_name": "등불지기 루리",
			"item_name": "마름모 등불", "item_icon": 2, "item_sheet": "expansion_items", "npc_icon": 2, "npc_sheet": "expansion_npcs",
			"title": "설원에 남은 마름모 불빛", "region": "snow", "kind": "collect",
			"description": "등대로 가던 빛이 거울 설원에서 약해졌어요. 길가의 마름모 등불 3개를 찾아 쉼터로 모아 주세요. 네 변이 같은 등불이 눈 속에서도 길을 알려 줄 거예요.",
			"objective": "마름모 등불 3개 모으기", "target": "rhombus_lantern", "target_count": 3,
			"question": "등불 테두리의 네 변은 각각 6칸이에요. 한 바퀴 두르는 데 필요한 끈의 길이는?",
			"options": ["24칸", "12칸", "18칸"],
			"answer": 0,
			"explanation": "마름모의 네 변의 길이는 같아요. 네 변을 모두 더하면 6 + 6 + 6 + 6 = 24칸이에요.",
			"reward": 35
		},
		{
			"id": "snow_tracks", "npc_id": "tracker", "npc_name": "길잡이 설이",
			"item_name": "평행한 썰매길 표식", "item_icon": 3, "item_sheet": "expansion_items", "npc_icon": 3, "npc_sheet": "expansion_npcs",
			"title": "눈 속의 평행한 썰매길", "region": "snow", "kind": "explore",
			"description": "거울 조각을 옮길 썰매길이 눈에 덮였어요. 평행한 길을 나타내는 표식 2개를 조사해 주세요. 두 길 사이를 수직으로 재면 어느 곳에서나 같은 폭인지 확인할 수 있어요.",
			"objective": "평행한 썰매길 표식 2개 조사하기", "target": "parallel_track", "target_count": 2,
			"question": "두 평행선 사이를 수직으로 재니 4칸, 비스듬히 재니 5칸이에요. 길 사이의 거리는?",
			"options": ["5칸", "4칸", "9칸"],
			"answer": 1,
			"explanation": "평행선 사이의 거리는 두 평행선에 수직인 선분의 길이예요. 비스듬한 선분의 길이를 더하거나 대신 고르지 않아요. 평행선 사이의 거리는 어디에서 수직으로 재도 같아요.",
			"reward": 35
		},
		{
			"id": "snow_windows", "npc_id": "glazier", "npc_name": "유리 장인 미로",
			"item_name": "정사각형 거울 창", "item_icon": 4, "item_sheet": "expansion_items", "npc_icon": 4, "npc_sheet": "expansion_npcs",
			"title": "빛을 잇는 정사각형 거울", "region": "snow", "kind": "collect",
			"description": "성곽의 별빛을 항구로 보내는 거울 창 3개를 모아 주세요. 정사각형 창은 네 변도 같고 네 각도 직각이에요. 창을 돌려 달아도 이 성질은 바뀌지 않아요. 다음 빛의 시작은 별빛 성곽에 있어요.",
			"objective": "정사각형 거울 창 3개 모으기", "target": "square_window", "target_count": 3,
			"question": "정사각형 거울 창을 비스듬히 돌렸어요. 무엇이 그대로인가요?",
			"options": ["네 변의 길이가 서로 달라져요", "네 각이 더 이상 직각이 아니에요", "같은 네 변과 네 직각이 그대로예요"],
			"answer": 2,
			"explanation": "돌려 놓아도 변의 길이와 각의 크기는 바뀌지 않아요. 네 변이 같고 네 각이 직각이므로 여전히 정사각형이에요.",
			"reward": 35
		},
		{
			"id": "citadel_banners", "npc_id": "guardian", "npc_name": "성곽지기 반듯",
			"item_name": "평행사변형 깃발", "item_icon": 5, "item_sheet": "expansion_items", "npc_icon": 5, "npc_sheet": "expansion_npcs",
			"title": "성곽의 평행사변형 깃발", "region": "citadel", "kind": "collect",
			"description": "별빛이 돌아올 길을 표시할 평행사변형 깃발 3개가 필요해요. 마주 보는 두 쌍의 변이 평행한 깃발을 찾아 주세요. 이곳의 기록관과 별지기도 빛을 되찾을 방법을 알고 있어요.",
			"objective": "평행사변형 깃발 3개 모으기", "target": "parallel_banner", "target_count": 3,
			"question": "평행사변형 깃발의 한 각이 70°예요. 그 각과 이웃한 각은 몇 도인가요?",
			"options": ["70°", "110°", "180°"],
			"answer": 1,
			"explanation": "평행사변형에서 이웃한 두 각의 합은 180°예요. 따라서 180° - 70° = 110°예요. 70°인 각과 마주 보는 각은 다시 70°가 돼요.",
			"reward": 40
		},
		{
			"id": "citadel_seals", "npc_id": "archivist", "npc_name": "기록관 아린",
			"item_name": "직사각형 기록 인장", "item_icon": 6, "item_sheet": "expansion_items", "npc_icon": 6, "npc_sheet": "expansion_npcs",
			"title": "네 직각으로 읽는 별빛 기록", "region": "citadel", "kind": "collect",
			"description": "빛을 다루는 오래된 기록에 직사각형 인장 2개가 빠졌어요. 네 각이 직각인 인장을 찾아 주세요. 기록에는 별빛 핵을 모아 성곽에서 설원과 항구로 빛을 잇는 방법이 담겨 있어요.",
			"objective": "직사각형 기록 인장 2개 모으기", "target": "rectangle_seal", "target_count": 2,
			"question": "직사각형 인장의 네 각의 크기를 모두 더하면 얼마인가요?",
			"options": ["180°", "270°", "360°"],
			"answer": 2,
			"explanation": "직사각형의 각은 하나마다 90°예요. 네 각을 더하면 90° × 4 = 360°예요. 이 게임에서 다루는 볼록 사각형은 모두 네 각의 합이 360°예요.",
			"reward": 40
		},
		{
			"id": "starlight_core", "npc_id": "astronomer", "npc_name": "별지기 루나",
			"item_name": "정사각형 별빛 핵", "item_icon": 7, "item_sheet": "expansion_items", "npc_icon": 7, "npc_sheet": "expansion_npcs",
			"title": "다시 빛나는 사각형 월드", "region": "citadel", "kind": "collect",
			"description": "별빛 장치에 들어갈 정사각형 핵 4개를 찾아 주세요. 같은 네 변과 네 직각을 확인해 주세요. 주민들의 손길이 모이면 성곽의 빛이 설원의 거울을 지나 항구 등대를 비추고, 마을 축제까지 환해질 거예요.",
			"objective": "정사각형 별빛 핵 4개 모으기", "target": "square_core", "target_count": 4,
			"question": "별빛 핵이 정사각형인 까닭을 그림의 변과 각으로 설명해 볼까요?",
			"options": ["네 변의 길이가 같고 네 각이 모두 직각이에요", "위쪽으로 뾰족하게 놓여 있어요", "마주 보는 두 변만 길이가 같아요"],
			"answer": 0,
			"explanation": "네 변의 길이가 같고 네 각이 모두 직각인지 확인해요. 도형을 돌리거나 같은 비율로 크게 해도 이 성질은 유지돼요.",
			"reward": 50
		}
	]
	for quest: Dictionary in quests:
		quest["story_description"] = quest.description
		var sentences: PackedStringArray = str(quest.description).split(". ")
		quest.description = ". ".join(sentences.slice(0, 2)).trim_suffix(".") + "."
		quest["topic"] = LearningCatalog.quest_topic(str(quest.id))
		var lesson: Dictionary = LearningCatalog.lesson(str(quest.topic))
		var feedback: Array[String] = []
		for index: int in range(3):
			feedback.append(str(quest.explanation) if index == int(quest.answer) else str(lesson.hint))
		var calculation_hints: Dictionary = {
			"parallelogram_bridge": ["마주 보는 각부터 찾아요. 마주 보는 각은 주어진 65°와 같아요.", "", "이웃한 각까지 같지는 않아요. 이웃한 두 각의 합 180°에서 65°를 빼 보세요."],
			"citadel_banners": ["70°는 마주 보는 각과 같아요. 이웃한 각은 180°에서 70°를 빼요.", "", "180°는 이웃한 두 각의 합이에요. 그중 주어진 70°를 빼 보세요."],
			"snow_lanterns": ["", "12칸은 두 변만 더한 길이예요. 마름모의 같은 네 변을 모두 더해요.", "18칸은 세 변만 더한 길이예요. 마지막 한 변 6칸도 더해요."],
			"citadel_seals": ["180°는 직각 두 개를 더한 값이에요. 네 각을 모두 확인해요.", "270°는 직각 세 개를 더한 값이에요. 네 번째 직각도 더해요.", ""]
		}
		if calculation_hints.has(str(quest.id)):
			for index: int in range(3):
				if index != int(quest.answer): feedback[index] = str(calculation_hints[str(quest.id)][index])
		quest["option_feedback"] = feedback
	return quests


static func get_quest(quest_id: String) -> Dictionary:
	for quest: Dictionary in all_quests():
		if String(quest["id"]) == quest_id:
			return quest
	return {}


static func target_limit(item_id: String) -> int:
	var limit: int = 0
	for quest: Dictionary in all_quests():
		if String(quest["target"]) == item_id:
			limit += int(quest["target_count"])
	return limit


static func region_story(region_id: String) -> Dictionary:
	var stories: Dictionary = {
		"market": {"title": "1장 · 별빛 축제의 아침", "intro": "초록 마을은 별빛 축제를 준비하고 있어요. 그런데 먼 항구 등대의 빛이 보이지 않아요. 먼저 주민들의 이야기를 듣고 여행 준비를 도와주세요.", "outro": "마을의 축제 준비가 든든해졌어요. 바람 숲 너머에서 등대 소식을 기다리는 친구들을 만나 보세요."},
		"forest": {"title": "2장 · 숲길에서 만난 친구들", "intro": "바람 숲에는 길 잃은 두부와 여행길을 정비하는 친구들이 있어요. 도형의 성질을 살피며 길과 친구들을 돌봐 주세요.", "outro": "두부가 돌아오고 숲길의 준비도 끝났어요. 평행 계곡의 도서관에 별빛 등대의 기록이 있다는군요."},
		"valley": {"title": "3장 · 꺼진 등대의 소식", "intro": "평행 계곡에 모인 기록과 축제 배지를 찾아보세요. 별빛 성곽, 설원의 거울, 항구 등대가 하나의 빛길로 이어져 있대요.", "outro": "등대를 살필 단서가 모였어요. 사다리 항구로 가서 선장 바루와 창고지기 네모의 이야기를 들어 보세요."},
		"harbor": {"title": "4장 · 사다리 항구의 잠든 등대", "intro": "등대가 꺼진 사다리 항구에서 수리 배가 기다려요. 돛과 도구 상자를 모으며 설원에서 온 편지의 내용을 알아보세요.", "outro": "수리 배의 돛과 도구가 준비됐어요. 거울 설원의 친구들과 함께 끊어진 빛길을 이어 보세요."},
		"snow": {"title": "5장 · 거울 설원의 빛길", "intro": "눈보라가 흩어 놓은 등불과 거울 창을 찾아요. 평행한 썰매길을 확인하며 별빛을 보내는 거울을 다시 준비해 주세요.", "outro": "설원의 거울을 다시 쓸 준비가 됐어요. 빛이 시작되는 별빛 성곽에서 마지막 친구들을 만나 보세요."},
		"citadel": {"title": "6장 · 다시 빛나는 사각형 월드", "intro": "성곽의 깃발과 기록 인장, 정사각형 별빛 핵을 모아 보세요. 여섯 지역 친구들의 지혜를 모으면 별빛 축제를 다시 밝힐 수 있어요.", "outro": "성곽의 별빛 장치가 준비됐어요! 다른 지역에 남은 부탁도 도우면 등대와 축제를 잇는 이야기가 완성돼요. 이미 모든 친구를 도왔다면, 환해진 사각형 월드의 주인공은 바로 여러분이에요."}
	}
	return stories.get(region_id, {}).duplicate(true)
