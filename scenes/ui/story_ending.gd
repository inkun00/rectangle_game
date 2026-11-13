class_name StoryEnding
extends Control

signal home_requested

const DURATION: float = 17.0
const PLANET_PATH: String = "res://assets/generated/opening-v1/planet.webp"
const PNG_SIZE: Vector2i = Vector2i(960, 600)

const EARTH_BEATS: Array[String] = [
	"지구에 처음 도착했을 때는 돌아갈 방법만 찾았어요.",
	"함께 심부름을 하고 집을 지으면서 이 마을에 친구들이 생겼어요.",
	"완성한 집에 불을 밝혔어요. 이제 이곳에서 마을 사람들과 함께 살 거예요."
]
const SPACE_BEATS: Array[String] = [
	"마을 사람들과 함께 모은 돈으로 나만의 우주선을 완성했어요.",
	"친구들의 인사를 뒤로하고, 내가 만든 우주선을 타고 별들 사이로 올라갔어요.",
	"드디어 사각성에 도착했어요. 지구에서 만난 친구들을 오래 기억할 거예요."
]

var branch: String = ""
var artwork_title: String = ""
var elapsed: float = 0.0
var paused: bool = false
var finished: bool = false
var _artwork: Texture2D
var _post_url: String = ""
var _hero: Dictionary = {}
var _ship_performance: int = 12
var _stage: EndingStage
var _chapter: Label
var _subtitle: Label
var _progress: ProgressBar
var _pause_button: Button
var _skip_button: Button
var _replay_button: Button
var _padlet_button: Button
var _home_button: Button


func configure(ending_branch: String, png: PackedByteArray, title: String = "", post_url: String = "", protagonist: Dictionary = {}, ship_performance: int = 12) -> bool:
	if is_inside_tree() or ending_branch not in ["earth", "space"] or not _valid_png_header(png): return false
	var image: Image = Image.new()
	if image.load_png_from_buffer(png) != OK or image.get_size() != PNG_SIZE: return false
	# The saved PNG retains its padding. Crop only the display texture to its
	# visible pixels so the player's house or ship can fill the camera shot.
	var visible_bounds: Rect2i = image.get_used_rect()
	if not visible_bounds.has_area(): return false
	_artwork = ImageTexture.create_from_image(image.get_region(visible_bounds))
	branch = ending_branch
	artwork_title = title.strip_edges()
	_hero = protagonist.duplicate(true) if not protagonist.is_empty() else CharacterTemplates.protagonist()
	_ship_performance = clampi(ship_performance, 12, 36)
	set_post_url(post_url)
	return true


func _ready() -> void:
	name = "StoryEnding"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background: ColorRect = ColorRect.new()
	background.color = Color("0b1624")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margins: MarginContainer = MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 14)
	add_child(margins)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margins.add_child(column)
	_chapter = QuadTheme.label("", 22, StarfrontArt.AMBER)
	column.add_child(_chapter)
	_stage = EndingStage.new()
	_stage.name = "EndingStage"
	_stage.branch = branch
	_stage.artwork = _artwork
	_stage.ship_power = float(_ship_performance - 12) / 24.0
	_stage.configure_hero(_hero)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size.y = 180.0
	column.add_child(_stage)
	var subtitle_panel: PanelContainer = PanelContainer.new()
	subtitle_panel.add_theme_stylebox_override("panel", StarfrontArt.panel(0, 10))
	column.add_child(subtitle_panel)
	_subtitle = QuadTheme.paragraph("", 20, QuadTheme.INK)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.custom_minimum_size.y = 54.0
	subtitle_panel.add_child(_subtitle)
	_progress = ProgressBar.new()
	_progress.name = "EndingProgress"
	_progress.max_value = DURATION
	_progress.step = 0.0
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 5.0
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.add_theme_stylebox_override("background", _flat(Color("243b50")))
	_progress.add_theme_stylebox_override("fill", _flat(QuadTheme.TEAL))
	column.add_child(_progress)
	var actions: HFlowContainer = HFlowContainer.new()
	actions.alignment = FlowContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	column.add_child(actions)
	_pause_button = QuadTheme.button("일시정지", toggle_pause)
	_pause_button.name = "PauseEnding"
	actions.add_child(_pause_button)
	_skip_button = QuadTheme.button("마지막 장면으로 · Esc", finish)
	_skip_button.name = "SkipEnding"
	actions.add_child(_skip_button)
	_replay_button = QuadTheme.button("엔딩 다시 보기", replay)
	_replay_button.name = "ReplayEnding"
	actions.add_child(_replay_button)
	_padlet_button = QuadTheme.button("패들릿 작품 보기", _open_post)
	_padlet_button.name = "OpenEndingPadlet"
	actions.add_child(_padlet_button)
	_home_button = QuadTheme.button("메인으로 돌아가기", func() -> void: home_requested.emit(), true)
	_home_button.name = "LeaveEnding"
	actions.add_child(_home_button)
	replay()


func set_post_url(post_url: String) -> void:
	_post_url = post_url if ArtPublicationStore._valid_post_url(post_url) else ""
	if is_instance_valid(_padlet_button): _padlet_button.visible = finished and not _post_url.is_empty()


func _open_post() -> void:
	if not _post_url.is_empty(): OS.shell_open(_post_url)


func replay() -> void:
	if not is_instance_valid(_stage): return
	elapsed = 0.0
	paused = false
	finished = false
	_pause_button.text = "일시정지"
	_pause_button.show()
	_skip_button.show()
	_replay_button.hide()
	_padlet_button.hide()
	_home_button.hide()
	_progress.show()
	_refresh()
	_pause_button.grab_focus()
	set_process(true)


func toggle_pause() -> void:
	if finished: return
	paused = not paused
	_pause_button.text = "계속 보기" if paused else "일시정지"
	set_process(not paused)


func finish() -> void:
	if finished or not is_instance_valid(_stage): return
	elapsed = DURATION
	paused = false
	finished = true
	set_process(false)
	_pause_button.hide()
	_skip_button.hide()
	_replay_button.show()
	_padlet_button.visible = not _post_url.is_empty()
	_home_button.show()
	_progress.hide()
	_refresh()
	_home_button.grab_focus()


func _process(delta: float) -> void:
	elapsed = minf(DURATION, elapsed + delta)
	if elapsed >= DURATION:
		finish()
		return
	_refresh()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_action_pressed("ui_cancel"): return
	get_viewport().set_input_as_handled()
	if finished: home_requested.emit()
	else: finish()


func _refresh() -> void:
	_stage.elapsed = elapsed
	_stage.queue_redraw()
	_progress.value = elapsed
	var earth: bool = branch == "earth"
	var beat: int = 0 if elapsed < 4.5 else (1 if elapsed < 10.8 else 2)
	var caption: String = (EARTH_BEATS if earth else SPACE_BEATS)[beat]
	if beat == 2 and not artwork_title.is_empty(): caption += "\n「%s」" % artwork_title
	if finished and not earth: caption += " · 비행 성능 %d" % _ship_performance
	_subtitle.text = caption
	_chapter.text = "지구에 남기로 했어요" if earth else "사각성에 돌아왔어요"
	if not finished: _chapter.text = "마을의 새 이웃" if earth else "사각성으로"


static func _flat(color: Color) -> StyleBoxFlat:
	var result: StyleBoxFlat = StyleBoxFlat.new()
	result.bg_color = color
	return result


static func _valid_png_header(png: PackedByteArray) -> bool:
	if png.size() < 33 or png.size() > 2400000: return false
	if png.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]): return false
	if png.slice(12, 16).get_string_from_ascii() != "IHDR": return false
	# PNG dimensions are big-endian. Reject a different size before decoding.
	return png.slice(16, 24) == PackedByteArray([0, 0, 3, 192, 0, 0, 2, 88])


class EndingStage extends Control:
	var branch: String = ""
	var elapsed: float = 0.0
	var artwork: Texture2D
	var ship_power: float = 0.0
	var _village: Texture2D
	var _planet: Texture2D
	var _neighbors: Array[Texture2D] = []
	var _hero_parts: Array[Dictionary] = []
	var _hero_bounds: Rect2 = Rect2()


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		resized.connect(queue_redraw)
		_village = StarfrontArt.scene(0)
		_neighbors.assign([GameArt.npc(0), GameArt.npc(1), GameArt.npc(3)])
		if branch == "space" and ResourceLoader.exists(PLANET_PATH):
			_planet = load(PLANET_PATH) as Texture2D


	func configure_hero(data: Dictionary) -> void:
		var first: bool = true
		var head: Rect2 = Rect2()
		for item: Dictionary in data.get("parts", []):
			var vertices: PackedVector2Array = item.vertices
			var points: PackedVector2Array = PackedVector2Array()
			for vertex: Vector2 in vertices:
				var point: Vector2 = vertex + Vector2(item.position)
				points.append(point)
				_hero_bounds = Rect2(point, Vector2.ZERO) if first else _hero_bounds.expand(point)
				first = false
				if str(item.id) == "head": head = Rect2(point, Vector2.ZERO) if points.size() == 1 else head.expand(point)
			_hero_parts.append({"points": points, "color": Color(item.color)})
		if head.has_area() and data.get("template_id") == "robot":
			var face: Color = Color("213a49")
			for x: float in [0.29, 0.62]:
				_add_hero_feature(Rect2(head.position + head.size * Vector2(x, 0.40), head.size * Vector2(0.09, 0.12)), face)
			_add_hero_feature(Rect2(head.position + head.size * Vector2(0.44, 0.65), head.size * Vector2(0.19, 0.055)), face)


	func _add_hero_feature(rect: Rect2, tint: Color) -> void:
		var points: PackedVector2Array = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		_hero_parts.append({"points": points, "color": tint})


	func _draw() -> void:
		if size.x <= 1.0 or size.y <= 1.0: return
		if branch == "space": _draw_space()
		else: _draw_earth()


	func _draw_earth() -> void:
		var camera: float = smoothstep(0.0, 9.0, elapsed)
		_draw_village(camera, Color("b2b9c8"))
		var ground: float = size.y * 0.80
		_draw_ground(ground, Color("285149"), Color("a08855"))
		var house_size: Vector2 = _fitted(artwork, Vector2(size.x * lerpf(0.50, 0.59, camera), size.y * lerpf(0.58, 0.72, camera)))
		var house_center: Vector2 = Vector2(size.x * lerpf(0.62, 0.56, camera), ground - house_size.y * 0.5)
		_draw_artwork(house_center, house_size, 0.0)
		var walk: float = smoothstep(0.2, 6.7, elapsed)
		var step: float = 1.0 - smoothstep(5.8, 7.0, elapsed)
		_draw_hero(Vector2(size.x * lerpf(0.06, 0.31, walk), ground - absf(sin(elapsed * 11.0)) * 4.0 * step), size.y * 0.25)
		_draw_neighbor(0, Vector2(size.x * lerpf(0.11, 0.20, walk), ground + 9.0), size.y * 0.18, false)
		_draw_neighbor(1, Vector2(size.x * lerpf(0.97, 0.82, walk), ground + 4.0), size.y * 0.20, true)
		_draw_neighbor(2, Vector2(size.x * lerpf(1.05, 0.92, walk), ground + 13.0), size.y * 0.17, true)
		_draw_lantern(Vector2(size.x * 0.12, ground), 0.0)
		_draw_lantern(Vector2(size.x * 0.73, ground), 1.4)
		_draw_sparks(0.78, Color("ffde9b"))


	func _draw_space() -> void:
		var lift: float = smoothstep(2.0, lerpf(7.2, 6.1, ship_power), elapsed)
		var sky: float = smoothstep(3.6, 7.0, elapsed)
		var arrival: float = smoothstep(10.2, 16.0, elapsed)
		if sky < 1.0:
			_draw_village(lift, Color("9faac8"))
			var ground: float = size.y * (0.81 + lift * 0.55)
			_draw_ground(ground, Color("284151"), Color("9caebe"))
			if elapsed < 3.6:
				_draw_hero(Vector2(size.x * lerpf(0.21, 0.40, smoothstep(0.2, 3.1, elapsed)), ground - absf(sin(elapsed * 10.0)) * 4.0), size.y * 0.20)
				_draw_neighbor(0, Vector2(size.x * 0.16, ground), size.y * 0.18, false)
				_draw_neighbor(1, Vector2(size.x * 0.10, ground + 9.0), size.y * 0.16, false)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.061, 0.13, sky))
		_draw_stars(sky, lift * (1.0 - arrival) * lerpf(1.0, 1.5, ship_power))
		if arrival > 0.01: _draw_planet(arrival)
		var ship_size: Vector2 = _fitted(artwork, Vector2(size.x * lerpf(0.48, 0.44, arrival), size.y * lerpf(0.64, 0.55, arrival)))
		var climb: float = sin(lift * PI) * 0.20
		var center: Vector2 = size * Vector2(lerpf(0.54, 0.31, arrival), lerpf(0.81 - ship_size.y / maxf(1.0, size.y) * 0.5, 0.47, lift) - climb)
		var angle: float = arrival * 0.34 + sky * sin(elapsed * 0.7) * (1.0 - arrival) * 0.10
		if elapsed > 2.1 and arrival < 0.99: _draw_exhaust(center, ship_size, angle, (1.0 - arrival) * smoothstep(2.1, 3.0, elapsed))
		_draw_artwork(center, ship_size, angle)


	func _draw_village(camera: float, tint: Color) -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("122742"))
		if _village == null: return
		var source: Vector2 = _village.get_size()
		var factor: float = maxf(size.x / source.x, size.y / source.y) * lerpf(1.0, 1.10, camera)
		var extent: Vector2 = source * factor
		var position: Vector2 = (size - extent) * Vector2(lerpf(0.22, 0.63, camera), 0.60)
		draw_texture_rect(_village, Rect2(position, extent), false, tint)


	func _draw_ground(y: float, base: Color, edge: Color) -> void:
		draw_rect(Rect2(0.0, y, size.x, maxf(0.0, size.y - y)), base)
		draw_rect(Rect2(0.0, y, size.x, 6.0), edge)
		for column: int in range(16):
			var width: float = size.x / 16.0
			draw_rect(Rect2(float(column) * width, y + 14.0, width - 2.0, 10.0), base.lightened(0.10 if column % 2 == 0 else 0.04))


	func _draw_artwork(center: Vector2, extent: Vector2, angle: float) -> void:
		if artwork == null: return
		draw_set_transform(center, angle)
		draw_texture_rect(artwork, Rect2(-extent * 0.5, extent), false)
		draw_set_transform(Vector2.ZERO)


	func _draw_hero(feet: Vector2, height: float) -> void:
		if not _hero_bounds.has_area(): return
		var origin: Vector2 = Vector2(_hero_bounds.get_center().x, _hero_bounds.end.y)
		var factor: float = height / _hero_bounds.size.y
		for item: Dictionary in _hero_parts:
			var points: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in item.points: points.append(feet + (point - origin) * factor)
			var tint: Color = item.color
			draw_colored_polygon(points, tint)
			points.append(points[0])
			draw_polyline(points, tint.darkened(0.32), 1.2, true)


	func _draw_neighbor(index: int, feet: Vector2, height: float, face_left: bool) -> void:
		var sprite: Texture2D = _neighbors[index]
		var extent: Vector2 = Vector2(sprite.get_width() * height / float(sprite.get_height()), height)
		var bob: float = sin(elapsed * 4.2 + float(index)) * (1.0 - smoothstep(12.0, 17.0, elapsed)) * 3.0
		draw_set_transform(feet + Vector2(0.0, bob), 0.0, Vector2(-1.0 if face_left else 1.0, 1.0))
		draw_texture_rect(sprite, Rect2(Vector2(-extent.x * 0.5, -extent.y), extent), false)
		draw_set_transform(Vector2.ZERO)


	func _draw_lantern(feet: Vector2, phase: float) -> void:
		var top: Vector2 = feet - Vector2(0.0, size.y * 0.16)
		draw_rect(Rect2(top, Vector2(5.0, feet.y - top.y)), Color("624637"))
		var glow: float = 0.20 + sin(elapsed * 5.0 + phase) * 0.07
		for width: float in [38.0, 27.0, 17.0]:
			draw_rect(Rect2(top - Vector2.ONE * width * 0.5, Vector2.ONE * width), Color(1.0, 0.65, 0.23, glow * 0.48))
		draw_rect(Rect2(top - Vector2(5.0, 7.0), Vector2(15.0, 13.0)), Color("ffd27a"))


	func _draw_stars(opacity: float, speed: float) -> void:
		for index: int in range(88):
			var seed_value: float = float(index)
			var offset: float = elapsed * speed * (0.08 + float(index % 4) * 0.035)
			var point: Vector2 = size * Vector2(fposmod(seed_value * 0.618, 1.0), fposmod(seed_value * 0.347 + offset, 1.0))
			var brightness: float = (0.34 + 0.23 * sin(elapsed * 2.2 + seed_value)) * opacity
			draw_rect(Rect2(point, Vector2(2.0 + float(index % 2), 2.0 + 12.0 * speed)), Color(0.68, 0.92, 1.0, brightness))


	func _draw_planet(arrival: float) -> void:
		var extent: float = minf(size.x * 0.48, size.y * 0.94) * lerpf(0.12, 1.0, arrival)
		var center: Vector2 = size * Vector2(0.74, 0.46)
		if _planet != null:
			draw_texture_rect(_planet, Rect2(center - Vector2.ONE * extent * 0.5, Vector2.ONE * extent), false, Color(1.0, 1.0, 1.0, arrival))
			return
		var face: Rect2 = Rect2(center - Vector2.ONE * extent * 0.31, Vector2.ONE * extent * 0.62)
		draw_rect(face, Color(0.23, 0.64, 0.59, arrival))
		draw_rect(Rect2(face.position + face.size * 0.1, face.size * 0.55), Color(0.49, 0.83, 0.66, arrival))


	func _draw_exhaust(center: Vector2, extent: Vector2, angle: float, intensity: float) -> void:
		var length: float = size.y * (lerpf(0.22, 0.35, ship_power) + sin(elapsed * 26.0) * 0.035) * intensity
		var spread: float = minf(extent.x * 0.20, 43.0)
		draw_set_transform(center, angle)
		var y: float = extent.y * 0.47
		var points: PackedVector2Array = PackedVector2Array([Vector2(-spread, y), Vector2(spread, y), Vector2(spread * 0.32, y + length), Vector2(-spread * 0.32, y + length)])
		draw_colored_polygon(points, Color(0.99, 0.50, 0.23, 0.85 * intensity))
		var core: Rect2 = Rect2(Vector2(-spread * 0.35, y), Vector2(spread * 0.70, length * 0.66))
		draw_rect(core, Color(1.0, 0.9, 0.60, intensity))
		draw_set_transform(Vector2.ZERO)


	func _draw_sparks(base_y: float, color: Color) -> void:
		for index: int in range(21):
			var seed_value: float = float(index)
			var phase: float = fposmod(seed_value * 0.31 + elapsed * 0.12, 1.0)
			var point: Vector2 = size * Vector2(fposmod(seed_value * 0.618, 0.93) + 0.03, base_y - phase * 0.40)
			var tint: Color = Color(color, sin(phase * PI) * 0.62)
			draw_rect(Rect2(point, Vector2.ONE * (2.0 + float(index % 2))), tint)


	static func _fitted(texture: Texture2D, maximum: Vector2) -> Vector2:
		if texture == null: return maximum
		var original: Vector2 = texture.get_size()
		return original * minf(maximum.x / original.x, maximum.y / original.y)
