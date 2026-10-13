---
name: triangle-geometry
description: Handles triangle geometry, side lengths, angles, grid units, triangle validation and classification.
---

# Quadrilateral Geometry Skill

For the current Quadrilateral World project, use `scripts/core/quadrilateral_math.gd`:
1. Each part's four ordered local `vertices` and `position` are the only authoritative geometry.
2. Never store side lengths or angles as independent authoritative state. Compute them from the vertices.
3. Use the math module's measurements and classification. Follow the curriculum's inclusive definitions: a trapezoid has at least one parallel pair; a square is also a rectangle, rhombus, parallelogram, and trapezoid.
4. Validate an interior-angle sum approximately 360 degrees; `display_angles()` keeps displayed integer degrees at exactly 360.
5. Grid distance is `pixel_distance / grid_step`; the current workshop grid step is 20 pixels per unit.
6. Preserve the selected trapezoid, parallelogram, rhombus, rectangle, or square family under supported transformations. Reject nonfinite, crossed, concave, or collapsed four-vertex shapes. Do not introduce unrestricted vertex dragging.
7. Cover geometry changes with `tests/test_quadrilateral_math.gd` and run `powershell -File tools/run_tests.ps1`.
