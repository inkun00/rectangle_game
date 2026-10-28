# ImageGen 에셋 생성 기록

2026-10-29 초등학생용 건축게임 UI를 위해 새로 생성한 패널·버튼·아이콘·재료·의뢰인·5단계 배지 14종은 [건축게임 제작 기록](construction-game/GENERATION.md)과 해당 폴더의 `prompts.json`에 정리했습니다. [공식 게임 참고 조사](../../docs/CONSTRUCTION_GAME_REFERENCES.md)를 바탕으로 제작했습니다.

생성 방식: 내장 `image_gen` 도구. 외부 CLI/API 키는 사용하지 않았습니다.

2026-10-28 건축·메인·그림/공방 종이·앱 아이콘에 추가한 8개 생성 PNG와 프롬프트는 [이미지 교체 기록](revision/GENERATION.md)에 있습니다. 코드로 그리던 삽화·질감·아이콘과 Kenney 의뢰인 이미지를 대체하며, 자재 40종을 위한 추가 재질 시트를 포함합니다.

추가한 항구·설원·성곽 이미지 4장과 프롬프트는 [확장 지역 제작 기록](EXPANSION-GENERATION.md)에 있습니다.

선택한 원본 PNG를 `assets/generated/`로 복사했습니다. 게임은 원본 픽셀을 AtlasTexture로 잘라 표시합니다. UI는 생성 패널의 안쪽 영역을 사용하며, 배경·건물·NPC·수집물·몬스터를 코드로 합성하지 않습니다. 플레이어가 만든 캐릭터와 편집 가이드는 별도입니다.

## 최종 파일

|파일|구성|
|---|---|
|world_backdrop.png|초록 마을·바람 숲·평행 계곡 파노라마|
|environment_atlas.png|집4종, 나무2종, 수정, 표지판, 지형, 발판, 다리, 관문|
|npc_atlas.png|주민8명|
|items_atlas.png|퀘스트물품8종, 회복약, 코인, 몬스터3종, 상자, 타격효과, 부탁표식|
|ui_atlas.png|양피지·남색·청록·연두 패널|

## 배경 최종 교정 프롬프트

Edit this game panorama; preserve composition, gorgeous paper texture, palette, exact dimensions and landscape. Replace every triangular/pointed castle roof on the left with a flat-topped TRAPEZOID roof. Replace rightmost 3D faceted crystals with FLAT RHOMBUS silhouettes composed of inset smaller rhombi (no internal triangular facets). All tree leaves are simple flat rhombi or parallelograms. Keep mountains flat-topped trapezoids, square sun, rectangular clouds. Eliminate triangular patches on cloud corners. Each visible piece must be a four-sided rectangle/square/trapezoid/parallelogram/rhombus. No curves or triangles anywhere; preserve attractive detailed game art and region layout. Not a diagram.

## 배경 문·다리 최종 교정 프롬프트

Use case: precise-object-edit. Edit target: this exact game panorama. Change ONLY the bridge openings and the building door openings on the left. Replace every rounded or clipped-corner arched opening with a clean straight RECTANGLE opening, including the two bridge openings around one-fifth of the image width and all tiny castle doorways. Keep the complete panorama, size, lighting, paper texture, square sun, rectangular clouds, trapezoid mountains and roofs, rhombus trees and crystals unchanged. Do not add objects. All openings must have exactly four straight sides and four right angles, no curve and no clipped corners. Preserve the original art everywhere else.

## environment 생성 프롬프트

Use case: stylized-concept. Production game asset ATLAS, exactly 4 COLUMNS by 3 ROWS of equally sized square cells, 1536x1152 landscape, on a GENUINELY TRANSPARENT background. Each single separate object centered within its cell with generous transparent padding (12% per side), no touching neighboring cells, no labels, no lines dividing cells. Premium handcrafted paper-cut 2D side-scrolling fantasy RPG art, warm golden light, deep jade/navy, cream, terracotta, lilac. EVERY object and decorative detail constructed exclusively of straight-edged QUADRILATERALS: rectangles, squares, trapezoids, parallelograms, rhombi. Never use circles, triangles, round edges, curved outlines or polygons with other than four sides. Orthographic SIDE view, not isometric. EXACT row-major order: ROW1 (1) inviting cream bakery building, broad terracotta TRAPEZOID roof, rectangular door and square windows, (2) timber craftsman's workshop with PARALLELOGRAM slanted wooden roof and rectangular beams, (3) forest inn of jade rectangular blocks with trapezoid roof, (4) lavender crystal library building with rectangle shelves and rhombus roof tiles. ROW2 (1) tall fantastical tree with RECTANGLE trunk and several clearly RHOMBUS leaves, (2) tall tree made of stacked PARALLELOGRAM canopy blocks and rectangle trunk, (3) three glowing RHOMBUS crystals on square rock plinth, (4) simple wood road sign made of rectangular board and rectangular post, NO TEXT. ROW3 (1) wide rectangular side-scroller GROUND TILE: thick dark navy earth, top strip lush rectangular jade grass, visible square brick strata, fully fills central 80% cell width, (2) wide thin RECTANGULAR floating timber PLATFORM with golden top edge and rectangular underside, (3) small bridge segment of clearly slanted PARALLELOGRAM wooden boards, (4) magical rectangular PORTAL: tall rectangle doorway with concentric straight rectangular gold and teal frame, glowing rectangular interior. Clean isolated sprite silhouettes with authentic alpha. Detailed painterly paper texture ONLY inside quadrilateral pieces. No characters, background scene, watermarks or text.

## npcs 생성 프롬프트

Use case: stylized-concept. Production transparent game NPC sprite ATLAS, exactly 4 columns x 2 rows, 1536x768 landscape. Eight separate front-three-quarter NPCs in exact equal square cells with 12% transparent padding on all sides. Same size baseline and height (80% of cell). Premium beautiful paper-cut 2D fantasy RPG style, gold edge lighting, cream skin, deep navy outlines, jade/terracotta/indigo palette. ALL characters made ONLY of quadrilaterals: square heads, tiny square eyes and noses, rectangle hands/feet, trapezoid or parallelogram torsos, rhombus accents. No curved body edges, circles, triangles, or rounded hats. No labels, text, grid borders or background. ROW1 left to right: friendly baker with rectangular chef hat and trapezoid coral apron holding RHOMBUS chocolate; blue-clad roof artisan with trapezoid hat and rectangle hammer; green forest ranger with square backpack and parallelogram cloak holding square lantern; golden guide with rhombus brooch holding L tool built of TWO rectangles. ROW2 left to right: purple carpenter with rectangle hammer and parallelogram plank; teal surveyor with pair of parallel rectangular rods; lilac librarian with rectangle book and square spectacles; wise indigo village mayor with trapezoid gold crown and rhombus staff topper. Distinct personalities and readable silhouettes, expressive SQUARE eyes. All shapes four-sided. Actual transparent alpha background. Make each NPC an independent sprite, not a scene, no shadows beyond own cell.

## items 생성 프롬프트

Use case: stylized-concept. Production TRANSPARENT item and monster game sprite ATLAS: EXACTLY 4 columns x 4 rows equal square cells, 1024x1024. 16 independent centered sprites, each 65-75% cell, generous transparent padding, no crossing cells. Premium crisp paper-cut 2D fantasy RPG art, warm gold lighting, deep navy outlines, jewel teal, coral, lavender, chocolate, cream. Objects exclusively made of the FIVE QUADRILATERALS: rectangles,squares,trapezoids,parallelograms,rhombi. No circles,triangles,curves,rounded corners,ordinary-star shapes. No labels,numbers,text,gridlines,background. EXACT order row-major: ROW1: (1) a clearly RHOMBUS shaped chocolate bar subdivided into smaller rhombi, (2) adorable SQUARE-shaped puppy: large square head, square body, square ears, tiny square eyes,rectangular tail, (3) single terracotta TRAPEZOID roof tile, (4) clearly slanted golden PARALLELOGRAM wood plank. ROW2: (1) blue RECTANGLE closed book, (2) two parallel jade RECTANGULAR rails, (3) golden right-angle carpenter tool made of TWO perpendicular rectangles, (4) golden SQUARE badge with smaller square inset. ROW3: (1) coral health potion in RECTANGULAR bottle with square cap, NO rounded bottle, (2) golden RHOMBUS coin with inset small rhombus, (3) mischievous small teal SQUARE block monster with square eyes, rectangle feet, (4) amber PARALLELOGRAM block monster with square eyes and rectangular feet. ROW4: (1) violet RHOMBUS crystal monster with square eyes and tiny rectangle feet, (2) RECTANGULAR treasure chest with rectangular lid and square gold clasp, (3) hit spark composed of four small separated glowing golden SQUARES arranged in cross, not a star or circle, (4) SQUARE gold plaque containing an exclamation mark made of one thin rectangle above one square. Actual transparent alpha, clean cutouts, consistent high-quality sprites.

## ui 생성 프롬프트

Use case: ui-mockup. Production game UI skin atlas, transparent background, EXACT 2x2 equal square cells in a 1024x1024 square image. Four beautiful RECTANGULAR nine-slice panel textures, each occupies exactly 90% of its square cell with equal transparent padding. Crisp straight rectangular outlines, entirely square corners, absolutely no rounded corners, circles, triangles, curves, letters, logos or icons. Premium illustrated paper-cut fantasy RPG UI. ROW1 left: warm ivory parchment panel with double thin deep-teal RECTANGULAR border and small gold SQUARES in each corner; right: very dark navy panel with double thin antique-gold RECTANGULAR frame and little gold SQUARE corner inlays. ROW2 left: muted deep forest-teal panel with subtle rectangular woodgrain bands and thin jade rectangular border; right: bright jade-green selected button/panel with lighter mint inset rectangular face and square gold corner accents. Uniform straight 16px border details at corners, large clean subtly textured center to hold readable UI text. Flat orthographic front view. Four discrete panels separate with transparency gutters, nothing else.

## 환경 에셋 교정

Correct ONLY non-quadrilateral motifs of this 4-column 3-row transparent game atlas, keep all cells/objects/palette/style/placement intact. First bakery: replace all oval bread and oval sign icon with RHOMBUS chocolates; awning stripe ends straight rectangular, no curves. Fourth building top row library: roof becomes a broad flat-topped TRAPEZOID, NOT pointed/triangular; glowing window a simple RECTANGLE, not pentagon. Make crystal interiors nested flat RHOMBI instead of triangular facets. All visible pieces must be FOUR-sided trapezoids/parallelograms/rectangles/squares/rhombi. Remove curved details and triangular pieces, preserve all other beautiful paper-cut details and alpha transparency. EXACT same4x3atlas layout; no crop, no moved objects, no additions.

## NPC 교정

Correct this transparent4columns2rows8NPC game atlas while preserving the exact character identities/poses/cell arrangement/texture/palette. ONLY change every curved mouth to a tiny straight RECTANGLE; all triangular hair bangs to slanted PARALLELOGRAM strips; every triangular collar to small TRAPEZOID. Mayor crown must have FLAT-TOP trapezoid tips, not triangle tips. Remove circular rolls on surveyor backpack, replace with square-ended rectangular bars. Make hat bands/eyes/hands all simple quadrilateral polygons. All decorative pieces throughout must be rectangles/squares/trapezoids/parallelograms/rhombi, NO triangular or curved edges. Keep high-quality game character appearance, existing transparent alpha, no resizing/cropping/rearranging.

## 배치 기록

환경 아틀라스는 생성 결과를 검토해 행 경계를 0/397/749/1086으로 지정했습니다. 원본을 다시 그리거나 픽셀을 합성하지 않았습니다. 게임의 바닥과 발판은 해당 그림의 영역과 실제 충돌 위치를 맞췄습니다. 모든 생성 이미지의 사각형 요소를 검토했고, 뾰족한 지붕·둥근 빵·둥근 입은 추가 생성 편집으로 교정했습니다.
# Drawing studio scenes and masterpiece guides

The 30 new drawing backgrounds and 10 original geometric masterpiece studies are documented in [drawing/GENERATION.md](drawing/GENERATION.md), including image prompts and historical metadata sources.
