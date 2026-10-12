import gzip
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.prepare_web_release import ROOT, compressed_loader, optimize_png, prepare


def exported_loader() -> str:
    # The repository ships its Godot-generated engine. Exercise that real
    # version rather than a stub that cannot expose preloader integration bugs.
    engine_path = next(path for path in (ROOT / "build/web").glob("engine-*.js")
                       if re.fullmatch(r"engine-[0-9a-f]{12}\.js", path.name))
    source = engine_path.read_text(encoding="utf-8")
    if "const triangleArtUngzip" in source:
        source = "var Godot=" + source.split("var Godot=", 1)[1]
        source = source.replace(
            "return triangleArtFetchCompressed(file, fileSize).then(function (response) {",
            "return fetch(file).then(function (response) {",
            1,
        )
    return source


def write_export(directory: Path, worklet: str = "worklet") -> None:
    for name in (
        "index.wasm",
        "index.pck",
        "index.audio.worklet.js",
        "index.audio.position.worklet.js",
    ):
        (directory / name).write_bytes((name + worklet).encode("ascii") * 64)
    (directory / "index.js").write_text(exported_loader(), encoding="utf-8")
    (directory / "index.html").write_text(
        '<script src="index.js"></script>\n'
        'const config = {"executable":"index","fileSizes":{"index.pck":9,"index.wasm":10}};',
        encoding="utf-8",
    )


class PrepareWebReleaseTests(unittest.TestCase):
    def test_png_lossless_recompression_preserves_pixels_and_metadata(self) -> None:
        def chunk(kind: bytes, data: bytes) -> bytes:
            return len(data).to_bytes(4, "big") + kind + data + zlib.crc32(kind + data).to_bytes(4, "big")

        with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
            image = Path(temporary) / "image.png"
            scanlines = b"\x00" + b"\xff" * 256
            compressed = zlib.compress(scanlines, level=0)
            header = (256).to_bytes(4, "big") + (1).to_bytes(4, "big") + b"\x08\x00\x00\x00\x00"
            metadata = chunk(b"tEXt", b"Title\x00Triangle Art")
            image.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + metadata
                              + chunk(b"IDAT", compressed[:12]) + chunk(b"IDAT", compressed[12:]) + chunk(b"IEND", b""))
            self.assertGreater(optimize_png(image), 0)
            self.assertIn(metadata, image.read_bytes())
            data = image.read_bytes()
            position = data.index(b"IDAT")
            length = int.from_bytes(data[position - 4 : position], "big")
            self.assertEqual(zlib.decompress(data[position + 4 : position + 4 + length]), scanlines)
            self.assertEqual(optimize_png(image), 0)

    def test_content_hashes_and_references(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
            directory = Path(temporary)
            write_export(directory)
            (directory / "index.png").write_bytes(b"unused splash")
            (directory / "index.png.import").write_bytes(b"editor cache")
            raw_wasm = (directory / "index.wasm").read_bytes()
            raw_pack = (directory / "index.pck").read_bytes()
            engine, pack = prepare(directory)
            html = (directory / "index.html").read_text(encoding="utf-8")
            config = json.JSONDecoder().raw_decode(html.split("const config = ", 1)[1])[0]
            self.assertEqual(config["executable"], engine)
            self.assertEqual(config["mainPack"], pack)
            self.assertIn(f'<script src="{engine}.js"></script>', html)
            self.assertEqual(config["fileSizes"][f"{engine}.wasm"], len(raw_wasm))
            self.assertEqual(config["fileSizes"][pack], len(raw_pack))
            self.assertTrue((directory / f"{engine}.audio.worklet.js").is_file())
            self.assertTrue((directory / f"{engine}.audio.position.worklet.js").is_file())
            self.assertEqual(gzip.decompress((directory / f"{engine}.wasm.gz").read_bytes()), raw_wasm)
            self.assertEqual(gzip.decompress((directory / f"{pack}.gz").read_bytes()), raw_pack)
            self.assertEqual(pack, f"art-{hashlib.sha256(raw_pack).hexdigest()[:12]}.pck")
            self.assertFalse((directory / "index.wasm").exists())
            self.assertFalse((directory / f"{engine}.wasm").exists())
            self.assertFalse((directory / pack).exists())
            self.assertTrue((directory / "PAKO-LICENSE.txt").is_file())
            self.assertTrue((directory / "ZLIB-LICENSE.txt").is_file())
            self.assertFalse((directory / "index.png").exists())
            self.assertFalse((directory / "index.png.import").exists())

    def test_repeat_export_is_deterministic_and_cleans_stale_assets(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
            directory = Path(temporary)
            write_export(directory)
            first_engine, first_pack = prepare(directory)
            first_gzip = (directory / f"{first_engine}.wasm.gz").read_bytes()
            write_export(directory)
            self.assertEqual(prepare(directory), (first_engine, first_pack))
            self.assertEqual((directory / f"{first_engine}.wasm.gz").read_bytes(), first_gzip)
            (directory / "engine-0123456789ab.wasm").write_bytes(b"legacy raw")
            (directory / "art-0123456789ab.pck.gz").write_bytes(b"legacy compressed")
            write_export(directory, worklet="updated worklet")
            next_engine, next_pack = prepare(directory)
            self.assertNotEqual(next_engine, first_engine)
            self.assertNotEqual(next_pack, first_pack)
            self.assertFalse((directory / f"{first_engine}.wasm.gz").exists())
            self.assertFalse((directory / "engine-0123456789ab.wasm").exists())
            self.assertFalse((directory / "art-0123456789ab.pck.gz").exists())

    def test_updated_engine_loader_invalidates_cached_engine(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
            directory = Path(temporary)
            write_export(directory)
            first_engine, first_pack = prepare(directory)
            write_export(directory)
            with (directory / "index.js").open("a", encoding="utf-8") as loader:
                loader.write("\n// changed engine loader")
            next_engine, next_pack = prepare(directory)
            self.assertNotEqual(first_engine, next_engine)
            self.assertEqual(first_pack, next_pack)

    def test_unknown_loader_fails_before_modifying_export(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
            directory = Path(temporary)
            write_export(directory)
            old_asset = directory / "engine-0123456789ab.wasm"
            old_asset.write_bytes(b"previous export")
            (directory / "index.js").write_text("unexpected loader", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "preloader fetch"):
                prepare(directory)
            self.assertEqual(old_asset.read_bytes(), b"previous export")
            self.assertTrue((directory / "index.wasm").exists())

    @unittest.skipUnless(shutil.which("node"), "Node.js is required to verify browser decoders")
    def test_native_and_fallback_browser_decoders(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
            directory = Path(temporary)
            loader = directory / "loader.js"
            loader.write_text(compressed_loader(exported_loader()), encoding="utf-8")
            result = subprocess.run(
                ["node", str(ROOT / "tests/test_compressed_assets.cjs"), str(loader)],
                capture_output=True, text=True, timeout=60,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
