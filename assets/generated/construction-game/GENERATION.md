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
