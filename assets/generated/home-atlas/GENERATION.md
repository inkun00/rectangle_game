# 홈 메뉴 원화

2026-11-22에 Codex 내장 ImageGen으로 홈 타이틀과 세 활동의 메뉴 그림을 제작했다. 캐릭터의 참고 자료는 이 게임 오프닝에 쓰인 사각이 원화다. 청록색 사각 머리, 남색 눈과 부츠, 산호색 목도리, 금색 장식이 달린 상의를 맞췄다.

원본 생성 파일은 `exec-809c2cfd-f521-4b56-9950-8a0ed9bd184f.png`이며 크기는 1536 × 1024이다. 위에서부터 타이틀, 그림 작업실, 건축 공방, 사각형 마을 순이다. 각 단의 경계 픽셀을 제외하고 FFmpeg로 자른 뒤 품질 88의 WebP로 저장했다. 한글은 게임에서 직접 표시한다.

| 파일 | 원본 y 범위 (상한 미포함) |
| --- | --- |
| arrival.webp | 0–254 |
| drawing.webp | 257–509 |
| building.webp | 513–765 |
| village.webp | 769–1024 |

## 생성 프롬프트

```text
Use case: illustration-story. Produce one build-ready, landscape game menu illustration atlas, four original wide postcard pictures in four contiguous horizontal strips stacked vertically (top quarter, second quarter, third quarter, bottom quarter), each strip fills its entire rectangular area edge to edge. Landscape 3:2 canvas. Perfectly aligned straight horizontal cuts at exactly 25%, 50%, 75%; no gaps, borders or stripes. No lettering or typography anywhere. Each of these four wide illustrations tells a complete story, composed for a premium whimsical Korean children's paper-diorama exploration RPG. Rich fibered cardstock, soft side rim light, crisp constructed paper edges and small layered shadows, warm matte analog picture-book color separations, miniature physical objects; quiet areas balanced with bold silhouettes. (1, top) cinematic ultrawide night sky of deep ink navy, little flecks of starlight and a small golden comet. Keep the LEFT 50% a clean uninterrupted dark navy field for white game title UI. On the RIGHT, behind and around x=70%, a mint and amber rolling island, little cream block village buildings with lit windows, a pale mint planet ring in the distance, and a SINGLE full body mint square-headed adventurer exactly as the provided reference (neutral upper left outfit, faithful square eyes, coral scarf, ivory tunic and gold patch) feet on the hill. Fit his entire silhouette inside this first strip with generous margins. (2) intimate warm sunset-lit studio still life, an angled wood easel showing a beautiful paper collage made only of squares, rhombi and trapezoids, pots of gouache paint, a coral colored pencil and teal papers on a desk, peach/coral wall backdrop. (3) miniature house-building atelier, a beautiful partly assembled cream-white folded cardboard townhouse with teal roof and warm golden windows, ochre architectural ruler, little quadrilateral material swatches on a honey yellow workbench, warm sunny golden ochre palette. (4, bottom) magical layered jade-green woodland village walking trail: mint square-shaped tree crowns, a tiny coral awning on the village shop, little paper bridge arching over turquoise stream and a view toward distant block rooftops of a town. No characters in strips 2/3/4. In strips 2/3/4 keep all main objects around horizontal center, in middle vertical half of each strip with margins to allow crop. Each strip has distinctly different colors and silhouettes. Native asset: four original game menu illustrations on a contact sheet. No watermarks, logos, user interface objects, frames, labels, type or track lines.
```

## 최후의 선택

`choice.webp`는 마지막 활동이 열리면 나타나는 집과 우주선의 원화다. 위의 `building.webp`를 재질 참고 자료로 전달해 내장 ImageGen으로 별도 생성했다. 원본은 `exec-c959e028-ca4c-400d-be29-4d9e5995c1b3.png`다. 화면 표시 크기에 맞춰 원본 비율을 유지한 채 너비 900픽셀, WebP 품질 86으로 저장했다. 게임 안에서 사용하는 다섯 메뉴 그림은 Godot에서 손실 압축 품질 0.90으로 가져온다.

```text
Use case: illustration-story. Original landscape very wide 3:2 game menu illustration for the unlocked ending choice in a cozy paper-diorama children's adventure. Use the provided house-building atelier image only as a material and craftsmanship reference, not for layout. Mid-distance view of two equally significant little physical paper models side by side on a workbench: LEFT a completed warm ivory cottage with a jade teal roof and golden light in the windows. RIGHT a small retro ivory spacecraft standing on four squat coral and teal landing feet with a large teal square window and blocky, cream folded sides. Cuboid silhouettes and layered quadrilateral cardstock, artfully curved with cut notches, avoid pointed rocket nose. They represent a playable choice between a home on Earth and a journey back to the stars. Two models must both fit entirely within the CENTER 60% of the image: roof and top of spaceship sit just above horizontal middle, feet just below. Deep indigo star map behind them, specks of warm gold stars, twilight violet light from a circular observatory window; warm side lighting across paper fibres, small contact shadows, beautiful handcrafted tabletop, crisp. Full-bleed image with no frame, no boundaries, no text, no diagrams or symbols, no title, no letterforms, no characters, no buttons, no logo. Continuous composition, enough space above and below to crop to panoramic 2.6:1.
```
