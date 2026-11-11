# Drawing studio artwork provenance

## Illustrated backgrounds — 2026-10-28

Thirty independent original PNG backgrounds were produced with the built-in `image_gen` tool (one generation for each scene; no API key or fallback CLI). The final images were copied from the tool's generated-image directory into `backgrounds/`; the source originals remain in place. The full prompts and original generated filenames are recorded in [background-prompts.json](background-prompts.json). All thirty are finished source images, rather than palette changes of one image.

Scenes: daytime city, nighttime city, sea, sunset beach, coral reef, planets, moon base, galaxy, green mountains, snowy mountains, autumn mountains, cozy home, treehouse, country cottage, forest, bamboo forest, desert, oasis, polar ice, meadow, farm, garden, castle, village, harbor, river, lake, waterfall, rainbow sky and playground. The drawing catalog supplies their Korean names.

Shared art direction: landscape 8:5; friendly geometric papercraft/gouache illustration; subtle paper grain; spacious composition for children's own artwork; quadrilateral scenery silhouettes; no people, text, logos, borders or watermark. These are original generated scenes with no proprietary game assets. The Godot import pipeline limits the packaged texture size for memory and uses lossy compression; original PNG source files are preserved unchanged.

## Geometric masterpiece studies — 2026-10-28

The `masterpieces/*.svg` files are original vector educational studies generated
from the explicit geometry in `tools/generate_drawing_guides.py`. They are not
museum image downloads, scans, traces, or reproductions of textbook illustrations.
No external image assets, fonts, signatures, logos, or proprietary artwork are
embedded in these files. The named underlying historical works are in the public
domain; the museum links below were used to verify titles, artists and dates.

Production brief: "Create an original, simplified geometric study of the named
historical composition, recognizable by its principal subjects and arrangement.
Use a 960 × 600 canvas and convex, nondegenerate four-sided regions suitable for
filling with several approved quadrilateral pieces. Produce a calm gray outlined
underdrawing on warm white paper, and a separate colored geometric reference with
identical regions. Do not include text, numbers, signatures, decorative UI, or
textbook illustrations. Keep every study below the drawing document's 128-part
limit."

The SVG guides use `#9ba5a5` outlines and `#f9f8f3` fills on `#fffdf8` paper.
The `*-reference.svg` variants illustrate one possible color arrangement; players
may freely choose their own colors, shapes and interpretation. An original study
is not a claim to match the composition or appearance of the original painting.

| ID | Historical work and artist | Source date | Four-sided regions | Metadata source |
|---|---|---|---:|---|
| `starry_night` | The Starry Night — Vincent van Gogh | 1889 | 48 | [MoMA](https://www.moma.org/collection/works/79802) |
| `sunflowers` | Sunflowers — Vincent van Gogh | 1889 | 74 | [Van Gogh Museum](https://www.vangoghmuseum.nl/en/collection/s0031V1962) |
| `bedroom` | The Bedroom — Vincent van Gogh | 1888 | 35 | [Van Gogh Museum](https://www.vangoghmuseum.nl/en/collection/s0047V1962) |
| `mona_lisa` | Mona Lisa — Leonardo da Vinci | 1503–1519 | 33 | [Louvre](https://collections.louvre.fr/en/ark:/53355/cl010062370) |
| `pearl_earring` | Girl with a Pearl Earring — Johannes Vermeer | c. 1665 | 23 | [Mauritshuis](https://www.mauritshuis.nl/en/our-collection/artworks/670-girl-with-a-pearl-earring) |
| `great_wave` | Under the Wave off Kanagawa — Katsushika Hokusai | c. 1830–1832 | 45 | [The Metropolitan Museum of Art](https://www.metmuseum.org/art/collection/search/45434) |
| `water_lilies` | Water Lilies — Claude Monet | 1914–1926 | 48 | [MoMA](https://www.moma.org/collection/works/80220) |
| `red_blue_yellow` | Composition with Red, Blue and Yellow — Piet Mondrian | 1930 | 12 | [Kunsthaus Zürich](https://kunsthaus.ch/en/sammlung/klassische-moderne/) |
| `the_scream` | The Scream — Edvard Munch | 1893 | 36 | [Nasjonalmuseet](https://www.nasjonalmuseet.no/en/collection/object/NG.M.00939) |
| `apple_basket` | The Basket of Apples — Paul Cézanne | c. 1893 | 41 | [Art Institute of Chicago](https://www.artic.edu/artworks/111436/the-basket-of-apples) |

Rebuild the vector originals with `python tools/generate_drawing_guides.py`.
The generator verifies that every drawn region has four points, is convex and has
nonzero area. These are underdrawing guides, not editable artwork document parts;
the game continues deriving player artwork geometry through `QuadrilateralMath`.

The guides deliberately reinterpret curved shapes with faceted regions. Users
fill them by arranging their own quadrilaterals; no silhouette score, puzzle
stars or copied textbook questions are introduced.

## 2026-11-10 무손실 저장 형식 최적화

현재 게임에서 쓰는 PNG 원본은 크기와 모든 RGBA 픽셀을 그대로 유지하는 무손실 WebP로 재인코딩했습니다. 이 문서와 프롬프트 JSON의 `.png` 이름·생성 ID는 최초 생성 기록이며, 현재 파일명과 원본/현재 SHA-256·크기·픽셀 해시는 `assets/image_optimization_manifest.json`의 `original_path` → `path` 대응표로 확인합니다. 원본 PNG와 `.import`는 프로젝트 밖의 `rectangle_game_quarantine_2026-11-10/original_images/`에 같은 상대 경로로 백업하고 해시를 검증했습니다. 투명도·해상도·아틀라스 좌표와 Godot import UID·압축/크기 설정은 유지했습니다. 원화와 프롬프트를 새로 생성하거나 손실 압축한 작업이 아닙니다.
