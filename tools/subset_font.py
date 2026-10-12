"""Build the bundled UI font from its losslessly compressed complete source."""

from io import BytesIO
import lzma
from pathlib import Path
from tempfile import NamedTemporaryFile

from fontTools import subset
from fontTools.ttLib import TTFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools/font_sources/korean_font_full.ttf.xz"
OUTPUT = ROOT / "assets/fonts/korean_font.ttf"
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".html"}
TEXT_ROOTS = (ROOT / "scenes", ROOT / "scripts", ROOT / "assets/theme", ROOT / "web")


def required_codepoints() -> set[int]:
    codepoints = set(range(0x20, 0x100))
    codepoints.update(range(0x1100, 0x1200))  # Hangul Jamo for composing text.
    codepoints.update(range(0x3130, 0x3190))  # Compatibility Jamo.
    codepoints.update(range(0x2000, 0x2070))  # Common punctuation.
    for directory in TEXT_ROOTS:
        for path in directory.rglob("*"):
            if path.is_file() and path.suffix in TEXT_SUFFIXES:
                codepoints.update(map(ord, path.read_text(encoding="utf-8")))
    codepoints.update(map(ord, (ROOT / "project.godot").read_text(encoding="utf-8")))
    return codepoints


def main() -> None:
    source_bytes = lzma.decompress(SOURCE.read_bytes())
    source = TTFont(BytesIO(source_bytes))
    supported = set(source.getBestCmap())
    wanted = required_codepoints() & supported
    options = subset.Options()
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=wanted)
    subsetter.subset(source)
    if wanted - set(source.getBestCmap()):
        raise RuntimeError("Font subsetting removed required characters")
    source.recalcTimestamp = False
    with NamedTemporaryFile(dir=OUTPUT.parent, suffix=".ttf", delete=False) as temporary:
        temporary_path = Path(temporary.name)
    try:
        source.save(temporary_path)
        temporary_path.replace(OUTPUT)
    finally:
        temporary_path.unlink(missing_ok=True)
    source.close()
    print(
        f"UI font: {len(source_bytes):,} -> {OUTPUT.stat().st_size:,} bytes "
        f"({len(wanted)} characters; complete source stored in {SOURCE.stat().st_size:,} bytes)"
    )


if __name__ == "__main__":
    main()
