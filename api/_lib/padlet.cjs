'use strict';

const { createHash } = require('node:crypto');
const { PNG } = require('pngjs');

const BOARD_ID = 's025d52oqqhj786g8cry';
const BOARD_URL = `https://padlet.com/inkun02/padlet-${BOARD_ID}`;
const PUBLIC_ORIGIN = 'https://rectangle-game-iota.vercel.app';
const GAME_ORIGINS = [PUBLIC_ORIGIN, 'https://rectangle-game-snowy.vercel.app'];
const PADLET_BOARD_API = `https://api.padlet.dev/v1/boards/${BOARD_ID}`;
const MAX_BODY_BYTES = 3300000;
const MAX_PNG_BYTES = 2400000;
const REQUEST_TIMEOUT_MS = 15000;
const POSTING_GRACE_MS = 45000;
const ID_PATTERN = /^[a-f0-9]{32}$/;
const PNG_SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

class InputError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

function dependencies(overrides) {
  return {
    blob: overrides.blob || require('@vercel/blob'),
    fetch: globalThis.fetch,
    env: process.env,
    now: Date.now,
    pause: (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds)),
    ...overrides,
  };
}

function header(request, name) {
  const value = request.headers?.[name.toLowerCase()];
  return typeof value === 'string' ? value : '';
}

function allowedOrigin(request, env) {
  const origin = header(request, 'origin');
  if (!origin) return true; // Native Godot clients do not send Origin; this is not authentication.
  const allowed = new Set(GAME_ORIGINS);
  if (env.VERCEL_URL) allowed.add(`https://${env.VERCEL_URL}`);
  if (env.NODE_ENV !== 'production') {
    const host = header(request, 'host');
    if (/^(localhost|127\.0\.0\.1)(:\d+)?$/.test(host)) allowed.add(`http://${host}`);
  }
  return allowed.has(origin);
}

function publicOrigin(request, env) {
  const productionOrigin = `https://${env.VERCEL_PROJECT_PRODUCTION_URL}`;
  if (GAME_ORIGINS.includes(productionOrigin)) return productionOrigin;
  const requestOrigin = `https://${header(request, 'host')}`;
  return GAME_ORIGINS.includes(requestOrigin) ? requestOrigin : PUBLIC_ORIGIN;
}

function sendJson(response, status, data, origin = '') {
  response.setHeader('Content-Type', 'application/json; charset=utf-8');
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('X-Content-Type-Options', 'nosniff');
  if (origin) {
    response.setHeader('Access-Control-Allow-Origin', origin);
    response.setHeader('Vary', 'Origin');
  }
  response.statusCode = status;
  response.end(JSON.stringify(data));
}

function fail(message, retryable = true, status = 503) {
  return { status, body: { ok: false, error: message, retryable } };
}

function pending(deps, record) {
  const needsHelp = record && deps.now() - record.updated_at >= 15 * 60000;
  return fail(needsHelp ? '등록 결과를 확인할 수 없어요. 패들릿 보드에서 그림을 확인한 뒤 선생님께 알려 주세요.' :
    '패들릿 등록 결과를 확인하고 있어요. 잠시 뒤 다시 확인해 주세요.', true, 202);
}

function manifestPath(id) {
  return `padlet/submissions/${id}.json`;
}

function imagePath(id) {
  return `padlet/artworks/${id}.png`;
}

function imageUrl(id, origin) {
  return `${origin}/api/artwork-image?id=${id}`;
}

function hash(value) {
  return createHash('sha256').update(value).digest('hex');
}

async function consumeRateBucket(deps, name, maximum) {
  const pathname = `padlet/rate/${name}.json`;
  const window = Math.floor(deps.now() / 60000);
  const started = Date.now();
  for (let attempt = 0; attempt < 8 && Date.now() - started < 5000; attempt += 1) {
    const stored = await deps.blob.get(pathname, {
      access: 'private', useCache: false, token: deps.env.BLOB_READ_WRITE_TOKEN,
      abortSignal: AbortSignal.timeout(4000),
    });
    const previous = stored ? JSON.parse((await boundedStream(stored.stream, 1024)).toString('utf8')) : null;
    const count = previous?.window === window ? previous.count : 0;
    if (!Number.isInteger(count) || count < 0) throw new Error('Invalid request counter');
    if (count >= maximum) return false;
    try {
      await deps.blob.put(pathname, JSON.stringify({ window, count: count + 1 }), {
        access: 'private', token: deps.env.BLOB_READ_WRITE_TOKEN, contentType: 'application/json',
        addRandomSuffix: false, allowOverwrite: Boolean(stored),
        ...(stored ? { ifMatch: stored.blob.etag } : {}), cacheControlMaxAge: 60,
        abortSignal: AbortSignal.timeout(4000),
      });
      return true;
    } catch {
      // Another function may have reserved this slot. Retry from a consistent read.
      await deps.pause(15 + attempt * 10);
    }
  }
  return false;
}

async function allowRequestRate(deps, request) {
  // Vercel supplies these client IP headers; do not store the address itself.
  const ip = header(request, 'x-vercel-forwarded-for') || header(request, 'x-forwarded-for') ||
    request.socket?.remoteAddress || 'unknown';
  const clientKey = hash(`${deps.env.PADLET_API_KEY}\0${ip}`).slice(0, 32);
  if (!await consumeRateBucket(deps, `client-${clientKey}`, 120)) return false;
  return consumeRateBucket(deps, 'global', 180);
}

async function boundedStream(stream, maximum) {
  const chunks = [];
  let total = 0;
  for await (const chunk of stream) {
    const bytes = Buffer.from(chunk);
    total += bytes.length;
    if (total > maximum) throw new InputError('파일 용량이 너무 커요.', 413);
    chunks.push(bytes);
  }
  return Buffer.concat(chunks, total);
}

async function readBody(request) {
  if (!/^application\/json(?:\s*;|$)/i.test(header(request, 'content-type'))) {
    throw new InputError('그림 등록 정보를 다시 보내 주세요.', 415);
  }
  const declaredLength = Number(header(request, 'content-length'));
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) {
    throw new InputError('그림 파일 용량이 너무 커요.', 413);
  }
  let raw = request.body;
  if (raw === undefined) raw = await boundedStream(request, MAX_BODY_BYTES);
  if (Buffer.isBuffer(raw)) raw = raw.toString('utf8');
  if (typeof raw === 'string') {
    if (Buffer.byteLength(raw) > MAX_BODY_BYTES) throw new InputError('그림 파일 용량이 너무 커요.', 413);
    try { raw = JSON.parse(raw); } catch { throw new InputError('그림 등록 정보를 읽을 수 없어요.'); }
  } else if (raw && typeof raw === 'object') {
    if (Buffer.byteLength(JSON.stringify(raw)) > MAX_BODY_BYTES) {
      throw new InputError('그림 파일 용량이 너무 커요.', 413);
    }
  }
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new InputError('그림 등록 정보를 다시 확인해 주세요.');
  }
  return raw;
}

function textField(value, maximum, label, multiline = false) {
  if (typeof value !== 'string') throw new InputError(`${label}을 입력해 주세요.`);
  const normalized = value.trim().normalize('NFC');
  if (!normalized || [...normalized].length > maximum) {
    throw new InputError(`${label}은 1~${maximum}자로 입력해 주세요.`);
  }
  const controls = multiline ? /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]/ : /[\x00-\x1F\x7F-\x9F]/;
  if (controls.test(normalized)) throw new InputError(`${label}에 사용할 수 없는 글자가 있어요.`);
  return normalized;
}

function validateSubmission(raw) {
  if (typeof raw.id !== 'string' || !ID_PATTERN.test(raw.id)) {
    throw new InputError('작품 번호가 올바르지 않아요. 그림을 다시 열어 주세요.');
  }
  const author = textField(raw.author, 40, '사용자 이름');
  const title = textField(raw.title, 80, '그림 제목');
  const description = textField(raw.description, 1000, '그림 설명', true);
  if (!Number.isSafeInteger(raw.price) || raw.price < 100 || raw.price > 8000000) {
    throw new InputError('그림 가격이 올바르지 않아요. 판매 화면에서 다시 확인해 주세요.');
  }
  const encoded = raw.png_base64;
  if (typeof encoded !== 'string' || !encoded || encoded.length > Math.ceil(MAX_PNG_BYTES / 3) * 4 ||
      encoded.length % 4 !== 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(encoded)) {
    throw new InputError('PNG 그림 파일을 다시 만들어 주세요.');
  }
  const png = Buffer.from(encoded, 'base64');
  if (png.length < 33 || png.length > MAX_PNG_BYTES || png.toString('base64') !== encoded ||
      !png.subarray(0, 8).equals(PNG_SIGNATURE) || png.readUInt32BE(8) !== 13 ||
      png.toString('ascii', 12, 16) !== 'IHDR' || png.readUInt32BE(16) !== 960 || png.readUInt32BE(20) !== 600) {
    throw new InputError('960×600 크기의 PNG 그림이 필요해요. 그림을 다시 저장해 주세요.');
  }
  // Check dimensions before decompression, then verify CRCs and the complete PNG stream.
  try {
    const decoded = PNG.sync.read(png, { checkCRC: true });
    if (decoded.width !== 960 || decoded.height !== 600 || decoded.data.length !== 960 * 600 * 4) {
      throw new Error('Unexpected decoded dimensions');
    }
  } catch {
    throw new InputError('그림 파일이 손상되었어요. PNG를 다시 저장해 주세요.');
  }
  const imageHash = hash(png);
  const payloadHash = hash(JSON.stringify([raw.id, author, title, description, raw.price, imageHash]));
  return { id: raw.id, author, title, description, price: raw.price, png, imageHash, payloadHash };
}

async function readManifest(deps, id) {
  const stored = await deps.blob.get(manifestPath(id), {
    access: 'private', useCache: false, token: deps.env.BLOB_READ_WRITE_TOKEN,
    abortSignal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  if (!stored) return null;
  const value = JSON.parse((await boundedStream(stored.stream, 16384)).toString('utf8'));
  if (value.version !== 1 || value.id !== id || typeof value.payload_hash !== 'string' || !stored.blob.etag) {
    throw new Error('Invalid submission record');
  }
  return { value, etag: stored.blob.etag };
}

async function writeManifest(deps, value, etag) {
  const result = await deps.blob.put(manifestPath(value.id), JSON.stringify(value), {
    access: 'private', token: deps.env.BLOB_READ_WRITE_TOKEN,
    addRandomSuffix: false, allowOverwrite: Boolean(etag), ...(etag ? { ifMatch: etag } : {}),
    contentType: 'application/json', cacheControlMaxAge: 60,
    abortSignal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  return { value, etag: result.etag };
}

async function ensureImage(deps, submission) {
  try {
    await deps.blob.put(imagePath(submission.id), submission.png, {
      access: 'private', token: deps.env.BLOB_READ_WRITE_TOKEN,
      addRandomSuffix: false, allowOverwrite: false, contentType: 'image/png',
      abortSignal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
  } catch (error) {
    // The upload may have succeeded before its response was lost, or a concurrent request won.
    const existing = await deps.blob.get(imagePath(submission.id), {
      access: 'private', useCache: false, token: deps.env.BLOB_READ_WRITE_TOKEN,
      abortSignal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    if (!existing || hash(await boundedStream(existing.stream, MAX_PNG_BYTES)) !== submission.imageHash) throw error;
  }
}

function escapeHtml(value) {
  return value.replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character]);
}

function createPadletBody(submission, origin = PUBLIC_ORIGIN) {
  return {
    data: {
      type: 'post',
      attributes: {
        content: {
          subject: submission.title,
          body: `사용자 이름: ${escapeHtml(submission.author)}\n\n그림 설명: ${escapeHtml(submission.description)}\n\n게임 내 그림 가격: ${submission.price.toLocaleString('en-US')}원\n작품 번호: ${submission.id}`,
          attachment: { url: imageUrl(submission.id, origin), caption: submission.title },
        },
      },
    },
  };
}

function padletHeaders(deps) {
  return {
    'X-API-KEY': deps.env.PADLET_API_KEY,
    Accept: 'application/vnd.api+json',
    'Content-Type': 'application/vnd.api+json',
  };
}

function postUrl(post) {
  const value = post?.attributes?.webUrl?.live;
  try {
    const parsed = new URL(value);
    if (parsed.protocol === 'https:' && parsed.hostname === 'padlet.com') return parsed.href;
  } catch { /* Fall back to the fixed board if Padlet omits a permalink. */ }
  return BOARD_URL;
}

function published(record) {
  return {
    status: 200,
    body: { ok: true, post_url: record.post_url || BOARD_URL, moderation_pending: record.post_status === 'pending_moderation' },
  };
}

async function recordSuccess(deps, current, post) {
  const value = {
    ...current.value, state: 'published', post_id: post.id, post_url: postUrl(post),
    post_status: post.attributes?.status || 'approved', updated_at: deps.now(),
  };
  try { await writeManifest(deps, value, current.etag); } catch {
    // The remote post is the durable receipt. A later retry reconciles it without creating another post.
  }
  return published(value);
}

async function reconcile(deps, current) {
  try {
    const response = await deps.fetch(`${PADLET_BOARD_API}?include=posts`, {
      method: 'GET', headers: padletHeaders(deps), signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    if (!response.ok) return pending(deps, current.value);
    const board = await response.json();
    const posts = Array.isArray(board.included) ? board.included : [];
    const marker = `작품 번호: ${current.value.id}`;
    const attachmentUrls = GAME_ORIGINS.map((origin) => imageUrl(current.value.id, origin));
    const match = posts.find((post) => post.type === 'post' && typeof post.id === 'string' && (
      attachmentUrls.includes(post.attributes?.content?.attachment?.url) ||
      (typeof post.attributes?.content?.bodyHtml === 'string' && post.attributes.content.bodyHtml.includes(marker))
    ));
    if (match) return await recordSuccess(deps, current, match);
  } catch { /* A failed lookup cannot prove that the original create failed. */ }
  return pending(deps, current.value);
}

async function processSubmission(deps, submission, origin) {
  let current = await readManifest(deps, submission.id);
  if (!current) {
    const value = {
      version: 1, id: submission.id, payload_hash: submission.payloadHash,
      state: 'prepared', created_at: deps.now(), updated_at: deps.now(),
    };
    try { current = await writeManifest(deps, value); } catch (error) {
      current = await readManifest(deps, submission.id);
      if (!current) throw error;
    }
  }
  if (current.value.payload_hash !== submission.payloadHash) {
    return fail('이미 등록을 시작한 작품의 정보가 달라졌어요. 저장된 작품 정보로 다시 시도해 주세요.', false, 409);
  }
  if (current.value.state === 'published') return published(current.value);
  if (current.value.state === 'unknown' || current.value.state === 'posting') {
    if (current.value.state === 'posting' && deps.now() - current.value.updated_at < POSTING_GRACE_MS) return pending(deps, current.value);
    return reconcile(deps, current);
  }
  if (!['prepared', 'rejected'].includes(current.value.state)) throw new Error('Invalid submission state');
  if (current.value.retry_after > deps.now()) {
    return fail('패들릿에 등록 요청이 많아요. 1분 뒤에 다시 시도해 주세요.', true, 429);
  }

  await ensureImage(deps, submission);
  try {
    current = await writeManifest(deps, {
      ...current.value, state: 'posting', updated_at: deps.now(), retry_after: 0,
    }, current.etag);
  } catch {
    const winner = await readManifest(deps, submission.id);
    if (winner?.value.state === 'published') return published(winner.value);
    return pending(deps, current.value);
  }

  try {
    const response = await deps.fetch(`${PADLET_BOARD_API}/posts`, {
      method: 'POST', headers: padletHeaders(deps), body: JSON.stringify(createPadletBody(submission, origin)),
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    if (response.status === 201) {
      const data = await response.json();
      if (data.data?.type === 'post' && typeof data.data.id === 'string' && data.data.id) {
        return recordSuccess(deps, current, data.data);
      }
    } else if ([400, 401, 403, 404, 422, 429].includes(response.status)) {
      const rateLimited = response.status === 429;
      await writeManifest(deps, {
        ...current.value, state: 'rejected', updated_at: deps.now(),
        retry_after: rateLimited ? deps.now() + 60000 : 0,
      }, current.etag);
      return fail(rateLimited ? '패들릿에 등록 요청이 많아요. 1분 뒤에 다시 시도해 주세요.' :
        '패들릿에서 등록을 허용하지 않았어요. 선생님께 패들릿 연결을 확인해 달라고 해 주세요.', true, rateLimited ? 429 : 502);
    }
  } catch { /* Timeouts and lost responses may already have created a post. */ }

  try {
    current = await writeManifest(deps, { ...current.value, state: 'unknown', updated_at: deps.now() }, current.etag);
  } catch { /* Keep posting state: it is also reconciled, never blindly re-posted. */ }
  return reconcile(deps, current);
}

function createSubmissionHandler(overrides = {}) {
  const deps = dependencies(overrides);
  return async (request, response) => {
    if (!allowedOrigin(request, deps.env)) {
      return sendJson(response, 403, { ok: false, error: '게임 화면에서 그림을 등록해 주세요.', retryable: false });
    }
    const origin = header(request, 'origin');
    if (request.method === 'OPTIONS') {
      response.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
      response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
      return sendJson(response, 200, { ok: true }, origin);
    }
    if (request.method !== 'POST') {
      response.setHeader('Allow', 'POST, OPTIONS');
      return sendJson(response, 405, { ok: false, error: '그림 등록 버튼을 눌러 주세요.', retryable: false }, origin);
    }
    if (!deps.env.PADLET_API_KEY || !deps.env.BLOB_READ_WRITE_TOKEN) {
      return sendJson(response, 503, {
        ok: false, error: '패들릿 연결을 준비 중이에요. 그림은 저장되어 있어요. 선생님께 알려 주세요.', retryable: true,
      }, origin);
    }
    try {
      const submission = validateSubmission(await readBody(request));
      if (!await allowRequestRate(deps, request)) {
        response.setHeader('Retry-After', '60');
        return sendJson(response, 429, {
          ok: false, error: '등록 요청이 많아요. 1분 뒤에 다시 시도해 주세요.', retryable: true,
        }, origin);
      }
      const result = await processSubmission(deps, submission, publicOrigin(request, deps.env));
      return sendJson(response, result.status, result.body, origin);
    } catch (error) {
      const result = error instanceof InputError ? fail(error.message, false, error.status) :
        fail('그림을 보내지 못했어요. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.');
      return sendJson(response, result.status, result.body, origin);
    }
  };
}

function createImageHandler(overrides = {}) {
  const deps = dependencies(overrides);
  return async (request, response) => {
    if (!['GET', 'HEAD'].includes(request.method)) {
      response.setHeader('Allow', 'GET, HEAD');
      return sendJson(response, 405, { ok: false, error: '그림을 열 수 없어요.', retryable: false });
    }
    const id = new URL(request.url, PUBLIC_ORIGIN).searchParams.get('id');
    if (!id || !ID_PATTERN.test(id)) return sendJson(response, 404, { ok: false, error: '그림을 찾을 수 없어요.' });
    if (!deps.env.BLOB_READ_WRITE_TOKEN) return sendJson(response, 503, { ok: false, error: '그림 보관함을 준비 중이에요.' });
    try {
      const stored = await deps.blob.get(imagePath(id), {
        access: 'private', token: deps.env.BLOB_READ_WRITE_TOKEN,
        abortSignal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });
      if (!stored) return sendJson(response, 404, { ok: false, error: '그림을 찾을 수 없어요.' });
      const bytes = await boundedStream(stored.stream, MAX_PNG_BYTES);
      response.setHeader('Content-Type', 'image/png');
      response.setHeader('Content-Length', String(bytes.length));
      response.setHeader('Content-Disposition', `inline; filename="quadrilateral-${id}.png"`);
      response.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
      response.setHeader('X-Content-Type-Options', 'nosniff');
      response.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
      response.setHeader('Access-Control-Allow-Origin', '*');
      if (stored.blob.etag) response.setHeader('ETag', stored.blob.etag);
      if (header(request, 'if-none-match') && header(request, 'if-none-match') === stored.blob.etag) {
        response.statusCode = 304;
        response.removeHeader('Content-Length');
        return response.end();
      }
      response.statusCode = 200;
      return response.end(request.method === 'HEAD' ? undefined : bytes);
    } catch {
      return sendJson(response, 503, { ok: false, error: '그림을 불러오지 못했어요. 잠시 뒤 다시 열어 주세요.' });
    }
  };
}

module.exports = {
  BOARD_ID, BOARD_URL, PUBLIC_ORIGIN, MAX_BODY_BYTES, MAX_PNG_BYTES,
  createSubmissionHandler, createImageHandler, validateSubmission, createPadletBody,
};
