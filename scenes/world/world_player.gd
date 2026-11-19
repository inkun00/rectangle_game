class_name WorldPlayer
extends CharacterBody2D

## Sagaki's movement and combat drive the poses shared with the story endings.
signal jumped
signal respawned
signal attack_requested(origin: Vector2, direction: float)
signal damaged(amount: int)
signal defeated

const SPEED: float = 320.0
const ACCELERATION: float = 1900.0
const GRAVITY: float = 1450.0
const JUMP_SPEED: float = -625.0
const MAX_FALL_SPEED: float = 900.0
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.13
const DEFAULT_WORLD_WIDTH: float = 11000.0
const BODY_HEIGHT: float = 112.0
const ATTACK_INTERVAL: float = 0.4
const HIT_IMMUNITY: float = 0.85
const Art = preload("res://scripts/core/sagaki_art.gd")

var controls_enabled: bool = true
var touch_left: bool = false
var touch_right: bool = false
var touch_jump: bool = false
var spawn_point: Vector2 = Vector2(280.0, 690.0)
var facing: float = 1.0
var hp: int = 100
var max_hp: int = 100
var attack_cooldown: float = 0.0
var invulnerability: float = 0.0
var world_width: float = DEFAULT_WORLD_WIDTH
var _world_min_x: float = 36.0
var _world_max_x: float = DEFAULT_WORLD_WIDTH - 36.0
var _phase: float = 0.0
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _jump_was_down: bool = false
var _walk_amount: float = 0.0
var _attack_pose_left: float = 0.0
var _knockback_left: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 8.0
	var body_shape: CapsuleShape2D = CapsuleShape2D.new()
	body_shape.radius = 19.0
	body_shape.height = 94.0
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.name = "BodyCollision"
	collider.position = Vector2(0.0, -47.0)
	collider.shape = body_shape
	add_child(collider)

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		clear_touch_controls()
		velocity = Vector2.ZERO
		_jump_buffer_left = 0.0
		_jump_was_down = true
		_knockback_left = 0.0

func set_touch_control(action: String, pressed: bool) -> void:
	if pressed and not controls_enabled: return
	match action:
		"left": touch_left = pressed
		"right": touch_right = pressed
		"jump": touch_jump = pressed

func clear_touch_controls() -> void:
	touch_left = false
	touch_right = false
	touch_jump = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: clear_touch_controls()

func set_world_bounds(width: float, left_margin: float = 36.0, right_margin: float = 36.0) -> void:
	if not is_finite(width) or not is_finite(left_margin) or not is_finite(right_margin):
		return
	if left_margin < 0.0 or right_margin < 0.0 or width <= left_margin + right_margin:
		return
	world_width = width
	_world_min_x = left_margin
	_world_max_x = width - right_margin
	position.x = clampf(position.x, _world_min_x, _world_max_x)

func respawn() -> void:
	position = spawn_point
	velocity = Vector2.ZERO
	_knockback_left = 0.0
	_attack_pose_left = 0.0
	invulnerability = HIT_IMMUNITY
	respawned.emit()
	queue_redraw()

func begin_attack() -> bool:
	if not controls_enabled or hp <= 0 or attack_cooldown > 0.0:
		return false
	attack_cooldown = ATTACK_INTERVAL
	_attack_pose_left = 0.28
	attack_requested.emit(global_position + Vector2(facing * 22.0, -58.0), facing)
	queue_redraw()
	return true

func take_damage(amount: int, source_x: float) -> bool:
	if amount <= 0 or hp <= 0 or invulnerability > 0.0 or not is_finite(source_x):
		return false
	var actual: int = mini(amount, hp)
	hp -= actual
	invulnerability = HIT_IMMUNITY
	_knockback_left = 0.18
	var away: float = signf(global_position.x - source_x)
	if is_zero_approx(away):
		away = -facing
	velocity = Vector2(away * 260.0, -190.0)
	_attack_pose_left = 0.0
	damaged.emit(actual)
	if hp == 0:
		defeated.emit()
	queue_redraw()
	return true

func heal(amount: int) -> void:
	if amount > 0:
		hp = mini(max_hp, hp + amount)
		queue_redraw()

func set_health(value: int, maximum: int, reset_combat: bool = true) -> void:
	max_hp = clampi(maximum, 1, 100000)
	hp = clampi(value, 0, max_hp)
	if reset_combat:
		invulnerability = 0.0
		attack_cooldown = 0.0
		_attack_pose_left = 0.0
		_knockback_left = 0.0
	queue_redraw()

func pose_name() -> String:
	if hp <= 0:
		return "defeated"
	if _attack_pose_left > 0.0:
		return "attack"
	if _knockback_left > 0.0:
		return "hurt"
	if absf(velocity.y) > 35.0:
		return "jump"
	if _walk_amount > 0.05:
		return "walk"
	return "idle"

func _physics_process(delta: float) -> void:
	# Keep this guard outside pause handling so an invalid loaded position recovers.
	if position.y > 1200.0 and hp > 0:
		respawn()
	if not controls_enabled or not is_visible_in_tree() or hp <= 0:
		return
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	invulnerability = maxf(invulnerability - delta, 0.0)
	_attack_pose_left = maxf(_attack_pose_left - delta, 0.0)
	_knockback_left = maxf(_knockback_left - delta, 0.0)
	var direction: float = float(touch_right or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(touch_left or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var jump_down: bool = touch_jump or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	if absf(direction) > 0.0 and _knockback_left <= 0.0:
		facing = direction
	if Input.is_physical_key_pressed(KEY_Z) or Input.is_physical_key_pressed(KEY_F):
		begin_attack()
	_coyote_left = COYOTE_TIME if is_on_floor() else maxf(_coyote_left - delta, 0.0)
	_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
	if jump_down and not _jump_was_down:
		_jump_buffer_left = JUMP_BUFFER
	if _jump_buffer_left > 0.0 and _coyote_left > 0.0 and _knockback_left <= 0.0:
		velocity.y = JUMP_SPEED
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		jumped.emit()
	if not jump_down and _jump_was_down and velocity.y < -250.0:
		velocity.y *= 0.58
	_jump_was_down = jump_down
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	if _knockback_left <= 0.0:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
	move_and_slide()
	position.x = clampf(position.x, _world_min_x, _world_max_x)
	_walk_amount = move_toward(_walk_amount, minf(absf(velocity.x) / SPEED, 1.0), delta * 8.0)
	_phase += delta * lerpf(2.0, 16.0, _walk_amount)
	queue_redraw()

func pose_frame() -> int:
	match pose_name():
		"walk": return Art.walk_frame(_phase)
		"jump": return Art.JUMP
		"attack": return Art.ATTACK
		"hurt", "defeated": return Art.HURT
		_: return Art.IDLE

func _draw() -> void:
	var frame: int = pose_frame()
	var bob: float = -absf(sin(_phase)) * 2.0 * _walk_amount if frame in [Art.WALK_A, Art.WALK_B] else 0.0
	var tint: Color = Color.WHITE
	if invulnerability > 0.0 and fmod(invulnerability, 0.12) > 0.07:
		tint.a = 0.52
	Art.draw_pose(self, Vector2(0.0, bob), BODY_HEIGHT, frame, facing, tint)
