'use strict';

const { createHash } = require('node:crypto');
const { PNG } = require('pngjs');

const BOARD_ID = 's025d52oqqhj786g8cry';
const BOARD_URL = `https://padlet.com/inkun02/padlet-${BOARD_ID}`;
const DRAWING_BOARD = { board_id: BOARD_ID, board_url: BOARD_URL };
const BUILDING_BOARD_ID = 's025ilggr7czshhrgkv2';
const BUILDING_BOARD = { board_id: BUILDING_BOARD_ID, board_url: `https://padlet.com/inkun02/padlet-${BUILDING_BOARD_ID}` };
const SPECIAL_GALLERIES = {
  wall: { prefix: 'PADLET_WALL', label: '담장 전시장', id: 's025pydws5qowdbbgrdp' },
  ship: { prefix: 'PADLET_SPACESHIP', label: '우주선 전시장', id: 's025pyexx3eepqe19zum' },
};
const PUBLIC_ORIGIN = 'https://rectangle-game-snowy.vercel.app';
const GAME_ORIGINS = [PUBLIC_ORIGIN, 'https://rectangle-game-iota.vercel.app'];
const MAX_BODY_BYTES = 3300000;
const MAX_PNG_BYTES = 2400000;
const REQUEST_TIMEOUT_MS = 15000;
const POSTING_GRACE_MS = 45000;
const ID_PATTERN = /^[a-f0-9]{32}$/;
const BOARD_ID_PATTERN = /^[a-zA-Z0-9]{16,22}$/;
const BUILDING_KINDS = new Set(['commission', 'my_house', 'earth_house']);
const PNG_SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
const DRAWING_PRICE = { minimum: 100, maximum: 8_000_000, label: '게임 내 그림 가격' };
const EXHIBITION_PRICE = { minimum: 0, maximum: 0 };
const PROJECT_PRICES = new Map([
  ['commission', { minimum: 100_000_000, maximum: 260_000_000, label: '게임 내 건물 가격' }],
  // 400 parts, each at most 600 × 400, at the highest custom rate and surcharges.
  ['my_house', { minimum: 100, maximum: 1_250_000_000, label: '게임 내 재료비' }],
  ['earth_house', { minimum: 100, maximum: 1_250_000_000, label: '게임 내 재료비' }],
  ['spaceship', { minimum: 1_200_000_000, maximum: 1_800_000_000, label: '게임 내 우주선 제작비' }],
]);

class InputError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

function dependencies(overrides) {
  const env = overrides.env || process.env;
  const blobAuth = env.BLOB_READ_WRITE_TOKEN ? { token: env.BLOB_READ_WRITE_TOKEN }
    : env.BLOB_STORE_ID ? { storeId: env.BLOB_STORE_ID } : null;
  return {
    blob: overrides.blob || require('@vercel/blob'),
    fetch: globalThis.fetch,
    env, blobAuth,
    now: Date.now,
    pause: (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds)),
    ...overrides,
  };
}

function header(request, name) {
  const value = request.headers?.[name.toLowerCase()];
  return typeof value === 'string' ? value : '';
}

function projectProductionOrigin(env) {
  const host = env.VERCEL_PROJECT_PRODUCTION_URL;
  if (!host) return null;
  const origin = `https://${host}`;
  if (GAME_ORIGINS.includes(origin)) return origin;
  // Vercel sets this to the project's own (possibly custom) production domain.
  // Only the server's exact system hostname is trusted, never the incoming Host.
  if (env.VERCEL === '1' && host.length <= 253 &&
      /^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/i.test(host)) return origin;
  return null;
}

function allowedOrigin(request, env) {
  const origin = header(request, 'origin');
  if (!origin) return true; // Native Godot clients do not send Origin; this is not authentication.
  const allowed = new Set(GAME_ORIGINS);
  const production = projectProductionOrigin(env);
  if (production) allowed.add(production);
  if (env.VERCEL_URL) allowed.add(`https://${env.VERCEL_URL}`);
  if (env.NODE_ENV !== 'production') {
    const host = header(request, 'host');
    if (/^(localhost|127\.0\.0\.1)(:\d+)?$/.test(host)) allowed.add(`http://${host}`);
  }
  return allowed.has(origin);
}

function publicOrigin(request, env) {
  const productionOrigin = projectProductionOrigin(env);
  if (productionOrigin) return productionOrigin;
  const requestOrigin = `https://${header(request, 'host')}`;
  return GAME_ORIGINS.includes(requestOrigin) ? requestOrigin : PUBLIC_ORIGIN;
}

function padletUrl(value) {
  try {
    const url = new URL(value);
    if (url.origin === 'https://padlet.com' && !url.username && !url.password) return url;
  } catch { /* Missing and invalid Padlet URLs have no destination. */ }
  return null;
}

function boardDestination(boardId, boardUrl) {
  if (typeof boardId !== 'string' || !BOARD_ID_PATTERN.test(boardId)) return null;
  const url = padletUrl(boardUrl);
  const slug = url?.pathname.split('/').filter(Boolean).at(-1);
  if (slug !== boardId && !slug?.endsWith(`-${boardId}`)) return null;
  return { board_id: boardId, board_url: url.href };
}

function specialGallery(kind) {
  if (kind === 'wall') return SPECIAL_GALLERIES.wall;
  if (kind === 'spaceship' || kind === 'ship_exhibit') return SPECIAL_GALLERIES.ship;
  return null;
}

function submissionBoard(deps, submission) {
  const gallery = specialGallery(submission.kind);
  if (gallery) {
    const env = deps.env;
    const id = env[`${gallery.prefix}_BOARD_ID`]?.trim();
    const url = env[`${gallery.prefix}_BOARD_URL`]?.trim();
    const board = id === undefined && url === undefined
      ? boardDestination(gallery.id, `https://padlet.com/inkun02/padlet-${gallery.id}`) : boardDestination(id, url);
    const other = gallery === SPECIAL_GALLERIES.wall ? SPECIAL_GALLERIES.ship : SPECIAL_GALLERIES.wall;
    const reserved = [BOARD_ID, BUILDING_BOARD_ID, env.PADLET_BUILDING_BOARD_ID?.trim(), other.id, env[`${other.prefix}_BOARD_ID`]?.trim()];
    return board && !reserved.includes(board.board_id) ? board : null;
  }
  if (!BUILDING_KINDS.has(submission.kind)) return DRAWING_BOARD;
  const { PADLET_BUILDING_BOARD_ID: boardId, PADLET_BUILDING_BOARD_URL: boardUrl } = deps.env;
  if (boardId === undefined && boardUrl === undefined) return BUILDING_BOARD;
  const board = boardDestination(boardId?.trim(), boardUrl?.trim());
  const reserved = [BOARD_ID, ...Object.values(SPECIAL_GALLERIES).flatMap((item) => [item.id, deps.env[`${item.prefix}_BOARD_ID`]?.trim()])];
  return board && !reserved.includes(board.board_id) ? board : null;
}

function padletBoardApi(boardId) {
  return `https://api.padlet.dev/v1/boards/${boardId}`;
}

function missingBoard(kind) {
  const gallery = specialGallery(kind)?.label ?? '건축물 전시관';
  return fail(`${gallery} 주소를 확인해야 해요. 저장한 작품은 설정을 고친 뒤 다시 보낼 수 있어요.`, false, 503, 'configuration');
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

function fail(message, retryable = true, status = 503, code) {
  return { status, body: { ok: false, error: message, retryable, ...(code ? { code } : {}) } };
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
      access: 'private', useCache: false, ...deps.blobAuth,
      abortSignal: AbortSignal.timeout(4000),
    });
    const previous = stored ? JSON.parse((await boundedStream(stored.stream, 1024)).toString('utf8')) : null;
    const count = previous?.window === window ? previous.count : 0;
    if (!Number.isInteger(count) || count < 0) throw new Error('Invalid request counter');
    if (count >= maximum) return false;
    try {
      await deps.blob.put(pathname, JSON.stringify({ window, count: count + 1 }), {
        access: 'private', ...deps.blobAuth, contentType: 'application/json',
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
  const kind = raw.kind;
  const projectPrice = PROJECT_PRICES.get(kind);
  const exhibition = kind === 'drawing' || kind === 'wall' || kind === 'ship_exhibit';
  if (kind !== undefined && !exhibition && !projectPrice) throw new InputError('작품 종류를 확인해 주세요.');
  const work = kind === 'wall' ? '담장' : specialGallery(kind) === SPECIAL_GALLERIES.ship ? '우주선' : projectPrice ? '건물' : '그림';
  if (typeof raw.id !== 'string' || !ID_PATTERN.test(raw.id)) {
    throw new InputError('작품을 확인할 수 없어요. 게임에서 작품을 다시 열어 주세요.');
  }
  const author = textField(raw.author, 40, '작성자 이름');
  const nameLabel = kind === 'earth_house' ? '집 이름' : kind === 'spaceship' ? '우주선 이름' : `${work} 제목`;
  const title = textField(raw.title, 80, nameLabel);
  const description = textField(raw.description, 1000, `${work} 설명`, true);
  const price = exhibition ? EXHIBITION_PRICE : projectPrice ?? DRAWING_PRICE;
  if (!Number.isSafeInteger(raw.price) || raw.price < price.minimum || raw.price > price.maximum) {
    if (exhibition) throw new InputError(`전시할 ${work} 정보를 다시 확인해 주세요.`);
    throw new InputError(projectPrice ? '작품 금액이 올바르지 않아요. 게임 화면에서 다시 확인해 주세요.' :
      '그림 가격이 올바르지 않아요. 판매 화면에서 다시 확인해 주세요.');
  }
  const encoded = raw.png_base64;
  if (typeof encoded !== 'string' || !encoded || encoded.length > Math.ceil(MAX_PNG_BYTES / 3) * 4 ||
      encoded.length % 4 !== 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(encoded)) {
    throw new InputError('작품의 PNG 파일을 다시 만들어 주세요.');
  }
  const png = Buffer.from(encoded, 'base64');
  if (png.length < 33 || png.length > MAX_PNG_BYTES || png.toString('base64') !== encoded ||
      !png.subarray(0, 8).equals(PNG_SIGNATURE) || png.readUInt32BE(8) !== 13 ||
      png.toString('ascii', 12, 16) !== 'IHDR' || png.readUInt32BE(16) !== 960 || png.readUInt32BE(20) !== 600) {
    throw new InputError(`960×600 크기의 PNG가 필요해요. ${work}을 다시 저장해 주세요.`);
  }
  // Check dimensions before decompression, then verify CRCs and the complete PNG stream.
  try {
    const decoded = PNG.sync.read(png, { checkCRC: true });
    if (decoded.width !== 960 || decoded.height !== 600 || decoded.data.length !== 960 * 600 * 4) {
      throw new Error('Unexpected decoded dimensions');
    }
  } catch {
    throw new InputError('작품 파일이 손상되었어요. PNG를 다시 저장해 주세요.');
  }
  const imageHash = hash(png);
  const payload = [raw.id, author, title, description, raw.price, imageHash];
  // Preserve the payload hash already stored for drawing submissions.
  if (kind !== undefined) payload.push(kind);
  const payloadHash = hash(JSON.stringify(payload));
  return { id: raw.id, author, title, description, price: raw.price, png, imageHash, payloadHash, kind };
}

async function readManifest(deps, id) {
  const stored = await deps.blob.get(manifestPath(id), {
    access: 'private', useCache: false, ...deps.blobAuth,
    abortSignal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  if (!stored) return null;
  const value = JSON.parse((await boundedStream(stored.stream, 16384)).toString('utf8'));
  if (value.version !== 1 || value.id !== id || typeof value.payload_hash !== 'string' || !stored.blob.etag) {
    throw new Error('Invalid submission record');
  }
  if ((value.board_id !== undefined || value.board_url !== undefined) && !boardDestination(value.board_id, value.board_url)) {
    throw new Error('Invalid submission board');
  }
  return { value, etag: stored.blob.etag };
}

async function writeManifest(deps, value, etag) {
  const result = await deps.blob.put(manifestPath(value.id), JSON.stringify(value), {
    access: 'private', ...deps.blobAuth,
    addRandomSuffix: false, allowOverwrite: Boolean(etag), ...(etag ? { ifMatch: etag } : {}),
    contentType: 'application/json', cacheControlMaxAge: 60,
    abortSignal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  return { value, etag: result.etag };
}

async function ensureImage(deps, submission) {
  try {
    await deps.blob.put(imagePath(submission.id), submission.png, {
      access: 'private', ...deps.blobAuth,
      addRandomSuffix: false, allowOverwrite: false, contentType: 'image/png',
      abortSignal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
  } catch (error) {
    // The upload may have succeeded before its response was lost, or a concurrent request won.
    const existing = await deps.blob.get(imagePath(submission.id), {
      access: 'private', useCache: false, ...deps.blobAuth,
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
  const projectPrice = PROJECT_PRICES.get(submission.kind);
  const descriptionLabel = submission.kind === 'wall' ? '담장 설명' : specialGallery(submission.kind) === SPECIAL_GALLERIES.ship ? '우주선 설명' : projectPrice ? '건물 설명' : '그림 설명';
  const body = [`작성자: ${escapeHtml(submission.author)}`, `${descriptionLabel}: ${escapeHtml(submission.description)}`];
  if (submission.kind !== 'drawing' && submission.kind !== 'wall' && submission.kind !== 'ship_exhibit') {
    body.push(`${(projectPrice ?? DRAWING_PRICE).label}: ${submission.price.toLocaleString('en-US')}원`);
  }
  return {
    data: {
      type: 'post',
      attributes: {
        content: {
          subject: `${submission.title} · ${submission.author}`,
          body: body.join('\n\n'),
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

function published(record) {
  return {
    status: 200,
    body: { ok: true, post_url: record.post_url || record.board_url || BOARD_URL, moderation_pending: record.post_status === 'pending_moderation' },
  };
}

async function recordSuccess(deps, current, post) {
  let postUrl = padletUrl(post.attributes?.webUrl?.live)?.href;
  // A dedicated exhibition stays on its own board even if Padlet returns a different link format.
  if (specialGallery(current.value.kind) && !postUrl?.startsWith(`${current.value.board_url}/`)) postUrl = current.value.board_url;
  const value = {
    ...current.value, state: 'published', post_id: post.id, post_url: postUrl || current.value.board_url || BOARD_URL,
    post_status: post.attributes?.status || 'approved', updated_at: deps.now(),
  };
  try { await writeManifest(deps, value, current.etag); } catch {
    // The remote post is the durable receipt. A later retry reconciles it without creating another post.
  }
  return published(value);
}

async function reconcile(deps, current) {
  try {
    // Legacy submissions with an uncertain outcome could only have reached the drawing board.
    const response = await deps.fetch(`${padletBoardApi(current.value.board_id || BOARD_ID)}?include=posts`, {
      method: 'GET', headers: padletHeaders(deps), signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    if (!response.ok) return pending(deps, current.value);
    const board = await response.json();
    const posts = Array.isArray(board.included) ? board.included : [];
    const attemptedUrl = current.value.attachment_url;
    const attachmentUrls = attemptedUrl ? [attemptedUrl] : GAME_ORIGINS.map((origin) => imageUrl(current.value.id, origin));
    const legacyMarker = `작품 번호: ${current.value.id}`;
    const match = posts.find((post) => post.type === 'post' && typeof post.id === 'string' && (
      attachmentUrls.includes(post.attributes?.content?.attachment?.url) ||
      (!attemptedUrl && typeof post.attributes?.content?.bodyHtml === 'string' &&
        post.attributes.content.bodyHtml.includes(legacyMarker))
    ));
    if (match) return await recordSuccess(deps, current, match);
  } catch { /* A failed lookup cannot prove that the original create failed. */ }
  return pending(deps, current.value);
}

async function processSubmission(deps, submission, origin) {
  let current = await readManifest(deps, submission.id);
  if (!current) {
    const board = submissionBoard(deps, submission);
    if (!board) return missingBoard(submission.kind);
    const value = {
      version: 1, id: submission.id, payload_hash: submission.payloadHash, ...board,
      ...(specialGallery(submission.kind) ? { kind: submission.kind } : {}),
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
    if (!current.value.board_id && ['wall', 'ship_exhibit'].includes(submission.kind)) return missingBoard(submission.kind);
    if (current.value.state === 'posting' && deps.now() - current.value.updated_at < POSTING_GRACE_MS) return pending(deps, current.value);
    return reconcile(deps, current);
  }
  if (!['prepared', 'rejected'].includes(current.value.state)) throw new Error('Invalid submission state');
  if (current.value.retry_after > deps.now()) {
    return fail('패들릿에 등록 요청이 많아요. 1분 뒤에 다시 시도해 주세요.', true, 429);
  }

  // Prepared and definitely rejected legacy submissions have no remote post to reconcile.
  const migrateUnpostedShip = submission.kind === 'spaceship' && !current.value.kind;
  const board = current.value.board_id && !migrateUnpostedShip ? { board_id: current.value.board_id, board_url: current.value.board_url }
    : submissionBoard(deps, submission);
  if (!board) return missingBoard(submission.kind);
  await ensureImage(deps, submission);
  try {
    current = await writeManifest(deps, {
      ...current.value, ...board, state: 'posting', updated_at: deps.now(), retry_after: 0,
      ...(specialGallery(submission.kind) ? { kind: submission.kind } : {}),
      attachment_url: imageUrl(submission.id, origin),
    }, current.etag);
  } catch {
    const winner = await readManifest(deps, submission.id);
    if (winner?.value.state === 'published') return published(winner.value);
    return pending(deps, current.value);
  }

  try {
    const response = await deps.fetch(`${padletBoardApi(board.board_id)}/posts`, {
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
      if (rateLimited) return fail('패들릿에 등록 요청이 많아요. 1분 뒤에 다시 시도해 주세요.', true, 429);
      return fail('패들릿이 등록 요청을 거절했어요. 선생님이 전시관 주소와 게시 권한을 확인한 뒤 다시 보내 주세요.', false, 502, 'configuration');
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
    if (!deps.env.PADLET_API_KEY || !deps.blobAuth) {
      return sendJson(response, 503, {
        ok: false, error: '전시관 연결 설정이 필요해요. 작품은 저장했어요. 선생님께 알려 주세요.', retryable: false, code: 'configuration',
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
    if (!deps.blobAuth) return sendJson(response, 503, { ok: false, error: '그림 보관함을 준비 중이에요.' });
    try {
      const stored = await deps.blob.get(imagePath(id), {
        access: 'private', ...deps.blobAuth,
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
