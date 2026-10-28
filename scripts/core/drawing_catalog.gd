class_name DrawingCatalog
extends RefCounted
## Curated scene metadata and original geometric studies of public-domain works.

const ROOT: String = "res://assets/generated/drawing/"
const BACKGROUND_DATA: Array[Array] = [
	["city_day", "맑은 도시", "도시"], ["city_night", "야경 도시", "도시"],
	["seaside", "푸른 바다", "바다"], ["sunset_beach", "노을 해변", "바다"], ["coral_reef", "산호 바닷속", "바다"],
	["space_planets", "행성 우주", "우주"], ["moon_base", "달 기지", "우주"], ["galaxy", "은하수", "우주"],
	["green_mountains", "초록 산", "산"], ["snowy_mountains", "눈 덮인 산", "산"], ["autumn_mountains", "단풍 산", "산"],
	["cozy_home", "포근한 집", "집"], ["treehouse", "나무집", "집"], ["country_cottage", "시골집", "집"],
	["forest", "숲속 산책", "자연"], ["bamboo_forest", "대나무 숲", "자연"], ["desert", "사막", "자연"],
	["oasis", "오아시스", "자연"], ["polar", "빙하", "자연"], ["meadow", "꽃 들판", "자연"],
	["farm", "농장", "마을"], ["garden", "정원", "자연"], ["castle", "성", "마을"], ["village", "작은 마을", "마을"],
	["harbor", "항구", "바다"], ["river", "강변", "자연"], ["lake", "호수", "자연"],
	["waterfall", "폭포", "자연"], ["rainbow_sky", "무지개 하늘", "하늘"], ["playground", "놀이터", "도시"]
]
const MASTERPIECE_DATA: Array[Array] = [
	["starry_night", "별이 빛나는 밤", "빈센트 반 고흐", "1889", "밤하늘의 빛과 마을을 크고 작은 사각형으로 채워 봐요.", "https://www.moma.org/collection/works/79802"],
	["sunflowers", "해바라기", "빈센트 반 고흐", "1889", "꽃잎은 마름모로, 화병은 사다리꼴로 표현해 봐요.", "https://www.vangoghmuseum.nl/en/collection/s0031V1962"],
	["bedroom", "아를의 침실", "빈센트 반 고흐", "1888", "침대와 창문, 의자의 기울기를 살펴보며 방을 꾸며 봐요.", "https://www.vangoghmuseum.nl/en/collection/s0047V1962"],
	["mona_lisa", "모나리자", "레오나르도 다 빈치", "1503–1519", "차분한 얼굴과 겹친 두 손을 사각형 조각으로 표현해 봐요.", "https://collections.louvre.fr/en/ark:/53355/cl010062370"],
	["pearl_earring", "진주 귀걸이를 한 소녀", "요하네스 페르메이르", "약 1665", "파란 머리 천과 반짝이는 귀걸이에 나만의 색을 더해 봐요.", "https://www.mauritshuis.nl/en/our-collection/artworks/670-girl-with-a-pearl-earring"],
	["great_wave", "가나가와 해변의 높은 파도", "가쓰시카 호쿠사이", "약 1830–1832", "길쭉한 사각형으로 넘실대는 파도와 작은 배를 만들어 봐요.", "https://www.metmuseum.org/art/collection/search/45434"],
	["water_lilies", "수련", "클로드 모네", "1914–1926", "물 위의 꽃과 길게 비친 빛을 여러 사각형으로 채워 봐요.", "https://www.moma.org/collection/works/80220"],
	["red_blue_yellow", "빨강, 파랑, 노랑의 구성", "피트 몬드리안", "1930", "직사각형과 정사각형의 크기, 세 가지 색의 균형을 찾아봐요.", "https://kunsthaus.ch/en/sammlung/klassische-moderne/"],
	["the_scream", "절규", "에드바르 뭉크", "1893", "노을과 다리의 기울기를 관찰하고 인물의 표정을 표현해 봐요.", "https://www.nasjonalmuseet.no/en/collection/object/NG.M.00939"],
	["apple_basket", "사과 바구니", "폴 세잔", "약 1893", "탁자 위의 사과와 바구니를 따뜻한 색의 사각형으로 채워 봐요.", "https://www.artic.edu/artworks/111436/the-basket-of-apples"]
]

static func backgrounds() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Array in BACKGROUND_DATA:
		result.append({"id": str(row[0]), "name": str(row[1]), "category": str(row[2]), "path": ROOT + "backgrounds/" + str(row[0]) + ".png"})
	return result

static func masterpieces() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Array in MASTERPIECE_DATA:
		result.append({"id": str(row[0]), "name": str(row[1]), "artist": str(row[2]), "year": str(row[3]), "description": str(row[4]), "source_url": str(row[5]), "path": ROOT + "masterpieces/" + str(row[0]) + ".svg", "reference_path": ROOT + "masterpieces/" + str(row[0]) + "-reference.svg"})
	return result

static func background(id: String) -> Dictionary:
	for entry: Dictionary in backgrounds():
		if str(entry.id) == id:
			return entry
	return {}

static func masterpiece(id: String) -> Dictionary:
	for entry: Dictionary in masterpieces():
		if str(entry.id) == id:
			return entry
	return {}
