class_name WallStudio
extends Control

const Design = preload("res://scripts/core/wall_tile_design.gd")
const Geometry = preload("res://scripts/core/quadrilateral_math.gd")
const Preview = preload("res://scenes/wall/wall_pattern_preview.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Metadata = preload("res://scripts/export/art_submission_metadata.gd")

signal home_requested
signal design_changed
signal commission_submitted
signal wall_publication_requested(author: String, title: String, description: String)
signal exhibition_board_requested

var design: Design = Design.new()
var free_mode: bool = false
var free_designs: Dictionary = {}
var _draft: Design:
	get: return free_designs[_selected_order] if free_mode else design
var _balance: int = 0
var _stage: String = "orders"
var _selected_order: String = ""
var _piece: int = -1
var _kind: String = ""
var _ink: int = 1
var _scroll: ScrollContainer
var _body: VBoxContainer
var _balance_label: Label
var _title: Label
var _preview: Preview
var _work: BoxContainer
var _overview: Label
var _note: Label
var _status: String = ""
var _controls: Dictionary = {}
var _form: ConfirmationDialog
var _author: LineEdit
var _work_title: LineEdit
var _description: TextEdit
var _validation: Label

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
	if stage == "orders": free_mode = false
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
	_work = BoxContainer.new()
	_work.add_theme_constant_override("separation", 14)
	var titles: Dictionary = {"orders": "담장 의뢰", "blank": "꾸미기 전 담장", "tile": "타일 한 장 디자인", "filled": "내 타일로 채운 담장"}
	var heading: String = "자유 작품 · " + str(titles[_stage]) if free_mode else str(titles[_stage])
	_title = QuadTheme.paragraph(heading, 26, Color("#fff0d5"))
	_title.focus_mode = Control.FOCUS_CLICK
	_body.add_child(_title)
	_body.add_child(_work)
	_preview = Preview.new()
	_preview.design = _draft
	_preview.view_kind = "blank" if _stage in ["orders", "blank"] else _stage
	_preview.name = {"orders":"WallOrderPreview", "blank":"WallBlankPreview", "tile":"WallTileEditor", "filled":"WallFinishedPreview"}[_stage]
	_preview.set_location(_selected_order)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_stretch_ratio = 1.4
	_preview.piece_selected.connect(_select_piece)
	_preview.piece_placed.connect(_place)
	_preview.edited.connect(_changed)
	_work.add_child(_preview)
	var tools: VBoxContainer = VBoxContainer.new()
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_theme_constant_override("separation", 8)
	_work.add_child(tools)
	_overview = _paragraph(tools, "")
	_note = null
	match _stage:
		"orders":
			var choices: HFlowContainer = _flow(tools)
			for id: String in Design.COMMISSIONS:
				var label: String = str(Design.COMMISSIONS[id].title)
				if id in design.completed: label += " · 완료"
				_action(choices, "WallCommission_" + id, label, _select_order.bind(id), true)
			var actions: HFlowContainer = _flow(tools)
			_action(actions, "WallAccept", "이 담장 꾸미기", _accept, false, true)
			_action(actions, "WallFreeDesign", "자유롭게 꾸미기", _start_free)
		"blank":
			var choices: HFlowContainer = _flow(tools)
			_action(choices, "WallStartTile", "타일 디자인하기", _go.bind("tile"), false, true)
			if design.finished:
				_action(choices, "WallResume", "완성한 담장 보기", _go.bind("filled"))
			_action(choices, "WallOrders", "다른 의뢰 보기", _go.bind("orders"))
		"tile": _tile_tools(tools)
		"filled":
			var nav: HFlowContainer = _flow(tools)
			if not free_mode: _action(nav, "WallSubmit", "의뢰인에게 납품", _submit, false, true)
			_action(nav, "WallEditTile", "타일 고치기", _go.bind("tile"))
			_action(nav, "WallPublish", "완성한 담장 등록", _open_form)
			_action(nav, "WallBrowse", "담장 전시장 보기", func() -> void: exhibition_board_requested.emit())
			_action(nav, "WallOrders", "다른 장소 보기" if free_mode else "다른 의뢰 보기", _go.bind("orders"))
			_note = _paragraph(tools, _status)
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
	_preview.set_location(id)
	refresh()

func _accept() -> void:
	free_mode = false
	if design.commission_id != _selected_order:
		design.set_commission(_selected_order)
		design_changed.emit()
	_piece = -1
	_kind = ""
	_status = ""
	_go("blank")

func _start_free() -> void:
	if not free_designs.has(_selected_order):
		var work: Design = Design.new()
		work.set_commission(_selected_order)
		free_designs[_selected_order] = work
	free_mode = true
	_piece = -1
	_kind = ""
	_status = ""
	_go("tile")

func _tile_tools(tools: VBoxContainer) -> void:
	var shapes: HFlowContainer = _flow(tools)
	var kinds: Array[String] = Geometry.KINDS.duplicate()
	kinds.append("freeform")
	for kind: String in kinds:
		var label: String = "자유 사각형" if kind == "freeform" else Geometry.kind_name(kind)
		_action(shapes, "WallShape_" + kind, label, _arm.bind(kind), true)
	var selection: HFlowContainer = _flow(tools)
	_action(selection, "WallPlaceCenter", "가운데에 놓기", _center_place)
	_action(selection, "WallPiecePrevious", "이전 조각", _cycle.bind(-1))
	_action(selection, "WallPieceNext", "다음 조각", _cycle.bind(1))
	var palette: HFlowContainer = _flow(tools)
	for i: int in range(Design.PALETTE.size()):
		var button: Button = _action(palette, "WallColor_%d" % i, str(Design.PALETTE_NAMES[i]), _color.bind(i), true)
		var swatch: GradientTexture2D = GradientTexture2D.new()
		swatch.gradient = Gradient.new()
		swatch.gradient.colors = PackedColorArray([Design.PALETTE[i], Design.PALETTE[i]])
		swatch.width = 16
		swatch.height = 16
		button.icon = swatch
		button.expand_icon = false
	var transforms: HFlowContainer = _flow(tools)
	_action(transforms, "WallRotate", "15° 돌리기", _edit.bind("rotate"))
	_action(transforms, "WallMirror", "좌우 뒤집기", _edit.bind("mirror"))
	_action(transforms, "WallGrow", "키우기", _edit.bind("grow"))
	_action(transforms, "WallShrink", "줄이기", _edit.bind("shrink"))
	_action(transforms, "WallDelete", "조각 지우기", _edit.bind("delete"))
	_action(transforms, "WallUndo", "되돌리기", _history.bind(false))
	_action(transforms, "WallRedo", "다시 실행", _history.bind(true))
	var nav: HFlowContainer = _flow(tools)
	_action(nav, "WallFinishTile", "타일 완성 · 담장 채우기", _finish, false, true)
	_action(nav, "WallOrders", "장소 목록" if free_mode else "의뢰 목록", _go.bind("orders"))
	_note = _paragraph(tools, "")

func _arm(kind: String) -> void:
	_kind = "" if _kind == kind else kind
	_piece = -1
	refresh()

func _place(point: Vector2) -> void:
	if _kind.is_empty(): return
	var added: int = _draft.add_piece(_kind, point, _ink)
	if added < 0:
		_note.text = "조각 전체가 타일 안에 들어가도록 안쪽을 눌러 주세요."
		return
	_kind = ""
	_piece = added
	_changed()

func _center_place() -> void:
	_place(_draft.tile_size() * 0.5)

func _select_piece(index: int) -> void:
	_kind = ""
	_piece = index
	var parts: Array[Dictionary] = _draft.motif_parts()
	if index >= 0 and index < parts.size(): _ink = int(parts[index].palette_index)
	refresh()

func _cycle(step: int) -> void:
	var count: int = _draft.motif_parts().size()
	if count: _select_piece(posmod(_piece + step, count))

func _color(index: int) -> void:
	_ink = index
	if _piece >= 0 and _draft.set_color(_piece, index): _changed()
	else: refresh()

func _edit(action: String) -> void:
	if _piece < 0: return
	var success: bool = false
	match action:
		"rotate": success = _draft.rotate_piece(_piece, 15.0)
		"mirror": success = _draft.mirror_piece(_piece)
		"grow": success = _draft.resize_piece(_piece, 1.2)
		"shrink": success = _draft.resize_piece(_piece, 1.0 / 1.2)
		"delete":
			success = _draft.remove_piece(_piece)
			if success: _piece = mini(_piece, _draft.motif_parts().size() - 1)
	if success: _changed()
	else: _note.text = "크기나 위치를 바꾼 뒤 다시 해 보세요. 조각은 타일 안에 있어야 해요."

func _history(redo: bool) -> void:
	var success: bool = _draft.redo() if redo else _draft.undo()
	if success:
		_kind = ""
		_piece = -1
		_changed()

func _finish() -> void:
	if not _draft.finish_tile(): return
	_kind = ""
	_piece = -1
	_changed()
	_go("filled")

func _submit() -> void:
	if free_mode: return
	var report: Dictionary = _draft.evaluate()
	if _draft.finished and report.ok and not report.claimed:
		commission_submitted.emit()
	refresh()

func _changed() -> void:
	_status = ""
	design_changed.emit()
	refresh()

func refresh() -> void:
	if not is_instance_valid(_body): return
	set_balance(_balance)
	var order: Dictionary = Design.COMMISSIONS[_selected_order]
	_preview.placing = not _kind.is_empty()
	_preview.selected_piece = _piece
	_preview.refresh()
	match _stage:
		"orders", "blank":
			_overview.text = "%s  ·  %s\n%s" % [order.title, Catalog.format_won(int(order.reward)), order.brief]
			if _stage == "orders":
				for id: String in Design.COMMISSIONS:
					_controls["WallCommission_" + id].set_pressed_no_signal(id == _selected_order)
		"tile":
			var parts: Array[Dictionary] = _draft.motif_parts()
			for kind: String in Geometry.KINDS + ["freeform"]:
				_controls["WallShape_" + kind].set_pressed_no_signal(_kind == kind)
			for i: int in range(Design.PALETTE.size()): _controls["WallColor_%d" % i].set_pressed_no_signal(_ink == i)
			for id: String in ["WallRotate", "WallMirror", "WallGrow", "WallShrink", "WallDelete"]: _controls[id].disabled = _piece < 0
			for id: String in ["WallPiecePrevious", "WallPieceNext"]: _controls[id].disabled = parts.is_empty()
			_controls.WallFinishTile.disabled = parts.size() < 2
			_controls.WallPlaceCenter.disabled = _kind.is_empty()
			_controls.WallUndo.disabled = not _draft.can_undo()
			_controls.WallRedo.disabled = not _draft.can_redo()
			_overview.text = "도형을 고른 뒤 타일에서 놓을 곳을 눌러요. 조각을 두 개 이상 놓고 끌어서 무늬를 만들어요."
			if _piece >= 0 and _piece < parts.size():
				var piece: Dictionary = parts[_piece]
				_note.text = "선택한 조각 %d / %d · %s" % [_piece + 1, parts.size(), "자유 사각형" if piece.kind == "freeform" else Geometry.kind_name(piece.kind)]
				if piece.kind == "freeform": _note.text += " · 꼭짓점을 끌어 모양을 바꿔요."
			else: _note.text = ("타일에 놓을 곳을 눌러 주세요." if not _kind.is_empty() else "조각 %d개" % parts.size())
		"filled":
			var report: Dictionary = _draft.evaluate()
			if free_mode:
				_overview.text = "%s · 자유 작품" % order.title
			else: _overview.text = "%s\n%s" % [order.title, "납품 완료 · 받은 의뢰비 " + Catalog.format_won(int(order.reward)) if report.claimed else str(report.feedback)]
			if not free_mode: _controls.WallSubmit.disabled = not _draft.finished or not report.ok or report.claimed
			_controls.WallPublish.disabled = not _draft.finished
			_note.text = _status

func _layout() -> void:
	if is_instance_valid(_work) and is_instance_valid(_preview):
		var narrow: bool = size.x < 800.0
		_work.vertical = narrow
		_preview.custom_minimum_size.y = clampf(size.y * (0.34 if narrow else 0.55), 160, 500)

func publication_design() -> Dictionary:
	if _stage != "filled" or not _draft.finished: return {}
	var snapshot: Dictionary = _draft.to_dict()
	snapshot.erase("completed")
	return snapshot

func set_publication_status(message: String) -> void:
	_status = message
	if _stage == "filled" and is_instance_valid(_note): _note.text = message

func _open_form() -> void:
	if _stage != "filled" or not _draft.finished: return
	if not is_instance_valid(_form): _build_form()
	_validation.text = ""
	_form.popup_centered(Vector2i(mini(480, maxi(230, int(size.x) - 28)), mini(420, maxi(200, int(size.y) - 30))))
	_author.grab_focus()

func _build_form() -> void:
	_form = ConfirmationDialog.new()
	_form.name = "WallPublicationForm"
	_form.title = "완성한 담장 등록"
	_form.exclusive = true
	_form.dialog_hide_on_ok = false
	_form.ok_button_text = "등록하기"
	_form.cancel_button_text = "취소"
	_form.get_ok_button().name = "WallPublicationSend"
	_form.get_cancel_button().name = "WallPublicationCancel"
	_form.confirmed.connect(_send_form)
	add_child(_form)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_form.add_child(scroll)
	var fields: VBoxContainer = VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(fields)
	_paragraph(fields, "작성자")
	_author = LineEdit.new()
	_author.name = "WallAuthor"
	_author.accessibility_name = "작성자 이름"
	_author.max_length = Metadata.MAX_AUTHOR_LENGTH
	fields.add_child(_author)
	_paragraph(fields, "담장 제목")
	_work_title = LineEdit.new()
	_work_title.name = "WallPublicationTitle"
	_work_title.accessibility_name = "담장 제목"
	_work_title.max_length = Metadata.MAX_TITLE_LENGTH
	fields.add_child(_work_title)
	_paragraph(fields, "담장 설명")
	_description = TextEdit.new()
	_description.name = "WallDescription"
	_description.accessibility_name = "담장 설명"
	_description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_description.custom_minimum_size.y = 84
	fields.add_child(_description)
	_validation = _paragraph(fields, "")

func _send_form() -> void:
	if _stage != "filled" or not _draft.finished: return
	var issue: String = Metadata.validation_error(_author.text, _work_title.text, _description.text)
	if not issue.is_empty():
		_validation.text = issue.replace("그림", "담장")
		return
	_form.hide()
	wall_publication_requested.emit(_author.text.strip_edges(), _work_title.text.strip_edges(), _description.text.strip_edges())

func render_publication_png() -> PackedByteArray:
	if publication_design().is_empty() or DisplayServer.get_name() == "headless": return PackedByteArray()
	var frozen: Design = Design.new()
	if not frozen.restore(_draft.to_dict()): return PackedByteArray()
	var capture: SubViewport = SubViewport.new()
	capture.size = Vector2i(960, 600)
	capture.disable_3d = true
	capture.render_target_update_mode = SubViewport.UPDATE_ONCE
	var illustration: Preview = Preview.new()
	illustration.design = frozen
	illustration.view_kind = "filled"
	illustration.export_only = true
	illustration.set_location(frozen.commission_id)
	if illustration.backdrop == null:
		illustration.free()
		capture.free()
		return PackedByteArray()
	illustration.size = Vector2(capture.size)
	capture.add_child(illustration)
	add_child(capture)
	await RenderingServer.frame_post_draw
	var picture: Image = capture.get_texture().get_image()
	capture.queue_free()
	if picture == null or picture.is_empty(): return PackedByteArray()
	return picture.save_png_to_buffer()
