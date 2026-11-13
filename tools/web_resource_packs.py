"""Partition an exported Godot 4 PCK without re-encoding any game resource.

The PCK reader/writer follows Godot 4.7's core/io/pck_packer.cpp and
core/io/file_access_pack.cpp. Only ordinary, unencrypted standalone PCK v4
exports are accepted; fail rather than guessing when the export format changes.
"""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
from pathlib import PurePosixPath
import re
import struct


MAGIC = 0x43504447
FORMAT_VERSION = 4
RELATIVE_FILE_BASE = 2
HEADER_BYTES = 104
ALIGNMENT = 32
FEATURES = ("drawing", "construction", "adventure", "space", "opening")
REGION_BACKGROUNDS = frozenset(("forest", "valley", "harbor", "snow", "citadel"))


@dataclass(frozen=True)
class PackEntry:
    path: str
    data: bytes


@dataclass(frozen=True)
class ResourcePack:
    engine_version: tuple[int, int, int]
    entries: tuple[PackEntry, ...]


def _canonical_path(path: str) -> str:
    path = path.removeprefix("res://")
    parts = PurePosixPath(path).parts
    if (not path or not parts or ":" in path or "\\" in path or "\0" in path or path.startswith("/")
            or any(part in (".", "..") for part in parts)
            or str(PurePosixPath(path)) != path):
        raise ValueError(f"Invalid resource path: {path!r}")
    return path


def read_pack(data: bytes) -> ResourcePack:
    if len(data) < HEADER_BYTES:
        raise ValueError("Truncated PCK header")
    magic, version, major, minor, patch, flags, file_base, directory = struct.unpack_from("<6I2Q", data)
    if magic != MAGIC or version != FORMAT_VERSION:
        raise ValueError("Expected an ordinary Godot PCK v4 export")
    if flags != RELATIVE_FILE_BASE:
        raise ValueError("Encrypted, sparse or unsupported PCK flags")
    if not HEADER_BYTES <= file_base <= directory <= len(data) - 4:
        raise ValueError("Invalid PCK payload/directory bounds")
    count = struct.unpack_from("<I", data, directory)[0]
    # Every directory entry needs at least 44 bytes, even with a short path.
    if count > (len(data) - directory - 4) // 44:
        raise ValueError("Invalid PCK entry count")
    cursor = directory + 4
    seen: set[str] = set()
    entries: list[PackEntry] = []
    for _ in range(count):
        if cursor + 4 > len(data):
            raise ValueError("Truncated PCK directory")
        path_size = struct.unpack_from("<I", data, cursor)[0]
        cursor += 4
        if not path_size or path_size % 4 or cursor + path_size + 36 > len(data):
            raise ValueError("Invalid PCK path size")
        raw_path = data[cursor:cursor + path_size]
        path = _canonical_path(raw_path.rstrip(b"\0").decode("utf-8"))
        cursor += path_size
        offset, size = struct.unpack_from("<QQ", data, cursor)
        digest = data[cursor + 16:cursor + 32]
        entry_flags = struct.unpack_from("<I", data, cursor + 32)[0]
        cursor += 36
        start, end = file_base + offset, file_base + offset + size
        if entry_flags or start < file_base or end > directory:
            raise ValueError(f"Unsupported flags or invalid resource bounds: {path}")
        payload = data[start:end]
        if hashlib.md5(payload).digest() != digest:
            raise ValueError(f"Resource checksum mismatch: {path}")
        if path in seen:
            raise ValueError(f"Duplicate resource path: {path}")
        seen.add(path)
        entries.append(PackEntry(path, payload))
    if cursor != len(data):
        raise ValueError("Unexpected data after the PCK directory")
    return ResourcePack((major, minor, patch), tuple(entries))


def _align(buffer: bytearray, alignment: int = ALIGNMENT) -> None:
    buffer.extend(b"\0" * (-len(buffer) % alignment))


def write_pack(pack: ResourcePack) -> bytes:
    # Fixed ordering keeps feature URLs stable when only scripts change.
    entries = sorted((PackEntry(_canonical_path(entry.path), entry.data) for entry in pack.entries),
                     key=lambda entry: entry.path)
    if len({entry.path for entry in entries}) != len(entries):
        raise ValueError("Duplicate resource paths")
    result = bytearray(HEADER_BYTES)
    _align(result)
    file_base = len(result)
    offsets: list[int] = []
    for entry in entries:
        _canonical_path(entry.path)
        offsets.append(len(result) - file_base)
        result.extend(entry.data)
        _align(result)
    directory = len(result)
    result.extend(struct.pack("<I", len(entries)))
    for entry, offset in zip(entries, offsets):
        path = entry.path.encode("utf-8")
        padded = path + b"\0" * (-len(path) % 4)
        result.extend(struct.pack("<I", len(padded)))
        result.extend(padded)
        result.extend(struct.pack("<QQ", offset, len(entry.data)))
        result.extend(hashlib.md5(entry.data).digest())
        result.extend(struct.pack("<I", 0))
    struct.pack_into("<6I2Q", result, 0, MAGIC, FORMAT_VERSION, *pack.engine_version,
                     RELATIVE_FILE_BASE, file_base, directory)
    return bytes(result)


def feature_for_source(path: str) -> str:
    """Map original resource paths, never ambiguous imported-cache basenames."""
    path = _canonical_path(path).removesuffix(".import")
    if path.startswith("assets/generated/drawing/"):
        return "drawing"
    if (path.startswith("assets/generated/starfront-hd/materials/")
            or re.fullmatch(r"assets/generated/construction-game/badge-[1-5]\.webp", path)
            or path == "assets/generated/starfront-v1/brick.webp"):
        return "construction"
    if path.startswith("assets/generated/starfront-hd/props/"):
        return "adventure"
    if path.startswith("assets/generated/starfront-hd/backgrounds/"):
        if PurePosixPath(path).stem in REGION_BACKGROUNDS:
            return "adventure"
    if path == "assets/generated/opening-v1/planet.webp" or path.startswith("assets/generated/ship-parts-v2/"):
        return "space"
    if path in ("assets/video/quadrilateral-opening.ogv", "assets/video/quadrilateral-opening.ogv.uid"):
        return "opening"
    # Shared UI, portraits, paper, home-card backgrounds, fonts and code remain
    # in the bootstrap pack. The desktop export is never passed through here.
    return "core"


def split_pack(pack: ResourcePack) -> dict[str, ResourcePack]:
    entries = {entry.path: entry for entry in pack.entries}
    assignment = {path: feature_for_source(path) for path in entries}
    imported_owners: dict[str, set[str]] = {}
    for path, entry in entries.items():
        if not path.endswith(".import"):
            continue
        text = entry.data.rstrip(b"\0").decode("utf-8")
        for target in re.findall(r'"res://([^"\n]+)"', text):
            if target in entries and target.startswith(".godot/imported/"):
                imported_owners.setdefault(target, set()).add(assignment[path])
    for target, owners in imported_owners.items():
        # A resource shared across features belongs to core and is sent once.
        assignment[target] = next(iter(owners)) if len(owners) == 1 else "core"
    orphan_imports = [path for path in entries if path.startswith(".godot/imported/") and path not in imported_owners]
    if orphan_imports:
        raise ValueError(f"Unmapped imported resources: {orphan_imports}")
    groups: dict[str, ResourcePack] = {}
    for group in ("core", *FEATURES):
        groups[group] = ResourcePack(pack.engine_version, tuple(
            entry for entry in pack.entries if assignment[entry.path] == group
        ))
    # Validate exact partition before any delivery files are written.
    combined = {entry.path: entry.data for group in groups.values() for entry in group.entries}
    if combined != {entry.path: entry.data for entry in pack.entries}:
        raise ValueError("Resource partition lost or duplicated game data")
    return groups
