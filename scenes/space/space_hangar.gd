class_name SpaceHangar
extends Control

signal purchase_requested(part_id: String)
signal launch_requested
signal home_requested
signal drawing_requested
signal construction_requested
signal village_requested

const Catalog: GDScript = preload("res://scripts/economy/spaceship_catalog.gd")
const ShipCanvas: GDScript = preload("res://scenes/space/spaceship_canvas.gd")
const Money: GDScript = preload("res://scripts/construction/construction_catalog.gd")
const Art: GDScript = preload("res://scripts/construction_art.gd")

class ProductPreview extends Control:
	var item: Dictionary = {}

	func _draw() -> void:
		if item.is_empty(): return
		var bounds: Rect2 = QuadrilateralMath.bounds(item.vertices)
		var room: Vector2 = size - Vector2(6, 6)
		var factor: float = minf(room.x / bounds.size.x, room.y / bounds.size.y)
		var points: PackedVector2Array = PackedVector2Array()
		for vertex: Vector2 in item.vertices:
			points.append(size * 0.5 + (vertex - bounds.get_center()) * factor)
		SpaceshipCanvas.draw_installed_part(self, points, item)
		points.append(points[0])
		draw_polyline(points, Color("aac1d2"), 1.2, true)

var state: ConstructionState
var managed_endings: bool = false
var ending_saved: bool = false
var canvas: SpaceshipCanvas
var _selected_id: String = "hull"
var _selected_variant_id: String = "hull"
var _slot_picker: OptionButton
var _variant_buttons: Array[Button] = []
var _variant_previews: Array[ProductPreview] = []
var _slots: Array[Dictionary] = []
var _balance: Label
var _progress: Label
var _detail: Label
var _purchase: Button
var _launch: Button
var _status: Label
var _workspace: HBoxContainer
var _list_scroll: ScrollContainer
var _ship_panel: PanelContainer
var _confirmation: ConfirmationDialog
var _pending_part: String = ""
var _pending_price: int = -1
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
	var title: Label = QuadTheme.paragraph("사각성 귀향선 제작소", 27, Color.WHITE)
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
	_list_scroll.custom_minimum_size = Vector2(320, 342)
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.follow_focus = true
	_workspace.add_child(_list_scroll)
	_build_shop(_list_scroll)
	var detail_panel: VBoxContainer = QuadTheme.card(column, Color("182432"), 10)
	detail_panel.add_theme_constant_override("separation", 5)
	_detail = QuadTheme.paragraph("", 16, Art.INK)
	detail_panel.add_child(_detail)
	var actions: HFlowContainer = HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 6)
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
	_status = QuadTheme.paragraph("필수 부품 12종을 한 개씩 갖추면 사각성으로 출발할 수 있어요.", 15, Art.INK)
	column.add_child(_status)
	_build_confirmation()
	_build_launch_panel()
	resized.connect(_responsive)
	visibility_changed.connect(_visibility_changed)
	if state != null: state.changed.connect(refresh)
	refresh()
	_responsive()
	set_process(false)

func _build_shop(parent: ScrollContainer) -> void:
	var rail: VBoxContainer = VBoxContainer.new()
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(rail)
	var list: VBoxContainer = QuadTheme.card(rail, Color("182432"), 10)
	list.add_theme_constant_override("separation", 6)
	list.add_child(QuadTheme.paragraph("필수 부품 고르기", 19, Art.GOLD))
	_slot_picker = OptionButton.new()
	_slot_picker.name = "ShipPartSlot"
	_slot_picker.tooltip_text = "우주선에 필요한 12종류의 부품"
	_slot_picker.custom_minimum_size.y = 44
	_slot_picker.add_theme_font_override("font", QuadTheme.FONT)
	ButtonArt.apply(_slot_picker)
	list.add_child(_slot_picker)
	_slots = Catalog.all_parts()
	for slot: Dictionary in _slots: _slot_picker.add_item(str(slot.slot_name))
	_slot_picker.item_selected.connect(func(index: int): _select_part(str(_slots[index].slot_id)))
	for tier: int in range(Catalog.TIER_NAMES.size()):
		var button: Button = QuadTheme.button("", func(): _select_tier(tier))
		button.name = "ShipVariant_%d" % tier
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 15)
		button.custom_minimum_size.y = 74
		for style: String in ButtonArt.STATES:
			var box: StyleBox = button.get_theme_stylebox(style)
			box.content_margin_left = 76.0
		list.add_child(button)
		_variant_buttons.append(button)
		var thumbnail: ProductPreview = ProductPreview.new()
		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(thumbnail)
		thumbnail.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		thumbnail.offset_left = 9.0
		thumbnail.offset_right = 69.0
		thumbnail.offset_top = -28.0
		thumbnail.offset_bottom = 28.0
		_variant_previews.append(thumbnail)

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
	_confirmation.canceled.connect(_clear_quote)
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
	column.add_child(QuadTheme.paragraph("사각성으로 돌아가는 길", 25, Art.GOLD))
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
	canvas.selected_part_id = _selected_id
	_balance.text = "부품 구매에 쓸 수 있는 돈  %s" % Money.format_won(state.ship_available_funds())
	_progress.text = "필수 부품 %d / %d종 · 비행 성능 %d · 사용한 제작비 %s\n건축 운영비 3천만 원과 내 집에 사용한 돈은 남겨 둬요." % [state.purchased_ship_parts.size(), Catalog.PART_COUNT, state.ship_performance(), Money.format_won(state.ship_spent())]
	for index: int in range(_slots.size()):
		var slot: Dictionary = _slots[index]
		var equipped: bool = not state.installed_ship_part(str(slot.slot_id)).is_empty()
		_slot_picker.set_item_text(index, ("조립됨 · " if equipped else "빈자리 · ") + str(slot.slot_name))
		if slot.slot_id == _selected_id: _slot_picker.select(index)
	var installed: Dictionary = state.installed_ship_part(_selected_id)
	var variants: Array[Dictionary] = Catalog.variants(_selected_id)
	for item: Dictionary in variants:
		var button: Button = _variant_buttons[int(item.tier)]
		var id: String = str(item.id)
		var due: int = state.ship_purchase_price(id)
		var label: String = "조립됨" if installed.get("id") == id else ("교체 차액 " + Money.format_won(due) if due >= 0 and not installed.is_empty() else Money.format_won(int(item.price)))
		button.text = "%s\n%s · 성능 +%d\n%s" % [str(item.name), QuadrilateralMath.kind_name(str(item.kind)), int(item.performance), label]
		button.tooltip_text = _part_detail(item)
		button.set_pressed_no_signal(id == _selected_variant_id)
		var thumbnail: ProductPreview = _variant_previews[int(item.tier)]
		thumbnail.item = item
		thumbnail.queue_redraw()
	var selected: Dictionary = Catalog.part(_selected_variant_id)
	var price: int = state.ship_purchase_price(_selected_variant_id)
	var missing: int = maxi(0, price - state.ship_available_funds())
	_detail.text = _part_detail(selected)
	canvas.show_preview(_selected_variant_id if installed.get("id") != _selected_variant_id else "")
	_purchase.disabled = price < 0 or missing > 0
	if price < 0: _purchase.text = "조립한 부품" if installed.get("id") == _selected_variant_id else "더 높은 등급의 부품을 쓰고 있어요"
	elif missing > 0: _purchase.text = "%s 더 모으면 구매" % Money.format_won(missing)
	else: _purchase.text = "선택한 부품 구매" if installed.is_empty() else "차액 내고 교체"
	_launch.disabled = not state.ship_complete()
	var replay: bool = ending_saved or state.launched
	_launch.text = "엔딩 다시 보기" if replay else ("완성하고 엔딩 보기" if state.ship_complete() else "필수 부품 12종을 갖추면 완성")
	canvas.queue_redraw()
	if _confirmation.visible:
		_confirmation.get_ok_button().disabled = not _quote_is_current()

func _select_part(id: String) -> void:
	var part: Dictionary = Catalog.part(id)
	if state == null or part.is_empty() or _launch_panel.visible: return
	_selected_id = str(part.slot_id)
	var installed: Dictionary = state.installed_ship_part(_selected_id)
	_selected_variant_id = str(installed.get("id", _selected_id))
	refresh()

func _select_tier(tier: int) -> void:
	if _launch_panel.visible: return
	var variants: Array[Dictionary] = Catalog.variants(_selected_id)
	if tier < 0 or tier >= variants.size(): return
	_selected_variant_id = str(variants[tier].id)
	refresh()

func _part_detail(item: Dictionary) -> String:
	var dimensions: Vector2 = QuadrilateralMath.bounds(item.vertices).size
	var shape: String = QuadrilateralMath.kind_name(str(item.kind))
	return "%s · %s · %s\n%s · 크기 %d × %d · 비행 성능 +%d" % [str(item.name), shape, Money.format_won(int(item.price)), str(item.description), roundi(dimensions.x), roundi(dimensions.y), int(item.performance)]

func _ask_purchase() -> void:
	if state == null or _purchase.disabled or _launch_panel.visible or not is_visible_in_tree(): return
	_pending_part = _selected_variant_id
	_pending_price = state.ship_purchase_price(_pending_part)
	if not _quote_is_current():
		_clear_quote()
		refresh()
		return
	var item: Dictionary = Catalog.part(_pending_part)
	var installed: Dictionary = state.installed_ship_part(_selected_id)
	var decision: String = "%s 부품을 %s에 구입할까요?" % [str(item.name), Money.format_won(_pending_price)]
	if not installed.is_empty(): decision = "%s을(를) %s으로 바꿀까요?\n지금 부품과의 차액 %s을 내요." % [str(installed.name), str(item.name), Money.format_won(_pending_price)]
	_confirmation.dialog_text = decision + "\n남는 제작비 %s" % Money.format_won(state.ship_available_funds() - _pending_price)
	_confirmation.get_ok_button().disabled = false
	_focus_before_confirm = get_viewport().gui_get_focus_owner()
	_confirmation.popup_centered(Vector2i(mini(540, int(size.x) - 32), 220))

func _confirm_purchase() -> void:
	var id: String = _pending_part
	var valid: bool = _quote_is_current() and is_visible_in_tree() and not _launch_panel.visible
	_clear_quote()
	_confirmation.hide()
	if valid: purchase_requested.emit(id)
	else: refresh()

func _clear_quote() -> void:
	_pending_part = ""
	_pending_price = -1

func _quote_is_current() -> bool:
	return state != null and not _pending_part.is_empty() and _pending_price >= 0 and state.ship_purchase_price(_pending_part) == _pending_price and state.ship_available_funds() >= _pending_price

func _request_launch() -> void:
	if state == null or not state.ship_complete() or _launch_panel.visible: return
	# The PNG and ending always use the installed ship. Clear the shop preview
	# first so players see exactly which parts will be included.
	if not canvas._preview_id.is_empty():
		_select_part(_selected_id)
		_status.text = "조립한 부품으로 사각성에 갈 준비를 해요."
	if state.launched and not managed_endings: play_launch()
	else: launch_requested.emit()

func show_transaction_result(result: Dictionary) -> void:
	_status.text = str(result.get("message", "구매한 부품을 우주선에 조립했어요.")) if bool(result.get("ok", false)) else str(result.get("error", "잠시 후 다시 시도해 주세요."))
	refresh()

func play_launch() -> void:
	if state == null or not state.ship_complete() or not state.launched: return
	_confirmation.hide()
	_clear_quote()
	_launch_clock = 0.0
	_launch_done = false
	_launch_canvas.set_parts(state.purchased_ship_parts)
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
	_clear_quote()
	if is_instance_valid(_launch_panel): _launch_panel.hide()
	if is_instance_valid(_content): _content.show()
	_launch_clock = -1.0
	_launch_done = false
	set_process(false)

func _visibility_changed() -> void:
	if not is_visible_in_tree(): cancel_activity()
	else:
		refresh()
		if is_instance_valid(_slot_picker): _slot_picker.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode != KEY_ESCAPE: return
	if _confirmation.visible:
		_confirmation.hide()
		_clear_quote()
	elif _launch_panel.visible:
		if _launch_done: home_requested.emit()
		else: _finish_launch()
	else: home_requested.emit()
	get_viewport().set_input_as_handled()

func _responsive() -> void:
	if not is_instance_valid(_list_scroll): return
	_list_scroll.custom_minimum_size.x = 325 if size.x < 1000 else 420
	if is_instance_valid(_confirmation) and _confirmation.visible:
		_confirmation.popup_centered(Vector2i(mini(540, int(size.x) - 32), 220))
