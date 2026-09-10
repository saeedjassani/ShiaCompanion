#!/usr/bin/env node
// Snapshot assets/zikr/* to a timestamped JSON file. git history already
// covers this, but a single JSON blob is what apply_patch.js/restore.js
// actually diff against, and it lets a whole batch be reverted in one move
// without walking git log across dozens of files.
//
//   node scripts/zikr_arabic/backup.js [outdir]     (default: .zikr-backups/)

const fs = require('fs');
const path = require('path');

const ZIKR_DIR = path.join(__dirname, '..', '..', 'assets', 'zikr');

function readCorpus() {
  const out = {};
  for (const uid of fs.readdirSync(ZIKR_DIR)) {
    const p = path.join(ZIKR_DIR, uid);
    if (!fs.statSync(p).isFile()) continue;
    try {
      out[uid] = JSON.parse(fs.readFileSync(p, 'utf8'));
    } catch (e) {
      console.warn(`  ${uid}: not valid JSON, skipped (${e.message})`);
    }
  }
  return out;
}

function main() {
  const outdir = process.argv[2] || path.join(__dirname, '..', '..', '.zikr-backups');
  fs.mkdirSync(outdir, { recursive: true });

  const out = readCorpus();
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const file = path.join(outdir, `zikr-${stamp}.json`);
  fs.writeFileSync(file, JSON.stringify(out, null, 1));
  console.log(`${Object.keys(out).length} documents -> ${file}`);
}

main();
