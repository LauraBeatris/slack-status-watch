#!/usr/bin/env node
// Renders the landing page's share card, AppStore/design/og.html, into
// web/public/og.mp4 and its first frame into web/public/og.png.
//
//   node Scripts/render-og-video.mjs
//
// With --out it renders to that file only and leaves the share card alone.
// --width sets the output width, and --page picks another page to render:
//
//   node Scripts/render-og-video.mjs --width 3840 --out AppStore/promo/og-3840x2016.mp4
//   node Scripts/render-og-video.mjs --page AppStore/design/og-demo.html --width 3840 --out AppStore/promo/og-video-demo.mp4
//
// A page is drawn at the size its <html> element sets. Headless Chrome is paused and
// stepped through it one frame at a time, so the video is exact however slow the
// machine is. A page that defines window.seek(ms) and window.DURATION is stepped
// through those; otherwise through its Web Animations. The frames are then encoded
// by Scripts/encode-frames.swift. Needs Chrome, Node 22+ and Xcode.

import { spawn, execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const chromePath = process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const { values: options } = parseArgs({
  options: { page: { type: 'string' }, width: { type: 'string' }, out: { type: 'string' } },
});
const page = options.page ? resolve(options.page) : join(root, 'AppStore/design/og.html');
const WIDTH = Number(options.width ?? 1200);
if (!(WIDTH > 0)) throw new Error('--width must be a positive number');
const FPS = 60;

const shareCard = !options.out;
const video = shareCard ? join(root, 'web/public/og.mp4') : resolve(options.out);
mkdirSync(dirname(video), { recursive: true });

const work = mkdtempSync(join(tmpdir(), 'og-video-'));
const frames = join(work, 'frames');
mkdirSync(frames);

const chrome = spawn(chromePath, [
  '--headless=new', '--remote-debugging-port=0', `--user-data-dir=${join(work, 'profile')}`,
  '--hide-scrollbars', '--no-first-run', '--autoplay-policy=no-user-gesture-required', 'about:blank',
], { stdio: ['ignore', 'ignore', 'pipe'] });

try {
  const send = await connect(await debuggerPort(chrome));

  await send('Page.enable');
  const loaded = send.once('Page.loadEventFired');
  await send('Page.navigate', { url: pathToFileURL(page).href });
  await loaded;

  const design = await evaluate(send, `({ width: document.documentElement.offsetWidth, height: document.documentElement.offsetHeight })`);
  const scale = WIDTH / design.width;
  await send('Emulation.setDeviceMetricsOverride', { ...design, deviceScaleFactor: scale, mobile: false });

  const duration = await evaluate(send, `Promise.resolve(window.ready ?? document.fonts.ready).then(() =>
    window.DURATION ?? Math.max(0, ...document.getAnimations().map((a) => a.effect.getTiming().duration)))`);
  if (!duration) throw new Error(`${page} has nothing to animate`);

  const count = Math.round((duration / 1000) * FPS);
  for (let i = 0; i < count; i++) {
    const ms = (i * 1000) / FPS;
    await evaluate(send, `Promise.resolve(window.seek ? window.seek(${ms}) : (() => {
      for (const a of document.getAnimations()) { a.pause(); a.currentTime = ${ms}; }
    })()).then(() => new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done))))`);
    const { data } = await send('Page.captureScreenshot', { format: 'png' });
    writeFileSync(join(frames, `${String(i).padStart(5, '0')}.png`), Buffer.from(data, 'base64'));
    process.stdout.write(`\rframe ${i + 1}/${count}`);
  }
  process.stdout.write('\n');

  // The share card stays small for link previews. Anything else gets enough bits that
  // gradients and text edges hold up at full size: about 0.05 bits a pixel.
  const pixels = WIDTH * Math.round(design.height * scale);
  const bitrate = shareCard ? 1_600_000 : Math.round(pixels * FPS * 0.05);
  execFileSync('swift', [join(root, 'Scripts/encode-frames.swift'), frames, video, String(FPS), String(bitrate)], { stdio: 'inherit' });
  if (shareCard) copyFileSync(join(frames, '00000.png'), join(root, 'web/public/og.png'));
  console.log(`wrote ${video}${shareCard ? ' and og.png' : ''}`);
} finally {
  chrome.kill();
  rmSync(work, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
}

/** Chrome prints the port it picked on stderr. */
function debuggerPort(child) {
  return new Promise((resolvePort, reject) => {
    let log = '';
    child.stderr.on('data', (chunk) => {
      log += chunk;
      const match = log.match(/DevTools listening on ws:\/\/[^:]+:(\d+)\//);
      if (match) resolvePort(Number(match[1]));
    });
    child.on('error', reject);
    child.on('exit', (code) => reject(new Error(`Chrome exited (${code}) before it was ready:\n${log}`)));
  });
}

/** A minimal DevTools protocol client for the first tab. */
async function connect(port) {
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const socket = new WebSocket(targets.find((t) => t.type === 'page').webSocketDebuggerUrl);
  await new Promise((open, reject) => { socket.onopen = open; socket.onerror = reject; });

  let nextId = 0;
  const pending = new Map();
  const waiting = new Map();
  socket.onmessage = ({ data }) => {
    const message = JSON.parse(data);
    if (message.id === undefined) {
      waiting.get(message.method)?.(message.params);
      waiting.delete(message.method);
      return;
    }
    const { done, fail } = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) fail(new Error(message.error.message));
    else done(message.result);
  };

  const send = (method, params = {}) => new Promise((done, fail) => {
    pending.set(++nextId, { done, fail });
    socket.send(JSON.stringify({ id: nextId, method, params }));
  });
  send.once = (event) => new Promise((done) => waiting.set(event, done));
  return send;
}

async function evaluate(send, expression) {
  const { result, exceptionDetails } = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  if (exceptionDetails) throw new Error(exceptionDetails.exception?.description ?? exceptionDetails.text);
  return result.value;
}
