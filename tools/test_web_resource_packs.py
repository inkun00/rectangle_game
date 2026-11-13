"""Verify delivery partitions, immutable URLs, corruption checks and encodings."""

import gzip
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import brotli

import prepare_web_release as release
from web_resource_packs import PackEntry, ResourcePack, read_pack, split_pack, write_pack


def imported(source: str, cache: str, pixels: bytes) -> tuple[PackEntry, PackEntry]:
    return (
        PackEntry(source + ".import", ('[remap]\nuid="uid://sameidentity"\n'
                  f'path="res://.godot/imported/{cache}.ctex"\n').encode()),
        PackEntry(".godot/imported/" + cache + ".ctex", pixels),
    )


def fixture() -> ResourcePack:
    entries = [
        PackEntry("project.binary", b"bootstrap configuration"),
        PackEntry("scripts/main.gd.remap", b"initial script"),
        PackEntry("assets/video/quadrilateral-opening.ogv", b"unchanged video bytes" * 50),
    ]
    for source, cache in (
        ("assets/generated/starfront-v1/skin.webp", "skin"),
        ("assets/generated/starfront-v1/crew.webp", "crew"),
        ("assets/generated/starfront-v1/brick.webp", "brick"),
        ("assets/generated/drawing/backgrounds/forest.webp", "drawingforest"),
        ("assets/generated/drawing/masterpieces/guide.svg", "guide"),
        ("assets/generated/starfront-hd/backgrounds/forest.webp", "adventureforest"),
        ("assets/generated/starfront-hd/backgrounds/observatory.webp", "home"),
        ("assets/generated/starfront-hd/materials/details-a.webp", "material"),
        ("assets/generated/opening-v1/planet.webp", "planet"),
        ("assets/generated/ship-parts-v2/standard.webp", "shipatlas"),
    ):
        entries.extend(imported(source, cache, (cache.encode() + b"\0RGBA") * 40))
    return ResourcePack((4, 7, 2), tuple(entries))


class PackTests(unittest.TestCase):
    def test_pck_roundtrip_retains_every_resource_byte_and_engine_version(self):
        original = fixture()
        recovered = read_pack(write_pack(original))
        self.assertEqual(recovered.engine_version, original.engine_version)
        self.assertEqual({e.path: e.data for e in recovered.entries}, {e.path: e.data for e in original.entries})

    def test_partition_is_complete_disjoint_and_moves_import_with_texture(self):
        original = fixture()
        groups = split_pack(original)
        all_paths = [entry.path for pack in groups.values() for entry in pack.entries]
        self.assertEqual(len(all_paths), len(set(all_paths)))
        self.assertEqual(set(all_paths), {entry.path for entry in original.entries})
        drawing = {entry.path for entry in groups["drawing"].entries}
        adventure = {entry.path for entry in groups["adventure"].entries}
        self.assertIn(".godot/imported/drawingforest.ctex", drawing)
        self.assertNotIn(".godot/imported/adventureforest.ctex", drawing)
        self.assertIn(".godot/imported/adventureforest.ctex", adventure)
        self.assertIn(".godot/imported/shipatlas.ctex", {entry.path for entry in groups["space"].entries})
        self.assertEqual([entry.data for entry in groups["opening"].entries],
                         [b"unchanged video bytes" * 50])
        for group in groups.values():
            self.assertEqual({entry.path: entry.data for entry in read_pack(write_pack(group)).entries},
                             {entry.path: entry.data for entry in group.entries})

    def test_small_code_updates_keep_all_optional_asset_pack_urls(self):
        original = fixture()
        changed = ResourcePack(original.engine_version, tuple(
            PackEntry(entry.path, b"updated text") if entry.path == "scripts/main.gd.remap" else entry
            for entry in original.entries
        ))
        before, after = split_pack(original), split_pack(changed)
        self.assertNotEqual(write_pack(before["core"]), write_pack(after["core"]))
        for feature in ("drawing", "construction", "adventure", "space", "opening"):
            self.assertEqual(write_pack(before[feature]), write_pack(after[feature]))

    def test_invalid_flags_bounds_checksum_and_duplicate_paths_fail(self):
        valid = write_pack(fixture())
        encrypted = bytearray(valid)
        struct.pack_into("<I", encrypted, 20, 3)
        invalid_directory = bytearray(valid)
        struct.pack_into("<Q", invalid_directory, 32, len(valid) + 1)
        corrupt = bytearray(valid)
        corrupt[struct.unpack_from("<Q", valid, 24)[0]] ^= 1
        for payload in (b"short", encrypted, invalid_directory, corrupt):
            with self.subTest(payload=bytes(payload[:12])):
                with self.assertRaises(ValueError):
                    read_pack(payload)
        with self.assertRaises(ValueError):
            write_pack(ResourcePack((4, 7, 2), (PackEntry("same", b"a"), PackEntry("same", b"b"))))
        for path in (".", "../outside", "folder/../outside", "/absolute", "C:/absolute"):
            with self.subTest(path=path):
                with self.assertRaises(ValueError):
                    write_pack(ResourcePack((4, 7, 2), (PackEntry(path, b"data"),)))

    def test_unmapped_imported_texture_fails_instead_of_silently_shipping_in_core(self):
        with self.assertRaisesRegex(ValueError, "Unmapped imported"):
            split_pack(ResourcePack((4, 7, 2), (PackEntry(".godot/imported/orphan.ctex", b"pixels"),)))

    def test_compressed_representations_are_lossless(self):
        original = write_pack(fixture())
        encoded_br, encoded_gzip = release.compressed_payloads(original)
        self.assertEqual(brotli.decompress(encoded_br), original)
        self.assertEqual(gzip.decompress(encoded_gzip), original)

    def test_prepare_injects_optional_manifest_and_only_bootstraps_core(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            for name in ("index.wasm", "index.js", "index.audio.worklet.js", "index.audio.position.worklet.js"):
                (directory / name).write_bytes((name + " contents").encode())
            original = fixture()
            (directory / "index.pck").write_bytes(write_pack(original))
            (directory / "index.html").write_text(
                '<script>window.QUAD_RESOURCE_PACKS = null;</script>\n'
                '<script src="index.js"></script>\n'
                '<script>const config = {"executable":"index","fileSizes":{}};</script>', encoding="utf-8")
            (directory / "feature-opening-000000000000.pck.gz").write_bytes(b"stale previous export")
            with patch.object(release, "compressed_loader", side_effect=lambda source: source):
                engine, core = release.prepare(directory)
            html = (directory / "index.html").read_text()
            manifest_text = html.split("window.QUAD_RESOURCE_PACKS = ", 1)[1].split(";</script>", 1)[0]
            manifest = json.loads(manifest_text)
            self.assertEqual(set(manifest["packs"]), {"drawing", "construction", "adventure", "space", "opening"})
            self.assertIn(f'"mainPack":"{core}"', html)
            self.assertNotIn("window.QUAD_RESOURCE_PACKS = null;", html)
            self.assertFalse((directory / "index.pck").exists())
            self.assertFalse((directory / "feature-opening-000000000000.pck.gz").exists())
            recovered: dict[str, bytes] = {}
            for descriptor in manifest["packs"].values():
                raw = brotli.decompress((directory / descriptor["br_url"]).read_bytes())
                self.assertEqual(gzip.decompress((directory / descriptor["gzip_url"]).read_bytes()), raw)
                self.assertEqual(hashlib.sha256(raw).hexdigest(), descriptor["sha256"])
                self.assertEqual(len(raw), descriptor["bytes"])
                self.assertFalse((directory / descriptor["url"]).exists())
                recovered.update({entry.path: entry.data for entry in read_pack(raw).entries})
            core_raw = gzip.decompress((directory / (core + ".gz")).read_bytes())
            core_entries = read_pack(core_raw).entries
            self.assertFalse(any(entry.path.endswith(".ogv") for entry in core_entries))
            recovered.update({entry.path: entry.data for entry in core_entries})
            self.assertEqual(recovered, {entry.path: entry.data for entry in original.entries})
            self.assertTrue((directory / (engine + ".wasm.br")).exists())
            report = json.loads((directory / "delivery-report.json").read_text())
            self.assertEqual(report["resources_preserved"], len(original.entries))


if __name__ == "__main__":
    unittest.main()
