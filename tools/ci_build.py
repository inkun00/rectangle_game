"""Build from source on Vercel/Linux or CI without committed build artifacts.

Tool downloads stay outside the checkout. The official template archive is read
with HTTP ranges so a web build downloads about 21 MB, rather than all platforms.
Every retained binary is checked against a pinned SHA-256 from Godot 4.7.2.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.7.2"
TEMPLATE_VERSION = f"{VERSION}.stable"
RELEASE = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable"
TEMPLATE_ARCHIVE = f"Godot_v{VERSION}-stable_export_templates.tpz"
TEMPLATE_ARCHIVE_SIZE = 1_281_349_702
TEMPLATE_ARCHIVE_SHA256 = "f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011"
TEMPLATES = {
    "version.txt": "38885c88f75abbc797a1db7559719800279a00cfb9fa8b2e2868a7f6f84bad2e",
    "web_release.zip": "02f0dca13ed3d8343fa68f8f88ac80295562408d71aa67157e8b96ddebaa67a3",
    "web_nothreads_release.zip": "d3ee2f08cef0cf3cf6678a6355a92a8db48ccdd35cbd2e8bfd5f0e8a0b4032a0",
}
LINUX_ARCHIVE = f"Godot_v{VERSION}-stable_linux.x86_64.zip"
LINUX_ARCHIVE_SHA256 = "cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4"
ENGINE_PROBLEM = re.compile(r"^\s*(?:SCRIPT ERROR|ERROR|WARNING):", re.MULTILINE)
ANSI_ESCAPE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
GENERATED_FONT = r"res://\.godot/imported/korean_font\.ttf-[0-9a-f]{32}\.fontdata"
FONT_BOOTSTRAP_PROBLEMS = tuple(re.compile(pattern) for pattern in (
    rf"ERROR: Cannot open file '{GENERATED_FONT}'\.",
    rf"ERROR: Failed loading resource: {GENERATED_FONT}\.",
    r"ERROR: Failed loading resource: res://assets/fonts/korean_font\.ttf\.",
    r"ERROR: Error loading custom project font 'res://assets/fonts/korean_font\.ttf'",
))


class RangeUnavailable(RuntimeError):
    """The download server requires the verified full-archive fallback."""


def request(url: str, headers: dict[str, str] | None = None):
    for attempt in range(3):
        try:
            return urllib.request.urlopen(
                urllib.request.Request(url, headers={"User-Agent": "rectangle-game-build", **(headers or {})}),
                timeout=90,
            )
        except (urllib.error.URLError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(attempt + 1)


class ReleaseZipReader(io.RawIOBase):
    """Seekable, bounded HTTP reader for zipfile's central directory/member reads."""

    def __init__(self) -> None:
        self.position = 0

    def readable(self) -> bool:
        return True

    def seekable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.position

    def seek(self, offset: int, whence: int = 0) -> int:
        bases = {0: 0, 1: self.position, 2: TEMPLATE_ARCHIVE_SIZE}
        if whence not in bases or not 0 <= bases[whence] + offset <= TEMPLATE_ARCHIVE_SIZE:
            raise ValueError("Invalid template archive seek")
        self.position = bases[whence] + offset
        return self.position

    def read(self, size: int = -1) -> bytes:
        remaining = TEMPLATE_ARCHIVE_SIZE - self.position
        size = remaining if size < 0 else min(size, remaining)
        if size == 0:
            return b""
        start, end = self.position, self.position + size - 1
        with request(f"{RELEASE}/{TEMPLATE_ARCHIVE}", {"Range": f"bytes={start}-{end}"}) as response:
            if response.status != 206:
                raise RangeUnavailable("Server did not return a partial template archive")
            expected = f"bytes {start}-{end}/{TEMPLATE_ARCHIVE_SIZE}"
            if response.headers.get("Content-Range") != expected:
                raise RangeUnavailable("Unexpected template archive byte range")
            data = response.read(size + 1)
        if len(data) != size:
            raise OSError("Incomplete template archive range")
        self.position += size
        return data


def matches(path: Path, digest: str) -> bool:
    if not path.is_file():
        return False
    hasher = hashlib.sha256()
    with path.open("rb") as source:
        while block := source.read(1024 * 1024):
            hasher.update(block)
    return hasher.hexdigest() == digest


def write_verified(path: Path, data: bytes, digest: str) -> None:
    if hashlib.sha256(data).hexdigest() != digest:
        raise ValueError(f"SHA-256 mismatch: {path.name}")
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".download")
    temporary.write_bytes(data)
    temporary.replace(path)


def download(path: Path, filename: str, digest: str) -> None:
    if matches(path, digest):
        return
    print(f"Downloading official {filename}", flush=True)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".download")
    hasher = hashlib.sha256()
    with request(f"{RELEASE}/{filename}") as response, temporary.open("wb") as output:
        while block := response.read(1024 * 1024):
            output.write(block)
            hasher.update(block)
    if hasher.hexdigest() != digest:
        temporary.unlink(missing_ok=True)
        raise ValueError(f"SHA-256 mismatch: {filename}")
    temporary.replace(path)


def template_directory() -> Path:
    if sys.platform == "win32":
        return Path(os.environ["APPDATA"]) / "Godot/export_templates" / TEMPLATE_VERSION
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "godot/export_templates" / TEMPLATE_VERSION


def install_templates(cache: Path) -> None:
    destination = template_directory()
    needed = {name: digest for name, digest in TEMPLATES.items() if not matches(destination / name, digest)}
    if not needed:
        return
    print("Installing pinned web export templates (HTTP ranges, SHA-256 and ZIP CRC checked)", flush=True)

    def extract(archive: zipfile.ZipFile) -> None:
        for name, digest in needed.items():
            member = archive.getinfo(f"templates/{name}")
            if member.is_dir() or member.file_size > 30_000_000:
                raise ValueError(f"Unexpected web template member: {name}")
            # Fixed names only; never extract arbitrary paths from the archive.
            write_verified(destination / name, archive.read(member), digest)

    try:
        with zipfile.ZipFile(ReleaseZipReader()) as archive:
            extract(archive)
    except RangeUnavailable:
        print("HTTP ranges unavailable; falling back to the verified official full archive", flush=True)
        full_archive = cache / TEMPLATE_ARCHIVE
        download(full_archive, TEMPLATE_ARCHIVE, TEMPLATE_ARCHIVE_SHA256)
        with zipfile.ZipFile(full_archive) as archive:
            extract(archive)
        full_archive.unlink()


def resolve_engine(cache: Path, supplied: str | None) -> Path:
    if supplied:
        path = Path(shutil.which(supplied) or supplied).resolve()
    else:
        if sys.platform != "linux" or os.uname().machine != "x86_64":
            raise RuntimeError("Automatic engine setup supports Linux x86_64; pass --godot or GODOT_EXE on other systems")
        path = cache / f"Godot_v{VERSION}-stable_linux.x86_64"
        if not path.is_file():
            package = cache / LINUX_ARCHIVE
            download(package, LINUX_ARCHIVE, LINUX_ARCHIVE_SHA256)
            with zipfile.ZipFile(package) as archive:
                # The whole editor archive has already been SHA-256 verified.
                path.write_bytes(archive.read(path.name))
            path.chmod(0o755)
            package.unlink()
    version = subprocess.check_output([str(path), "--headless", "--version"], text=True, encoding="utf-8", errors="replace").strip()
    if not version.startswith(f"{VERSION}.stable."):
        raise RuntimeError(f"Godot {VERSION}.stable required, found {version}")
    print(f"Using Godot {version}", flush=True)
    return path


def engine_problems(output: str) -> list[str]:
    return [line.strip() for line in ANSI_ESCAPE.sub("", output).splitlines() if ENGINE_PROBLEM.match(line)]


def run(command: list[str], *, check_engine: bool = False, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    print("+ " + " ".join(command), flush=True)
    environment = dict(os.environ if env is None else env)
    environment["GODOT_SILENCE_ROOT_WARNING"] = "1"
    result = subprocess.run(command, cwd=ROOT, env=environment, text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout, end="", flush=True)
    if result.returncode or (check_engine and engine_problems(result.stdout)):
        raise RuntimeError(f"Build step failed: {command[0]}")
    return result


def import_project(engine: str) -> None:
    command = [engine, "--headless", "--editor", "--import", "--quit", "--path", str(ROOT)]
    result = run(command)
    problems = engine_problems(result.stdout)
    if not problems:
        return
    # On a clean checkout, ThemeDB can ask for the project's generated font
    # before the importer creates it. Retry once only for these exact messages,
    # with exit code zero and an explicit missing generated-font diagnostic.
    known_font_only = all(any(pattern.fullmatch(line) for pattern in FONT_BOOTSTRAP_PROBLEMS) for line in problems)
    missing_generated_font = any(FONT_BOOTSTRAP_PROBLEMS[0].fullmatch(line) for line in problems)
    if not known_font_only or not missing_generated_font:
        raise RuntimeError("Godot import reported an unexpected error or warning")
    print("Fresh-cache font bootstrap completed; verifying import again with strict error checking", flush=True)
    run(command, check_engine=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_EXE"))
    parser.add_argument("--test", action="store_true", help="Run the existing Godot headless suite before export")
    parser.add_argument("--desktop", action="store_true", help="Also generate the Windows PCK and launcher")
    parser.add_argument("--templates-only", action="store_true", help="Install web templates without running Godot")
    args = parser.parse_args()
    cache = Path(os.environ.get("RECTANGLE_BUILD_CACHE", Path.home() / ".cache/rectangle-game-build"))
    cache.mkdir(parents=True, exist_ok=True)
    install_templates(cache)
    if args.templates_only:
        print(f"Web export templates ready: {template_directory()}")
        return
    engine = str(resolve_engine(cache, args.godot))
    dependencies = cache / f"python-{sys.version_info.major}.{sys.version_info.minor}"
    run([sys.executable, "-m", "pip", "install", "--disable-pip-version-check", "--target", str(dependencies), "--upgrade", "-r", "tools/requirements-web.txt"])
    environment = dict(os.environ)
    environment["PYTHONPATH"] = str(dependencies) + (os.pathsep + environment["PYTHONPATH"] if environment.get("PYTHONPATH") else "")
    run([sys.executable, "tools/subset_font.py"], env=environment)
    import_project(engine)
    if args.test:
        run([engine, "--headless", "--path", str(ROOT), "res://tests/test_runner.tscn"], check_engine=True)
    (ROOT / "build/web").mkdir(parents=True, exist_ok=True)
    run([engine, "--headless", "--path", str(ROOT), "--script", "tools/export_button_web.gd"], check_engine=True)
    run([engine, "--headless", "--path", str(ROOT), "--export-release", "Web", "build/web/index.html"], check_engine=True)
    if args.desktop:
        desktop = ROOT / "build/windows"
        desktop.mkdir(parents=True, exist_ok=True)
        run([engine, "--headless", "--path", str(ROOT), "--export-pack", "Windows Desktop", str(desktop / "QuadrilateralWorld.pck")], check_engine=True)
        launcher = ('@echo off\r\nsetlocal\r\nset "QUADRILATERAL_WORLD_PROJECT_DIR=%~dp0"\r\n'
                    'set "QUADRILATERAL_WORLD_PACK=%~dp0QuadrilateralWorld.pck"\r\n'
                    'powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference=\'Stop\'; . (Join-Path $env:QUADRILATERAL_WORLD_PROJECT_DIR \'godot_common.ps1\'); $engine=Resolve-GodotExecutable; & $engine --main-pack $env:QUADRILATERAL_WORLD_PACK; exit $LASTEXITCODE"\r\nexit /b %ERRORLEVEL%\r\n')
        (desktop / "Run_QuadrilateralWorld.bat").write_bytes(launcher.encode("ascii"))
        shutil.copyfile(ROOT / "tools/godot_common.ps1", desktop / "godot_common.ps1")
        for notice in (ROOT / "licenses").glob("*.txt"):
            shutil.copyfile(notice, desktop / notice.name)
    # Desktop export scans the project again and can create sidecars in build/web.
    # Compress and clean the web directory after the final Godot process exits.
    run([sys.executable, "tools/prepare_web_release.py"], env=environment)
    print("Source build completed; outputs are in build/", flush=True)


if __name__ == "__main__":
    main()
