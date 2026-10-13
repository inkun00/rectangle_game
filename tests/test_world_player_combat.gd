class_name TestWorldPlayerCombat
extends RefCounted

const Player = preload("res://scenes/world/world_player.gd")
const Templates = preload("res://scripts/core/character_templates.gd")

static func run(t: Node) -> void:
	_test_side_profiles(t)
	_test_damage_and_attacks(t)
	await _test_keyboard_and_pause(t)
	await _test_expanded_world_bounds(t)

static func _test_side_profiles(t: Node) -> void:
	for template: Dictionary in Templates.all_templates():
		var player: WorldPlayer = Player.new()
		var original: Dictionary = template.duplicate(true)
		player.set_character(template)
		var parts: Array[Dictionary] = player.get_render_parts()
		t.assert_eq(player.character, original, "Profile rendering preserves every authored vertex, color, kind and position")
		var head: Dictionary = _find(parts, "head")
		var body: Dictionary = _find(parts, "body")
		t.assert_gt(_center(head.vertices).x, _center(body.vertices).x, "Side view projects the head ahead of the body: " + str(template.id))
		var eye_count: int = 0
		for part: Dictionary in parts:
			if "eye" in str(part.slot_id):
				eye_count += 1
			if not bool(part.feature):
				var source: Dictionary = _source(template, str(part.slot_id))
				t.assert_eq(part.color, source.color, "Side projection keeps the player's chosen part color")
				t.assert_eq(part.kind, source.kind, "Side projection keeps the authored shape identity")
		t.assert_eq(eye_count, 1, "Exactly one eye is visible in the side profile")
		if str(template.id) != "beetle":
			var far: Dictionary = _find(parts, "leg_left")
			var near: Dictionary = _find(parts, "leg_right")
			t.assert_lt(int(far.depth), int(body.depth), "Far leg renders behind body")
			t.assert_gt(int(near.depth), int(body.depth), "Near leg renders in front of body")
			var front_leg_distance: float = absf(Vector2(_source(template, "leg_right").position).x - Vector2(_source(template, "leg_left").position).x) * player._art_scale
			var side_leg_distance: float = absf(_center(near.vertices).x - _center(far.vertices).x)
			t.assert_lt(side_leg_distance, front_leg_distance, "Profile limbs overlap instead of keeping frontal spread")
		if str(template.id) == "cat":
			t.assert_lt(_center(_find(parts, "tail").vertices).x, _center(body.vertices).x, "Cat tail lies behind its side-facing body")
			player.begin_attack()
			t.assert_true(_find(player.get_render_parts(), "leg_right").vertices != _find(parts, "leg_right").vertices, "Cat attacks with a forward paw pose")
			player.attack_cooldown = 0.0
			player._attack_pose_left = 0.0
		player.facing = -1.0
		var reverse: Array[Dictionary] = player.get_render_parts()
		t.assert_float_approx(_center(_find(reverse, "head").vertices).x, -_center(head.vertices).x, 0.001, "Left direction reverses the already-sideways rig")
		player.velocity.y = -100.0
		t.assert_eq(player.pose_name(), "jump", "Airborne motion selects jump pose")
		var jumped: Array[Dictionary] = player.get_render_parts()
		t.assert_true(jumped != reverse, "Jump visibly bends articulated limbs")
		player.velocity = Vector2.ZERO
		player._walk_amount = 1.0
		player._phase = 0.75
		t.assert_eq(player.pose_name(), "walk", "Walking selects gait pose")
		t.assert_true(player.get_render_parts() != reverse, "Walk cycles alter limb positions")
		t.assert_eq(player.character, original, "Facing, jumping and walking never mutate workshop artwork")
		player.free()

static func _test_damage_and_attacks(t: Node) -> void:
	var player: WorldPlayer = Player.new()
	player.position = Vector2(400, 500)
	player.set_character(Templates.get_template("robot"))
	var signals: Dictionary = {"attacks": 0, "damages": 0, "defeats": 0, "origin": Vector2.ZERO, "direction": 0.0}
	player.attack_requested.connect(func(origin: Vector2, direction: float):
		signals.attacks += 1
		signals.origin = origin
		signals.direction = direction)
	player.damaged.connect(func(amount: int): signals.damages += amount)
	player.defeated.connect(func(): signals.defeats += 1)
	var idle: Array[Dictionary] = player.get_render_parts()
	t.assert_true(player.begin_attack(), "Ready player can attack")
	t.assert_eq(signals.attacks, 1, "One accepted attack emits one hit request")
	t.assert_eq(signals.origin, Vector2(422, 442), "Attack origin is in front of torso in world space")
	t.assert_eq(signals.direction, 1.0, "Attack request carries facing direction")
	t.assert_eq(player.pose_name(), "attack", "Attack has dedicated pose")
	t.assert_true(_find(player.get_render_parts(), "hand_right").vertices != _find(idle, "hand_right").vertices, "Punch visibly extends near arm and hand")
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
	player.set_character(Templates.get_template("robot"))
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

static func _find(parts: Array[Dictionary], slot: String) -> Dictionary:
	for part: Dictionary in parts:
		if str(part.slot_id) == slot:
			return part
	return {}

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

static func _source(template: Dictionary, slot: String) -> Dictionary:
	for part: Dictionary in template.parts:
		if str(part.id) == slot:
			return part
	return {}

static func _center(vertices: PackedVector2Array) -> Vector2:
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in vertices:
		center += point
	return center / float(vertices.size())

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
