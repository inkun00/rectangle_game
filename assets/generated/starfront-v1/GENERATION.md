# 별빛 개척지 원화

2026-11-01. 도구: OpenAI ImageGen. 상용 게임의 자산을 추출하거나 복사하지 않은 독자 제작 이미지다. Starbound는 사용자가 지정한 분위기 참고 자료다.

공통 프롬프트 방향: original 16-bit pixel-art space-frontier educational sandbox; crisp hard-edged square pixel clusters; navy, steel blue, teal, amber and copper; no text/logos or existing game characters. 원본은 생성 이미지 보관소에 그대로 남겼고 아래 파일로 복사했다. 프레임의 크기 조정·아틀라스 자르기는 Godot에서 수행한다.

| 파일 | 배치와 제작 프롬프트 | 생성 결과 ID |
| --- | --- | --- |
| `environment-scenes.png` | 불투명 3×3. 황혼의 따뜻한 목재 정착지/청록 달; 에메랄드 숲과 폭포; 황금 계곡; 푸른 항구; 오로라 설원; 빛나는 성곽; 중앙 작업 공간이 빈 우주선 작업실; 새벽 개척 공사장; 큰 행성이 보이는 궤도 관측실. 인물·UI·문자 없이 원경과 중경을 층으로 구성. | `a62bdfce-7207-463a-a5d6-1814a906aa04` |
| `skin.png` | 불투명 4×2, 같은 크기 8개, 간격 없는 square-corner nine-slice metal panels. 큰 조용한 중앙 면, 좁은 강철 베벨·리벳. 순서: navy normal; blue hover; copper primary; cyan selected; recessed slot; secondary tab; coral HP fill; mint XP fill. 글자·아이콘 없음. | `a64394ca-ca83-4dc6-b0bc-1ced02765d5a` |
| `crew.png` | 투명 4×4, 같은 크기의 전신 주민 16명. 제빵사·목수·숲지기·길잡이·다리 기술자·측량사·사서·조정자·선장·창고지기·등불지기·설원 탐험가·유리 기술자·수호자·기록관·천문학자. 사각형 중심의 옷과 장비, 서로 다른 모자·색, 셀 안 여백, 지면 그림자·글자 없음. | `b2ca6cae-46c3-40bd-b567-75d6aca9e529` |
| `props.png` | 투명 4×5, 20개. 제빵소/목공소/여관/관측소; 두 나무/바위/표지판; 불투명 흙 타일/발판/다리/포털; 항구 창고/등대/설원 오두막/중계탑; 성문/에너지 장치/착륙선/얼음. 후속 편집: 같은 배치를 보존하며 지붕·탑의 끝을 평평한 사다리꼴로, 수관은 네모 덩어리로, 얼음·바위는 평행사변형과 사다리꼴 중심으로 수정. | 최초 `52927f19-84e3-4cc2-ad7c-445a0096c52d`; 교정 `cb229f1b-85f1-4a5c-82b3-adae48498c4f` |
| `items.png` | 투명 4×6, 24개. 초콜릿/강아지/지붕/판자; 책/평행 레일/직각 도구/네모 배지; 회복약/코인/이동 칩/가방; 초록 슬라임/보라 박쥐/타격 빛/목표 표지; 돛/상자/마름모 등불/평행 발자국; 창/깃발/인장/별빛 핵. 후속 편집: 5행 1열 돛의 천을 짧은 윗변과 긴 아랫변의 사다리꼴로, 6행 2열 깃발을 홈 없는 정확히 네 변의 평행사변형으로 수정. 다른 22개와 배치 유지. | 최초 `c8c27440-968d-4ae1-95aa-6bdf7d8162f4`; 교정 `1d9eedda-b3ea-40f1-93be-1e00af82d8e0` |
| `materials.png` | 불투명 4×6, 정면 재료 패치 24개. 벽돌 무늬/벽 패널/네 칸 창/문; 목재/청록 지붕/장식 목재/황금 모자이크; 돌/콘크리트/회벽/녹색 벽돌; 불투명 유리/호박 유리/청록 유리/그릴; 아연/기와/슬레이트/철판; 삼나무/루버/모자이크/구리. 셀 전체 채우기, 문자 없음. 첫 셀의 여러 벽돌 무늬는 수량 학습에 쓰지 않고 아래 단일 벽돌로 교체 연결했다. | `4ee0eb7c-bcca-4a2b-abb2-6cc3285f9f88` |
| `brick.png` | 불투명 2:1. One SINGLE rectangular warm terracotta BRICK surface texture, flat front orthographic. Entire image is exactly ONE brick filling all edges. Slight mottled red clay, narrow dark outer bevel, tiny amber highlights. No masonry wall, multiple bricks, internal seams, mortar grid, letters or background. One image equals one counted brick. | `ca382a6e-bf03-4644-aa01-b8f13084fd16` |
| `tools.png` | 투명 4×4, 밝은 흰색·호박·청록 16개 도구. 선택/실행취소/재실행/휴지통; 회전/돋보기/화면맞춤/확인 망치; 영수증/집/저장/물음표; 복제/연필/모험 부츠/학습 책. 큰 단순 실루엣, navy outline, 셀별 여백, 설명 문자 없음. | `9f3c9871-f513-4502-b7bd-1ca79d7ebc27` |
| `app-icon.png` | 위 items 24번째 별빛 핵 셀을 Godot으로 자른 256×256 아이콘. 새 그림 합성 없음. | items 원본에서 파생 |

`tools/export_button_web.gd`는 같은 금속 버튼과 관측실 배경의 실제 픽셀을 웹 로딩 화면으로 내보낸다. 아틀라스 구성과 실제 셀 좌표는 `scripts/core/starfront_art.gd`, 기존 ID 호환 매핑은 `GameArt`·`ConstructionArt`에 있다. 텍스트와 수학 도형은 원화에 포함하지 않으며 별도 렌더링한다.
