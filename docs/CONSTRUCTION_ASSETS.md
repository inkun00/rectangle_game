# 집 짓기 모드의 공개 이미지

> **2026-10-28 변경:** 현재 앱의 의뢰인·패널·아이콘·재료·표지는 ImageGen 생성 이미지로 교체했다. 아래 내용은 초기 Kenney 자산의 출처 보관 기록이다. 활성 화면은 아래 PNG를 참조하지 않는다. 새 파일·프롬프트·적용 범위는 [이미지 교체 기록](../assets/generated/revision/GENERATION.md)에 있다. 배포 시 기존 라이선스 고지는 계속 보존한다.

확인·다운로드: **2026-10-27**. 제공자: **Kenney**. 아래 세 팩은 공식 페이지와 ZIP 내부 라이선스에서 **Creative Commons Zero / CC0 1.0**을 확인했다. 개인·교육·상업 용도로 사용할 수 있다. 출처 안내와 각 팩의 원문 고지는 `licenses/KENNEY-CONSTRUCTION-CC0.txt`에 보관한다.

이번 모드는 적합한 공개 이미지가 있으므로 새 이미지 생성 도구를 사용하지 않았다. 모든 프로젝트 PNG는 아래 ZIP의 원본 파일을 이름만 바꾸어 복사했다. PNG를 다시 그리거나 편집하지 않았다. 사람의 얼굴·상의 조합, 크기 조절, UI 색상 조절은 Godot 렌더링 단계에서 수행한다.

## 원본과 버전

| 팩 | 버전 | 원본 페이지 | 원본 ZIP SHA-256 |
| --- | --- | --- | --- |
| Modular Characters | 1.0, 2014 | https://kenney.nl/assets/modular-characters | `FF08976D4B93C10CCA1E2D67A99588FA82E63737676BE543D6F5929606C13B93` |
| UI Pack | 2.0, 제작일 2024-06-12 | https://kenney.nl/assets/ui-pack | `A8A14A234911EB648C062622915C93E79E94E97CB7F9F375A70F6617F1174318` |
| Platformer Art Buildings | 1.0, 2013 | https://kenney.nl/assets/platformer-art-buildings | `77A621073D7DA1770AED02C30E7422DAAFB89C378EF815C83EBCE7FF70CB7729` |

공식 다운로드 주소:

- https://kenney.nl/media/pages/assets/modular-characters/d84577feef-1677670340/kenney_modular-characters.zip
- https://kenney.nl/media/pages/assets/ui-pack/f651646eab-1718203990/kenney_ui-pack.zip
- https://kenney.nl/media/pages/assets/platformer-art-buildings/6aec290935-1677696287/kenney_platformer-art-buildings.zip

ZIP과 전체 해제본은 개발용 `.godot/construction-assets/`에만 둔다. 게임 배포에는 선택한 `assets/construction/` PNG와 라이선스 고지만 포함한다.

## 인물 조합

`scripts/construction_art.gd`의 `ConstructionArt.portrait(index)`가 원본 부품을 표시한다. 128×144 기준 좌표를 출력 크기에 맞춰 비율 유지하므로 64×72와 120×140에서도 잘리지 않는다. 방문객의 `mood`는 `happy`, `straight`, `sad` 중 하나이며 글로도 만족도를 함께 안내해야 한다. 표정만으로 평가를 전달하지 않는다.

| 출력 인덱스 | 피부 Tint | 머리카락 원본 (`PNG/Hair/` 아래) | 상의 원본 (`PNG/Shirts/` 아래) |
| --- | --- | --- | --- |
| 0 | 1 | `Black/blackWoman1.png` | `Blue/blueShirt1.png` |
| 1 | 2 | `Brown 2/brown2Man5.png` | `Red/redShirt1.png` |
| 2 | 4 | `Grey/greyMan2.png` | `Pine/pineShirt1.png` |
| 3 | 5 | `Black/blackMan1.png` | `Yellow/shirtYellow1.png` |
| 4 | 7 | `Brown 1/brown1Woman4.png` | `White/whiteShirt1.png` |
| 5 | 3 | `Black/blackMan4.png` | `Blue/blueShirt3.png` |

각 인덱스의 `head_N.png`, `neck_N.png`는 각각 `PNG/Skin/Tint T/tintT_head.png`, `tintT_neck.png`에서 복사했다. `nose_N.png`는 `PNG/Face/Nose/Tint T/tintTNose1.png`다. 머리·상의는 `hair_N.png`, `shirt_N.png`로 이름만 바꾸었다.

공통 얼굴 PNG:

- `eye.png` ← `PNG/Face/Eyes/eyeBrown_small.png`
- `brow.png` ← `PNG/Face/Eyebrows/blackBrow1.png`
- `mouth_happy.png`, `mouth_straight.png`, `mouth_sad.png` ← `PNG/Face/Mouth/`의 동명 원본

## UI와 재료 질감

| 프로젝트 파일 (`assets/construction/` 아래) | ZIP 내부 원본 |
| --- | --- |
| `ui/button_blue.png` | UI Pack `PNG/Blue/Default/button_rectangle_depth_flat.png` |
| `ui/button_light.png` | UI Pack `PNG/Grey/Default/button_rectangle_flat.png` |
| `ui/panel_blue.png` | UI Pack `PNG/Blue/Default/button_rectangle_flat.png` |
| `ui/panel_light.png` | UI Pack `PNG/Extra/Default/input_rectangle.png` |
| `materials/houseBeigeAlt.png` | Buildings `Tiles/houseBeigeAlt.png` |
| `materials/houseDarkAlt.png` | Buildings `Tiles/houseDarkAlt.png` |
| `materials/houseGrayAlt.png` | Buildings `Tiles/houseGrayAlt.png` |
| `materials/roofRedMid.png` | Buildings `Tiles/roofRedMid.png` |
| `materials/roofGreyMid.png` | Buildings `Tiles/roofGreyMid.png` |

위 UI PNG는 초기 화면에서 사용했던 공개 자산으로 보관한다. 현재 `panel()`과 `button_style()`은 코드로 만든 `StyleBoxFlat`을 사용한다. 선 아이콘과 자재 견본도 원본 SVG를 코드에서 생성한다. 한국어와 가격은 이미지에 넣지 않고 게임의 텍스트로 표시한다.

위 재료 PNG도 초기 질감 자산으로 보관한다. 현재 입면의 벽돌 줄눈·목재 결·창틀·유리 반사는 네 꼭짓점 내부에 코드로 그린다. 재료의 **네 꼭짓점, 분류, 무게, 충돌 영역은 건축 모델과 물리 엔진**이 결정한다. 공개 팩의 둥근 창문·문, 삼각형 지붕 조각은 채택하지 않았다. 창문·문은 벽에 실제로 비워 둔 자리 안에 표시하며 벽 위의 장식 스티커로 사용하지 않는다.

## 디자인 스킬 적용 범위

`frontend-design`, `ui-ux-pro-max`, `emil-design-eng`의 작업대 구성, 읽기 쉬운 대비, 큰 조작 영역, 선택·배치 피드백 원칙을 Godot UI에 맞춰 사용한다. 건축 작업대와 메인은 [CONSTRUCTION_DESIGN.md](CONSTRUCTION_DESIGN.md)의 건축 사무소 디자인을 따른다. 그림·모험 모드는 각각의 디자인과 저장 자료를 유지한다.
