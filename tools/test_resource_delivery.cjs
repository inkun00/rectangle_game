'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const zlib = require('node:zlib');
const source = fs.readFileSync(path.join(__dirname, '../web/compressed_assets.js'), 'utf8');
const payload = Buffer.from('identical game content');
const url = 'feature-opening-aaaaaaaaaaaa.pck';
function setup(fetch, extra = {}) {
  const context = {fetch, Headers, Response, DecompressionStream, Uint8Array, AbortController,
    triangleArtUngzip: data => zlib.gunzipSync(data),
    QUAD_RESOURCE_PACKS: {version:1, packs:{opening:{url, bytes:payload.length, sha256:'a'.repeat(64)}}}, ...extra};
  vm.runInNewContext(source, context);
  return context;
}
const decoded = () => new Response(payload, {headers:{'Content-Encoding':'br'}});
const request = context => new Promise(resolve => context.QuadResourcePacks.download('opening', (...args) => resolve(args)));

test('startup never downloads an optional pack', () => {
  const calls = [];
  setup((...args) => {calls.push(args);});
  assert.equal(calls.length, 0);
});
test('Brotli uses the browser-decoded bytes without a second decompression', async () => {
  const calls = [];
  const context = setup(async name => {calls.push(name);return decoded();});
  const response = await context.triangleArtFetchCompressed(url, payload.length);
  assert.deepEqual(Buffer.from(await response.arrayBuffer()), payload);
  assert.equal(response.headers.get('Content-Encoding'), null);
  assert.equal(Number(response.headers.get('Content-Length')), payload.length);
  assert.deepEqual(calls, [url+'.br']);
});
test('a static host without Brotli headers falls back to gzip', async () => {
  const calls = [];
  const context = setup(async name => {
    calls.push(name);
    return name.endsWith('.br') ? new Response('unusable encoded body') : new Response(zlib.gzipSync(payload));
  });
  const response = await context.triangleArtFetchCompressed(url, payload.length);
  assert.deepEqual(Buffer.from(await response.arrayBuffer()), payload);
  assert.deepEqual(calls, [url+'.br', url+'.gz']);
});
test('the vendored gzip fallback works without DecompressionStream', async () => {
  const context = setup(async name => name.endsWith('.br') ? new Response('', {status:404}) : new Response(zlib.gzipSync(payload)), {DecompressionStream:undefined});
  assert.deepEqual(Buffer.from(await (await context.triangleArtFetchCompressed(url, payload.length)).arrayBuffer()), payload);
});
test('server-decoded gzip is not decompressed twice', async () => {
  const context = setup(async name => name.endsWith('.br') ? new Response('', {status:404}) : new Response(payload, {headers:{'Content-Encoding':'gzip'}}));
  assert.deepEqual(Buffer.from(await (await context.triangleArtFetchCompressed(url, payload.length)).arrayBuffer()), payload);
});
test('simultaneous consumers share one request', async () => {
  let resolve, calls = 0;
  const context = setup(() => {calls++;return new Promise(done => {resolve=done;});});
  const first=request(context), second=request(context);
  resolve(decoded());
  for (const result of await Promise.all([first, second])) {
    assert.equal(result[0], true);
    assert.deepEqual(Buffer.from(result[1]), payload);
  }
  assert.equal(calls, 1);
});
test('cancellation aborts the transfer and ignores a stale response after retry', async () => {
  let resolveFirst, firstSignal, calls=0;
  const context = setup((name, options) => {
    calls++;
    if (calls===1) {firstSignal=options.signal;return new Promise(done => {resolveFirst=done;});}
    return Promise.resolve(decoded());
  });
  let callbackCount=0;
  const cancelled = new Promise(resolve => context.QuadResourcePacks.download('opening', (...args) => {callbackCount++;resolve(args);}));
  context.QuadResourcePacks.cancel('opening');
  assert.equal((await cancelled)[0], false);
  assert.equal(firstSignal.aborted, true);
  assert.equal((await request(context))[0], true);
  resolveFirst(decoded());
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(callbackCount, 1);
});
test('a truncated pack fails and a later retry can succeed', async () => {
  let calls=0;
  const context=setup(async () => ++calls===1 ? new Response('short', {headers:{'Content-Encoding':'br'}}) : decoded());
  assert.equal((await request(context))[0], false);
  assert.equal((await request(context))[0], true);
});
test('HTTP errors are delivered to the caller instead of hanging', async () => {
  const context=setup(async () => new Response('', {status:503}));
  const result=await request(context);
  assert.equal(result[0], false);
  assert.match(result[2], /503/);
});
test('an absent manifest does not start a request', async () => {
  let calls=0;
  const context=setup(async () => {calls++;return decoded();}, {QUAD_RESOURCE_PACKS:null});
  assert.equal((await request(context))[0], false);
  assert.equal(calls, 0);
});
test('audio is unlocked synchronously in the play gesture', () => {
  let resumed=false;
  const context=setup(async () => decoded(), {quadUnlockAudio:() => {resumed=true;}});
  context.QuadResourcePacks.unlockAudio();
  assert.equal(resumed, true);
});
test('unrelated assets retain their normal URLs', async () => {
  const calls=[];
  const context=setup(async name => {calls.push(name);return new Response('icon');});
  assert.equal(await (await context.triangleArtFetchCompressed('icon.png')).text(), 'icon');
  assert.deepEqual(calls, ['icon.png']);
});
