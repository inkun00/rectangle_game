class_name ConstructionMaterialCard
extends Button

## A catalog sample: the native Button keeps its text and keyboard semantics.
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Art = preload("res://scripts/construction_art.gd")
const Math = preload("res://scripts/core/quadrilateral_math.gd")
const Language = preload("res://scripts/construction/construction_language.gd")

var _sample: Art.MaterialSample
var _title: Label
var _family: Label
var _dimensions: Label
var _price: Label
var _badge: PanelContainer
var _color_state: String = ""

var material_id: String = "":
	set(value):
		material_id = value
		_update_material()

func _ready() -> void:
	custom_minimum_size = Vector2(0, 112)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	expand_icon = false
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_override("font", QuadTheme.FONT)
	add_theme_font_size_override("font_size", 14)
	add_theme_constant_override("h_separation", 10)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, Art.button_style(state == "pressed", state, 8))
	# Retain full native text for accessibility, while the child labels provide
	# the compact sample layout without truncating material names.
	for mode: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_disabled_color", "font_hover_pressed_color"]:
		add_theme_color_override(mode, Color.TRANSPARENT)
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Art.COPPER
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	add_theme_stylebox_override("focus", focus)
	_build_content()
	_update_material()
	_refresh_colors()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW and is_instance_valid(_title):
		_refresh_colors()

func _build_content() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	_title = _content_label(16)
	column.add_child(_title)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_sample = Art.MaterialSample.new()
	_sample.custom_minimum_size = Vector2(68, 60)
	row.add_child(_sample)
	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)
	_badge = PanelContainer.new()
	_badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	details.add_child(_badge)
	_family = _content_label(13)
	_family.clip_text = false
	_badge.add_child(_family)
	_dimensions = _content_label(13)
	details.add_child(_dimensions)
	_price = _content_label(16)
	details.add_child(_price)
	for child: Node in find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _content_label(font_size: int) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_override("font", QuadTheme.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

func _refresh_colors() -> void:
	var active: bool = button_pressed and not disabled
	var color_state: String = "%s_%s" % [str(active), str(disabled)]
	if _color_state == color_state: return
	_color_state = color_state
	var main_color: Color = Color.WHITE if active else (Art.MUTED if disabled else Art.INK)
	_title.add_theme_color_override("font_color", main_color)
	_price.add_theme_color_override("font_color", main_color)
	_family.add_theme_color_override("font_color", Color("edf4ef") if active else Art.MUTED)
	_dimensions.add_theme_color_override("font_color", Color("edf4ef") if active else Art.MUTED)
	_sample.modulate = Color(1, 1, 1, 0.50 if disabled else 1.0)
	var badge_style: StyleBoxTexture = StyleBoxTexture.new()
	badge_style.texture = Art.quiet_surface_texture(active)
	badge_style.modulate_color = Art.ACCENT if active else Color("e9efec")
	badge_style.content_margin_left = 5
	badge_style.content_margin_right = 5
	badge_style.content_margin_top = 1
	badge_style.content_margin_bottom = 1
	_badge.add_theme_stylebox_override("panel", badge_style)

func configure(id: String) -> void:
	material_id = id

func _update_material() -> void:
	var material: Dictionary = Catalog.material(material_id)
	if material.is_empty(): return
	var title: String = Language.simplify(str(material.label))
	var description: String = Language.simplify(str(material.description))
	var family: String = Math.kind_label(str(material.kind))
	text = "%s\n%s" % [title, Catalog.format_won(int(material.price))]
	icon = null
	tooltip_text = "%s · %s\n%s\n%s\n%s\n\n%s: %s" % [title, Language.simplify(str(material.unit)), Catalog.dimensions_label(material_id), Catalog.edge_lengths_label(material_id), description, family, Language.explanation(family)]
	if not is_instance_valid(_title): return
	_sample.material_id = material_id
	_title.text = Language.simplify(Catalog.short_label(material_id))
	_family.text = family
	_family.custom_minimum_size.x = QuadTheme.FONT.get_string_size(_family.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var extent: Vector2 = Vector2(material.dimensions) / Catalog.GRID_UNIT
	_dimensions.text = "폭%s·높이%s칸" % [Catalog.format_length(extent.x), Catalog.format_length(extent.y)]
	_price.text = Catalog.format_won(int(material.price))
