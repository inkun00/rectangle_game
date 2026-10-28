class_name QuadrilateralApp
extends Node

const SHAPES: Array[String] = ["trapezoid", "parallelogram", "rhombus", "rectangle", "square"]
const SHAPE_NOTES: Dictionary = {
	"trapezoid": "평행한 변이 있는 사각형이에요.\n두 쌍이 평행해도 사다리꼴이에요.",
	"parallelogram": "마주 보는 두 쌍의 변이 평행해요.\n마주 보는 변의 길이와 각이 같아요.",
	"rhombus": "네 변의 길이가 모두 같아요.\n마주 보는 두 쌍의 변은 평행해요.",
	"rectangle": "네 각이 모두 직각(90°)이에요.\n마주 보는 변의 길이가 같아요.",
	"square": "네 변의 길이가 모두 같고,\n네 각이 모두 직각(90°)이에요."
}

var document: CharacterDocument
var testing: bool = false
var journal: QuestJournal
var adventure: AdventureState
var workshop: CharacterWorkshop
var world: QuadrilateralWorld
var _sound: SoundManager
var _ui: Control
var _home_screen: HomePage
var _drawing_screen: DrawingStudio
var _construction_screen: ConstructionStudio
var _workshop_screen: Control
var _world_hud: Control
var _modal_overlay: Control
var _modal_body: VBoxContainer
var _toast: Label
var _toast_timer: Timer
var _autosave: Timer
var _preview: CharacterPreview
var _progress: Label
var _progress_bar: ProgressBar
var _shape_note: Label
var _inspector: Label
var _inspector_panel: Control
var _start_button: Button
var _undo_button: Button
var _redo_button: Button
var _world_stats: Label
var _world_region: Label
var _active_quests: Label
var _health_label: Label
var _level_label: Label
var _health_bar: ProgressBar
var _xp_bar: ProgressBar
var _potion_button: Button
var _pickup_button: Button
var _guidance: Label
var _story_label: Label
var _tracked_quest: String = ""
var _guidance_clock: float = 0.0
var _shape_buttons: Dictionary = {}
var _template_buttons: Dictionary = {}
var _swatches: Array[Button] = []
var _world_data: Dictionary = {}
var _in_world: bool = false
var _restoring: bool = false
var _exporting: bool = false
var _save_clock: float = 0.0

func _ready() -> void:
	document = CharacterDocument.new()
	journal = QuestJournal.new()
	adventure = AdventureState.new()
	_sound = SoundManager.new()
	add_child(_sound)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = Theme.new()
	_ui.theme.default_font = QuadTheme.FONT
	layer.add_child(_ui)
	_build_workshop()
	_build_home()
	_build_drawing()
	_build_construction()
	_build_world_hud()
	_build_toast()
	_autosave = Timer.new()
	_autosave.one_shot = true
	_autosave.wait_time = 0.7
	_autosave.timeout.connect(func(): _save(false))
	add_child(_autosave)
	document.changed.connect(_document_changed)
	journal.changed.connect(_journal_changed)
	adventure.changed.connect(_adventure_changed)
	get_viewport().size_changed.connect(_responsive)
	if not testing: _load(false)
	_document_changed()
	_journal_changed()
	_adventure_changed()
	_responsive()
	_show_home()
	# Rendering smoke tests use command-line flags, never bypass player-facing validation.
	if "--quad-preview-world" in OS.get_cmdline_user_args():
		document.fill_example()
		_enter_world()
	elif "--quad-preview-drawing" in OS.get_cmdline_user_args():
		_show_drawing()
	elif "--quad-preview-construction" in OS.get_cmdline_user_args():
		_show_construction()

func _build_home() -> void:
	_home_screen = HomePage.new()
	_home_screen.drawing_requested.connect(_show_drawing)
	_home_screen.adventure_requested.connect(_show_workshop)
	_home_screen.construction_requested.connect(_show_construction)
	_home_screen.notebook_requested.connect(_show_notebook)
	_ui.add_child(_home_screen)

func _build_drawing() -> void:
	_drawing_screen = DrawingStudio.new()
	_drawing_screen.testing = testing
	_drawing_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawing_screen.home_requested.connect(_show_home)
	_drawing_screen.hide()
	_ui.add_child(_drawing_screen)

func _build_construction() -> void:
	_construction_screen = ConstructionStudio.new()
	_construction_screen.testing = testing
	_construction_screen.home_requested.connect(_show_home)
	_construction_screen.hide()
	_ui.add_child(_construction_screen)

func _leave_activity() -> void:
	_close_modal()
	var save_adventure: bool = _in_world or _workshop_screen.visible
	if _drawing_screen.visible:
		_drawing_screen.cancel_gesture()
		if not testing: _drawing_screen.save_drawing(false)
	if _construction_screen.visible:
		_construction_screen.cancel_activity()
	workshop.cancel_gesture()
	if world != null:
		_world_data = world.serialize()
		world.set_controls_enabled(false)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		world.hide()
		world.camera.enabled = false
	_in_world = false
	_home_screen.hide()
	_drawing_screen.hide()
	_construction_screen.hide()
	_workshop_screen.hide()
	_world_hud.hide()
	if _toast != null: _toast.hide()
	if save_adventure: _save(false)

func _show_home() -> void:
	_leave_activity()
	_home_screen.show()
	_responsive()

func _show_drawing() -> void:
	_leave_activity()
	_drawing_screen.show()
	_responsive()

func _show_construction() -> void:
	_leave_activity()
	_construction_screen.show()
	_responsive()

func _show_workshop() -> void:
	_leave_activity()
	_workshop_screen.show()
	_responsive()

func _process(delta: float) -> void:
	if _in_world:
		_guidance_clock += delta
		if _guidance_clock >= 0.15:
			_guidance_clock = 0.0
			_refresh_world_guidance()
		_save_clock += delta
		if _save_clock > 10.0:
			_save_clock = 0.0
			_save(false)

func _build_workshop() -> void:
	_workshop_screen = Control.new()
	_workshop_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_workshop_screen)
	var bg: TextureRect = TextureRect.new()
	bg.texture = GameArt.panel_texture(0)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_workshop_screen.add_child(bg)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	_workshop_screen.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var brand: VBoxContainer = VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	brand.add_child(QuadTheme.label("사각형 월드", 29))
	brand.add_child(QuadTheme.label("QUADRILATERAL WORLD  /  나의 그림이 모험이 되는 곳", 12, QuadTheme.MUTED))
	header.add_child(QuadTheme.button("메인으로", _show_home))
	header.add_child(QuadTheme.button("도형 도감", _show_notebook))
	header.add_child(QuadTheme.button("불러오기", func(): _load(true)))
	header.add_child(QuadTheme.button("저장", func(): _save(true)))
	var sound_button: Button = QuadTheme.button("소리 켜짐", Callable())
	sound_button.pressed.connect(func():
		_sound.sound_enabled = not _sound.sound_enabled
		sound_button.text = "소리 켜짐" if _sound.sound_enabled else "소리 꺼짐")
	header.add_child(sound_button)
	var title_row: HBoxContainer = HBoxContainer.new()
	column.add_child(title_row)
	var title: Label = QuadTheme.label("01  캐릭터 공방", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	title_row.add_child(QuadTheme.label("도형 고르기   →   골격 채우기   →   모험 떠나기", 15, QuadTheme.MUTED))
	var workspace: HBoxContainer = HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 18)
	column.add_child(workspace)
	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_scroll.custom_minimum_size.x = 228
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.add_child(left_scroll)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 16)
	left_scroll.add_child(left)
	var templates: VBoxContainer = QuadTheme.card(left, Color.WHITE, 16)
	templates.add_theme_constant_override("separation", 8)
	templates.add_child(QuadTheme.label("어떤 친구를 만들까요?", 17))
	for info: Dictionary in CharacterTemplates.all_templates():
		var id: String = String(info["id"])
		var b: Button = QuadTheme.button(String(info["name"]), func(): _choose_template(id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		templates.add_child(b)
		_template_buttons[id] = b
	var shapes: VBoxContainer = QuadTheme.card(left, Color.WHITE, 16)
	shapes.add_theme_constant_override("separation", 8)
	shapes.add_child(QuadTheme.label("사각형 팔레트", 17))
	for kind: String in SHAPES:
		var b: Button = QuadTheme.button(QuadrilateralMath.kind_label(kind), func(): _select_kind(kind))
		b.icon = QuadTheme.icon(kind)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("h_separation", 10)
		shapes.add_child(b)
		_shape_buttons[kind] = b
	_shape_note = QuadTheme.paragraph("", 13)
	shapes.add_child(_shape_note)
	var center: VBoxContainer = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 12)
	workspace.add_child(center)
	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	center.add_child(toolbar)
	_undo_button = QuadTheme.button("되돌리기", document.undo)
	_redo_button = QuadTheme.button("다시", document.redo)
	toolbar.add_child(_undo_button)
	toolbar.add_child(_redo_button)
	toolbar.add_child(QuadTheme.button("복제", document.duplicate_selected))
	toolbar.add_child(QuadTheme.button("삭제", document.delete_selected))
	toolbar.add_child(QuadTheme.button("왼쪽 15°", func(): document.rotate_selected(-15)))
	toolbar.add_child(QuadTheme.button("오른쪽 15°", func(): document.rotate_selected(15)))
	toolbar.add_child(QuadTheme.button("축소", func(): document.scale_selected(0.9)))
	toolbar.add_child(QuadTheme.button("확대", func(): document.scale_selected(1.1)))
	var canvas_panel: PanelContainer = PanelContainer.new()
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.add_theme_stylebox_override("panel", QuadTheme.style(Color("eff5f4"), 20, QuadTheme.BORDER, 0))
	center.add_child(canvas_panel)
	workshop = CharacterWorkshop.new()
	workshop.document = document
	workshop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workshop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workshop.hint_requested.connect(_show_toast)
	canvas_panel.add_child(workshop)
	var colors: HBoxContainer = HBoxContainer.new()
	colors.alignment = BoxContainer.ALIGNMENT_CENTER
	colors.add_theme_constant_override("separation", 10)
	center.add_child(colors)
	colors.add_child(QuadTheme.label("색", 14, QuadTheme.MUTED))
	for color: Color in QuadTheme.COLORS:
		var swatch: Button = QuadTheme.button("", func(): _choose_color(color))
		swatch.custom_minimum_size = Vector2(39, 39)
		swatch.add_theme_stylebox_override("normal", QuadTheme.style(color, 12, color.darkened(0.15), 0))
		swatch.add_theme_stylebox_override("hover", QuadTheme.style(color.lightened(0.12), 12, QuadTheme.INK, 0))
		swatch.add_theme_stylebox_override("pressed", QuadTheme.style(color, 12, QuadTheme.INK, 0))
		colors.add_child(swatch)
		_swatches.append(swatch)
	var custom_color: ColorPickerButton = ColorPickerButton.new()
	custom_color.custom_minimum_size = Vector2(39, 39)
	custom_color.color = QuadTheme.TEAL
	custom_color.edit_alpha = false
	custom_color.color_changed.connect(_choose_color)
	custom_color.tooltip_text = "직접 색 고르기"
	colors.add_child(custom_color)
	var canvas_hint: Label = QuadTheme.label("도형을 고른 뒤 같은 이름의 골격을 눌러요. 빈 곳에 드래그하면 자유롭게 추가해요.", 13, QuadTheme.MUTED)
	canvas_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(canvas_hint)
	var right_scroll: ScrollContainer = ScrollContainer.new()
	right_scroll.custom_minimum_size.x = 258
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.add_child(right_scroll)
	_inspector_panel = right_scroll
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	right_scroll.add_child(right)
	var preview_card: VBoxContainer = QuadTheme.card(right)
	preview_card.add_child(QuadTheme.label("나의 모험 친구", 18))
	_preview = CharacterPreview.new()
	preview_card.add_child(_preview)
	_progress = QuadTheme.label("", 15)
	preview_card.add_child(_progress)
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size.y = 9
	_progress_bar.show_percentage = false
	_progress_bar.add_theme_stylebox_override("background", QuadTheme.style(Color("e7eee8"), 5, Color.TRANSPARENT, 0))
	_progress_bar.add_theme_stylebox_override("fill", QuadTheme.style(QuadTheme.TEAL, 5, Color.TRANSPARENT, 0))
	preview_card.add_child(_progress_bar)
	preview_card.add_child(QuadTheme.button("색칠된 예시 사용", document.fill_example))
	preview_card.add_child(QuadTheme.button("그림 PNG 저장", _export_png))
	var info_card: VBoxContainer = QuadTheme.card(right, Color("fff6e3"))
	info_card.add_child(QuadTheme.label("도형 탐구", 16))
	_inspector = QuadTheme.paragraph("도형을 누르면 변의 길이와 각을 살펴볼 수 있어요.", 13, QuadTheme.INK)
	info_card.add_child(_inspector)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	column.add_child(bottom)
	var bottom_note: Label = QuadTheme.paragraph("내가 만든 모습 그대로 걷고 뛰어요. 골격을 모두 채우면 사각형 월드로 출발할 수 있어요.", 15)
	bottom.add_child(bottom_note)
	_start_button = QuadTheme.button("사각형 월드로 출발  →", _enter_world, true)
	_start_button.custom_minimum_size = Vector2(280, 54)
	bottom.add_child(_start_button)
	_select_kind("square")

func _build_world_hud() -> void:
	_world_hud = Control.new()
	_world_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_hud.visible = false
	_ui.add_child(_world_hud)
	var identity: PanelContainer = PanelContainer.new()
	identity.position = Vector2(22, 18)
	identity.custom_minimum_size = Vector2(342, 128)
	identity.add_theme_stylebox_override("panel", GameArt.panel(1, 18))
	_world_hud.add_child(identity)
	var character_info: VBoxContainer = VBoxContainer.new()
	character_info.add_theme_constant_override("separation", 7)
	identity.add_child(character_info)
	_level_label = QuadTheme.label("LV. 1  사각형 탐험가", 22, Color("f6d794"))
	character_info.add_child(_level_label)
	_health_label = QuadTheme.label("HP 100 / 100", 14, Color("f7edd7"))
	character_info.add_child(_health_label)
	_health_bar = _rpg_bar(Color("ef8668"), 12)
	character_info.add_child(_health_bar)
	_xp_bar = _rpg_bar(Color("f3cd6e"), 7)
	character_info.add_child(_xp_bar)
	var region_panel: PanelContainer = PanelContainer.new()
	region_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	region_panel.offset_left = -208
	region_panel.offset_right = 208
	region_panel.offset_top = 18
	region_panel.add_theme_stylebox_override("panel", GameArt.panel(1, 16))
	_world_hud.add_child(region_panel)
	var region_info: VBoxContainer = VBoxContainer.new()
	region_panel.add_child(region_info)
	_world_region = QuadTheme.label("초록 마을", 22, Color("f6d794"))
	_world_region.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_info.add_child(_world_region)
	_world_stats = QuadTheme.label("", 14, Color("ece2c5"))
	_world_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_info.add_child(_world_stats)
	_story_label = QuadTheme.label("", 13, Color("c1cfc6"))
	_story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_info.add_child(_story_label)
	var quest_panel: PanelContainer = PanelContainer.new()
	quest_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	quest_panel.offset_left = -334
	quest_panel.offset_right = -22
	quest_panel.offset_top = 18
	quest_panel.add_theme_stylebox_override("panel", GameArt.panel(1, 18))
	quest_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_hud.add_child(quest_panel)
	var qv: VBoxContainer = VBoxContainer.new()
	qv.add_theme_constant_override("separation", 12)
	quest_panel.add_child(qv)
	qv.add_child(QuadTheme.label("QUEST  /  주민들의 부탁", 17, Color("f6d794")))
	_active_quests = QuadTheme.paragraph("주민 곁에서 E를 눌러 첫 부탁을 받아 보세요!", 14, Color("e8e5ce"))
	_active_quests.custom_minimum_size.x = 260
	qv.add_child(_active_quests)
	_guidance = QuadTheme.paragraph("", 14, Color("f6d794"))
	qv.add_child(_guidance)
	qv.add_child(_rpg_button("부탁 수첩  J", _show_journal))
	var bottom: PanelContainer = PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 22
	bottom.offset_right = -22
	bottom.offset_top = -112
	bottom.offset_bottom = -18
	bottom.add_theme_stylebox_override("panel", GameArt.panel(1, 16))
	_world_hud.add_child(bottom)
	var bottom_column: VBoxContainer = VBoxContainer.new()
	bottom_column.add_theme_constant_override("separation", 8)
	bottom.add_child(bottom_column)
	var shortcuts: HBoxContainer = HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 10)
	shortcuts.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_column.add_child(shortcuts)
	_pickup_button = _rpg_button("줍기  G", _pickup_nearest, 9)
	shortcuts.add_child(_pickup_button)
	shortcuts.add_child(_rpg_button("공격  Z / F", func():
		if world != null: world.player.begin_attack(), 14))
	_potion_button = _rpg_button("회복약  Q", _use_potion, 8)
	shortcuts.add_child(_potion_button)
	shortcuts.add_child(_rpg_button("가방  I", _show_inventory, 13))
	shortcuts.add_child(_rpg_button("지도  M", _show_map, 7))
	shortcuts.add_child(_rpg_button("이야기  H", _show_story, 4))
	shortcuts.add_child(_rpg_button("도형 도감", _show_notebook, 4))
	shortcuts.add_child(_rpg_button("캐릭터 공방", _return_workshop))
	var controls: Label = QuadTheme.label("방향키 이동   Space 점프   G 물건 줍기   E 대화·이용   Z / F 공격   Q 회복약   가까이 닿으면 자동으로 주워요", 13, Color("c1cfc6"))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_column.add_child(controls)

func _rpg_bar(tint: Color, height: float) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(250, height)
	bar.show_percentage = false
	var back: StyleBoxTexture = GameArt.panel(1, 0)
	var fill: StyleBoxTexture = GameArt.panel(3, 0)
	fill.texture = GameArt.panel_texture(0)
	fill.modulate_color = tint
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _rpg_button(text: String, callback: Callable, item_index: int = -1) -> Button:
	var button: Button = QuadTheme.button(text, callback)
	button.add_theme_stylebox_override("normal", GameArt.panel(2, 12))
	button.add_theme_stylebox_override("hover", GameArt.panel(1, 12))
	button.add_theme_stylebox_override("pressed", GameArt.panel(1, 12))
	button.add_theme_color_override("font_color", Color("f8eacb"))
	button.add_theme_color_override("font_hover_color", Color("ffe2a0"))
	button.add_theme_color_override("font_pressed_color", Color("ffe2a0"))
	if item_index >= 0: button.icon = GameArt.item(item_index)
	return button

func _build_toast() -> void:
	_toast = QuadTheme.label("", 16, Color.WHITE)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -370
	_toast.offset_right = 370
	_toast.offset_top = -174
	_toast.offset_bottom = -126
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_stylebox_override("normal", QuadTheme.style(Color("213b42f0"), 12, Color.TRANSPARENT, 12))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_ui.add_child(_toast)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 3.5
	_toast_timer.timeout.connect(func(): _toast.hide())
	add_child(_toast_timer)

func _show_toast(message: String) -> void:
	if _toast == null: return
	_toast.text = message
	_toast.show()
	_ui.move_child(_toast, _ui.get_child_count() - 1)
	_toast_timer.start()

func _select_kind(kind: String) -> void:
	if workshop != null: workshop.select_kind(kind)
	if _shape_note != null: _shape_note.text = String(SHAPE_NOTES.get(kind, ""))
	for key: String in _shape_buttons:
		var b: Button = _shape_buttons[key]
		b.add_theme_stylebox_override("normal", QuadTheme.style(Color("dff2e9") if key == kind else Color.WHITE, 11, QuadTheme.TEAL if key == kind else QuadTheme.BORDER, 6))

func _choose_color(color: Color) -> void:
	workshop.set_paint_color(color)
	document.set_color(color)
	for i: int in range(_swatches.size()):
		var c: Color = QuadTheme.COLORS[i]
		_swatches[i].text = "✓" if c.is_equal_approx(color) else ""
		_swatches[i].add_theme_color_override("font_color", QuadTheme.INK if c.get_luminance() > 0.55 else Color.WHITE)

func _choose_template(id: String) -> void:
	document.set_template(id)
	_sound.play_click()
	_show_toast("골격을 바꿨어요. 되돌리기로 이전 그림을 복원할 수 있어요.")

func _document_changed() -> void:
	if _preview == null: return
	_preview.set_character(document.character_data())
	var done: Dictionary = document.completion()
	_progress.text = "골격 %d / %d 완성" % [int(done["filled"]), int(done["total"])]
	_progress_bar.max_value = maxi(int(done["total"]), 1)
	_progress_bar.value = int(done["filled"])
	_start_button.disabled = not bool(done["ready"])
	_undo_button.disabled = not document.can_undo()
	_redo_button.disabled = not document.can_redo()
	for id: String in _template_buttons:
		var b: Button = _template_buttons[id]
		b.add_theme_stylebox_override("normal", QuadTheme.style(Color("dff2e9") if id == document.template_id else Color.WHITE, 11, QuadTheme.TEAL if id == document.template_id else QuadTheme.BORDER, 8))
	var selected: Dictionary = document.get_selected()
	if selected.is_empty():
		_inspector.text = "도형을 누르면 변의 길이와 각을 살펴볼 수 있어요.\n\n돌리거나 크기를 바꿔도 선택한 사각형의 성질은 유지돼요."
	else:
		var vertices: PackedVector2Array = selected["vertices"]
		var lengths: PackedFloat32Array = QuadrilateralMath.side_lengths(vertices)
		var angles: PackedInt32Array = QuadrilateralMath.display_angles(vertices)
		var length_text: PackedStringArray = PackedStringArray()
		var angle_text: PackedStringArray = PackedStringArray()
		for length: float in lengths: length_text.append("%.1f" % (length / 20.0))
		for angle: float in angles: angle_text.append("%.0f°" % angle)
		var names: PackedStringArray = PackedStringArray()
		for kind: String in QuadrilateralMath.classifications(vertices): names.append(QuadrilateralMath.kind_label(kind))
		_inspector.text = "%s\n\n변의 길이 (칸)\n%s\n\n네 각\n%s\n\n이 도형의 이름\n%s" % [QuadrilateralMath.kind_label(String(selected["kind"])), " · ".join(length_text), " · ".join(angle_text), ", ".join(names)]
	if not _restoring and _autosave != null: _autosave.start()

func _journal_changed() -> void:
	if _world_stats == null: return
	_world_stats.text = "%d 코인   ·   친구 %d / %d" % [journal.coins, journal.completed_count(), QuestCatalog.all_quests().size()]
	var lines: PackedStringArray = PackedStringArray()
	for quest: Dictionary in QuestCatalog.all_quests():
		var id: String = String(quest["id"])
		var state: String = journal.quest_state(id)
		if state == "active" or state == "ready":
			lines.append(("✓ " if state == "ready" else "· ") + journal.progress_text(id))
	if lines.size() > 3:
		var remaining: int = lines.size() - 3
		lines.resize(3)
		lines.append("외 %d개의 부탁  ·  J로 모두 보기" % remaining)
	if lines.is_empty():
		_active_quests.text = "주민 곁에서 E를 눌러\n새로운 부탁을 받아 보세요!" if journal.completed_count() < QuestCatalog.all_quests().size() else "모든 주민을 도왔어요!\n별빛이 다시 켜졌어요.\n이야기 수첩에서 여행을 돌아봐요."
	else: _active_quests.text = "\n\n".join(lines)
	if not _restoring and _autosave != null: _autosave.start()

func _adventure_changed() -> void:
	if _health_label == null: return
	_health_label.text = "HP  %d / %d      XP  %d / %d" % [adventure.hp, adventure.max_hp, adventure.xp_in_level(), adventure.xp_for_next_level()]
	_level_label.text = "LV. %d  사각형 탐험가" % adventure.level
	_health_bar.max_value = adventure.max_hp
	_health_bar.value = adventure.hp
	_xp_bar.max_value = adventure.xp_for_next_level()
	_xp_bar.value = adventure.xp_in_level()
	_potion_button.text = "회복약 %d  Q" % adventure.potions
	if world != null: world.player.set_health(adventure.hp, adventure.max_hp, false)
	if not _restoring and _autosave != null: _autosave.start()

func _on_player_damaged(amount: int) -> void:
	adventure.damage(amount)

func _on_player_defeated() -> void:
	adventure.heal(adventure.max_hp)
	world.recover_at_checkpoint()
	_show_toast("쉼터에서 기운을 회복했어요. 코인과 모은 물건은 그대로예요!")

func _on_enemy_defeated(enemy_id: String) -> void:
	var old_level: int = adventure.level
	if adventure.record_enemy_defeat(enemy_id):
		_sound.play_create()
		_show_toast("레벨 업! LV. %d · 체력을 모두 회복했어요." % adventure.level if adventure.level > old_level else "사각형 몬스터를 물리쳤어요! +20 경험치")

func _use_potion() -> void:
	if adventure.use_potion():
		_sound.play_create()
		_show_toast("회복약으로 체력을 회복했어요.")
	else:
		_show_toast("체력이 이미 가득해요." if adventure.hp >= adventure.max_hp else "회복약이 없어요. 초록 마을의 상점을 찾아가요!")

func _pickup_nearest() -> void:
	if world == null or not _in_world or is_instance_valid(_modal_overlay): return
	if not world.pickup_nearest():
		_show_toast("물건 옆으로 다가가 G를 눌러요. 위쪽 발판은 Space로 올라갈 수 있어요.")

func _on_item_collected(label: String, quest_id: String, count: int, required: int) -> void:
	_sound.play_create()
	var quest: Dictionary = QuestCatalog.get_quest(quest_id)
	if journal.accepted.has(quest_id): _tracked_quest = quest_id
	var next_step: String = "모두 모았어요! %s에게 돌아가요." % str(quest["npc_name"]) if journal.can_turn_in(quest_id) else "가방 I에서 확인해요."
	if not journal.accepted.has(quest_id): next_step = "%s의 부탁에 쓸 수 있어요." % str(quest["npc_name"])
	_show_toast("주웠어요! %s  %d / %d\n%s" % [label, count, required, next_step])
	_refresh_world_guidance()

func _refresh_world_guidance() -> void:
	if world == null or not _in_world or _guidance == null: return
	var region: Dictionary = QuadrilateralWorld.region_at(world.player.position.x)
	var story: Dictionary = QuestCatalog.region_story(str(region["id"]))
	_story_label.text = str(story.get("title", "")) + "  ·  H 이야기"
	var nearby: Dictionary = world.nearby_pickup()
	_pickup_button.tooltip_text = "물건 옆에서 G를 눌러 주워요" if nearby.is_empty() else str(nearby.get("label", "물건")) + " 줍기"
	if _tracked_quest.is_empty() or journal.quest_state(_tracked_quest) == "completed":
		_tracked_quest = ""
		for quest: Dictionary in QuestCatalog.all_quests():
			if journal.quest_state(str(quest["id"])) in ["active", "ready"]:
				_tracked_quest = str(quest["id"])
				break
	var waypoint: Dictionary = _quest_waypoint(_tracked_quest)
	if not nearby.is_empty():
		_guidance.text = "G 줍기  ·  " + str(nearby.get("label", "물건"))
	elif not waypoint.is_empty():
		var offset: Vector2 = Vector2(waypoint["position"]) - world.player.position
		var direction: String = "왼쪽" if offset.x < -70.0 else ("오른쪽" if offset.x > 70.0 else "바로 근처")
		var vertical: String = " · 위쪽 발판으로 점프" if offset.y < -90.0 else ""
		_guidance.text = "%s\n%s %d걸음%s" % [waypoint["name"], direction, maxi(1, ceili(absf(offset.x) / 40.0)), vertical]
	else:
		_guidance.text = "물건은 G로 줍기 · 가까이 닿으면 자동 수집\n부탁을 받기 전에 모아도 괜찮아요."

func _quest_waypoint(quest_id: String) -> Dictionary:
	if world == null or quest_id.is_empty(): return {}
	var quest: Dictionary = QuestCatalog.get_quest(quest_id)
	if quest.is_empty(): return {}
	if journal.quest_state(quest_id) != "active":
		for npc: Dictionary in world.npcs:
			if str(npc["quest"]) == quest_id:
				return {"position": npc["position"], "name": str(npc["name"]) + "에게 E로 대화"}
	var nearest: Dictionary = {}
	var distance: float = INF
	var collected: Array = world.serialize().get("collected", [])
	for item: Dictionary in world.collectibles:
		if str(item["quest"]) != quest_id or collected.has(str(item["id"])): continue
		var item_distance: float = world.player.position.distance_to(Vector2(item["position"]))
		if item_distance < distance:
			distance = item_distance
			nearest = {"position": item["position"], "name": str(item["label"]) + " 찾기"}
	return nearest

func _region_completed(region_id: String) -> bool:
	var total: int = 0
	for quest: Dictionary in QuestCatalog.all_quests():
		if str(quest["region"]) != region_id: continue
		total += 1
		if not journal.completed.has(str(quest["id"])): return false
	return total > 0

func _show_story() -> void:
	var body: VBoxContainer = _open_modal("이야기 수첩  ·  꺼진 별빛을 찾아서")
	body.add_child(QuadTheme.paragraph("사각형 축제를 앞두고 먼 성곽의 별빛이 꺼졌어요. 마을에서 만난 친구들의 작은 부탁이 항구, 설원, 성곽으로 이어져요. 여섯 지역을 자유롭게 탐험하며 이야기를 완성해 보세요.", 19, QuadTheme.INK))
	for region: Dictionary in QuadrilateralWorld.REGION_DATA:
		var id: String = str(region["id"])
		var story: Dictionary = QuestCatalog.region_story(id)
		var done: int = 0
		var total: int = 0
		for quest: Dictionary in QuestCatalog.all_quests():
			if str(quest["region"]) == id:
				total += 1
				if journal.completed.has(str(quest["id"])): done += 1
		var card: VBoxContainer = QuadTheme.card(body, Color("edf5ef"), 16)
		card.add_child(QuadTheme.label("%s  ·  %d / %d" % [story.get("title", region["name"]), done, total], 20, QuadTheme.TEAL))
		card.add_child(QuadTheme.paragraph(str(story.get("intro", "")), 17, QuadTheme.INK))
		if done == total:
			card.add_child(QuadTheme.paragraph("이야기 완성\n" + str(story.get("outro", "")), 17, QuadTheme.TEAL))
		else:
			card.add_child(QuadTheme.paragraph("주민들의 부탁을 마치면 다음 이야기가 기록돼요.", 14))
	body.add_child(QuadTheme.button("여행 지도 펼치기", _show_map, true))
	body.add_child(QuadTheme.button("모험 계속하기", _close_modal))

func _show_inventory() -> void:
	var body: VBoxContainer = _open_modal("모험가의 가방  ·  LV. %d" % adventure.level)
	var balance: HBoxContainer = HBoxContainer.new()
	balance.add_child(GameArt.view(GameArt.item(9)))
	balance.add_child(QuadTheme.label("%d 코인  ·  주민 %d / %d명 도움" % [journal.coins, journal.completed_count(), QuestCatalog.all_quests().size()], 21))
	body.add_child(balance)
	var medicine: VBoxContainer = QuadTheme.card(body, Color("edf5ef"), 16)
	var potion_row: HBoxContainer = HBoxContainer.new()
	potion_row.add_child(GameArt.view(GameArt.item(8), Vector2(64, 72)))
	potion_row.add_child(QuadTheme.paragraph("회복약 × %d\n체력 40 회복 · 단축키 Q\n현재 체력 %d / %d" % [adventure.potions, adventure.hp, adventure.max_hp], 17, QuadTheme.INK))
	medicine.add_child(potion_row)
	medicine.add_child(QuadTheme.button("회복약 사용", func():
		_use_potion()
		_show_inventory(), true))
	body.add_child(QuadTheme.label("퀘스트 물품", 22))
	var found: bool = false
	for quest: Dictionary in QuestCatalog.all_quests():
		var target: String = String(quest["target"])
		var count: int = int(journal.inventory.get(target, 0))
		if count <= 0: continue
		found = true
		var row: HBoxContainer = HBoxContainer.new()
		row.add_child(GameArt.view(GameArt.quest_item(quest), Vector2(48, 48)))
		row.add_child(QuadTheme.paragraph("%s  × %d\n%s" % [str(quest["item_name"]), count, "주민에게 전달할 준비가 됐어요" if journal.can_turn_in(str(quest["id"])) else "부탁을 받기 전에 주운 물건도 사용할 수 있어요"], 17, QuadTheme.INK))
		body.add_child(row)
	if not found: body.add_child(QuadTheme.paragraph("빛나는 물건 옆에서 G를 누르거나 가까이 다가가 주워요. 부탁을 받기 전에도 모을 수 있어요. 전달을 마친 물건은 가방에서 빠져요.", 17))
	body.add_child(QuadTheme.button("모험 계속하기", _close_modal))

func _show_service(service_id: String) -> void:
	if service_id == "travel":
		_show_travel()
		return
	var is_shop: bool = service_id == "shop"
	var body: VBoxContainer = _open_modal("네모 잡화점" if is_shop else "따뜻한 모험가 쉼터")
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(GameArt.view(GameArt.item(8) if is_shop else GameArt.cell("environment_atlas", 2, 4, 3), Vector2(120, 130)))
	row.add_child(QuadTheme.paragraph("모험을 떠나기 전에 가방을 채워요.\n회복약 한 병은 체력을 40 회복해요." if is_shop else "따뜻한 쉼터에서 쉬었다 가세요.\n휴식하면 체력을 모두 회복해요.", 21, QuadTheme.INK))
	body.add_child(row)
	body.add_child(QuadTheme.label("보유 코인 %d  ·  회복약 %d  ·  HP %d / %d" % [journal.coins, adventure.potions, adventure.hp, adventure.max_hp], 18))
	var feedback: Label = QuadTheme.paragraph("", 16, QuadTheme.TEAL)
	if is_shop:
		body.add_child(QuadTheme.button("10 코인으로 회복약 구입", func():
			if adventure.purchase_potion(journal):
				_show_service("shop")
				_show_toast("회복약 한 병을 가방에 넣었어요.")
			else: feedback.text = "코인이 부족해요. 주민의 부탁을 도와 보상을 받아요.", true))
	else:
		body.add_child(QuadTheme.button("5 코인으로 충분히 쉬기", func():
			if adventure.rest(journal):
				_close_modal()
				_show_toast("푹 쉬고 체력을 모두 회복했어요!")
			else: feedback.text = "이미 체력이 가득해요." if adventure.hp >= adventure.max_hp else "휴식에 필요한 코인이 부족해요.", true))
	body.add_child(feedback)
	body.add_child(QuadTheme.button("다음에 다시 올게요", _close_modal))

func _show_travel() -> void:
	var body: VBoxContainer = _open_modal("사각형 관문  ·  빠른 이동")
	body.add_child(QuadTheme.paragraph("직접 방문한 지역의 관문으로 이동할 수 있어요. 처음 가는 길은 걸어서 발견해 보세요.", 18))
	for info: Dictionary in QuadrilateralWorld.REGION_DATA:
		var region_id: String = String(info["id"])
		var known: bool = adventure.discovered_regions.has(region_id)
		var button: Button = QuadTheme.button(String(info["name"]) + ("로 이동" if known else "  ·  아직 발견하지 않았어요"), func():
			if world != null and world.travel_to(region_id):
				_close_modal()
				_show_toast(String(info["name"]) + "에 도착했어요."))
		button.disabled = not known
		body.add_child(button)
	body.add_child(QuadTheme.button("걸어서 계속 탐험", _close_modal))

func _enter_world() -> void:
	if not bool(document.completion()["ready"]):
		_show_toast("골격을 모두 채운 뒤 출발해 주세요.")
		return
	_leave_activity()
	if world == null:
		world = QuadrilateralWorld.new()
		world.setup(document.character_data(), journal)
		add_child(world)
		world.interaction_requested.connect(_talk_to_npc)
		world.hint_requested.connect(_show_toast)
		world.item_collected.connect(_on_item_collected)
		world.region_changed.connect(func(region: String): _world_region.text = "사각형 월드  ·  " + region)
		world.progress_changed.connect(func(): _autosave.start())
		world.service_requested.connect(_show_service)
		world.enemy_defeated.connect(_on_enemy_defeated)
		world.player.damaged.connect(_on_player_damaged)
		world.player.defeated.connect(_on_player_defeated)
		world.configure_adventure(adventure)
		if not _world_data.is_empty(): world.restore(_world_data)
	else:
		world.update_character(document.character_data())
		world.show()
		world.process_mode = Node.PROCESS_MODE_INHERIT
		world.set_controls_enabled(true)
	_in_world = true
	_workshop_screen.hide()
	_world_hud.show()
	_responsive()
	_adventure_changed()
	_world_region.text = "사각형 월드  ·  " + world.get_current_region()
	_sound.play_create()
	_show_toast("물건 옆에서 G로 줍기! E로 주민과 대화하고, H로 이야기를 확인해요.")
	_refresh_world_guidance()
	_save(false)

func _return_workshop() -> void:
	_show_workshop()

func _talk_to_npc(npc_id: String) -> void:
	for quest: Dictionary in QuestCatalog.all_quests():
		if String(quest["npc_id"]) == npc_id:
			_show_quest_dialog(quest)
			return

func _show_quest_dialog(quest: Dictionary) -> void:
	var id: String = String(quest["id"])
	var body: VBoxContainer = _open_modal(String(quest["npc_name"]) + "의 부탁")
	var portrait_row: HBoxContainer = HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 20)
	portrait_row.add_child(GameArt.view(GameArt.quest_npc(quest), Vector2(90, 110)))
	var identity: VBoxContainer = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_row.add_child(identity)
	identity.add_child(QuadTheme.label(String(quest["npc_name"]), 23, QuadTheme.TEAL))
	identity.add_child(QuadTheme.paragraph("마을의 이야기를 함께 완성해 주세요.\n보상: %d 코인 · %d 경험치" % [int(quest["reward"]), int(quest["reward"]) * 2], 15))
	body.add_child(portrait_row)
	body.add_child(QuadTheme.label(String(quest["title"]), 25))
	var state: String = journal.quest_state(id)
	if state == "completed":
		body.add_child(QuadTheme.paragraph(str(quest.get("completion_story", "도와줘서 고마워요! 덕분에 별빛을 향해 한 걸음 더 나아갔어요.")) + "\n\n" + String(quest["explanation"]), 17, QuadTheme.INK))
	elif state == "ready":
		body.add_child(QuadTheme.paragraph("모두 찾았군요! 마지막으로 함께 생각해 볼까요?", 16))
		body.add_child(QuadTheme.paragraph(String(quest["question"]), 20, QuadTheme.INK))
		var feedback: Label = QuadTheme.paragraph("", 16, QuadTheme.TEAL)
		var options: Array = quest["options"]
		for index: int in range(options.size()):
			var button: Button = QuadTheme.button(String(options[index]), Callable())
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.pressed.connect(func():
				var answer: Dictionary = journal.answer_quest(id, index)
				feedback.text = String(answer["message"])
				if bool(answer["correct"]):
					_sound.play_fanfare()
					_show_quest_success(quest, answer)
				else: _sound.play_click())
			body.add_child(button)
		body.add_child(feedback)
	else:
		body.add_child(QuadTheme.paragraph(String(quest["description"]), 18, QuadTheme.INK))
		body.add_child(QuadTheme.paragraph("탐험 목표  ·  " + journal.progress_text(id), 16, QuadTheme.TEAL))
		body.add_child(QuadTheme.label("선물  ·  %d 코인" % int(quest["reward"]), 15))
		if state == "available":
			body.add_child(QuadTheme.button("제가 도와드릴게요!", func():
				journal.accept_quest(id)
				_tracked_quest = id
				_close_modal()
				_sound.play_create()
				_show_toast("이미 물건을 모두 모았어요! 이 주민에게 다시 E로 대화해 전달해요." if journal.can_turn_in(id) else "부탁을 받았어요! 물건 옆에서 G로 줍고, 다 모으면 주민에게 돌아와요."), true))
		else:
			body.add_child(QuadTheme.paragraph("가까이에서 G를 눌러 물건을 줍거나 표식을 조사해요. 높은 곳은 Space로 올라가요. 다 모으면 다시 찾아와 주세요.", 15))
	body.add_child(QuadTheme.button("계속 탐험하기", _close_modal))

func _show_quest_success(quest: Dictionary, answer: Dictionary) -> void:
	adventure.claim_quest(String(quest["id"]))
	var body: VBoxContainer = _open_modal("고마워요, 사각형 탐험가!")
	body.add_child(QuadTheme.label(String(quest["title"]) + " 완료", 24, QuadTheme.TEAL))
	body.add_child(QuadTheme.paragraph(String(answer["message"]), 18, QuadTheme.INK))
	body.add_child(QuadTheme.label("+ %d 코인  ·  도와준 친구 %d / %d" % [int(answer["reward"]), journal.completed_count(), QuestCatalog.all_quests().size()], 20, QuadTheme.TEAL))
	var chapter: Dictionary = QuestCatalog.region_story(str(quest["region"]))
	if _region_completed(str(quest["region"])):
		body.add_child(QuadTheme.paragraph(str(chapter.get("outro", "")), 18, QuadTheme.INK))
	if journal.completed_count() == QuestCatalog.all_quests().size():
		body.add_child(QuadTheme.paragraph("모든 지역에 별빛이 돌아왔어요! 서로 다른 사각형들의 성질을 알아본 덕분이에요. H로 이야기 수첩을 펼쳐 모험을 다시 읽어 보세요.", 18, QuadTheme.INK))
	body.add_child(QuadTheme.button("모험 계속하기", _close_modal, true))

func _show_journal() -> void:
	var body: VBoxContainer = _open_modal("나의 부탁 수첩")
	body.add_child(QuadTheme.paragraph("G로 물건을 주워요. 미리 모아도 괜찮아요! 부탁을 받아 목표를 다 모으면 주민에게 돌아가 도형 이야기를 나눠요. ‘이 목표 안내’로 화면에 방향을 표시할 수 있어요.", 16))
	body.add_child(QuadTheme.button("여섯 지역의 이야기 보기", _show_story))
	for quest: Dictionary in QuestCatalog.all_quests():
		var state: String = journal.quest_state(String(quest["id"]))
		var status: String = {"available": "아직 만나지 않았어요", "active": "탐험 중", "ready": "주민에게 돌아가요", "completed": "완료"}.get(state, "")
		var card: VBoxContainer = QuadTheme.card(body, Color("edf5ef"), 14)
		card.add_child(QuadTheme.label(String(quest["npc_name"]) + "  ·  " + status, 14, QuadTheme.TEAL))
		card.add_child(QuadTheme.label(String(quest["title"]), 19))
		card.add_child(QuadTheme.paragraph(journal.progress_text(String(quest["id"])), 15))
		if state == "completed": card.add_child(QuadTheme.paragraph(String(quest["explanation"]), 14))
		else: card.add_child(QuadTheme.button("이 목표 안내", func():
			_tracked_quest = str(quest["id"])
			_close_modal()
			_refresh_world_guidance()))
	body.add_child(QuadTheme.button("닫기", _close_modal))

func _show_notebook() -> void:
	var body: VBoxContainer = _open_modal("사각형 탐험 도감")
	body.add_child(QuadTheme.paragraph("돌리거나 크기를 바꿔도 도형의 성질은 그대로예요. 생김새와 방향보다 변과 각을 살펴봐요.", 17))
	for kind: String in SHAPES:
		var card: VBoxContainer = QuadTheme.card(body, Color("edf5ef"), 14)
		var row: HBoxContainer = HBoxContainer.new()
		card.add_child(row)
		var texture: TextureRect = TextureRect.new()
		texture.texture = QuadTheme.icon(kind)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.custom_minimum_size = Vector2(54, 54)
		row.add_child(texture)
		row.add_child(QuadTheme.label(QuadrilateralMath.kind_label(kind), 20))
		card.add_child(QuadTheme.paragraph(String(SHAPE_NOTES[kind]), 16, QuadTheme.INK))
	body.add_child(QuadTheme.paragraph("사각형 가족\n정사각형은 직사각형이면서 마름모예요. 두 도형 모두 평행사변형이고, 평행사변형은 사다리꼴에도 속해요. 이 도감은 ‘평행한 변이 있는 사각형’을 사다리꼴로 배워요.", 18, QuadTheme.INK))
	body.add_child(QuadTheme.paragraph("수직과 평행\n두 직선이 만나 직각을 이루면 서로 수직이에요. 아무리 늘여도 만나지 않는 두 직선은 평행해요. 평행선 사이 거리는 수직인 선분으로 재요.", 18, QuadTheme.INK))
	body.add_child(QuadTheme.paragraph("변·각·둘레\n평행사변형은 마주 보는 각이 같고, 이웃한 두 각의 합이 180°예요. 사각형의 네 각의 합은 360°예요. 둘레는 네 변의 길이를 모두 더한 값이에요.", 18, QuadTheme.INK))
	body.add_child(QuadTheme.button("닫기", _close_modal))

func _show_map() -> void:
	var body: VBoxContainer = _open_modal("사각형 월드 지도")
	body.add_child(QuadTheme.paragraph("마을과 숲을 지나, 항구에서 설원과 별빛 성곽까지!\n방향키로 이동 · Space로 발판 오르기 · G로 줍기", 19, QuadTheme.INK))
	if world != null:
		var map: WorldMapView = WorldMapView.new()
		map.points = world.navigation_points()
		map.player_x = world.player.position.x
		var waypoint: Dictionary = _quest_waypoint(_tracked_quest)
		if not waypoint.is_empty(): map.target_x = Vector2(waypoint["position"]).x
		body.add_child(map)
	for region: Dictionary in QuadrilateralWorld.REGION_DATA:
		var id: String = str(region["id"])
		var known: bool = adventure.discovered_regions.has(id)
		var card: VBoxContainer = QuadTheme.card(body, Color("edf5ef"), 14)
		card.add_child(QuadTheme.label(str(region["name"]) + ("  ·  발견" if known else "  ·  새로운 여행지"), 21))
		card.add_child(QuadTheme.paragraph(str(region["subtitle"]), 16, QuadTheme.TEAL))
		for quest: Dictionary in QuestCatalog.all_quests():
			if str(quest["region"]) != id: continue
			card.add_child(QuadTheme.paragraph("%s · %s\n%s" % [quest["npc_name"], quest["title"], journal.progress_text(str(quest["id"]))], 15))
		if known and world != null:
			card.add_child(QuadTheme.button("관문으로 이동", func():
				world.travel_to(id)
				_close_modal()))
	body.add_child(QuadTheme.button("탐험 계속하기", _close_modal))

func _open_modal(title: String) -> VBoxContainer:
	_close_modal()
	if world != null and _in_world: world.set_controls_enabled(false)
	_modal_overlay = Control.new()
	_modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_modal_overlay)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.09, 0.17, 0.2, 0.52)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_overlay.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", QuadTheme.style(QuadTheme.PAPER, 22, QuadTheme.BORDER, 24))
	center.add_child(panel)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	panel.add_child(outer)
	var header: HBoxContainer = HBoxContainer.new()
	outer.add_child(header)
	var heading: Label = QuadTheme.label(title, 23)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(QuadTheme.button("닫기 ×", _close_modal))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(minf(660, get_viewport().get_visible_rect().size.x - 100), minf(520, get_viewport().get_visible_rect().size.y - 180))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_modal_body = VBoxContainer.new()
	_modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_body.add_theme_constant_override("separation", 18)
	scroll.add_child(_modal_body)
	return _modal_body

func _close_modal() -> void:
	if is_instance_valid(_modal_overlay):
		_modal_overlay.queue_free()
		_modal_overlay = null
	if world != null and _in_world: world.set_controls_enabled(true)

func _save(notify_user: bool) -> void:
	if _restoring or testing: return
	if world != null: _world_data = world.serialize()
	var error: Error = WorldSaveStore.save_game(document.serialize(), journal.serialize(), _world_data, WorldSaveStore.SAVE_PATH, adventure.serialize())
	if notify_user:
		_show_toast("그림과 모험을 저장했어요. 다음에도 이어서 할 수 있어요." if error == OK else "저장 공간을 확인해 주세요. 저장하지 못했어요.")

func _load(notify_user: bool) -> bool:
	var data: Dictionary = WorldSaveStore.load_game()
	if data.is_empty():
		if notify_user: _show_toast("아직 저장한 그림과 모험이 없어요.")
		return false
	var candidate_document: CharacterDocument = CharacterDocument.new()
	var candidate_journal: QuestJournal = QuestJournal.new()
	var candidate_adventure: AdventureState = AdventureState.new()
	if not candidate_document.restore(data["editor"]) or not candidate_journal.restore(data["journal"]) or not QuadrilateralWorld.is_valid_save(data["world"]):
		if notify_user: _show_toast("저장 내용을 읽을 수 없어요. 현재 그림은 그대로 유지돼요.")
		return false
	if data.has("adventure") and not candidate_adventure.restore(data["adventure"]):
		if notify_user: _show_toast("모험가 정보를 읽을 수 없어요. 현재 상태는 유지돼요.")
		return false
	if not data.has("adventure"):
		for quest_id: String in candidate_journal.completed: candidate_adventure.claim_quest(quest_id)
	for claimed_id: String in candidate_adventure.claimed_quests:
		if not candidate_journal.completed.has(claimed_id): return false
	_restoring = true
	document.restore(data["editor"])
	journal.restore(data["journal"])
	adventure.restore(candidate_adventure.serialize())
	_world_data = data["world"].duplicate(true)
	if world != null:
		world.restore(_world_data)
		world.update_character(document.character_data())
		world.configure_adventure(adventure)
	_restoring = false
	if notify_user: _show_toast("그림과 모험을 불러왔어요.")
	return true

func _export_png() -> void:
	if _exporting or document.shapes.is_empty():
		_show_toast("먼저 사각형을 그려 주세요.")
		return
	if DisplayServer.get_name() == "headless": return
	_exporting = true
	var bytes: PackedByteArray = await CharacterExporter.export_png(get_tree(), document.character_data())
	_exporting = false
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, "my-quadrilateral-friend.png", "image/png")
		_show_toast("캐릭터 PNG를 내려받았어요.")
	else:
		var dialog: FileDialog = FileDialog.new()
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dialog.filters = PackedStringArray(["*.png ; PNG 이미지"])
		dialog.current_file = "my-quadrilateral-friend.png"
		dialog.use_native_dialog = true
		dialog.file_selected.connect(func(path: String):
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(bytes)
				file.close()
				_show_toast("캐릭터 PNG를 저장했어요.")
			else: _show_toast("이미지 저장 위치를 확인해 주세요.")
			dialog.queue_free())
		dialog.canceled.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered(Vector2i(800, 600))

func _responsive() -> void:
	# Creation screens use the window's available space so their labels and tools
	# stay readable on smaller desktops; the adventure retains its game viewport.
	var window: Window = get_window()
	var creation_visible: bool = is_instance_valid(_home_screen) and (_home_screen.visible or _drawing_screen.visible or (is_instance_valid(_construction_screen) and _construction_screen.visible))
	var desired_size: Vector2i = Vector2i(maxi(window.size.x, 800), maxi(window.size.y, 600)) if creation_visible else Vector2i(1600, 900)
	if window.content_scale_size != desired_size:
		window.content_scale_size = desired_size
	if _inspector_panel != null:
		_inspector_panel.visible = get_viewport().get_visible_rect().size.x >= 1160.0

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if _drawing_screen.visible or _construction_screen.visible: return
	if event.keycode == KEY_ESCAPE:
		_close_modal()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_modal_overlay): return
	if _home_screen.visible: return
	if event.ctrl_pressed and event.keycode == KEY_S:
		_save(true)
		get_viewport().set_input_as_handled()
	elif _in_world:
		if event.keycode == KEY_J: _show_journal()
		elif event.keycode == KEY_M: _show_map()
		elif event.keycode == KEY_I: _show_inventory()
		elif event.keycode == KEY_H: _show_story()
		elif event.keycode == KEY_Q: _use_potion()
	elif event.ctrl_pressed and event.keycode == KEY_Z:
		if event.shift_pressed: document.redo()
		else: document.undo()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_Y:
		document.redo()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_D:
		document.duplicate_selected()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_DELETE:
		document.delete_selected()
		get_viewport().set_input_as_handled()
