#!/usr/bin/env node
// Renders the landing page's share card, AppStore/design/og.html, into
// web/public/og.mp4 and its first frame into web/public/og.png.
//
//   node Scripts/render-og-video.mjs
//
// Headless Chrome is paused and stepped through the card's animations one frame
// at a time, so the video is exact however slow the machine is. The frames are
// then encoded by Scripts/encode-frames.swift. Needs Chrome, Node 22+ and Xcode.

import { spawn, execFileSync } from 'node:child_process';
import { copyFileSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const page = join(root, 'AppStore/design/og.html');
const out = join(root, 'web/public');
const chromePath = process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

// The card is drawn at 3840 x 2016 and comes out at 1200 x 630
const DESIGN = { width: 3840, height: 2016 };
const SCALE = 1200 / DESIGN.width;
const FPS = 60;

const work = mkdtempSync(join(tmpdir(), 'og-video-'));
const frames = join(work, 'frames');
execFileSync('mkdir', ['-p', frames]);

const chrome = spawn(chromePath, [
  '--headless=new', '--remote-debugging-port=0', `--user-data-dir=${join(work, 'profile')}`,
  '--hide-scrollbars', '--no-first-run', 'about:blank',
], { stdio: ['ignore', 'ignore', 'pipe'] });

try {
  const send = await connect(await debuggerPort(chrome));

  await send('Emulation.setDeviceMetricsOverride', { ...DESIGN, deviceScaleFactor: SCALE, mobile: false });
  await send('Page.enable');
  const loaded = send.once('Page.loadEventFired');
  await send('Page.navigate', { url: pathToFileURL(page).href });
  await loaded;

  const loop = await evaluate(send, `document.fonts.ready.then(() =>
    Math.max(0, ...document.getAnimations().map((a) => a.effect.getTiming().duration)))`);
  if (!loop) throw new Error(`${page} has no animations to render`);

  const count = Math.round((loop / 1000) * FPS);
  for (let i = 0; i < count; i++) {
    await evaluate(send, `new Promise((done) => {
      for (const a of document.getAnimations()) { a.pause(); a.currentTime = ${(i * 1000) / FPS}; }
      requestAnimationFrame(() => requestAnimationFrame(done));
    })`);
    const { data } = await send('Page.captureScreenshot', { format: 'png' });
    writeFileSync(join(frames, `${String(i).padStart(5, '0')}.png`), Buffer.from(data, 'base64'));
    process.stdout.write(`\rframe ${i + 1}/${count}`);
  }
  process.stdout.write('\n');

  execFileSync('swift', [join(root, 'Scripts/encode-frames.swift'), frames, join(out, 'og.mp4'), String(FPS)], { stdio: 'inherit' });
  copyFileSync(join(frames, '00000.png'), join(out, 'og.png'));
  console.log(`wrote ${join(out, 'og.mp4')} and og.png`);
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
