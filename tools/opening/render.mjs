/**
 * Quadrilateral World opening: deterministic, entirely local frame rendering.
 * Method inspired by the CC0 Awesome Claude motion-graphics renderer; see
 * .agents/skills/motion-graphics and docs/OPENING_REFERENCES.md for provenance.
 */
import { chromium } from 'playwright-core';
import { spawn, spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { createHash } from 'node:crypto';
import { readFile, writeFile, mkdir, mkdtemp, readdir, stat, rename } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { cpus } from 'node:os';
import { dirname, join, resolve, relative, extname, isAbsolute } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '../..');
const OUTPUT = join(ROOT, 'output/opening');
const VIDEO = join(ROOT, 'assets/video');
const CACHE = join(ROOT, '.godot/opening-render');
const SCENE = join(HERE, 'scene.html');
const DURATION = 55;
const KEYFRAMES = [0.5, 6, 9.3, 12, 18.5, 25, 35.5, 42.5, 50.5];
const args = new Set(process.argv.slice(2));
const allowed = new Set(['--contact', '--draft', '--help']);
for (const arg of args) {
  if (!allowed.has(arg)) throw new Error(`Unknown argument: ${arg}. Use --help.`);
}
if (args.has('--help')) {
  console.log('node tools/opening/render.mjs [--contact | --draft]\n' +
    '  --contact: 1 fps contact sheet, full-size keyframes, poster, determinism check\n' +
    '  --draft: contact sheet + 960x540 / 15 fps draft with soundtrack\n' +
    '  default: contact sheet + 1920x1080 / 30 fps MP4 + 1280x720 OGV\n' +
    'Optional environment: CHROME_PATH, FFMPEG_PATH, PYTHON_PATH, OPENING_WORKERS (1..4).');
  process.exit(0);
}
if (args.has('--contact') && args.has('--draft')) throw new Error('Choose --contact or --draft.');

const python = process.env.PYTHON_PATH || 'python';
let browser;
let server;
let interrupted = false;
let renderFailure = null;
const children = new Set();
const browserErrors = [];
const captureStats = { canvas: 0, screenshot: 0 };

function ensureRunning() {
  if (interrupted) throw new Error('Rendering interrupted.');
  if (renderFailure) throw renderFailure;
  if (browserErrors.length) throw new Error(browserErrors.join('\n'));
}

/** Spawn without shell interpolation; retain a bounded diagnostic tail. */
function startChild(executable, argv, pipe = false) {
  const child = spawn(executable, argv, {
    cwd: ROOT,
    windowsHide: true,
    stdio: [pipe ? 'pipe' : 'ignore', 'pipe', 'pipe'],
  });
  const record = { child, closed: false, failure: null, tail: '', done: null };
  children.add(record);
  const append = (data) => { record.tail = (record.tail + data.toString()).slice(-10000); };
  child.stdout.on('data', append);
  child.stderr.on('data', append);
  // A broken pipe must reject a write rather than become an unhandled event.
  if (child.stdin) child.stdin.on('error', (error) => { record.failure = error; });
  record.done = new Promise((resolveDone, rejectDone) => {
    child.once('error', (error) => {
      record.failure = error;
      rejectDone(error);
    });
    child.once('close', (code, signal) => {
      record.closed = true;
      children.delete(record);
      if (code === 0 && !record.failure) resolveDone(record.tail);
      else {
        record.failure ||= new Error(`${executable} failed (${code ?? signal}):\n${record.tail}`);
        rejectDone(record.failure);
      }
    });
  });
  // The consumer awaits this after feeding frames; prevent an early-exit warning.
  record.done.catch(() => {});
  return record;
}

async function run(executable, argv) {
  ensureRunning();
  return await startChild(executable, argv).done;
}

async function findChrome() {
  if (process.env.CHROME_PATH) {
    if (!existsSync(process.env.CHROME_PATH)) throw new Error('CHROME_PATH does not exist.');
    return process.env.CHROME_PATH;
  }
  const candidates = [];
  for (const base of [process.env.PROGRAMFILES, process.env['PROGRAMFILES(X86)'], process.env.LOCALAPPDATA].filter(Boolean)) {
    candidates.push(join(base, 'Google/Chrome/Application/chrome.exe'));
    candidates.push(join(base, 'Microsoft/Edge/Application/msedge.exe'));
  }
  const installed = join(process.env.LOCALAPPDATA || '', 'ms-playwright');
  if (existsSync(installed)) {
    const revisions = (await readdir(installed)).filter((name) => /^chromium-\d+$/.test(name))
      .sort((a, b) => Number(b.split('-')[1]) - Number(a.split('-')[1]));
    for (const revision of revisions) {
      candidates.push(join(installed, revision, 'chrome-win64/chrome.exe'));
      candidates.push(join(installed, revision, 'chrome-win/chrome.exe'));
    }
  }
  const found = candidates.find((candidate) => existsSync(candidate));
  if (!found) throw new Error('Chrome/Chromium/Edge not found. Set CHROME_PATH to an installed browser.');
  return found;
}

function findFfmpeg() {
  if (process.env.FFMPEG_PATH) {
    if (!existsSync(process.env.FFMPEG_PATH)) throw new Error('FFMPEG_PATH does not exist.');
    return process.env.FFMPEG_PATH;
  }
  const local = spawnSync('ffmpeg', ['-version'], { encoding: 'utf8', windowsHide: true });
  if (local.status === 0) return 'ffmpeg';
  const result = spawnSync(python, ['-c', 'import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())'],
    { encoding: 'utf8', windowsHide: true });
  const path = result.stdout?.trim();
  if (result.status !== 0 || !path || !existsSync(path)) {
    throw new Error('FFmpeg not found. Set FFMPEG_PATH or install imageio-ffmpeg in the selected Python.');
  }
  return path;
}

async function serve() {
  const mime = {
    '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8', '.json': 'application/json',
    '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp',
    '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2',
    '.wav': 'audio/wav', '.mp3': 'audio/mpeg', '.css': 'text/css; charset=utf-8',
  };
  server = createServer(async (request, response) => {
    try {
      const pathname = decodeURIComponent(new URL(request.url, 'http://127.0.0.1').pathname);
      if (pathname === '/favicon.ico') { response.writeHead(204); response.end(); return; }
      const file = resolve(ROOT, '.' + pathname);
      const fromRoot = relative(ROOT, file);
      if (fromRoot.startsWith('..') || isAbsolute(fromRoot) || !(await stat(file)).isFile()) {
        response.writeHead(403); response.end('Forbidden'); return;
      }
      const bytes = await readFile(file);
      response.writeHead(200, { 'Content-Type': mime[extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
      response.end(bytes);
    } catch {
      response.writeHead(404); response.end('Not found');
    }
  });
  await new Promise((resolveListen, rejectListen) => {
    server.once('error', rejectListen);
    server.listen(0, '127.0.0.1', resolveListen);
  });
  return `http://127.0.0.1:${server.address().port}`;
}

function captureClock() {
  window.__rendering = true;
  window.__RENDERING = true;
  window.__CAPTURE = true;
  let frameTime = 0;
  let rafId = 0;
  const epoch = 1793664000000;
  Object.defineProperty(performance, 'now', { value: () => frameTime, configurable: true });
  Date.now = () => epoch + frameTime;
  window.requestAnimationFrame = () => ++rafId;
  window.cancelAnimationFrame = () => {};
  window.__setFrameTime = (seconds) => {
    frameTime = seconds * 1000;
    for (const animation of document.getAnimations()) {
      animation.pause();
      animation.currentTime = frameTime;
    }
  };
}

async function openPage(origin, width, height) {
  const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
  page.on('pageerror', (error) => browserErrors.push(`Scene error: ${error.message}`));
  page.on('requestfailed', (request) => browserErrors.push(`Failed asset: ${request.url()} (${request.failure()?.errorText})`));
  page.on('response', (response) => {
    if (response.status() >= 400) browserErrors.push(`Missing asset: ${response.status()} ${response.url()}`);
  });
  await page.route('**/*', async (route) => {
    const url = route.request().url();
    if (url.startsWith(origin + '/') || url.startsWith('data:') || url.startsWith('blob:')) await route.continue();
    else {
      browserErrors.push(`External resource is not permitted: ${url}`);
      await route.abort('blockedbyclient');
    }
  });
  await page.addInitScript(captureClock);
  await page.goto(`${origin}/tools/opening/scene.html?capture=1`, { waitUntil: 'networkidle', timeout: 60000 });
  await page.evaluate(async () => {
    if (!window.ready || typeof window.ready.then !== 'function') throw new Error('Scene must expose window.ready as a Promise.');
    await Promise.race([
      Promise.all([window.ready, document.fonts.ready]),
      new Promise((_, reject) => setTimeout(() => reject(new Error('Scene assets were not ready within 60 seconds.')), 60000)),
    ]);
    await Promise.all(Array.from(document.images, async (image) => {
      if (!image.complete) await image.decode();
      if (!image.naturalWidth) throw new Error(`Image did not load: ${image.src}`);
    }));
    if (typeof window.renderAt !== 'function') throw new Error('Scene must expose window.renderAt(seconds).');
  });
  ensureRunning();
  return page;
}

async function capture(page, seconds) {
  ensureRunning();
  const canvasPng = await page.evaluate(async (t) => {
    window.__setFrameTime(t);
    await window.renderAt(t);
    // This film is one full-viewport canvas. Read its PNG directly to bypass
    // Chrome's slower screenshot compositor/PNG path without changing pixels.
    // Non-canvas scenes retain the screenshot fallback, with no second draw.
    const canvases = document.querySelectorAll('canvas');
    const canvas = canvases.length === 1 ? canvases[0] : null;
    if (canvas) {
      const bounds = canvas.getBoundingClientRect();
      if (bounds.x === 0 && bounds.y === 0 && bounds.width === innerWidth &&
          bounds.height === innerHeight && canvas.width === innerWidth && canvas.height === innerHeight) {
        return canvas.toDataURL('image/png').split(',')[1];
      }
    }
    return null;
  }, seconds);
  const bytes = canvasPng
    ? Buffer.from(canvasPng, 'base64')
    : await page.screenshot({ type: 'png', animations: 'allow', caret: 'hide' });
  captureStats[canvasPng ? 'canvas' : 'screenshot']++;
  ensureRunning();
  return bytes;
}

async function contactSheet(origin) {
  const frames = join(OUTPUT, 'frames');
  const keyframes = join(OUTPUT, 'keyframes');
  await mkdir(frames, { recursive: true });
  await mkdir(keyframes, { recursive: true });
  const page = await openPage(origin, 960, 540);
  try {
    const samples = [];
    for (let second = 0; second < DURATION; second++) {
      const name = `second-${String(second).padStart(2, '0')}.png`;
      const bytes = await capture(page, second);
      await writeFile(join(frames, name), bytes);
      samples.push({ time: second, file: `frames/${name}`, sha256: createHash('sha256').update(bytes).digest('hex') });
    }
    const determinism = [];
    for (const time of [9.3, 35.5]) {
      const first = await capture(page, time);
      await capture(page, 50.5);
      const second = await capture(page, time);
      const hash = (bytes) => createHash('sha256').update(bytes).digest('hex');
      if (hash(first) !== hash(second)) throw new Error(`Non-deterministic scene at ${time}s. The frame depends on prior playback.`);
      determinism.push({ time, sha256: hash(first), passed: true });
    }
    await page.setViewportSize({ width: 1920, height: 1080 });
    for (const time of KEYFRAMES) {
      const name = `frame-${time.toFixed(1).replace('.', '-')}.png`;
      await writeFile(join(keyframes, name), await capture(page, time));
    }
    await page.setViewportSize({ width: 1280, height: 720 });
    await writeFile(join(VIDEO, 'opening-poster.png'), await capture(page, 50));
    await writeFile(join(OUTPUT, 'frames.json'), JSON.stringify({ duration: DURATION, samples, keyframes: KEYFRAMES, determinism }, null, 2) + '\n');
  } finally { await page.close(); }
  const script = [
    'from pathlib import Path', 'from PIL import Image, ImageDraw, ImageFont', 'import sys',
    'base = Path(sys.argv[1])', 'files = sorted((base / "frames").glob("second-*.png"))',
    'w, h, label, cols = 320, 180, 28, 6', 'rows = (len(files) + cols - 1) // cols',
    'sheet = Image.new("RGB", (cols*w, rows*(h+label)), "#0c1927")', 'draw = ImageDraw.Draw(sheet)',
    'font = ImageFont.load_default(size=18)',
    'for i, path in enumerate(files):',
    '    x, y = (i%cols)*w, (i//cols)*(h+label)',
    '    with Image.open(path) as frame: sheet.paste(frame.convert("RGB").resize((w,h), Image.Resampling.LANCZOS), (x,y))',
    '    draw.text((x+10,y+h+4), f"{i:02d}:00", fill="#e7f6ed", font=font)',
    'sheet.save(base / "contact-sheet.jpg", quality=94, subsampling=0)',
  ].join('\n');
  await run(python, ['-c', script, OUTPUT]);
  console.log('Contact sheet, keyframes, poster and determinism checks complete.');
}

async function renderChunk(origin, ffmpeg, directory, chunk, start, end, fps, width, height) {
  const output = join(directory, `chunk-${String(chunk).padStart(2, '0')}.mp4`);
  const page = await openPage(origin, width, height);
  let encoder;
  try {
    encoder = startChild(ffmpeg, ['-hide_banner', '-loglevel', 'warning', '-y',
      '-f', 'image2pipe', '-framerate', String(fps), '-i', 'pipe:0', '-an',
      '-frames:v', String(end - start), '-c:v', 'libx264', '-preset', 'fast', '-threads', '2',
      '-crf', '18', '-pix_fmt', 'yuv420p', '-fps_mode', 'cfr', '-movflags', '+faststart', output], true);
    for (let frame = start; frame < end; frame++) {
      if (encoder.failure) throw encoder.failure;
      if (encoder.closed) throw new Error(`Encoder closed before frame ${frame}.`);
      const bytes = await capture(page, frame / fps);
      // Waiting for the write callback bounds the buffer and propagates EPIPE.
      await new Promise((resolveWrite, rejectWrite) => {
        encoder.child.stdin.write(bytes, (error) => error ? rejectWrite(error) : resolveWrite());
      });
      if ((frame - start) % fps === 0) console.log(`Chunk ${chunk + 1}: frame ${frame}/${Math.round(DURATION * fps)}`);
    }
    encoder.child.stdin.end();
    await encoder.done;
    return output;
  } catch (error) {
    renderFailure ||= error;
    throw error;
  } finally {
    if (encoder && !encoder.closed) {
      encoder.child.kill();
      await encoder.done.catch(() => {});
    }
    await page.close();
  }
}

async function renderMovie(origin, ffmpeg, draft) {
  const soundtrack = join(OUTPUT, 'soundtrack.wav');
  if (!existsSync(soundtrack)) throw new Error(`Missing soundtrack: ${soundtrack}. Run compose_music.py first.`);
  const width = draft ? 960 : 1920;
  const height = draft ? 540 : 1080;
  const fps = draft ? 15 : 30;
  const frames = DURATION * fps;
  const configured = Number(process.env.OPENING_WORKERS || Math.min(4, Math.max(1, cpus().length - 1)));
  if (!Number.isInteger(configured) || configured < 1 || configured > 4) throw new Error('OPENING_WORKERS must be an integer from 1 to 4.');
  const directory = await mkdtemp(join(CACHE, draft ? 'draft-' : 'full-'));
  const jobs = Array.from({ length: configured }, (_, i) => renderChunk(origin, ffmpeg, directory, i,
    Math.floor(i * frames / configured), Math.floor((i + 1) * frames / configured), fps, width, height));
  const results = await Promise.allSettled(jobs);
  const failures = results.filter((result) => result.status === 'rejected');
  if (failures.length) throw new AggregateError(failures.map((result) => result.reason), 'One or more rendering chunks failed.');
  const paths = results.map((result) => result.value);
  const concat = join(directory, 'concat.txt');
  const escapePath = (path) => path.replaceAll('\\', '/').replaceAll("'", "'\\''");
  await writeFile(concat, paths.map((path) => `file '${escapePath(path)}'`).join('\n') + '\n');
  const finalTemp = join(directory, 'with-audio.mp4');
  await run(ffmpeg, ['-hide_banner', '-loglevel', 'warning', '-y', '-f', 'concat', '-safe', '0', '-i', concat,
    '-i', soundtrack, '-map', '0:v:0', '-map', '1:a:0', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k',
    '-t', String(DURATION), '-movflags', '+faststart', finalTemp]);
  const destination = join(OUTPUT, draft ? 'draft.mp4' : 'quadrilateral-opening.mp4');
  await rename(finalTemp, destination);
  console.log(`Wrote ${destination}`);
  if (!draft) {
    const ogvTemp = join(directory, 'quadrilateral-opening.ogv');
    await run(ffmpeg, ['-hide_banner', '-loglevel', 'warning', '-y', '-i', destination, '-i', soundtrack,
      '-map', '0:v:0', '-map', '1:a:0',
      '-vf', 'scale=1280:720:flags=lanczos', '-r', '30', '-c:v', 'libtheora', '-q:v', '7',
      '-g:v', '64', '-pix_fmt', 'yuv420p', '-c:a', 'libvorbis', '-q:a', '4', '-t', String(DURATION), ogvTemp]);
    await rename(ogvTemp, join(VIDEO, 'quadrilateral-opening.ogv'));
    console.log(`Wrote ${join(VIDEO, 'quadrilateral-opening.ogv')}`);
  }
  await writeFile(join(OUTPUT, draft ? 'draft-render.json' : 'render.json'), JSON.stringify({
    duration: DURATION, width, height, fps, frames, workers: configured, source: 'tools/opening/scene.html',
    soundtrack: 'output/opening/soundtrack.wav', movie: relative(ROOT, destination).replaceAll('\\', '/'),
    appMovie: draft ? null : 'assets/video/quadrilateral-opening.ogv',
    capture: { preferred: 'canvas.toDataURL(image/png)', fallback: 'page.screenshot', counts: captureStats },
  }, null, 2) + '\n');
}

async function cleanup() {
  interrupted = true;
  for (const record of children) record.child.kill();
  await Promise.allSettled([...children].map((record) => record.done));
  if (browser) await browser.close().catch(() => {});
  if (server) await new Promise((resolveClose) => server.close(resolveClose));
}
process.once('SIGINT', () => { interrupted = true; for (const record of children) record.child.kill(); });
process.once('SIGTERM', () => { interrupted = true; for (const record of children) record.child.kill(); });

try {
  if (!existsSync(SCENE)) throw new Error(`Scene is not ready: ${SCENE}`);
  await Promise.all([OUTPUT, VIDEO, CACHE].map((directory) => mkdir(directory, { recursive: true })));
  const chrome = await findChrome();
  const origin = await serve();
  console.log(`Using local browser: ${chrome}`);
  browser = await chromium.launch({ executablePath: chrome, headless: true,
    args: ['--disable-background-timer-throttling', '--disable-renderer-backgrounding'] });
  await contactSheet(origin);
  if (!args.has('--contact')) await renderMovie(origin, findFfmpeg(), args.has('--draft'));
} catch (error) {
  console.error(error.stack || error);
  if (error instanceof AggregateError) for (const child of error.errors) console.error(child.stack || child);
  process.exitCode = 1;
} finally {
  await cleanup();
}
