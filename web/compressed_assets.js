// Brotli is decoded by the browser; plain static hosts use the gzip fallback.
async function triangleArtFetchCompressed(file, fileSize, options = {}) {
	if (!/(?:^|\/)(?:engine-[0-9a-f]{12}\.wasm|art-[0-9a-f]{12}\.pck|feature-[a-z_]+-[0-9a-f]{12}\.pck)$/.test(file)) return fetch(file, options);
	const decodedResponse = function(response, body) {
		const headers = new Headers(response.headers);
		headers.delete('Content-Encoding');
		headers.delete('Content-Length');
		headers.set('Content-Type', file.endsWith('.wasm') ? 'application/wasm' : 'application/octet-stream');
		if (fileSize) headers.set('Content-Length', String(fileSize));
		return new Response(body, { headers });
	};
	try {
		const response = await fetch(`${file}.br`, options);
		if (response.ok && /\bbr\b/i.test(response.headers.get('Content-Encoding') || '')) return decodedResponse(response, response.body);
		if (response.body) await response.body.cancel();
	} catch (error) {
		if ((options.signal && options.signal.aborted) || error.name === 'AbortError') throw error;
	}
	const response = await fetch(`${file}.gz`, options);
	if (!response.ok) return response;
	if (/\bgzip\b/i.test(response.headers.get('Content-Encoding') || '')) return decodedResponse(response, response.body);
	if (typeof DecompressionStream !== 'undefined') return decodedResponse(response, response.body.pipeThrough(new DecompressionStream('gzip')));
	const bytes = new Uint8Array(await response.arrayBuffer());
	return decodedResponse(response, triangleArtUngzip(bytes));
}

(function(global) {
	'use strict';
	const pending = new Map();
	function finish(feature, task, success, buffer, error) {
		if (pending.get(feature) !== task) return;
		pending.delete(feature);
		for (const callback of task.callbacks) callback(success, buffer, error || '');
	}
	global.QuadResourcePacks = {
		download(feature, callback) {
			const manifest = global.QUAD_RESOURCE_PACKS;
			const pack = manifest && manifest.version === 1 && manifest.packs && manifest.packs[feature];
			if (!pack || !/^feature-[a-z_]+-[0-9a-f]{12}\.pck$/.test(pack.url) || !(pack.bytes > 0)) { callback(false, null, 'Resource manifest is unavailable'); return; }
			if (pending.has(feature)) { pending.get(feature).callbacks.push(callback); return; }
			const task = { controller: new AbortController(), callbacks: [callback] };
			pending.set(feature, task);
			triangleArtFetchCompressed(pack.url, pack.bytes, { signal: task.controller.signal })
				.then(response => {
					if (!response.ok) throw new Error(`Resource download failed (${response.status})`);
					return response.arrayBuffer();
				})
				.then(buffer => {
					if (buffer.byteLength !== pack.bytes) throw new Error('Incomplete resource download');
					finish(feature, task, true, buffer, '');
				})
				.catch(error => finish(feature, task, false, null, String(error.message || error)));
		},
		cancel(feature) {
			const task = pending.get(feature);
			if (!task) return;
			finish(feature, task, false, null, 'Download cancelled');
			task.controller.abort();
		},
		unlockAudio() { if (typeof global.quadUnlockAudio === 'function') global.quadUnlockAudio(); }
	};
})(globalThis);
