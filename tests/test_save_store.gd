class_name TestSaveStore
extends RefCounted

const Store = preload("res://scripts/core/world_save_store.gd")
const TEST_PATH: String = "user://quad_save_schema_test.json"


static func run(t: Node) -> void:
	# This suite owns one fixture file; it never reads or replaces the real save.
	var fixture: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	t.assert_not_null(fixture, "Save schema test fixture can be created")
	if fixture == null:
		return
	fixture.close()
	var valid: Dictionary = {"version": 1, "editor": {"sample": "character"}, "journal": {}, "world": {}}
	_write(JSON.stringify(valid))
	var loaded: Dictionary = Store.load_game(TEST_PATH)
	t.assert_false(loaded.is_empty(), "Valid schema survives JSON numeric decoding")
	t.assert_eq(int(loaded.get("version", -1)), 1, "Schema version value is preserved")
	t.assert_eq(loaded.get("editor", {}), valid["editor"], "Component dictionaries are preserved")
	_write('{"version":1.0,"editor":{},"journal":{},"world":{}}')
	t.assert_false(Store.load_game(TEST_PATH).is_empty(), "Integral JSON float version is valid")
	var invalid_versions: Array = [{}, [], null, true, false, "1", "invalid", 1.5, 0, -1, 2]
	for version: Variant in invalid_versions:
		var data: Dictionary = valid.duplicate(true)
		data["version"] = version
		_write(JSON.stringify(data))
		t.assert_true(Store.load_game(TEST_PATH).is_empty(), "Invalid version type/value is rejected without runtime error: " + str(version))
	var missing_version: Dictionary = valid.duplicate(true)
	missing_version.erase("version")
	_write(JSON.stringify(missing_version))
	t.assert_true(Store.load_game(TEST_PATH).is_empty(), "Missing schema version is rejected")
	for malformed: String in ["", "{", "{invalid", "null", "[]", "true", "1", '"save"']:
		_write(malformed)
		t.assert_true(Store.load_game(TEST_PATH).is_empty(), "Malformed JSON or non-object root is rejected")
	for field: String in ["editor", "journal", "world"]:
		for invalid_field: Variant in [null, [], "wrong", 1, true]:
			var data: Dictionary = valid.duplicate(true)
			data[field] = invalid_field
			_write(JSON.stringify(data))
			t.assert_true(Store.load_game(TEST_PATH).is_empty(), "Save component must be a dictionary: " + field)
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(field)
		_write(JSON.stringify(missing))
		t.assert_true(Store.load_game(TEST_PATH).is_empty(), "Missing save component is rejected: " + field)
	# Component-specific validation belongs to the document, journal and world.
	var delegated: Dictionary = valid.duplicate(true)
	delegated["world"] = {"player_x": "invalid coordinate"}
	_write(JSON.stringify(delegated))
	t.assert_false(Store.load_game(TEST_PATH).is_empty(), "The store preserves dictionaries for component validation")
	t.assert_eq(DirAccess.remove_absolute(TEST_PATH), OK, "Only this suite's exact fixture file is removed")
	t.assert_true(Store.load_game(TEST_PATH).is_empty(), "Missing save file returns an empty result")


static func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
