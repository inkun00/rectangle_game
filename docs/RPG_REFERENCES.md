# 사각형 월드 RPG 구현 참고 자료

검토일: 2026-10-13. 저장소 소개뿐 아니라 아래에 연결한 실제 GDScript를 읽고, 이 프로젝트의 횡스크롤 탐험·대화·성장·회복 흐름에 맞는 부분을 선택했다. 외부 RPG 프로젝트나 대화 애드온 전체를 설치하지 않았으며 해당 코드·캐릭터·음원을 복사하지 않았다. 사각형 조립 캐릭터와 초등 수학 퀘스트는 이 프로젝트에서 구현한다.

## 공개 저장소 비교

| 자료 | 확인한 코드와 특징 | 이 프로젝트에서의 선택 |
| --- | --- | --- |
| [GDQuest Open RPG](https://github.com/gdquest-demos/godot-open-rpg) | 현재 README는 **Godot 4.6.2** 대상의 개발 중인 턴제 RPG 데모다. [BattlerStats](https://github.com/gdquest-demos/godot-open-rpg/blob/main/src/combat/battlers/battler_stats.gd)는 체력을 범위 안으로 제한하고 변화 신호를 보낸다. [Inventory](https://github.com/gdquest-demos/godot-open-rpg/blob/main/src/common/inventory.gd)는 아이템 수량과 저장을 맡는다. [Player](https://github.com/gdquest-demos/godot-open-rpg/blob/main/src/common/player.gd)는 필드·전투에서 사용하는 플레이어 상태를 연결한다. | 체력·경험치·소모품 상태와 화면을 분리하고 변경 신호로 HUD와 저장을 갱신한다. 이 게임은 직접 이동하며 공격하므로 턴제 전투 화면과 파티 시스템은 채택하지 않았다. [MIT](https://github.com/gdquest-demos/godot-open-rpg/blob/main/LICENSE). |
| [Nathan Hoad Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) | 현재 4 계열은 Godot 4.6 이상용 대화 편집기·실행기다. [dialogue_manager.gd](https://github.com/nathanhoad/godot_dialogue_manager/blob/main/addons/dialogue_manager/dialogue_manager.gd)의 `get_next_dialogue_line`, `get_line`은 대사·선택지·조건 평가·상태 변경을 구분한다. [조건과 상태 변경 문서](https://github.com/nathanhoad/godot_dialogue_manager/blob/main/docs/Conditions_Mutations.md)도 확인했다. | NPC 대화가 수락 전 / 수집 중 / 제출 가능 / 완료 상태에 따라 달라지는 방식을 적용한다. 학습 대사의 원본은 `QuestCatalog`, 상태와 보상은 `QuestJournal`, 표시와 선택 버튼은 `main.gd`가 맡는다. 16개 퀘스트에는 별도 대화 언어와 편집기를 추가하지 않았다. [MIT](https://github.com/nathanhoad/godot_dialogue_manager/blob/main/LICENSE). |
| [matula Example Godot RPG](https://github.com/matula/example-godot-rpg) | Godot 4.4용 작은 시작 예제다. [GameManager.gd](https://github.com/matula/example-godot-rpg/blob/main/scripts/autoload/GameManager.gd)에서 경험치·발견 지역·퀘스트·JSON 저장을, [Enemy.gd](https://github.com/matula/example-godot-rpg/blob/main/scripts/entities/Enemy.gd)에서 순찰·추적·공격·피격·사망 상태를 확인했다. 애니메이션과 드롭 일부는 예시 주석이다. 퀘스트 보상 함수에는 재지급 방지 검사가 없다. | 실제 RPG에 필요한 상태 목록을 비교하는 데 참고했다. 우리 구현은 처치·퀘스트 ID를 저장해 보상이 한 번만 지급되며 저장 형식을 검증한다. README에 교육용 사용 안내는 있지만 별도의 표준 LICENSE 파일은 확인되지 않아 소스 재사용 대상으로 선택하지 않았다. |
| [Godot 공식 2D Platformer](https://github.com/godotengine/godot-demo-projects/tree/master/2d/platformer) | [player.gd](https://github.com/godotengine/godot-demo-projects/blob/master/2d/platformer/player/player.gd)에서 `CharacterBody2D`, 중력, 가속, 점프, `move_and_slide`, 방향 전환, 이동 상태에 따른 애니메이션을 확인했다. | 횡스크롤 이동과 Godot 물리 사용의 기준으로 선택했다. 조립한 사각형을 직접 그리는 플레이어에 맞춰 컨트롤러를 구현하며, 외부 데모의 플레이어 그림·총·음악은 포함하지 않았다. [MIT](https://github.com/godotengine/godot-demo-projects/blob/master/LICENSE.md). 기존 고지문은 `licenses/GODOT-DEMO-MIT.txt`. |

Godot 4를 유지하면 기존 공방의 벡터 사각형, 명령 기반 되돌리기, 키보드 캐릭터 조작과 물리를 같은 엔진에서 연결할 수 있다. Open RPG의 현재 Godot 4 코드를 과거 Godot 3 프로젝트로 오인하지 않도록 버전을 확인했다. RPG의 상태·대화 설계는 위 자료를 참고하고, 조립 캐릭터에 맞는 횡스크롤 행동은 공식 플랫폼 게임 예제를 기준으로 삼았다.

## 공식 게임의 화면 구성 참고

[메이플스토리 공식 초보자 매뉴얼](https://gi.maplestory.nexon.com/Guide/Beginner/Manual)에서 지역명·NPC·퀘스트를 알려주는 미니맵, 오른쪽 퀘스트 알리미, 레벨·HP·경험치를 보여주는 상태창, NPC 대화창의 내용·보상 안내를 확인했다. [공식 Maple Guide 설명](https://support-maplestory.nexon.com/hc/en-us/articles/204744405-How-does-Maple-Guide-work)에서는 목적지 안내와 이동의 역할을 확인했다. 이 자료는 상용 게임의 인터페이스 설명이며 오픈소스나 재배포 가능한 게임 에셋이 아니다.

이번 화면 설계에서는 캐릭터 상태, 현재 목표, 주변 위치, 즉시 실행할 행동을 구분해 읽기 쉽게 배치한다. 발견한 지역으로 이동하는 기능은 탐험 이후의 반복 이동을 줄이는 데 사용한다. 학습 퀘스트를 레벨이나 전투 승리로 잠그지 않는다. 공식 이미지 링크는 확인했지만 이 검토 환경에서 브라우저 화면 캡처는 사용할 수 없어 실제 전체 화면의 픽셀 비교를 검증 근거로 삼지 않았다. 메이플스토리의 로고·캐릭터·맵·UI 이미지·음원을 게임에 포함하지 않는다.

## 구현 연결

| RPG 동작 | 담당 코드 / 규칙 |
| --- | --- |
| 조립 캐릭터로 횡스크롤 모험 | `scenes/world/world_player.gd`, `scenes/world/quadrilateral_world.gd`의 이동·점프·공격·피격·지역 탐험 |
| NPC 부탁, 수집, 복습, 보상 | `scripts/world/quest_catalog.gd`, `quest_journal.gd`. 기존 모험을 보존하면서 6지역·16개 학습 퀘스트·41개 목표 아이템으로 확장했다. G로 물건을 미리 주울 수 있고 수락 후 목표에 반영된다. 정답만 선택해서는 완료할 수 없다. |
| 체력·성장·회복 | `scripts/world/adventure_state.gd`. 체력 100, 물약 3개로 시작. 처치한 고유 적마다 20 XP, 완료 퀘스트마다 카탈로그 코인 보상의 2배 XP를 한 번 지급한다. |
| 레벨 | XP는 누적값으로 저장한다. 레벨 2/3/4의 누적 기준은 100/300/600 XP. 레벨당 최대 체력이 10 증가하고 레벨이 오르면 전부 회복한다. |
| 상점과 여관 | 물약은 10코인에 하나, 사용 시 체력 40 회복. 체력이 가득 차면 소비하지 않는다. 휴식은 5코인으로 전부 회복하며 체력 0에서의 구조는 무료다. 코인은 `QuestJournal` 한 곳에서 관리한다. |
| 발견과 재방문 | `AdventureState.discover()`가 마을·숲·계곡 발견을 기록한다. 체크포인트와 좌표는 월드 저장이 맡는다. |
| 재접속 | 모험 상태의 경험치·체력·물약·처치 ID·발견 지역·수령한 퀘스트 XP를 저장한다. 로드 시 타입, 수치 범위, 레벨과 최대 체력의 일치, 고유 보상 기록을 먼저 검증한다. |

`claim_quest()`는 완료된 퀘스트의 XP 지급 함수다. 호출하는 화면은 반드시 `QuestJournal`의 실제 완료 성공 이후에 호출한다. 목표 수집·정답 검증과 코인 지급은 기존 저널의 책임으로 유지한다. 상점과 여관은 두 모델을 모두 변경한 뒤 신호를 보내 자동 저장이 중간 거래를 기록하지 않도록 한다.

## 에셋과 검증 범위

현재 월드 배경·환경·NPC·몬스터·아이템과 UI 질감은 `assets/generated`의 생성 이미지를 사용한다. 제작 프롬프트와 출처는 [GENERATION.md](../assets/generated/GENERATION.md)에 기록한다. 플레이어의 작품은 공방에서 정한 네 꼭짓점과 색으로 직접 그린다. 위 GitHub 참고 자료의 라이선스는 각 저장소의 범위에 적용되며 이 프로젝트의 모든 신규 코드를 자동으로 그 라이선스로 바꾸지 않는다.

`tests/test_adventure_state.gd`는 XP 경계·다중 레벨업, 체력 제한, 물약 소비, 상점·여관 거래, 무료 구조, 보상 중복 방지, JSON 왕복, 잘못된 저장값의 원자적 거절을 검증한다. 검증 명령은 `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1`이다. 화면 배치·공격 거리·애니메이션은 별도의 실제 실행 검증 대상이다.
