"""Inventory image sources and record native atlas-cell resolution; never edit pixels."""

import fnmatch
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
HD = ROOT / "assets/generated/starfront-hd"
BITMAPS = {".png", ".jpg", ".jpeg", ".webp"}


def usage(path: str) -> str:
    if "starfront-hd/backgrounds/" in path:
        return "regenerated full-frame background"
    if "starfront-hd/props/" in path:
        return "regenerated environment sprites; measured silhouette regions"
    if "starfront-hd/materials/" in path:
        return "regenerated building material; 2x3 detail sheet or single wide texture"
    if "starfront-v1/" in path:
        return "retained icons, characters or nine-slice skin; replaced large atlases excluded"
    if "drawing/backgrounds/" in path:
        return "retained 1586x992 artwork background; fits the drawing board at 1920x1080"
    if "drawing/masterpieces/" in path:
        return "retained scalable vector artwork/guide"
    if "focused-ui/" in path:
        return "retained quiet drafting paper; no detailed scene stretched across the screen"
    if re.search(r"construction-game/badge-[1-5]\.png$", path):
        return "retained badge; displayed at 112 or 148 pixels"
    return "legacy image; not displayed by the current theme"


def inspect() -> dict:
    preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    excluded = re.search(r'^exclude_filter="([^"]*)"', preset, re.M).group(1).split(",")
    files = []
    for path in sorted((ROOT / "assets").rglob("*")):
        if path.suffix.lower() not in BITMAPS | {".svg"}:
            continue
        relative = path.relative_to(ROOT).as_posix()
        row = {"path": relative, "web_exported": not any(fnmatch.fnmatchcase(relative, pattern) for pattern in excluded), "usage": usage(relative)}
        if path.suffix.lower() == ".svg":
            node = ET.parse(path).getroot()
            row.update(kind="vector", viewbox=node.attrib.get("viewBox"), width=node.attrib.get("width"), height=node.attrib.get("height"))
        else:
            with Image.open(path) as source:
                row.update(kind="bitmap", width=source.width, height=source.height, mode=source.mode)
        files.append(row)
    generated = []
    prompts = json.loads((HD / "prompts.json").read_text(encoding="utf-8"))
    for relative in sorted(prompts["assets"]):
        path = HD / relative
        with Image.open(path) as source:
            generated.append({"path": path.relative_to(ROOT).as_posix(), "native_width": source.width, "native_height": source.height, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    return {
        "review_date": "2026-11-01", "reference_viewport": [1920, 1080],
        "method": "Source inventory plus native crop dimensions, renderer usage review, and actual 1920x1080/800x600 app captures. No bitmap interpolation or Python image editing.",
        "baseline_bitmap_count": sum(row["kind"] == "bitmap" and "/starfront-hd/" not in row["path"] for row in files),
        "vector_count": sum(row["kind"] == "vector" for row in files),
        "regenerated_file_count": len(generated),
        "exported_bitmap_count": sum(row["kind"] == "bitmap" and row["web_exported"] for row in files),
        "native_use_comparison": [
            {"use": "9 full-screen backgrounds", "before": "3x3 cells, approximately 557x314 each", "after": "9 individual 1672x941 native images", "change": "approximately 3x per axis, 9x pixels per scene"},
            {"use": "20 environmental sprites", "before": "4x5 atlas; approximately 280x280 per cell", "after": "5 2x2 sheets, 1254x1254 each; individual measured silhouettes up to about 700x630", "change": "Native detail increased; crop regions preserve overhangs and transparent margins"},
            {"use": "18 detail material patches", "before": "256x256 cells", "after": "512x501..526 native patches", "change": "Approximately 2x per axis"},
            {"use": "4 roof textures and 1 long timber texture", "before": "256x256 cells", "after": "5 independent 2172x724 textures", "change": "Long parts no longer enlarge tiny square swatches"},
        ],
        "limits": "Dimensions are measured from returned ImageGen files, not the requested prompt size. The backgrounds are not represented as 4K; additional scaling on larger displays remains possible. Nine-slice panel centers and repeated single-brick tiles are intentional scalable surfaces.",
        "generated": generated, "files": files,
    }


if __name__ == "__main__":
    report = inspect()
    output = ROOT / "docs/IMAGE_RESOLUTION_AUDIT.json"
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Inspected {report['baseline_bitmap_count']} original bitmaps and {report['vector_count']} vectors; {report['regenerated_file_count']} regenerated files. Current export: {report['exported_bitmap_count']} bitmaps. Report: {output}")
