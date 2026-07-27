#!/usr/bin/env node
/**
 * Day 1 metrics + static server.
 * Serves Vite build (or falls back to SPA shell) on PORT (default 3000)
 * and exposes /api/metrics + /api/demo for dashboard validation.
 */
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT || 3000);
const MODE = process.env.SERVE_MODE || 'dev'; // 'dev' | 'static'
const METRICS_FILE = path.join(__dirname, '.metrics.json');

const emptyMetrics = () => ({
  totalVotes: 0,
  clickEvents: 0,
  mainThreadBlocks: 0,
  lastBlockDurationMs: 0,
  uiFreezeDetected: false,
  responsivenessScore: 100,
  lastEventAt: null,
  demoRuns: 0,
});

function loadMetrics() {
  try {
    if (fs.existsSync(METRICS_FILE)) {
      return { ...emptyMetrics(), ...JSON.parse(fs.readFileSync(METRICS_FILE, 'utf8')) };
    }
  } catch { /* ignore */ }
  return emptyMetrics();
}

function saveMetrics(m) {
  fs.writeFileSync(METRICS_FILE, JSON.stringify(m, null, 2));
}

function scoreFromBlock(durationMs, blocks) {
  const penalty = Math.min(95, Math.round(durationMs / 100) + blocks * 5);
  return Math.max(5, 100 - penalty);
}

function runDemo() {
  const m = loadMetrics();
  const durationMs = 5000;
  m.totalVotes += 3;
  m.clickEvents += 5;
  m.mainThreadBlocks += 1;
  m.lastBlockDurationMs = durationMs;
  m.uiFreezeDetected = true;
  m.responsivenessScore = scoreFromBlock(durationMs, m.mainThreadBlocks);
  m.demoRuns += 1;
  m.lastEventAt = new Date().toISOString();
  saveMetrics(m);
  return m;
}

function sendJson(res, status, body) {
  const data = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  res.end(data);
}

function contentType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  return (
    {
      '.html': 'text/html; charset=utf-8',
      '.js': 'text/javascript; charset=utf-8',
      '.css': 'text/css; charset=utf-8',
      '.json': 'application/json',
      '.svg': 'image/svg+xml',
      '.png': 'image/png',
      '.ico': 'image/x-icon',
    }[ext] || 'application/octet-stream'
  );
}

const distDir = path.join(__dirname, 'dist');

function serveStatic(req, res) {
  let urlPath = decodeURIComponent((req.url || '/').split('?')[0]);
  if (urlPath === '/') urlPath = '/index.html';
  const filePath = path.join(distDir, urlPath);
  if (!filePath.startsWith(distDir)) {
    res.writeHead(403);
    return res.end('Forbidden');
  }
  if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
    res.writeHead(200, { 'Content-Type': contentType(filePath) });
    return fs.createReadStream(filePath).pipe(res);
  }
  // SPA fallback
  const index = path.join(distDir, 'index.html');
  if (fs.existsSync(index)) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    return fs.createReadStream(index).pipe(res);
  }
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`<!doctype html><html><body style="font-family:sans-serif;padding:2rem">
    <h1>Resilient UI Day 1</h1>
    <p>Build not found. Run <code>npm run build</code> or use start.sh (dev mode).</p>
    <pre id="m">loading…</pre>
    <button id="demo">Run Demo</button>
    <script>
      async function refresh(){ const r=await fetch('/api/metrics'); document.getElementById('m').textContent=JSON.stringify(await r.json(),null,2); }
      document.getElementById('demo').onclick=async()=>{ await fetch('/api/demo',{method:'POST'}); refresh(); };
      refresh(); setInterval(refresh,1500);
    </script>
  </body></html>`);
}

const apiServer = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
    return res.end();
  }

  const url = (req.url || '').split('?')[0];

  if (url === '/api/metrics' && req.method === 'GET') {
    return sendJson(res, 200, loadMetrics());
  }

  if (url === '/api/metrics' && req.method === 'POST') {
    let body = '';
    for await (const chunk of req) body += chunk;
    try {
      const incoming = JSON.parse(body || '{}');
      const next = { ...loadMetrics(), ...incoming };
      saveMetrics(next);
      return sendJson(res, 200, next);
    } catch {
      return sendJson(res, 400, { error: 'invalid json' });
    }
  }

  if (url === '/api/demo' && req.method === 'POST') {
    const metrics = runDemo();
    return sendJson(res, 200, { ok: true, metrics });
  }

  if (url === '/api/health') {
    return sendJson(res, 200, { ok: true, port: PORT, mode: MODE });
  }

  // In static mode this process serves files; in dev mode Vite serves UI
  if (MODE === 'static') return serveStatic(req, res);

  sendJson(res, 404, { error: 'not found', hint: 'UI is on Vite (proxied) or use SERVE_MODE=static' });
});

let viteChild = null;

function start() {
  // Prefer static if dist exists and MODE not forced to dev
  const useStatic = MODE === 'static' || (MODE !== 'dev' && fs.existsSync(path.join(distDir, 'index.html')));
  if (useStatic) {
    process.env.SERVE_MODE = 'static';
    apiServer.listen(PORT, '127.0.0.1', () => {
      console.log(`[server] static+api on http://127.0.0.1:${PORT}`);
    });
    return;
  }

  // Dev: API on 3001, Vite on PORT with proxy
  const API_PORT = Number(process.env.API_PORT || 3001);
  apiServer.listen(API_PORT, '127.0.0.1', () => {
    console.log(`[server] api on http://127.0.0.1:${API_PORT}`);
  });

  viteChild = spawn(
    process.platform === 'win32' ? 'npx.cmd' : 'npx',
    ['vite', '--port', String(PORT), '--host', '127.0.0.1', '--strictPort'],
    { cwd: __dirname, stdio: 'inherit', env: { ...process.env } },
  );
  viteChild.on('exit', (code) => {
    console.log(`[vite] exited ${code}`);
    process.exit(code ?? 0);
  });
}

function shutdown() {
  if (viteChild) viteChild.kill('SIGTERM');
  apiServer.close();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

start();
