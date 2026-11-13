'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { Readable } = require('node:stream');
const { PNG } = require('pngjs');
const {
  BOARD_ID, BOARD_URL, PUBLIC_ORIGIN, MAX_BODY_BYTES,
  createSubmissionHandler, createImageHandler,
} = require('../api/_lib/padlet.cjs');

const image = new PNG({ width: 960, height: 600 });
image.data.fill(255);
const png = PNG.sync.write(image);
const base = {
  id: '0123456789abcdef0123456789abcdef',
  author: '사각이', title: '사각형으로 만든 우리 마을',
  description: '네모난 집과 파란 하늘을 표현했어요.', price: 2600,
  png_base64: png.toString('base64'),
};
const manifestPath = `padlet/submissions/${base.id}.json`;
const pngPath = `padlet/artworks/${base.id}.png`;
const publicPngUrl = `${PUBLIC_ORIGIN}/api/artwork-image?id=${base.id}`;
const legacyOrigin = 'https://rectangle-game-snowy.vercel.app';
const legacyPngUrl = `${legacyOrigin}/api/artwork-image?id=${base.id}`;
const post = {
  type: 'post', id: 'post_test_example', attributes: {
    status: 'approved', webUrl: { live: `${BOARD_URL}/wish/1234` },
    content: { attachment: { url: publicPngUrl } },
  },
};

class MemoryBlob {
  constructor() {
    this.files = new Map();
    this.version = 0;
    this.reads = [];
    this.writes = [];
  }
  async get(pathname, options) {
    this.reads.push({ pathname, options });
    const existing = this.files.get(pathname);
    if (!existing) return null;
    return {
      statusCode: 200,
      stream: new ReadableStream({ start(controller) { controller.enqueue(existing.bytes); controller.close(); } }),
      blob: { etag: existing.etag, contentType: existing.contentType, size: existing.bytes.length },
    };
  }
  async put(pathname, content, options) {
    if (this.beforePut) await this.beforePut(pathname, content, options);
    const existing = this.files.get(pathname);
    if (existing && !options.allowOverwrite) throw new Error('Blob already exists');
    if (options.ifMatch && existing?.etag !== options.ifMatch) throw new Error('ETag mismatch');
    const value = { bytes: Buffer.from(content), etag: `"v${++this.version}"`, contentType: options.contentType };
    this.files.set(pathname, value);
    this.writes.push({ pathname, options });
    return { pathname, etag: value.etag };
  }
  json(pathname) { return JSON.parse(this.files.get(pathname).bytes.toString('utf8')); }
  setJson(pathname, value) {
    this.files.set(pathname, { bytes: Buffer.from(JSON.stringify(value)), etag: `"v${++this.version}"`, contentType: 'application/json' });
  }
}

function environment(overrides = {}) {
  let clock = 1000000;
  const deps = {
    blob: new MemoryBlob(),
    env: { PADLET_API_KEY: 'test-private-padlet-key', BLOB_READ_WRITE_TOKEN: 'test-private-blob-key', NODE_ENV: 'production' },
    now: () => clock,
    pause: async () => {},
    calls: [],
    advance(milliseconds) { clock += milliseconds; },
    async fetch(url, options) {
      deps.calls.push({ url, options });
      return new Response(JSON.stringify(options.method === 'POST' ? { data: post } : { data: { type: 'board' }, included: [post] }), {
        status: options.method === 'POST' ? 201 : 200,
      });
    },
    ...overrides,
  };
  return deps;
}

async function call(handler, body = base, settings = {}) {
  const request = Readable.from([Buffer.from(typeof body === 'string' ? body : JSON.stringify(body))]);
  request.method = settings.method || 'POST';
  request.url = settings.url || '/api/padlet-artworks';
  request.headers = { 'content-type': 'application/json', host: new URL(PUBLIC_ORIGIN).host, 'x-vercel-forwarded-for': '203.0.113.40', ...settings.headers };
  if (settings.parsed !== false) request.body = body;
  const response = {
    headers: {}, statusCode: 0,
    setHeader(name, value) { this.headers[name.toLowerCase()] = value; },
    removeHeader(name) { delete this.headers[name.toLowerCase()]; },
    end(value) { this.bytes = value === undefined ? Buffer.alloc(0) : Buffer.from(value); },
  };
  await handler(request, response);
  if (response.headers['content-type']?.includes('application/json')) response.json = JSON.parse(response.bytes.toString());
  return response;
}

test('posts the completed PNG with all five fields to the fixed board, then serves identical pixels', async () => {
  const deps = environment();
  const response = await call(createSubmissionHandler(deps), { ...base, board_id: 'ignored', destination: 'https://invalid.example/' }, {
    headers: { origin: PUBLIC_ORIGIN }, parsed: false,
  });
  assert.equal(response.statusCode, 200);
  assert.equal(response.json.ok, true);
  assert.equal(response.json.post_url, post.attributes.webUrl.live);
  assert.equal(deps.calls[0].url, `https://api.padlet.dev/v1/boards/${BOARD_ID}/posts`);
  assert.equal(deps.calls[0].options.headers['X-API-KEY'], deps.env.PADLET_API_KEY);
  const content = JSON.parse(deps.calls[0].options.body).data.attributes.content;
  assert.equal(content.subject, base.title);
  assert.match(content.body, /사용자 이름: 사각이/);
  assert.match(content.body, /네모난 집과 파란 하늘/);
  assert.match(content.body, /게임 내 그림 가격: 2,600원/);
  assert.equal(content.attachment.url, publicPngUrl);
  assert.deepEqual(deps.blob.files.get(pngPath).bytes, png);
  assert.equal(deps.blob.json(manifestPath).state, 'published');
  assert.ok(deps.blob.reads.filter((read) => read.pathname.endsWith('.json')).every((read) => read.options.useCache === false));
  const result = await call(createImageHandler(deps), {}, { method: 'GET', url: `/api/artwork-image?id=${base.id}` });
  assert.equal(result.statusCode, 200);
  assert.equal(result.headers['content-type'], 'image/png');
  assert.equal(result.headers['cross-origin-resource-policy'], 'cross-origin');
  assert.deepEqual(result.bytes, png);
  assert.equal(response.bytes.includes(deps.env.PADLET_API_KEY), false);
  assert.equal(response.bytes.includes(deps.env.BLOB_READ_WRITE_TOKEN), false);
});

test('posts buildings and ending projects with their price labels and original PNG', async () => {
  for (const [kind, price, priceLine, descriptionLabel] of [
    ['commission', 260_000_000, /게임 내 건물 가격: 260,000,000원/, '건물 설명'],
    ['my_house', 10_700_000, /게임 내 재료비: 10,700,000원/, '건물 설명'],
    ['earth_house', 11_400_000, /게임 내 재료비: 11,400,000원/, '건물 설명'],
    ['spaceship', 1_200_000_000, /게임 내 우주선 제작비: 1,200,000,000원/, '우주선 설명'],
    ['spaceship', 1_800_000_000, /게임 내 우주선 제작비: 1,800,000,000원/, '우주선 설명'],
  ]) {
    const deps = environment();
    const projectName = kind === 'earth_house' ? '노을이 머무는 집'
      : kind === 'spaceship' ? '사각성으로 가는 푸른 별' : base.title;
    const submission = { ...base, kind, price, title: projectName };
    const handler = createSubmissionHandler(deps);
    assert.equal((await call(handler, submission)).statusCode, 200);
    const content = JSON.parse(deps.calls[0].options.body).data.attributes.content;
    assert.equal(content.subject, projectName);
    assert.equal(content.attachment.caption, projectName);
    assert.match(content.body, /사용자 이름: 사각이/);
    assert.ok(content.body.includes(`${descriptionLabel}: ${base.description}`));
    assert.match(content.body, priceLine);
    assert.equal(content.attachment.url, publicPngUrl);
    assert.deepEqual(deps.blob.files.get(pngPath).bytes, png);
    assert.equal((await call(handler, submission)).statusCode, 200);
    assert.equal(deps.calls.length, 1);
    if (kind === 'commission') {
      assert.equal((await call(handler, { ...submission, kind: 'my_house' })).statusCode, 409);
    }
  }
});

test('a saved drawing receipt is still recognized after the addition of publication kinds', async () => {
  const deps = environment();
  const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');
  const legacyPayload = [base.id, base.author, base.title, base.description, base.price, digest(png)];
  deps.blob.setJson(manifestPath, {
    version: 1, id: base.id, state: 'published', payload_hash: digest(JSON.stringify(legacyPayload)),
    post_url: post.attributes.webUrl.live,
  });
  const response = await call(createSubmissionHandler(deps));
  assert.equal(response.statusCode, 200);
  assert.equal(response.json.post_url, post.attributes.webUrl.live);
  assert.equal(deps.calls.length, 0);
});

test('attachment URLs stay on an approved production domain', async () => {
  const legacyHost = new URL(legacyOrigin).host;
  for (const [host, productionHost, expectedUrl] of [
    [legacyHost, undefined, legacyPngUrl],
    ['generated-deployment.vercel.app', legacyHost, legacyPngUrl],
    ['untrusted.example', 'untrusted.example', publicPngUrl],
  ]) {
    const deps = environment();
    deps.env.VERCEL_PROJECT_PRODUCTION_URL = productionHost;
    const response = await call(createSubmissionHandler(deps), base, { headers: { host, origin: legacyOrigin } });
    assert.equal(response.statusCode, 200);
    const content = JSON.parse(deps.calls[0].options.body).data.attributes.content;
    assert.equal(content.attachment.url, expectedUrl);
  }
});

test('repeated and cold-start submissions reuse the receipt; a changed payload cannot reuse its id', async () => {
  const deps = environment();
  await call(createSubmissionHandler(deps));
  const duplicate = await call(createSubmissionHandler(deps));
  assert.equal(duplicate.json.ok, true);
  assert.equal(deps.calls.length, 1);
  for (const changed of [{ title: '다른 제목' }, { price: 4500 }, { author: '다른 작가' }]) {
    const response = await call(createSubmissionHandler(deps), { ...base, ...changed });
    assert.equal(response.statusCode, 409);
    assert.equal(response.json.retryable, false);
  }
  assert.equal(deps.calls.length, 1);
});

test('two independent functions publishing concurrently create one Padlet post', async () => {
  const deps = environment();
  let release;
  let started;
  const startedPromise = new Promise((resolve) => { started = resolve; });
  const releasePromise = new Promise((resolve) => { release = resolve; });
  const normalFetch = deps.fetch;
  deps.fetch = async (url, options) => {
    if (options.method === 'POST') { started(); await releasePromise; }
    return normalFetch(url, options);
  };
  const firstPromise = call(createSubmissionHandler(deps));
  await startedPromise;
  const competing = await call(createSubmissionHandler(deps));
  assert.equal(competing.statusCode, 202);
  release();
  const first = await firstPromise;
  assert.equal(first.json.ok, true);
  assert.equal(deps.calls.filter((entry) => entry.options.method === 'POST').length, 1);
  assert.equal((await call(createSubmissionHandler(deps))).json.ok, true);
});

test('a lost POST response reconciles the existing post instead of creating another', async () => {
  const deps = environment();
  let creates = 0;
  deps.fetch = async (_url, options) => {
    if (options.method === 'POST') { creates += 1; throw new Error('Response lost after remote commit'); }
    const legacyPost = { ...post, attributes: { ...post.attributes, content: { attachment: { url: legacyPngUrl } } } };
    return new Response(JSON.stringify({ data: { type: 'board' }, included: [legacyPost] }));
  };
  assert.equal((await call(createSubmissionHandler(deps))).json.ok, true);
  assert.equal((await call(createSubmissionHandler(deps))).json.ok, true);
  assert.equal(creates, 1);
});

test('unknown remote outcomes never trigger a blind second create, and eventually explain how to get help', async () => {
  const deps = environment();
  let creates = 0;
  deps.fetch = async (_url, options) => {
    if (options.method === 'POST') { creates += 1; throw new Error('Network interrupted'); }
    return new Response(JSON.stringify({ data: { type: 'board' }, included: [] }));
  };
  const first = await call(createSubmissionHandler(deps));
  assert.equal(first.statusCode, 202);
  assert.equal(first.json.retryable, true);
  deps.advance(16 * 60000);
  const later = await call(createSubmissionHandler(deps));
  assert.equal(later.statusCode, 202);
  assert.match(later.json.error, /선생님/);
  assert.equal(creates, 1);
});

test('reconciliation can find the stable work number if Padlet rewrites the attachment URL', async () => {
  const deps = environment();
  deps.fetch = async (_url, options) => {
    if (options.method === 'POST') return new Response('upstream failure', { status: 502 });
    return new Response(JSON.stringify({ included: [{ ...post, attributes: {
      ...post.attributes, content: { bodyHtml: `<p>작품 번호: ${base.id}</p>` },
    } }] }));
  };
  assert.equal((await call(createSubmissionHandler(deps))).json.ok, true);
});

test('a durable receipt write failure still returns remote success and recovers on a later request', async () => {
  const deps = environment();
  let failReceipt = true;
  deps.blob.beforePut = async (path, content) => {
    if (path === manifestPath && JSON.parse(content).state === 'published' && failReceipt) throw new Error('Storage interrupted');
  };
  assert.equal((await call(createSubmissionHandler(deps))).json.ok, true);
  failReceipt = false;
  deps.advance(60000);
  assert.equal((await call(createSubmissionHandler(deps))).json.ok, true);
  assert.equal(deps.calls.filter((entry) => entry.options.method === 'POST').length, 1);
  assert.equal(deps.blob.json(manifestPath).state, 'published');
});

test('a definite Padlet rate rejection allows retry only after its cooldown', async () => {
  const deps = environment();
  let creates = 0;
  deps.fetch = async () => {
    creates += 1;
    return creates === 1 ? new Response('{}', { status: 429 }) : new Response(JSON.stringify({ data: post }), { status: 201 });
  };
  assert.equal((await call(createSubmissionHandler(deps))).statusCode, 429);
  assert.equal((await call(createSubmissionHandler(deps))).statusCode, 429);
  assert.equal(creates, 1);
  deps.advance(60001);
  assert.equal((await call(createSubmissionHandler(deps))).json.ok, true);
  assert.equal(creates, 2);
});

test('moderation is returned honestly and remains available after a reload', async () => {
  const deps = environment({ fetch: async () => new Response(JSON.stringify({ data: {
    ...post, attributes: { ...post.attributes, status: 'pending_moderation' },
  } }), { status: 201 }) });
  const first = await call(createSubmissionHandler(deps));
  assert.equal(first.json.ok, true);
  assert.equal(first.json.moderation_pending, true);
  assert.equal((await call(createSubmissionHandler(deps))).json.moderation_pending, true);
});

test('invalid fields and malformed PNGs fail before any storage or remote call', async () => {
  const deps = environment();
  const invalidPng = Buffer.from(png);
  invalidPng[invalidPng.length - 1] ^= 1;
  const hugeHeader = Buffer.from(png);
  hugeHeader.writeUInt32BE(1000000000, 16);
  const variants = [
    { kind: 'drawing' }, { kind: '__proto__' }, { kind: null }, { kind: ['commission'] },
    { kind: 'commission', price: 99_999_999 }, { kind: 'commission', price: 260_000_001 },
    { kind: 'my_house', price: 99 }, { kind: 'my_house', price: 1_250_000_001 },
    { kind: 'earth_house', price: 1_250_000_001 }, { kind: 'spaceship', price: 1_199_999_999 }, { kind: 'spaceship', price: 1_800_000_001 },
    { id: '../../private/config' }, { author: '   ' }, { title: '가'.repeat(81) },
    { description: '가'.repeat(1001) }, { title: '안녕\0' }, { author: '이름\u0085' },
    { description: '설명\u009f' }, { price: 99 }, { price: 8000001 }, { price: 100.1 },
    { png_base64: Buffer.from('not a PNG').toString('base64') },
    { png_base64: invalidPng.toString('base64') }, { png_base64: hugeHeader.toString('base64') },
    { png_base64: png.subarray(0, 40).toString('base64') }, { png_base64: `${base.png_base64}\n` },
  ];
  for (const changed of variants) {
    const response = await call(createSubmissionHandler(deps), { ...base, ...changed });
    assert.equal(response.statusCode, 400, JSON.stringify(changed).slice(0, 80));
    assert.equal(response.json.retryable, false);
  }
  assert.equal(deps.blob.files.size, 0);
  assert.equal(deps.calls.length, 0);
});

test('oversized and invalid JSON requests are rejected without reading external services', async () => {
  const deps = environment();
  const handler = createSubmissionHandler(deps);
  assert.equal((await call(handler, base, { headers: { 'content-length': String(MAX_BODY_BYTES + 1) } })).statusCode, 413);
  assert.equal((await call(handler, '{broken', { parsed: false })).statusCode, 400);
  assert.equal((await call(handler, base, { headers: { 'content-type': 'text/plain' } })).statusCode, 415);
  assert.equal((await call(handler, { ...base, extra: 'x'.repeat(MAX_BODY_BYTES) })).statusCode, 413);
  assert.equal(deps.calls.length, 0);
});

test('origin and method checks prevent cross-site browser publishing, while native requests remain supported', async () => {
  const deps = environment();
  const handler = createSubmissionHandler(deps);
  assert.equal((await call(handler, base, { headers: { origin: 'https://other.example' } })).statusCode, 403);
  assert.equal((await call(handler, base, { method: 'GET' })).statusCode, 405);
  assert.equal(deps.blob.files.size, 0);
  const preflight = await call(handler, base, { method: 'OPTIONS', headers: { origin: PUBLIC_ORIGIN } });
  assert.equal(preflight.statusCode, 200);
  assert.equal(preflight.headers['access-control-allow-origin'], PUBLIC_ORIGIN);
  assert.equal((await call(handler)).json.ok, true);
});

test('missing configuration gives actionable Korean feedback without exposing secrets', async () => {
  const deps = environment({ env: { NODE_ENV: 'production' } });
  const response = await call(createSubmissionHandler(deps));
  assert.equal(response.statusCode, 503);
  assert.equal(response.json.retryable, true);
  assert.match(response.json.error, /선생님/);
  assert.equal(deps.calls.length, 0);
});

test('persistent request limits span function instances and allow a new minute', async () => {
  const deps = environment();
  deps.blob.setJson('padlet/rate/global.json', { window: Math.floor(deps.now() / 60000), count: 180 });
  const blocked = await call(createSubmissionHandler(deps));
  assert.equal(blocked.statusCode, 429);
  assert.equal(blocked.headers['retry-after'], '60');
  assert.equal(deps.calls.length, 0);
  assert.equal(deps.blob.files.has(manifestPath), false);
  deps.advance(60000);
  assert.equal((await call(createSubmissionHandler(deps))).json.ok, true);
  assert.equal([...deps.blob.files.keys()].some((pathname) => pathname.includes('203.0.113.40')), false);
});

test('an upload failure leaves a resumable preparation without a Padlet side effect', async () => {
  const deps = environment();
  let rejectImage = true;
  deps.blob.beforePut = async (pathname) => { if (pathname === pngPath && rejectImage) throw new Error('Storage unavailable'); };
  const failed = await call(createSubmissionHandler(deps));
  assert.equal(failed.statusCode, 503);
  assert.equal(deps.calls.length, 0);
  assert.equal(deps.blob.json(manifestPath).state, 'prepared');
  rejectImage = false;
  assert.equal((await call(createSubmissionHandler(deps))).json.ok, true);
});

test('image route supports HEAD and conditional reads but never exposes JSON manifests', async () => {
  const deps = environment();
  await call(createSubmissionHandler(deps));
  const handler = createImageHandler(deps);
  const head = await call(handler, {}, { method: 'HEAD', url: `/api/artwork-image?id=${base.id}` });
  assert.equal(head.statusCode, 200);
  assert.equal(head.bytes.length, 0);
  assert.equal(Number(head.headers['content-length']), png.length);
  const cached = await call(handler, {}, { method: 'GET', url: `/api/artwork-image?id=${base.id}`, headers: { 'if-none-match': head.headers.etag } });
  assert.equal(cached.statusCode, 304);
  assert.equal(cached.bytes.length, 0);
  for (const id of ['../../submissions/foo.json', `${base.id}.json`, 'f'.repeat(32)]) {
    assert.equal((await call(handler, {}, { method: 'GET', url: `/api/artwork-image?id=${encodeURIComponent(id)}` })).statusCode, 404);
  }
});

test('author text is escaped and never replaces the API account author identity', async () => {
  const deps = environment();
  assert.equal((await call(createSubmissionHandler(deps), { ...base, author: '<작가 & 친구>', description: '<script>alert(1)</script>' })).json.ok, true);
  const attributes = JSON.parse(deps.calls[0].options.body).data.attributes;
  assert.equal(attributes.author, undefined);
  assert.match(attributes.content.body, /&lt;작가 &amp; 친구&gt;/);
  assert.equal(attributes.content.body.includes('<script>'), false);
});
