class_name OpeningIntro
extends Control

signal closed(reason: String)
signal sound_changed(enabled: bool)

const VIDEO_PATH: String = "res://assets/video/quadrilateral-opening.ogv"
const Art: GDScript = preload("res://scripts/construction_art.gd")
enum PlaybackState { READY, PLAYING, PAUSED, CLOSED }

var video_path: String = VIDEO_PATH
var sound_enabled: bool = true
var playback_state: int = PlaybackState.READY
var _player: VideoStreamPlayer
var _poster: TextureRect
var _poster_dim: ColorRect
var _start_button: Button
var _pause_button: Button
var _sound_button: Button
var _skip_button: Button
var _gate: CenterContainer
var _time_label: Label
var _stalled_seconds: float = 0.0
var _last_position: float = -1.0


func _ready() -> void:
	name = "OpeningIntro"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background: ColorRect = ColorRect.new()
	background.color = Color("080f1a")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	column.add_child(QuadTheme.paragraph("사각형 월드 · 별빛 고향으로", 20, Color("e8f4ff")))
	var stage: Control = Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(stage)
	_poster = TextureRect.new()
	_poster.name = "OpeningPoster"
	_poster.texture = preload("res://assets/video/opening-poster.png")
	_poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_poster)
	_poster_dim = ColorRect.new()
	_poster_dim.color = Color(0.02, 0.04, 0.07, 0.46)
	_poster_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poster_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_poster_dim)
	var aspect: AspectRatioContainer = AspectRatioContainer.new()
	aspect.name = "OpeningAspect"
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(aspect)
	_player = VideoStreamPlayer.new()
	_player.name = "OpeningVideo"
	_player.expand = true
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.finished.connect(func(): finish("completed"))
	aspect.add_child(_player)
	_gate = CenterContainer.new()
	_gate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_gate)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	panel.add_theme_stylebox_override("panel", Art.gold_panel(24))
	_gate.add_child(panel)
	var story: VBoxContainer = VBoxContainer.new()
	story.add_theme_constant_override("separation", 16)
	panel.add_child(story)
	story.add_child(QuadTheme.paragraph("집으로 돌아가는 작은 도전", 26, Color.WHITE))
	story.add_child(QuadTheme.paragraph("지구에 불시착한 사각형 외계인!\n그림을 팔고, 집을 지어\n새 우주선을 만들 수 있을까요?", 20, Art.INK))
	_start_button = _button("이야기 시작", start_playback)
	_start_button.name = "StartOpening"
	story.add_child(_start_button)
	story.add_child(QuadTheme.paragraph("소리와 함께 감상할 수 있어요.", 15, Art.INK))
	var controls: HBoxContainer = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	column.add_child(controls)
	_pause_button = _button("일시정지", toggle_pause)
	_pause_button.name = "PauseOpening"
	_pause_button.disabled = true
	controls.add_child(_pause_button)
	_sound_button = _button("", toggle_sound)
	_sound_button.name = "OpeningSound"
	controls.add_child(_sound_button)
	_time_label = QuadTheme.paragraph("", 15, Color("becedd"))
	_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.add_child(_time_label)
	_skip_button = _button("건너뛰기 · Esc", func(): finish("skipped"))
	_skip_button.name = "SkipOpening"
	controls.add_child(_skip_button)
	_refresh_sound()
	_start_button.grab_focus()
	set_process(false)


func _button(text: String, action: Callable) -> Button:
	var button: Button = QuadTheme.button(text, action)
	button.custom_minimum_size = Vector2(0, 48)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	return button


func start_playback() -> void:
	if playback_state != PlaybackState.READY: return
	# Load only after the user's click: this also gives browsers an audio gesture.
	if not ResourceLoader.exists(video_path, "VideoStream"):
		finish("unavailable")
		return
	var stream: VideoStream = ResourceLoader.load(video_path, "VideoStream") as VideoStream
	if stream == null:
		finish("unavailable")
		return
	_player.stream = stream
	_player.paused = false
	playback_state = PlaybackState.PLAYING
	_poster.hide()
	_poster_dim.hide()
	_gate.hide()
	_pause_button.disabled = false
	_pause_button.grab_focus()
	_stalled_seconds = 0.0
	_last_position = -1.0
	_player.play()
	set_process(true)


func toggle_pause() -> void:
	if playback_state not in [PlaybackState.PLAYING, PlaybackState.PAUSED]: return
	var pause: bool = playback_state == PlaybackState.PLAYING
	_player.paused = pause
	playback_state = PlaybackState.PAUSED if pause else PlaybackState.PLAYING
	_pause_button.text = "계속 보기" if pause else "일시정지"
	_stalled_seconds = 0.0


func toggle_sound() -> void:
	if playback_state == PlaybackState.CLOSED: return
	sound_enabled = not sound_enabled
	_refresh_sound()
	sound_changed.emit(sound_enabled)


func _refresh_sound() -> void:
	_player.volume_db = 0.0 if sound_enabled else -80.0
	_sound_button.text = "소리 끄기" if sound_enabled else "소리 켜기"
	_sound_button.tooltip_text = "영상 소리를 켜거나 꺼요."


func handle_key(event: InputEvent) -> bool:
	if playback_state == PlaybackState.CLOSED: return false
	if not event is InputEventKey or not event.pressed or event.echo: return false
	if event.keycode == KEY_ESCAPE:
		finish("skipped")
		return true
	if event.keycode == KEY_SPACE:
		if playback_state == PlaybackState.READY: start_playback()
		else: toggle_pause()
		return true
	return false


func _process(delta: float) -> void:
	if playback_state != PlaybackState.PLAYING: return
	var position_seconds: float = _player.stream_position
	var length_seconds: float = _player.get_stream_length()
	_time_label.text = "%s / %s" % [_clock(position_seconds), _clock(length_seconds)] if length_seconds > 0.0 else _clock(position_seconds)
	if position_seconds > _last_position + 0.01:
		_stalled_seconds = 0.0
		_last_position = position_seconds
	else:
		_stalled_seconds += delta
	# A missing/undecodable stream must never trap the player on a black screen.
	if _stalled_seconds >= 8.0: finish("unavailable")


static func _clock(seconds: float) -> String:
	var whole: int = maxi(0, int(seconds))
	return "%d:%02d" % [int(float(whole) / 60.0), whole % 60]


func finish(reason: String) -> void:
	if playback_state == PlaybackState.CLOSED: return
	dismiss()
	closed.emit(reason)


func dismiss() -> void:
	playback_state = PlaybackState.CLOSED
	set_process(false)
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null
	hide()


func _exit_tree() -> void:
	if is_instance_valid(_player): _player.stop()
