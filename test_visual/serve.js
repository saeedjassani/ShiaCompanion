'use strict';

// Static server that mirrors the Firebase Hosting behaviour declared in
// firebase.json: real files win, everything else rewrites to /index.html.
// Visual tests run against this so a rewrite or asset-path regression shows up
// locally and in CI rather than in production.

const fs = require('fs');
const http = require('http');
const path = require('path');

const ROOT = path.resolve(process.env.WEB_BUILD_DIR || 'build/web');
const PORT = Number(process.env.PORT || 4173);

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.xml': 'application/xml',
  '.txt': 'text/plain; charset=utf-8',
  '.bin': 'application/octet-stream',
  '.symbols': 'text/plain; charset=utf-8',
};

// firebase.json pins these explicitly; mirror it so the tests exercise the
// same content types the browser sees in production.
const FORCED_CONTENT_TYPES = new Map([
  ['/apple-app-site-association', 'application/json'],
  ['/.well-known/apple-app-site-association', 'application/json'],
  ['/.well-known/assetlinks.json', 'application/json'],
  ['/sitemap.xml', 'application/xml'],
]);

function resolveWithinRoot(urlPath) {
  const decoded = decodeURIComponent(urlPath.split('?')[0].split('#')[0]);
  const candidate = path.resolve(ROOT, `.${path.posix.normalize(decoded)}`);
  // Refuse to serve anything that escapes the build directory.
  return candidate === ROOT || candidate.startsWith(`${ROOT}${path.sep}`)
    ? candidate
    : null;
}

function findFile(candidate) {
  if (!candidate || !fs.existsSync(candidate)) return null;
  const stats = fs.statSync(candidate);
  if (stats.isFile()) return candidate;
  if (stats.isDirectory()) {
    const index = path.join(candidate, 'index.html');
    if (fs.existsSync(index) && fs.statSync(index).isFile()) return index;
  }
  return null;
}

function send(res, status, filePath, forcedType) {
  const body = fs.readFileSync(filePath);
  res.writeHead(status, {
    'Content-Type':
      forcedType || MIME_TYPES[path.extname(filePath).toLowerCase()] ||
      'application/octet-stream',
    'Content-Length': body.length,
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

const server = http.createServer((req, res) => {
  const urlPath = req.url || '/';
  const pathname = urlPath.split('?')[0].split('#')[0];
  const direct = findFile(resolveWithinRoot(pathname));

  if (direct) {
    send(res, 200, direct, FORCED_CONTENT_TYPES.get(pathname));
    return;
  }

  // firebase.json: { "source": "**", "destination": "/index.html" }
  const fallback = path.join(ROOT, 'index.html');
  if (fs.existsSync(fallback)) {
    send(res, 200, fallback);
    return;
  }

  res.writeHead(404, {'Content-Type': 'text/plain; charset=utf-8'});
  res.end(`No build found at ${ROOT}. Run: flutter build web --wasm`);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Serving ${ROOT} at http://127.0.0.1:${PORT}`);
});
