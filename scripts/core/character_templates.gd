class_name CharacterTemplates
extends RefCounted

const Math = preload("res://scripts/core/quadrilateral_math.gd")
const CORAL: Color = Color("f47962")
const TEAL: Color = Color("28aaa0")
const GOLD: Color = Color("f8c35b")
const NAVY: Color = Color("253852")
const BLUE: Color = Color("73a9cf")

static func all_templates() -> Array[Dictionary]:
	return [get_template("robot"), get_template("cat"), get_template("beetle")]

static func get_template(id: String) -> Dictionary:
	var parts: Array[Dictionary] = []
	match id:
		"robot":
			parts = [
				_part("antenna", "안테나", "square", Vector2(0, -153), Vector2(21, 21), GOLD, "head"),
				_part("head", "머리", "rectangle", Vector2(0, -106), Vector2(94, 66), TEAL, "head"),
				_part("body", "몸통", "trapezoid", Vector2(0, -12), Vector2(100, 100), CORAL, "body"),
				_part("chest", "가슴 보석", "rhombus", Vector2(0, -12), Vector2(38, 52), GOLD, "body"),
				_part("arm_left", "왼팔", "parallelogram", Vector2(-78, -11), Vector2(29, 76), TEAL, "arm_left", 14),
				_part("arm_right", "오른팔", "parallelogram", Vector2(78, -11), Vector2(29, 76), TEAL, "arm_right", -14),
				_part("hand_left", "왼손", "square", Vector2(-89, 43), Vector2(29, 29), GOLD, "arm_left"),
				_part("hand_right", "오른손", "square", Vector2(89, 43), Vector2(29, 29), GOLD, "arm_right"),
				_part("leg_left", "왼다리", "rectangle", Vector2(-27, 90), Vector2(29, 80), BLUE, "leg_left"),
				_part("leg_right", "오른다리", "rectangle", Vector2(27, 90), Vector2(29, 80), BLUE, "leg_right"),
				_part("foot_left", "왼발", "trapezoid", Vector2(-32, 141), Vector2(49, 24), NAVY, "leg_left"),
				_part("foot_right", "오른발", "trapezoid", Vector2(32, 141), Vector2(49, 24), NAVY, "leg_right")]
			return {"id": id, "name": "로봇 루미", "description": "도형을 모아 나만의 씩씩한 탐험 로봇을 만들어요.", "parts": parts}
		"cat":
			parts = [
				_part("tail", "꼬리", "parallelogram", Vector2(85, 28), Vector2(28, 118), GOLD, "body", 26),
				_part("tail_tip", "꼬리 끝", "rhombus", Vector2(108, -38), Vector2(28, 40), CORAL, "body", 15),
				_part("ear_left", "왼쪽 귀", "parallelogram", Vector2(-37, -127), Vector2(30, 45), CORAL, "head", -12),
				_part("ear_right", "오른쪽 귀", "parallelogram", Vector2(37, -127), Vector2(30, 45), CORAL, "head", 12),
				_part("head", "머리", "trapezoid", Vector2(0, -82), Vector2(108, 78), GOLD, "head", 180),
				_part("eye_left", "왼쪽 눈", "square", Vector2(-24, -90), Vector2(13, 13), NAVY, "head"),
				_part("eye_right", "오른쪽 눈", "square", Vector2(24, -90), Vector2(13, 13), NAVY, "head"),
				_part("nose", "코", "rhombus", Vector2(0, -65), Vector2(22, 16), CORAL, "head"),
				_part("body", "몸통", "rectangle", Vector2(0, 28), Vector2(79, 112), GOLD, "body"),
				_part("belly", "배", "square", Vector2(0, 26), Vector2(48, 48), Color("fff2cd"), "body"),
				_part("leg_left", "왼발", "trapezoid", Vector2(-27, 119), Vector2(43, 57), TEAL, "leg_left"),
				_part("leg_right", "오른발", "trapezoid", Vector2(27, 119), Vector2(43, 57), TEAL, "leg_right")]
			return {"id": id, "name": "고양이 모모", "description": "쫑긋한 귀와 긴 꼬리! 사각형 고양이와 모험해요.", "parts": parts}
		"beetle":
			parts = [
				_part("leg_left_1", "왼쪽 앞다리", "rectangle", Vector2(-76, -27), Vector2(58, 17), NAVY, "arm_left", 28),
				_part("leg_right_1", "오른쪽 앞다리", "rectangle", Vector2(76, -27), Vector2(58, 17), NAVY, "arm_right", -28),
				_part("leg_left_2", "왼쪽 가운데 다리", "rectangle", Vector2(-84, 34), Vector2(60, 17), NAVY, "arm_left", -8),
				_part("leg_right_2", "오른쪽 가운데 다리", "rectangle", Vector2(84, 34), Vector2(60, 17), NAVY, "arm_right", 8),
				_part("leg_left_3", "왼쪽 뒷다리", "rectangle", Vector2(-65, 100), Vector2(62, 17), NAVY, "leg_left", -38),
				_part("leg_right_3", "오른쪽 뒷다리", "rectangle", Vector2(65, 100), Vector2(62, 17), NAVY, "leg_right", 38),
				_part("antenna_left", "왼쪽 더듬이", "parallelogram", Vector2(-29, -139), Vector2(14, 50), GOLD, "head", -22),
				_part("antenna_right", "오른쪽 더듬이", "parallelogram", Vector2(29, -139), Vector2(14, 50), GOLD, "head", 22),
				_part("head", "머리", "square", Vector2(0, -88), Vector2(63, 63), TEAL, "head"),
				_part("body", "등 보석", "rhombus", Vector2(0, 32), Vector2(126, 186), GOLD, "body"),
				_part("wing_left", "왼쪽 날개", "trapezoid", Vector2(-31, 27), Vector2(48, 124), CORAL, "body", 180),
				_part("wing_right", "오른쪽 날개", "trapezoid", Vector2(31, 27), Vector2(48, 124), BLUE, "body", 180)]
			return {"id": id, "name": "딱정벌레 토토", "description": "여섯 다리로 숲을 누비는 알록달록 곤충을 만들어요.", "parts": parts}
	return {}

static func _part(id: String, label: String, kind: String, position: Vector2, dimensions: Vector2, color: Color, group: String, rotation: float = 0.0) -> Dictionary:
	var vertices: PackedVector2Array = Math.create_vertices(kind, dimensions)
	return {"id": id, "label": label, "kind": kind, "position": position, "vertices": Math.rotate_vertices(vertices, rotation), "color": color, "group": group}
