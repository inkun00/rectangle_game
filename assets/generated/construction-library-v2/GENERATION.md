# 집짓기 재료 표면

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

2026-11-22 내장 ImageGen으로 4×4 질감 이미지 한 장을 생성했다. 생성 ID는 `exec-ccdc837a-ed2c-4057-a002-0691a764c3cf`이다. 1254×1254 원본의 각 칸 가장자리를 3픽셀씩 잘라 이웃 재질이 비치지 않도록 한 뒤 칸마다 256×256으로 축소했다. 게임은 결과물 [surfaces.webp](surfaces.webp)에서 자재에 맞는 칸을 골라 재료 카드, 도면, 완성 이미지의 네 꼭짓점에 맞춘다.

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

같은 날 내장 ImageGen으로 문 2종과 창문 4종의 앞모습을 따로 제작했다. 생성 ID는 `exec-e96e7087-7513-40ce-b656-48f5a4889186`이다. 손잡이와 창틀을 포함한 1536×1024 원화에서 칸마다 2픽셀의 가장자리를 덜어 낸 뒤 256×256씩 배치해 [openings.webp](openings.webp)로 저장했다.

> Create one polished illustrated GAME ATLAS of ready-made architectural doors/windows. A landscape canvas perfectly divided into a strict THREE COLUMN by TWO ROW grid, six SQUARE cells. Zero gutters. Each asset completely fills its whole square cell edge to edge. NO wallpaper outside, NO floor, NO scene, NO text/numbers/labels, NO shadows cast outside cells. Actual front elevation for a Korean elementary children's house construction game, warm detailed gouache, clean hand-painted wood, dimensional crafted materials, charming miniature dollhouse detail, clearly legible when resized to 80 pixels. Straight-on facing camera, absolutely no perspective. Draw all framing and handles within each cell; no arched tops. Six exact cells, order matters.
>
> Top row left: a closed cozy dark walnut front entry door showing straight thick wooden doorframe at edges, two handsome finely grained raised walnut panels and a small polished brass door handle on the right, no other feature. Top row center: a CLOSED golden-green bamboo sliding door made of lashed green bamboo vertical stalks, a neat wooden frame around four sides, a dark recessed pull on the left and horizontal wood runner along bottom edge. Top row right: authentic Korean hanji window, soft luminous ivory paper behind simple carefully spaced geometric warm wood changsal lattice filling the square, thick rectangular wooden perimeter.
>
> Bottom row left: a charming FOUR-PETAL flower rosette stained glass window, ruby and amber petals on jewel-blue sky glass, dark lead dividers, slim dark hardwood outer frame occupying all four edges. Bottom row center: bright turquoise sea-glass window in a whitewashed timber frame with central vertical mullion, two watery aqua glass panes with soft flowing wave highlights. Bottom row right: a radiant golden EIGHT-POINTED STAR motif inside cobalt and emerald stained glass, dark lead seams and slim copper squared frame. Central star exactly symmetrical and strong from any rotation: game maps it into a DIAMOND.
>
> All assets must align exactly to the 3x2 grid with no margins. All six are square source art even though the game may stretch the doors taller. Do not include cell names or any lettering, signs, hinges that extend out of a cell, people, elaborate surroundings, or empty background.
