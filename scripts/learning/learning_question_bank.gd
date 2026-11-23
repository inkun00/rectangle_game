class_name LearningQuestionBank
extends RefCounted

const Catalog = preload("res://scripts/learning/learning_catalog.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const TYPES: Array[String] = ["lines", "distance", "parallel_sides", "equal_sides", "right_angles"]
const ORIGINAL_PER_TYPE: int = 20
const PER_TYPE: int = 40
const GRID_SIZE: Vector2i = Vector2i(10, 6)
const FIGURE_SETS: Dictionary = {
	"trapezoid": [["trapezoid", "general", "rectangle", "parallelogram"], ["general", "trapezoid", "general", "rhombus"], ["square", "rhombus", "general", "trapezoid"], ["general", "rectangle", "general", "general"]],
	"parallelogram": [["parallelogram", "trapezoid", "rectangle", "general"], ["square", "general", "rhombus", "trapezoid"], ["trapezoid", "general", "parallelogram", "trapezoid"], ["rectangle", "square", "trapezoid", "parallelogram"]],
	"rhombus": [["rhombus", "square", "rectangle", "general"], ["trapezoid", "parallelogram", "square", "rectangle"], ["rhombus", "rectangle", "rhombus", "square"], ["general", "rhombus", "parallelogram", "trapezoid"]],
	"rectangle": [["rectangle", "rhombus", "square", "parallelogram"], ["general", "trapezoid", "square", "rhombus"], ["rectangle", "square", "trapezoid", "rectangle"], ["trapezoid", "rectangle", "general", "rhombus"]],
	"square": [["square", "rectangle", "rhombus", "square"], ["general", "trapezoid", "square", "rectangle"], ["square", "rhombus", "square", "parallelogram"], ["rectangle", "square", "rhombus", "trapezoid"]],
}

# Each row begins with its curriculum lesson and prompt and ends with its own hint.
# The intervening fields contain the answer(s) and, for choice questions, distractors.
const CHOICE_ITEMS: Dictionary = {
	"lines": [
		["perpendicular", "직사각형 공책의 위쪽 변에 수직인 선은 어느 것인가요?", "공책의 왼쪽 변", "공책의 아래쪽 변", "위쪽 변을 길게 이은 선", "위쪽 변에서 만나는 각이 직각인지 떠올려요."],
		["parallel", "종이에 떨어져 있는 두 선분이 보여요. 두 선분이 평행한지 어떻게 확인할까요?", "두 선분을 양쪽으로 늘여도 만나지 않는지 본다", "두 선분의 길이만 비교한다", "두 선분의 끝점을 잇는다", "평행한 두 직선은 같은 평면에서 아무리 늘여도 만나지 않아요."],
		["perpendicular", "두 직선이 만나는 곳의 각 하나가 90°예요. 바로 알 수 있는 사실은 무엇인가요?", "두 직선은 서로 수직이다", "두 직선은 평행하다", "두 직선은 만나지 않는다", "직각으로 만나는 두 직선의 관계를 떠올려요."],
		["parallel", "곧고 평행한 기찻길을 그린 종이를 돌렸어요. 두 레일을 나타내는 직선은 어떻게 될까요?", "여전히 평행하다", "서로 수직이 된다", "가까이에서 만난다", "종이 전체를 돌릴 때 두 선 사이의 간격이 변하는지 생각해요."],
		["perpendicular", "사각이가 삼각자의 직각 모서리로 수선을 그리려고 해요. 어떻게 해야 할까요?", "직각을 낀 한 변을 기준선에 맞추고 다른 변을 따라 긋는다", "가장 긴 변을 기준선에서 멀리 놓는다", "삼각자의 뾰족한 각을 기준선에 맞춘다", "수선은 기준선과 직각으로 만나요."],
	],
	"distance": [
		["distance", "곧고 평행한 강둑 사이의 폭을 재려고 해요. 어떤 줄을 놓을까요?", "두 강둑에 수직인 곧은 줄", "두 강둑을 비스듬히 잇는 줄", "한쪽 강둑을 따라 놓은 줄", "폭은 두 평행선 사이의 가장 짧은 길이예요."],
		["distance", "평행한 두 울타리 사이를 수직으로 재니 4 m였어요. 옆으로 열 걸음 간 뒤 수직으로 재면 얼마일까요?", "4 m", "열 걸음 더 긴 거리", "걸을 때마다 다른 거리", "평행선의 간격은 재는 위치에 따라 달라지지 않아요."],
		["distance", "서로 평행한 두 선을 잇는 선분의 길이가 5 cm, 6 cm, 8 cm예요. 세 선분 중 하나가 두 선에 수직이라면 어느 것일까요?", "5 cm인 선분", "6 cm인 선분", "8 cm인 선분", "두 평행선을 잇는 선분 중 수직인 선분이 가장 짧아요."],
		["distance", "평행한 두 도로를 종이에 그렸어요. 두 도로 사이의 거리를 바꾸는 방법은 무엇일까요?", "한 도로만 다른 도로에서 수직으로 멀리 옮긴다", "그림 전체를 돌린다", "두 도로를 같은 방향으로 똑같이 옮긴다", "두 도로의 간격이 달라져야 해요."],
		["distance", "두 평행선 사이를 잘못 잰 친구는 누구인가요?", "준호: 비스듬히 잰 길이를 적었어.", "수빈: 한 선에서 다른 선까지 수선을 그었어.", "지우: 수직으로 놓은 자의 두 눈금을 빼서 구했어.", "자로 잰 방향이 두 선과 직각인지 확인해요."],
	],
	"parallel_sides": [
		["trapezoid", "어느 설명만으로 사다리꼴임을 알 수 있을까요?", "평행한 변이 한 쌍 이상인 사각형이다", "한 변이 긴 사각형이다", "각 하나가 뾰족한 사각형이다", "사다리꼴은 평행한 변이 있는 사각형이에요."],
		["parallelogram", "놀이판 조각이 평행사변형인지 확인하려고 해요. 무엇을 볼까요?", "마주 보는 두 쌍의 변이 각각 평행한지", "네 변이 모두 같은 색인지", "한 변이 가로로 놓였는지", "마주 보는 변을 한 쌍씩 살펴요."],
		["trapezoid", "평행한 변이 딱 한 쌍인 사각형에 항상 붙일 수 있는 이름은 무엇인가요?", "사다리꼴", "평행사변형", "직사각형", "평행사변형과 직사각형은 마주 보는 두 쌍의 변이 모두 평행해요."],
		["parallelogram", "평행사변형 종이의 한 변을 빨갛게 칠했어요. 이 변과 평행한 변은 어디에 있나요?", "빨간 변과 마주 보는 곳", "빨간 변의 왼쪽 끝에 맞닿은 곳", "빨간 변의 오른쪽 끝에 맞닿은 곳", "평행사변형에서 서로 마주 보는 두 변의 관계를 떠올려요."],
		["trapezoid", "평행사변형을 사다리꼴 모음에 놓은 까닭은 무엇일까요?", "평행한 변이 한 쌍 이상 있기 때문이다", "네 변이 언제나 모두 같기 때문이다", "네 각이 언제나 모두 직각이기 때문이다", "사다리꼴은 평행한 변이 한 쌍이어도, 두 쌍이어도 돼요."],
	],
	"equal_sides": [
		["rhombus", "나무 막대 네 개로 마름모를 만들어요. 어떤 막대 꾸러미를 고를까요?", "4 cm, 4 cm, 4 cm, 4 cm", "3 cm, 5 cm, 3 cm, 5 cm", "4 cm, 4 cm, 4 cm, 6 cm", "마름모의 네 변은 모두 길이가 같아요."],
		["rhombus", "꼭짓점이 위를 향한 사각형이에요. 마름모인지 알려면 무엇을 더 확인해야 할까요?", "네 변의 길이가 모두 같은지", "그림이 기울어 보이는지", "맨 위 꼭짓점이 뾰족한지", "그림을 돌리면 놓인 방향은 바뀌어도 변의 길이는 그대로예요."],
		["rhombus", "네 변이 모두 5 cm인 사각형이에요. 꼭 들어맞는 설명을 골라요.", "마름모이다", "네 각이 모두 직각이다", "한 각이 반드시 60°이다", "변의 길이가 알려 주는 성질과 각을 재야 알 수 있는 성질을 구별해요."],
		["rhombus", "마름모의 세 변을 재니 모두 7 cm였어요. 마지막 변을 무엇이라고 예상할 수 있을까요?", "7 cm", "14 cm", "21 cm", "같은 마름모에 있는 네 변의 길이를 비교해요."],
		["rhombus", "정사각형 타일을 마름모 모음에 넣을 수 있는 까닭은 무엇인가요?", "네 변의 길이가 모두 같아서", "네 각이 모두 직각이기만 하면 되어서", "타일이 꼭 기울어져 있어서", "마름모를 구별하는 조건은 네 변의 길이에 있어요."],
	],
	"right_angles": [
		["rectangle", "어느 설명만으로 직사각형임을 알 수 있을까요?", "네 각이 모두 직각인 사각형이다", "네 변이 모두 같은 사각형이다", "한 각이 둔각인 사각형이다", "직사각형은 변의 길이보다 네 각을 확인해요."],
		["square", "직사각형 종이가 정사각형이기도 한지 확인하려면 무엇을 더 살펴야 할까요?", "네 변의 길이가 모두 같은지", "가로 방향으로 놓였는지", "네 각이 서로 다른지", "직사각형의 네 각은 이미 직각이에요."],
		["rectangle", "긴 직사각형 액자를 비스듬히 걸었어요. 액자의 네 각은 어떻게 되었을까요?", "네 각 모두 90° 그대로이다", "위쪽 두 각만 작아진다", "네 각 모두 서로 달라진다", "도형 전체를 돌려도 모서리가 벌어진 정도는 그대로예요."],
		["square", "네 변이 모두 같은 사각형에 어떤 조건을 더하면 정사각형이라고 확신할 수 있을까요?", "네 각이 모두 직각이다", "종이가 파란색이다", "한 꼭짓점이 위를 향한다", "정사각형은 변의 길이와 각의 크기를 함께 확인해요."],
		["rectangle", "네 각이 모두 직각이고 이웃한 두 변이 3 cm와 5 cm인 타일이에요. 알맞은 이름은 무엇인가요?", "직사각형", "정사각형", "마름모", "네 각은 모두 직각이지만 이웃한 두 변의 길이가 달라요."],
	],
}

const SHORT_ITEMS: Dictionary = {
	"lines": [
		["perpendicular", "두 직선이 수직으로 만나면 생기는 직각의 크기는 몇 도인가요?", ["90", "90도", "90°", "구십도"], "직각자의 모서리가 나타내는 각의 크기를 떠올려요."],
		["parallel", "같은 평면에서 서로 다른 두 직선을 아무리 늘여도 만나지 않아요. 이런 두 직선을 무엇이라고 하나요?", ["평행선", "평행한 두 직선", "평행한 직선", "평행한 두 선"], "나란히 달리는 곧은 두 레일을 떠올려요."],
		["perpendicular", "한 직선에 수직으로 그은 직선을 무엇이라고 하나요? 두 글자로 써 보세요.", ["수선"], "‘수직으로 그은 직선’을 줄인 두 글자예요."],
		["perpendicular", "두 직선이 수직으로 교차해요. 만나는 점 둘레에 직각은 모두 몇 개 생기나요?", ["4", "4개", "네 개", "네", "넷"], "교차점을 중심으로 한 바퀴 돌며 직각을 세어 봐요."],
		["parallel", "같은 평면에 있는 서로 다른 두 직선이 평행해요. 두 직선이 만나는 점은 몇 개인가요?", ["0", "0개", "영", "영 개", "없다", "없음", "없어요"], "두 선을 양쪽으로 계속 늘였다고 생각해요."],
	],
	"distance": [
		["distance", "자의 눈금 2 cm와 8 cm가 각각 두 평행선 위에 있어요. 자가 두 선에 수직일 때 두 선 사이의 거리는 몇 cm인가요?", ["6", "6cm", "6센티미터", "육 센티미터"], "끝 눈금에서 시작 눈금을 빼요."],
		["distance", "한 칸의 길이가 2 cm인 모눈종이에 가로선 두 개를 그었어요. 두 선 사이가 세로로 4칸이면 거리는 몇 cm인가요?", ["8", "8cm", "8센티미터", "팔 센티미터"], "한 칸의 길이를 네 번 더해요."],
		["distance", "평행한 두 울타리 사이의 거리는 7 m예요. 3 m쯤 옆으로 걸어가서 다시 수직으로 재면 몇 m인가요?", ["7", "7m", "7미터", "칠 미터"], "평행선 사이의 거리는 어디에서 수직으로 재도 같아요."],
		["distance", "두 평행선 사이의 거리는 5 cm예요. 한 선을 다른 선에서 수직으로 2 cm 더 멀리 옮기면 새 거리는 몇 cm인가요?", ["7", "7cm", "7센티미터", "칠 센티미터"], "멀어진 만큼 처음 간격에 더해요."],
		["distance", "세 직선이 나란해요. 첫째와 둘째 사이 거리는 3 cm, 둘째와 셋째 사이 거리는 6 cm예요. 둘째가 가운데라면 첫째와 셋째 사이 거리는 몇 cm인가요?", ["9", "9cm", "9센티미터", "구 센티미터"], "바깥쪽 두 선 사이에는 두 간격이 이어져 있어요."],
	],
	"parallel_sides": [
		["parallelogram", "평행사변형에서 서로 평행한 변은 모두 몇 쌍인가요?", ["2", "2쌍", "두 쌍", "두", "둘"], "한 쌍을 찾은 뒤 나머지 두 변도 비교해요."],
		["trapezoid", "사각형이 사다리꼴이려면 평행한 변이 적어도 몇 쌍 있어야 할까요?", ["1", "1쌍", "한 쌍", "한", "하나"], "‘적어도’는 조건을 만족하는 가장 작은 수를 물어요."],
		["parallelogram", "마주 보는 두 쌍의 변이 각각 평행한 사각형을 부르는 다섯 글자 이름은 무엇인가요?", ["평행사변형"], "모양이 기울었는지보다 마주 보는 두 쌍의 변을 살펴요."],
		["trapezoid", "평행한 변이 딱 한 쌍인 사각형의 이름을 써 보세요.", ["사다리꼴"], "이 사각형에는 서로 평행한 두 변이 있어요."],
		["parallelogram", "평행사변형 종이의 한 변이 6 cm예요. 그 변과 마주 보는 변은 몇 cm인가요?", ["6", "6cm", "6센티미터", "육 센티미터"], "평행사변형의 마주 보는 두 변은 길이도 같아요."],
	],
	"equal_sides": [
		["rhombus", "마름모의 한 변이 5 cm예요. 네 변의 길이를 모두 더하면 몇 cm인가요?", ["20", "20cm", "20센티미터", "이십 센티미터"], "마름모에는 길이가 같은 변이 네 개 있어요."],
		["rhombus", "마름모 테두리 전체 길이가 24 cm예요. 한 변은 몇 cm인가요?", ["6", "6cm", "6센티미터", "육 센티미터"], "전체 길이를 네 변에 똑같이 나누어요."],
		["rhombus", "네 변이 모두 같은 사각형의 세 글자 이름을 써 보세요.", ["마름모"], "정사각형도 이 도형의 성질을 가지고 있어요."],
		["rhombus", "한 변이 3 cm인 마름모 두 개의 테두리를 각각 실로 둘러요. 실은 모두 몇 cm 필요한가요?", ["24", "24cm", "24센티미터", "이십사 센티미터"], "한 마름모에 필요한 길이를 먼저 구한 뒤 두 배 해요."],
		["rhombus", "마름모의 한 변이 4 cm에서 6 cm로 늘었어요. 나머지 변도 똑같이 늘었다면 테두리 전체는 몇 cm 더 길어졌나요?", ["8", "8cm", "8센티미터", "팔 센티미터"], "한 변에서 늘어난 길이를 네 번 더해요."],
	],
	"right_angles": [
		["rectangle", "직사각형의 네 모서리 중 직각인 것은 모두 몇 개인가요?", ["4", "4개", "네 개", "네", "넷"], "네 꼭짓점에서 이웃한 두 변이 만나는 각을 떠올려요."],
		["square", "네 각이 직각이고 네 변의 길이가 모두 같은 사각형의 네 글자 이름을 써 보세요.", ["정사각형"], "각의 크기와 변의 길이를 모두 이름에 담은 도형을 떠올려요."],
		["rectangle", "가로 6 cm, 세로 3 cm인 직사각형의 테두리 전체 길이는 몇 cm인가요?", ["18", "18cm", "18센티미터", "십팔 센티미터"], "가로 변과 세로 변이 각각 두 개씩 있어요."],
		["square", "한 변이 5 cm인 정사각형 종이의 이웃한 두 변을 따라가면 모두 몇 cm를 가나요?", ["10", "10cm", "10센티미터", "십 센티미터"], "같은 길이의 변을 두 번 따라가요."],
		["rectangle", "직사각형 종이를 반 바퀴 돌렸어요. 모서리 하나의 각은 몇 도인가요?", ["90", "90도", "90°", "구십도"], "도형을 돌려도 각의 크기는 변하지 않아요."],
	],
}

const ORDER_ITEMS: Dictionary = {
	"lines": [
		["perpendicular", "직선 위의 점 ㄱ에서 수선을 그어요. 할 일을 순서대로 골라요.", "삼각자의 직각 꼭짓점을 ㄱ에 놓기", "ㄱ을 고정하고 한 변을 직선에 맞추기", "직각의 다른 변을 따라 선 긋기", "삼각자의 직각을 끼고 있는 두 변을 이용해요."],
		["perpendicular", "각도기로 두 직선이 수직인지 확인하는 순서를 맞춰요.", "각도기 중심을 두 직선이 만나는 점에 놓기", "중심을 고정하고 0° 선을 한 직선에 맞추기", "다른 직선이 90°를 지나는지 보기", "직각을 이루는 두 직선은 수직이에요."],
		["perpendicular", "돌린 각도가 작은 것부터 골라요.", "직각의 절반", "직각 한 개", "직각 두 개", "직각 한 개는 90°예요."],
		["parallel", "삼각자와 곧은 자로 점 ㄱ을 지나는 평행선을 그려요. 순서를 맞춰요.", "삼각자의 한 변을 원래 직선에 맞추기", "옆에 댄 자를 따라 삼각자를 ㄱ까지 밀기", "처음 맞춘 변을 따라 새 직선 긋기", "삼각자를 돌리지 않고 그대로 밀어요."],
		["perpendicular", "두 직선이 이루는 각을 직각에 가까운 것부터 골라요.", "88°", "95°", "75°", "90°까지 몇 도를 더하거나 빼야 할까요?"],
	],
	"distance": [
		["distance", "평행한 두 직선 사이 거리를 재는 순서를 맞춰요.", "한 직선 위에 점 찍기", "그 점에서 다른 직선까지 수선 긋기", "그은 수선에서 두 직선 사이 길이 재기", "두 직선에 수직인 선분을 먼저 만들어요."],
		["distance", "평행한 두 울타리 사이의 폭을 수직으로 쟀어요. 좁은 곳부터 골라요.", "90 cm", "1 m", "110 cm", "같은 단위로 바꾸어 비교해요."],
		["distance", "평행선 사이를 수직으로 잰 기록이에요. 거리가 짧은 것부터 골라요.", "18 mm", "2 cm", "25 mm", "1 cm는 10 mm예요."],
		["distance", "한 칸이 2 cm인 격자예요. 평행한 가로선 사이 거리가 긴 것부터 골라요.", "세로로 6칸", "세로로 4칸", "세로로 3칸", "가로선 사이 거리는 세로 방향으로 재요."],
		["distance", "평행한 두 선의 간격이 4 cm였어요. 간격을 바꾼 뒤 좁은 것부터 골라요.", "2 cm 좁힘", "그대로 둠", "1 cm 넓힘", "움직인 뒤의 간격을 각각 구해요."],
	],
	"parallel_sides": [
		["parallelogram", "평행한 변의 쌍이 적은 사각형부터 골라요.", "평행한 변이 없는 사각형", "평행한 변이 한 쌍뿐인 사다리꼴", "평행사변형", "마주 보는 두 변이 평행하면 한 쌍이에요."],
		["trapezoid", "뒤의 도형은 모두 앞 묶음에 들어가요. 가장 넓은 묶음부터 골라요.", "사각형", "사다리꼴", "평행사변형", "평행한 변이 한 쌍 이상이면 사다리꼴이에요."],
		["trapezoid", "아랫변부터 그려서 사다리꼴을 완성해요. 순서를 맞춰요.", "가로로 아랫변 그리기", "아랫변 위에 나란한 윗변 그리기", "두 변의 왼쪽 끝끼리, 오른쪽 끝끼리 잇기", "윗변과 아랫변이 나란하게 놓여야 해요."],
		["trapezoid", "사다리꼴의 평행한 두 변을 쟀어요. 두 길이의 합이 작은 것부터 골라요.", "2 cm와 4 cm", "3 cm와 5 cm", "4 cm와 6 cm", "카드마다 적힌 두 수를 더해요."],
		["parallelogram", "평행사변형 세 개의 이웃한 두 변을 쟀어요. 네 변의 합이 작은 것부터 골라요.", "2 cm와 3 cm", "2 cm와 5 cm", "3 cm와 6 cm", "마주 보는 두 변의 길이는 같아요."],
	],
	"equal_sides": [
		["rhombus", "마름모 모양 액자의 한 변을 쟀어요. 테두리에 두를 끈이 짧은 것부터 골라요.", "한 변 3 cm", "한 변 5 cm", "한 변 7 cm", "마름모의 네 변은 길이가 같아요."],
		["rhombus", "마름모의 꼭짓점에서 출발해 테두리를 한 방향으로 걸어요. 먼저 일어나는 일부터 골라요.", "첫 번째 변 끝에 닿기", "출발점의 맞은편 꼭짓점에 닿기", "네 변을 지나 출발점으로 돌아오기", "네 꼭짓점을 빙 둘러 걸어 보세요."],
		["rhombus", "막대 네 개로 마름모 틀을 만들어요. 순서를 맞춰요.", "같은 길이의 막대 네 개 고르기", "고른 막대를 차례로 이어 사슬 만들기", "사슬의 양 끝을 만나게 해 틀 닫기", "이웃한 막대는 끝점끼리 만나요."],
		["rhombus", "카드에 마름모의 네 변의 길이를 더한 값이 있어요. 한 변이 짧은 것부터 골라요.", "20 cm", "28 cm", "32 cm", "각 카드의 길이를 4로 나누어요."],
		["rhombus", "다음 묶음 안에 앞 묶음이 쏙 들어가게, 가장 작은 묶음부터 골라요.", "정사각형", "마름모", "평행사변형", "정사각형은 네 변이 같고, 마름모는 마주 보는 두 쌍의 변이 나란해요."],
	],
	"right_angles": [
		["rectangle", "직각인 꼭짓점이 적은 도형부터 골라요.", "직각이 없는 마름모", "직각이 두 개인 사다리꼴", "직사각형", "직사각형의 네 각은 모두 직각이에요."],
		["square", "사각형 카드에 ‘네 직각’, ‘네 변의 길이도 같음’ 조건을 차례로 붙여요. 처음 묶음부터 골라요.", "사각형", "직사각형", "정사각형", "네 각이 모두 직각인 도형을 먼저 모은 뒤 네 변의 길이도 같아야 해요."],
		["rectangle", "왼쪽 아래에서 오른쪽으로 출발해 가로 4칸, 세로 2칸인 직사각형의 처음 세 변을 그려요. 순서를 맞춰요.", "오른쪽으로 4칸 긋기", "위로 2칸 긋기", "왼쪽으로 4칸 긋기", "모서리마다 직각으로 돌아요."],
		["square", "정사각형을 따라 걸으며 모서리마다 오른쪽으로 돌아요. 돌아간 각의 합이 작은 것부터 골라요.", "모서리 한 번 돌기", "모서리 두 번 돌기", "모서리 세 번 돌기", "모서리 하나를 지날 때마다 90°씩 돌아요."],
		["rectangle", "가로가 모두 6 cm인 직사각형이에요. 네 변의 길이의 합이 큰 것부터 골라요.", "세로 5 cm", "세로 4 cm", "세로 2 cm", "가로가 같으면 세로가 길수록 테두리도 길어요."],
	],
}

const MATCH_ITEMS: Dictionary = {
	"lines": [
		["perpendicular", "종이에 그린 서로 다른 두 직선의 모습을 알맞은 말과 짝지어요.", ["직각으로 만남", "끝없이 늘여도 만나지 않음", "60°로 만남"], ["수직", "평행", "만나지만 수직은 아님"], "만나는지, 만난다면 직각을 이루는지 살펴요."],
		["parallel", "도형의 두 변을 각각 그 관계와 짝지어요.", ["직사각형의 위·아래 변", "직사각형의 위·오른쪽 변", "정삼각형의 두 변"], ["평행", "수직", "60°로 만남"], "직사각형의 이웃한 두 변이 만드는 각을 떠올려요."],
		["perpendicular", "직선 두 개가 만나는 곳에서 각 하나를 쟀어요. 각의 종류와 짝지어요.", ["35°", "90°", "125°"], ["예각", "직각", "둔각"], "90°와 비교해 보세요."],
		["perpendicular", "정각일 때 시계의 두 바늘이 만드는 작은 쪽 각을 찾아요.", ["2시", "3시", "6시"], ["60°", "90°", "180°"], "숫자 한 칸을 움직이면 30°가 달라져요."],
		["perpendicular", "동쪽을 향한 화살표를 시계 방향으로 돌려요. 돌아간 뒤의 방향을 찾아요.", ["직각 한 번", "직각 두 번", "직각 세 번"], ["남쪽", "서쪽", "북쪽"], "동쪽에서 시계 방향으로 한 번 직각만큼 돌면 남쪽이에요."],
	],
	"distance": [
		["distance", "두 평행선을 수직으로도 비스듬하게도 이었어요. 두 평행선 사이의 거리를 찾아요.", ["수직 3 cm·비스듬히 5 cm", "수직 4 cm·비스듬히 6 cm", "수직 5 cm·비스듬히 8 cm"], ["3 cm", "4 cm", "5 cm"], "두 평행선 사이의 거리는 수직인 선분의 길이예요."],
		["distance", "한 칸의 길이가 2 cm인 격자예요. 두 가로선 사이의 거리를 찾아요.", ["세로로 2칸", "세로로 4칸", "세로로 5칸"], ["4 cm", "8 cm", "10 cm"], "한 칸의 길이에 칸 수를 곱해요."],
		["distance", "평행선에 수직으로 놓은 자의 두 눈금이에요. 두 선 사이의 거리를 찾아요.", ["2 cm와 7 cm", "3 cm와 6 cm", "4 cm와 8 cm"], ["5 cm", "3 cm", "4 cm"], "끝 눈금에서 시작 눈금을 빼요."],
		["distance", "평행한 선 하나를 다른 선에서 수직으로 2 cm 더 멀리 옮겼어요. 새 간격을 찾아요.", ["처음 간격 3 cm", "처음 간격 5 cm", "처음 간격 7 cm"], ["5 cm", "7 cm", "9 cm"], "처음 간격에 멀어진 길이를 더해요."],
		["distance", "긴 종이띠 두 개의 가로 가장자리를 나란히 맞대었어요. 합친 띠의 폭을 찾아요.", ["폭 2 cm와 3 cm", "폭 3 cm와 4 cm", "폭 4 cm와 5 cm"], ["5 cm", "7 cm", "9 cm"], "겹치지 않게 맞댄 두 띠의 폭을 더해요."],
	],
	"parallel_sides": [
		["parallelogram", "서로 마주 보는 변 중 평행한 쌍의 수를 연결해요.", ["평행한 변이 없는 사각형", "평행한 변이 한 쌍뿐인 사다리꼴", "평행사변형"], ["0쌍", "1쌍", "2쌍"], "평행사변형의 마주 보는 두 쌍의 변은 각각 평행해요."],
		["trapezoid", "각 설명에 맞는 도형 전체를 부르는 이름을 찾아요.", ["변이 네 개인 다각형", "평행한 변이 한 쌍 이상인 사각형", "마주 보는 두 쌍의 변이 각각 평행한 사각형"], ["사각형", "사다리꼴", "평행사변형"], "조건이 더해지면 그 조건에 맞는 도형만 남아요."],
		["parallelogram", "평행사변형의 세 변을 차례로 쟀어요. 마지막 변의 길이를 찾아요.", ["3, 5, 3 cm", "4, 6, 4 cm", "7, 2, 7 cm"], ["5 cm", "6 cm", "2 cm"], "마주 보는 변의 길이는 같아요."],
		["trapezoid", "각 묶음에 사다리꼴인 카드는 몇 장인지 찾아요.", ["정사각형 3장", "직사각형 2장과 삼각형 1장", "마름모 1장과 삼각형 2장"], ["3장", "2장", "1장"], "평행한 변이 한 쌍 이상인 사각형을 모두 세요."],
		["parallelogram", "평행사변형의 이웃한 두 변을 쟀어요. 네 변의 길이의 합을 찾아요.", ["3 cm와 4 cm", "4 cm와 5 cm", "5 cm와 6 cm"], ["14 cm", "18 cm", "22 cm"], "마주 보는 두 변의 길이는 서로 같아요."],
	],
	"equal_sides": [
		["rhombus", "마름모 테두리를 따라 한 바퀴 걸었어요. 걸은 거리를 찾아요.", ["한 변 3 m", "한 변 5 m", "한 변 8 m"], ["12 m", "20 m", "32 m"], "같은 길이를 네 번 더해요."],
		["rhombus", "철사 한 가닥을 모두 써서 마름모 하나를 만들어요. 한 변의 길이를 찾아요.", ["철사 16 cm", "철사 24 cm", "철사 36 cm"], ["4 cm", "6 cm", "9 cm"], "철사 길이를 같은 네 부분으로 나누어요."],
		["rhombus", "한 변이 5 cm인 마름모의 테두리를 걸어요. 지난 변의 수를 거리와 짝지어요.", ["한 변", "이웃한 두 변", "연달아 세 변"], ["5 cm", "10 cm", "15 cm"], "변 하나를 지날 때마다 5 cm씩 가요."],
		["rhombus", "네 변 중 가장 짧은 변과 길이가 같은 변을 모두 세어요. 가장 짧은 변 자신도 세어 주세요.", ["3, 3, 3, 3 cm", "3, 5, 3, 5 cm", "3, 4, 5, 4 cm"], ["4개", "2개", "1개"], "네 수를 보고 가장 작은 수가 몇 번 나오는지 세어요."],
		["rhombus", "보기 중 각 사각형을 가장 자세하게 부르는 이름을 찾아요.", ["네 변이 같고 직각이 없음", "네 변이 같고 네 각이 직각", "네 각이 직각이고 가로와 세로가 다름"], ["마름모", "정사각형", "직사각형"], "변의 길이와 직각을 함께 살펴요."],
	],
	"right_angles": [
		["rectangle", "각 카드에 있는 도형들의 직각 수를 모두 더해 연결해요.", ["직사각형 1개", "정사각형 2개", "정사각형 1개와 직사각형 2개"], ["4개", "8개", "12개"], "직사각형과 정사각형에는 각각 직각이 네 개씩 있어요."],
		["rectangle", "직사각형 테두리를 따라 한 방향으로 걸었어요. 방향을 90° 바꾼 횟수를 찾아요.", ["첫째 변에서 둘째 변까지", "첫째 변에서 셋째 변까지", "첫째 변에서 넷째 변까지"], ["1번", "2번", "3번"], "한 변에서 다음 변으로 갈 때 모서리 하나를 지나가요."],
		["square", "도형을 재어 본 기록과 알맞은 이름을 짝지어요.", ["네 직각·네 변 모두 4 cm", "네 직각·이웃한 변 4 cm와 6 cm", "직각 없음·네 변 모두 4 cm"], ["정사각형", "정사각형이 아닌 직사각형", "직사각형이 아닌 마름모"], "직각과 변의 길이를 함께 살펴요."],
		["square", "같은 정사각형 타일 세 장을 빈틈없이 가로로 한 줄 놓아요. 줄 전체 길이를 찾아요.", ["한 변 2 cm", "한 변 3 cm", "한 변 4 cm"], ["6 cm", "9 cm", "12 cm"], "타일 한 장의 가로 길이를 세 번 더해요."],
		["rectangle", "사각형을 잰 기록을 보고, 각 기록만으로 확인한 성질을 짝지어요.", ["네 모서리에 직각자가 딱 맞음", "자로 잰 네 변이 각각 5 cm", "네 각이 직각이고 네 변도 같음"], ["네 직각을 확인함", "변의 길이가 같음을 확인함", "두 성질을 모두 확인함"], "어떤 도구로 각과 길이를 확인했는지 다시 읽어요."],
	],
}

const CARD_PERMUTATIONS: Array = [[2, 0, 1], [0, 2, 1], [1, 0, 2], [2, 1, 0], [1, 2, 0]]
const CARD_TITLES: Dictionary = {
	"lines": "두 직선의 관계",
	"distance": "평행선 사이의 거리",
	"parallel_sides": "사각형의 평행한 변",
	"equal_sides": "길이가 같은 변",
	"right_angles": "직각이 있는 사각형",
}

static func next_index(index: int) -> int:
	return posmod(index + 1, PER_TYPE)

static func question(type_id: String, index: int) -> Dictionary:
	if not TYPES.has(type_id) or index < 0 or index >= PER_TYPE: return {}
	var result: Dictionary = {"id": "%s_%02d" % [type_id, index + 1], "type_id": type_id, "index": index}
	if index >= ORIGINAL_PER_TYPE:
		return _card_question(result, type_id, index - ORIGINAL_PER_TYPE)
	match type_id:
		"lines": return _line_question(result, "perpendicular" if index % 2 == 0 else "parallel", index)
		"distance":
			if index < 12: return _line_question(result, "distance", index)
			return _distance_question(result, index - 12)
		"parallel_sides": return _shape_question(result, "trapezoid" if index % 2 == 0 else "parallelogram", index)
		"equal_sides":
			if index >= 8 and index < 12: return _rhombus_measurement(result, index - 8)
			return _shape_question(result, "rhombus", index)
		_: return _shape_question(result, "rectangle" if index % 2 == 0 else "square", index)

static func _base(result: Dictionary, lesson_id: String, mode: String, prompt: String) -> void:
	var lesson: Dictionary = Catalog.lesson(lesson_id)
	result.merge({"lesson_id": lesson_id, "mode": mode, "title": str(lesson.title), "prompt": prompt, "hint": str(lesson.hint), "rotation": 0.0, "start_value": 0.0})

static func _line_question(result: Dictionary, lesson_id: String, index: int) -> Dictionary:
	var lesson: Dictionary = Catalog.lesson(lesson_id)
	var prompts: Dictionary = {
		"perpendicular": [str(lesson.task), "직각자로 확인할 수 있게 초록 선을 돌려, 검은 선에 대한 수선을 만들어 보세요."],
		"parallel": [str(lesson.task), "짧은 선을 길게 이어도 검은 선과 만나지 않도록 방향을 맞춰 보세요."],
		"distance": [str(lesson.task), "파란 점을 옮겨 두 선 사이의 거리를 바르게 나타내는 선분을 만들어 보세요."],
	}
	var wording: Array = prompts[lesson_id]
	_base(result, lesson_id, "line", str(wording[int(float(index) / 2.0) % wording.size()]))
	result.rotation = float(posmod(index * 11, 31) - 15)
	if lesson_id == "distance":
		result["gap"] = float(60 + 20 * (index % 5))
		result.start_value = float((30 + 10 * (index % 7)) * (1 if index % 2 == 0 else -1))
	else:
		const ANGLES: Array[float] = [35.0, 120.0, 60.0, 145.0, 15.0, 110.0, 155.0, 55.0, 105.0, 40.0]
		result.start_value = ANGLES[int(float(index) / 2.0)]
	return result

static func _distance_question(result: Dictionary, index: int) -> Dictionary:
	const GAPS: Array[int] = [3, 4, 5, 7, 6, 8, 4, 6]
	const OFFSETS: Array[int] = [80, -60, 90, -80, 60, -70, 90, -80]
	var distance_cm: int = GAPS[index]
	var prompt: String = "두 평행선 사이의 거리는 몇 cm인가요?" if index % 2 == 0 else "나란한 두 길의 사이를 가장 짧게 잰 길이를 골라요."
	_base(result, "distance", "measure", prompt)
	result["gap"] = float(distance_cm * 20)
	result.rotation = float(posmod(index * 7, 21) - 10)
	result.start_value = float(OFFSETS[index])
	var slanted: String = Math.measurement_label(Vector2(result.start_value, result.gap).length() / 20.0) + " cm"
	var values: Array[String] = ["%d cm" % distance_cm, slanted]
	for distractor: int in [distance_cm - 1, distance_cm + 1, distance_cm + 2]:
		var label: String = "%d cm" % distractor
		if values.size() < 4 and not values.has(label): values.append(label)
	return _with_choices(result, values, index)

static func _rhombus_measurement(result: Dictionary, index: int) -> Dictionary:
	const SIDES: Array[int] = [4, 7, 5, 6]
	var figure: PackedVector2Array = Math.create_vertices("rhombus", Vector2(130.0 + index * 7.0, 88.0 - index * 4.0))
	var side_cm: int = SIDES[index]
	var scale: float = float(side_cm * 20) / Math.side_lengths(figure)[0]
	var prompt: String = "재어 보기로 확인한 마름모의 한 변은 몇 cm인가요?" if index % 2 == 0 else "마름모의 네 변의 길이를 모두 더하면 몇 cm인가요?"
	_base(result, "rhombus", "measure", prompt)
	result.title = "마름모의 변의 길이"
	result["vertices"] = Math.scale_vertices(figure, scale)
	result.rotation = float(index * 13 - 15)
	var choices: Array[String] = []
	var numbers: Array[int] = []
	if index % 2 == 0: numbers.assign([side_cm, side_cm - 1, side_cm + 1, side_cm * 2])
	else: numbers.assign([side_cm * 4, side_cm * 2, side_cm * 3, side_cm + 4])
	for length: int in numbers: choices.append("%d cm" % length)
	return _with_choices(result, choices, index)

static func _with_choices(result: Dictionary, ordered: Array[String], index: int) -> Dictionary:
	var choices: Array[String] = []
	var offset: int = posmod(index * (ordered.size() - 1) + 1, ordered.size())
	for slot: int in range(ordered.size()): choices.append(ordered[posmod(slot - offset, ordered.size())])
	result["choices"] = choices
	result["answer_index"] = offset
	return result

static func _shape_question(result: Dictionary, kind: String, index: int) -> Dictionary:
	if index >= 12: return _draw_question(result, kind, index - 12)
	var lesson: Dictionary = Catalog.lesson(kind)
	var prompt: String = str(lesson.task) if index % 3 != 2 else "네 사각형 중 %s인 것을 모두 골라요. 돌려 놓은 도형도 성질을 살펴봐요." % Math.kind_name(kind)
	_base(result, kind, "select", prompt)
	var sets: Array = FIGURE_SETS[kind]
	var set_index: int = int(float(index) / 2.0) + index % 3
	var kinds: Array = sets[set_index % sets.size()]
	var figures: Array[PackedVector2Array] = []
	var correct: Array[int] = []
	var offset: int = posmod(index * 3 + TYPES.find(str(result.type_id)), 4)
	for slot: int in range(4):
		var vertices: PackedVector2Array = _figure(str(kinds[(slot + offset) % 4]), index * 7 + slot * 9)
		figures.append(vertices)
		if Math.matches_kind(vertices, kind): correct.append(slot)
	result["figures"] = figures
	result["correct_choices"] = correct
	return result

static func _figure(kind: String, variant: int) -> PackedVector2Array:
	var width: float = float(100 + variant % 39)
	var height: float = float(59 + variant % 19)
	var vertices: PackedVector2Array
	match kind:
		"general":
			vertices = PackedVector2Array([Vector2(-48, -27), Vector2(48, -44), Vector2(62, 28), Vector2(-35, 46)])
			for index: int in range(vertices.size()):
				vertices[index] *= Vector2(width / 112.0, height / 80.0)
			vertices[1].y -= float(variant % 7)
		"trapezoid": vertices = Math.create_trapezoid_vertices(Vector2(width, height), 0.45 + 0.04 * float(variant % 6), float(variant % 5 - 2) * 0.5)
		"parallelogram": vertices = Math.create_parallelogram_vertices(Vector2(width, height), float(2 + variant % 4) * (0.1 if variant % 2 == 0 else -0.1))
		"square": vertices = Math.create_vertices(kind, Vector2.ONE * float(68 + variant % 24))
		_: vertices = Math.create_vertices(kind, Vector2(width, height))
	return Math.rotate_vertices(vertices, float(posmod(variant * 7, 71) - 35))

static func _draw_question(result: Dictionary, kind: String, index: int) -> Dictionary:
	const VERTEX_COUNTS: Array[int] = [0, 0, 2, 2, 3, 3, 2, 3]
	var count: int = 2 if kind == "rhombus" and index == 1 else VERTEX_COUNTS[index]
	var kind_name: String = Math.kind_name(kind)
	var prompt: String = "격자점 네 곳을 차례로 찍어 %s 모양을 그려요." % kind_name
	if count > 0: prompt = "주어진 선분에 이어 %s 모양을 완성해요." % kind_name
	_base(result, kind, "draw", prompt)
	result.title = "%s 그리기" % kind_name
	result["grid_size"] = GRID_SIZE
	var solution: Array[Vector2i] = _grid_example(kind, index)
	var given: Array[Vector2i] = []
	for vertex: int in range(count): given.append(solution[vertex])
	result["given"] = given
	result["draw_solution"] = solution
	return result

static func _grid_example(kind: String, index: int) -> Array[Vector2i]:
	var width: int = 4 + index % 3
	var height: int = 2 + index % 2
	var points: Array[Vector2i] = [Vector2i.ZERO, Vector2i(width, 0), Vector2i(width, height), Vector2i(0, height)]
	match kind:
		"trapezoid": points[2].x -= 1 + index % 2
		"parallelogram":
			points[2].x += 1 + index % 2
			points[3].x += 1 + index % 2
		"rhombus":
			var half_width: int = 2 + int(index in [1, 3, 6, 7])
			var half_height: int = 1 + (index + 1) % 2
			if half_height == half_width: half_height = 1
			points = [Vector2i(0, half_height), Vector2i(half_width, 0), Vector2i(half_width * 2, half_height), Vector2i(half_width, half_height * 2)]
		"square":
			var side: int = 2 + index % 2
			points = [Vector2i.ZERO, Vector2i(side, 0), Vector2i(side, side), Vector2i(0, side)]
			if index % 4 == 3: points = [Vector2i(0, 2), Vector2i(2, 0), Vector2i(4, 2), Vector2i(2, 4)]
	var solution: Array[Vector2i] = []
	for slot: int in range(4):
		var point: Vector2i = points[(slot + index) % 4] + Vector2i(1 + index % 2, 1 + int(float(index) / 2.0) % 2)
		if index % 2 == 1: point.x = GRID_SIZE.x - point.x
		solution.append(point)
	return solution

static func _card_question(result: Dictionary, type_id: String, index: int) -> Dictionary:
	const MODES: Array[String] = ["choice", "short", "order", "match"]
	var mode: String = MODES[index % MODES.size()]
	var variant: int = floori(float(index) / MODES.size())
	var row: Array
	match mode:
		"choice": row = CHOICE_ITEMS[type_id][variant]
		"short": row = SHORT_ITEMS[type_id][variant]
		"order": row = ORDER_ITEMS[type_id][variant]
		_: row = MATCH_ITEMS[type_id][variant]
	_base(result, str(row[0]), mode, str(row[1]))
	result.hint = str(row.back())
	result.title = str(CARD_TITLES[type_id])
	var layout: int = variant + TYPES.find(type_id)
	match mode:
		"choice":
			var choices: Array[String] = [str(row[2]), str(row[3]), str(row[4])]
			return _with_choices(result, choices, layout)
		"short":
			var answers: Array[String] = []
			answers.assign(row[2])
			result["accepted_answers"] = answers
		"order", "match":
			# The answer key points to positions in the displayed, shuffled cards.
			var permutation: Array = CARD_PERMUTATIONS[layout % CARD_PERMUTATIONS.size()]
			var source: Array = row.slice(2, 5) if mode == "order" else row[3]
			var cards: Array[String] = []
			var key: Array[int] = []
			for card: int in permutation:
				cards.append(str(source[card]))
			for slot: int in range(source.size()):
				key.append(permutation.find(slot))
			if mode == "order":
				result["choices"] = cards
				result["answer_order"] = key
			else:
				var left_items: Array[String] = []
				left_items.assign(row[2])
				result["left_items"] = left_items
				result["right_items"] = cards
				result["answer_pairs"] = key
	return result

static func short_answer_correct(item: Dictionary, response: String) -> bool:
	var normalized: String = _normalize_response(response)
	if normalized.is_empty(): return false
	for answer: String in item.get("accepted_answers", []):
		if normalized == _normalize_response(answer): return true
	return false

static func _normalize_response(response: String) -> String:
	# Spaces around a unit or between Korean words do not change the answer.
	# Preserve spaces between digits so "2 4" cannot silently become "24".
	var words: PackedStringArray = response.strip_edges().to_lower().replace("\t", " ").split(" ", false)
	var normalized: String = ""
	for word: String in words:
		if normalized.right(1).is_valid_int() and word.left(1).is_valid_int():
			return ""
		normalized += word
	return normalized
