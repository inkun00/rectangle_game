// Only content-addressed Godot binaries use on-disk gzip. Other requests keep
// their normal paths, and decoded byte counts still drive Godot's progress UI.
function triangleArtFetchCompressed(file, fileSize) {
	if (!/(?:^|\/)(?:engine-[0-9a-f]{12}\.wasm|art-[0-9a-f]{12}\.pck)$/.test(file)) {
		return fetch(file);
	}
	return fetch(`${file}.gz`).then(async function(response) {
		if (!response.ok) return response;
		const headers = new Headers(response.headers);
		const decodedByServer = /\bgzip\b/i.test(headers.get('Content-Encoding') || '');
		headers.delete('Content-Encoding');
		headers.delete('Content-Length');
		headers.set('Content-Type', file.endsWith('.wasm') ? 'application/wasm' : 'application/octet-stream');
		if (fileSize) headers.set('Content-Length', String(fileSize));
		if (decodedByServer) {
			return new Response(response.body, { headers });
		}
		if (typeof DecompressionStream !== 'undefined') {
			return new Response(response.body.pipeThrough(new DecompressionStream('gzip')), { headers });
		}
		// Older browsers use the vendored decoder without a network dependency.
		const bytes = new Uint8Array(await response.arrayBuffer());
		return new Response(triangleArtUngzip(bytes), { headers });
	});
}
