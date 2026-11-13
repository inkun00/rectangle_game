# 사각성 귀환 우주선 부품

내장 `image_gen`으로 제작한 투명 스프라이트 36종. 각 파일은 1024×768 WebP이며 256×256 셀 12개를 행 우선으로 담는다. 각 셀에는 1448×1086 원본에서 잘라 낸 한 부품을 넣었다. 게임은 이미지의 네 모서리 안쪽을 표본으로 삼아 제품의 실제 네 꼭짓점에 맞춰 그린다. 외곽과 모양의 성질은 게임의 사각형 모델이 정한다. 웹에서는 제작소를 열 때 받는 선택 리소스에 포함한다.

| 파일 | 제품 등급 | 최종 원본 |
| --- | --- | --- |
| `standard.webp` | 기본형 | `exec-bbbf7add-be81-4333-a012-e5cf84874d97.png` |
| `advanced.webp` | 강화형 | `exec-3f27fddf-1dd5-4796-bf58-0a510d1121dc.png` |
| `elite.webp` | 최고급형 | `exec-589ab080-385b-43de-a824-e0ba0e2eb7eb.png` |

## 기본형 프롬프트

```text
Produce a game sprite sheet with exactly 12 individually isolated industrial spaceship components, in exact 4 columns × 3 rows of equal square cells, in the requested row-major order. Canvas 4:3 landscape. Transparent background and transparent space between the objects. One large centered component per cell; leave ~8% clear gutter around each cell, never touch another cell. No text, numbers, guide lines, grids, shadows outside the pieces or extra props. Game camera looks straight down on a flat plate, no perspective or isometric edges. Each part MUST be a solid face bounded by EXACTLY FOUR ruler-straight full outside edges meeting at four unmistakable corners. The filled silhouette is literally the geometry described; zero clipped or notched corners, clipped bevels, irregular scallops, rounding, outside barrels, outside tabs, hexagons, outlines made of tiny steps, cutout holes or fins. Draw the full perimeter as a clean, thick metallic rim, and paint complex cockpit glass, vents, bolts, cores and lights WITHIN that strict shape. Interiors may have detail, but the overall four-edge geometry should be instantly recognizable in a Grade 4 geometry game. Sophisticated hand-rendered retro sci-fi game art with dimensional metal materials INSIDE the shape, crisp dark edges, readable highlights and premium craftsmanship. All nose-like or propulsive shapes have a clearly finite flat fourth edge. Vary aspect ratios and sizes; separate graphics will be mounted on a larger ship. Match left/right visual design without repeating other parts.

Warm ivory and brushed nickel with bronze joints, teal light and a few amber vents. Functional expedition grade.

Row-major components:
1. tall narrow rectangular fuselage.
2. wide tapered trapezoid nose, short horizontal edge on top, long horizontal edge below.
3. broad rectangular cockpit windshield.
4. slanted parallelogram left wing plate, lean left.
5. opposite leaning parallelogram right wing plate.
6. narrow vertical rectangular fuel cell with gauge.
7. somewhat wider vertical rectangular fuel cell, mirrored gauge.
8. medium square propulsion block with circular turbine fully inside.
9. wide shallow rectangle exhaust manifold with amber vents.
10. tall narrow rhombus power cell, sharp diamond.
11. small square navigation display with radar.
12. very wide shallow rectangular armor rail with dark bevel.
The outer shapes are exactly four edges. Confirm 12 centered silhouettes, 4 columns and 3 rows. Output as transparent RGBA.
```

## 강화형 프롬프트

```text
Produce a game sprite sheet with exactly 12 individually isolated industrial spaceship components, in exact 4 columns × 3 rows of equal square cells, in the requested row-major order. Canvas 4:3 landscape. Transparent background and transparent space between the objects. One large centered component per cell; leave ~8% clear gutter around each cell, never touch another cell. No text, numbers, guide lines, grids, shadows outside the pieces or extra props. Game camera looks straight down on a flat plate, no perspective or isometric edges. Each part MUST be a solid face bounded by EXACTLY FOUR ruler-straight full outside edges meeting at four unmistakable corners. The filled silhouette is literally the geometry described; zero clipped or notched corners, clipped bevels, irregular scallops, rounding, outside barrels, outside tabs, hexagons, outlines made of tiny steps, cutout holes or fins. Draw the full perimeter as a clean, thick metallic rim, and paint complex cockpit glass, vents, bolts, cores and lights WITHIN that strict shape. Interiors may have detail, but the overall four-edge geometry should be instantly recognizable in a Grade 4 geometry game. Sophisticated hand-rendered retro sci-fi game art with dimensional metal materials INSIDE the shape, crisp dark edges, readable highlights and premium craftsmanship. All nose-like or propulsive shapes have a clearly finite flat fourth edge. Vary aspect ratios and sizes; separate graphics will be mounted on a larger ship. Match left/right visual design without repeating other parts.

Deep blue enamel, silver rims, blue-white cyan conduits, clean engineered grade, detailed small brushed silver accents.

Row-major components:
1. wide vertical rectangular fuselage.
2. oblique trapezoid nose, long edge on bottom, very short edge offset to the right at top.
3. wide low trapezoid cockpit, narrower bottom edge and long top edge.
4. asymmetric trapezoid left wing plate, long near-vertical edge on right and short near-vertical edge on left.
5. asymmetric trapezoid right wing plate, long near-vertical edge on left and short near-vertical edge on right.
6. upright diagonally left leaning parallelogram fuel cell.
7. upright oppositely leaning parallelogram fuel cell.
8. wide rectangular propulsion unit with blue turbine inside.
9. wide short inverted trapezoid manifold with long top edge and short bottom edge, bright internal vents.
10. small square luminous blue energy unit.
11. oblique rhombus navigation panel with four equal edges.
12. wide right-leaning parallelogram armor plate.
The outer shapes are exactly four edges. Confirm 12 centered silhouettes, 4 columns and 3 rows. Output as transparent RGBA.
```

## 최고급형 프롬프트

```text
Produce a game sprite sheet with exactly 12 individually isolated industrial spaceship components, in exact 4 columns × 3 rows of equal square cells, in the requested row-major order. Canvas 4:3 landscape. Transparent background and transparent space between the objects. One large centered component per cell; leave ~8% clear gutter around each cell, never touch another cell. No text, numbers, guide lines, grids, shadows outside the pieces or extra props. Game camera looks straight down on a flat plate, no perspective or isometric edges. Each part MUST be a solid face bounded by EXACTLY FOUR ruler-straight full outside edges meeting at four unmistakable corners. The filled silhouette is literally the geometry described; zero clipped or notched corners, clipped bevels, irregular scallops, rounding, outside barrels, outside tabs, hexagons, outlines made of tiny steps, cutout holes or fins. Draw the full perimeter as a clean, thick metallic rim, and paint complex cockpit glass, vents, bolts, cores and lights WITHIN that strict shape. Interiors may have detail, but the overall four-edge geometry should be instantly recognizable in a Grade 4 geometry game. Sophisticated hand-rendered retro sci-fi game art with dimensional metal materials INSIDE the shape, crisp dark edges, readable highlights and premium craftsmanship. All nose-like or propulsive shapes have a clearly finite flat fourth edge. Vary aspect ratios and sizes; separate graphics will be mounted on a larger ship. Match left/right visual design without repeating other parts.

Rich dark titanium, polished warm-gold rim and layered interior hardware, concentrated amethyst and cyan technology. The most extravagant of the sets, but maintain a single solid strict four-edged exterior per part.

Row-major components:
1. large, long oblique trapezoid titanium fuselage, long edge on top, shorter edge offset to the left on bottom.
2. wide gold rhombus prow with bright purple light.
3. distinct wide rhombus cockpit glass framed in gold.
4. wide aggressively slanted parallelogram left wing.
5. oppositely slanted parallelogram right wing.
6. tall trapezoid left fuel cell with two vertical parallel edges, outer left edge shorter.
7. tall trapezoid right fuel cell with two vertical parallel edges, outer right edge shorter.
8. big wide asymmetrical trapezoid propulsion casing, short top edge offset to the right, long bottom edge.
9. wide rectangular high-output manifold.
10. tall gold rim rhombus energy core with brilliant violet plasma.
11. medium square gold navigation unit with cyan radar.
12. very wide flat trapezoid protective armor plate with long top edge and short bottom edge offset left.
The outer shapes are exactly four edges. Confirm 12 centered silhouettes, 4 columns and 3 rows. Output as transparent RGBA.
```
