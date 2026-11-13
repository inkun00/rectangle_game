class_name SpaceshipStyle
extends RefCounted

## Each field begins with its default choice. Store choice IDs in saves and
## keep presentation names and colors here so they can be refined independently.
const _FIELDS: Array[Dictionary] = [
	{"key": "finish", "name": "표면 재질", "options": [
		{"id": "ceramic", "name": "무광 세라믹"},
		{"id": "titanium", "name": "티타늄"},
		{"id": "carbon", "name": "탄소섬유"},
	]},
	{"key": "base", "name": "바탕색", "options": [
		{"id": "ivory", "name": "상아색", "color": Color("e8dfcf")},
		{"id": "slate", "name": "회청색", "color": Color("aebcc9")},
		{"id": "navy", "name": "남색", "color": Color("45668a")},
		{"id": "red", "name": "석류색", "color": Color("b54b55")},
		{"id": "teal", "name": "청록색", "color": Color("46988e")},
		{"id": "lilac", "name": "연보라색", "color": Color("a89ac7")},
	]},
	{"key": "accent", "name": "강조색", "options": [
		{"id": "amber", "name": "호박색", "color": Color("f1ac4e")},
		{"id": "cyan", "name": "하늘색", "color": Color("62cde7")},
		{"id": "mint", "name": "민트색", "color": Color("83deb2")},
		{"id": "coral", "name": "산호색", "color": Color("fb8574")},
		{"id": "violet", "name": "보라색", "color": Color("bf95f2")},
		{"id": "silver", "name": "은색", "color": Color("d8e5ee")},
	]},
	{"key": "fore", "name": "기수 추가 부품", "options": [
		{"id": "none", "name": "장착 안 함"},
		{"id": "scanner", "name": "탐색 안테나"},
		{"id": "sensor", "name": "정밀 센서"},
	]},
	{"key": "wings", "name": "날개 추가 부품", "options": [
		{"id": "none", "name": "장착 안 함"},
		{"id": "fins", "name": "끝날개"},
		{"id": "solar", "name": "태양광 패널"},
	]},
	{"key": "sides", "name": "측면 추가 부품", "options": [
		{"id": "none", "name": "장착 안 함"},
		{"id": "cargo", "name": "화물함"},
		{"id": "pods", "name": "측면 캡슐"},
	]},
	{"key": "tail", "name": "꼬리 추가 부품", "options": [
		{"id": "none", "name": "장착 안 함"},
		{"id": "radiators", "name": "냉각판"},
		{"id": "boosters", "name": "보조 추진기"},
	]},
]


static func defaults() -> Dictionary:
	var appearance: Dictionary = {}
	for field: Dictionary in _FIELDS:
		appearance[field.key] = field.options[0].id
	return appearance


static func fields() -> Array[Dictionary]:
	return _FIELDS.duplicate(true)


static func options(key: String) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for field: Dictionary in _FIELDS:
		if field.key == key:
			choices.assign(field.options)
			return choices.duplicate(true)
	return choices


static func is_valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != _FIELDS.size():
		return false
	for field: Dictionary in _FIELDS:
		var selected: Variant = value.get(field.key)
		if not selected is String or _choice(field.key, selected).is_empty():
			return false
	return true


static func palette(appearance: Dictionary) -> Dictionary:
	var base: Color = _choice("base", appearance.get("base")).get("color", Color("e8dfcf"))
	var accent: Color = _choice("accent", appearance.get("accent")).get("color", Color("f1ac4e"))
	var metal: Color = Color("8e9eaa")
	var shade: Color = Color("305166").lerp(base.darkened(0.4), 0.16)
	match appearance.get("finish"):
		"titanium":
			base = base.lerp(Color("b9c7d3"), 0.17)
			metal = Color("a6b9ca")
		"carbon":
			base = base.lerp(Color("242d3c"), 0.25)
			metal = Color("566477")
			shade = shade.darkened(0.21)
	return {
		"shell": base,
		"shade": shade,
		"metal": metal,
		"trim": accent,
		"accent": accent,
		"glass": Color("55c4d4"),
		"dark": Color("203042"),
		"glow": Color("a0f4ff"),
		"edge": Color("344654"),
		"highlight": base.lightened(0.31),
		"shadow": base.darkened(0.32),
	}


static func _choice(key: String, id: Variant) -> Dictionary:
	for field: Dictionary in _FIELDS:
		if field.key != key:
			continue
		for option: Dictionary in field.options:
			if option.id == id:
				return option
		break
	return {}
