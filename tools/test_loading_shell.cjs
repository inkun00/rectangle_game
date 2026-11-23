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
const script = [...exported.matchAll(/<script>\s*([\s\S]*?)<\/script>/g)]
  .map(match => match[1]).find(source => source.includes('engine.startGame'));

function shell(options = {}) {
  const elements = new Map();
  const listeners = {};
  const document = {activeElement: null, getElementById: id => elements.get(id),
    addEventListener: (event, handler) => { listeners[event] = handler; }};
  for (const match of html.matchAll(/<[a-z][^>]*\bid="([^"]+)"[^>]*>/g)) {
    const attributes = new Map([...match[0].matchAll(/([\w-]+)="([^"]*)"/g)].map(item => [item[1], item[2]]));
    let text = match[1] === 'stage' ? '그림 도구와 건축 재료를 준비하고 있어요…' : '';
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
  const timers = new Map();
  let now = 0, nextTimer = 0;
  function advance(ms) {
    now += ms;
    for (const [id, timer] of timers) {
      if (timer.at > now) continue;
      timers.delete(id);
      timer.callback();
    }
  }
  const context = {document, console: {error: value => errors.push(value)}, location: {reload: () => result.reloads++},
    setTimeout(callback, delay) { const id = ++nextTimer; timers.set(id, {callback, at: now + delay}); return id; },
    clearTimeout: id => timers.delete(id)};
  if (!options.noEngine) context.Engine = Engine;
  vm.runInNewContext(script, context, {filename: 'loading.html'});
  if (!options.waitForScript) listeners.DOMContentLoaded();
  return {...result, resolve, reject, advance, scriptLoaded: listeners.DOMContentLoaded, state: result};
}

async function flush() { await Promise.resolve(); await Promise.resolve(); }

const dailyQuizScript = [...exported.matchAll(/<script>\s*([\s\S]*?)<\/script>/g)]
  .map(match => match[1]).find(source => source.includes('window.QuadDailyQuiz ='));

function quizPage(profile, options = {}) {
  const window = {
    location: {protocol: 'https:'},
    get localStorage() {
      if (options.storageBlocked) throw new Error('Storage is unavailable');
      return {
        getItem: key => profile.storage.get(key) ?? null,
        setItem: (key, value) => profile.storage.set(key, value),
        removeItem: key => profile.storage.delete(key),
      };
    },
  };
  const document = {
    get cookie() { return options.cookiesBlocked ? '' : profile.cookie; },
    set cookie(value) {
      if (options.cookiesBlocked) return;
      assert.match(value, /; Path=\/; Max-Age=(?:172800; SameSite=Lax; Secure|0; SameSite=Lax)$/);
      const entry = value.split(';', 1)[0];
      const prefix = entry.slice(0, entry.indexOf('=') + 1);
      const others = profile.cookie.split('; ').filter(item => item && !item.startsWith(prefix));
      profile.cookie = (value.includes('Max-Age=0;') ? others : [...others, entry]).join('; ');
    },
  };
  vm.runInNewContext(dailyQuizScript, {window, document});
  return window.QuadDailyQuiz;
}

test('daily completion survives reloads, reopening and overlapping tabs, and expires by the next Korean date', () => {
  const profile = {storage: new Map(), cookie: ''};
  const first = quizPage(profile);
  const otherTab = quizPage(profile);
  const today = '2026-11-23', tomorrow = '2026-11-24';
  assert.equal(first.completedToday(today), false);
  assert.equal(first.markCompleted(today), true);
  assert.equal(otherTab.completedToday(today), true);
  assert.equal(quizPage(profile).completedToday(today), true);
  assert.equal(quizPage(profile).completedToday(tomorrow), false);
  assert.equal(otherTab.markCompleted(tomorrow), true);
  assert.equal(first.markCompleted(today), true);
  assert.equal(first.completedToday(tomorrow), true);
  assert.equal(first.completedToday(today), false);
});

test('legacy completions migrate and the daily cookie survives localStorage rejection', () => {
  const key = 'quadrilateral_world.startup_completion.v1';
  const date = '2026-11-23';
  const profile = {storage: new Map([[key, date]]), cookie: ''};
  assert.equal(quizPage(profile).completedToday(date), true);
  profile.storage.clear();
  const restricted = {storageBlocked: true};
  assert.equal(quizPage(profile, restricted).completedToday(date), true);
  const next = '2026-11-24';
  assert.equal(quizPage(profile, restricted).markCompleted(next), true);
  assert.equal(quizPage(profile, restricted).completedToday(next), true);
  assert.equal(quizPage(profile).completedToday(next), true);
  assert.equal(profile.storage.get(key), next);
});

test('daily completion still uses local storage when cookies are blocked and reports total storage failure', () => {
  const date = '2026-11-23';
  const profile = {storage: new Map(), cookie: ''};
  const noCookies = {cookiesBlocked: true};
  assert.equal(quizPage(profile, noCookies).markCompleted(date), true);
  assert.equal(quizPage(profile, noCookies).completedToday(date), true);
  const blocked = quizPage(profile, {cookiesBlocked: true, storageBlocked: true});
  assert.equal(blocked.markCompleted(date), false);
  assert.equal(blocked.completedToday(date), false);
  assert.equal(quizPage(profile).markCompleted('invalid; SameSite=None'), false);
});

test('daily progress restores the same variants on the same date without moving a later tab backward', () => {
  const day = '2026-11-23', nextDay = '2026-11-24';
  const json = (date, index, variants = [1, 2, 3, 4, 5]) => JSON.stringify({version: 1, date, index, variants});
  const profile = {storage: new Map(), cookie: ''};
  const first = quizPage(profile);
  const other = quizPage(profile);
  assert.equal(first.readProgress(day), '');
  assert.equal(first.saveProgress(day, json(day, 2)), true);
  assert.equal(other.saveProgress(day, json(day, 1)), true);
  assert.equal(quizPage(profile).readProgress(day), json(day, 2));
  const retry = json(day, 2, [1, 2, 9, 4, 5]);
  assert.equal(other.saveProgress(day, retry), true);
  assert.equal(quizPage(profile, {storageBlocked: true}).readProgress(day), retry);
  assert.equal(other.readProgress(nextDay), '');
  assert.equal(first.markCompleted(day), true);
  assert.equal(profile.storage.has('quadrilateral_world.startup_progress.v1'), false);
  assert.doesNotMatch(profile.cookie, /quad_quiz_progress_v1=/);
  assert.equal(other.saveProgress(day, json(day, 3)), true);
  assert.equal(other.readProgress(day), '');
  assert.equal(other.saveProgress(nextDay, json(nextDay, 0)), true);
  assert.equal(first.saveProgress(day, json(day, 4)), true);
  assert.equal(other.readProgress(nextDay), json(nextDay, 0));
});

test('invalid partial sessions are rejected and a newer valid session survives a stale write', () => {
  const day = '2026-11-23', nextDay = '2026-11-24';
  const profile = {storage: new Map(), cookie: ''};
  const tab = quizPage(profile);
  const raw = JSON.stringify({version: 1, date: nextDay, index: 0, variants: [1, 2, 3, 4, 5]});
  assert.equal(tab.saveProgress(nextDay, raw), true);
  assert.equal(tab.saveProgress(day, raw.replace(nextDay, day)), true);
  assert.equal(tab.saveProgress(nextDay, raw.replace('[1,', '[41,')), false);
  assert.equal(tab.saveProgress(nextDay, 'broken'), false);
  assert.equal(tab.saveProgress(day, raw), false);
  assert.equal(tab.readProgress(nextDay), raw);
});

test('the shell preserves Godot export and asset fingerprinting contracts', () => {
  for (const macro of ['$GODOT_HEAD_INCLUDE', '$GODOT_URL', '$GODOT_THREADS_ENABLED', '$GODOT_CONFIG']) {
    assert.equal(html.split(macro).length - 1, 1, macro);
  }
  assert.equal(exported.split('<script src="index.js"></script>').length - 1, 1);
  assert.ok(exported.indexOf('watchForStall()') < exported.indexOf('<script src="index.js"></script>'));
  assert.equal(JSON.parse(exported.match(/\bconst config = (\{.*\});/)[1]).executable, 'index');
  assert.match(html, /<title>사각이의 모험<\/title>/);
  assert.match(html, /<h1 id="loading-title">사각이의 모험<\/h1>/);
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
  assert.match(run.elements.get('stage').textContent, /게임을 여는 중/);
  assert.equal(run.document.activeElement, null);
  run.resolve();
  await flush();
  assert.equal(run.elements.get('loading').removed, true);
  assert.equal(run.document.activeElement, run.elements.get('canvas'));
  assert.equal(run.elements.get('canvas').tabIndex, 0);
  assert.equal(run.elements.get('canvas').attributes.get('aria-busy'), 'false');
  assert.equal(run.errors.length, 0);
  const previous = run.elements.get('stage').textContent;
  run.state.progress(10, 100);
  assert.equal(run.elements.get('stage').textContent, previous);
});

test('a stalled script offers retry and can still finish normally', async () => {
  const run = shell({waitForScript: true});
  run.advance(30000);
  assert.equal(run.state.starts, 0);
  assert.equal(run.elements.get('error-box').hidden, false);
  assert.equal(run.elements.get('error-info').hidden, true);
  assert.equal(run.elements.get('canvas').attributes.get('aria-busy'), 'true');
  run.scriptLoaded();
  run.resolve();
  await flush();
  assert.equal(run.elements.get('loading').removed, true);
  assert.equal(run.document.activeElement, run.elements.get('canvas'));
});

test('received bytes extend the wait, repeated progress does not, and a later failure can be retried', async () => {
  const run = shell();
  run.advance(20000);
  run.state.progress(1, 100);
  run.advance(20000);
  assert.equal(run.elements.get('error-box').hidden, true);
  run.state.progress(1, 100);
  run.advance(10000);
  assert.equal(run.elements.get('error-box').hidden, false);
  assert.equal(run.document.activeElement, null);
  run.reject(new Error('Connection interrupted'));
  await flush();
  assert.equal(run.elements.get('error-info').hidden, false);
  assert.equal(run.document.activeElement, run.elements.get('retry-btn'));
  run.elements.get('retry-btn').listeners.click();
  assert.equal(run.state.reloads, 1);
});

test('resumed progress clears a stall notice and preserves keyboard focus on retry', () => {
  const run = shell();
  const recovery = run.elements.get('error-box');
  const retry = run.elements.get('retry-btn');
  run.advance(30000);
  run.state.progress(1, 100);
  assert.equal(recovery.hidden, true);
  run.advance(30000);
  assert.equal(recovery.hidden, false);
  retry.focus();
  run.state.progress(2, 100);
  assert.equal(recovery.hidden, false);
  assert.equal(run.document.activeElement, retry);
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
