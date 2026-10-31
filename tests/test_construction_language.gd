class_name TestConstructionLanguage
extends RefCounted

const Language = preload("res://scripts/construction/construction_language.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Card = preload("res://scenes/construction/material_card.gd")

static func run(t: Node) -> void:
	var labels: Dictionary = {
		"자재 라이브러리": "재료 상자", "정면 입면도": "집 앞모습", "입면 설계": "집 짓기",
		"시공 검사": "튼튼한지 확인", "정산": "보상 받기", "견적": "예상 비용",
		"외장 패널": "꾸미기 판", "외장패널": "꾸미기 판", "처마": "지붕 끝", "하중": "누르는 무게",
		"보": "가로 받침", "기초": "바닥 받침", "준공 완료": "집 완성!", "자재 예산": "재료에 쓸 돈"
	}
	for original: String in labels:
		t.assert_eq(Language.simplify(original), labels[original], "Construction button uses plain Korean: " + original)
	for quality: String in ["집의 비례", "지붕과 처마의 마감"]:
		var friendly: String = Language.simplify(quality)
		t.assert_true(friendly.contains("어울림"), "Building quality uses a familiar description")
		t.assert_eq(Language.simplify(friendly), friendly, "Repeated refresh leaves quality copy unchanged")
	var sentences: Dictionary = {
		"문·창문 위에는 받침보가 필요해요.": "문·창문 위에는 가로 받침이 필요해요.",
		"벽과 보를 놓아요.": "벽과 가로 받침을 놓아요.",
		"보와 지붕을 이어 보세요.": "가로 받침과 지붕을 이어 보세요.",
		"정보를 보고 보너스와 보상 기록을 살펴보는 중이에요.": "정보를 보고 보너스와 보상 기록을 살펴보는 중이에요.",
		"서로 마주 보는 변이 두 쌍 있어요.": "서로 마주 보는 변이 두 쌍 있어요.",
		"시공 검사를 다시 해 주세요.": "튼튼한지 다시 확인해 주세요.",
		"정산했거나 아직 의뢰를 받지 않았어요.": "보상을 받았거나 아직 부탁을 받지 않았어요.",
		"같은 집의 보수는 한 번만 받아요.": "같은 집의 보상은 한 번만 받아요."
	}
	for original: String in sentences:
		t.assert_eq(Language.simplify(original), sentences[original], "Simplification respects Korean particles and unrelated words")
	for kind: String in QuadrilateralMath.KINDS:
		var name: String = QuadrilateralMath.kind_name(kind)
		t.assert_eq(Language.simplify(name), name, "Curriculum family name remains authoritative")
		t.assert_true(not Language.explanation(name).is_empty(), "Each required shape has child-friendly help")
	t.assert_true(Language.explanation("사다리꼴").contains("한 쌍 이상"), "Trapezoid help follows inclusive curriculum")
	t.assert_true(Language.explanation("정사각형").contains("네 변의 길이가 같고") and Language.explanation("정사각형").contains("네 각이 모두 직각"), "Square help explains its two observable conditions without requiring a parent-family chain")
	t.assert_true(Language.explanation("평행").contains("수직"), "Parallel distance is explained with perpendicular measurement")
	t.assert_eq(Language.explanation("받침보"), Language.explanation("가로 받침"), "Old and plain-language terms resolve to the same help")
	t.assert_eq(Language.explanation("not-a-term"), "", "Unknown glossary term does not invent a definition")
	var entries: Array[Dictionary] = Language.glossary()
	t.assert_gt(entries.size(), 15, "Visible help dialog can explain building, geometry and money")
	entries[0].title = "changed outside"
	t.assert_false(str(Language.glossary()[0].title) == "changed outside", "Help dialog cannot mutate glossary definitions")
	t.assert_true(Language.help_for("시공 검사와 평행사변형").contains("튼튼한지 확인"), "Contextual tooltip explains original technical terms")
	t.assert_true(Language.help_for("보너스").contains("더 받을"), "Short beam term does not swallow bonus help")
	for item: Dictionary in Catalog.materials():
		var raw: String = "%s\n%s\n%s" % [str(item.label), Catalog.short_label(str(item.id)), str(item.description)]
		var simplified: String = Language.simplify(raw)
		t.assert_eq(Language.simplify(simplified), simplified, "Double-rendering copy never repeats replacement words")
		for jargon: String in ["외장", "받침보", "처마", "하중", "벽체", "구조재"]:
			t.assert_false(simplified.contains(jargon), "Every material display removes difficult term: " + jargon)
	for entry: Dictionary in Language.glossary():
		var copy: String = "%s\n%s" % [str(entry.title), str(entry.explanation)]
		t.assert_eq(Language.simplify(Language.simplify(copy)), Language.simplify(copy), "Glossary descriptions remain stable across UI refreshes")
	var card: Card = Card.new()
	card.configure("beam_trapezoid")
	t.add_child(card)
	t.assert_true(card.text.contains("가로 받침"), "Material accessibility label uses the same friendly name")
	t.assert_true(card.tooltip_text.contains("사다리꼴:") and card.tooltip_text.contains("한 쌍 이상"), "Material tooltip explains its preserved geometry name")
	t.assert_false(card.tooltip_text.contains("추정가"), "Quick material help keeps price evidence in its dedicated screen")
	t.assert_ge(card._sample.custom_minimum_size.x, 48.0, "Material previews retain readable width beside the enlarged name")
	t.assert_ge(card._sample.custom_minimum_size.y, 48.0, "Material previews retain readable height")
	card.free()
