class_name SpaceHangar
extends Control

signal purchase_requested(part_id: String)
signal design_requested(part_id: String, kind: String, color: String)
signal launch_requested
signal home_requested
signal drawing_requested
signal construction_requested
signal village_requested

const Catalog: GDScript = preload("res://scripts/economy/spaceship_catalog.gd")
const ShipCanvas: GDScript = preload("res://scenes/space/spaceship_canvas.gd")
const Money: GDScript = preload("res://scripts/construction/construction_catalog.gd")
const Art: GDScript = preload("res://scripts/construction_art.gd")

var state: ConstructionState
var managed_endings: bool = false
var ending_saved: bool = false
var canvas: SpaceshipCanvas
var _selected_id: String = "hull"
var _part_buttons: Dictionary = {}
var _balance: Label
var _progress: Label
var _detail: Label
var _design_row: HFlowContainer
var _design_shape: OptionButton
var _design_color: ColorPickerButton
var _apply_design: Button
var _purchase: Button
var _launch: Button
var _status: Label
var _workspace: HBoxContainer
var _list_scroll: ScrollContainer
var _ship_panel: PanelContainer
var _confirmation: ConfirmationDialog
var _pending_part: String = ""
var _launch_panel: Control
var _launch_canvas: SpaceshipCanvas
var _launch_home: Button
var _launch_skip: Button
var _launch_clock: float = -1.0
var _launch_done: bool = false
var _content: MarginContainer
var _page_scroll: ScrollContainer
var _focus_before_confirm: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: TextureRect = TextureRect.new()
	background.texture = StarfrontArt.scene(6)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color("7a8c9c")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_content = MarginContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]: _content.add_theme_constant_override("margin_" + edge, 12)
	add_child(_content)
	_page_scroll = ScrollContainer.new()
	_page_scroll.name = "HangarScroll"
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_scroll.follow_focus = true
	_content.add_child(_page_scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	_page_scroll.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)
	header.add_child(QuadTheme.button("← 메인", func(): home_requested.emit()))
	var title: Label = QuadTheme.paragraph("별빛 귀향선 제작소", 27, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var funds: VBoxContainer = QuadTheme.card(column, Color("182432"), 10)
	funds.add_theme_constant_override("separation", 3)
	_balance = QuadTheme.paragraph("", 19, Art.GOLD)
	funds.add_child(_balance)
	_progress = QuadTheme.paragraph("", 16, Art.INK)
	funds.add_child(_progress)
	_workspace = HBoxContainer.new()
	_workspace.add_theme_constant_override("separation", 10)
	_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_workspace)
	_ship_panel = PanelContainer.new()
	_ship_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_panel.add_theme_stylebox_override("panel", Art.panel(false, 8))
	_workspace.add_child(_ship_panel)
	canvas = ShipCanvas.new()
	canvas.name = "ShipAssembly"
	canvas.custom_minimum_size = Vector2(230, 220)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.part_selected.connect(_select_part)
	_ship_panel.add_child(canvas)
	_list_scroll = ScrollContainer.new()
	_list_scroll.custom_minimum_size.x = 300
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.follow_focus = true
	_workspace.add_child(_list_scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	_list_scroll.add_child(list)
	for part_info: Dictionary in Catalog.all_parts():
		var id: String = str(part_info.id)
		var button: Button = QuadTheme.button("", func(): _select_part(id))
		button.name = "ShipPart_" + id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.icon = QuadTheme.icon(str(part_info.kind))
		button.add_theme_font_size_override("font_size", 16)
		button.custom_minimum_size.y = 62
		list.add_child(button)
		_part_buttons[id] = button
	var detail_panel: VBoxContainer = QuadTheme.card(column, Color("182432"), 10)
	detail_panel.add_theme_constant_override("separation", 5)
	_detail = QuadTheme.paragraph("", 16, Art.INK)
	detail_panel.add_child(_detail)
	_build_design_controls(detail_panel)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	detail_panel.add_child(actions)
	_purchase = QuadTheme.button("부품 구매", _ask_purchase, true)
	_purchase.name = "BuyShipPart"
	_purchase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_purchase)
	_launch = QuadTheme.button("모든 부품을 모으면 출발", _request_launch, true)
	_launch.name = "LaunchShip"
	_launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_launch)
	var earn_row: HFlowContainer = HFlowContainer.new()
	earn_row.add_theme_constant_override("h_separation", 8)
	column.add_child(earn_row)
	earn_row.add_child(QuadTheme.button("그림 그려 돈 모으기", func(): drawing_requested.emit()))
	earn_row.add_child(QuadTheme.button("집 지어 돈 모으기", func(): construction_requested.emit()))
	earn_row.add_child(QuadTheme.button("마을 주민 심부름하기", func(): village_requested.emit()))
	_status = QuadTheme.paragraph("부품을 하나씩 모아 사각형 행성으로 돌아가요.", 15, Art.INK)
	column.add_child(_status)
	_build_confirmation()
	_build_launch_panel()
	resized.connect(_responsive)
	visibility_changed.connect(_visibility_changed)
	if state != null: state.changed.connect(refresh)
	refresh()
	_responsive()
	set_process(false)

func _build_design_controls(parent: VBoxContainer) -> void:
	_design_row = HFlowContainer.new()
	_design_row.add_theme_constant_override("h_separation", 8)
	_design_row.add_theme_constant_override("v_separation", 5)
	parent.add_child(_design_row)
	var shape_label: Label = QuadTheme.paragraph("부품 모양", 16, Art.INK)
	shape_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_design_row.add_child(shape_label)
	_design_shape = OptionButton.new()
	_design_shape.name = "ShipPartShape"
	_design_shape.add_theme_font_override("font", QuadTheme.FONT)
	_design_shape.custom_minimum_size = Vector2(150, 42)
	ButtonArt.apply(_design_shape)
	for kind: String in QuadrilateralMath.KINDS:
		_design_shape.add_item(QuadrilateralMath.kind_name(kind))
	_design_shape.item_selected.connect(func(_index: int): _preview_design())
	_design_row.add_child(_design_shape)
	var color_label: Label = QuadTheme.paragraph("부품 색", 16, Art.INK)
	color_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_design_row.add_child(color_label)
	_design_color = ColorPickerButton.new()
	_design_color.name = "ShipPartColor"
	_design_color.edit_alpha = false
	_design_color.custom_minimum_size = Vector2(58, 42)
	_design_color.tooltip_text = "부품 색 고르기"
	ButtonArt.apply(_design_color)
	_design_color.color_changed.connect(func(_color: Color): _preview_design())
	_design_row.add_child(_design_color)
	_apply_design = QuadTheme.button("모양과 색 저장", _request_design, true)
	_apply_design.name = "SaveShipPartDesign"
	_design_row.add_child(_apply_design)

func _build_confirmation() -> void:
	_confirmation = ConfirmationDialog.new()
	_confirmation.name = "ConfirmShipPurchase"
	_confirmation.title = "우주선 부품 구매"
	_confirmation.dialog_autowrap = true
	_confirmation.ok_button_text = "이 부품 구매하기"
	_confirmation.cancel_button_text = "취소"
	_confirmation.min_size = Vector2i(340, 180)
	_confirmation.add_theme_font_override("font", QuadTheme.FONT)
	_confirmation.add_theme_font_size_override("font_size", 18)
	_confirmation.add_theme_stylebox_override("panel", Art.panel(false, 18))
	ButtonArt.apply(_confirmation.get_ok_button(), true)
	ButtonArt.apply(_confirmation.get_cancel_button(), false)
	_confirmation.confirmed.connect(_confirm_purchase)
	_confirmation.canceled.connect(func(): _pending_part = "")
	_confirmation.visibility_changed.connect(func():
		if not _confirmation.visible and is_instance_valid(_focus_before_confirm) and is_visible_in_tree():
			_focus_before_confirm.grab_focus())
	add_child(_confirmation)

func _build_launch_panel() -> void:
	_launch_panel = Control.new()
	_launch_panel.name = "HomecomingScene"
	_launch_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_launch_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_launch_panel)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("091622")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_launch_panel.add_child(backdrop)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 16)
	_launch_panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	column.add_child(QuadTheme.paragraph("내 그림과 내가 지은 집으로 이룬 꿈", 25, Art.GOLD))
	_launch_canvas = ShipCanvas.new()
	_launch_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_launch_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_launch_canvas)
	var thanks: Label = QuadTheme.paragraph("함께해 줘서 고마워요. 돌아온 뒤에도 그림과 집을 계속 만들 수 있어요.", 18, Art.INK)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(thanks)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	_launch_skip = QuadTheme.button("도착 장면으로 · Esc", _finish_launch)
	row.add_child(_launch_skip)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_launch_home = QuadTheme.button("메인으로 돌아가기", func(): home_requested.emit(), true)
	row.add_child(_launch_home)
	_launch_panel.hide()

func refresh() -> void:
	if not is_instance_valid(canvas) or state == null: return
	canvas.set_parts(state.purchased_ship_parts)
	canvas.set_design(state.ship_design)
	canvas.selected_part_id = _selected_id
	_balance.text = "부품 구매에 쓸 수 있는 돈  %s" % Money.format_won(state.ship_available_funds())
	_progress.text = "조립 %d / 12개 · 구매한 부품 %s / 총 12억 원\n건축 운영비 3천만 원과 내 집에 사용한 돈은 남겨 둬요." % [state.purchased_ship_parts.size(), Money.format_won(state.ship_spent())]
	for id: String in _part_buttons:
		var button: Button = _part_buttons[id]
		var item: Dictionary = Catalog.part(id)
		var owned: bool = state.purchased_ship_parts.has(id)
		var part_selection: Dictionary = state.ship_design.get(id, {})
		button.icon = QuadTheme.icon(str(part_selection.get("kind", item.kind)))
		button.text = "%s %s\n%s" % ["✓" if owned else "□", str(item.name), "구매 완료" if owned else Money.format_won(int(item.price))]
		button.set_pressed_no_signal(id == _selected_id)
	var selected: Dictionary = Catalog.part(_selected_id)
	var bought: bool = state.purchased_ship_parts.has(_selected_id)
	var selection: Dictionary = state.ship_design.get(_selected_id, {})
	var current_kind: String = str(selection.get("kind", selected.kind))
	var current_color: Color = Color(str(selection.color)) if selection.has("color") else Color(selected.color)
	var missing: int = maxi(0, int(selected.price) - state.ship_available_funds())
	_set_part_detail(selected, current_kind)
	_design_row.visible = bought
	_design_shape.select(QuadrilateralMath.KINDS.find(current_kind))
	_design_color.color = current_color
	_apply_design.disabled = true
	_purchase.disabled = bought or missing > 0
	_purchase.text = "이미 조립한 부품" if bought else ("%s 더 모으면 구매" % Money.format_won(missing) if missing > 0 else "선택한 부품 구매")
	_launch.disabled = not state.ship_complete()
	var replay: bool = ending_saved or state.launched
	_launch.text = "엔딩 다시 보기" if replay else ("완성하고 엔딩 보기" if state.ship_complete() else "12개를 모두 모으면 완성")
	canvas.queue_redraw()
	if _confirmation.visible:
		var pending: Dictionary = Catalog.part(_pending_part)
		_confirmation.get_ok_button().disabled = pending.is_empty() or state.purchased_ship_parts.has(_pending_part) or state.ship_available_funds() < int(pending.get("price", 0))

func _select_part(id: String) -> void:
	if Catalog.part(id).is_empty() or _launch_panel.visible: return
	_selected_id = id
	refresh()

func _preview_design() -> void:
	if state == null or not state.purchased_ship_parts.has(_selected_id) or _launch_panel.visible: return
	var kind: String = QuadrilateralMath.KINDS[_design_shape.selected]
	var color: String = _design_color.color.to_html(false)
	var actual: Dictionary = Catalog.part(_selected_id)
	var current: Dictionary = state.ship_design.get(_selected_id, {})
	var default_color: Color = actual.color
	_apply_design.disabled = kind == current.get("kind", actual.kind) and color == current.get("color", default_color.to_html(false))
	_set_part_detail(actual, kind)
	var preview: Dictionary = state.ship_design.duplicate(true)
	preview[_selected_id] = {"kind": kind, "color": color}
	canvas.set_design(preview)

func _set_part_detail(item: Dictionary, kind: String) -> void:
	_detail.text = "%s · %s · %s\n%s" % [str(item.name), QuadrilateralMath.kind_name(kind), Money.format_won(int(item.price)), str(item.description)]

func _request_design() -> void:
	if state == null or not is_visible_in_tree() or _launch_panel.visible or _apply_design.disabled:
		return
	if not state.purchased_ship_parts.has(_selected_id): return
	design_requested.emit(_selected_id, QuadrilateralMath.KINDS[_design_shape.selected], _design_color.color.to_html(false))

func _ask_purchase() -> void:
	if state == null or _purchase.disabled or _launch_panel.visible: return
	_pending_part = _selected_id
	var item: Dictionary = Catalog.part(_pending_part)
	_confirmation.dialog_text = "%s을(를) %s에 구매할까요?\n구매 후 남는 제작비: %s\n한 번 구매한 부품은 계속 사용할 수 있어요." % [str(item.name), Money.format_won(int(item.price)), Money.format_won(state.ship_available_funds() - int(item.price))]
	_confirmation.get_ok_button().disabled = false
	_focus_before_confirm = get_viewport().gui_get_focus_owner()
	_confirmation.popup_centered(Vector2i(mini(540, int(size.x) - 32), 220))

func _confirm_purchase() -> void:
	var id: String = _pending_part
	_pending_part = ""
	_confirmation.hide()
	if state == null or id.is_empty() or not is_visible_in_tree() or _launch_panel.visible: return
	var item: Dictionary = Catalog.part(id)
	if item.is_empty() or state.purchased_ship_parts.has(id) or state.ship_available_funds() < int(item.price):
		refresh()
		return
	purchase_requested.emit(id)

func _request_launch() -> void:
	if state == null or not state.ship_complete() or _launch_panel.visible: return
	if _design_row.visible and not _apply_design.disabled:
		_status.text = "바꾼 부품의 모양과 색을 먼저 저장해 주세요."
		_apply_design.grab_focus()
		return
	if state.launched and not managed_endings: play_launch()
	else: launch_requested.emit()

func show_transaction_result(result: Dictionary) -> void:
	_status.text = str(result.get("message", "구매한 부품을 우주선에 조립했어요.")) if bool(result.get("ok", false)) else str(result.get("error", "잠시 후 다시 시도해 주세요."))
	refresh()

func play_launch() -> void:
	if state == null or not state.ship_complete() or not state.launched: return
	_confirmation.hide()
	_pending_part = ""
	_launch_clock = 0.0
	_launch_done = false
	_launch_canvas.set_parts(state.purchased_ship_parts)
	_launch_canvas.set_design(state.ship_design)
	_launch_canvas.launch_time = 0.0
	_launch_canvas.queue_redraw()
	_launch_panel.show()
	_content.hide()
	_launch_skip.show()
	_launch_home.hide()
	_launch_skip.grab_focus()
	set_process(true)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or _launch_clock < 0.0 or _launch_done: return
	_launch_clock = minf(_launch_clock + delta, SpaceshipCanvas.LAUNCH_SECONDS)
	_launch_canvas.launch_time = _launch_clock
	_launch_canvas.queue_redraw()
	if _launch_clock >= SpaceshipCanvas.LAUNCH_SECONDS: _finish_launch()

func _finish_launch() -> void:
	if not _launch_panel.visible: return
	_launch_clock = SpaceshipCanvas.LAUNCH_SECONDS
	_launch_done = true
	_launch_canvas.launch_time = _launch_clock
	_launch_canvas.queue_redraw()
	_launch_skip.hide()
	_launch_home.show()
	_launch_home.grab_focus()
	set_process(false)

func cancel_activity() -> void:
	if is_instance_valid(_confirmation): _confirmation.hide()
	_pending_part = ""
	if is_instance_valid(_launch_panel): _launch_panel.hide()
	if is_instance_valid(_content): _content.show()
	_launch_clock = -1.0
	_launch_done = false
	set_process(false)

func _visibility_changed() -> void:
	if not is_visible_in_tree(): cancel_activity()
	else:
		refresh()
		if _part_buttons.has(_selected_id): (_part_buttons[_selected_id] as Button).grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode != KEY_ESCAPE: return
	if _confirmation.visible:
		_confirmation.hide()
		_pending_part = ""
	elif _launch_panel.visible:
		if _launch_done: home_requested.emit()
		else: _finish_launch()
	else: home_requested.emit()
	get_viewport().set_input_as_handled()

func _responsive() -> void:
	if not is_instance_valid(_list_scroll): return
	_list_scroll.custom_minimum_size.x = 290 if size.x < 1000 else 350
	if is_instance_valid(_confirmation) and _confirmation.visible:
		_confirmation.popup_centered(Vector2i(mini(540, int(size.x) - 32), 220))
