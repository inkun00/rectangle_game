# 집 짓기 재료 원화

## 2026-11-24 종이 모형 스타일

Codex 내장 ImageGen으로 집 짓기 재료를 정면 과슈 일러스트로 다시 그렸다. 스타일 기준은 홈 메뉴의 [종이 모형 집](../home-atlas/building.webp)이다. 재료 면을 채우는 큰 무늬와 색을 사용하고, 도형의 외곽선은 게임의 네 꼭짓점에 맞춘다. 견본, 배치, 시공 검사, 완공 기록과 PNG 내보내기가 모두 같은 시트 칸을 사용한다.

| 저장 파일 | 구성과 실사용 규격 | 생성 ID |
| --- | --- | --- |
| [core-a.webp](core-a.webp) | 3×4, 칸당 352×352. 기본 목재, 창문, 지붕, 벽돌 등 | `exec-e3c0593d-e9f3-4d5c-bc1d-fd5c3222e742` |
| [core-b.webp](core-b.webp) | 3×4, 칸당 352×352. 유리, 지붕판, 금속 등 | `exec-4762918d-cd02-42fd-a378-bfeaeb99b282` |
| [surfaces.webp](surfaces.webp) | 4×4, 칸당 288×288. 대나무·갈대·자개 등 16종 | `exec-5ae976af-4b80-410e-ac5e-30edb72d6bb3` |
| [openings.webp](openings.webp) | 3×2, 칸당 320×320. 문 2종과 창문 4종 | `exec-95662a2b-1fe1-4471-8a10-86974ad726df` |
| [workshop.webp](workshop.webp) | 5×5, 칸당 288×288. 위쪽 세 행과 아래쪽 두 행을 이어 배치 | `exec-40d5cffb-7b73-4010-a957-429b10af27f7`, `exec-d96a2562-0778-4edf-9f30-d93c6147693d` |

원화에서 칸 경계의 2~3픽셀을 덜어 낸 뒤 규격에 맞춰 리샘플링하고 WebP로 저장했다. 철제 격자 가로창은 창틀 안쪽으로 정리해 바깥 벽면이 붙지 않게 했다. 기본 문과 초록 벽돌 한 장은 2×1 원화 `exec-6d56126b-1002-468a-8f1e-171fb421f1ae`로 다시 생성해 core-a의 두 번째 행 첫 칸과 네 번째 행 마지막 칸에 넣었다. 8장 묶음은 새 초록 벽돌 한 장의 그림을 8번 반복한다.

### 공통 프롬프트

> Use case: stylized-concept. Asset type: a production sprite atlas for the front-facing editable construction parts of the Korean elementary game Quadrilateral World. The supplied reference image is only the existing game's style guide: friendly tabletop papercraft miniature, cream board, warm clay, petrol blue roof, child-friendly storybook. Generate only the flat front faces specified below. Clean hand-painted gouache/cut-paper cartoon with big readable design marks, thin deep-brown or dark teal drawn linework, 2–3 controlled tones per surface and negligible gentle paper grain. A restrained palette of warm cream, russet, honey and muted teal with distinct colors per material. Absolutely no photography, tiny organic noise, specular chrome, digital procedural noise, gradients, environments, 3D render, borders around the contact sheet, bevel around ordinary textures, free-floating objects, mockups, watermarks, labels, lettering, digits or gutters. Every face is strictly orthographic straight-on, no depth or tilt, fills its exact matrix cell completely edge-to-edge. Main patterns remain readable at thumbnail size. Each item sits in its assigned grid cell only, rectangular full-bleed fills run even into cell corners. The game independently bends each square face to its true four-vertex shape. Only actual door/window designs have a flat inset frame, and keep 5% of base color near the tile edges so all hardware remains inside. Keep the grid exact and divide canvas into equal cells in both axes.

### 시트별 프롬프트

**core-a**

> Strict THREE columns by FOUR rows, portrait 3:4 atlas with twelve square tiles. Each row listed LEFT to RIGHT, exact order. R1: a SINGLE solid terracotta brick with marginless clay face and slim bevel, no mortar or segmentation | warm ivory wall facing made of five broad brick courses | bright blue four-pane wood square window with honey frame. R2: closed warm reddish wooden panel entry door with little brass knob | gold tan long wood beam face with broad horizontal grain | small layered cobalt and muted petrol-blue scalloped shingles, broad three straight horizontal rows with straight edges. R3: muted green-painted wooden trim with fine parallel timber strokes | miniature amber-gold square ceramic mosaic | large gray irregular stone masonry with brown dry joints. R4: pale blue-gray concrete panel with a few sparse pebble flecks | warm ivory troweled plaster with two broad ochre strokes | green glazed rectangular brick in offset rows.

**core-b**

> Strict THREE columns by FOUR rows, portrait 3:4 atlas with twelve square tiles. Every cell is the full continuous front-facing material swatch with no interruptions and no blank margin. Each row listed LEFT to RIGHT, exact order. R1: softly matte icy blue frosted window glass with broad white marks | translucent warm amber glass with two pale simple reflection marks | saturated dark teal glass in four panes with an ivory painted frame. R2: dark blue-gray crosshatched simple wrought iron grille | blue-gray zinc sheet with broad evenly spaced painted corrugation stripes | red clay roof tiles with three straight rows of overlapping U-shaped lap seams. R3: indigo gray slate shingle surface with three straight bands of flat stone tiles | pale blue-green standing-seam sheet metal with five broad straight vertical ribs | honey-brown cedar boards with slow sweeping horizontal drawn grain. R4: dark teal wood louver with five broad horizontal slats | colorful pale teal and apricot quadrilateral mosaic | mellow reddish copper panels with two neat seams and a few small gold rivets.

**surfaces**

> Strict FOUR columns by FOUR rows, square 4x4 atlas with sixteen equal cells. Each row listed LEFT to RIGHT in exact order. R1: muted gold green bamboo stalks side-by-side with simple horizontal joints | warm honey cork board with gently scattered illustrated flecks | ochre sandstone block masonry with a few subtle irregular bands | charcoal basalt masonry with wide cool blue gray blocks. R2: cream birch boards with simple horizontal grain | celadon jade green ceramic square tile grid | burnt orange terracotta U-shaped overlapping tile roof pattern, straight parallel courses | warm yellow-gold REED THATCH ROOF, bundled in three straight horizontal layers, use broad flat hand-drawn ribbons and scarce short lines. R3: teal verdigris copper panels with warm rivets | dark indigo solar cell modules with neatly spaced desaturated blue grid | turquoise sea glass with two broad pale cel-shaded ripple marks | multicolor stained glass geometry with dark plum lead, aqua, cobalt and honey. R4: ivory hanji paper and simple straight warm brown lattice | rich dark walnut wood planks with simple curved flat grain | light mother-of-pearl shell tesserae in pastel pink and aqua | golden woven rattan with broad alternating bands. Each swatch reaches all four edges; no frames.

**openings**

> Strict THREE columns by TWO rows landscape 3:2 atlas. Six square full-bleed orthographic FRONT ELEVATION sprites. Exact order LEFT to RIGHT. R1: handsome closed umber WALNUT DOOR with two outlined rectangular panels and little brass right-side knob | golden-green BAMBOO sliding door with simple timber horizontal tracks, dark recessed pull | softly bright ivory Korean HANJI paper behind simple warm wooden lattice grid. R2: geometric four-petal ruby and apricot FLOWER stained-glass window on blue glass | turquoise SEA GLASS window, central straight wood mullion and two painted wave reflections in cream timber frame | symmetrical golden eight-point STAR inside cobalt and emerald stained glass with dark lead and slim copper frame. All frames only 8-10% of each cell, no arcs or sill projecting outside. Each cell fills completely.

**workshop-a**

> Strict FIVE columns by THREE rows, landscape 5:3 atlas with fifteen equal square tiles. Exact order LEFT to RIGHT. R1: terrazzo pale mineral slab with large colored geometric chips | icy turquoise glass block with softly shaded inner square and painted highlight | ivory ceramic with a bold navy compass rose at center | honey oak parquet herringbone | dark indigo cross-braced Asian wooden star-lattice window with dusty light blue panes. R2: closed barn-red plank door with clearly drawn pale wooden diagonal X brace | horizontal blue window with iron grid, ivory front reflections and black frame | laminated long golden wood beam with flat horizontal alternating bands | rammed-earth wall with broad peachy and ochre bands | striped cloth canopy in alternating muted red and honey, wide evenly spaced straight vertical stripes with slim folded painted edge at the bottom, absolutely no fabric photo, no sag, no scalloped or external outline. R3: slate overlapping rounded stone shingles, three neat horizontal courses | green moss roof pattern of simply drawn round tufts spread across stylized flat sage and olive ground, a few tiny ochre pebble accents, no photo or flowers or garden scene | satin blue-gray zinc canopy corrugation drawn as six straight vertical alternating flat light/darker ribs | grained light charcoal granite with a few sparse distinct speckles | stained leaded turquoise glass canopy with fine dark teal straight parallel grid and broad graphic ivory highlights. All tiles must fill every corner as pure flat texture, even the roofs, never show any cutout or trapezoid.

**workshop-b**

> Strict FIVE columns by TWO rows, a wide 5:2 atlas with ten equal square tiles. Exact order LEFT to RIGHT. R1: amber ribbed glass with broad vertical stripes and creamy painted reflections | dark walnut chevron woodgrain parquet | brushed gold brass joiner face with four small dark corner rivets and simple diagonal accents | driftwood gray wall of horizontal planks washed with earthy cool colors | ultramarine enamel band of repeating large aqua-and-ivory ceramic zigzags. R2: dark navy ceramic tile with an elegant single flat warm cream mother-of-pearl crescent | honey colored geometric honeycomb glass behind a slim ochre frame | warm clay terracotta tile with a single bold radiating floral rosette motif | icy pale blue tile with a stylized eight-point crystalline star | slim charcoal iron scrollwork window with two clearly rolled curl shapes on soft turquoise panes. Every image fills its entire square, no borders on non-window tiles and no gutter.

### 기본 문과 초록 벽돌 보정 프롬프트

> Use case: precise-object-edit. Generate a matching TWO COLUMN by ONE ROW 2:1 atlas to supply two replacement square cells for a Korean elementary quadrilateral house-building game. Reference image is the project's original material atlas, use its subdued hand-painted gouache opacity, subtle matte paper tooth, thin cocoa outlines and simple large graphic details. Face-on orthographic and entirely flat. Neither sample has a border or margin around the cell. Left half, correct the atlas door: ONE CLOSED RECTANGULAR warm rusty-red wooden board door, with a flat perfectly horizontal top edge and four ninety-degree corners. Entire tile is door front, including all four corners: no arch, no cream plaster, no background, no exterior wall. Paint a simple recessed rectangular panel on top and a smaller rectangular panel below; tiny ochre metal knob on the right. A thin cognac-colored wooden jamb is inset within all four edges, also rectangular. Right half: ONE SINGLE emerald/forest-green glazed CLAY BRICK, a solid jade face with a thin dark forest clay bevel all around, just two restrained brush-like painted highlights like the reference's single rust red brick. No rows, no mortar, no repeated masonry, no text, no symbols, no furniture mockup or perspective. Two continuous full-bleed squares meeting at the precise vertical centerline. Hard rectangular corners are essential because the game overlays the true quadrilateral geometry.

# 이전 버전의 생성 기록

아래에 기록한 이전 시트는 Git 커밋 `b910922`에서 확인할 수 있다.

## 공방 재료 25종 · 2026-11-23

ImageGen으로 원화를 생성했다. 프롬프트는 “정면에서 본 건축 표면을 5행 5열의 같은 크기 칸에 그린다. 재료마다 특징이 작은 화면에서도 분명하게 보이게 하고 글자, 라벨, 칸 사이 여백, 바깥 여백은 넣지 않는다”였다. 다음 순서로 재질과 세부 디자인을 지정했다.

| 행 | 왼쪽부터 다섯 칸 |
| --- | --- |
| 1 | 돌조각 테라조, 유리 블록, 파란 나침반 도자기, 참나무 쪽매, 남빛 별살창 |
| 2 | 빗장이 엇갈린 빨간 문, 가로 격자창, 얇은 목재를 겹친 보, 흙다짐 줄무늬, 줄무늬 천 차양 |
| 3 | 비늘 모양 돌지붕, 다육식물과 이끼 정원, 주름진 아연판, 거친 화강암, 물빛 쪽유리 |
| 4 | 호박빛 골유리, 화살무늬 호두나무, 징이 박힌 황동 이음판, 회색 물결나무, 파란 칠보 띠 |
| 5 | 자개 초승달, 벌집 유리, 황토 꽃문양, 얼음별 유리, 소용돌이 철제창 |

1254×1254 원화를 1250×1250 WebP로 저장했다. 각 칸은 250×250픽셀이며, 카드·도면·PNG 내보내기에서 같은 칸을 개별 부품의 네 꼭짓점에 맞춰 사용한다.

2026-11-22 내장 ImageGen으로 4×4 질감 이미지 한 장을 생성했다. 생성 ID는 `exec-ccdc837a-ed2c-4057-a002-0691a764c3cf`이다. 1254×1254 원본의 각 칸 가장자리를 3픽셀씩 잘라 이웃 재질이 비치지 않도록 한 뒤 칸마다 256×256으로 축소했다. 당시 게임은 `surfaces.webp`에서 자재에 맞는 칸을 골라 재료 카드, 도면, 완성 이미지의 네 꼭짓점에 맞췄다.

| 행 | 왼쪽부터 오른쪽으로 |
| --- | --- |
| 1 | 대나무, 코르크, 사암, 현무암 |
| 2 | 자작나무, 청자 타일, 적갈색 기와, 갈대 이엉 |
| 3 | 녹청색 구리, 태양 전지, 바다 유리, 색유리 |
| 4 | 한지 창살, 호두나무, 자개 모자이크, 등나무 짜임 |

## 생성 프롬프트

> Generate ONE professional game MATERIAL TEXTURE ATLAS. Square image fully occupied by a rigorous 4 by 4 REGULAR GRID of 16 separate equal square diffuse textures, exact quadrant cell bounds at 25%,50%,75%. No gutters, NO text, NO digits, no labels, no frames, no background, no rounded tiles, never show a contact sheet border. Each cell fills its entire square edge to edge. This atlas is sampled and mapped onto front-facing architectural polygons in a Korean children's illustrated house-building game. Orthographic flat front elevation, warmly hand-painted gouache plus clean cut-paper details, saturated but naturally rich colors, friendly tactile Nintendo-like craft style, controlled highlights with excellent legibility when reduced to 48px, beautifully differentiated surfaces. These are not perspective samples or three dimensional blocks. It is essential to follow EXACT order by row left-to-right:
>
> Row 1: golden green bamboo stalks bound side-by-side vertically with occasional distinct joints; warm honey cork board with characteristic coarse mottled pores; pale ochre red sandstone block masonry in offset rows with subtle flowing sediment bands; charcoal basalt stone layered masonry with cool edges.
>
> Row 2: light cream birch wood boards with flowing horizontal grain and little dark knots; celadon jade green glossy ceramic tiles with glaze and golden seams; deep burnt orange terracotta overlapping curved tile collection; woven straw reed thatched roof in golden brown, downward woven bundles.
>
> Row 3: verdigris teal patinated copper panels with a few warm copper warm rivets; midnight blue photovoltaic rectangles with silver lines and highlights; translucent turquoise sea-glass window textured with light reflected water ripples; vivid cathedral-like multicolor stained glass window abstract geometric panes with dark lead seams, cobalt, ruby, gold and emerald.
>
> Row 4: cream Korean hanji paper behind natural wooden lattice, clearly geometric delicate lattice over cream paper; luxurious deep dark walnut wood planks with rich smooth grain; pale pearl iridescent seashell mosaic tile with small softly colored pink and blue facets; golden woven rattan basketweave broad strips crossing one another.
>
> All equal at 4x4, each cell features generous recognizable pattern scale with no decorative objects on top. No typography whatsoever. Keep all sixteen cells completely independent.

## 문과 창문

같은 날 내장 ImageGen으로 문 2종과 창문 4종의 앞모습을 따로 제작했다. 생성 ID는 `exec-e96e7087-7513-40ce-b656-48f5a4889186`이다. 손잡이와 창틀을 포함한 1536×1024 원화에서 칸마다 2픽셀의 가장자리를 덜어 낸 뒤 256×256씩 배치해 `openings.webp`로 저장했다.

> Create one polished illustrated GAME ATLAS of ready-made architectural doors/windows. A landscape canvas perfectly divided into a strict THREE COLUMN by TWO ROW grid, six SQUARE cells. Zero gutters. Each asset completely fills its whole square cell edge to edge. NO wallpaper outside, NO floor, NO scene, NO text/numbers/labels, NO shadows cast outside cells. Actual front elevation for a Korean elementary children's house construction game, warm detailed gouache, clean hand-painted wood, dimensional crafted materials, charming miniature dollhouse detail, clearly legible when resized to 80 pixels. Straight-on facing camera, absolutely no perspective. Draw all framing and handles within each cell; no arched tops. Six exact cells, order matters.
>
> Top row left: a closed cozy dark walnut front entry door showing straight thick wooden doorframe at edges, two handsome finely grained raised walnut panels and a small polished brass door handle on the right, no other feature. Top row center: a CLOSED golden-green bamboo sliding door made of lashed green bamboo vertical stalks, a neat wooden frame around four sides, a dark recessed pull on the left and horizontal wood runner along bottom edge. Top row right: authentic Korean hanji window, soft luminous ivory paper behind simple carefully spaced geometric warm wood changsal lattice filling the square, thick rectangular wooden perimeter.
>
> Bottom row left: a charming FOUR-PETAL flower rosette stained glass window, ruby and amber petals on jewel-blue sky glass, dark lead dividers, slim dark hardwood outer frame occupying all four edges. Bottom row center: bright turquoise sea-glass window in a whitewashed timber frame with central vertical mullion, two watery aqua glass panes with soft flowing wave highlights. Bottom row right: a radiant golden EIGHT-POINTED STAR motif inside cobalt and emerald stained glass, dark lead seams and slim copper squared frame. Central star exactly symmetrical and strong from any rotation: game maps it into a DIAMOND.
>
> All assets must align exactly to the 3x2 grid with no margins. All six are square source art even though the game may stretch the doors taller. Do not include cell names or any lettering, signs, hinges that extend out of a cell, people, elaborate surroundings, or empty background.
