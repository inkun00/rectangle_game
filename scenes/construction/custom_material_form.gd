class_name CustomMaterialForm
extends VBoxContainer

## Editing the form only previews a prefab; registration belongs to the studio.
const Custom = preload("res://scripts/construction/custom_material_catalog.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Art = preload("res://scripts/construction_art.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")

signal registration_requested(material_id: String)
signal choices_changed

var registered_material_ids: Array[String] = []
var current_material_id: String = ""
var current_quote: Dictionary = {}
var _kind_picker: OptionButton
var _trapezoid_picker: OptionButton
var _width_spin: SpinBox
var _height_spin: SpinBox
var _surface_picker: OptionButton
var _pattern_picker: OptionButton
var _role_picker: OptionButton
var _preview: Art.MaterialSample
var _quote_label: Label
var _total_label: Label
var _register_button: Button
var _registration_note: Label
var _shape_label: Label
var _dimension_note: Label
var _trapezoid_field: VBoxContainer
var _fields: GridContainer
var _updating: bool = false


func setup(ids: Array[String]) -> void:
	registered_material_ids = ids.duplicate()
	if is_node_ready(): refresh_quote()


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	_build_ui()
	resized.connect(_layout_fields)
	_layout_fields()
	refresh_quote()


func _build_ui() -> void:
	add_child(QuadTheme.paragraph("도형과 크기, 재질과 무늬를 골라 나만의 자재를 만들어요.", 17, Art.INK))
	add_child(QuadTheme.paragraph("등록은 무료예요. 놓을 때마다 한 개당 제작비가 재료비에 들어가요.", 15, Art.ACCENT))
	var preview_panel: PanelContainer = PanelContainer.new()
	preview_panel.add_theme_stylebox_override("panel", Art.card_panel(10))
	add_child(preview_panel)
	_preview = Art.MaterialSample.new()
	_preview.name = "CustomMaterialPreview"
	_preview.fit_preview = true
	_preview.custom_minimum_size = Vector2(160, 150)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(_preview)
	_shape_label = QuadTheme.paragraph("", 15, Art.INK)
	add_child(_shape_label)
	_fields = GridContainer.new()
	_fields.columns = 2
	_fields.add_theme_constant_override("h_separation", 12)
	_fields.add_theme_constant_override("v_separation", 10)
	add_child(_fields)
	_kind_picker = _picker("CustomMaterialKind")
	for kind: String in Math.KINDS:
		_add_choice(_kind_picker, Math.kind_name(kind), kind)
	_kind_picker.select(Math.KINDS.find("rectangle"))
	_field("도형", _kind_picker)
	_kind_picker.item_selected.connect(func(_index: int): refresh_quote())
	_trapezoid_picker = _picker("CustomMaterialTrapezoid")
	var trapezoid_labels: Array[String] = ["양옆이 기울어진 모양", "왼쪽 두 각이 직각", "오른쪽 두 각이 직각"]
	for index: int in range(Math.TRAPEZOID_VARIANTS.size()):
		_add_choice(_trapezoid_picker, trapezoid_labels[index], Math.TRAPEZOID_VARIANTS[index])
	_trapezoid_field = _field("사다리꼴 모양", _trapezoid_picker)
	_trapezoid_picker.item_selected.connect(func(_index: int): refresh_quote())
	_width_spin = _spin("CustomMaterialWidth", 30.0, 6.0)
	_field("가로 크기", _width_spin)
	_width_spin.value_changed.connect(func(_value: float): _dimensions_changed(true))
	_height_spin = _spin("CustomMaterialHeight", 20.0, 4.0)
	_field("세로 크기", _height_spin)
	_height_spin.value_changed.connect(func(_value: float): _dimensions_changed(false))
	_surface_picker = _picker("CustomMaterialSurface")
	for surface: String in Custom.SURFACE_IDS:
		_add_choice(_surface_picker, Custom.surface_label(surface), surface)
	_field("재질", _surface_picker)
	_surface_picker.item_selected.connect(func(_index: int): refresh_quote())
	_pattern_picker = _picker("CustomMaterialPattern")
	for pattern: String in Custom.PATTERN_IDS:
		_add_choice(_pattern_picker, Custom.pattern_label(pattern), pattern)
	_field("무늬", _pattern_picker)
	_pattern_picker.item_selected.connect(func(_index: int): refresh_quote())
	_role_picker = _picker("CustomMaterialRole")
	for role: String in Custom.ROLE_IDS:
		_add_choice(_role_picker, Custom.role_label(role), role)
	_field("사용할 곳", _role_picker)
	_role_picker.item_selected.connect(func(_index: int): refresh_quote())
	_dimension_note = QuadTheme.paragraph("", 14, Art.MUTED)
	add_child(_dimension_note)
	var quote_panel: VBoxContainer = QuadTheme.card(self, Art.PAPER, 12)
	quote_panel.add_child(QuadTheme.label("자재 한 개 제작비", 18, Art.INK))
	_quote_label = QuadTheme.paragraph("", 15, Art.MUTED)
	quote_panel.add_child(_quote_label)
	_total_label = QuadTheme.paragraph("", 20, Art.GOLD)
	quote_panel.add_child(_total_label)
	quote_panel.add_child(QuadTheme.paragraph("금액은 항목별로 100원 단위로 반올림해요. 게임 속 제작 견적이에요.", 13, Art.MUTED))
	_registration_note = QuadTheme.paragraph("", 14, Art.GOLD)
	add_child(_registration_note)
	_register_button = QuadTheme.button("무료로 자재 등록", request_registration, true)
	_register_button.name = "RegisterCustomMaterial"
	add_child(_register_button)


func _field(caption: String, control: Control) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	box.add_child(QuadTheme.label(caption, 15, Art.INK))
	box.add_child(control)
	_fields.add_child(box)
	return box


func _picker(control_name: String) -> OptionButton:
	var picker: OptionButton = OptionButton.new()
	picker.name = control_name
	picker.custom_minimum_size.y = 44
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.fit_to_longest_item = false
	picker.clip_text = true
	picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	picker.add_theme_font_override("font", QuadTheme.FONT)
	picker.add_theme_font_size_override("font_size", 16)
	picker.focus_mode = Control.FOCUS_ALL
	for mode: String in ["font_color", "font_hover_color", "font_focus_color"]:
		picker.add_theme_color_override(mode, Art.INK)
	picker.add_theme_color_override("font_pressed_color", Color.WHITE)
	for mode: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		picker.add_theme_stylebox_override(mode, Art.button_style(false, mode, 8))
	picker.add_theme_stylebox_override("focus", ButtonArt.focus_style())
	var popup: PopupMenu = picker.get_popup()
	popup.add_theme_font_override("font", QuadTheme.FONT)
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_color_override("font_color", Art.INK)
	popup.add_theme_color_override("font_hover_color", Art.INK)
	popup.add_theme_stylebox_override("panel", Art.panel(false, 10))
	popup.add_theme_stylebox_override("hover", Art.button_style(false, "hover", 10))
	return picker


func _spin(control_name: String, maximum: float, initial: float) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.name = control_name
	spin.custom_minimum_size.y = 44
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.min_value = 0.5
	spin.max_value = maximum
	spin.step = 0.5
	spin.value = initial
	spin.suffix = " 칸"
	spin.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	spin.tooltip_text = "0.5칸씩 조절해요. 0.5~%s칸 사이에서 골라요." % Catalog.format_length(maximum)
	var edit: LineEdit = spin.get_line_edit()
	edit.add_theme_font_override("font", QuadTheme.FONT)
	edit.add_theme_font_size_override("font_size", 17)
	edit.add_theme_color_override("font_color", Art.INK)
	edit.add_theme_color_override("caret_color", Art.INK)
	edit.add_theme_stylebox_override("normal", Art.button_style(false, "normal", 8))
	edit.add_theme_stylebox_override("focus", ButtonArt.focus_style())
	return spin


func _add_choice(picker: OptionButton, caption: String, id: String) -> void:
	picker.add_item(caption)
	picker.set_item_metadata(picker.item_count - 1, id)


func _choice(picker: OptionButton) -> String:
	return str(picker.get_item_metadata(picker.selected)) if picker.selected >= 0 else ""


func _layout_fields() -> void:
	if _fields != null:
		_fields.columns = 2 if size.x >= 480.0 else 1


func _dimensions_changed(width_changed: bool) -> void:
	if _updating: return
	if _choice(_kind_picker) == "square":
		_updating = true
		var side: float = _width_spin.value if width_changed else _height_spin.value
		_width_spin.set_value_no_signal(side)
		_height_spin.set_value_no_signal(side)
		_updating = false
	refresh_quote()


func refresh_quote() -> void:
	if _updating or not is_instance_valid(_register_button): return
	_updating = true
	var kind: String = _choice(_kind_picker)
	_width_spin.max_value = 20.0 if kind == "square" else 30.0
	_width_spin.tooltip_text = "0.5칸씩 조절해요. 0.5~%s칸 사이에서 골라요." % Catalog.format_length(_width_spin.max_value)
	if kind == "square": _height_spin.set_value_no_signal(_width_spin.value)
	_trapezoid_field.visible = kind == "trapezoid"
	var dimensions: Vector2 = Vector2(_width_spin.value, _height_spin.value) * Catalog.GRID_UNIT
	var trapezoid_variant: String = _choice(_trapezoid_picker) if kind == "trapezoid" else "symmetric"
	current_material_id = Custom.make_id(kind, dimensions, _choice(_surface_picker), _choice(_pattern_picker), _choice(_role_picker), trapezoid_variant)
	current_quote = Custom.quote(current_material_id)
	_preview.material_id = current_material_id
	var material: Dictionary = Catalog.material(current_material_id)
	var valid: bool = not material.is_empty() and not current_quote.is_empty()
	var already_registered: bool = current_material_id in registered_material_ids
	var at_capacity: bool = registered_material_ids.size() >= Custom.MAX_REGISTERED
	_register_button.disabled = not valid or already_registered or at_capacity
	_register_button.text = "이미 등록한 자재" if already_registered else ("등록 한도 %d개" % Custom.MAX_REGISTERED if at_capacity else "무료로 자재 등록")
	_registration_note.visible = at_capacity and not already_registered
	_registration_note.text = "맞춤 자재는 %d개까지 등록할 수 있어요. 등록한 자재는 선반에서 계속 쓸 수 있어요." % Custom.MAX_REGISTERED
	_register_button.tooltip_text = "이미 선반에 등록한 자재예요." if already_registered else (_registration_note.text if at_capacity else "등록은 무료이며, 놓은 개수만큼 제작비가 들어가요.")
	if valid:
		_shape_label.text = "%s · %s · %s\n%s\n%s" % [Math.kind_name(kind), _choice_label(_surface_picker), _choice_label(_pattern_picker), Catalog.dimensions_label(current_material_id), Catalog.edge_lengths_label(current_material_id)]
		_dimension_note.text = "가로·세로는 두 대각선의 길이예요. 마름모의 변 길이와는 달라요." if kind == "rhombus" else ("정사각형은 가로와 세로를 같은 크기로 맞춰요." if kind == "square" else "가로·세로는 도형 바깥의 폭과 높이예요. 변의 길이와 다를 수 있어요.")
		_dimension_note.text += " 1칸은 게임 속 길이예요."
		_quote_label.text = "도형 넓이 %s칸² · 재질 단가 %s/칸²\n바탕 재료비  %s\n모양 가공비  %s\n무늬 가공비  %s\n용도 제작비  %s" % [Math.measurement_label(float(current_quote.area_cells), 2), Catalog.format_won(int(current_quote.unit_rate)), Catalog.format_won(int(current_quote.base_cost)), Catalog.format_won(int(current_quote.shape_fee)), Catalog.format_won(int(current_quote.pattern_fee)), Catalog.format_won(int(current_quote.role_fee))]
		_total_label.text = "한 개당 %s" % Catalog.format_won(int(current_quote.total))
	else:
		_shape_label.text = "도형과 크기를 다시 확인해 주세요."
		_dimension_note.text = "가로 0.5~30칸, 세로 0.5~20칸으로 만들 수 있어요."
		_quote_label.text = "올바른 자재를 고르면 제작비를 보여 드려요."
		_total_label.text = ""
	_updating = false
	choices_changed.emit()


func _choice_label(picker: OptionButton) -> String:
	return picker.get_item_text(picker.selected) if picker.selected >= 0 else ""


func request_registration() -> void:
	refresh_quote()
	if not is_instance_valid(_register_button) or _register_button.disabled: return
	registration_requested.emit(current_material_id)
