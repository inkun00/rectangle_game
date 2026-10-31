class_name ConstructionLanguage
extends RefCounted
## Display copy only. Save keys, material IDs, calculations and price evidence
## retain their original values. Longer phrases precede individual words.

const REPLACEMENTS: Array[Array] = [
	["자재 라이브러리", "재료 상자"], ["정면 입면도", "집 앞모습"], ["입면 설계", "집 짓기"],
	["납품·정산", "집 완성·보상"], ["준공·정산 보고서", "완성한 집과 보상"], ["준공 완료", "집 완성!"],
	["의뢰 확인", "부탁 보기"], ["프로젝트 의뢰", "집 짓기 부탁"], ["공사 견적", "예상 비용"],
	["기초 배치", "첫 배치"], ["집의 앞면", "집 앞모습"],
	["집의 비례", "집 모양의 어울림"], ["지붕과 처마의 마감", "지붕의 어울림"],
	["중력으로 시공을 검사하고 있어요", "무게와 받침을 확인하고 있어요"],
	["시공 검사를 다시 해 주세요", "튼튼한지 다시 확인해 주세요"],
	["시공 검사를 다시 하면", "튼튼한지 다시 확인하면"],
	["시공 검사를 다시 시작할", "튼튼한지 다시 확인할"],
	["시공 검사를 해요", "튼튼한지 확인해요"], ["시공 검사로", "튼튼한지 확인해서"],
	["시공 검사를", "튼튼한지 확인하는 일을"], ["시공 검사", "튼튼한지 확인"],
	["중력 검사 · 문과 창 주변 지지", "무게와 문·창문 받침 확인"],
	["중력 검사를 통과했어요", "무게를 잘 받쳤어요"], ["중력 검사", "무게와 받침 확인"],
	["정산했거나", "보상을 받았거나"], ["정산할 돈", "마지막에 낼 돈"], ["정산하기", "보상 받기"],
	["정산 때", "보상을 받을 때"], ["정산 이익", "남은 돈"], ["정산 기록", "보상 기록"], ["정산", "보상 받기"],
	["먼저 받는 계약금", "먼저 받는 돈"], ["먼저 받은 계약금", "먼저 받은 돈"],
	["집 전체 계약금액", "집 한 채를 지으면 받는 돈"], ["건축 계약금액", "집을 지으면 받는 돈"],
	["계약금액", "약속한 돈"], ["계약금", "먼저 받는 돈"], ["계약하기", "약속하기"], ["계약해요", "약속해요"],
	["계약을", "약속을"], ["계약은", "약속은"], ["계약", "약속"],
	["전면 자재 예산", "집 앞 재료에 쓸 돈"], ["전면 재료비", "집 앞에 쓴 재료값"],
	["기본 공사비", "집의 다른 곳에 드는 돈"], ["공사비", "집 짓는 비용"], ["재료비", "재료값"],
	["자재 예산", "재료에 쓸 돈"], ["자재를", "재료를"], ["자재가", "재료가"], ["자재는", "재료는"], ["자재", "재료"],
	["예산을", "쓸 돈을"], ["예산이", "쓸 돈이"], ["예산도", "쓸 돈도"], ["예산", "쓸 돈"],
	["외장 패널", "꾸미기 판"], ["외장패널", "꾸미기 판"], ["외장판", "꾸미기 판"], ["외장 타일", "벽 꾸미기 타일"],
	["미장", "벽 바르기"], ["징크", "금속"], ["슬레이트", "얇은 돌판"], ["목재", "나무"], ["석재", "돌"], ["구조목", "받침 나무"],
	["받침보예요", "가로 받침이에요"], ["받침보를", "가로 받침을"], ["받침보가", "가로 받침이"], ["받침보", "가로 받침"],
	["구조 벽체로", "튼튼한 벽으로"], ["구조 벽체", "튼튼한 벽"], ["구조벽", "튼튼한 벽"], ["구조 블록", "벽 블록"], ["구조재", "집을 받치는 재료"],
	["구조물", "쌓아 놓은 재료"], ["벽체를", "벽 묶음을"], ["벽체가", "벽 묶음이"], ["벽체는", "벽 묶음은"], ["벽체", "벽 묶음"], ["구조를", "받침을"],
	["처마가", "지붕 끝이"], ["처마를", "지붕 끝을"], ["처마는", "지붕 끝은"], ["처마로", "지붕 끝으로"],
	["처마", "지붕 끝"], ["외벽", "바깥벽"], ["개구부", "자리"], ["하중", "누르는 무게"],
	["기초", "바닥 받침"], ["지지해", "받쳐"], ["지지", "받침"], ["보강해", "더 튼튼하게 해"],
	["모르타르", "벽돌을 붙이는 재료"], ["규격", "크기"], ["입면도", "집 앞모습"], ["입면", "집 앞모습"],
	["골조", "집의 뼈대"], ["설비", "전기·수도 장치"], ["인건비", "일하는 사람에게 주는 돈"], ["공정", "짓는 순서"], ["단가", "하나의 값"],
	["정사각 벽", "정사각형 벽"], ["정사각벽", "정사각형 벽"], ["정사각 창", "정사각형 창"], ["정사각창", "정사각형 창"],
	["정사각 타일", "정사각형 타일"],
	["의뢰인의", "집을 부탁한 사람의"], ["의뢰인에게", "집을 부탁한 사람에게"], ["의뢰인", "집을 부탁한 사람"],
	["의뢰서", "부탁 카드"], ["의뢰를", "부탁을"], ["의뢰는", "부탁은"], ["의뢰가", "부탁이"], ["의뢰", "부탁"],
	["납품 전", "집을 보여 주기 전"], ["납품", "집 보여 주기"], ["준공", "집 완성"],
	["공사 장부", "집 짓기 돈 기록"], ["사무소 장부", "집 짓기 돈 기록"], ["장부", "돈 기록"],
	["견적을", "예상 비용을"], ["견적은", "예상 비용은"], ["견적", "예상 비용"],
	["보수는 한 번만 받아요", "보상은 한 번만 받아요"], ["지불해요", "내요"],
	["전면", "집 앞"], ["필수 부탁", "꼭 해 줄 부탁"], ["선택 자재", "고른 재료"], ["완공", "완성"],
	["프로젝트", "집 짓기"], ["사무소", "우리 작업실"]
]

const GLOSSARY: Array[Dictionary] = [
	{"term": "가로 받침", "title": "가로 받침", "category": "집 짓기", "aliases": ["보", "받침보"], "explanation": "문과 창문 위를 가로질러 놓는 긴 재료예요. 양 끝을 벽으로 받치면 위의 무게를 나누어 받아요."},
	{"term": "지붕 끝", "title": "지붕 끝", "category": "집 짓기", "aliases": ["처마"], "explanation": "벽보다 밖으로 조금 나온 지붕의 끝이에요. 비와 햇빛을 가려 줘요."},
	{"term": "꾸미기 판", "title": "꾸미기 판", "category": "집 짓기", "aliases": ["외장판", "외장 패널", "외장패널"], "explanation": "집 바깥벽에 붙여 색과 무늬를 더해요. 장식이라서 위에 놓인 지붕을 받쳐 주지는 않아요."},
	{"term": "문·창문 자리", "title": "문·창문 자리", "category": "집 짓기", "aliases": ["개구부", "문·창 개구부"], "explanation": "문과 창문이 들어갈 빈자리예요. 이 안은 벽돌로 막지 않고, 둘레를 벽과 가로 받침으로 받쳐요."},
	{"term": "바닥 받침", "title": "바닥 받침", "category": "집 짓기", "aliases": ["기초"], "explanation": "집 아래에서 무게를 땅으로 전해 주는 부분이에요. 그 위에 벽을 차곡차곡 올려요."},
	{"term": "튼튼한지 확인", "title": "튼튼한지 확인", "category": "집 짓기", "aliases": ["시공 검사", "중력 검사"], "explanation": "잠깐 재료에 무게를 주어 떨어지거나 기울어지는 곳을 찾아요. 고칠 곳을 확인한 뒤 다시 지을 수 있어요."},
	{"term": "중력", "title": "중력: 아래로 끌어당기는 힘", "category": "힘과 무게", "aliases": [], "explanation": "지구가 물건을 아래로 끌어당기는 힘이에요. 벽돌 아래에 받침이 없으면 아래로 떨어져요."},
	{"term": "누르는 무게", "title": "누르는 무게", "category": "힘과 무게", "aliases": ["하중"], "explanation": "위에 놓인 재료가 아래를 누르는 무게예요. 받침을 넓히고 양쪽에 고르게 나누어 놓아 봐요."},
	{"term": "받침", "title": "받침", "category": "힘과 무게", "aliases": ["지지"], "explanation": "다른 재료가 떨어지지 않게 아래나 옆에서 받쳐 주는 것이에요. 받침은 바닥까지 이어져야 해요."},
	{"term": "집 앞모습", "title": "집 앞모습", "category": "집 짓기", "aliases": ["입면", "입면도", "정면 입면도"], "explanation": "집을 앞에서 바라본 모습이에요. 벽, 문, 창문, 지붕이 어디에 있는지 한눈에 볼 수 있어요."},
	{"term": "평행", "title": "평행", "category": "도형", "aliases": ["평행한 변"], "explanation": "두 직선을 아무리 길게 늘여도 만나지 않는 것을 말해요. 두 직선 사이는 수직으로 재면 어디서나 거리가 같아요."},
	{"term": "직각", "title": "직각", "category": "도형", "aliases": [], "explanation": "네모 종이의 모서리처럼 반듯하게 꺾인 각이에요. 크기는 90°예요."},
	{"term": "사다리꼴", "title": "사다리꼴", "category": "도형", "aliases": [], "explanation": "평행한 변이 한 쌍 이상 있는 사각형이에요. 한 쌍이든 두 쌍이든 평행한 변이 있는지 확인해요."},
	{"term": "평행사변형", "title": "평행사변형", "category": "도형", "aliases": [], "explanation": "마주 보는 두 쌍의 변이 모두 평행한 사각형이에요. 두 쌍을 각각 확인해요."},
	{"term": "마름모", "title": "마름모", "category": "도형", "aliases": [], "explanation": "네 변의 길이가 모두 같은 사각형이에요. 네 변을 하나씩 재어 비교해요."},
	{"term": "직사각형", "title": "직사각형", "category": "도형", "aliases": [], "explanation": "네 각이 모두 직각인 사각형이에요. 네 변의 길이까지 같으면 정사각형이에요."},
	{"term": "정사각형", "title": "정사각형", "category": "도형", "aliases": [], "explanation": "네 변의 길이가 같고 네 각이 모두 직각인 사각형이에요. 변과 각을 함께 확인해요."},
	{"term": "칸", "title": "칸: 그림 속 길이 단위", "category": "도형", "aliases": ["격자 단위"], "explanation": "작업판의 이웃한 두 눈금 사이 길이를 1칸으로 세어요. 화면에서 확대해도 재료의 실제 칸 수는 바뀌지 않아요."},
	{"term": "예상 비용", "title": "예상 비용", "category": "돈", "aliases": ["견적"], "explanation": "집을 짓는 데 얼마가 들지 미리 계산한 돈이에요. 재료를 바꾸면 예상 비용도 달라져요."},
	{"term": "재료에 쓸 돈", "title": "재료에 쓸 돈", "category": "돈", "aliases": ["예산", "자재 예산"], "explanation": "재료를 고르는 데 쓸 수 있도록 정해 둔 돈이에요. 이 금액 안에서 집을 만들어 봐요."},
	{"term": "먼저 받는 돈", "title": "먼저 받는 돈", "category": "돈", "aliases": ["계약금"], "explanation": "집 짓기를 약속하면 전체 금액 중 일부를 먼저 받아요. 완성할 때 받는 나머지 돈에서는 이 금액을 빼요."},
	{"term": "이익", "title": "이익: 쓰고 남은 돈", "category": "돈", "aliases": [], "explanation": "집을 지어 받은 돈에서 집 짓는 데 쓴 돈을 뺀 금액이에요. 받은 돈에 보너스가 있다면 함께 더해요."},
	{"term": "보너스", "title": "보너스: 추가로 받는 돈", "category": "돈", "aliases": ["만족 보너스"], "explanation": "기본 부탁에 더해 추가 부탁도 들어주면 더 받을 수 있는 돈이에요."},
	{"term": "보상 받기", "title": "보상 받기", "category": "돈", "aliases": ["정산"], "explanation": "튼튼한 집을 완성해 보여 주고 약속한 돈을 받아요. 같은 집의 보상은 한 번만 받아요."}
]

const BEAM_ENDINGS: Dictionary = {"": "", "를": "을", "와": "과", "가": "이", "로": "으로", "의": "의", "에": "에", "에서": "에서"}
static var _beam_word: RegEx

static func simplify(text: String) -> String:
	var result: String = text
	for pair: Array in REPLACEMENTS:
		result = result.replace(str(pair[0]), str(pair[1]))
	if _beam_word == null:
		_beam_word = RegEx.new()
		# 보는 is also a verb (마주 보는 변); keep that educational phrase intact.
		_beam_word.compile("(?<![가-힣A-Za-z0-9_])보(를|와|가|로|의|에서|에)?(?![가-힣A-Za-z0-9_])")
	var matches: Array[RegExMatch] = _beam_word.search_all(result)
	for index: int in range(matches.size() - 1, -1, -1):
		var found: RegExMatch = matches[index]
		var ending: String = str(BEAM_ENDINGS.get(found.get_string(1), ""))
		result = result.left(found.get_start()) + "가로 받침" + ending + result.substr(found.get_end())
	return result

static func glossary() -> Array[Dictionary]:
	return GLOSSARY.duplicate(true)

static func entries() -> Array[Dictionary]:
	return glossary()

static func explanation(term: String) -> String:
	var query: String = term.strip_edges()
	for entry: Dictionary in GLOSSARY:
		if query == str(entry.term) or query == str(entry.title) or entry.aliases.has(query):
			return str(entry.explanation)
	return ""

## Compact contextual help for hover/focus tooltips; glossary() also supports
## a visible help dialog so pointer hover is never the only way to read it.
static func help_for(text: String) -> String:
	var lines: Array[String] = []
	for entry: Dictionary in GLOSSARY:
		var matches: bool = text.contains(str(entry.term))
		for alias: String in entry.aliases:
			# Bare 보 is too short to search within words such as 보너스.
			if alias != "보" and text.contains(alias):
				matches = true
		if matches:
			lines.append("%s: %s" % [str(entry.term), str(entry.explanation)])
		if lines.size() >= 3:
			break
	return "\n".join(lines)
