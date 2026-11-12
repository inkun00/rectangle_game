class_name PadletUploader
extends RefCounted

const PRODUCTION_ORIGIN: String = "https://rectangle-game-snowy.vercel.app"
const BOARD_URL: String = "https://padlet.com/inkun02/padlet-s025d52oqqhj786g8cry"

static func upload(owner: Node, entry: Dictionary, bytes: PackedByteArray) -> Dictionary:
	var origin: String = PRODUCTION_ORIGIN
	if OS.has_feature("web"):
		var web_origin: Variant = JavaScriptBridge.eval("window.location.origin", true)
		if web_origin is String: origin = str(web_origin)
	var request: HTTPRequest = HTTPRequest.new()
	request.timeout = 55.0
	request.body_size_limit = 65536
	owner.add_child(request)
	var payload: Dictionary = {
		"id": entry.id, "author": entry.author, "title": entry.title,
		"description": entry.description, "price": int(entry.price),
		"png_base64": Marshalls.raw_to_base64(bytes)
	}
	var error: Error = request.request(origin + "/api/padlet-artworks", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		request.queue_free()
		return _failure("인터넷 연결을 확인하고 패들릿 등록을 다시 시도해 주세요.")
	var response: Array = await request.request_completed
	request.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		return _failure("패들릿 응답을 받지 못했어요. 판매와 PNG는 보존했어요. 다시 시도해 주세요.")
	var status: int = int(response[1])
	var body: PackedByteArray = response[3]
	var decoded: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not decoded is Dictionary: return _failure("패들릿 연결을 확인하지 못했어요. 잠시 후 다시 시도해 주세요.")
	if status >= 200 and status < 300 and decoded.get("ok") == true:
		var post_url: String = str(decoded.get("post_url", ""))
		if not ArtPublicationStore._valid_post_url(post_url): return _failure("패들릿 등록 주소를 확인하지 못했어요.")
		return {"ok": true, "post_url": post_url, "moderation_pending": decoded.get("moderation_pending", false) == true}
	var message: String = str(decoded.get("error", "패들릿 등록을 마치지 못했어요. 다시 시도해 주세요.")).left(300)
	return _failure(message, status in [202, 400, 409, 413, 415, 422])

static func _failure(message: String, item_error: bool = false) -> Dictionary:
	return {"ok": false, "error": message, "item_error": item_error}
