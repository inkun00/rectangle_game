'use strict';

// Exercise the real exported shell script with controlled engine outcomes.
// No browser packages, engine downloads, or generated release files are needed.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const html = fs.readFileSync(path.join(__dirname, '../web/loading.html'), 'utf8');
const exported = html.replace('$GODOT_HEAD_INCLUDE', '')
  .replace('$GODOT_URL', 'index.js')
  .replace('$GODOT_THREADS_ENABLED', 'false')
  .replace('$GODOT_CONFIG', '{"executable":"index","fileSizes":{}}');
const script = exported.match(/<script>\s*([\s\S]*?)<\/script>/)[1];

function shell(options = {}) {
  const elements = new Map();
  const document = {activeElement: null, getElementById: id => elements.get(id)};
  for (const match of html.matchAll(/<[a-z][^>]*\bid="([^"]+)"[^>]*>/g)) {
    const attributes = new Map([...match[0].matchAll(/([\w-]+)="([^"]*)"/g)].map(item => [item[1], item[2]]));
    let text = match[1] === 'stage' ? '공방과 모험길을 준비하고 있어요…' : '';
    elements.set(match[1], {
      attributes, writes: [], listeners: {}, removed: false,
      hidden: /\bhidden\b/.test(match[0]), tabIndex: Number(attributes.get('tabindex') || 0),
      get textContent() { return text; },
      set textContent(value) { text = value; this.writes.push(value); },
      set value(value) { attributes.set('value', String(value)); },
      get value() { return Number(attributes.get('value')); },
      setAttribute(name, value) { attributes.set(name, value); },
      removeAttribute(name) { attributes.delete(name); },
      addEventListener(name, action) { this.listeners[name] = action; },
      remove() { this.removed = true; },
      focus() { document.activeElement = this; },
    });
  }
  const errors = [];
  const result = {elements, document, errors, reloads: 0, starts: 0};
  let resolve, reject;
  const readiness = new Promise((yes, no) => { resolve = yes; reject = no; });
  class Engine {
    static getMissingFeatures() { return options.missing || []; }
    startGame(callbacks) {
      result.starts += 1;
      if (options.throwOnStart) throw new Error('Synchronous engine failure');
      result.progress = callbacks.onProgress;
      return readiness;
    }
  }
  const context = {document, console: {error: value => errors.push(value)}, location: {reload: () => result.reloads++}};
  if (!options.noEngine) context.Engine = Engine;
  vm.runInNewContext(script, context, {filename: 'loading.html'});
  return {...result, resolve, reject, state: result};
}

async function flush() { await Promise.resolve(); await Promise.resolve(); }

test('the shell preserves Godot export and asset fingerprinting contracts', () => {
  for (const macro of ['$GODOT_HEAD_INCLUDE', '$GODOT_URL', '$GODOT_THREADS_ENABLED', '$GODOT_CONFIG']) {
    assert.equal(html.split(macro).length - 1, 1, macro);
  }
  assert.equal(exported.split('<script src="index.js"></script>').length - 1, 1);
  assert.equal(JSON.parse(exported.match(/\bconst config = (\{.*\});/)[1]).executable, 'index');
  assert.ok(html.indexOf('id="game-controls"') < html.indexOf('<section id="loading"'));
  assert.match(html, /aria-describedby="game-controls"/);
  assert.match(html, /#canvas:focus-visible\{outline:/);
  assert.match(html, /prefers-reduced-motion:reduce/);
});

test('frequent progress callbacks announce only milestones, not every percentage', () => {
  const run = shell();
  for (let percent = 0; percent < 100; percent++) run.state.progress(percent, 100);
  assert.equal(run.elements.get('progress').value, 99);
  const announcements = run.elements.get('stage').writes;
  assert.equal(announcements.length, 3);
  assert.match(announcements[0], /25%/);
  assert.match(announcements[2], /75%/);
  run.state.progress(99, 100);
  assert.equal(announcements.length, 3);
});

test('unknown totals can return to the same known percentage', () => {
  const run = shell();
  run.state.progress(50, 100);
  run.state.progress(0, 0);
  assert.equal(run.elements.get('progress').attributes.has('value'), false);
  run.state.progress(50, 100);
  assert.equal(run.elements.get('progress').value, 50);
  assert.equal(run.elements.get('progress-value').textContent, '50%');
});

test('100% download does not start play until the engine is ready', async () => {
  const run = shell();
  run.state.progress(100, 100);
  assert.equal(run.elements.get('loading').removed, false);
  assert.match(run.elements.get('stage').textContent, /공방을 여는 중/);
  assert.equal(run.document.activeElement, null);
  run.resolve();
  await flush();
  assert.equal(run.elements.get('loading').removed, true);
  assert.equal(run.document.activeElement, run.elements.get('canvas'));
  assert.equal(run.elements.get('canvas').tabIndex, 0);
  assert.equal(run.elements.get('canvas').attributes.get('aria-busy'), 'false');
  assert.equal(run.errors.length, 0);
  // The VM has no setTimeout: successful startup cannot depend on a fade timer.
  const previous = run.elements.get('stage').textContent;
  run.state.progress(10, 100);
  assert.equal(run.elements.get('stage').textContent, previous);
});

test('a rejected engine start exposes recovery and ignores late progress', async () => {
  const run = shell();
  run.reject(new Error('<failed network request>'));
  await flush();
  assert.equal(run.elements.get('loading').removed, false);
  assert.equal(run.elements.get('error-box').hidden, false);
  assert.equal(run.document.activeElement, run.elements.get('retry-btn'));
  assert.equal(run.elements.get('stage').attributes.get('aria-live'), 'off');
  assert.equal(run.elements.get('error-details').textContent, '<failed network request>');
  assert.match(run.elements.get('error-msg').textContent, /다시 불러와/);
  run.state.progress(100, 100);
  assert.equal(run.elements.get('progress-value').textContent, '준비 중단');
  assert.equal(run.errors.length, 1);
  run.elements.get('retry-btn').listeners.click();
  assert.equal(run.state.reloads, 1);
});

test('a missing engine script offers a focused retry', () => {
  const run = shell({noEngine: true});
  assert.equal(run.document.activeElement, run.elements.get('retry-btn'));
  assert.equal(run.errors.length, 1);
  assert.match(run.elements.get('error-msg').textContent, /게임 파일/);
});

test('unsupported browser features explain the remedy without starting', () => {
  const run = shell({missing: ['WebGL2']});
  assert.equal(run.state.starts, 0);
  assert.match(run.elements.get('error-msg').textContent, /브라우저를 업데이트/);
  assert.match(run.elements.get('error-details').textContent, /WebGL2/);
});

test('a synchronous engine failure also reaches the recovery flow', () => {
  const run = shell({throwOnStart: true});
  assert.equal(run.document.activeElement, run.elements.get('retry-btn'));
  assert.equal(run.errors.length, 1);
  assert.equal(run.elements.get('error-box').hidden, false);
});
