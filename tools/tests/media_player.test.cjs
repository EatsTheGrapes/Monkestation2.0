// Run: node tools/tests/media_player.test.cjs
// Exercise the production media wrapper with a fake Howl and deterministic
// timers; no network, browser, server or audio device is required.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.resolve(__dirname, '../../code/modules/media/assets/media_player.js'), 'utf8');
const helpers = source.slice(source.indexOf('  function n('), source.indexOf('  (!(function'));
const wrapper = source.slice(source.indexOf('\n    (active_request = null),'), source.lastIndexOf('})();'));
const navigations = [];
const timers = new Map();
const howls = [];
let nextTimer = 0;
class FakeHowl {
  constructor(options) { this.options = options; this._sounds = []; howls.push(this); }
  unload() { this.unloaded = true; }
  pos() {}
  stereo() {}
  play() {}
  pause() {}
  volume() {}
  seek() {}
}
const context = vm.createContext({
  e: FakeHowl, console, Date, encodeURIComponent,
  document: { readyState: 'loading' },
  setTimeout(callback) { const id = ++nextTimer; timers.set(id, callback); return id; },
  clearTimeout(id) { timers.delete(id); },
});
context.window = context;
context.location = { set href(url) { navigations.push(url); } };
vm.runInContext(helpers + "(" + wrapper, context);
const messages = () => navigations.map(url => new URLSearchParams(url.slice(url.indexOf('?') + 1).replaceAll(';', '&')));
const lastHowl = () => howls.at(-1);
context.play('https://example.test/bad.mp3', 42.5, '', 0, 0, 0, 0, 11);
const failed = lastHowl();
failed.options.onloaderror();
assert.equal(navigations.length, 1, 'failure emits one Topic, without a competing clear');
assert.equal(messages()[0].get('type'), 'load_error');
assert.deepEqual(JSON.parse(messages()[0].get('params')), { url: 'https://example.test/bad.mp3', token: 11, reason: 'load_error' });
failed.options.onloaderror();
assert.equal(navigations.length, 1, 'duplicate failures are ignored');
context.play('https://example.test/new.mp3', 85, '', 0, 0, 0, 0, 12);
const current = lastHowl();
failed.options.onloaderror();
failed.options.onend();
assert.equal(context.audio, current, 'stale callbacks cannot unload replacement audio');
assert.equal(navigations.length, 1);
current.options.onplay();
assert.equal(timers.size, 0, 'successful playback cancels load timeout');
assert.equal(messages().at(-1).get('type'), 'playing');
assert.equal(JSON.parse(messages().at(-1).get('params')).token, 12);
current.options.onend();
assert.equal(messages().at(-1).get('type'), 'clear', 'normal song completion does not skip tracks');
assert.equal(JSON.parse(messages().at(-1).get('params')).token, 12);
context.play('https://example.test/gesture.mp3', 85, '', 0, 0, 0, 0, 13);
lastHowl().options.onplayerror();
assert.equal(timers.size, 0);
assert.equal(messages().at(-1).get('type'), 'clear', 'autoplay rejection does not blacklist a song');
const failuresBefore = messages().filter(message => message.get('type') === 'load_error').length;
context.play('https://example.test/hang.mp3', 85, '', 0, 0, 0, 0, 14);
const timeout = [...timers.values()][0];
timeout();
assert.equal(messages().filter(message => message.get('type') === 'load_error').length, failuresBefore + 1);
assert.equal(JSON.parse(messages().at(-1).get('params')).reason, 'timeout');
context.play('https://example.test/stop.mp3', 85, '', 0, 0, 0, 0, 15);
const stopped = lastHowl();
const stopTimeout = [...timers.values()][0];
context.stop();
const afterStop = navigations.length;
stopTimeout();
stopped.options.onloaderror();
assert.equal(navigations.length, afterStop, 'stop ignores already queued old timeout/error callbacks');
assert.equal(timers.size, 0, 'stop cancels pending timeout');
context.play('https://example.test/replaced.mp3', 85, '', 0, 0, 0, 0, 16);
const replaced = lastHowl();
const replacedTimeout = [...timers.values()][0];
context.play('https://example.test/replacement.mp3', 85, '', 0, 0, 0, 0, 17);
const replacement = lastHowl();
assert.equal(replaced.unloaded, true, 'replacement unloads previous Howl');
const beforeStale = navigations.length;
replacedTimeout();
replaced.options.onplay();
replaced.options.onloaderror();
replaced.options.onplayerror();
assert.equal(context.audio, replacement);
assert.equal(navigations.length, beforeStale, 'replacement ignores all stale callbacks');
assert.equal(timers.size, 1, 'replacement cancels old timeout and installs one new timer');
replacement.options.onplay();
assert.equal(JSON.parse(messages().at(-1).get('params')).token, 17);
context.play('https://example.test/paused.mp3', 85, '', 0, 0, 0, 0, 18);
context.pause();
assert.equal(timers.size, 0, 'pause cancels pending timeout');
console.log('media player regressions passed');
