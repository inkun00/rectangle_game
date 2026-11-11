"""Compress Godot binaries and fingerprint every engine asset for safe caching."""

import gzip
import hashlib
import json
import re
import shutil
import zlib
from pathlib import Path

import brotli

from web_resource_packs import read_pack, split_pack, write_pack


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build/web"
WEB = ROOT / "web"
FETCH_CALL = "return fetch(file).then(function (response) {"
ASSET_PATTERN = re.compile(
    r"(?:engine-[0-9a-f]{12}\.(?:wasm(?:\.gz|\.br)?|js|audio\.worklet\.js|audio\.position\.worklet\.js)"
    r"|art-[0-9a-f]{12}\.pck(?:\.gz|\.br)?"
    r"|feature-[a-z]+-[0-9a-f]{12}\.pck(?:\.gz|\.br)?)"
)
PACK_MANIFEST_PLACEHOLDER = "window.QUAD_RESOURCE_PACKS = null;"


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
    audio_resume = 'function _godot_audio_resume(){if(GodotAudio.ctx&&GodotAudio.ctx.state!=="running"){GodotAudio.ctx.resume()}}'
    audio_bridge = audio_resume + "globalThis.quadUnlockAudio=_godot_audio_resume;"
    if audio_bridge not in source:
        if source.count(audio_resume) != 1:
            raise ValueError("Unsupported Godot audio resume bridge; review the export template")
        source = source.replace(audio_resume, audio_bridge, 1)
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


def compressed_payloads(payload: bytes) -> tuple[bytes, bytes]:
    """Both delivery representations decode to the exact exported bytes."""
    encoded_br = brotli.compress(payload, quality=6)
    encoded_gzip = gzip.compress(payload, compresslevel=9, mtime=0)
    if brotli.decompress(encoded_br) != payload or gzip.decompress(encoded_gzip) != payload:
        raise ValueError("Lossless delivery compression round-trip failed")
    return encoded_br, encoded_gzip


def delivery_descriptor(name: str, payload: bytes, encoded: tuple[bytes, bytes]) -> dict:
    encoded_br, encoded_gzip = encoded
    return {
        "url": name,
        "sha256": hashlib.sha256(payload).hexdigest(),
        "bytes": len(payload),
        "br_url": name + ".br",
        "gzip_url": name + ".gz",
        "br_bytes": len(encoded_br),
        "gzip_bytes": len(encoded_gzip),
    }


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

    exported_pack = read_pack(pack_path.read_bytes())
    resource_groups = split_pack(exported_pack)
    core_payload = write_pack(resource_groups["core"])
    pack_name = f"art-{hashlib.sha256(core_payload).hexdigest()[:12]}.pck"
    compressed_packs: dict[str, tuple[bytes, bytes]] = {pack_name: compressed_payloads(core_payload)}
    manifest: dict = {"version": 1, "packs": {}}
    for feature, group in resource_groups.items():
        if feature == "core":
            continue
        payload = write_pack(group)
        name = f"feature-{feature}-{hashlib.sha256(payload).hexdigest()[:12]}.pck"
        encoded = compressed_payloads(payload)
        compressed_packs[name] = encoded
        manifest["packs"][feature] = delivery_descriptor(name, payload, encoded)
    engine_payloads = {name: (directory / name).read_bytes() for name in engine_files}
    engine_payloads["index.js"] = compressed_loader(
        engine_payloads["index.js"].decode("utf-8")
    ).encode("utf-8")
    engine_name = f"engine-{engine_fingerprint(list(engine_payloads.values()))}"
    html = html_path.read_text(encoding="utf-8")
    if html.count(PACK_MANIFEST_PLACEHOLDER) != 1:
        raise ValueError("Expected one optional resource pack manifest placeholder")
    html = html.replace(
        PACK_MANIFEST_PLACEHOLDER,
        "window.QUAD_RESOURCE_PACKS = " + json.dumps(manifest, ensure_ascii=False, separators=(",", ":")) + ";",
        1,
    )
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
        pack_name: len(core_payload),
    }
    html = (
        html[:config_start]
        + json.dumps(config, ensure_ascii=False, separators=(",", ":"))
        + html[config_start + config_length :]
    )
    html = html.replace(script_tag, f'<script src="{engine_name}.js"></script>', 1)

    compressed_wasm = compressed_payloads(engine_payloads["index.wasm"])

    # Generated assets from the previous export must not remain in the deployment.
    for old in directory.iterdir():
        if old.is_file() and ASSET_PATTERN.fullmatch(old.name):
            old.unlink()

    for name, payload in engine_payloads.items():
        target_name = name.replace("index", engine_name, 1)
        if name == "index.wasm":
            (directory / (target_name + ".br")).write_bytes(compressed_wasm[0])
            (directory / (target_name + ".gz")).write_bytes(compressed_wasm[1])
        else:
            (directory / target_name).write_bytes(payload)
        (directory / name).unlink()
    for name, (encoded_br, encoded_gzip) in compressed_packs.items():
        (directory / (name + ".br")).write_bytes(encoded_br)
        (directory / (name + ".gz")).write_bytes(encoded_gzip)
    pack_path.unlink()
    # License text accompanies the fallback decoder in the deployed engine JS.
    shutil.copyfile(WEB / "vendor/PAKO-LICENSE.txt", directory / "PAKO-LICENSE.txt")
    shutil.copyfile(WEB / "vendor/ZLIB-LICENSE.txt", directory / "ZLIB-LICENSE.txt")
    for license_path in (ROOT / "licenses").glob("*.txt"):
        shutil.copyfile(license_path, directory / license_path.name)
    html_path.write_text(html, encoding="utf-8")
    for pattern in ("*.png.import", "*.webp.import"):
        for imported in directory.glob(pattern):
            imported.unlink()
    # Replaced by a same-resolution WebP in export_button_web.gd.
    old_loading = directory / "frontier-loading.png"
    if old_loading.is_file() and "frontier-loading.png" not in html:
        old_loading.unlink()
    splash = directory / "index.png"
    if splash.is_file() and "index.png" not in html and "index.png" not in engine_payloads["index.js"].decode("utf-8"):
        splash.unlink()
    for image in directory.glob("*.png"):
        optimize_png(image)
    report = {
        "version": 1,
        "units": "bytes",
        "resources_preserved": len(exported_pack.entries),
        "exported_payload_bytes": sum(len(entry.data) for entry in exported_pack.entries),
        "engine": delivery_descriptor(engine_name + ".wasm", engine_payloads["index.wasm"], compressed_wasm),
        "core": {**delivery_descriptor(pack_name, core_payload, compressed_packs[pack_name]),
                 "entries": len(resource_groups["core"].entries)},
        "features": {feature: {**descriptor, "entries": len(resource_groups[feature].entries)}
                     for feature, descriptor in manifest["packs"].items()},
        "initial_binary_brotli_bytes": len(compressed_wasm[0]) + len(compressed_packs[pack_name][0]),
        "initial_binary_gzip_bytes": len(compressed_wasm[1]) + len(compressed_packs[pack_name][1]),
    }
    (directory / "delivery-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return engine_name, pack_name


def main() -> None:
    engine_name, pack_name = prepare(OUTPUT)
    print(f"Split web assets ready (Brotli + gzip): {engine_name}.wasm, {pack_name}; see delivery-report.json")


if __name__ == "__main__":
    main()
