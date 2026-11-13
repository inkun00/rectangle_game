class_name ProgressionTransactions
extends RefCounted

const State = preload("res://scripts/construction/construction_state.gd")
const Saves = preload("res://scripts/construction/construction_save_store.gd")
const Market = preload("res://scripts/economy/art_market.gd")

## Prepare and validate a complete ledger, durably publish it, then update the
## live economy once. A failed write never consumes a picture or a purchase.
static func commit(state: State, action: String, payload: Variant = null, path: String = Saves.SAVE_PATH, persist: bool = true) -> Dictionary:
	var candidate: State = State.new()
	if not candidate.restore(state.serialize()):
		return {"ok": false, "error": "장부를 확인하지 못했어요. 현재 그림과 돈은 그대로예요."}
	var result: Dictionary
	match action:
		"village_rewards":
			if not payload is Array: return {"ok": false, "error": "주민의 부탁 기록을 확인해 주세요."}
			result = candidate.claim_village_rewards(payload)
			if bool(result.ok) and int(result.price) == 0: return result
		"sell_art":
			if not payload is Dictionary: return {"ok": false, "error": "판매할 그림을 확인해 주세요."}
			if payload.has("document") or payload.has("title"):
				if not payload.get("document") is Dictionary: return {"ok": false, "error": "판매할 그림을 확인해 주세요."}
				if not Market.valid_title(payload.get("title")):
					return {"ok": false, "error": "작품 제목을 줄바꿈 없이 1~%d자로 입력해 주세요." % Market.MAX_TITLE_LENGTH}
				result = candidate.sell_art(payload.document, str(payload.title))
			else:
				# Existing callers pass the drawing document directly and keep
				# their automatically numbered title.
				result = candidate.sell_art(payload)
		"purchase_part":
			if not payload is String: return {"ok": false, "error": "구매할 부품을 선택해 주세요."}
			result = candidate.purchase_ship_part(payload)
		"customize_ship_part":
			if not payload is Dictionary or not payload.get("id") is String or not payload.get("kind") is String or not payload.get("color") is String:
				return {"ok": false, "error": "부품의 모양과 색을 확인해 주세요."}
			result = candidate.customize_ship_part(payload.id, payload.kind, payload.color)
		"launch":
			result = candidate.launch_ship()
		_:
			return {"ok": false, "error": "할 수 없는 거래예요."}
	if not bool(result.get("ok", false)): return result
	if persist:
		var saved: Dictionary = Saves.save(path, candidate)
		if not bool(saved.ok):
			return {"ok": false, "error": "저장하지 못해 거래를 취소했어요. 돈과 부품은 그대로예요. " + str(saved.error)}
	state.apply_economy_from(candidate)
	return result
