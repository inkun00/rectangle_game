const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const zlib = require('node:zlib');

const source = fs.readFileSync(process.argv[2], 'utf8');
const raw = Buffer.from('Triangle Art web bytes '.repeat(4096));
const gzip = zlib.gzipSync(raw);
const wasm = 'engine-0123456789ab.wasm';
const pack = 'art-0123456789ab.pck';

async function verify(native, encodedByServer) {
    const requests = [];
    const context = vm.createContext({
        Headers, Response, Uint8Array, DecompressionStream: native ? DecompressionStream : undefined,
        fetch: async (file) => {
            requests.push(file);
            return new Response(encodedByServer ? raw : gzip, {
                headers: encodedByServer ? { 'Content-Encoding': 'gzip' } : {},
            });
        },
    });
    vm.runInContext(source, context);
    for (const file of [wasm, pack]) {
        const response = await context.triangleArtFetchCompressed(file, raw.length);
        assert.deepEqual(Buffer.from(await response.arrayBuffer()), raw);
        assert.equal(requests.at(-1), `${file}.gz`);
        assert.equal(response.headers.get('Content-Length'), String(raw.length));
        assert.equal(response.headers.get('Content-Encoding'), null);
    }
    const response = await context.triangleArtFetchCompressed('other.json', raw.length);
    assert.equal(requests.at(-1), 'other.json');
    assert.deepEqual(Buffer.from(await response.arrayBuffer()), encodedByServer ? raw : gzip);
    assert.equal(context.pako, undefined, 'The fallback library must stay private');
}

async function verifyFailure(native, data) {
    const context = vm.createContext({
        Headers, Response, Uint8Array, DecompressionStream: native ? DecompressionStream : undefined,
        fetch: async () => new Response(data),
    });
    vm.runInContext(source, context);
    await assert.rejects(async () => {
        const response = await context.triangleArtFetchCompressed(wasm, raw.length);
        await response.arrayBuffer();
    });
}

async function verifyGodotFailure(native, file, data, streaming = true) {
    const context = vm.createContext({
        Headers, Response, ReadableStream, Uint8Array, TextEncoder, TextDecoder,
        WebAssembly: streaming ? WebAssembly : { ...WebAssembly, instantiateStreaming: undefined, instantiate: WebAssembly.instantiate },
        DecompressionStream: native ? DecompressionStream : undefined,
        fetch: async () => new Response(data),
        window: {}, document: { currentScript: { src: 'https://example.test/engine.js' } },
        navigator: { language: 'ko' }, URL,
        requestAnimationFrame: () => {}, setTimeout: (callback, delay) => setTimeout(callback, Math.min(delay, 10)),
    });
    vm.runInContext(source, context);
    const engine = new context.window.Engine({ executable: wasm.slice(0, -5) });
    const promise = file === pack ? engine.preloadFile(pack, pack) : engine.init(wasm.slice(0, -5));
    await assert.rejects(Promise.race([
        promise,
        new Promise((_, reject) => setTimeout(() => reject(new Error('Godot loader stalled')), 2000)),
    ]), (error) => !String(error).includes('Godot loader stalled'));
}

(async () => {
    await verify(true, false);
    await verify(false, false);
    await verify(true, true);
    await verify(false, true);
    for (const native of [true, false]) {
        await verifyFailure(native, gzip.subarray(0, gzip.length - 4));
        await verifyFailure(native, Buffer.from('invalid gzip'));
        await verifyGodotFailure(native, pack, gzip.subarray(0, gzip.length - 4));
        const emptyWasm = Buffer.from([0, 97, 115, 109, 1, 0, 0, 0]);
        const brokenWasmGzip = zlib.gzipSync(emptyWasm).subarray(0, -4);
        await verifyGodotFailure(native, wasm, brokenWasmGzip);
        await verifyGodotFailure(native, wasm, brokenWasmGzip, false);
        await verifyGodotFailure(native, wasm, zlib.gzipSync(Buffer.from('invalid wasm')));
    }
    console.log('Native and fallback gzip decoders passed.');
})().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
