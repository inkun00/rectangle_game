class_name SagakiArt
extends RefCounted

## The village and the endings use the same right-facing, foot-aligned poses.
enum { IDLE, WALK_A, WALK_B, JUMP, ATTACK, HURT }
const SHEET_PATH: String = "res://assets/generated/sagaki/sagaki-poses.webp"
const CELL_SIZE: float = 256.0
const FOOT_ANCHOR: Vector2 = Vector2(128.0, 239.0)
const IDLE_HEIGHT: float = 215.0
static var _sheet: Texture2D

static func walk_frame(phase: float) -> int:
	var stride: float = sin(phase)
	if absf(stride) < 0.32: return IDLE
	return WALK_A if stride > 0.0 else WALK_B

static func frame_region(frame: int) -> Rect2:
	var origin: Vector2 = Vector2(frame % 3, floori(frame / 3.0)) * CELL_SIZE
	return Rect2(origin, Vector2.ONE * CELL_SIZE)

static func draw_pose(canvas: CanvasItem, feet: Vector2, height: float, frame: int = IDLE, facing: float = 1.0, tint: Color = Color.WHITE) -> void:
	if _sheet == null:
		_sheet = load(SHEET_PATH) as Texture2D
	var scale_factor: float = height / IDLE_HEIGHT
	var destination: Rect2 = Rect2(feet - FOOT_ANCHOR * scale_factor, Vector2.ONE * CELL_SIZE * scale_factor)
	if facing < 0.0: destination.size.x = -destination.size.x
	canvas.draw_texture_rect_region(_sheet, destination, frame_region(frame), tint)
