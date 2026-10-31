class_name QuadrilateralApp
extends Node

const SHAPES: Array[String] = ["trapezoid", "parallelogram", "rhombus", "rectangle", "square"]
const SHAPE_NOTES: Dictionary = {
	"trapezoid": "평행한 변이 있는 사각형이에요.\n마주 보는 변을 확인해요.",
	"parallelogram": "마주 보는 두 쌍의 변이 평행해요.\n마주 보는 변의 길이와 각이 같아요.",
	"rhombus": "네 변의 길이가 모두 같아요.\n마주 보는 두 쌍의 변은 평행해요.",
	"rectangle": "네 각이 모두 직각(90°)이에요.\n마주 보는 변의 길이가 같아요.",
	"square": "네 변의 길이가 모두 같고,\n네 각이 모두 직각(90°)이에요."
}

var document: CharacterDocument
var testing: bool = false
var learning_progress: LearningProgress = LearningProgress.new()
var _learning_screen: LearningStudio
var journal: QuestJournal
var adventure: AdventureState
var workshop: CharacterWorkshop
var world: QuadrilateralWorld
var _sound: SoundManager
var _ui: Control
var _ui_layer: CanvasLayer
var _ui_scale: float = 1.0
var _compact_hud: bool = false
var _identity_panel: PanelContainer
var _region_panel: PanelContainer
var _quest_panel: PanelContainer
var _quest_heading: Label
var _quest_open_button: Button
var _hud_bottom: PanelContainer
var _hud_actions: HBoxContainer
var _touch_row: HBoxContainer
var _touch_buttons: Dictionary = {}
var _touch_fingers: Dictionary = {}
var _hud_controls: Label
var _hud_buttons: Array[Button] = []
var _modal_panel: PanelContainer
var _modal_scroll: ScrollContainer
var _modal_close: Button
var _modal_focus_before: Control
var _journal_filter: String = "active"
var _workshop_margin: MarginContainer
var _workshop_left: ScrollContainer
var _workshop_workspace: HBoxContainer
var _workshop_compact_selectors: HFlowContainer
var _workshop_template_picker: OptionButton
var _workshop_shape_picker: OptionButton
var _workshop_steps: Label
var _workshop_tagline: Label
var _workshop_bottom_note: Label
var _workshop_helpers: HFlowContainer
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
	if not testing and not learning_progress.load_file():
		learning_progress.touch_controls = DisplayServer.is_touchscreen_available()
	document = CharacterDocument.new()
	journal = QuestJournal.new()
	adventure = AdventureState.new()
	_sound = SoundManager.new()
	add_child(_sound)
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = Theme.new()
	_ui.theme.default_font = QuadTheme.FONT
	ButtonArt.install(_ui.theme)
	get_window().theme = _ui.theme
	_ui_layer.add_child(_ui)
	_build_workshop()
	_build_home()
	_build_drawing()
	_build_construction()
	_build_learning()
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
	get_viewport().size_changed.connect(func(): call_deferred("_responsive"))
	if not testing: _load(false)
	_document_changed()
	_journal_changed()
	_adventure_changed()
	_responsive()
	_show_home()
	learning_progress.changed.connect(_learning_changed)
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
	_home_screen.learning_requested.connect(_show_learning)
	_ui.add_child(_home_screen)
	_home_screen.set_learning_progress(learning_progress.completed.size())

func _build_learning() -> void:
	_learning_screen = LearningStudio.new()
	_learning_screen.progress = learning_progress
	_learning_screen.home_requested.connect(_show_home)
	_learning_screen.drawing_requested.connect(_show_drawing)
	_learning_screen.hide()
	_ui.add_child(_learning_screen)

func _show_learning(id: String = "") -> void:
	_leave_activity()
	_learning_screen.show()
	_learning_screen.open_lesson(learning_progress.next_lesson() if id.is_empty() else id)
	_responsive()

func _learning_changed() -> void:
	_home_screen.set_learning_progress(learning_progress.completed.size())
	if world != null:
		world.peaceful = learning_progress.peaceful
		if not learning_progress.touch_controls: _clear_touch_inputs()
	if is_instance_valid(_touch_row):
		_touch_row.visible = learning_progress.touch_controls
		_layout_hud(_ui_size())
	if not testing: learning_progress.save_file()

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
	_clear_touch_inputs()
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
	if is_instance_valid(_learning_screen): _learning_screen.hide()
	_world_hud.hide()
	if _toast != null: _toast.hide()
	if save_adventure: _save(false)

func _show_home() -> void:
	_leave_activity()
	_home_screen.show()
	_responsive()
	_home_screen.focus_primary()

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
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_workshop_screen.add_child(bg)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_workshop_screen.add_child(scroll)
	_workshop_margin = MarginContainer.new()
	_workshop_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workshop_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for edge: String in ["left", "right", "top", "bottom"]:
		_workshop_margin.add_theme_constant_override("margin_" + edge, 24)
	scroll.add_child(_workshop_margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_workshop_margin.add_child(column)
	var header: HFlowContainer = HFlowContainer.new()
	header.add_theme_constant_override("h_separation", 12)
	header.add_theme_constant_override("v_separation", 8)
	column.add_child(header)
	var brand: VBoxContainer = VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	brand.add_child(QuadTheme.label("사각형 월드", 29))
	_workshop_tagline = QuadTheme.label("나의 그림이 모험이 되는 곳", 15, QuadTheme.MUTED)
	brand.add_child(_workshop_tagline)
	header.add_child(QuadTheme.button("메인으로", _show_home))
	header.add_child(QuadTheme.button("도형 도감", _show_notebook))
	header.add_child(QuadTheme.button("불러오기", func(): _load(true)))
	header.add_child(QuadTheme.button("저장", func(): _save(true)))
	var sound_button: Button = QuadTheme.button("소리 켜짐", Callable())
	sound_button.pressed.connect(func():
		_sound.sound_enabled = not _sound.sound_enabled
		sound_button.text = "소리 켜짐" if _sound.sound_enabled else "소리 꺼짐")
	header.add_child(sound_button)
	var title_row: HFlowContainer = HFlowContainer.new()
	title_row.add_theme_constant_override("h_separation", 16)
	column.add_child(title_row)
	var title: Label = QuadTheme.label("01  캐릭터 공방", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_workshop_steps = QuadTheme.label("도형 고르기   →   골격 채우기   →   모험 떠나기", 15, QuadTheme.MUTED)
	title_row.add_child(_workshop_steps)
	_workshop_compact_selectors = HFlowContainer.new()
	_workshop_compact_selectors.add_theme_constant_override("h_separation", 8)
	_workshop_compact_selectors.add_theme_constant_override("v_separation", 8)
	column.add_child(_workshop_compact_selectors)
	_workshop_template_picker = OptionButton.new()
	_workshop_shape_picker = OptionButton.new()
	for picker: OptionButton in [_workshop_template_picker, _workshop_shape_picker]:
		var skin: Button = QuadTheme.button("", Callable())
		picker.custom_minimum_size = Vector2(150, 48)
		picker.add_theme_font_override("font", QuadTheme.FONT)
		picker.add_theme_font_size_override("font_size", 18)
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			picker.add_theme_stylebox_override(state, skin.get_theme_stylebox(state))
		for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
			picker.add_theme_color_override(color_name, skin.get_theme_color(color_name))
		picker.get_popup().add_theme_font_override("font", QuadTheme.FONT)
		picker.get_popup().add_theme_font_size_override("font_size", 18)
		picker.get_popup().add_theme_color_override("font_color", QuadTheme.INK)
		picker.get_popup().add_theme_color_override("font_hover_color", QuadTheme.INK)
		picker.get_popup().add_theme_stylebox_override("panel", GameArt.panel(0, 8))
		picker.get_popup().add_theme_stylebox_override("hover", skin.get_theme_stylebox("hover"))
		picker.get_popup().add_theme_constant_override("v_separation", 12)
		_workshop_compact_selectors.add_child(picker)
		skin.free()
	for info: Dictionary in CharacterTemplates.all_templates():
		_workshop_template_picker.add_item("친구 · " + str(info["name"]))
		_workshop_template_picker.set_item_metadata(_workshop_template_picker.item_count - 1, str(info["id"]))
	for kind: String in SHAPES:
		_workshop_shape_picker.add_item("도형 · " + QuadrilateralMath.kind_label(kind))
		_workshop_shape_picker.set_item_metadata(_workshop_shape_picker.item_count - 1, kind)
	_workshop_template_picker.item_selected.connect(func(index: int): _choose_template(str(_workshop_template_picker.get_item_metadata(index))))
	_workshop_shape_picker.item_selected.connect(func(index: int): _select_kind(str(_workshop_shape_picker.get_item_metadata(index))))
	document.changed.connect(func():
		for index: int in range(_workshop_template_picker.item_count):
			if str(_workshop_template_picker.get_item_metadata(index)) == document.template_id:
				_workshop_template_picker.select(index)
				break)
	_workshop_workspace = HBoxContainer.new()
	_workshop_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_workshop_workspace.add_theme_constant_override("separation", 18)
	column.add_child(_workshop_workspace)
	_workshop_left = ScrollContainer.new()
	_workshop_left.custom_minimum_size.x = 228
	_workshop_left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_workshop_workspace.add_child(_workshop_left)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 16)
	_workshop_left.add_child(left)
	var templates: VBoxContainer = QuadTheme.card(left, Color.WHITE, 12)
	templates.add_theme_constant_override("separation", 8)
	templates.add_child(QuadTheme.paragraph("친구를 골라요", 17, QuadTheme.INK))
	for info: Dictionary in CharacterTemplates.all_templates():
		var id: String = String(info["id"])
		var b: Button = QuadTheme.button(String(info["name"]), func(): _choose_template(id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		templates.add_child(b)
		_template_buttons[id] = b
	var shapes: VBoxContainer = QuadTheme.card(left, Color.WHITE, 12)
	shapes.add_theme_constant_override("separation", 8)
	shapes.add_child(QuadTheme.label("사각형 팔레트", 17))
	for kind: String in SHAPES:
		var b: Button = QuadTheme.button(QuadrilateralMath.kind_label(kind), func(): _select_kind(kind))
		b.icon = QuadTheme.icon(kind)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("h_separation", 6)
		b.add_theme_constant_override("icon_max_width", 26)
		shapes.add_child(b)
		_shape_buttons[kind] = b
	_shape_note = QuadTheme.paragraph("", 15)
	shapes.add_child(_shape_note)
	var center: VBoxContainer = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 12)
	_workshop_workspace.add_child(center)
	var toolbar: HFlowContainer = HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 8)
	toolbar.add_theme_constant_override("v_separation", 8)
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
	canvas_panel.custom_minimum_size = Vector2(220, 240)
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.add_theme_stylebox_override("panel", QuadTheme.style(Color("eff5f4"), 20, QuadTheme.BORDER, 0))
	center.add_child(canvas_panel)
	workshop = CharacterWorkshop.new()
	workshop.document = document
	workshop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workshop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workshop.hint_requested.connect(_show_toast)
	canvas_panel.add_child(workshop)
	var colors: HFlowContainer = HFlowContainer.new()
	colors.alignment = FlowContainer.ALIGNMENT_CENTER
	colors.add_theme_constant_override("h_separation", 8)
	colors.add_theme_constant_override("v_separation", 8)
	center.add_child(colors)
	colors.add_child(QuadTheme.label("색", 14, QuadTheme.MUTED))
	for color: Color in QuadTheme.COLORS:
		var swatch: Button = QuadTheme.button("", func(): _choose_color(color))
		swatch.tooltip_text = "칠할 색 #" + color.to_html(false).to_upper()
		swatch.custom_minimum_size = Vector2(44, 44)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			swatch.add_theme_stylebox_override(state, ButtonArt.swatch(color, state))
		colors.add_child(swatch)
		_swatches.append(swatch)
	var custom_color: ColorPickerButton = ColorPickerButton.new()
	ButtonArt.apply(custom_color, false, 18)
	custom_color.custom_minimum_size = Vector2(44, 44)
	custom_color.color = QuadTheme.TEAL
	custom_color.edit_alpha = false
	custom_color.color_changed.connect(_choose_color)
	custom_color.tooltip_text = "직접 색 고르기"
	colors.add_child(custom_color)
	var canvas_hint: Label = QuadTheme.label("도형을 고른 뒤 같은 이름의 골격을 눌러요. 빈 곳에 드래그하면 자유롭게 추가해요.", 14, QuadTheme.MUTED)
	canvas_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(canvas_hint)
	_workshop_helpers = HFlowContainer.new()
	_workshop_helpers.add_theme_constant_override("h_separation", 8)
	_workshop_helpers.add_theme_constant_override("v_separation", 8)
	center.add_child(_workshop_helpers)
	_workshop_helpers.add_child(QuadTheme.button("색칠된 예시 사용", document.fill_example))
	_workshop_helpers.add_child(QuadTheme.button("그림 PNG 저장", _export_png))
	_progress = QuadTheme.label("", 15)
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_workshop_helpers.add_child(_progress)
	var right_scroll: ScrollContainer = ScrollContainer.new()
	right_scroll.custom_minimum_size.x = 258
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_workshop_workspace.add_child(right_scroll)
	_inspector_panel = right_scroll
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	right_scroll.add_child(right)
	var preview_card: VBoxContainer = QuadTheme.card(right)
	preview_card.add_child(QuadTheme.label("나의 모험 친구", 18))
	_preview = CharacterPreview.new()
	preview_card.add_child(_preview)
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size.y = 9
	_progress_bar.show_percentage = false
	_progress_bar.add_theme_stylebox_override("background", QuadTheme.style(Color("e7eee8"), 5, Color.TRANSPARENT, 0))
	_progress_bar.add_theme_stylebox_override("fill", StarfrontArt.gauge(7))
	preview_card.add_child(_progress_bar)
	var info_card: VBoxContainer = QuadTheme.card(right, Color("fff6e3"))
	info_card.add_child(QuadTheme.label("도형 탐구", 16))
	_inspector = QuadTheme.paragraph("도형을 누르면 변의 길이와 각을 살펴볼 수 있어요.", 13, QuadTheme.INK)
	info_card.add_child(_inspector)
	var bottom: HFlowContainer = HFlowContainer.new()
	bottom.add_theme_constant_override("h_separation", 16)
	bottom.add_theme_constant_override("v_separation", 8)
	column.add_child(bottom)
	_workshop_bottom_note = QuadTheme.paragraph("내가 만든 모습 그대로 걷고 뛰어요. 골격을 모두 채우면 사각형 월드로 출발할 수 있어요.", 15)
	bottom.add_child(_workshop_bottom_note)
	_start_button = QuadTheme.button("사각형 월드로 출발  →", _enter_world, true)
	_start_button.custom_minimum_size = Vector2(280, 54)
	bottom.add_child(_start_button)
	_select_kind("square")

func _layout_workshop(ui_size: Vector2) -> void:
	if _workshop_margin == null: return
	var narrow: bool = ui_size.x < 620.0
	var compact: bool = ui_size.x < 1160.0
	var gutter: int = 12 if compact else 24
	for edge: String in ["left", "right", "top", "bottom"]:
		_workshop_margin.add_theme_constant_override("margin_" + edge, gutter)
	_workshop_workspace.add_theme_constant_override("separation", 12 if compact else 18)
	_workshop_left.custom_minimum_size.x = 190.0 if compact else 228.0
	_workshop_left.visible = not narrow
	_inspector_panel.visible = not compact
	_workshop_compact_selectors.visible = narrow
	_workshop_steps.visible = ui_size.x >= 760.0
	_workshop_tagline.visible = not narrow
	_workshop_bottom_note.visible = not compact
	for index: int in range(_workshop_template_picker.item_count):
		if str(_workshop_template_picker.get_item_metadata(index)) == document.template_id:
			_workshop_template_picker.select(index)
			break
	for index: int in range(_workshop_shape_picker.item_count):
		if str(_workshop_shape_picker.get_item_metadata(index)) == workshop.selected_kind:
			_workshop_shape_picker.select(index)
			break

func _build_world_hud() -> void:
	_world_hud = Control.new()
	_world_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_hud.visible = false
	_ui.add_child(_world_hud)
	_identity_panel = PanelContainer.new()
	_identity_panel.add_theme_stylebox_override("panel", GameArt.panel(1, 16))
	_world_hud.add_child(_identity_panel)
	var character_info: VBoxContainer = VBoxContainer.new()
	character_info.add_theme_constant_override("separation", 6)
	_identity_panel.add_child(character_info)
	_level_label = QuadTheme.label("LV. 1  사각형 탐험가", 22, Color("f6d794"))
	character_info.add_child(_level_label)
	_health_label = QuadTheme.label("", 16, Color("f7edd7"))
	character_info.add_child(_health_label)
	_health_bar = _rpg_bar(Color("ff6b79"), 12)
	character_info.add_child(_health_bar)
	_xp_bar = _rpg_bar(Color("74dfb0"), 7)
	character_info.add_child(_xp_bar)
	_region_panel = PanelContainer.new()
	_region_panel.add_theme_stylebox_override("panel", GameArt.panel(1, 14))
	_world_hud.add_child(_region_panel)
	var region_info: VBoxContainer = VBoxContainer.new()
	region_info.add_theme_constant_override("separation", 5)
	_region_panel.add_child(region_info)
	_world_region = QuadTheme.paragraph("초록 마을", 20, Color("f6d794"))
	_world_region.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_info.add_child(_world_region)
	_world_stats = QuadTheme.label("", 16, Color("f7edd7"))
	_world_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_info.add_child(_world_stats)
	_story_label = QuadTheme.paragraph("", 16, Color("e2e9df"))
	_story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_info.add_child(_story_label)
	_quest_panel = PanelContainer.new()
	_quest_panel.add_theme_stylebox_override("panel", GameArt.panel(1, 16))
	_world_hud.add_child(_quest_panel)
	var qv: VBoxContainer = VBoxContainer.new()
	qv.add_theme_constant_override("separation", 8)
	_quest_panel.add_child(qv)
	_quest_heading = QuadTheme.label("지금의 부탁", 18, Color("f6d794"))
	qv.add_child(_quest_heading)
	_active_quests = QuadTheme.paragraph("", 17, Color("f7edd7"))
	qv.add_child(_active_quests)
	_guidance = QuadTheme.paragraph("", 16, Color("f6d794"))
	qv.add_child(_guidance)
	_quest_open_button = _rpg_button("부탁 수첩  J", _show_journal)
	qv.add_child(_quest_open_button)
	_hud_bottom = PanelContainer.new()
	_hud_bottom.add_theme_stylebox_override("panel", GameArt.panel(1, 12))
	_world_hud.add_child(_hud_bottom)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_hud_bottom.add_child(column)
	_hud_actions = HBoxContainer.new()
	_hud_actions.add_theme_constant_override("separation", 8)
	_hud_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_hud_actions)
	_pickup_button = _rpg_button("줍기 G", _pickup_nearest, 9)
	_add_hud_action(_pickup_button, "줍기 G", true)
	_add_hud_action(_rpg_button("대화 E", func():
		if world != null: world.interact(), 15), "대화 E", true)
	_add_hud_action(_rpg_button("공격 Z / F", func():
		if world != null: world.player.begin_attack(), 14), "공격 Z / F", false)
	_potion_button = _rpg_button("회복약 Q", _use_potion, 8)
	_add_hud_action(_potion_button, "회복약 Q", false)
	_add_hud_action(_rpg_button("가방 I", _show_inventory, 11), "가방 I", true)
	_add_hud_action(_rpg_button("메뉴", _show_game_menu), "메뉴", true)
	_touch_row = HBoxContainer.new()
	_touch_row.name = "TouchMovementControls"
	_touch_row.add_theme_constant_override("separation", 10)
	column.add_child(_touch_row)
	for action: String in ["left", "right", "jump"]:
		var caption: String = str({"left": "← 왼쪽", "right": "오른쪽 →", "jump": "점프"}[action])
		var button: Button = _rpg_button(caption, Callable())
		_touch_buttons[action] = button
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_down.connect(func():
			if world != null: world.player.set_touch_control(action, true))
		button.button_up.connect(func():
			if world != null: world.player.set_touch_control(action, false))
		_touch_row.add_child(button)
	var touch_attack: Button = _rpg_button("공격", func():
		if world != null: world.player.begin_attack())
	touch_attack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_touch_buttons["attack"] = touch_attack
	_touch_row.add_child(touch_attack)
	_touch_row.visible = learning_progress.touch_controls
	_hud_controls = QuadTheme.paragraph("방향키 이동   Space 점프   G 줍기   E 대화   Z / F 공격   Q 회복   Tab 메뉴", 16, Color("e2e9df"))
	_hud_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hud_controls)
	for panel: PanelContainer in [_identity_panel, _region_panel, _quest_panel, _hud_bottom]:
		panel.minimum_size_changed.connect(func(): call_deferred("_fit_hud_heights"))

func _add_hud_action(button: Button, caption: String, keep_compact: bool) -> void:
	button.set_meta("caption", caption)
	button.set_meta("compact", keep_compact)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_buttons.append(button)
	_hud_actions.add_child(button)

func _layout_hud(area: Vector2) -> void:
	if _identity_panel == null: return
	_compact_hud = area.x < 1180.0
	var touch_compact: bool = _compact_hud and learning_progress.touch_controls
	var narrow: bool = area.x < 640.0
	var gutter: float = 12.0 if _compact_hud else 20.0
	var identity_width: float = minf(306.0, area.x - gutter * 2.0)
	_identity_panel.position = Vector2(gutter, gutter)
	_identity_panel.size = Vector2(identity_width, 116)
	var region_width: float = area.x - gutter * 2.0 if narrow else (area.x - identity_width - gutter * 3.0 if _compact_hud else 360.0)
	_region_panel.position = Vector2(gutter if narrow else (area.x - region_width - gutter if _compact_hud else area.x * 0.5 - 180.0), 136.0 if narrow else gutter)
	_region_panel.size = Vector2(region_width, 90.0)
	_story_label.visible = not _compact_hud
	_quest_heading.visible = not _compact_hud
	_quest_open_button.visible = not _compact_hud
	_active_quests.visible = not touch_compact
	_quest_panel.position = Vector2(gutter if _compact_hud else area.x - 340.0 - gutter, 240.0 if narrow else (144.0 if _compact_hud else gutter))
	_quest_panel.size = Vector2(minf(470.0, area.x - gutter * 2.0) if _compact_hud else 340.0, 0)
	var bottom_height: float = 120.0 if narrow else 104.0
	var hotbar_width: float = minf(1000.0, area.x - gutter * 2.0)
	_hud_bottom.position = Vector2((area.x - hotbar_width) * 0.5, area.y - bottom_height - gutter)
	_hud_bottom.size = Vector2(hotbar_width, bottom_height)
	for button: Button in _hud_buttons:
		var show_button: bool = not _compact_hud or bool(button.get_meta("compact", false))
		button.visible = show_button
		button.icon = button.get_meta("art_icon") if not _compact_hud and button.has_meta("art_icon") else null
		button.add_theme_font_size_override("font_size", 17 if _compact_hud else 18)
		button.text = str(button.get_meta("caption", button.text))
	if _potion_button != null: _potion_button.text = "회복약 %d  Q" % adventure.potions
	_hud_controls.text = "방향키 이동 · Space 점프\nZ / F 공격 · Q 회복 · Tab 메뉴" if _compact_hud else "방향키 이동   Space 점프   G 줍기   E 대화   Z / F 공격   Q 회복   Tab 메뉴"
	_hud_controls.visible = not learning_progress.touch_controls
	call_deferred("_fit_hud_heights")

func _fit_hud_heights() -> void:
	# Wrapped text can become shorter after a resize; positioned panels must shrink too.
	for panel: PanelContainer in [_identity_panel, _region_panel, _quest_panel]:
		panel.size.y = panel.get_combined_minimum_size().y
	var gutter: float = 12.0 if _compact_hud else 20.0
	_hud_bottom.size.y = _hud_bottom.get_combined_minimum_size().y
	_hud_bottom.position.y = _ui_size().y - _hud_bottom.size.y - gutter

func _rpg_bar(tint: Color, height: float) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(250, height)
	bar.show_percentage = false
	var back: StyleBoxTexture = GameArt.panel(1, 0)
	var fill: StyleBoxTexture = StarfrontArt.panel(6 if tint.r > tint.g else 7, 0)
	fill.texture = StarfrontArt.interior(6 if tint.r > tint.g else 7)
	for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: fill.set_texture_margin(edge, 0.0)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _rpg_button(text: String, callback: Callable, item_index: int = -1) -> Button:
	var button: Button = QuadTheme.button(text, callback)
	ButtonArt.apply(button, false, 18)
	button.focus_mode = Control.FOCUS_NONE
	if item_index >= 0:
		button.icon = GameArt.item(item_index)
		button.set_meta("art_icon", button.icon)
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
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		ButtonArt.apply(b, key == kind, 18)

func _choose_color(color: Color) -> void:
	workshop.set_paint_color(color)
	document.set_color(color)
	for i: int in range(_swatches.size()):
		var c: Color = QuadTheme.COLORS[i]
		_swatches[i].text = "●" if c.is_equal_approx(color) else ""
		var ink: Color = Color("213b42") if c.get_luminance() > 0.55 else Color.WHITE
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			_swatches[i].add_theme_color_override(state, ink)

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
		ButtonArt.apply(b, id == document.template_id, 18)
	var selected: Dictionary = document.get_selected()
	if selected.is_empty():
		_inspector.text = "도형을 누르면 변의 길이와 각을 살펴볼 수 있어요.\n\n돌리거나 크기를 바꿔도 선택한 사각형의 성질은 유지돼요."
	else:
		var vertices: PackedVector2Array = selected["vertices"]
		var lengths: PackedFloat32Array = QuadrilateralMath.side_lengths(vertices)
		var length_text: PackedStringArray = PackedStringArray()
		var angle_text: PackedStringArray = PackedStringArray()
		for length: float in lengths: length_text.append(QuadrilateralMath.measurement_label(length / 20.0))
		for angle: float in QuadrilateralMath.angles(vertices): angle_text.append(QuadrilateralMath.measurement_label(angle) + "°")
		_inspector.text = "%s\n\n변 ㄱㄴ · ㄴㄷ · ㄷㄹ · ㄹㄱ (칸)\n%s\n\n각 ㄱ · ㄴ · ㄷ · ㄹ\n%s\n\n%s" % [QuadrilateralMath.kind_label(String(selected["kind"])), " · ".join(length_text), " · ".join(angle_text), QuadrilateralMath.property_summary(vertices)]
	if not _restoring and _autosave != null: _autosave.start()

func _journal_changed() -> void:
	if _world_stats == null: return
	_world_stats.text = "%d 코인   ·   친구 %d / %d" % [journal.coins, journal.completed_count(), QuestCatalog.all_quests().size()]
	var lines: PackedStringArray = PackedStringArray()
	for quest: Dictionary in QuestCatalog.all_quests():
		var id: String = String(quest["id"])
		var state: String = journal.quest_state(id)
		if state == "active" or state == "ready":
			lines.append(("● " if state == "ready" else "· ") + journal.progress_text(id))
	var shown_count: int = 1 if _compact_hud else 3
	if lines.size() > shown_count:
		var remaining: int = lines.size() - shown_count
		lines.resize(shown_count)
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
	var use_button: Button = QuadTheme.button("회복약 사용", func():
		_use_potion()
		_show_inventory(), true)
	use_button.disabled = adventure.potions <= 0 or adventure.hp >= adventure.max_hp
	medicine.add_child(use_button)
	if use_button.disabled:
		medicine.add_child(QuadTheme.paragraph("체력이 가득해요. 다쳤을 때 사용해요." if adventure.hp >= adventure.max_hp else "회복약이 없어요. 초록 마을 잡화점에서 살 수 있어요.", 17))
	body.add_child(QuadTheme.label("퀘스트 물품", 22))
	var slots: GridContainer = GridContainer.new()
	slots.columns = 2 if _ui_size().x < 850.0 else 3
	slots.add_theme_constant_override("h_separation", 10)
	slots.add_theme_constant_override("v_separation", 10)
	body.add_child(slots)
	var found: bool = false
	for quest: Dictionary in QuestCatalog.all_quests():
		var target: String = String(quest["target"])
		var count: int = int(journal.inventory.get(target, 0))
		if count <= 0: continue
		found = true
		var slot: PanelContainer = PanelContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_stylebox_override("panel", StarfrontArt.panel(4, 12))
		slots.add_child(slot)
		var content: VBoxContainer = VBoxContainer.new()
		content.add_theme_constant_override("separation", 6)
		slot.add_child(content)
		content.add_child(GameArt.view(GameArt.quest_item(quest), Vector2(52, 52)))
		content.add_child(QuadTheme.paragraph("%s × %d" % [str(quest["item_name"]), count], 17, QuadTheme.INK))
		content.add_child(QuadTheme.paragraph("전달 준비 완료" if journal.can_turn_in(str(quest["id"])) else "모은 물건", 15, QuadTheme.TEAL))
	if not found:
		body.add_child(QuadTheme.paragraph("아직 모은 물건이 없어요. 빛나는 물건 옆에서 G를 누르거나 가까이 다가가 주워요. 부탁을 받기 전에도 모을 수 있어요.", 17))
	body.add_child(QuadTheme.button("부탁 수첩에서 필요한 물건 보기", _show_journal, true))
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
	world.peaceful = learning_progress.peaceful
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
	body.add_theme_constant_override("separation", 10)
	var portrait_row: HBoxContainer = HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 20)
	portrait_row.add_child(GameArt.view(GameArt.quest_npc(quest), Vector2(60, 68)))
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
		portrait_row.hide()
		body.add_child(QuadTheme.paragraph(String(quest["question"]), 20, QuadTheme.INK))
		var diagram: LearningCanvas = LearningCanvas.new()
		diagram.configure_question(id)
		body.add_child(diagram)
		var measurements: Label = QuadTheme.paragraph("", 16, QuadTheme.INK)
		measurements.hide()
		body.add_child(QuadTheme.button("변·각 살펴보기", func():
			diagram.measure()
			measurements.show()
			measurements.text = diagram.measurement_text()))
		body.add_child(measurements)
		var feedback: Label = QuadTheme.paragraph("", 16, QuadTheme.TEAL)
		feedback.hide()
		var options: Array = quest["options"]
		for index: int in range(options.size()):
			var button: Button = QuadTheme.button(String(options[index]), Callable())
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.pressed.connect(func():
				var answer: Dictionary = journal.answer_quest(id, index)
				feedback.text = String(answer["message"])
				feedback.show()
				if bool(answer["correct"]):
					_sound.play_fanfare()
					_show_quest_success(quest, answer)
				else: _sound.play_click())
			body.add_child(button)
		body.add_child(feedback)
	else:
		body.add_child(QuadTheme.paragraph(String(quest["description"]), 18, QuadTheme.INK))
		if str(quest.get("story_description", "")) != str(quest.description):
			body.add_child(QuadTheme.button("이야기 더 읽기", func():
				var story: VBoxContainer = _open_modal(str(quest.npc_name) + "의 이야기")
				story.add_child(QuadTheme.paragraph(str(quest.story_description), 19, QuadTheme.INK))
				story.add_child(QuadTheme.button("부탁으로 돌아가기", _show_quest_dialog.bind(quest), true))))
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

func _show_game_menu() -> void:
	var body: VBoxContainer = _open_modal("모험 메뉴")
	var peaceful: CheckButton = CheckButton.new()
	peaceful.text = "편안한 탐험 · 몬스터에 닿아도 다치지 않아요"
	ButtonArt.apply(peaceful)
	peaceful.custom_minimum_size.y = 48
	peaceful.button_pressed = learning_progress.peaceful
	peaceful.toggled.connect(func(enabled: bool):
		learning_progress.peaceful = enabled
		learning_progress.changed.emit())
	body.add_child(peaceful)
	var touch: CheckButton = CheckButton.new()
	touch.text = "화면에 이동·점프 버튼 표시"
	ButtonArt.apply(touch)
	touch.custom_minimum_size.y = 48
	touch.button_pressed = learning_progress.touch_controls
	touch.toggled.connect(func(enabled: bool):
		learning_progress.touch_controls = enabled
		learning_progress.changed.emit())
	body.add_child(touch)
	body.add_child(QuadTheme.button("수학 직접 해 보기", _show_learning))
	body.add_child(QuadTheme.paragraph("방향키 / A·D 이동 · Space 점프\nG 줍기 · E 대화 · Z / F 공격 · Q 회복약\nTab으로 버튼 이동 · Enter 선택 · Esc 닫기", 18, QuadTheme.INK))
	body.add_child(QuadTheme.button("부탁 수첩  J", _show_journal, true))
	body.add_child(QuadTheme.button("여행 지도  M", _show_map))
	body.add_child(QuadTheme.button("모험가의 가방  I", _show_inventory))
	body.add_child(QuadTheme.button("이야기 수첩  H", _show_story))
	body.add_child(QuadTheme.button("사각형 도감", _show_notebook))
	body.add_child(QuadTheme.button("조작 방법", _show_controls))
	body.add_child(QuadTheme.button("캐릭터 공방으로", _return_workshop))
	body.add_child(QuadTheme.button("모험 계속하기", _close_modal))

func _show_controls() -> void:
	var body: VBoxContainer = _open_modal("조작 방법")
	body.add_child(QuadTheme.paragraph("방향키 / A·D로 좌우 이동\nSpace / W / 위쪽 방향키로 점프\nG로 가까운 물건 줍기 · E로 주민과 대화\nZ / F로 바라보는 방향 공격\nQ로 회복약 사용", 20, QuadTheme.INK))
	body.add_child(QuadTheme.paragraph("가방 I · 부탁 수첩 J · 지도 M · 이야기 H\nTab / Esc로 메뉴 열기\n메뉴에서는 Tab으로 이동 · Enter로 선택 · Esc로 닫기", 18, QuadTheme.INK))
	body.add_child(QuadTheme.paragraph("물건은 가까이 닿아도 모을 수 있어요. 부탁을 받기 전에 주워도 괜찮아요. 위쪽 물건은 발판에 올라가 찾아보세요.", 18))
	body.add_child(QuadTheme.button("모험 계속하기", _close_modal, true))

func _show_journal(filter: String = "active") -> void:
	_journal_filter = filter if filter in ["active", "available", "completed", "all"] else "active"
	var body: VBoxContainer = _open_modal("나의 부탁 수첩")
	body.add_child(QuadTheme.paragraph("물건을 다 모으면 주민에게 돌아가 도형 이야기를 나눠요. ‘이 목표 안내’를 누르면 가는 방향을 알려 줘요.", 17))
	var filters: HFlowContainer = HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 8)
	filters.add_theme_constant_override("v_separation", 8)
	body.add_child(filters)
	var captions: Dictionary = {"active": "진행 중", "available": "새 부탁", "completed": "완료", "all": "전체"}
	var counts: Dictionary = {"active": 0, "available": 0, "completed": 0, "all": QuestCatalog.all_quests().size()}
	for quest: Dictionary in QuestCatalog.all_quests():
		var state: String = journal.quest_state(str(quest["id"]))
		var group: String = "active" if state == "ready" else state
		counts[group] = int(counts[group]) + 1
	for key: String in ["active", "available", "completed", "all"]:
		filters.add_child(QuadTheme.button("%s%s %d" % ["● " if key == _journal_filter else "", captions[key], counts[key]], func(): _show_journal(key), key == _journal_filter))
	var shown: int = 0
	for quest: Dictionary in QuestCatalog.all_quests():
		var state: String = journal.quest_state(String(quest["id"]))
		var group: String = "active" if state == "ready" else state
		if _journal_filter != "all" and _journal_filter != group: continue
		shown += 1
		var status: String = {"available": "아직 만나지 않았어요", "active": "탐험 중", "ready": "주민에게 돌아가요", "completed": "완료"}.get(state, "")
		var card: VBoxContainer = QuadTheme.card(body, Color("edf5ef"), 14)
		card.add_child(QuadTheme.paragraph(String(quest["npc_name"]) + "  ·  " + status, 17, QuadTheme.TEAL))
		card.add_child(QuadTheme.paragraph(String(quest["title"]), 21, QuadTheme.INK))
		card.add_child(QuadTheme.paragraph(journal.progress_text(String(quest["id"])), 17))
		if state == "completed": card.add_child(QuadTheme.paragraph(String(quest["explanation"]), 17))
		else: card.add_child(QuadTheme.button("이 목표 안내", func():
			_tracked_quest = str(quest["id"])
			_close_modal()
			_refresh_world_guidance()))
	if shown == 0:
		body.add_child(QuadTheme.paragraph("진행 중인 부탁이 없어요. 지도에서 주민을 찾고 E로 이야기해 보세요." if _journal_filter == "active" else "이곳에 기록된 부탁이 아직 없어요. 새로운 친구를 만나 보세요.", 18, QuadTheme.INK))
		body.add_child(QuadTheme.button("지도에서 주민 찾기", _show_map, true))
	body.add_child(QuadTheme.button("여섯 지역의 이야기 보기", _show_story))
	body.add_child(QuadTheme.button("모험 계속하기", _close_modal))

func _show_notebook() -> void:
	var body: VBoxContainer = _open_modal("사각형 탐험 도감")
	body.add_child(QuadTheme.paragraph("색과 방향보다 변과 각을 살펴봐요. 주제를 골라 직접 재고 확인할 수 있어요.", 18))
	for id: String in LearningCatalog.IDS:
		var entry: Dictionary = LearningCatalog.lesson(id)
		var title: String = str(entry.title)
		var done: String = " · 활동 완료" if learning_progress.completed.has(id) else ""
		var button: Button = QuadTheme.button(title + done + "\n" + str(entry.goal), func(): _show_learning(id))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(button)
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
	_clear_touch_inputs()
	if not is_instance_valid(_modal_overlay):
		_modal_focus_before = get_viewport().gui_get_focus_owner()
	_close_modal(false)
	if world != null and _in_world: world.set_controls_enabled(false)
	_modal_overlay = Control.new()
	_modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_modal_overlay)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.09, 0.17, 0.2, 0.52)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.add_child(dim)
	_modal_panel = PanelContainer.new()
	_modal_panel.add_theme_stylebox_override("panel", QuadTheme.style(QuadTheme.PAPER, 22, QuadTheme.BORDER, 20))
	_modal_overlay.add_child(_modal_panel)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	_modal_panel.add_child(outer)
	var header: HBoxContainer = HBoxContainer.new()
	outer.add_child(header)
	var heading: Label = QuadTheme.paragraph(title, 23, QuadTheme.INK)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_modal_close = QuadTheme.button("닫기 Esc", _close_modal)
	_modal_close.custom_minimum_size.x = 124.0
	header.add_child(_modal_close)
	_modal_scroll = ScrollContainer.new()
	_modal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal_scroll.follow_focus = true
	outer.add_child(_modal_scroll)
	_modal_body = VBoxContainer.new()
	_modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_body.add_theme_constant_override("separation", 18)
	_modal_scroll.add_child(_modal_body)
	_layout_modal()
	call_deferred("_focus_modal")
	return _modal_body

func _layout_modal() -> void:
	if not is_instance_valid(_modal_panel): return
	var area: Vector2 = _ui_size()
	var margin: float = 12.0 if area.x < 640.0 else 24.0
	var panel_size: Vector2 = Vector2(minf(760.0, area.x - margin * 2.0), minf(680.0, area.y - margin * 2.0))
	_fit_modal_content(_modal_panel, maxf(100.0, panel_size.x - 64.0))
	_modal_panel.size = panel_size
	_modal_panel.position = (area - panel_size) * 0.5

func _fit_modal_content(parent: Node, width: float) -> void:
	for child: Node in parent.get_children():
		if child is Control:
			var control: Control = child as Control
			if control.custom_minimum_size.x > width:
				control.custom_minimum_size.x = width
		if child is Label:
			var label: Label = child as Label
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if label.get_theme_font_size("font_size") < 16:
				label.add_theme_font_size_override("font_size", 17)
		elif child is Button:
			var button: Button = child as Button
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size.y = maxf(48.0, button.custom_minimum_size.y)
			if parent is HFlowContainer:
				button.custom_minimum_size.x = minf(width, QuadTheme.FONT.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 40.0)
		_fit_modal_content(child, width)

func _focus_modal() -> void:
	if not is_instance_valid(_modal_overlay): return
	_layout_modal()
	var controls: Array[Control] = []
	for node: Node in _modal_panel.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control.focus_mode != Control.FOCUS_ALL or not control.is_visible_in_tree(): continue
		if control is BaseButton and (control as BaseButton).disabled: continue
		controls.append(control)
	if controls.is_empty(): return
	for index: int in range(controls.size()):
		var control: Control = controls[index]
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = control.get_path_to(controls[(index - 1 + controls.size()) % controls.size()])
	_modal_close.grab_focus()

func _close_modal(restore_focus: bool = true) -> void:
	if is_instance_valid(_modal_overlay):
		_modal_overlay.hide()
		_modal_overlay.queue_free()
		_modal_overlay = null
	_modal_panel = null
	_modal_scroll = null
	_modal_close = null
	if restore_focus:
		if is_instance_valid(_modal_focus_before) and _modal_focus_before.is_visible_in_tree():
			_modal_focus_before.grab_focus()
		_modal_focus_before = null
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
		dialog.theme = _ui.theme
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
	if _ui == null or _ui_layer == null: return
	var window: Window = get_window()
	var creation_visible: bool = is_instance_valid(_home_screen) and (_home_screen.visible or _drawing_screen.visible or _construction_screen.visible or (is_instance_valid(_learning_screen) and _learning_screen.visible))
	var desired_size: Vector2i = Vector2i(maxi(window.size.x, 800), maxi(window.size.y, 600)) if creation_visible else Vector2i(1600, 900)
	if window.content_scale_size != desired_size:
		window.content_scale_size = desired_size
	# Counter only the UI stretch. World coordinates and player artwork stay intact.
	var stretch: Vector2 = get_viewport().get_stretch_transform().get_scale()
	stretch = Vector2(maxf(stretch.x, 0.01), maxf(stretch.y, 0.01))
	_ui_scale = 1.0 / stretch.y
	_ui_layer.scale = Vector2(1.0 / stretch.x, 1.0 / stretch.y)
	_ui.position = Vector2.ZERO
	_ui.size = get_viewport().get_visible_rect().size * stretch
	_layout_workshop(_ui.size)
	_layout_hud(_ui.size)
	_layout_modal()
	if _toast != null:
		var toast_width: float = minf(740.0, _ui.size.x - 32.0)
		_toast.offset_left = -toast_width * 0.5
		_toast.offset_right = toast_width * 0.5
		_toast.offset_top = -214.0 if _compact_hud else -194.0
		_toast.offset_bottom = -144.0 if _compact_hud else -124.0
		if learning_progress.touch_controls and _compact_hud:
			_toast.offset_top = -300.0
			_toast.offset_bottom = -240.0
		_toast.add_theme_font_size_override("font_size", 17)
	_journal_changed()
	_refresh_world_guidance()

func _ui_size() -> Vector2:
	return _ui.size if _ui != null and _ui.size.x > 0.0 else get_viewport().get_visible_rect().size

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_screen_touch(event)
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE and is_instance_valid(_modal_overlay):
		_close_modal()
		get_viewport().set_input_as_handled()
	elif _in_world and not is_instance_valid(_modal_overlay) and event.keycode in [KEY_TAB, KEY_ESCAPE]:
		_show_game_menu()
		get_viewport().set_input_as_handled()

func _handle_screen_touch(event: InputEvent) -> void:
	var index: int = event.index
	if event is InputEventScreenTouch and not event.pressed:
		if not _touch_fingers.has(index): return
		_touch_fingers.erase(index)
		_sync_touch_fingers()
		get_viewport().set_input_as_handled()
		return
	if not _in_world or world == null or not learning_progress.touch_controls or is_instance_valid(_modal_overlay): return
	var action: String = ""
	for id: String in _touch_buttons:
		var button: Button = _touch_buttons[id]
		var local: Vector2 = button.get_global_transform_with_canvas().affine_inverse() * event.position
		if button.is_visible_in_tree() and Rect2(Vector2.ZERO, button.size).has_point(local):
			action = id
			break
	if action.is_empty() and not _touch_fingers.has(index): return
	var previous: String = str(_touch_fingers.get(index, ""))
	_touch_fingers[index] = action
	_sync_touch_fingers()
	if action == "attack" and previous != action: world.player.begin_attack()
	get_viewport().set_input_as_handled()

func _sync_touch_fingers() -> void:
	if world == null: return
	for action: String in ["left", "right", "jump"]:
		world.player.set_touch_control(action, _touch_fingers.values().has(action))

func _clear_touch_inputs() -> void:
	_touch_fingers.clear()
	if world != null: world.player.clear_touch_controls()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _clear_touch_inputs()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if _drawing_screen.visible or _construction_screen.visible or (is_instance_valid(_learning_screen) and _learning_screen.visible): return
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
