class_name ProgressionTransactions
extends RefCounted

const State = preload("res://scripts/construction/construction_state.gd")
const Saves = preload("res://scripts/construction/construction_save_store.gd")

## Prepare and validate a complete ledger, durably publish it, then update the
## live economy once. A failed write never consumes a picture or a purchase.
static func commit(state: State, action: String, payload: Variant = null, path: String = Saves.SAVE_PATH, persist: bool = true) -> Dictionary:
	var candidate: State = State.new()
	if not candidate.restore(state.serialize()):
		return {"ok": false, "error": "장부를 확인하지 못했어요. 현재 그림과 돈은 그대로예요."}
	var result: Dictionary
	match action:
		"sell_art":
			if not payload is Dictionary: return {"ok": false, "error": "판매할 그림을 확인해 주세요."}
			result = candidate.sell_art(payload)
		"purchase_part":
			if not payload is String: return {"ok": false, "error": "구매할 부품을 선택해 주세요."}
			result = candidate.purchase_ship_part(payload)
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
