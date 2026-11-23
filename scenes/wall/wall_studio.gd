class_name WallStudio
extends Control

const Design = preload("res://scripts/core/wall_tile_design.gd")
const Preview = preload("res://scenes/wall/wall_pattern_preview.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")

signal home_requested
signal design_changed
signal commission_submitted

var design: Design = Design.new()
var _balance: int = 0
var _stage: String = "orders"
var _selected_order: String = ""
var _free_mode: bool = false
var _piece: int = 0
var _scroll: ScrollContainer
var _body: VBoxContainer
var _balance_label: Label
var _title: Label
var _preview: Preview
var _work: BoxContainer
var _overview: Label
var _count_labels: Dictionary = {}
var _controls: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = Color("#132330")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var top: HFlowContainer = HFlowContainer.new()
	column.add_child(top)
	var home: Button = QuadTheme.button("← 메인", func() -> void: home_requested.emit())
	home.name = "WallHome"
	top.add_child(home)
	var brand: Label = QuadTheme.label("담장 꾸미기", 23)
	brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brand.custom_minimum_size.y = 48
	top.add_child(brand)
	_balance_label = QuadTheme.label("", 15, Color("#f3d294"))
	_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_balance_label.custom_minimum_size.y = 48
	top.add_child(_balance_label)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_scroll.add_child(_body)
	_selected_order = design.commission_id
	resized.connect(_layout)
	_build()

func set_balance(coins: int) -> void:
	_balance = coins
	if is_instance_valid(_balance_label):
		_balance_label.text = "보유 " + Catalog.format_won(_balance)

func _go(stage: String, focus_name: String = "") -> void:
	_stage = stage
	_build()
	_scroll.set_deferred("scroll_vertical", 0)
	var target: Control = _controls.get(focus_name, _title) as Control
	if target != null and is_visible_in_tree(): target.grab_focus()

func _build() -> void:
	for node: Node in _body.get_children():
		_body.remove_child(node)
		node.queue_free()
	_controls.clear()
	_count_labels.clear()
	_work = null
	_preview = null
	_overview = null
	var captions: Dictionary = {"orders":"담장을 꾸밀 곳을 골라요", "tile":"1. 타일 한 장 만들기", "wall":"2. 타일로 담장 꾸미기", "review":"내가 꾸민 담장" if _free_mode else "의뢰 확인하기"}
	_title = QuadTheme.paragraph(str(captions[_stage]), 28, Color("#fff0d5"))
	_title.focus_mode = Control.FOCUS_CLICK
	_body.add_child(_title)
	if _stage == "orders":
		var choices: HFlowContainer = _flow(_body)
		for id: String in Design.COMMISSIONS:
			var caption: String = str(Design.COMMISSIONS[id].title)
			if design.completed.has(id): caption += " · 완료"
			_action(choices, "WallCommission_" + id, caption, _select_order.bind(id), true)
		_work = BoxContainer.new()
		_work.add_theme_constant_override("separation", 16)
		_body.add_child(_work)
		_preview = Preview.new()
		_preview.wall = true
		_preview.name = "WallOrderSample"
		_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_work.add_child(_preview)
		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.add_theme_constant_override("separation", 12)
		_work.add_child(info)
		_overview = _paragraph(info, "")
		var actions: HFlowContainer = _flow(info)
		_action(actions, "WallAccept", "이 의뢰로 만들기", _accept, false, true)
		if design.completed.size() == Design.COMMISSIONS.size():
			_action(actions, "WallFreeDesign", "자유롭게 꾸미기", _start_free)
	else:
		var order: Dictionary = Design.COMMISSIONS[design.commission_id]
		if not _free_mode:
			_paragraph(_body, "%s  ·  %s\n%s" % [order.title, Catalog.format_won(int(order.reward)), order.brief])
		_work = BoxContainer.new()
		_work.add_theme_constant_override("separation", 16)
		_body.add_child(_work)
		_preview = Preview.new()
		_preview.design = design
		_preview.wall = _stage != "tile"
		_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_preview.size_flags_stretch_ratio = 1.25
		_preview.piece_selected.connect(_select_piece)
		_work.add_child(_preview)
		var tools: VBoxContainer = VBoxContainer.new()
		tools.add_theme_constant_override("separation", 8)
		tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_work.add_child(tools)
		match _stage:
			"tile": _tile_tools(tools)
			"wall": _wall_tools(tools)
			"review": _review_tools(tools)
	_layout()
	refresh()

func _paragraph(parent: Control, value: String) -> Label:
	var label: Label = QuadTheme.paragraph(value, 17, Color("#dfebeb"))
	parent.add_child(label)
	return label

func _flow(parent: Control) -> HFlowContainer:
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	parent.add_child(row)
	return row

func _action(parent: Control, id: String, label: String, handler: Callable, toggle: bool = false, primary: bool = false) -> Button:
	var button: Button = QuadTheme.button(label, handler, primary)
	button.name = id
	button.toggle_mode = toggle
	parent.add_child(button)
	_controls[id] = button
	return button

func _select_order(id: String) -> void:
	_selected_order = id
	refresh()

func _accept() -> void:
	_free_mode = false
	if design.commission_id != _selected_order:
		design.set_commission(_selected_order)
		design_changed.emit()
	_piece = 0
	_go("tile")

func _start_free() -> void:
	_free_mode = true
	_piece = 0
	_go("tile")

func _tile_tools(tools: VBoxContainer) -> void:
	_paragraph(tools, "기본 무늬를 고르세요.")
	var motifs: HFlowContainer = _flow(tools)
	for id: String in Design.MOTIFS:
		_action(motifs, "WallMotif_" + id, str(Design.MOTIFS[id]), _select_motif.bind(id), true)
	_paragraph(tools, "칠할 조각을 누르고 색을 고르세요.")
	var pieces: HFlowContainer = _flow(tools)
	for i: int in range(design.unit_parts().size()):
		_action(pieces, "WallPiece_%d" % i, "조각 %d" % (i + 1), _select_piece.bind(i), true)
	var colors: HFlowContainer = _flow(tools)
	for i: int in range(Design.PALETTE.size()):
		var button: Button = _action(colors, "WallColor_%d" % i, str(Design.PALETTE_NAMES[i]), _color.bind(i), true)
		var swatch: GradientTexture2D = GradientTexture2D.new()
		swatch.gradient = Gradient.new()
		swatch.gradient.colors = PackedColorArray([Design.PALETTE[i], Design.PALETTE[i]])
		swatch.width = 18
		swatch.height = 18
		button.icon = swatch
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 18)
	_paragraph(tools, "이 무늬를 반복해서 타일 한 장을 만들어요.")
	_repeat_controls(tools, true)
	_action(_flow(tools), "WallRotate", "무늬 90° 돌리기", _rotate)
	var nav: HFlowContainer = _flow(tools)
	_action(nav, "WallOrders", "의뢰 목록", _go.bind("orders"))
	_action(nav, "WallFinishTile", "타일 완성 → 담장 꾸미기", _go.bind("wall"), false, true)

func _wall_tools(tools: VBoxContainer) -> void:
	_paragraph(tools, "완성한 타일을 담장에 몇 장씩 붙일까요?")
	_repeat_controls(tools, false)
	_paragraph(tools, "타일을 놓을 방향을 골라요.")
	var layouts: HFlowContainer = _flow(tools)
	for id: String in Design.LAYOUTS:
		_action(layouts, "WallLayout_" + id, str(Design.LAYOUTS[id]), _set_layout.bind(id), true)
	_overview = _paragraph(tools, "")
	var nav: HFlowContainer = _flow(tools)
	_action(nav, "WallOrders", "의뢰 목록", _go.bind("orders"))
	_action(nav, "WallEditTile", "타일 고치기", _go.bind("tile"))
	_action(nav, "WallReview", "완성한 담장 보기" if _free_mode else "의뢰 확인하기", _go.bind("review"), false, true)

func _repeat_controls(parent: Control, inside_tile: bool) -> void:
	for axis: String in ["Columns", "Rows"]:
		var prefix: String = ("WallTile" if inside_tile else "Wall") + axis
		var row: HBoxContainer = HBoxContainer.new()
		parent.add_child(row)
		var count_label: Label = QuadTheme.label("", 17)
		count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(count_label)
		_count_labels[prefix] = count_label
		for change: int in [-1, 1]:
			var button: Button = _action(row, prefix + ("Less" if change < 0 else "More"), "−" if change < 0 else "+", _step.bind(inside_tile, axis, change))
			var direction: String = "가로" if axis == "Columns" else "세로"
			button.tooltip_text = "%s %s 수 %s" % ["무늬" if inside_tile else "타일", direction, "줄이기" if change < 0 else "늘리기"]
			button.accessibility_name = button.tooltip_text

func _review_tools(tools: VBoxContainer) -> void:
	_overview = _paragraph(tools, "")
	var nav: HFlowContainer = _flow(tools)
	_action(nav, "WallEditTile", "타일 고치기", _go.bind("tile"))
	_action(nav, "WallEditWall", "담장 고치기", _go.bind("wall"))
	if not _free_mode: _action(nav, "WallSubmit", "담장 납품하기", _submit, false, true)
	_action(nav, "WallOrders", "다른 의뢰 보기", _go.bind("orders"))

func _select_motif(id: String) -> void:
	if id != design.motif_id:
		design.select_motif(id)
		_piece = 0
		design_changed.emit()
		_go("tile", "WallMotif_" + id)
	else: refresh()

func _select_piece(index: int) -> void:
	_piece = index
	refresh()

func _color(index: int) -> void:
	design.set_color(_piece, index)
	_updated()

func _step(inside_tile: bool, axis: String, delta: int) -> void:
	var x: int = delta if axis == "Columns" else 0
	var y: int = delta if axis == "Rows" else 0
	if inside_tile: design.set_tile_repeat(design.tile_columns + x, design.tile_rows + y)
	else: design.set_repeat(design.columns + x, design.rows + y)
	_updated()

func _rotate() -> void:
	design.rotate_tile()
	_updated()

func _set_layout(id: String) -> void:
	design.set_layout(id)
	_updated()

func _submit() -> void:
	var result: Dictionary = design.evaluate()
	if result.ok and not result.claimed: commission_submitted.emit()
	refresh()

func _updated() -> void:
	design_changed.emit()
	refresh()

func refresh() -> void:
	if not is_instance_valid(_body): return
	set_balance(_balance)
	var order: Dictionary = Design.COMMISSIONS[_selected_order]
	if _stage == "orders":
		for id: String in Design.COMMISSIONS:
			_pressed("WallCommission_" + id, id == _selected_order)
		var sample: Design = Design.new()
		sample.set_commission(_selected_order)
		sample.select_motif(str(order.motif))
		var colors: Dictionary = {"harbor":[1, 3], "garden":[3, 5, 1, 5, 1], "station":[0, 4, 0, 0, 2, 0]}
		for i: int in range(sample.unit_parts().size()):
			sample.set_color(i, colors[_selected_order][i])
		sample.set_tile_repeat(2, 2 if _selected_order == "garden" else 1)
		sample.set_repeat(int(order.columns), int(order.rows))
		if _selected_order == "station": sample.set_layout("mirror")
		_preview.design = sample
		_preview.queue_redraw()
		_overview.text = "%s\n의뢰비 %s" % [order.brief, Catalog.format_won(int(order.reward))]
		if design.completed.has(_selected_order):
			_overview.text += "\n이미 납품한 벽이에요. 다시 꾸며 볼 수 있어요."
		return
	_preview.selected_piece = _piece
	_preview.queue_redraw()
	match _stage:
		"tile":
			for id: String in Design.MOTIFS: _pressed("WallMotif_" + id, id == design.motif_id)
			var parts: Array[Dictionary] = design.unit_parts()
			for i: int in range(parts.size()): _pressed("WallPiece_%d" % i, i == _piece)
			for i: int in range(Design.PALETTE.size()): _pressed("WallColor_%d" % i, parts[_piece].color == Design.PALETTE[i])
			_count("WallTileColumns", "가로", design.tile_columns, 1, 3)
			_count("WallTileRows", "세로", design.tile_rows, 1, 3)
		"wall":
			_count("WallColumns", "가로", design.columns, 2, 8)
			_count("WallRows", "세로", design.rows, 2, 6)
			for id: String in Design.LAYOUTS: _pressed("WallLayout_" + id, id == design.layout)
			_overview.text = "타일 %d장 × %d줄 = 모두 %d장" % [design.columns, design.rows, design.columns * design.rows]
		"review":
			if _free_mode:
				_overview.text = "한 장에 무늬 %d개, 담장에 타일 %d장을 놓았어요." % [design.tile_columns * design.tile_rows, design.columns * design.rows]
				return
			var check: Dictionary = design.evaluate()
			_overview.text = str(check.feedback)
			if check.claimed:
				_overview.text = "납품 완료 · 받은 의뢰비 %s" % Catalog.format_won(int(order.reward))
			_controls.WallSubmit.disabled = not check.ok or check.claimed

func _count(prefix: String, direction: String, value: int, minimum: int, maximum: int) -> void:
	_count_labels[prefix].text = "%s %d" % [direction, value]
	_controls[prefix + "Less"].disabled = value <= minimum
	_controls[prefix + "More"].disabled = value >= maximum

func _pressed(id: String, pressed: bool) -> void:
	var button: Button = _controls[id] as Button
	button.set_pressed_no_signal(pressed)

func _layout() -> void:
	if is_instance_valid(_work):
		var compact: bool = size.x < 800.0
		_work.vertical = compact
		_preview.custom_minimum_size.y = clampf(size.y * (0.33 if compact else 0.5), 180, 440)
