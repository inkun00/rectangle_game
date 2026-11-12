class_name TestArtPublicationStore
extends RefCounted

const Metadata = preload("res://scripts/export/art_submission_metadata.gd")
const Store = preload("res://scripts/export/art_publication_store.gd")
const Samples = preload("res://tests/test_art_composition.gd")
const BOARD: String = "https://padlet.com/inkun02/padlet-s025d52oqqhj786g8cry"

static func run(t: Node) -> void:
	_test_metadata(t)
	_test_receipt_gating_and_roundtrip(t)
	_test_invalid_load_and_atomic_update(t)

static func _test_metadata(t: Node) -> void:
	t.assert_eq(Metadata.validation_error("  네모별  ", "  나의 그림  ", " 설명 첫 줄\n\t다음 줄 "), "", "Korean names and a multiline description remain valid after trimming")
	t.assert_eq(Metadata.validation_error("가".repeat(40), "나".repeat(80), "다".repeat(1000)), "", "All maximum-length metadata fields accept their inclusive boundary")
	var cases: Array[Array] = [
		[" ", "그림", "설명"], ["작가", "\t", "설명"], ["작가", "그림", "\r\n\t"],
		[null, "그림", "설명"], ["작가", 4, "설명"], ["작가", "그림", []],
		["가".repeat(41), "그림", "설명"], ["작가", "가".repeat(81), "설명"], ["작가", "그림", "가".repeat(1001)],
		["작\n가", "그림", "설명"], ["작가", "그\t림", "설명"], ["작가", "그림", "설명" + String.chr(1)],
		["작가" + String.chr(127), "그림", "설명"], ["작가", "그림", String.chr(159)]
	]
	for values: Array in cases:
		t.assert_false(Metadata.validation_error(values[0], values[1], values[2]).is_empty(), "Invalid or unsafe metadata is rejected before publishing: " + str(values))

static func _test_receipt_gating_and_roundtrip(t: Node) -> void:
	var directory: String = _directory()
	DirAccess.make_dir_recursive_absolute(directory)
	var store: ArtPublicationStore = Store.new()
	store.path = directory.path_join("queue.json")
	var offer: Dictionary = ArtMarket.quote(Samples.house())
	var bytes: PackedByteArray = _png()
	var saved: Dictionary = SoldArtStore.save_png(bytes, "새 집", directory.path_join("art"))
	t.assert_true(saved.ok, "The publication fixture uses a real valid PNG")
	var prepared: Dictionary = store.prepare(_metadata(), offer, saved, bytes)
	t.assert_true(prepared.ok, "A valid finished artwork creates durable publication metadata")
	if not bool(prepared.ok):
		_cleanup(directory)
		return
	var entry: Dictionary = prepared.entry
	t.assert_eq(str(entry.id).length(), 32, "Each publication receives a stable opaque request identifier")
	t.assert_eq(entry.author, "네모별", "Persisted metadata trims the display name")
	t.assert_eq(entry.description, "사각형으로 만든 집이에요.\n두 가지 색을 골랐어요.", "Persisted descriptions retain intentional line breaks")
	t.assert_eq(store.last_author(), "네모별", "The durable outbox remembers the previous artist's name")
	t.assert_eq(store.pending([]).size(), 0, "Preparing metadata before payment cannot publish an unsold painting")
	var receipt: Dictionary = ArtMarket.receipt_from_quote(offer, "새 집")
	var receipts: Array[Dictionary] = [receipt]
	t.assert_eq(store.pending(receipts).size(), 1, "The matching committed sale enables its prepared publication")
	var wrong_title: Dictionary = receipt.duplicate(true)
	wrong_title.title = "다른 집"
	t.assert_eq(store.pending([wrong_title]).size(), 0, "A different titled receipt cannot authorize a prepared upload")
	var wrong_price: Dictionary = receipt.duplicate(true)
	wrong_price.price = int(receipt.price) + 100
	t.assert_eq(store.pending([wrong_price]).size(), 0, "A different paid price cannot authorize a prepared upload")
	var restored: ArtPublicationStore = Store.new()
	restored.path = store.path
	t.assert_true(restored.load_file().ok, "Publication metadata validates after a JSON round trip")
	var expected_records: Array = JSON.parse_string(JSON.stringify(store.entries))
	t.assert_eq(restored.entries, expected_records, "Reload preserves the request ID, PNG path and all artwork metadata through JSON numeric conversion")
	t.assert_eq(restored.read_png(restored.entries[0], directory.path_join("art")), bytes, "Reloaded publication reads the exact original PNG bytes")
	t.assert_true(restored.read_png(restored.entries[0], directory.path_join("elsewhere")).is_empty(), "The publisher cannot read a PNG outside its designated artwork directory")
	var pending_copy: Array[Dictionary] = restored.pending(receipts)
	pending_copy[0].author = "바뀐 이름"
	t.assert_eq(restored.entries[0].author, "네모별", "Returned upload payloads cannot mutate the durable queue in memory")
	var file: FileAccess = FileAccess.open(str(saved.path), FileAccess.WRITE)
	file.store_buffer(_png(Color.RED))
	file.close()
	t.assert_true(restored.read_png(entry, directory.path_join("art")).is_empty(), "Replacing a stored image cannot silently publish a different painting under the same request ID")
	t.assert_false(restored.mark_published(str(entry.id), "https://padlet.com.attacker.example/post").ok, "A foreign URL cannot be persisted as a successful Padlet publication")
	t.assert_true(restored.mark_published(str(entry.id), BOARD).ok, "Confirmed Padlet registration is durably recorded")
	t.assert_eq(restored.pending(receipts).size(), 0, "Published artworks are excluded from future retry batches")
	t.assert_false(restored.prepare(_metadata(), offer, saved, bytes).ok, "An already published fingerprint cannot be prepared for another post")
	var published: ArtPublicationStore = Store.new()
	published.path = restored.path
	t.assert_true(published.load_file().ok, "A published queue remains loadable")
	t.assert_eq(published.pending(receipts).size(), 0, "A restart cannot requeue a confirmed publication")
	_cleanup(directory)

static func _test_invalid_load_and_atomic_update(t: Node) -> void:
	var directory: String = _directory()
	DirAccess.make_dir_recursive_absolute(directory)
	var store: ArtPublicationStore = Store.new()
	store.path = directory.path_join("queue.json")
	var offer: Dictionary = ArtMarket.quote(Samples.house())
	var bytes: PackedByteArray = _png()
	var saved: Dictionary = SoldArtStore.save_png(bytes, "새 집", directory.path_join("art"))
	var prepared: Dictionary = store.prepare(_metadata(), offer, saved, bytes)
	t.assert_true(prepared.ok, "The corruption tests start from a valid durable outbox")
	if not bool(prepared.ok):
		_cleanup(directory)
		return
	var previous: Array[Dictionary] = store.entries.duplicate(true)
	var original_text: String = FileAccess.get_file_as_string(store.path)
	var malformed: Array[Variant] = [null, [], {"version": 2, "entries": previous}, {"version": 1, "entries": [previous[0], previous[0]]}]
	for key: String in ["id", "author", "description", "price", "filename", "status", "post_url"]:
		var bad: Dictionary = previous[0].duplicate(true)
		match key:
			"id": bad.id = "not-an-id"
			"author": bad.author = ""
			"description": bad.description = "x".repeat(1001)
			"price": bad.price = 3.5
			"filename": bad.filename = "../unrelated.png"
			"status": bad.status = "anything"
			"post_url": bad.post_url = BOARD
		malformed.append({"version": 1, "entries": [bad]})
	for data: Variant in malformed:
		_write(store.path, JSON.stringify(data))
		t.assert_false(store.load_file().ok, "Malformed publication saves are rejected")
		t.assert_eq(store.entries, previous, "Rejected publication data leaves the current live queue unchanged")
	_write(store.path, original_text)
	DirAccess.make_dir_absolute(store.path + ".tmp")
	t.assert_false(store.mark_published(str(previous[0].id), BOARD).ok, "An unwritable temporary outbox prevents publishing a misleading local success state")
	t.assert_eq(store.entries, previous, "Failed status persistence leaves the original retryable entry in memory")
	t.assert_eq(FileAccess.get_file_as_string(store.path), original_text, "Failed status persistence preserves the previous durable queue")
	DirAccess.remove_absolute(store.path + ".tmp")
	t.assert_true(store.mark_published(str(previous[0].id), BOARD).ok, "Repairing the destination allows a safe result-only retry")
	# Simulate interruption between backing up and renaming the new queue.
	DirAccess.remove_absolute(store.path)
	var recovered: ArtPublicationStore = Store.new()
	recovered.path = store.path
	t.assert_true(recovered.load_file().ok, "An interrupted atomic replace can recover the previous complete backup")
	var expected_records: Array = JSON.parse_string(JSON.stringify(previous))
	t.assert_eq(recovered.entries, expected_records, "Backup recovery retains the original stable request ID for server reconciliation")
	_cleanup(directory)

static func _metadata() -> Dictionary:
	return {"author": "  네모별  ", "title": " 새 집 ", "description": " 사각형으로 만든 집이에요.\n두 가지 색을 골랐어요. "}

static func _png(color: Color = Color.CORNFLOWER_BLUE) -> PackedByteArray:
	var image: Image = Image.create(960, 600, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image.save_png_to_buffer()

static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

static func _directory() -> String:
	return "user://test_art_publications_%s" % Crypto.new().generate_random_bytes(12).hex_encode()

static func _cleanup(directory: String) -> void:
	if not directory.begins_with("user://test_art_publications_"): return
	var images: String = directory.path_join("art")
	if DirAccess.dir_exists_absolute(images):
		for filename: String in DirAccess.get_files_at(images): DirAccess.remove_absolute(images.path_join(filename))
		DirAccess.remove_absolute(images)
	for filename: String in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
