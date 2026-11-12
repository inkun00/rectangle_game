class_name ArtSubmissionMetadata
extends RefCounted

const MAX_AUTHOR_LENGTH: int = 40
const MAX_TITLE_LENGTH: int = 80
const MAX_DESCRIPTION_LENGTH: int = 1000

static func validation_error(author: Variant, title: Variant, description: Variant) -> String:
	var error: String = _field_error(author, "사용자 이름", MAX_AUTHOR_LENGTH)
	if not error.is_empty(): return error
	error = _field_error(title, "그림 제목", MAX_TITLE_LENGTH)
	if not error.is_empty(): return error
	return _field_error(description, "그림 설명", MAX_DESCRIPTION_LENGTH, true)

static func _field_error(value: Variant, label: String, maximum: int, multiline: bool = false) -> String:
	if not value is String:
		return "%s을 적어 주세요." % label
	var text: String = str(value)
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty() or trimmed.length() > maximum:
		return "%s을 1~%d자로 적어 주세요." % [label, maximum]
	for index: int in range(text.length()):
		var codepoint: int = text.unicode_at(index)
		if multiline and codepoint in [9, 10, 13]: continue
		if codepoint < 32 or (codepoint >= 127 and codepoint <= 159):
			return "%s에 사용할 수 없는 문자가 있어요. 다시 적어 주세요." % label
	return ""
