'use strict';
// Serve the built web bundle, capture every screen, frame them, stop.
const path = require('path');
const {spawn, execFileSync} = require('child_process');
const {REPO, HERE, WEB_BUILD_DIR, PORT} = require('./config');

const server = spawn(process.execPath, [path.join(REPO, 'test_visual', 'serve.js')], {
  env: {...process.env, WEB_BUILD_DIR, PORT: String(PORT)},
  stdio: 'inherit',
});
const stop = () => { if (!server.killed) server.kill(); };
process.on('exit', stop); process.on('SIGINT', () => { stop(); process.exit(130); });

setTimeout(() => {
  try {
    execFileSync(process.execPath, [path.join(HERE, 'capture.js')], {stdio: 'inherit'});
    execFileSync(process.execPath, [path.join(HERE, 'build.js')], {stdio: 'inherit'});
  } finally {
    stop();
  }
}, 1200);
