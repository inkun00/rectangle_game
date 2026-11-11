extends RefCounted

static func run(t: Node) -> void:
	var payload: PackedByteArray = "unchanged artwork".to_utf8_buffer()
	var digest: String = "unchanged artwork".sha256_text()
	var entry: Dictionary = {"url": "feature-drawing-%s.pck" % digest.left(12), "sha256": digest, "bytes": payload.size()}
	t.assert_true(WebResourcePacks.valid_entry("drawing", entry), "A content-addressed pack manifest is accepted")
	t.assert_true(WebResourcePacks.valid_bytes(payload, entry), "Exact downloaded bytes pass integrity validation")
	t.assert_false(WebResourcePacks.valid_bytes("different artwork".to_utf8_buffer(), entry), "Changed data fails content hash validation")
	t.assert_false(WebResourcePacks.valid_bytes(payload.slice(1), entry), "Truncated downloads fail validation")
	t.assert_false(WebResourcePacks.valid_entry("../drawing", entry), "Unknown or escaping feature names are rejected")
	for key: String in ["url", "sha256", "bytes"]:
		var missing: Dictionary = entry.duplicate()
		missing.erase(key)
		t.assert_false(WebResourcePacks.valid_entry("drawing", missing), "Incomplete manifest rejected: " + key)
	for invalid_size: Variant in [0, -1, 0.5, 100_000_001, "12"]:
		var invalid: Dictionary = entry.duplicate()
		invalid.bytes = invalid_size
		t.assert_false(WebResourcePacks.valid_entry("drawing", invalid), "Invalid resource length is rejected")
	var external: Dictionary = entry.duplicate()
	external.url = "https://example.invalid/pack.pck"
	t.assert_false(WebResourcePacks.valid_entry("drawing", external), "Packs are restricted to their deployment's content-addressed URL")
	t.assert_false(WebResourcePacks.is_web_delivery(), "Native headless suite retains complete offline resources")
	t.assert_true(await WebResourcePacks.ensure("drawing"), "Desktop feature access never requires a download")
