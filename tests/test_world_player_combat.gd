class_name TestWorldPlayerCombat
extends RefCounted

const Player = preload("res://scenes/world/world_player.gd")
const HeroArt = preload("res://scripts/core/sagaki_art.gd")

static func run(t: Node) -> void:
	_test_protagonist_frames(t)
	_test_damage_and_attacks(t)
	await _test_keyboard_and_pause(t)
	await _test_expanded_world_bounds(t)

static func _test_protagonist_frames(t: Node) -> void:
	var texture: Texture2D = load(HeroArt.SHEET_PATH) as Texture2D
	t.assert_not_null(texture, "The playable hero has a shipped opening-matched sprite sheet")
	if texture == null: return
	var image: Image = texture.get_image()
	var seen: Array[Rect2i] = []
	for frame_id: int in [HeroArt.IDLE, HeroArt.WALK_A, HeroArt.WALK_B, HeroArt.JUMP, HeroArt.ATTACK, HeroArt.HURT]:
		var region: Rect2i = Rect2i(HeroArt.frame_region(frame_id))
		t.assert_true(Rect2i(Vector2i.ZERO, image.get_size()).encloses(region), "Every hero pose is inside the shipped sheet")
		t.assert_false(seen.has(region), "Each action selects its own sprite cell")
		seen.append(region)
		var pose: Image = image.get_region(region)
		t.assert_true(pose.get_used_rect().has_area(), "Every action contains visible hero pixels")
		t.assert_true(pose.detect_alpha() != Image.ALPHA_NONE, "Every hero pose has a transparent background")

	var player: WorldPlayer = Player.new()
	t.assert_eq(player.pose_frame(), HeroArt.IDLE, "A stationary player displays Sagaki's idle pose")
	player._walk_amount = 1.0
	var steps: Array[int] = []
	for tick: int in range(24):
		player._phase = TAU * float(tick) / 24.0
		var frame: int = player.pose_frame()
		if not steps.has(frame): steps.append(frame)
	t.assert_true(steps.has(HeroArt.WALK_A) and steps.has(HeroArt.WALK_B), "A walk cycle uses both strides")
	for frame: int in steps:
		t.assert_true(frame in [HeroArt.IDLE, HeroArt.WALK_A, HeroArt.WALK_B], "Walking uses only grounded poses")
	player.velocity.y = -100.0
	t.assert_eq(player.pose_frame(), HeroArt.JUMP, "An airborne player displays the jump sprite")
	player.facing = -1.0
	t.assert_eq(player.pose_frame(), HeroArt.JUMP, "Facing left retains the hero's current action")
	t.assert_true(player.begin_attack(), "An airborne player can start a directional attack")
	t.assert_eq(player.pose_frame(), HeroArt.ATTACK, "An attack selects its own sprite above the airborne pose")
	player._attack_pose_left = 0.0
	player.take_damage(8, player.global_position.x + 60.0)
	t.assert_eq(player.pose_frame(), HeroArt.HURT, "Initial knockback displays the hurt sprite")
	player.free()

static func _test_damage_and_attacks(t: Node) -> void:
	var player: WorldPlayer = Player.new()
	player.position = Vector2(400, 500)
	var signals: Dictionary = {"attacks": 0, "damages": 0, "defeats": 0, "origin": Vector2.ZERO, "direction": 0.0}
	player.attack_requested.connect(func(origin: Vector2, direction: float):
		signals.attacks += 1
		signals.origin = origin
		signals.direction = direction)
	player.damaged.connect(func(amount: int): signals.damages += amount)
	player.defeated.connect(func(): signals.defeats += 1)
	t.assert_true(player.begin_attack(), "Ready player can attack")
	t.assert_eq(signals.attacks, 1, "One accepted attack emits one hit request")
	t.assert_eq(signals.origin, Vector2(422, 442), "Attack origin is in front of torso in world space")
	t.assert_eq(signals.direction, 1.0, "Attack request carries facing direction")
	t.assert_eq(player.pose_name(), "attack", "Attack has dedicated pose")
	t.assert_false(player.begin_attack(), "Cooldown prevents duplicate attacks")
	t.assert_eq(signals.attacks, 1, "Rejected attack emits no hit request")
	player.attack_cooldown = 0.0
	player.facing = -1.0
	t.assert_true(player.begin_attack(), "Player can attack left after cooldown")
	t.assert_eq(signals.origin, Vector2(378, 442), "Left attack origin extends left")
	t.assert_eq(signals.direction, -1.0, "Left attack carries negative direction")
	t.assert_true(player.take_damage(8, 350), "Enemy contact damages vulnerable player")
	t.assert_eq(player.hp, 92, "Damage reduces HP exactly once")
	t.assert_gt(player.velocity.x, 0.0, "Hit from left knocks player away to right")
	t.assert_lt(player.velocity.y, 0.0, "Hit gives a small upward knockback")
	t.assert_false(player.take_damage(8, 350), "Invulnerability blocks repeated contact damage")
	t.assert_eq(signals.damages, 8, "Blocked damage does not emit a second HP event")
	var immunity_before_sync: float = player.invulnerability
	var knockback_before_sync: float = player._knockback_left
	player.set_health(92, 120, false)
	t.assert_eq(player.invulnerability, immunity_before_sync, "Ordinary HP sync preserves damage immunity")
	t.assert_eq(player._knockback_left, knockback_before_sync, "Ordinary HP sync preserves hit knockback clock")
	t.assert_false(player.take_damage(8, 350), "State synchronization cannot bypass contact immunity")
	player.attack_cooldown = 0.0
	player.begin_attack()
	var cooldown_before_sync: float = player.attack_cooldown
	var pose_before_sync: float = player._attack_pose_left
	player.set_health(95, 100, false)
	t.assert_eq(player.hp, 95, "Ordinary HP sync still updates current health")
	t.assert_eq(player.attack_cooldown, cooldown_before_sync, "Ordinary HP sync preserves attack cooldown")
	t.assert_eq(player._attack_pose_left, pose_before_sync, "Ordinary HP sync preserves active attack pose")
	t.assert_false(player.begin_attack(), "State synchronization cannot bypass attack cooldown")
	player.heal(1000)
	t.assert_eq(player.hp, 100, "Healing clamps to maximum health")
	player.set_health(12, 120)
	t.assert_eq(player.max_hp, 120, "Level progression can change maximum health")
	t.assert_true(player.take_damage(50, 450), "Lethal damage is accepted")
	t.assert_eq(player.hp, 0, "Health never becomes negative")
	t.assert_eq(signals.defeats, 1, "Defeat signal emits exactly once")
	t.assert_false(player.take_damage(50, 450), "Defeated player cannot be damaged again")
	t.assert_false(player.begin_attack(), "Defeated player cannot attack")
	t.assert_eq(signals.defeats, 1, "No repeated defeat signals")
	player.heal(40)
	t.assert_eq(player.hp, 40, "World can heal player after defeat")
	player.set_controls_enabled(false)
	player.attack_cooldown = 0.0
	t.assert_false(player.begin_attack(), "Dialogue disables attacks")
	player.set_health(999, 80)
	t.assert_eq(player.hp, 80, "Restored HP is bounded by max HP")
	t.assert_false(player.take_damage(-5, 0), "Negative damage cannot heal the player")
	t.assert_false(player.take_damage(5, NAN), "Invalid enemy coordinates are rejected")
	player.free()

static func _test_keyboard_and_pause(t: Node) -> void:
	var player: WorldPlayer = Player.new()
	player.position = Vector2(400, 400)
	t.add_child(player)
	var emitted: Array[int] = [0]
	player.attack_requested.connect(func(_origin: Vector2, _direction: float): emitted[0] += 1)
	_press(KEY_Z, true)
	await _frames(t, 3)
	_press(KEY_Z, false)
	t.assert_eq(emitted[0], 1, "Physical Z key triggers combat attack")
	player.attack_cooldown = 0.0
	_press(KEY_F, true)
	await _frames(t, 3)
	_press(KEY_F, false)
	t.assert_eq(emitted[0], 2, "Physical F key also triggers attack")
	player.set_controls_enabled(false)
	var paused_position: Vector2 = player.position
	var paused_timer: float = player.attack_cooldown
	_press(KEY_D, true)
	_press(KEY_Z, true)
	await _frames(t, 4)
	_press(KEY_D, false)
	_press(KEY_Z, false)
	t.assert_eq(player.position, paused_position, "Dialogue freezes horizontal movement and falling")
	t.assert_eq(player.attack_cooldown, paused_timer, "Dialogue freezes combat timers")
	t.assert_eq(emitted[0], 2, "Dialogue blocks attack keys")
	player.set_controls_enabled(true)
	await _frames(t, 30)
	t.assert_float_approx(player.attack_cooldown, 0.0, 0.001, "Attack cooldown expires after resumed physics")
	player.free()

static func _test_expanded_world_bounds(t: Node) -> void:
	var player: WorldPlayer = Player.new()
	player.position = Vector2(5190, 400)
	player.set_world_bounds(11000.0)
	t.add_child(player)
	_press(KEY_D, true)
	await _frames(t, 15)
	_press(KEY_D, false)
	t.assert_gt(player.position.x, 5200.0, "Player can physically cross the old world edge into harbor")
	t.assert_eq(player.world_width, 11000.0, "Player movement uses the width supplied by its world")
	player.position = Vector2(10960, 400)
	player.velocity = Vector2.ZERO
	_press(KEY_D, true)
	await _frames(t, 8)
	_press(KEY_D, false)
	t.assert_float_approx(player.position.x, 10964.0, 0.001, "Right movement stops at expanded citadel world edge")
	player.set_world_bounds(12000.0, 40.0, 60.0)
	t.assert_eq(player.world_width, 12000.0, "Bounds API supports future maps without another movement-code change")
	player.position.x = 13000.0
	player.set_world_bounds(12000.0, 40.0, 60.0)
	t.assert_eq(player.position.x, 11940.0, "Applying new world bounds clamps current position safely")
	player.position.x = -30.0
	player.set_world_bounds(12000.0, 40.0, 60.0)
	t.assert_eq(player.position.x, 40.0, "Custom left boundary applies consistently")
	player.set_world_bounds(NAN)
	player.set_world_bounds(10.0, 20.0, 20.0)
	t.assert_eq(player.world_width, 12000.0, "Invalid or collapsed world bounds are ignored atomically")
	player.free()

static func _frames(t: Node, count: int) -> void:
	for frame: int in range(count):
		await t.get_tree().physics_frame

static func _press(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
