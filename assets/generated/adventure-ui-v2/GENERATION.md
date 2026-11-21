# 사각이의 모험 공통 UI 원화

2026-11-22에 Codex 내장 ImageGen으로 투명 배경의 버튼, 메뉴판, 아이콘 시트를 새로 생성했다. 게임은 원본의 외곽선을 유지하는 9분할 텍스처를 사용한다. 화면 크기와 입력 상태에 따라 버튼을 늘리고 밝기를 바꾸며, 한글과 플레이어가 고른 물감색은 게임에서 직접 표시한다.

| 생성 원본 ID | 배포용 WebP | 가공 |
| --- | --- | --- |
| `exec-f1f424c3-02ce-4066-95bd-f07afbd3c9c3` | `button-petrol`, `button-coral`, `button-jade`, `button-slate` | 같은 순서로 네 행을 분리해 144 × 38로 축소. 탐색, 주요 행동, 선택, 비활성에 사용. |
| `exec-d63d8ec9-d2fd-45b8-9d02-1451e05655f7` | `panel-navy`, `panel-petrol` | 두 행을 분리해 186 × 80으로 축소. 일반 창과 강조 패널에 사용. |
| `exec-e2110c43-9ada-4a6f-b789-78ca80d121ce` | `checked`, `unchecked`, `pan`, `broom` | 2 × 2 시트에서 바깥 여백을 잘라 체크 표시는 26픽셀, 작업 도구는 높이 32픽셀로 축소. |

각 시트를 Lanczos로 축소해 알파 채널을 포함한 무손실 WebP로 저장했다. 메뉴의 작은 아이콘과 테두리는 런타임에서 다시 그리지 않는다.

## 그림 작업실

그림 작업실의 배경은 별도로 생성했다. 생성 ID는 `exec-b056753a-c58e-48b2-8d4d-9f2f8f6b8799`이며, 1440픽셀 너비의 [작업용 매트](../drawing/artist-desk-v2.webp)로 변환했다. 다른 화면에 진입할 때는 이 배경을 내려받지 않는다.

## 그림 작업실 생성 프롬프트

Use case: stylized-concept. A premium quiet background for the drawing studio of a papercraft children's adventure game. Cinematic wide landscape 16:9, top-down absolutely flat view of a dark peacock-blue and ink-navy artist's cutting mat on a paper artist's workbench, rich tangible fiber texture at subtle low contrast. Just the very outside edges of the frame show small crafted objects: a stack of cut mint and ocher rectangular papers at the bottom left corner and the tips of coral pencils and a little brass ruler near the upper right edge. Delicate sparse faint registration lines and cuts near the very outer edges, dark clean negative space across 85 percent of the image where white text and a drawing canvas will go. Flat diffused warm side light, lightly worn professional tools with soft shadows. Confident simple composition, thoughtfully cut materials that match a tactile storybook aesthetic. No text, lettering, numbers, buttons, menus, captions, scene panels, logos, hands, characters, bright objects behind the top-left title, or center objects. Single full bleed background image.

## 버튼 시트 생성 프롬프트

Use case: ui-mockup. A production game UI button spritesheet with real transparent background. Four precisely aligned straight-on horizontal blank rectangular enamel buttons, one per row in a single vertical column. Canvas square, centered at 12.5%, 37.5%, 62.5%, 87.5% height. Every button SAME full width and height (about 86% of canvas width by 17% of canvas height), axis aligned, squared gently clipped corners, clean silhouette and small even transparent gutters. A beautifully crafted, sophisticated family adventure RPG, colored paper and satin enamel, soft ivory upper rim, side edge and narrow dark bottom lip, a single fine inset keyline and elegantly faceted corners. Button 1: saturated dark petrol blue-green enamel, pale jade inset keyline. Button 2: rich burnt coral red enamel, apricot rim. Button 3: dark emerald teal enamel, bright mint edge for selection. Button 4: muted graphite slate blue, quiet steel rim. Centers are very dark, matte, flat, smooth and EMPTY so large pale Korean letters will be legible when added by the engine. Understated fine paper tooth, precision cut corners, subtly tangible pressable objects. Edges clean and simple for nine-slicing; center must tile without ornament. Four separate isolated authored items only. No text, no lettering, no words, no numbers, no icons, no screws, jewels, stars, arrows, no symbols, no background/shadow outside each shape, no watermark, no gradients across the length.

## 메뉴판 생성 프롬프트

Use case: ui-mockup. Premium storybook exploration game menu asset sheet, containing EXACTLY TWO separate fully opaque blank landscape menu panel plates on a genuinely transparent background, one above the other, same size (about 90% canvas width x 40% height each). Square canvas. Perfectly front-on and axis-aligned for nine-slice game UI. Beautiful restrained art direction for a book of adventures set in a world made of quadrilaterals. First/top panel: an almost-black, ink navy dyed bookcloth board, straight sides, tiny clipped corners, one fine, understated warm brass and deep teal inset rule and discreet folded corner details. Second/bottom panel: deep petrol blue slate/teal cartographer's case, small jade edge highlight, same geometry, finely cut paper layers. Realistic hand-finished surfaces in a polished stylized papercraft video game. Both feature very quiet dark flat matte cores suitable for placing ivory text anywhere, no directional shine, no pattern in center. Delicate texture visible at the edges, elegant and tactile, commercial family adventure RPG. Form is one neat continuous very thin border all around. Leave a clear gap and outside margin, scale texture practically for nine slice. No visible pages, no paper sticking out, no leather straps, no ornament near center, NO text, no markings, symbols, maps, illustrations, icons, logo, screws, rivets, machinery, drop shadows, outer scenery or background.

## 체크 표시와 도구 생성 프롬프트

Use case: ui-mockup. Transparent production sprite sheet for a tactile papercraft adventure game. Exactly four isolated simple UI pictograms, aligned in a perfect 2 by 2 grid of equal cells, one centered in each cell with clear empty padding. Top left: small dark emerald square checkbox with a thick absolutely clear ivory check mark, warm thin champagne bevel. Top right: same square empty dark navy checkbox, pale silver edge, no mark. Bottom left: a mint and ivory four-way pan cursor with four strong arrowheads pointing north south east west joined at the center. Bottom right: a simple recognizable angled coral-handled cleaning broom with golden straw, for clearing a drawing board. Each item fills about 70 percent of its cell. Front-on orthographic flat, beautifully cut colored paper with softly dimensional edges, chunky silhouettes, highly legible at only 24px. Match dark navy game menus with mint, cream and coral accents. Fully transparent outer background; no words, labels, numbers, portrait, borders around the grid, or shadow outside the objects.
