class_name TestSoldArtStore
extends RefCounted

const Store: GDScript = preload("res://scripts/export/sold_art_store.gd")

static func run(t: Node) -> void:
	var directory: String = "user://test_sold_art_%s" % Crypto.new().generate_random_bytes(12).hex_encode()
	var artwork: Image = Image.create(8, 6, false, Image.FORMAT_RGBA8)
	artwork.fill(Color("3399cc"))
	var bytes: PackedByteArray = artwork.save_png_to_buffer()
	var previous_art: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	previous_art.fill(Color("dd8844"))
	var previous_bytes: PackedByteArray = previous_art.save_png_to_buffer()
	var existing: String = directory.path_join("별빛 고향.png")
	t.assert_eq(DirAccess.make_dir_recursive_absolute(directory), OK, "Create an isolated artwork destination")
	var destination: DirAccess = DirAccess.open(directory)
	# Linux treats filenames starting with a period as hidden, including temporary saves.
	destination.include_hidden = true
	var original: FileAccess = FileAccess.open(existing, FileAccess.WRITE)
	original.store_buffer(previous_bytes)
	original.close()
	var first: Dictionary = Store.save_png(bytes, "  별빛 고향  ", directory)
	var second: Dictionary = Store.save_png(bytes, "별빛 고향", directory)
	t.assert_true(bool(first.ok) and bool(second.ok), "The same Korean title can be saved twice")
	t.assert_true(str(first.path) != str(second.path), "Repeated titles get independent file names")
	t.assert_true(str(first.filename).begins_with("별빛 고향_"), "Trimmed Korean titles remain readable in the filename")
	t.assert_eq(FileAccess.get_file_as_bytes(str(first.path)), bytes, "Saved PNG bytes exactly preserve the exported artwork")
	t.assert_eq(FileAccess.get_file_as_bytes(str(second.path)), bytes, "A second save keeps the full PNG")
	t.assert_eq(FileAccess.get_file_as_bytes(existing), previous_bytes, "Automatic saving never replaces an existing named PNG artwork")
	var titles: Array[String] = ["../별빛\\고향:<\"이름\">|?*\n\t .", "CON", "NUL.txt", "com1", "LPT9.txt", "COM¹", "...", "<>", "가".repeat(80)]
	for title: String in titles:
		var result: Dictionary = Store.save_png(bytes, title, directory)
		t.assert_true(bool(result.ok), "Reserved and unsafe titles can be saved with a safe filename")
		if not bool(result.ok): continue
		var filename: String = str(result.filename)
		t.assert_eq(str(result.path).get_base_dir(), directory, "Titles cannot escape the chosen directory")
		t.assert_eq(filename, filename.get_file(), "Saved names contain no path components")
		for bad: String in ['<', '>', ':', '"', '/', '\\', '|', '?', '*', '\n', '\t']:
			t.assert_false(filename.contains(bad), "Saved filenames omit Windows forbidden and control characters")
		t.assert_le(filename.to_utf8_buffer().size(), 255, "Long Korean titles remain within filesystem component limits")
		t.assert_eq(FileAccess.get_file_as_bytes(str(result.path)), bytes, "Filename sanitizing never changes picture contents")
	t.assert_true(Store._safe_stem("NUL.txt").begins_with("그림_"), "Reserved device names with extensions receive a safe prefix")
	t.assert_true(Store._safe_stem("com1").begins_with("그림_"), "Reserved device names are recognized without case sensitivity")
	var before: PackedStringArray = destination.get_files()
	t.assert_false(bool(Store.save_png(PackedByteArray(), "빈 파일", directory).ok), "Empty PNG data is rejected")
	t.assert_false(bool(Store.save_png("broken PNG".to_utf8_buffer(), "깨진 파일", directory).ok), "Invalid PNG data is rejected")
	var truncated: PackedByteArray = bytes.slice(0, 40)
	var engine_errors: bool = Engine.print_error_messages
	t.assert_false(bool(Store.save_png(truncated, "잘린 파일", directory).ok), "A PNG header without decodable image data is rejected")
	t.assert_eq(Engine.print_error_messages, engine_errors, "Expected invalid input does not change engine error reporting")
	t.assert_false(bool(Store.save_png(bytes, "  \t\n ", directory).ok), "Blank titles cannot be saved")
	t.assert_false(bool(Store.save_png(bytes, "가".repeat(81), directory).ok), "Titles over eighty characters are rejected")
	t.assert_eq(destination.get_files(), before, "Invalid input creates no partial or extra files")
	var failed: Dictionary = Store.save_png(bytes, "저장 실패", existing)
	t.assert_false(bool(failed.ok), "A file cannot be used as a save directory")
	t.assert_true(not str(failed.error).is_empty() and str(failed.path).is_empty(), "Failed saves return a useful error and no claimed output")
	t.assert_eq(FileAccess.get_file_as_bytes(existing), previous_bytes, "Failed saves preserve the existing destination PNG")
	for filename: String in destination.get_files():
		t.assert_false(filename.ends_with(".tmp"), "Successful and rejected saves leave no temporary files")
		destination.remove(filename)
	DirAccess.remove_absolute(directory)
	t.assert_false(DirAccess.dir_exists_absolute(directory), "The isolated test directory is cleaned up")
