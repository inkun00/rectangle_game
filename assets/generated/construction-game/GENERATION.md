# Construction game UI artwork — 2026-10-29

All fourteen PNG assets were generated independently with the built-in `image_gen` tool. No CLI, API key, downloaded game artwork, copied characters, logos, or extracted proprietary assets were used. The originals were copied into this directory and left at the tool's original generated-image location as well.

The exact production prompts, alpha settings and original generated filenames are saved in [prompts.json](prompts.json). The inspected official game references and adoption decisions are recorded in [CONSTRUCTION_GAME_REFERENCES.md](../../../docs/CONSTRUCTION_GAME_REFERENCES.md).

The direction combines a simple building toy interface, large material previews, visible build/test/reward steps, warm cream surfaces, cobalt controls and cheerful toy diorama scenery. Text, money, focus rings, measurements, progress bars and editable four-vertex artwork remain native Godot controls so they stay readable and accurate. They sit on the generated UI surfaces rather than being baked into artwork.

| Files | Use |
|---|---|
| `worksite.png` | Sunny illustrated building yard |
| `panel-light.png`, `panel-dark.png` | Inventory, project cards, stage selection, help, completion and gallery surfaces |
| `button-light.png`, `button-blue.png` | Secondary and primary interactive control surfaces |
| `tool-icons.png` | Sixteen matching toolbar, currency and reward icons |
| `material-base.png`, `material-expanded.png` | Material previews and the actual textured house parts |
| `client-portraits.png` | Six original friendly village client portraits |
| `badge-1.png` to `badge-5.png` | Five increasingly elaborate architectural construction awards: hard hats, brick houses, tools, blueprints and cranes; true alpha |

Runtime slicing and scaling adapts the painted panels and atlases to responsive controls. It does not replace them with procedural illustrations. PNG exports retain the player's real house and add only its validated earned badge in the top-left corner; guides, labels and tool UI are omitted.

## Architectural badge revision — 2026-10-29

At the user's request, all five badge images were regenerated independently with the built-in `image_gen` tool and replaced at their existing filenames. The exact replacement prompts and source filenames are in [badge-revision-prompts.json](badge-revision-prompts.json); the previous prompts remain in `prompts.json` as historical production records. Original generated files also remain in the tool's generated-image directory.

The revised theme uses a wooden apprentice plaque with hard hat, bricks and hammer; a silver builder frame with brick house and carpenter square; a blueprint-and-house architect plaque; a crane-and-tools building award; and an elaborate master-builder frame with timber structure, scaffolding and crane. Higher tiers gain architectural detail and richer construction framing. Royal crowns, gems, crystals, laurel wreaths and fantasy wings are excluded. All five images preserve transparent alpha and remain legible at the existing 112px UI and 148px PNG stamp sizes. Award thresholds, saved tiers, money and progression are unchanged.

## 2026-11-10 무손실 저장 형식 최적화

현재 게임에서 쓰는 PNG 원본은 크기와 모든 RGBA 픽셀을 그대로 유지하는 무손실 WebP로 재인코딩했습니다. 이 문서와 프롬프트 JSON의 `.png` 이름·생성 ID는 최초 생성 기록이며, 현재 파일명과 원본/현재 SHA-256·크기·픽셀 해시는 `assets/image_optimization_manifest.json`의 `original_path` → `path` 대응표로 확인합니다. 원본 PNG와 `.import`는 프로젝트 밖의 `rectangle_game_quarantine_2026-11-10/original_images/`에 같은 상대 경로로 백업하고 해시를 검증했습니다. 투명도·해상도·아틀라스 좌표와 Godot import UID·압축/크기 설정은 유지했습니다. 원화와 프롬프트를 새로 생성하거나 손실 압축한 작업이 아닙니다.
