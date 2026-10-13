class_name WorldArtwork
extends Node2D

## Every world visual is a generated raster asset. Atlas regions are cropped
## only to their transparent bounds; no replacement geometry is synthesized.

const ROOT: String = "res://assets/generated/"
const ATLAS_LAYOUTS: Dictionary = {"environment_atlas": Vector2i(4, 3), "npc_atlas": Vector2i(4, 2), "items_atlas": Vector2i(4, 4), "expansion_environment": Vector2i(4, 2), "expansion_npcs": Vector2i(4, 2), "expansion_items": Vector2i(4, 2)}
const STORY_QUESTS: Dictionary = {"harbor": ["harbor_sails", "harbor_crates"], "snow": ["snow_lanterns", "snow_tracks", "snow_windows"], "citadel": ["citadel_banners", "citadel_seals", "starlight_core"]}
const DORMANT_STORY_COLOR: Color = Color(0.45, 0.50, 0.60)

var npc_sprites: Dictionary = {}
var quest_markers: Dictionary = {}
var pickup_sprites: Dictionary = {}
var enemy_sprites: Dictionary = {}
var story_landmarks: Dictionary = {}
static var _textures: Dictionary = {}
static var _atlas_textures: Dictionary = {}
var _backdrop: Sprite2D
var _expansion_backdrop: Sprite2D
var _effects: Array[Dictionary] = []
var _portal_sprites: Array[Sprite2D] = []


func configure(npcs: Array[Dictionary], pickups: Array[Dictionary], platforms: Array[Rect2], world_width: float = 11000.0) -> void:
	name = "GeneratedWorldArtwork"
	_backdrop = _sprite(_texture("world_backdrop"), Rect2(-700, -250, 6150, 1160), -100, true)
	_expansion_backdrop = _sprite(_texture("expansion_backdrop"), Rect2(4950, -250, 6650, 1160), -99, true)
	var transition_shader: Shader = Shader.new()
	transition_shader.code = "shader_type canvas_item; void fragment() { COLOR = texture(TEXTURE, UV); COLOR.a *= smoothstep(0.0, 0.07, UV.x); }"
	var transition_material: ShaderMaterial = ShaderMaterial.new()
	transition_material.shader = transition_shader
	_expansion_backdrop.material = transition_material
	# Texture props at several depths leave the main walking lane readable.
	for i: int in range(29):
		var px: float = float(i) * 187.0 - 50.0
		var height: float = 205.0 + float(i % 4) * 24.0
		var index: int = 4 if px < 3300.0 else 6
		if px > 1600.0 and px < 3300.0 and i % 2 == 0:
			index = 5
		var prop: Sprite2D = _sprite(atlas("environment_atlas", index), Rect2(px, 690.0 - height, 165.0, height), -45)
		prop.modulate = Color(0.84, 0.94, 0.93, 0.68)
	for i: int in range(10):
		var px: float = 1750.0 + float(i) * 156.0
		_sprite(atlas("environment_atlas", 4 + i % 2), Rect2(px, 370, 175, 320), -28)
	# Architecture is image generated and shared by services and story NPCs.
	_sprite(atlas("environment_atlas", 2), Rect2(55, 468, 265, 222), -20)
	_sprite(atlas("environment_atlas", 0), Rect2(325, 378, 290, 312), -20)
	_sprite(atlas("environment_atlas", 1), Rect2(863, 439, 265, 251), -20)
	_sprite(atlas("environment_atlas", 2), Rect2(1640, 448, 230, 242), -20)
	_sprite(atlas("environment_atlas", 1), Rect2(2840, 466, 255, 224), -20)
	_sprite(atlas("environment_atlas", 3), Rect2(3950, 345, 350, 345), -20)
	_sprite(atlas("environment_atlas", 3), Rect2(4710, 421, 260, 269), -20)
	for i: int in range(3):
		_sprite(atlas("environment_atlas", 10), Rect2(2960.0 + float(i) * 122.0, 614, 125, 78), -5, true)
	_add_expansion_landmarks()
	# Opaque ground tiles cover the panoramic background's empty lower strip.
	var ground_texture: Texture2D = _ground_surface_texture()
	var columns: int = ceili(world_width / 200.0) + 1
	for i: int in range(columns):
		var ground: Sprite2D = _sprite(ground_texture, Rect2(float(i) * 200.0, 688, 202, 247), -8, true)
		ground.modulate = _region_tint(float(i) * 200.0)
	# Tall browser viewports reveal more below the playable surface. Repeat
	# only the generated tile's opaque soil/stone base, without grass rows.
	var subsoil_texture: Texture2D = _subsoil_texture()
	for row: int in range(7):
		for column: int in range(columns):
			var soil: Sprite2D = _sprite(subsoil_texture, Rect2(float(column) * 200.0, 935.0 + float(row) * 200.0, 202, 202), -9, true)
			soil.modulate = _region_tint(float(column) * 200.0)
	for platform: Rect2 in platforms:
		var plank: Sprite2D = _sprite(atlas("environment_atlas", 9), Rect2(platform.position - Vector2(0, 3), Vector2(platform.size.x, 34)), -2, true)
		plank.modulate = _region_tint(platform.position.x)
	for px: float in [90.0, 1680.0, 3380.0, 5310.0, 7110.0, 8910.0]:
		var portal: Sprite2D = _sprite(atlas("environment_atlas", 11), Rect2(px - 44, 520, 88, 170), -3)
		_portal_sprites.append(portal)
	for px: float in [730.0, 1580.0, 3300.0, 5080.0, 6970.0, 8760.0, 10920.0]:
		_sprite(atlas("environment_atlas", 7), Rect2(px - 53, 600, 106, 90), 0)
	for i: int in range(npcs.size()):
		var npc: Dictionary = npcs[i]
		var pos: Vector2 = npc["position"]
		var sprite: Sprite2D = _sprite(atlas(str(npc.get("sheet", "npc_atlas")), int(npc.get("icon", i % 8))), Rect2(pos - Vector2(51, 125), Vector2(102, 125)), 2)
		npc_sprites[str(npc["id"])] = sprite
		var marker: Sprite2D = _sprite(atlas("items_atlas", 15), Rect2(pos - Vector2(13, 197), Vector2(26, 30)), 4)
		quest_markers[str(npc["id"])] = marker
	for item: Dictionary in pickups:
		var pos: Vector2 = item["position"]
		var sprite: Sprite2D = _sprite(atlas(str(item.get("sheet", "items_atlas")), int(item.get("icon", 0))), Rect2(pos - Vector2(30, 30), Vector2(60, 60)), 3)
		pickup_sprites[str(item["id"])] = sprite
	# The shopkeeper's stock and inn supply are generated props, too.
	_sprite(atlas("items_atlas", 13), Rect2(614, 623, 73, 67), 1)
	_sprite(atlas("items_atlas", 8), Rect2(184, 612, 38, 62), 1)
	for px: float in [5900.0, 8150.0, 10000.0]:
		_sprite(atlas("items_atlas", 8), Rect2(px - 19, 612, 38, 62), 1)


func _add_expansion_landmarks() -> void:
	# Each destination uses its own generated architecture and silhouette.
	_sprite(atlas("expansion_environment", 1), Rect2(5360, 385, 400, 305), -22)
	_sprite(atlas("expansion_environment", 0), Rect2(5770, 440, 260, 250), -22)
	story_landmarks["harbor"] = _sprite(atlas("expansion_environment", 2), Rect2(6110, 265, 255, 425), -35)
	_sprite(atlas("expansion_environment", 0), Rect2(6350, 385, 355, 305), -22)
	_sprite(atlas("expansion_environment", 1), Rect2(6740, 492, 250, 198), -35)
	for i: int in range(12):
		var px: float = 7040.0 + float(i) * 148.0
		var height: float = 215.0 + float(i % 3) * 42.0
		var tree: Sprite2D = _sprite(atlas("expansion_environment", 4), Rect2(px, 690 - height, 168, height), -40)
		tree.modulate = Color(0.85, 0.94, 1.0, 0.84)
	_sprite(atlas("expansion_environment", 3), Rect2(7235, 435, 310, 255), -22)
	_sprite(atlas("expansion_environment", 5), Rect2(7770, 466, 212, 224), -22)
	_sprite(atlas("expansion_environment", 3), Rect2(8010, 475, 280, 215), -22)
	story_landmarks["snow"] = _sprite(atlas("expansion_environment", 5), Rect2(8330, 400, 240, 290), -22)
	_sprite(atlas("expansion_environment", 6), Rect2(8880, 330, 420, 360), -28)
	_sprite(atlas("expansion_environment", 5), Rect2(9440, 467, 190, 223), -30)
	_sprite(atlas("expansion_environment", 6), Rect2(9570, 386, 350, 304), -28)
	_sprite(atlas("expansion_environment", 3), Rect2(9860, 488, 250, 202), -22)
	story_landmarks["citadel"] = _sprite(atlas("expansion_environment", 7), Rect2(10330, 315, 390, 375), -22)
	_sprite(atlas("expansion_environment", 6), Rect2(10790, 435, 280, 255), -35)
	for px: float in [5240.0, 6880.0, 8840.0, 9350.0, 10110.0, 10880.0]:
		_sprite(atlas("environment_atlas", 6), Rect2(px, 537, 128, 153), -32)
	update_story({})


func update_story(completed_quests: Dictionary) -> void:
	# These colors are derived from the journal, never saved independently.
	# Loading an earlier chapter therefore also restores its dormant landmark.
	for region: String in story_landmarks:
		var restored_light: bool = true
		for quest_id: String in STORY_QUESTS[region]:
			if not completed_quests.has(quest_id):
				restored_light = false
				break
		var landmark: Sprite2D = story_landmarks[region]
		landmark.modulate = Color.WHITE if restored_light else DORMANT_STORY_COLOR


func _region_tint(x_position: float) -> Color:
	if x_position >= 8800.0:
		return Color(0.91, 0.87, 1.0)
	if x_position >= 7000.0:
		return Color(0.80, 0.93, 1.0)
	if x_position >= 5200.0:
		return Color(0.91, 0.97, 1.0)
	return Color.WHITE


func add_enemy(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy["position"]
	var sprite: Sprite2D = _sprite(atlas("items_atlas", int(enemy["texture"])), Rect2(pos - Vector2(37, 70), Vector2(74, 70)), 3)
	enemy_sprites[str(enemy["id"])] = sprite


func update_backdrop(player_x: float, clock: float) -> void:
	if is_instance_valid(_backdrop):
		_backdrop.position.x = -700.0 + player_x * 0.018
	if is_instance_valid(_expansion_backdrop):
		_expansion_backdrop.position.x = 4950.0 + player_x * 0.018
	for i: int in range(_portal_sprites.size()):
		_portal_sprites[i].modulate = Color(1.0, 1.0, 1.0, 0.90 + sin(clock * 1.5 + float(i)) * 0.10)


func update_npc(npc: Dictionary, state: String, clock: float) -> void:
	var sprite: Sprite2D = npc_sprites.get(str(npc["id"]))
	var marker: Sprite2D = quest_markers.get(str(npc["id"]))
	var pos: Vector2 = npc["position"]
	var bob: float = sin(clock * 1.8 + pos.x) * 1.5
	if sprite != null:
		sprite.position.y = float(sprite.get_meta("rest_y")) + bob
	if marker != null:
		marker.visible = state != "completed"
		marker.position.y = float(marker.get_meta("rest_y")) + sin(clock * 2.3) * 4.0
		marker.modulate = Color("a2d6ca") if state == "active" else Color.WHITE
		if state == "ready":
			marker.modulate = Color("fff194")


func update_pickup(item: Dictionary, collected: bool, active: bool, clock: float) -> void:
	var sprite: Sprite2D = pickup_sprites.get(str(item["id"]))
	if sprite == null:
		return
	sprite.visible = not collected
	sprite.position.y = float(sprite.get_meta("rest_y")) + sin(clock * 2.4 + Vector2(item["position"]).x) * 4.0
	sprite.modulate = Color.WHITE if active else Color(0.84, 0.88, 0.90, 0.72)


func update_enemy(enemy: Dictionary, clock: float) -> void:
	var sprite: Sprite2D = enemy_sprites.get(str(enemy["id"]))
	if sprite == null:
		return
	sprite.visible = int(enemy["hp"]) > 0
	var size: Vector2 = Vector2(sprite.get_meta("size", Vector2(74, 70)))
	var pos: Vector2 = enemy["position"]
	sprite.position = pos - Vector2(size.x * 0.5, size.y) + Vector2(0, -absf(sin(clock * 3.8 + pos.x)) * 3.0)
	sprite.flip_h = float(enemy.get("direction", 1.0)) < 0.0
	sprite.modulate = Color("fff1bc") if float(enemy.get("flash", 0.0)) > 0.0 else Color.WHITE


func add_effect(position_in_world: Vector2, kind: String = "hit") -> void:
	var index: int = 14 if kind == "hit" else 9
	var size: float = 70.0 if kind == "hit" else 32.0
	var sprite: Sprite2D = _sprite(atlas("items_atlas", index), Rect2(position_in_world - Vector2.ONE * size * 0.5, Vector2.ONE * size), 10)
	_effects.append({"sprite": sprite, "age": 0.0, "start": sprite.position, "kind": kind})


func advance_effects(delta: float) -> void:
	for i: int in range(_effects.size() - 1, -1, -1):
		var effect: Dictionary = _effects[i]
		effect["age"] = float(effect["age"]) + delta
		var sprite: Sprite2D = effect["sprite"]
		var age: float = float(effect["age"])
		sprite.position = Vector2(effect["start"]) + Vector2(0, -age * 35.0)
		sprite.modulate.a = maxf(0.0, 1.0 - age / 0.7)
		if age > 0.7:
			sprite.queue_free()
			_effects.remove_at(i)


func atlas(name: String, index: int) -> Texture2D:
	var key: String = "%s:%d" % [name, index]
	if _atlas_textures.has(key):
		return _atlas_textures[key]
	var texture: Texture2D = _texture(name)
	if texture == null:
		return null
	var layout: Vector2i = ATLAS_LAYOUTS[name]
	var cell: Vector2i = Vector2i(texture.get_size()) / layout
	var region: Rect2i = Rect2i(Vector2i(index % layout.x, index / layout.x) * cell, cell)
	if name == "environment_atlas":
		# Measured gutters in the final imagegen sheet preserve complete houses,
		# trees and platforms while keeping adjacent rows out of each sprite.
		var row: int = floori(float(index) / 4.0)
		var boundaries: Array[float] = [0.0, 397.0 / 1086.0, 749.0 / 1086.0, 1.0]
		var top: int = roundi(boundaries[row] * texture.get_height())
		var bottom: int = roundi(boundaries[row + 1] * texture.get_height())
		if index >= 8 and index <= 10:
			# These short bottom-row props begin below the taller portal; exclude
			# faint tree-base shadows spilling from the preceding row.
			top = maxi(top, roundi(float(texture.get_height()) * 0.75))
		region = Rect2i(region.position.x, top, cell.x, bottom - top)
		if index == 9:
			# The neighboring ground tile reaches a few pixels into this cell.
			var gutter: int = roundi(float(cell.x) * 0.07)
			region.position.x += gutter
			region.size.x -= gutter
	var source_image: Image = texture.get_image()
	if source_image != null:
		if source_image.is_compressed():
			source_image.decompress()
		var used: Rect2i = source_image.get_region(region).get_used_rect()
		if used.has_area():
			region = Rect2i(region.position + used.position, used.size)
	var result: AtlasTexture = AtlasTexture.new()
	result.atlas = texture
	result.region = Rect2(region)
	result.filter_clip = true
	_atlas_textures[key] = result
	return result


func _ground_surface_texture() -> Texture2D:
	var source: AtlasTexture = atlas("environment_atlas", 8) as AtlasTexture
	if source == null:
		return null
	# Crop decorative grass tips above the solid ledge; the visible walking
	# surface then aligns with the physical collider at y=690.
	var region: Rect2 = source.region
	var tip_height: float = floorf(region.size.y * 0.31)
	region.position.y += tip_height
	region.size.y -= tip_height
	var result: AtlasTexture = AtlasTexture.new()
	result.atlas = source.atlas
	result.region = region
	result.filter_clip = true
	return result


func _subsoil_texture() -> Texture2D:
	var source: AtlasTexture = atlas("environment_atlas", 8) as AtlasTexture
	if source == null:
		return null
	var region: Rect2 = source.region
	var soil_height: float = floorf(region.size.y * 0.43)
	region.position.y = region.end.y - soil_height
	region.size.y = soil_height
	var result: AtlasTexture = AtlasTexture.new()
	result.atlas = source.atlas
	result.region = region
	result.filter_clip = true
	return result


func _texture(asset_name: String) -> Texture2D:
	if _textures.has(asset_name):
		return _textures[asset_name]
	var path: String = ROOT + asset_name + ".png"
	var texture: Texture2D
	if ResourceLoader.exists(path):
		texture = load(path)
	elif FileAccess.file_exists(path):
		var source: Image = Image.load_from_file(path)
		if source == null or source.is_empty():
			return null
		texture = ImageTexture.create_from_image(source)
	else:
		return null
	_textures[asset_name] = texture
	return texture


func _sprite(texture: Texture2D, rect: Rect2, depth: int, stretch: bool = false) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.z_index = depth
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var size: Vector2 = rect.size
	if texture != null:
		if stretch:
			sprite.scale = rect.size / texture.get_size()
		else:
			var factor: float = minf(rect.size.x / texture.get_width(), rect.size.y / texture.get_height())
			sprite.scale = Vector2.ONE * factor
			size = texture.get_size() * factor
	sprite.position = rect.position + Vector2((rect.size.x - size.x) * 0.5, rect.size.y - size.y)
	sprite.set_meta("rest_y", sprite.position.y)
	sprite.set_meta("size", size)
	add_child(sprite)
	return sprite
