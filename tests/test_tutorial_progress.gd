class_name TestTutorialProgress
extends RefCounted

const Catalog: GDScript = preload("res://scripts/tutorial/tutorial_catalog.gd")
const Progress: GDScript = preload("res://scripts/tutorial/tutorial_progress.gd")

static func run(t: Node) -> void:
	_test_catalog_contract(t)
	_test_statuses_and_validation(t)
	_test_files(t)

static func _test_catalog_contract(t: Node) -> void:
	var expected_events: Dictionary = {
		"learning": ["learning_measure", "learning_adjust", "learning_check"],
		"drawing": ["drawing_add", "drawing_edit", "drawing_undo"],
		"masterpiece": ["masterpiece_chosen", "masterpiece_guide", "drawing_add"],
		"construction": ["construction_accept", "construction_place", "construction_inspect"],
		"my_house": ["my_house_place", "my_house_view"],
		"workshop": ["workshop_place", "workshop_ready"],
		"world": ["world_move", "world_jump", "world_inventory", "world_journal"]
	}
	t.assert_eq(Catalog.MODE_IDS.size(), 7, "Tutorials cover every activity and both creative submodes")
	for mode: String in Catalog.MODE_IDS:
		t.assert_false(Catalog.title(mode).is_empty(), "Every mode has a readable tutorial title")
		var entries: Array[Dictionary] = Catalog.steps(mode)
		t.assert_true(entries.size() >= 5 and entries.size() <= 8, "Every tutorial is a short conversation")
		var actions: Array[String] = []
		for entry: Dictionary in entries:
			for key: String in ["speaker", "text", "goal", "event", "target"]:
				t.assert_true(entry.has(key) and entry[key] is String, "Dialogue and target fields have the director's required type")
			t.assert_false(str(entry.get("text", "")).is_empty(), "Every tutorial step includes dialogue")
			t.assert_false(str(entry.get("goal", "")).is_empty(), "Every step explains its immediate goal")
			t.assert_eq(entry.get("portrait"), 3, "Tutorials use the existing generated guide portrait")
			if not str(entry.get("event", "")).is_empty():
				actions.append(str(entry["event"]))
				t.assert_eq(entry["target"], entry["event"], "Action targets use stable semantic IDs")
			t.assert_true(str(entry.get("text", "")).length() <= 120, "Guide dialogue stays short enough to read while playing")
		t.assert_eq(actions, expected_events[mode], "Action gates use only the supported events in order")
		entries[0]["text"] = "changed by a caller"
		t.assert_false(Catalog.steps(mode)[0]["text"] == "changed by a caller", "One tutorial view cannot mutate the shared catalog")
	t.assert_true(Catalog.steps("unknown").is_empty(), "Unknown modes have no tutorial content")
	t.assert_eq(Catalog.title("unknown"), "", "Unknown modes have no misleading title")

static func _test_statuses_and_validation(t: Node) -> void:
	var progress: Progress = Progress.new()
	var emissions: Array[int] = [0]
	progress.changed.connect(func() -> void: emissions[0] += 1)
	for mode: String in Catalog.MODE_IDS:
		t.assert_true(progress.should_offer(mode), "A new device offers each known tutorial")
	t.assert_false(progress.should_offer("unknown"), "Unknown modes are never automatically offered")
	t.assert_false(progress.mark("unknown", "completed"), "Unknown tutorial IDs cannot enter saved preferences")
	t.assert_false(progress.mark("drawing", "started"), "Only explicit completion or skip dismisses onboarding")
	t.assert_eq(emissions[0], 0, "Rejected tutorial updates emit no change")
	t.assert_true(progress.mark("drawing", "completed"), "A completed tutorial is recorded")
	t.assert_true(progress.mark("world", "skipped"), "An explicit skip is recorded separately")
	t.assert_false(progress.should_offer("drawing"), "Completed tutorials do not interrupt the next entry")
	t.assert_false(progress.should_offer("world"), "Skipped tutorials do not interrupt the next entry")
	t.assert_true(progress.mark("drawing", "completed"), "Recording the same valid status is harmless")
	t.assert_eq(emissions[0], 2, "An unchanged preference does not emit duplicate changes")
	var snapshot: Dictionary = progress.serialize()
	(snapshot["statuses"] as Dictionary)["drawing"] = "skipped"
	t.assert_eq(progress.statuses["drawing"], "completed", "Serialized preferences cannot mutate live progress")
	var before: Dictionary = progress.serialize()
	var invalid_data: Array[Dictionary] = [
		{}, {"version": 2, "statuses": {}}, {"version": 1.5, "statuses": {}},
		{"version": true, "statuses": {}}, {"version": "1", "statuses": {}},
		{"version": null, "statuses": {}}, {"version": {}, "statuses": {}},
		{"version": NAN, "statuses": {}}, {"version": INF, "statuses": {}},
		{"version": 1, "statuses": []}, {"version": 1, "statuses": {"unknown": "completed"}},
		{"version": 1, "statuses": {"drawing": "started"}}, {"version": 1, "statuses": {"drawing": true}},
		{"version": 1, "statuses": {"drawing": "skipped", "world": 3}},
		{"version": 1, "statuses": {5: "completed"}}, {"version": 1, "statuses": {}, "unknown": true}
	]
	for invalid: Dictionary in invalid_data:
		t.assert_false(progress.restore(invalid), "Malformed tutorial data is rejected")
		t.assert_eq(progress.serialize(), before, "Rejected tutorial data leaves all live statuses untouched")
		t.assert_eq(emissions[0], 2, "Rejected restore emits no change")
	t.assert_true(progress.restore({"version": 1.0, "statuses": {"drawing": "skipped"}}), "JSON's numeric version restores after complete validation")
	t.assert_eq(progress.statuses, {"drawing": "skipped"}, "Valid restore replaces rather than merges the anonymous preferences")
	t.assert_true(progress.mark("drawing", "completed"), "Replaying a skipped tutorial can mark it completed")
	t.assert_eq(progress.statuses["drawing"], "completed", "Replay updates only its own mode")

static func _test_files(t: Node) -> void:
	var path: String = "user://quadrilateral_tutorial_test_%d.json" % Time.get_ticks_usec()
	var progress: Progress = Progress.new()
	t.assert_false(progress.load_file(path), "A missing tutorial file keeps the fresh defaults")
	progress.mark("learning", "completed")
	progress.mark("masterpiece", "skipped")
	t.assert_eq(progress.save_file(path), OK, "Tutorial preferences save to an isolated test path")
	progress.mark("construction", "completed")
	t.assert_eq(progress.save_file(path), OK, "Replacing a tutorial file succeeds with a recovery copy")
	t.assert_true(FileAccess.file_exists(path + ".bak"), "An overwrite preserves the previous preference file")
	var loaded: Progress = Progress.new()
	t.assert_true(loaded.load_file(path), "Tutorial statuses load independently of all activity saves")
	t.assert_eq(loaded.serialize(), progress.serialize(), "Completion and skip statuses round trip exactly")
	var before: Dictionary = loaded.serialize()
	for invalid: String in ["{broken", "[]", '{"version":2,"statuses":{}}', '{"version":1,"statuses":{"drawing":"started"}}', " ".repeat(Progress.MAX_BYTES + 1)]:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		t.assert_not_null(file, "The isolated corrupt-file fixture opens")
		if file == null: continue
		file.store_string(invalid)
		file.close()
		t.assert_false(loaded.load_file(path), "Corrupt, unknown, and oversized tutorial files are rejected")
		t.assert_eq(loaded.serialize(), before, "A rejected file never partially changes the current tutorial preferences")
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
