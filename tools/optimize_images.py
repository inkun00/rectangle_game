"""Losslessly re-encode active PNG assets; verify and back up before replacement.

Install tools/requirements-images.txt, then run with --apply --backup-root PATH.
No resizing, quantization or lossy compression is performed. Export-excluded
artwork is deliberately left to the separate archive/quarantine workflow.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import fnmatch
import hashlib
from io import BytesIO
import json
from pathlib import Path
import re
import shutil

from PIL import Image, __version__ as PILLOW_VERSION, features


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets/image_optimization_manifest.json"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def rgba(data: bytes) -> tuple[tuple[int, int], bytes]:
    with Image.open(BytesIO(data)) as image:
        return image.size, image.convert("RGBA").tobytes()


def candidates() -> list[Path]:
    presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    exclusions = [
        value.split(",")
        for value in re.findall(r'^exclude_filter="([^"]*)"', presets, re.M)
    ]
    if not exclusions:
        raise ValueError("No export exclusions found; refusing an unbounded conversion")
    return [
        path for path in sorted((ROOT / "assets").rglob("*.png"))
        if not all(any(fnmatch.fnmatchcase(path.relative_to(ROOT).as_posix(), pattern)
                       for pattern in patterns) for patterns in exclusions)
    ]


def encode(path: Path) -> tuple[dict, bytes, bytes]:
    original = path.read_bytes()
    dimensions, pixels = rgba(original)
    with Image.open(BytesIO(original)) as image:
        encoded = BytesIO()
        metadata = {key: image.info[key] for key in ("icc_profile", "exif", "xmp")
                    if image.info.get(key)}
        # exact=True preserves even RGB values beneath fully transparent pixels.
        image.save(encoded, format="WEBP", lossless=True, exact=True, method=6,
                   **metadata)
    optimized = encoded.getvalue()
    decoded_dimensions, decoded_pixels = rgba(optimized)
    if dimensions != decoded_dimensions or pixels != decoded_pixels:
        raise ValueError(f"Pixel or dimension mismatch: {path}")
    smaller = len(optimized) < len(original)
    result = optimized if smaller else original
    relative = path.relative_to(ROOT).as_posix()
    target = path.with_suffix(".webp") if smaller else path
    row = {
        "original_path": relative,
        "path": target.relative_to(ROOT).as_posix(),
        "format": "lossless_webp" if smaller else "unchanged_png",
        "width": dimensions[0], "height": dimensions[1],
        "rgba_sha256": sha256(pixels),
        "original_bytes": len(original), "bytes": len(result),
        "saved_bytes": len(original) - len(result),
        "original_sha256": sha256(original), "sha256": sha256(result),
    }
    return row, original, result


def backed_up(path: Path, backup_root: Path) -> Path:
    destination = backup_root / path.relative_to(ROOT)
    destination.parent.mkdir(parents=True, exist_ok=True)
    expected = sha256(path.read_bytes())
    if destination.exists():
        if sha256(destination.read_bytes()) != expected:
            raise ValueError(f"Conflicting existing backup: {destination}")
    else:
        shutil.copy2(path, destination)
    if sha256(destination.read_bytes()) != expected:
        raise ValueError(f"Backup verification failed: {destination}")
    return destination


def write_atomic(path: Path, payload: bytes) -> None:
    temporary = path.with_name(path.name + ".optimization.tmp")
    temporary.write_bytes(payload)
    temporary.replace(path)


def import_metadata(source: Path, target: Path) -> bytes:
    original = source.read_text(encoding="utf-8")
    old_image = source.relative_to(ROOT).as_posix().removesuffix(".import")
    new_image = target.relative_to(ROOT).as_posix().removesuffix(".import")
    old_resource, new_resource = "res://" + old_image, "res://" + new_image
    old_cache = (Path(old_image).name + "-" +
                 hashlib.md5(old_resource.encode("utf-8")).hexdigest())
    new_cache = (Path(new_image).name + "-" +
                 hashlib.md5(new_resource.encode("utf-8")).hexdigest())
    if old_resource not in original or old_cache not in original:
        raise ValueError(f"Unexpected Godot texture importer metadata: {source}")
    return original.replace(old_resource, new_resource).replace(old_cache, new_cache).encode("utf-8")


def save_manifest(rows: list[dict]) -> None:
    document = {
        "schema_version": 1,
        "method": "WebP lossless, exact RGBA round-trip, original dimensions and alpha",
        "pillow_version": PILLOW_VERSION,
        "libwebp_version": features.version("webp"),
        "original_bytes": sum(row["original_bytes"] for row in rows),
        "bytes": sum(row["bytes"] for row in rows),
        "saved_bytes": sum(row["saved_bytes"] for row in rows),
        "files": sorted(rows, key=lambda row: row["original_path"]),
    }
    write_atomic(MANIFEST, (json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))


def verify(backup_root: Path) -> None:
    document = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for row in document["files"]:
        path = ROOT / row["path"]
        payload = path.read_bytes()
        dimensions, pixels = rgba(payload)
        if (sha256(payload) != row["sha256"] or
                dimensions != (row["width"], row["height"]) or
                sha256(pixels) != row["rgba_sha256"]):
            raise ValueError(f"Optimized asset verification failed: {path}")
        if row["format"] == "unchanged_png":
            continue
        backup = backup_root / row["original_path"]
        original = backup.read_bytes()
        if sha256(original) != row["original_sha256"] or rgba(original) != (dimensions, pixels):
            raise ValueError(f"Original backup verification failed: {backup}")
        original_import = backup_root / (row["original_path"] + ".import")
        if sha256(original_import.read_bytes()) != row["original_import_sha256"]:
            raise ValueError(f"Original import backup verification failed: {original_import}")
        current_import = Path(str(path) + ".import").read_text(encoding="utf-8")
        if f'uid="{row["import_uid"]}"' not in current_import:
            raise ValueError(f"Godot import UID changed: {path}")
    print(f'Verified {len(document["files"])} assets and their original backups; '
          f'{document["saved_bytes"]:,} bytes saved; all RGBA pixels identical.')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--apply", action="store_true")
    action.add_argument("--verify", action="store_true")
    parser.add_argument("--backup-root", type=Path, required=True)
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    backup_root = args.backup_root.resolve()
    if backup_root == ROOT or ROOT in backup_root.parents:
        raise ValueError("Backups must be outside the repository")
    if args.verify:
        verify(backup_root)
        return
    rows = json.loads(MANIFEST.read_text(encoding="utf-8"))["files"] if MANIFEST.exists() else []
    known = {row["original_path"] for row in rows}
    paths = [path for path in candidates() if path.relative_to(ROOT).as_posix() not in known]
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        for row, original, optimized in executor.map(encode, paths):
            source = ROOT / row["original_path"]
            target = ROOT / row["path"]
            if args.apply and row["saved_bytes"]:
                if target.exists():
                    raise ValueError(f"Target already exists: {target}")
                source_import = Path(str(source) + ".import")
                target_import = Path(str(target) + ".import")
                if target_import.exists():
                    raise ValueError(f"Target import metadata already exists: {target_import}")
                backed_up(source, backup_root)
                backed_up(source_import, backup_root)
                row["original_import_sha256"] = sha256(source_import.read_bytes())
                row["import_uid"] = re.search(r'^uid="([^"]+)"', source_import.read_text(), re.M).group(1)
                new_import = import_metadata(source_import, target_import)
                write_atomic(target, optimized)
                write_atomic(target_import, new_import)
                if sha256(target.read_bytes()) != row["sha256"]:
                    raise ValueError(f"Written file verification failed: {target}")
                source.unlink()
                source_import.unlink()
            rows.append(row)
            if args.apply:
                save_manifest(rows)
            print(f'{row["original_path"]}: {row["original_bytes"]:,} -> {row["bytes"]:,} '
                  f'({row["format"]})', flush=True)
    if args.apply:
        verify(backup_root)
    else:
        print(f'Dry run: {sum(row["saved_bytes"] for row in rows):,} bytes could be saved.')


if __name__ == "__main__":
    main()
