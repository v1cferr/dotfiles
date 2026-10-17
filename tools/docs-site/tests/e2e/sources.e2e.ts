// The source previews in a REAL browser, against the built static site, the way Pages serves it.
// No npm dependency: a headless Chromium driven over the DevTools protocol with node's own
// WebSocket. Not part of the build (a browser in the sandbox is not worth it): run by hand.
//
//   nix build .#pages && CHROMIUM=$(nix build --inputs-from . nixpkgs#chromium --print-out-paths --no-link)/bin/chromium \
//     SITE=$PWD/result pnpm --dir tools/docs-site test:e2e
//
// docs/notes/repo/site-sources.md
import assert from 'node:assert/strict';
import { type ChildProcess, spawn } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import type { AddressInfo } from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

const SITE = process.env.SITE;
const CHROMIUM = process.env.CHROMIUM;
if (!SITE || !CHROMIUM) throw new Error('set SITE (the built site) and CHROMIUM (a chromium binary)');

const TYPES: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.txt': 'text/plain; charset=utf-8',
  '.svg': 'image/svg+xml',
};

/** GitHub Pages, as far as this site cares: a directory URL serves its index.html. */
function serve(root: string): Promise<http.Server> {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url ?? '/', 'http://x');
    let file = path.join(root, decodeURIComponent(url.pathname));
    if (!file.startsWith(root)) return void res.writeHead(403).end();
    if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
    if (!fs.existsSync(file)) {
      res.writeHead(404, { 'content-type': TYPES['.html'] });
      return void res.end(fs.readFileSync(path.join(root, '404.html')));
    }
    res.writeHead(200, { 'content-type': TYPES[path.extname(file)] ?? 'application/octet-stream' });
    res.end(fs.readFileSync(file));
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

/** The smallest DevTools client that does the job: one browser socket, one flattened page session. */
class Browser {
  private socket!: WebSocket;
  private next = 0;
  private pending = new Map<number, { resolve: (v: any) => void; reject: (e: Error) => void }>();
  private listeners: ((method: string, params: any) => void)[] = [];
  session!: string;
  process!: ChildProcess;
  profile = fs.mkdtempSync(path.join(os.tmpdir(), 'e2e-chromium-'));

  async launch() {
    // A store-built browser carries its own libraries: an LD_LIBRARY_PATH inherited from the host
    // mixes two glibcs, and chromium dies before it listens.
    const { LD_LIBRARY_PATH: _, ...env } = process.env;
    this.process = spawn(CHROMIUM!, [
      '--headless=new',
      '--remote-debugging-port=0',
      `--user-data-dir=${this.profile}`,
      '--no-first-run',
      '--no-default-browser-check',
      'about:blank',
    ], { env });
    const endpoint = await new Promise<string>((resolve, reject) => {
      let log = '';
      this.process.stderr!.on('data', (chunk: Buffer) => {
        log += chunk;
        const match = /DevTools listening on (ws:\/\/\S+)/.exec(log);
        if (match) resolve(match[1]!);
      });
      this.process.on('exit', () => reject(new Error(`chromium exited:\n${log}`)));
    });
    this.socket = new WebSocket(endpoint);
    await new Promise((resolve) => this.socket.addEventListener('open', resolve, { once: true }));
    this.socket.addEventListener('message', (event) => {
      const message = JSON.parse(String(event.data));
      if (message.id !== undefined) {
        const waiter = this.pending.get(message.id)!;
        this.pending.delete(message.id);
        if (message.error) waiter.reject(new Error(message.error.message));
        else waiter.resolve(message.result);
      } else for (const listener of this.listeners) listener(message.method, message.params);
    });
    await this.send('Target.setDiscoverTargets', { discover: true }, false);
    const { targetId } = await this.send('Target.createTarget', { url: 'about:blank' }, false);
    ({ sessionId: this.session } = await this.send('Target.attachToTarget', { targetId, flatten: true }, false));
    await this.send('Page.enable');
    await this.send('Runtime.enable');
  }

  send(method: string, params: object = {}, inPage = true): Promise<any> {
    const id = ++this.next;
    this.socket.send(JSON.stringify({ id, method, params, ...(inPage && { sessionId: this.session }) }));
    return new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
  }

  on(listener: (method: string, params: any) => void) {
    this.listeners.push(listener);
    return () => (this.listeners = this.listeners.filter((l) => l !== listener));
  }

  async evaluate<T = unknown>(expression: string): Promise<T> {
    const { result, exceptionDetails } = await this.send('Runtime.evaluate', {
      expression,
      awaitPromise: true,
      returnByValue: true,
    });
    if (exceptionDetails) throw new Error(`${expression}: ${exceptionDetails.exception?.description}`);
    return result.value as T;
  }

  /** Polls every 50ms until the expression is truthy, one poll after the other. */
  async waitFor(expression: string, timeout = 10_000, deadline = Date.now() + timeout): Promise<void> {
    if (await this.evaluate<boolean>(`Boolean(${expression})`)) return;
    if (Date.now() > deadline) throw new Error(`timed out waiting for ${expression}`);
    await new Promise((r) => setTimeout(r, 50));
    return this.waitFor(expression, timeout, deadline);
  }

  async goto(url: string) {
    const loaded = new Promise<void>((resolve) => {
      const off = this.on((method) => {
        if (method === 'Page.loadEventFired') {
          off();
          resolve();
        }
      });
    });
    await this.send('Page.navigate', { url });
    await loaded;
  }

  async viewport(width: number, height: number, mobile = false) {
    await this.send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile });
  }

  /** A TRUSTED click at the element's center, so the browser applies its own modifier rules. */
  async click(selector: string, modifiers = 0) {
    await this.evaluate(`document.querySelector(${JSON.stringify(selector)}).scrollIntoView({block: 'center'})`);
    const { x, y } = await this.evaluate<{ x: number; y: number }>(
      `(() => { const r = document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect();
        return { x: r.left + Math.min(r.width / 2, 20), y: r.top + r.height / 2 }; })()`,
    );
    const mouse = { x, y, button: 'left', clickCount: 1, modifiers };
    await this.send('Input.dispatchMouseEvent', { type: 'mousePressed', ...mouse });
    await this.send('Input.dispatchMouseEvent', { type: 'mouseReleased', ...mouse });
  }

  async key(key: string) {
    const codes: Record<string, number> = { Escape: 27, Enter: 13, ArrowDown: 40, ArrowUp: 38, ArrowRight: 39, ArrowLeft: 37 };
    const event = { key, code: key, windowsVirtualKeyCode: codes[key] };
    await this.send('Input.dispatchKeyEvent', { type: 'keyDown', ...event });
    await this.send('Input.dispatchKeyEvent', { type: 'keyUp', ...event });
  }

  async type(text: string) {
    await this.send('Input.insertText', { text });
  }

  async close() {
    this.socket?.close();
    // The profile is removed only once chromium stopped writing to it.
    const exited = new Promise((resolve) => this.process.once('exit', resolve));
    this.process?.kill();
    await exited;
    fs.rmSync(this.profile, { recursive: true, force: true });
  }
}

const browser = new Browser();
let server: http.Server;
let origin: string;

const PREVIEW = 'aside[aria-label^="Source of"]';
const filesTab = '#source-tab-files';
const row = (file: string) => `[role="treeitem"][title^="${file}:"]`;
const resources = (part: string) =>
  `performance.getEntriesByType('resource').filter((e) => e.name.includes(${JSON.stringify(part)})).length`;

async function openFilesTab() {
  await browser.waitFor(`document.querySelector('${filesTab}')`);
  if ((await browser.evaluate(`document.querySelector('${filesTab}').getAttribute('aria-selected')`)) !== 'true') {
    await browser.click(filesTab);
  }
  await browser.waitFor(`document.querySelector('#source-panel-files')`);
}

before(async () => {
  server = await serve(path.resolve(SITE));
  origin = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  await browser.launch();
});
after(async () => {
  await browser.close();
  server.closeAllConnections();
  server.close();
});

describe('desktop', { timeout: 120_000 }, () => {
  before(async () => {
    await browser.viewport(1440, 900);
    await browser.goto(`${origin}/notes/desktop/hypr/`);
  });

  it('loads the manifest and nothing heavier until a file is opened', async () => {
    await openFilesTab();
    assert.equal(await browser.evaluate(resources('/_source/pages/notes/desktop/hypr.json')), 1);
    assert.equal(await browser.evaluate(resources('/_source/files/')), 0);
  });

  it('shows the real files of the Hyprland page in a tree', async () => {
    await browser.waitFor(`document.querySelector('[role="tree"]')`);
    const files = [
      'modules/home/desktop/hypr.nix',
      'modules/home/desktop/hypr/hyprland.lua',
      'modules/home/desktop/hypr/lua/keybinds.lua',
    ];
    const found = await browser.evaluate<boolean[]>(
      `${JSON.stringify(files)}.map((file) => Boolean(document.querySelector(\`[role="treeitem"][title^="\${file}:"]\`)))`,
    );
    assert.deepEqual(found, [true, true, true]);
  });

  it('folds and unfolds a folder, and filters by name', async () => {
    const folder = `[role="treeitem"][aria-expanded][title="modules/home/desktop/hypr/lua/"]`;
    await browser.waitFor(`document.querySelector('${folder}')`);
    const initial = await browser.evaluate(`document.querySelector('${folder}').getAttribute('aria-expanded')`);
    await browser.click(folder);
    await browser.waitFor(`document.querySelector('${folder}').getAttribute('aria-expanded') !== '${initial}'`);
    await browser.click(folder);

    await browser.click('#source-toc input[type="search"]');
    await browser.type('keybinds');
    await browser.waitFor(`document.querySelectorAll('#source-toc [role="treeitem"]:not([aria-expanded])').length === 1`);
    await browser.evaluate(`(() => { const i = document.querySelector('#source-toc input[type="search"]');
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(i, '');
      i.dispatchEvent(new Event('input', { bubbles: true })); })()`);
  });

  it('opens a file from the keyboard, highlighted, without moving the page', async () => {
    await browser.evaluate('window.scrollTo(0, 600)');
    const scrolled = await browser.evaluate<number>('window.scrollY');
    await browser.evaluate(`document.querySelector('${row('modules/home/desktop/hypr.nix')}').focus()`);
    await browser.key('Enter');
    await browser.waitFor(`document.querySelector('${PREVIEW}')`);
    // Highlighted means shiki ran: the tokens carry its theme variables.
    await browser.waitFor(`document.querySelector('${PREVIEW} [style*="--shiki"]')`);
    assert.ok(await browser.evaluate(`document.querySelector('${PREVIEW} figure[data-line-numbers], ${PREVIEW} [data-line-numbers]') !== null`));
    assert.equal(await browser.evaluate('new URLSearchParams(location.search).get("source")'), 'modules/home/desktop/hypr.nix');
    assert.equal(await browser.evaluate<number>('window.scrollY'), scrolled);
    assert.equal(await browser.evaluate(resources('/_source/files/')), 1);
  });

  it('closes with Escape, gives focus back, and leaves the URL and the scroll as they were', async () => {
    const scrolled = await browser.evaluate<number>('window.scrollY');
    await browser.key('Escape');
    await browser.waitFor(`!document.querySelector('${PREVIEW}')`);
    assert.equal(await browser.evaluate('location.search'), '');
    assert.equal(await browser.evaluate<number>('window.scrollY'), scrolled);
    assert.equal(
      await browser.evaluate(`document.activeElement?.getAttribute('title')?.startsWith('modules/home/desktop/hypr.nix')`),
      true,
    );
  });

  it('keeps a modified click on a source link for the browser', async () => {
    const link = 'a[data-source-preview][href*="/blob/"]';
    await browser.waitFor(`document.querySelector('${link}')`);
    // Without JS the link is the blob URL itself, which is the fallback.
    assert.match(await browser.evaluate<string>(`document.querySelector('${link}').href`), /^https:\/\/github\.com\/.+\/blob\//);
    const opened: string[] = [];
    const off = browser.on((method, params) => {
      if (method === 'Target.targetCreated' || method === 'Target.targetInfoChanged') opened.push(params.targetInfo.url);
    });
    await browser.click(link, 2 /* Ctrl */);
    await new Promise((r) => setTimeout(r, 500));
    off();
    assert.equal(await browser.evaluate(`Boolean(document.querySelector('${PREVIEW}'))`), false);
    assert.ok(opened.some((url) => url.startsWith('https://github.com/')), `opened: ${opened}`);
  });

  it('opens a plain click on a source link, and on a resolved inline path', async () => {
    await browser.click('a[data-source-preview][href*="/blob/"]');
    await browser.waitFor(`document.querySelector('${PREVIEW}')`);
    await browser.key('Escape');
    await browser.waitFor(`!document.querySelector('${PREVIEW}')`);

    // `autostart.lua` is a bare name the index resolved inside the page's own module.
    const code = 'a[data-source-preview] > code';
    assert.ok(await browser.evaluate(`[...document.querySelectorAll('${code}')].some((c) => c.textContent === 'autostart.lua')`));
    // `hyprctl reload` is code, not a path, and stays exactly that.
    assert.ok(await browser.evaluate(`[...document.querySelectorAll('code')].some((c) => c.textContent.startsWith('hyprctl') && !c.closest('a'))`));
  });

  it('opens a deep link at its line, and ignores one this page does not list', async () => {
    await browser.goto(`${origin}/notes/desktop/hypr/?source=modules/home/desktop/hypr/lua/keybinds.lua&line=5`);
    await browser.waitFor(`document.querySelector('${PREVIEW} .highlighted[data-line="5"]')`);
    await browser.key('Escape');

    await browser.goto(`${origin}/notes/desktop/hypr/?source=../../secrets/secrets.yaml`);
    await openFilesTab();
    await new Promise((r) => setTimeout(r, 300));
    assert.equal(await browser.evaluate(`Boolean(document.querySelector('${PREVIEW}'))`), false);
    assert.equal(await browser.evaluate(resources('secrets')), 0);
  });

  it('marks the files of the section on screen without moving the selection', async () => {
    await browser.evaluate(`document.getElementById('the-remote-access-safety-net').scrollIntoView()`);
    await browser.waitFor(
      `document.querySelector('${row('modules/home/desktop/hypr/lua/autostart.lua')}')?.textContent.includes('cited in the section on screen')`,
    );
  });

  it('follows a navigation to another page', async () => {
    await browser.evaluate(`document.querySelector('#nd-sidebar a[href="/notes/desktop/vicinae/"]').click()`);
    await browser.waitFor(`location.pathname === '/notes/desktop/vicinae/'`);
    await browser.waitFor(`document.querySelector('${row('modules/home/desktop/vicinae/default.nix')}')`);
    assert.equal(await browser.evaluate(`Boolean(document.querySelector('${row('modules/home/desktop/hypr.nix')}'))`), false);
  });

  it('shows Quickshell and Caddy their modules, and a page with none an empty state', async () => {
    await browser.goto(`${origin}/notes/desktop/quickshell/`);
    await openFilesTab();
    await browser.waitFor(`document.querySelector('${row('modules/home/desktop/quickshell.nix')}')`);

    await browser.goto(`${origin}/notes/network/caddy/`);
    await openFilesTab();
    await browser.waitFor(`document.querySelector('${row('modules/nixos/services/caddy.nix')}')`);

    await browser.goto(`${origin}/notes/repo/license/`);
    await openFilesTab();
    await browser.waitFor(`document.querySelector('#source-panel-files')?.textContent.includes('cites no source files')`);
  });

  it('respects reduced motion', async () => {
    await browser.send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-reduced-motion', value: 'reduce' }] });
    await browser.goto(`${origin}/notes/network/caddy/?source=modules/nixos/services/caddy.nix`);
    await browser.waitFor(`document.querySelector('${PREVIEW}')`);
    assert.equal(await browser.evaluate(`getComputedStyle(document.querySelector('${PREVIEW}')).animationName`), 'none');
    await browser.send('Emulation.setEmulatedMedia', { features: [] });
    await browser.key('Escape');
  });
});

describe('mobile', { timeout: 60_000 }, () => {
  before(async () => {
    await browser.viewport(390, 844, true);
    await browser.goto(`${origin}/notes/desktop/hypr/`);
  });

  it('opens the tree in a drawer and the preview full width, with no sideways scroll', async () => {
    const button = '#source-files-button';
    // `offsetParent` is always null for a fixed element, so visibility is read off its style.
    await browser.waitFor(`(() => { const b = document.querySelector('${button}'); return b && getComputedStyle(b).display !== 'none'; })()`);
    await browser.click(button);
    await browser.waitFor(`document.querySelector('dialog.source-drawer')?.open`);
    await browser.click(`dialog.source-drawer ${row('modules/home/desktop/hypr.nix')}`);
    await browser.waitFor(`document.querySelector('${PREVIEW}')`);
    assert.equal(await browser.evaluate(`Math.round(document.querySelector('${PREVIEW}').getBoundingClientRect().width)`), 390);
    assert.equal(await browser.evaluate(`document.querySelector('dialog.source-drawer').open`), false);
    assert.ok(await browser.evaluate<boolean>('document.documentElement.scrollWidth <= window.innerWidth'));
    await browser.click(`${PREVIEW} button[aria-label^="Close"]`);
    await browser.waitFor(`!document.querySelector('${PREVIEW}')`);
  });
});
