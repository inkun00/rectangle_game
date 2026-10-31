class_name WorldPlayer
extends CharacterBody2D

## Authored quadrilaterals remain unchanged. Side-profile projection and articulated
## poses are derived at render time, with far limbs behind the body and near limbs ahead.
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
const Templates = preload("res://scripts/core/character_templates.gd")

var controls_enabled: bool = true
var touch_left: bool = false
var touch_right: bool = false
var touch_jump: bool = false
var character: Dictionary = {}
var spawn_point: Vector2 = Vector2(280.0, 690.0)
var facing: float = 1.0
var hp: int = 100
var max_hp: int = 100
var attack_cooldown: float = 0.0
var invulnerability: float = 0.0
var world_width: float = DEFAULT_WORLD_WIDTH
var _world_min_x: float = 36.0
var _world_max_x: float = DEFAULT_WORLD_WIDTH - 36.0
var _parts: Array[Dictionary] = []
var _reference_parts: Dictionary = {}
var _template_id: String = "robot"
var _art_scale: float = 0.3
var _art_origin: Vector2 = Vector2.ZERO
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

func set_character(data: Dictionary) -> void:
	character = data.duplicate(true)
	_template_id = str(data.get("template_id", data.get("id", "robot")))
	_reference_parts.clear()
	var template: Dictionary = Templates.get_template(_template_id)
	for source: Dictionary in template.get("parts", []):
		_reference_parts[str(source.id)] = source
	_parts.clear()
	var first_vertex: bool = true
	var bounds: Rect2 = Rect2()
	for source: Dictionary in data.get("parts", []):
		var vertices: PackedVector2Array = source.get("vertices", PackedVector2Array())
		if vertices.size() != 4:
			continue
		_parts.append(source.duplicate(true))
		var part_position: Vector2 = source.get("position", Vector2.ZERO)
		for vertex: Vector2 in vertices:
			var point: Vector2 = vertex + part_position
			if first_vertex:
				bounds = Rect2(point, Vector2.ZERO)
				first_vertex = false
			else:
				bounds = bounds.expand(point)
	if not first_vertex:
		_art_scale = minf(BODY_HEIGHT / maxf(bounds.size.y, 1.0), 134.0 / maxf(bounds.size.x, 1.0))
		_art_origin = Vector2(bounds.get_center().x, bounds.end.y)
	queue_redraw()

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
	_phase += delta * (10.0 if _walk_amount > 0.05 else 2.0)
	queue_redraw()

func get_render_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pose: String = pose_name()
	var body_bob: float = -absf(sin(_phase)) * 3.0 * _walk_amount
	for part: Dictionary in _parts:
		var slot: String = str(part.get("slot_id", part.get("id", "")))
		# A true side view hides the far eye, while the complete authored data remains intact.
		if slot == "eye_left":
			continue
		var profile: Dictionary = _profile(part, slot)
		var projected_position: Vector2 = profile.position
		var squeeze: Vector2 = profile.squeeze
		var group: String = str(part.get("group", "body"))
		var pivot: Vector2 = _joint_for(group, projected_position)
		var angle: float = _joint_angle(group, pose)
		var rendered: PackedVector2Array = PackedVector2Array()
		for vertex: Vector2 in part.get("vertices", PackedVector2Array()):
			var point: Vector2 = projected_position + vertex.rotated(float(profile.rotation)) * squeeze
			if "arm" in group or "leg" in group:
				point = pivot + (point - pivot).rotated(angle)
			elif pose == "attack":
				point.x += 5.0
			point = (point - Vector2(0.0, _art_origin.y)) * _art_scale
			point.x *= facing
			point.y += body_bob
			rendered.append(point)
		result.append({"slot_id": slot, "group": group, "kind": str(part.get("kind", "")), "vertices": rendered, "color": part.get("color", Color("6a91dc")), "depth": int(profile.depth), "feature": false})
	result.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return int(first.depth) < int(second.depth))
	_add_face(result, body_bob, pose)
	return result

func _profile(part: Dictionary, slot: String) -> Dictionary:
	var original: Vector2 = part.get("position", Vector2.ZERO)
	var group: String = str(part.get("group", "body"))
	var projected: Vector2 = Vector2((original.x - _art_origin.x) * 0.38, original.y)
	# A side view may rearrange joints, but every individual quadrilateral
	# remains a similarity transform of the child's original four vertices.
	var squeeze: Vector2 = Vector2.ONE * 0.75
	var profile_rotation: float = 0.0
	var depth: int = 4
	var reference: Dictionary = _reference_parts.get(slot, {})
	var centers: Dictionary = {}
	match _template_id:
		"cat":
			centers = {"head": Vector2(20, -82), "ear_left": Vector2(5, -127), "ear_right": Vector2(25, -127), "eye_right": Vector2(40, -91), "nose": Vector2(56, -65), "body": Vector2(-2, 28), "belly": Vector2(19, 26), "tail": Vector2(-47, 28), "tail_tip": Vector2(-75, -38), "leg_left": Vector2(-8, 119), "leg_right": Vector2(11, 119)}
			if slot == "tail":
				profile_rotation = deg_to_rad(-52.0)
		"beetle":
			centers = {"head": Vector2(27, -88), "antenna_left": Vector2(22, -139), "antenna_right": Vector2(43, -139), "body": Vector2(0, 32), "wing_left": Vector2(-7, 27), "wing_right": Vector2(7, 27), "leg_left_1": Vector2(20, -8), "leg_right_1": Vector2(32, 4), "leg_left_2": Vector2(-8, 44), "leg_right_2": Vector2(3, 59), "leg_left_3": Vector2(-24, 108), "leg_right_3": Vector2(-11, 120)}
		_:
			centers = {"antenna": Vector2(15, -153), "head": Vector2(15, -106), "body": Vector2(0, -12), "chest": Vector2(29, -12), "arm_left": Vector2(-10, -11), "arm_right": Vector2(12, -11), "hand_left": Vector2(-10, 43), "hand_right": Vector2(12, 43), "leg_left": Vector2(-10, 90), "leg_right": Vector2(10, 90), "foot_left": Vector2(-2, 141), "foot_right": Vector2(18, 141)}
	if centers.has(slot) and not reference.is_empty():
		# Authored offsets remain visible instead of being discarded by the profile rig.
		projected = Vector2(centers[slot]) + (original - Vector2(reference.position)) * Vector2(0.55, 1.0)
	if group.ends_with("left"):
		depth = 1
	elif group.ends_with("right"):
		depth = 8
	if group == "body":
		depth = 3
		squeeze = Vector2.ONE * 0.63
	if slot == "head":
		depth = 6
		squeeze = Vector2.ONE * 0.78
	elif slot.begins_with("tail"):
		depth = 0
		squeeze = Vector2.ONE * 0.85
	elif slot == "chest" or slot == "belly":
		depth = 5
		squeeze = Vector2.ONE * 0.60
	elif slot == "eye_right" or slot == "nose":
		depth = 9
		squeeze = Vector2.ONE
	elif slot == "ear_left" or slot == "antenna_left":
		depth = 2
	elif slot == "ear_right" or slot == "antenna_right" or slot == "antenna":
		depth = 7
	elif slot == "wing_left":
		depth = 2
	elif slot == "wing_right":
		depth = 5
	return {"position": projected, "squeeze": squeeze, "depth": depth, "rotation": profile_rotation}

func _joint_for(group: String, center: Vector2) -> Vector2:
	var side: float = -1.0 if group.ends_with("left") else 1.0
	if "arm" in group:
		return Vector2(side * 10.0, -43.0 if _template_id != "beetle" else center.y - 12.0)
	if "leg" in group:
		return Vector2(side * 9.0, 57.0 if _template_id != "beetle" else 86.0)
	return center

func _joint_angle(group: String, pose: String) -> float:
	var side: float = -1.0 if group.ends_with("left") else 1.0
	if pose == "attack" and "arm" in group:
		return -1.28 if side > 0.0 else -0.22
	if pose == "attack" and _template_id == "cat" and "leg" in group:
		return -0.95 if side > 0.0 else 0.12
	if pose == "jump":
		if "leg" in group:
			return -0.60 if side > 0.0 else 0.26
		if "arm" in group:
			return 0.42 if side > 0.0 else -0.30
	if "leg" in group:
		return sin(_phase) * 0.40 * side * _walk_amount
	if "arm" in group:
		return sin(_phase) * -0.30 * side * _walk_amount
	return 0.0

func _add_face(result: Array[Dictionary], bob: float, pose: String) -> void:
	if _parts.is_empty() or _template_id == "cat":
		return
	var head: Dictionary = {}
	for part: Dictionary in _parts:
		if str(part.get("slot_id", part.get("id", ""))) == "head":
			head = part
			break
	if head.is_empty():
		return
	var profile: Dictionary = _profile(head, "head")
	var center: Vector2 = profile.position
	center += Vector2(19.0 + (5.0 if pose == "attack" else 0.0), -7.0)
	var eye: PackedVector2Array = PackedVector2Array()
	for offset: Vector2 in [Vector2(-5, -6), Vector2(5, -6), Vector2(5, 6), Vector2(-5, 6)]:
		var point: Vector2 = (center + offset - Vector2(0, _art_origin.y)) * _art_scale
		point.x *= facing
		point.y += bob
		eye.append(point)
	result.append({"slot_id": "profile_eye", "group": "head", "kind": "rectangle", "vertices": eye, "color": Color("213a49"), "depth": 10, "feature": true})
	# The small forward-facing mouth is character artwork, not a world effect.
	if _template_id == "robot":
		var mouth: PackedVector2Array = PackedVector2Array()
		for offset: Vector2 in [Vector2(10, 15), Vector2(23, 15), Vector2(23, 19), Vector2(10, 19)]:
			var point: Vector2 = (Vector2(profile.position) + offset - Vector2(0, _art_origin.y)) * _art_scale
			point.x *= facing
			point.y += bob
			mouth.append(point)
		result.append({"slot_id": "profile_mouth", "group": "head", "kind": "rectangle", "vertices": mouth, "color": Color("213a49"), "depth": 10, "feature": true})

func _draw() -> void:
	if invulnerability > 0.0 and fmod(invulnerability, 0.12) > 0.07:
		return
	for part: Dictionary in get_render_parts():
		var points: PackedVector2Array = part.vertices
		if points.size() != 4:
			continue
		var color: Color = part.color
		draw_colored_polygon(points, color)
		if not bool(part.feature):
			var outline: PackedVector2Array = points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, color.darkened(0.34), 1.7, true)
