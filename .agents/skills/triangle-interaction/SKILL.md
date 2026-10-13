---
name: triangle-interaction
description: Handles selection, body drag, vertex handle manipulation, snapping, duplication, and Undo/Redo commands.
---

# Quadrilateral Interaction Skill

For the current Quadrilateral World project, use `scenes/workshop/character_workshop.gd` and `scripts/core/character_document.gd`:
1. Route every artwork mutation through the document's command history in `scripts/core/command_manager.gd` for Undo/Redo.
2. Clicking an existing quadrilateral selects it. Clicking an empty skeleton slot fills it only with the required shape family; clicking outside deselects or starts a new part.
3. Body dragging changes `position`, moving all four local vertices together. Rotation and uniform scaling must preserve the chosen family and valid geometry. Vertex dots are selection indicators; do not add unrestricted vertex editing.
4. Snap whole parts to compatible skeleton slots through `attach_selected()`; use the workshop's whole-position snapping for free parts. Do not snap individual vertices in a way that changes the selected family.
5. Duplicate the selected part through `duplicate_selected()`, preserving geometry and color, clearing its slot assignment, and using the current offset `Vector2(24, 24)`.
6. Cover selection, dragging, template attachment, and Undo/Redo with `tests/test_character_document.gd`. For workshop/world integration, also use `tests/test_app_integration.gd`. Run `powershell -File tools/run_tests.ps1`.
