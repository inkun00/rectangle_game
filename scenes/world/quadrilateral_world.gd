class_name QuadrilateralWorld
extends Node2D

## A continuous, safe side-scrolling world. Quest progress belongs to QuestJournal;
## world state only records unique pickup instances and the player's position.

signal interaction_requested(npc_id: String)
signal hint_requested(message: String)
signal region_changed(region_name: String)
signal progress_changed
signal service_requested(service_id: String)
signal enemy_defeated(enemy_id: String)
signal item_collected(label: String, quest_id: String, count: int, required: int)

const PlayerScript = preload("res://scenes/world/world_player.gd")
const Catalog = preload("res://scripts/world/quest_catalog.gd")
const Artwork = preload("res://scenes/world/world_artwork.gd")
const WORLD_WIDTH: float = 11000.0
const GROUND_Y: float = 690.0
const FONT: Font = preload("res://assets/fonts/korean_font.ttf")
const REGION_SPAWNS: Dictionary = {"market": Vector2(280, GROUND_Y), "forest": Vector2(1850, GROUND_Y), "valley": Vector2(3580, GROUND_Y), "harbor": Vector2(5460, GROUND_Y), "snow": Vector2(7240, GROUND_Y), "citadel": Vector2(9040, GROUND_Y)}

const REGION_DATA: Array[Dictionary] = [
	{"id": "market", "name": "초록 마을", "start": 0.0, "end": 1600.0, "subtitle": "달콤한 가게와 지붕 공방"},
	{"id": "forest", "name": "바람 숲", "start": 1600.0, "end": 3300.0, "subtitle": "길 잃은 강아지와 다리 만들기"},
	{"id": "valley", "name": "평행 계곡", "start": 3300.0, "end": 5200.0, "subtitle": "도서관과 사각형 축제"},
	{"id": "harbor", "name": "사다리 항구", "start": 5200.0, "end": 7000.0, "subtitle": "멈춘 별빛 배와 항구 창고"},
	{"id": "snow", "name": "거울 설원", "start": 7000.0, "end": 8800.0, "subtitle": "눈길의 평행 흔적과 빛의 거울"},
	{"id": "citadel", "name": "별빛 성곽", "start": 8800.0, "end": 11000.0, "subtitle": "사각형의 성질로 별빛을 되찾아요"},
]

var player: WorldPlayer
var journal: QuestJournal
var camera: Camera2D
var controls_enabled: bool = true
var peaceful: bool = false
var npcs: Array[Dictionary] = []
var collectibles: Array[Dictionary] = []
var platforms: Array[Rect2] = []
var services: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var _artwork: Artwork
var _adventure: RefCounted
var _checkpoint_region: String = "market"
var _collected: Dictionary = {}
var _clock: float = 0.0
var _region: String = ""
var _initialized: bool = false
var _pending_restore: Dictionary = {}
var _pickup_effects: Array[Dictionary] = []


func _ready() -> void:
	if _initialized and controls_enabled:
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()


func setup(character: Dictionary, quest_journal: QuestJournal) -> void:
	journal = quest_journal
	if not _initialized:
		_initialize_world()
	player.set_character(character)
	if not journal.changed.is_connected(_on_journal_changed):
		journal.changed.connect(_on_journal_changed)
	if not _pending_restore.is_empty():
		_apply_restore(_pending_restore)
		_pending_restore.clear()
	else:
		_reconcile_collected_with_journal()
	set_controls_enabled(controls_enabled)
	queue_redraw()


func _initialize_world() -> void:
	_initialized = true
	npcs = [
		{"id": "baker", "name": "제빵사 코코", "role": "초콜릿 가게", "quest": "rhombus_chocolates", "position": Vector2(485.0, GROUND_Y), "color": Color("db9073")},
		{"id": "roofer", "name": "지붕 장인 루프", "role": "지붕 공방", "quest": "trapezoid_roofs", "position": Vector2(990.0, GROUND_Y), "color": Color("6daed0")},
		{"id": "ranger", "name": "숲지기 모리", "role": "강아지를 찾아요", "quest": "square_puppy", "position": Vector2(1770.0, GROUND_Y), "color": Color("80af72")},
		{"id": "guide", "name": "안내원 직각이", "role": "숲길 안내소", "quest": "right_angle_sign", "position": Vector2(2190.0, GROUND_Y), "color": Color("d6a752")},
		{"id": "carpenter", "name": "목수 파라", "role": "다리 작업장", "quest": "parallelogram_bridge", "position": Vector2(3010.0, GROUND_Y), "color": Color("b995cf")},
		{"id": "surveyor", "name": "측량사 라인", "role": "평행길 정거장", "quest": "parallel_rails", "position": Vector2(3530.0, GROUND_Y), "color": Color("619fae")},
		{"id": "librarian", "name": "사서 북이", "role": "도형 도서관", "quest": "rectangle_library", "position": Vector2(4140.0, GROUND_Y), "color": Color("c98dba")},
		{"id": "mayor", "name": "촌장 네모", "role": "사각형 축제", "quest": "square_festival", "position": Vector2(4780.0, GROUND_Y), "color": Color("8393cf")},
		{"id": "sailor", "role": "별빛 배 선착장", "quest": "harbor_sails", "position": Vector2(5530, GROUND_Y)},
		{"id": "keeper", "role": "항구 창고", "quest": "harbor_crates", "position": Vector2(6510, GROUND_Y)},
		{"id": "lamplighter", "role": "설원의 등불", "quest": "snow_lanterns", "position": Vector2(7390, GROUND_Y)},
		{"id": "tracker", "role": "눈길 탐험대", "quest": "snow_tracks", "position": Vector2(7900, GROUND_Y)},
		{"id": "glazier", "role": "거울 유리 공방", "quest": "snow_windows", "position": Vector2(8430, GROUND_Y)},
		{"id": "guardian", "role": "성곽 문지기", "quest": "citadel_banners", "position": Vector2(9110, GROUND_Y)},
		{"id": "archivist", "role": "별빛 기록실", "quest": "citadel_seals", "position": Vector2(9730, GROUND_Y)},
		{"id": "astronomer", "role": "별빛 관측소", "quest": "starlight_core", "position": Vector2(10520, GROUND_Y)},
	]
	for npc: Dictionary in npcs:
		var quest: Dictionary = Catalog.get_quest(str(npc["quest"]))
		npc["name"] = quest["npc_name"]
		npc["sheet"] = quest.get("npc_sheet", "npc_atlas")
		npc["icon"] = quest.get("npc_icon", 0)
	platforms = [
		Rect2(1010.0, 582.0, 185.0, 22.0), Rect2(1250.0, 478.0, 195.0, 22.0),
		Rect2(1500.0, 582.0, 175.0, 22.0), Rect2(1940.0, 582.0, 170.0, 22.0),
		Rect2(2390.0, 582.0, 180.0, 22.0), Rect2(2590.0, 478.0, 185.0, 22.0),
		Rect2(2860.0, 582.0, 155.0, 22.0), Rect2(3200.0, 582.0, 145.0, 22.0),
		Rect2(3640.0, 582.0, 180.0, 22.0), Rect2(3880.0, 478.0, 165.0, 22.0),
		Rect2(4360.0, 582.0, 180.0, 22.0), Rect2(4590.0, 478.0, 185.0, 22.0),
		Rect2(4890.0, 582.0, 180.0, 22.0),
		Rect2(5600, 582, 170, 22), Rect2(5810, 478, 185, 22),
		Rect2(6140, 582, 170, 22), Rect2(6380, 478, 190, 22), Rect2(6660, 582, 180, 22),
		Rect2(7270, 582, 180, 22), Rect2(7490, 478, 185, 22),
		Rect2(7790, 582, 190, 22), Rect2(8030, 478, 190, 22),
		Rect2(8350, 582, 180, 22), Rect2(8580, 478, 180, 22),
		Rect2(9140, 582, 180, 22), Rect2(9360, 478, 190, 22),
		Rect2(9660, 582, 180, 22), Rect2(9880, 478, 190, 22),
		Rect2(10190, 582, 180, 22), Rect2(10420, 478, 180, 22), Rect2(10720, 582, 180, 22),
	]
	_add_static_ground(Rect2(0.0, GROUND_Y, WORLD_WIDTH, 230.0), false)
	for platform: Rect2 in platforms:
		_add_static_ground(platform, true)
	_spawn_pickups()
	_initialize_services_and_enemies()
	_artwork = Artwork.new()
	add_child(_artwork)
	_artwork.configure(npcs, collectibles, platforms, WORLD_WIDTH)
	for enemy: Dictionary in enemies:
		_artwork.add_enemy(enemy)
	player = PlayerScript.new()
	player.set_world_bounds(WORLD_WIDTH)
	player.name = "DrawnCharacter"
	player.position = Vector2(280.0, GROUND_Y)
	player.z_index = 5
	add_child(player)
	player.respawned.connect(func() -> void: hint_requested.emit("쉼터로 돌아왔어요. 다시 출발해 볼까요?"))
	if player.has_signal("attack_requested"):
		player.connect("attack_requested", _on_player_attack)
	camera = Camera2D.new()
	camera.name = "WorldCamera"
	camera.position = Vector2(0.0, -270.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.5
	camera.limit_left = 0
	camera.limit_right = int(WORLD_WIDTH)
	camera.limit_top = 0
	camera.limit_bottom = 900
	camera.limit_smoothed = true
	player.add_child(camera)
	if is_inside_tree():
		camera.make_current()
	_sync_adventure_state()
	_refresh_artwork()


func _add_static_ground(rect: Rect2, one_way: bool) -> void:
	var ground: StaticBody2D = StaticBody2D.new()
	ground.position = rect.get_center()
	ground.collision_layer = 1
	ground.collision_mask = 2
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.shape = shape
	collider.one_way_collision = one_way
	collider.one_way_collision_margin = 10.0
	ground.add_child(collider)
	add_child(ground)


func _initialize_services_and_enemies() -> void:
	services = [
		{"id": "shop", "name": "모험 상점", "position": Vector2(650, GROUND_Y)},
		{"id": "inn", "name": "초록 쉼터", "position": Vector2(205, GROUND_Y)},
		{"id": "travel", "name": "초록 마을 포털", "position": Vector2(90, GROUND_Y)},
		{"id": "travel", "name": "바람 숲 포털", "position": Vector2(1680, GROUND_Y)},
		{"id": "travel", "name": "평행 계곡 포털", "position": Vector2(3380, GROUND_Y)},
		{"id": "travel", "name": "사다리 항구 포털", "position": Vector2(5310, GROUND_Y)},
		{"id": "travel", "name": "거울 설원 포털", "position": Vector2(7110, GROUND_Y)},
		{"id": "travel", "name": "별빛 성곽 포털", "position": Vector2(8910, GROUND_Y)},
		{"id": "inn", "name": "항구 쉼터", "position": Vector2(5900, GROUND_Y)},
		{"id": "inn", "name": "설원 쉼터", "position": Vector2(8150, GROUND_Y)},
		{"id": "inn", "name": "별빛 쉼터", "position": Vector2(10000, GROUND_Y)},
	]
	enemies = [
		{"id": "forest_moss_1", "name": "네모 이끼", "base_x": 1610.0, "position": Vector2(1610, GROUND_Y), "texture": 10, "hp": 2, "direction": 1.0, "flash": 0.0},
		{"id": "forest_moss_2", "name": "장난꾸러기 잎새", "base_x": 2310.0, "position": Vector2(2310, GROUND_Y), "texture": 11, "hp": 2, "direction": 1.0, "flash": 0.0},
		{"id": "valley_crystal_1", "name": "보석 슬라임", "base_x": 3440.0, "position": Vector2(3440, GROUND_Y), "texture": 12, "hp": 2, "direction": 1.0, "flash": 0.0},
		{"id": "valley_crystal_2", "name": "축제 장난꾼", "base_x": 4540.0, "position": Vector2(4540, GROUND_Y), "texture": 11, "hp": 2, "direction": 1.0, "flash": 0.0},
		{"id": "harbor_moss_1", "name": "부두 장난꾼", "base_x": 6260.0, "position": Vector2(6260, GROUND_Y), "texture": 11, "hp": 2, "direction": 1.0, "flash": 0.0},
		{"id": "snow_crystal_1", "name": "눈꽃 슬라임", "base_x": 7650.0, "position": Vector2(7650, GROUND_Y), "texture": 12, "hp": 2, "direction": 1.0, "flash": 0.0},
		{"id": "citadel_moss_1", "name": "별빛 장난꾼", "base_x": 10240.0, "position": Vector2(10240, GROUND_Y), "texture": 10, "hp": 2, "direction": 1.0, "flash": 0.0},
	]


func configure_adventure(state: RefCounted) -> void:
	if _adventure != state:
		if _adventure != null and _adventure.has_signal("changed") and _adventure.is_connected("changed", _sync_adventure_state):
			_adventure.disconnect("changed", _sync_adventure_state)
		for enemy: Dictionary in enemies:
			enemy["hp"] = 2
	_adventure = state
	if _adventure != null and _adventure.has_signal("changed") and not _adventure.is_connected("changed", _sync_adventure_state):
		_adventure.connect("changed", _sync_adventure_state)
	if _adventure != null:
		# Loading an older save can restore this same state object in place.
		# Revive only encounters absent from its authoritative defeat record;
		# ordinary reentry preserves recorded defeats and living patrol damage.
		var defeated_ids: Dictionary = _adventure.get("defeated_enemies")
		for enemy: Dictionary in enemies:
			if int(enemy["hp"]) == 0 and not defeated_ids.has(str(enemy["id"])):
				enemy["hp"] = 2
	_sync_adventure_state()


func _sync_adventure_state() -> void:
	if not _initialized or _adventure == null:
		return
	var defeated_ids: Dictionary = _adventure.get("defeated_enemies")
	for enemy: Dictionary in enemies:
		if defeated_ids.has(str(enemy["id"])):
			enemy["hp"] = 0
	var discovered: Dictionary = _adventure.get("discovered_regions")
	if not discovered.has(_checkpoint_region):
		_checkpoint_region = "market"
	if is_instance_valid(player):
		player.spawn_point = REGION_SPAWNS[_checkpoint_region]
	_refresh_artwork()


func travel_to(region_id: String) -> bool:
	if not _initialized or not REGION_SPAWNS.has(region_id):
		return false
	if _adventure == null:
		if region_id != "market":
			return false
	else:
		var discovered: Dictionary = _adventure.get("discovered_regions")
		if not discovered.has(region_id):
			return false
	_checkpoint_region = region_id
	player.spawn_point = REGION_SPAWNS[region_id]
	player.position = player.spawn_point
	player.velocity = Vector2.ZERO
	if is_inside_tree():
		camera.reset_smoothing()
	progress_changed.emit()
	return true


func recover_at_checkpoint() -> void:
	if not is_instance_valid(player):
		return
	player.spawn_point = REGION_SPAWNS.get(_checkpoint_region, REGION_SPAWNS["market"])
	player.respawn()
	if is_inside_tree():
		camera.reset_smoothing()
	progress_changed.emit()


func get_enemy_status() -> Array[Dictionary]:
	return enemies.duplicate(true)


func _on_player_attack(origin: Vector2, direction: float) -> void:
	attack_at(origin, direction)


func attack_at(origin: Vector2, direction: float) -> int:
	if not controls_enabled or _adventure == null or is_zero_approx(direction):
		return 0
	var hits: int = 0
	_artwork.add_effect(origin + Vector2(signf(direction) * 48.0, 0.0))
	for enemy: Dictionary in enemies:
		if int(enemy["hp"]) <= 0:
			continue
		var offset: Vector2 = Vector2(enemy["position"]) + Vector2(0, -35) - origin
		var forward: float = offset.x * signf(direction)
		if forward < -12.0 or forward > 110.0 or absf(offset.y) > 85.0:
			continue
		enemy["hp"] = maxi(0, int(enemy["hp"]) - 1)
		enemy["flash"] = 0.28
		hits += 1
		_artwork.add_effect(Vector2(enemy["position"]) + Vector2(0, -35))
		if int(enemy["hp"]) == 0:
			_artwork.add_effect(Vector2(enemy["position"]) + Vector2(0, -65), "coin")
			_pickup_effects.append({"position": Vector2(enemy["position"]) + Vector2(0, -40), "age": 0.0, "text": "+20 XP"})
			enemy_defeated.emit(str(enemy["id"]))
			progress_changed.emit()
	_refresh_artwork()
	return hits


func _update_enemies(delta: float) -> void:
	if _adventure == null:
		return
	for i: int in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		if int(enemy["hp"]) <= 0:
			continue
		var phase: float = _clock * 0.88 + float(i) * 1.8
		enemy["position"] = Vector2(float(enemy["base_x"]) + sin(phase) * 44.0, GROUND_Y)
		enemy["direction"] = signf(cos(phase))
		enemy["flash"] = maxf(0.0, float(enemy["flash"]) - delta)
		var offset: Vector2 = player.position - Vector2(enemy["position"])
		if not peaceful and absf(offset.x) < 44.0 and absf(offset.y) < 70.0 and player.has_method("take_damage"):
			player.call("take_damage", 8, Vector2(enemy["position"]).x)


func _refresh_artwork() -> void:
	if not is_instance_valid(_artwork):
		return
	_artwork.update_story(journal.completed if journal != null else {})
	if is_instance_valid(player):
		_artwork.update_backdrop(player.position.x, _clock)
	for npc: Dictionary in npcs:
		_artwork.update_npc(npc, journal.quest_state(str(npc["quest"])) if journal != null else "available", _clock)
	for item: Dictionary in collectibles:
		_artwork.update_pickup(item, _collected.has(item["id"]), _can_pick_up(item), _clock)
	for enemy: Dictionary in enemies:
		_artwork.update_enemy(enemy, _clock)
		if _adventure == null:
			var sprite: Sprite2D = _artwork.enemy_sprites.get(str(enemy["id"]))
			if sprite != null:
				sprite.hide()


func _spawn_pickups() -> void:
	collectibles.clear()
	_add_pickup_series("rhombus_chocolate", "rhombus_chocolates", "마름모 초콜릿", "rhombus", Color("855442"), [Vector2(790, 650), Vector2(1100, 546), Vector2(1340, 442), Vector2(1570, 546)])
	_add_pickup_series("square_puppy", "square_puppy", "정사각형 강아지", "puppy", Color("f4dab0"), [Vector2(2690, 442)])
	_add_pickup_series("trapezoid_tile", "trapezoid_roofs", "사다리꼴 기와", "trapezoid", Color("d97b64"), [Vector2(1210, 650), Vector2(1445, 650), Vector2(2020, 546)])
	_add_pickup_series("parallelogram_plank", "parallelogram_bridge", "평행사변형 판자", "parallelogram", Color("c69763"), [Vector2(2930, 546), Vector2(3170, 650), Vector2(3270, 546)])
	_add_pickup_series("rectangle_book", "rectangle_library", "직사각형 책", "rectangle", Color("759dca"), [Vector2(3970, 442), Vector2(4260, 650)])
	_add_pickup_series("parallel_marker", "parallel_rails", "평행 표시판", "parallel", Color("65a3a0"), [Vector2(3720, 546), Vector2(3850, 650)])
	_add_pickup_series("right_angle_tool", "right_angle_sign", "직각 도구", "right_angle", Color("dfa843"), [Vector2(2470, 546)])
	_add_pickup_series("square_badge", "square_festival", "정사각형 배지", "square", Color("dfb44d"), [Vector2(4450, 546), Vector2(4680, 442), Vector2(4990, 546)])
	_add_pickup_series("trapezoid_sail", "harbor_sails", "사다리꼴 돛", "trapezoid", Color.WHITE, [Vector2(5700, 546), Vector2(5910, 442), Vector2(6100, 650)])
	_add_pickup_series("rectangle_crate", "harbor_crates", "직사각형 상자", "rectangle", Color.WHITE, [Vector2(6470, 442), Vector2(6740, 546)])
	_add_pickup_series("rhombus_lantern", "snow_lanterns", "마름모 등불", "rhombus", Color.WHITE, [Vector2(7360, 546), Vector2(7580, 442), Vector2(7870, 546)])
	_add_pickup_series("parallel_track", "snow_tracks", "평행한 발자국", "parallel", Color.WHITE, [Vector2(7700, 650), Vector2(8120, 442)])
	_add_pickup_series("square_window", "snow_windows", "정사각형 창문", "square", Color.WHITE, [Vector2(8390, 546), Vector2(8670, 442), Vector2(8780, 650)])
	_add_pickup_series("parallel_banner", "citadel_banners", "평행사변형 깃발", "parallelogram", Color.WHITE, [Vector2(9230, 546), Vector2(9440, 442), Vector2(9590, 650)])
	_add_pickup_series("rectangle_seal", "citadel_seals", "직사각형 인장", "rectangle", Color.WHITE, [Vector2(9750, 546), Vector2(9970, 442)])
	_add_pickup_series("square_core", "starlight_core", "정사각형 별빛 코어", "square", Color.WHITE, [Vector2(10260, 546), Vector2(10510, 442), Vector2(10800, 546), Vector2(10930, 650)])


func _add_pickup_series(target: String, quest_id: String, label: String, shape: String, color: Color, points: Array) -> void:
	var quest: Dictionary = Catalog.get_quest(quest_id)
	for i: int in range(points.size()):
		collectibles.append({"id": "%s_%d" % [target, i], "target": target, "quest": quest_id, "label": label, "shape": shape, "color": color, "position": points[i], "sheet": quest.get("item_sheet", "items_atlas"), "icon": quest.get("item_icon", 0), "required": int(quest.get("target_count", 0))})


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if is_instance_valid(player):
		player.set_controls_enabled(enabled)
	if enabled and is_instance_valid(camera):
		camera.enabled = true
		if is_inside_tree():
			camera.make_current()


func update_character(character: Dictionary) -> void:
	if is_instance_valid(player):
		player.set_character(character)


func get_current_region() -> String:
	if not is_instance_valid(player):
		return "초록 마을"
	return region_at(player.position.x).get("name", "초록 마을")


func navigation_points() -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for npc: Dictionary in npcs:
		var npc_position: Vector2 = npc["position"]
		points.append({"npc_id": npc["id"], "name": npc["name"], "position": npc_position, "region": region_at(npc_position.x)["name"], "quest_id": npc["quest"]})
	return points


static func region_at(x_position: float) -> Dictionary:
	for region: Dictionary in REGION_DATA:
		if x_position < float(region["end"]):
			return region
	return REGION_DATA.back()


func teleport_to_start() -> void:
	if is_instance_valid(player):
		player.respawn()
		camera.reset_smoothing()
		progress_changed.emit()


func serialize() -> Dictionary:
	var ids: Array[String] = []
	for id: String in _collected.keys():
		ids.append(id)
	return {"player_x": player.position.x if is_instance_valid(player) else 280.0, "player_y": player.position.y if is_instance_valid(player) else GROUND_Y, "collected": ids, "checkpoint_region": _checkpoint_region}


static func is_valid_save(data: Dictionary) -> bool:
	for field: String in ["player_x", "player_y"]:
		var value: Variant = data.get(field, 0.0)
		if not value is int and not value is float:
			return false
		if not is_finite(float(value)):
			return false
	var ids: Variant = data.get("collected", [])
	if not ids is Array or ids.size() > 512:
		return false
	for id: Variant in ids:
		if not id is String:
			return false
	var checkpoint: Variant = data.get("checkpoint_region", "market")
	if not checkpoint is String or not REGION_SPAWNS.has(checkpoint):
		return false
	return true


func restore(data: Dictionary) -> void:
	if not is_valid_save(data):
		return
	if not _initialized:
		_pending_restore = data.duplicate(true)
		return
	_apply_restore(data)


func _apply_restore(data: Dictionary) -> void:
	_collected.clear()
	var valid_ids: Dictionary = {}
	for pickup: Dictionary in collectibles:
		valid_ids[str(pickup["id"])] = true
	for id: Variant in data.get("collected", []):
		if valid_ids.has(str(id)):
			_collected[str(id)] = true
	_reconcile_collected_with_journal()
	var x_position: float = float(data.get("player_x", 280.0))
	var y_position: float = float(data.get("player_y", GROUND_Y))
	if not is_finite(x_position) or not is_finite(y_position):
		x_position = 280.0
		y_position = GROUND_Y
	player.position = Vector2(clampf(x_position, 36.0, WORLD_WIDTH - 36.0), clampf(y_position, 160.0, GROUND_Y))
	player.velocity = Vector2.ZERO
	_checkpoint_region = str(data.get("checkpoint_region", "market"))
	player.spawn_point = REGION_SPAWNS[_checkpoint_region]
	_sync_adventure_state()
	if is_inside_tree():
		camera.reset_smoothing()
	_refresh_artwork()
	queue_redraw()


func _reconcile_collected_with_journal() -> void:
	# The journal is authoritative for objective counts. Repair interrupted or
	# older saves with mismatched pickup lists so every unfinished quest stays
	# solvable and restoring a missing list cannot create duplicate inventory.
	if journal == null:
		return
	for quest: Dictionary in Catalog.all_quests():
		var expected: int = int(quest["target_count"]) if journal.quest_state(str(quest["id"])) == "completed" else int(journal.inventory.get(str(quest["target"]), 0))
		var taken: Array[String] = []
		var available: Array[String] = []
		for item: Dictionary in collectibles:
			if item["quest"] == quest["id"]:
				if _collected.has(item["id"]):
					taken.append(str(item["id"]))
				else:
					available.append(str(item["id"]))
		while taken.size() > expected:
			_collected.erase(taken.pop_back())
		while taken.size() < expected and not available.is_empty():
			var id: String = available.pop_front()
			_collected[id] = true
			taken.append(id)


func _on_journal_changed() -> void:
	_refresh_artwork()
	queue_redraw()
	progress_changed.emit()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or not _initialized:
		return
	if not controls_enabled:
		return
	_clock += delta
	_artwork.advance_effects(delta)
	for i: int in range(_pickup_effects.size() - 1, -1, -1):
		_pickup_effects[i]["age"] = float(_pickup_effects[i]["age"]) + delta
		if float(_pickup_effects[i]["age"]) > 1.1:
			_pickup_effects.remove_at(i)
	var current_region: String = get_current_region()
	if current_region != _region:
		_region = current_region
		var region_id: String = str(region_at(player.position.x)["id"])
		_checkpoint_region = region_id
		player.spawn_point = REGION_SPAWNS[region_id]
		if _adventure != null:
			_adventure.call("discover", region_id)
		region_changed.emit(current_region)
		progress_changed.emit()
	_refresh_artwork()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _initialized or journal == null or not controls_enabled or not is_visible_in_tree():
		return
	_update_enemies(delta)
	for item: Dictionary in collectibles:
		if _collected.has(item["id"]) or not _can_pick_up(item):
			continue
		var offset: Vector2 = Vector2(item["position"]) - (player.position + Vector2(0.0, -43.0))
		if absf(offset.x) < 46.0 and absf(offset.y) < 43.0:
			collect_pickup(str(item["id"]))


func collect_pickup(instance_id: String) -> bool:
	if journal == null or _collected.has(instance_id):
		return false
	for item: Dictionary in collectibles:
		if str(item["id"]) != instance_id or not _can_pick_up(item):
			continue
		if not journal.collect_item(str(item["target"])):
			return false
		_collected[instance_id] = true
		_artwork.add_effect(item["position"], "coin")
		_pickup_effects.append({"position": item["position"], "age": 0.0, "text": str(item["label"]) + " +1"})
		var quest: Dictionary = Catalog.get_quest(str(item["quest"]))
		var count: int = int(journal.inventory.get(str(item["target"]), 0))
		var required: int = int(quest["target_count"])
		var message: String = "%s · %d/%d개 가방에 담았어요!" % [item["label"], count, required]
		if journal.quest_state(str(item["quest"])) == "available":
			message += " %s에게 가져가 주세요." % quest["npc_name"]
		hint_requested.emit(message)
		item_collected.emit(str(item["label"]), str(item["quest"]), count, required)
		progress_changed.emit()
		_refresh_artwork()
		queue_redraw()
		return true
	return false


func _can_pick_up(item: Dictionary) -> bool:
	if journal == null or journal.completed.has(str(item["quest"])):
		return false
	return int(journal.inventory.get(str(item["target"]), 0)) < int(item.get("required", 0))


func nearby_pickup() -> Dictionary:
	if not is_instance_valid(player):
		return {}
	var closest: Dictionary = {}
	var closest_distance: float = INF
	for item: Dictionary in collectibles:
		if _collected.has(item["id"]) or not _can_pick_up(item):
			continue
		var offset: Vector2 = Vector2(item["position"]) - (player.position + Vector2(0, -43))
		# A generous horizontal reach, but a different platform still requires
		# jumping. HUD prompts and both pickup keys use this same predicate.
		if absf(offset.x) > 115.0 or absf(offset.y) > 49.0:
			continue
		if offset.length_squared() < closest_distance:
			closest_distance = offset.length_squared()
			closest = item
	return closest.duplicate()


func pickup_nearest() -> bool:
	if not controls_enabled:
		return false
	var item: Dictionary = nearby_pickup()
	if item.is_empty():
		hint_requested.emit("가까운 물품이 없어요. 물품 옆으로 이동한 뒤 G를 눌러 주세요. 위쪽 물품은 점프해서 같은 발판으로 올라가요!")
		return false
	return collect_pickup(str(item["id"]))


func nearest_interaction() -> Dictionary:
	if not is_instance_valid(player):
		return {}
	var pickup: Dictionary = nearby_pickup()
	if not pickup.is_empty():
		return {"type": "item", "id": pickup["id"], "name": pickup["label"], "quest": pickup["quest"], "position": pickup["position"]}
	var closest: Dictionary = {}
	var closest_distance: float = 110.0
	for service: Dictionary in services:
		var distance: float = player.position.distance_to(Vector2(service["position"]))
		if distance < closest_distance:
			closest_distance = distance
			closest = {"type": "service", "id": service["id"], "name": service["name"], "position": service["position"]}
	for npc: Dictionary in npcs:
		var distance: float = player.position.distance_to(Vector2(npc["position"]))
		if distance < closest_distance:
			closest_distance = distance
			closest = {"type": "npc", "id": npc["id"], "name": npc["name"], "position": npc["position"]}
	return closest


func interact() -> void:
	if not controls_enabled:
		return
	var target: Dictionary = nearest_interaction()
	if target.is_empty():
		return
	if target["type"] == "npc":
		interaction_requested.emit(str(target["id"]))
	elif target["type"] == "service":
		service_requested.emit(str(target["id"]))
	else:
		pickup_nearest()


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not controls_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if key == KEY_G:
			pickup_nearest()
			get_viewport().set_input_as_handled()
		elif key == KEY_E:
			interact()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	# Labels are the only code-drawn world visuals; artwork uses Sprite2D atlases.
	if not _initialized:
		return
	for npc: Dictionary in npcs:
		var pos: Vector2 = npc["position"]
		_center_text(pos + Vector2(0, -153), str(npc["name"]), 16, Color("fbf5dc"))
		_center_text(pos + Vector2(0, 25), str(npc["role"]), 12, Color("f8edd1"))
	for item: Dictionary in collectibles:
		if _collected.has(item["id"]):
			continue
		var pos: Vector2 = item["position"]
		_center_text(pos + Vector2(0, 48), str(item["label"]), 12, Color("fff0ba") if _can_pick_up(item) else Color("ececdd"))
	for service: Dictionary in services:
		var pos: Vector2 = service["position"]
		_center_text(pos + Vector2(0, -100 if service["id"] != "travel" else -180), str(service["name"]), 14, Color("fff0bd"))
	for enemy: Dictionary in enemies:
		if int(enemy["hp"]) > 0 and _adventure != null:
			_center_text(Vector2(enemy["position"]) + Vector2(0, -82), str(enemy["name"]), 12, Color("f4e7bc"))
	for effect: Dictionary in _pickup_effects:
		var age: float = float(effect["age"])
		_center_text(Vector2(effect["position"]) + Vector2(0, -42.0 - age * 45.0), str(effect["text"]), 17, Color(1.0, 0.96, 0.74, clampf(1.5 - age, 0, 1)))
	_draw_interaction_prompt()


func _draw_interaction_prompt() -> void:
	if not controls_enabled:
		return
	var target: Dictionary = nearest_interaction()
	if target.is_empty():
		return
	var text: String = "E  ·  %s와 대화" % target["name"] if target["type"] == "npc" else "E  ·  " + str(target["name"])
	if target["type"] == "item":
		text = "G / E  ·  %s 줍기" % target["name"]
	_center_text(player.position + Vector2(0, -155), text, 16, Color("fff4c8"))


func _center_text(baseline: Vector2, text: String, size: int, color: Color) -> void:
	var width: float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var start: Vector2 = baseline - Vector2(width * 0.5, 0.0)
	draw_string_outline(FONT, start, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.14, 0.20, 0.20, color.a * 0.83))
	draw_string(FONT, start, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
