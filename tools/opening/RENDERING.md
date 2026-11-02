# Local opening renderer

The renderer follows the free, code-driven `renderAt(t)` workflow documented in
[the research notes](../../docs/OPENING_REFERENCES.md). It uses the installed
Chromium/Chrome/Edge, Playwright Core and FFmpeg. It does not call a video service,
upload assets or use a Claude model. The film is rendered from local source and
the original soundtrack is muxed on the same timebase.

From the repository root:

```powershell
npm.cmd --prefix tools/opening ci --ignore-scripts --no-fund --no-audit
python tools/opening/compose_music.py
node tools/opening/render.mjs --contact
node tools/opening/render.mjs --draft
node tools/opening/render.mjs
```

Review the contact sheet and the draft before the final render. No step deletes
the source images, soundtrack or previous ignored chunk directories.

| Mode | Deliverable |
| --- | --- |
| `--contact` | `output/opening/contact-sheet.jpg`, one frame per second in `frames/`, nine full-resolution `keyframes/`, `frames.json`, `assets/video/opening-poster.png` |
| `--draft` | Contact outputs plus `output/opening/draft.mp4`, 960×540, 15 fps, 55 seconds, stereo soundtrack |
| no flag | Contact outputs plus `output/opening/quadrilateral-opening.mp4`, 1920×1080, 30 fps, 55 seconds; `assets/video/quadrilateral-opening.ogv`, 1280×720, Theora/Vorbis |

`--help` prints usage. `CHROME_PATH`, `FFMPEG_PATH`, and `PYTHON_PATH` can override
installed executables. `OPENING_WORKERS` accepts integers 1–4. Defaults use up to
four contiguous chunks with two FFmpeg encoding threads per chunk. The renderer
discovers Playwright's existing local Chromium installations when Chrome/Edge are
not installed in their usual locations. FFmpeg is found on PATH or through the
existing Python `imageio_ffmpeg` package. Browser downloads are not triggered.

## Scene contract

`scene.html` exposes `window.ready`, a Promise resolving after local fonts and
images have loaded, and `window.renderAt(seconds)`. Every frame must be a pure
function of the supplied absolute time. The canvas backing store must match the
viewport size. Preview RAF loops should respect any of `window.__rendering`,
`window.__RENDERING`, or `window.__CAPTURE`. During capture RAF is stopped and the
clock is explicitly set before each call. Exported frames do not depend on actual
wall-clock render speed. Do not use per-frame incremental particle state or
unseeded random values.

The server binds only to `127.0.0.1`, serves only files under the project root and
blocks external asset requests. A failed asset, browser exception, encoder
failure or broken pipe fails the command. The PNG pipe waits for every write to
flush, and FFmpeg must finish successfully before a final file replaces its
destination. Temporary chunks live under the ignored `.godot/opening-render/`.

The contact pass compares SHA-256 hashes of identical timestamps after visiting
an unrelated timestamp (9.3 → 50.5 → 9.3 and 35.5 → 50.5 → 35.5). A mismatch stops
rendering. The per-second times, hashes and results are saved to `frames.json`.

For this film's single full-viewport canvas, frames are read directly with
`canvas.toDataURL('image/png')` after exactly one `renderAt(t)` call. This avoids
Chrome's screenshot compositor and expensive screenshot PNG compression. Scenes
without a matching canvas fall back to `page.screenshot()` using the frame already
drawn. Capture counts and the selected method are recorded in `render.json`.

### Capture benchmark, 2026-11-03

Measured on the development machine (Ryzen 5 5600, Chrome 156, Windows), while the
first full render was active. Ten 1920×1080 frames starting at 18 seconds:

| Capture method | Total time | PNG bytes for ten frames |
| --- | --- | --- |
| `page.screenshot()` | 5.303 s | 24,963,025 |
| `canvas.toDataURL('image/png')` | 1.479 s | 36,655,754 |

The direct canvas PNG path was 3.6× faster. At 18.0 seconds the two PNGs decoded to
identical RGB pixels: 1920×1080, maximum channel error 0, mean error 0, differing
pixel count 0. The PNG compression differs; the picture does not. The benchmark
source and evidence are retained in ignored `.godot/opening_browser_benchmark.mjs`
and `.godot/opening-browser-benchmark.log`.

A separate 75-frame PNG-to-H.264 benchmark using the production FFmpeg arguments
completed in 1.353 s. Forcing a single PNG decoder thread took 2.458 s, so that
change was not adopted. Evidence is in `.godot/opening_ffmpeg_benchmark.py` and
`.godot/ffmpeg-benchmark-default.log`. The encoder is not the capture bottleneck.

The MP4 is the shareable high-resolution film. Godot uses the lower-resolution
OGV because its built-in player supports Theora and web video decoding is CPU
bound. The actual OGV should be checked in Godot after every video regeneration.
