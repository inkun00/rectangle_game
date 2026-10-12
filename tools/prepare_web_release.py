"""Compress Godot binaries and fingerprint every engine asset for safe caching."""

import gzip
import hashlib
import json
import re
import shutil
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build/web"
WEB = ROOT / "web"
FETCH_CALL = "return fetch(file).then(function (response) {"
ASSET_PATTERN = re.compile(
    r"(?:engine-[0-9a-f]{12}\.(?:wasm(?:\.gz)?|js|audio\.worklet\.js|audio\.position\.worklet\.js)"
    r"|art-[0-9a-f]{12}\.pck(?:\.gz)?)"
)


def fingerprint(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12]


def engine_fingerprint(payloads: list[bytes]) -> str:
    # Worklets and the decoder must invalidate the engine cache as well as WASM.
    digest = hashlib.sha256()
    for payload in payloads:
        digest.update(len(payload).to_bytes(8, "little"))
        digest.update(payload)
    return digest.hexdigest()[:12]


def harden_loader(source: str) -> str:
    # Godot 4.7's preloader drops stream and instantiation rejections. Connect
    # them to startGame().catch(), including CRC errors from the gzip decoder.
    replacements = [
        (
            "onloadprogress(reader, controller).then(function () {\n"
            "\t\t\t\t\tcontroller.close();\n\t\t\t\t});",
            "onloadprogress(reader, controller).then(function () {\n"
            "\t\t\t\t\tcontroller.close();\n\t\t\t\t}).catch(function (error) {\n"
            "\t\t\t\t\tcontroller.error(error);\n\t\t\t\t});",
        ),
        (
            'Module["instantiateWasm"](info,(inst,mod)=>{resolve(receiveInstance(inst,mod))})',
            'Module["instantiateWasm"](info,(inst,mod)=>{resolve(receiveInstance(inst,mod))},reject)',
        ),
        (
            "'instantiateWasm': function (imports, onSuccess) {",
            "'instantiateWasm': function (imports, onSuccess, onError) {",
        ),
        (
            "WebAssembly.instantiateStreaming(Promise.resolve(r), imports).then(done);",
            "WebAssembly.instantiateStreaming(Promise.resolve(r), imports).then(done).catch(onError);",
        ),
        (
            "r.arrayBuffer().then(function (buffer) {\n"
            "\t\t\t\t\t\tWebAssembly.instantiate(buffer, imports).then(done);\n\t\t\t\t\t});",
            "r.arrayBuffer().then(function (buffer) {\n"
            "\t\t\t\t\t\treturn WebAssembly.instantiate(buffer, imports).then(done);\n"
            "\t\t\t\t\t}).catch(onError);",
        ),
        (
            "Godot(me.config.getModuleConfig(loadPath, cloned)).then(function (module) {",
            "return Godot(me.config.getModuleConfig(loadPath, cloned)).then(function (module) {",
        ),
        (
            "module['initFS'](paths).then(function (err) {",
            "return module['initFS'](paths).then(function (err) {",
        ),
        (
            "\t\t\t\t\t\t\t\t\tresolve();\n"
            "\t\t\t\t\t\t\t\t});\n\t\t\t\t\t\t\t});\n"
            "\t\t\t\t\t\t});\n\t\t\t\t\t});",
            "\t\t\t\t\t\t\t\t\tif (err) reject(err); else resolve();\n"
            "\t\t\t\t\t\t\t\t});\n\t\t\t\t\t\t\t});\n"
            "\t\t\t\t\t\t}).catch(reject);\n\t\t\t\t\t});",
        ),
    ]
    for index, (before, after) in enumerate(replacements, start=1):
        if after in source:
            continue
        if source.count(before) != 1:
            raise ValueError(f"Unsupported Godot loader error handling (patch {index}); review the export template")
        source = source.replace(before, after, 1)
    return source


def compressed_loader(source: str) -> str:
    source = source.replace("\r\n", "\n")
    if source.count(FETCH_CALL) != 1:
        raise ValueError("Expected one Godot preloader fetch call")
    pako = (WEB / "vendor/pako_inflate.min.js").read_text(encoding="utf-8")
    decoder = (WEB / "compressed_assets.js").read_text(encoding="utf-8")
    # Keep the library private, even on pages that already load an AMD library.
    preamble = (
        "const triangleArtUngzip = (() => {const exports = {};const module = {exports};\n"
        + pako
        + "\nreturn exports.ungzip;})();\n"
        + decoder
        + "\n"
    )
    return preamble + harden_loader(source).replace(
        FETCH_CALL,
        "return triangleArtFetchCompressed(file, fileSize).then(function (response) {",
        1,
    )


def optimize_png(path: Path) -> int:
    """Recompress only PNG's lossless image stream, preserving ancillary data."""
    original = path.read_bytes()
    signature = b"\x89PNG\r\n\x1a\n"
    if not original.startswith(signature):
        raise ValueError(f"Invalid PNG signature: {path.name}")
    chunks: list[tuple[bytes, bytes, bytes]] = []
    offset = len(signature)
    while offset < len(original):
        size = int.from_bytes(original[offset : offset + 4], "big")
        end = offset + size + 12
        if end > len(original):
            raise ValueError(f"Truncated PNG chunk: {path.name}")
        kind = original[offset + 4 : offset + 8]
        data = original[offset + 8 : end - 4]
        crc = int.from_bytes(original[end - 4 : end], "big")
        if zlib.crc32(kind + data) != crc:
            raise ValueError(f"Invalid PNG checksum: {path.name}")
        chunks.append((kind, data, original[offset:end]))
        offset = end
    if not chunks or chunks[-1][0] != b"IEND":
        raise ValueError(f"Missing PNG end marker: {path.name}")
    image = b"".join(data for kind, data, _ in chunks if kind == b"IDAT")
    compressed = zlib.compress(zlib.decompress(image), level=9)
    candidate = bytearray(signature)
    image_written = False
    for kind, _, chunk in chunks:
        if kind != b"IDAT":
            candidate.extend(chunk)
        elif not image_written:
            candidate.extend(len(compressed).to_bytes(4, "big"))
            candidate.extend(b"IDAT" + compressed)
            candidate.extend(zlib.crc32(b"IDAT" + compressed).to_bytes(4, "big"))
            image_written = True
    saved = len(original) - len(candidate)
    if saved > 0:
        path.write_bytes(candidate)
        return saved
    return 0


def prepare(directory: Path) -> tuple[str, str]:
    directory = directory.resolve()
    html_path = directory / "index.html"
    wasm_path = directory / "index.wasm"
    pack_path = directory / "index.pck"
    engine_files = [
        "index.wasm",
        "index.js",
        "index.audio.worklet.js",
        "index.audio.position.worklet.js",
    ]
    for name in engine_files + ["index.pck", "index.html"]:
        if not (directory / name).is_file():
            raise FileNotFoundError(f"Missing fresh Godot export file: {name}")

    engine_payloads = {name: (directory / name).read_bytes() for name in engine_files}
    engine_payloads["index.js"] = compressed_loader(
        engine_payloads["index.js"].decode("utf-8")
    ).encode("utf-8")
    engine_name = f"engine-{engine_fingerprint(list(engine_payloads.values()))}"
    pack_name = f"art-{fingerprint(pack_path)}.pck"
    html = html_path.read_text(encoding="utf-8")
    script_tag = '<script src="index.js"></script>'
    if html.count(script_tag) != 1:
        raise ValueError("Expected one Godot engine script tag")
    match = re.search(r"\bconst config = ", html)
    if not match:
        raise ValueError("Godot export config was not found")
    config_start = match.end()
    config, config_length = json.JSONDecoder().raw_decode(html[config_start:])
    if config.get("executable") != "index":
        raise ValueError("Expected an unprepared Godot export")
    config["executable"] = engine_name
    config["mainPack"] = pack_name
    config["fileSizes"] = {
        f"{engine_name}.wasm": wasm_path.stat().st_size,
        pack_name: pack_path.stat().st_size,
    }
    html = (
        html[:config_start]
        + json.dumps(config, ensure_ascii=False, separators=(",", ":"))
        + html[config_start + config_length :]
    )
    html = html.replace(script_tag, f'<script src="{engine_name}.js"></script>', 1)

    compressed_wasm = gzip.compress(engine_payloads["index.wasm"], compresslevel=9, mtime=0)
    compressed_pack = gzip.compress(pack_path.read_bytes(), compresslevel=9, mtime=0)

    # Generated assets from the previous export must not remain in the deployment.
    for old in directory.iterdir():
        if old.is_file() and ASSET_PATTERN.fullmatch(old.name):
            old.unlink()

    for name, payload in engine_payloads.items():
        target_name = name.replace("index", engine_name, 1)
        if name == "index.wasm":
            target_name += ".gz"
            payload = compressed_wasm
        (directory / target_name).write_bytes(payload)
        (directory / name).unlink()
    (directory / f"{pack_name}.gz").write_bytes(compressed_pack)
    pack_path.unlink()
    # License text accompanies the fallback decoder in the deployed engine JS.
    shutil.copyfile(WEB / "vendor/PAKO-LICENSE.txt", directory / "PAKO-LICENSE.txt")
    shutil.copyfile(WEB / "vendor/ZLIB-LICENSE.txt", directory / "ZLIB-LICENSE.txt")
    html_path.write_text(html, encoding="utf-8")
    for imported in directory.glob("*.png.import"):
        imported.unlink()
    splash = directory / "index.png"
    if splash.is_file() and "index.png" not in html and "index.png" not in engine_payloads["index.js"].decode("utf-8"):
        splash.unlink()
    for image in directory.glob("*.png"):
        optimize_png(image)
    return engine_name, pack_name


def main() -> None:
    engine_name, pack_name = prepare(OUTPUT)
    print(f"Compressed web assets ready: {engine_name}.wasm.gz, {pack_name}.gz")


if __name__ == "__main__":
    main()
