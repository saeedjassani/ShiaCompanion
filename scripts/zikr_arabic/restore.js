#!/usr/bin/env node
// Restore assets/zikr/* from a snapshot written by backup.js. Mostly
// superseded by `git checkout` on the affected files, but useful when a
// batch touched files you can no longer cleanly separate out of later
// commits, or when working from a snapshot taken mid-session.
//
//   node scripts/zikr_arabic/restore.js .zikr-backups/zikr-<stamp>.json --dry-run
//   node scripts/zikr_arabic/restore.js .zikr-backups/zikr-<stamp>.json
//   …             --only AA9,AA13        restore just these documents
//
// Only writes files whose content actually differs from what is on disk, and
// prints which fields differ. Takes a fresh backup of current state first, so
// a restore is itself revertible.

const fs = require('fs');
const path = require('path');

const ZIKR_DIR = path.join(__dirname, '..', '..', 'assets', 'zikr');
const DRY_RUN = process.argv.includes('--dry-run');
const snapFile = process.argv[2];
const onlyArg = process.argv.indexOf('--only');
const only = onlyArg > -1 ? new Set(process.argv[onlyArg + 1].split(',')) : null;

const stable = (v) => JSON.stringify(v, Object.keys(v || {}).sort());

function readLocal(uid) {
  const p = path.join(ZIKR_DIR, uid);
  if (!fs.existsSync(p)) return null;
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch (e) {
    return null;
  }
}

function readCorpus() {
  const out = {};
  for (const uid of fs.readdirSync(ZIKR_DIR)) {
    const p = path.join(ZIKR_DIR, uid);
    if (!fs.statSync(p).isFile()) continue;
    const doc = readLocal(uid);
    if (doc) out[uid] = doc;
  }
  return out;
}

function main() {
  if (!snapFile) throw new Error('usage: restore.js <snapshot.json> [--dry-run] [--only a,b]');
  const snap = JSON.parse(fs.readFileSync(snapFile, 'utf8'));

  if (!DRY_RUN) {
    const dir = path.join(__dirname, '..', '..', '.zikr-backups');
    fs.mkdirSync(dir, { recursive: true });
    const f = path.join(dir, `pre-restore-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
    fs.writeFileSync(f, JSON.stringify(readCorpus(), null, 1));
    console.log(`current state saved to ${f}\n`);
  }

  let changed = 0, same = 0;

  for (const [uid, doc] of Object.entries(snap)) {
    if (only && !only.has(uid)) continue;
    const cur = readLocal(uid);

    if (cur && stable(cur) === stable(doc)) { same++; continue; }

    const fields = [...new Set([...Object.keys(doc), ...Object.keys(cur || {})])]
      .filter((k) => JSON.stringify(doc[k]) !== JSON.stringify((cur || {})[k]));
    console.log(`  ${DRY_RUN ? '[dry-run] ' : ''}${uid}: ${fields.join(', ') || '(new)'}`);
    changed++;
    if (DRY_RUN) continue;

    fs.writeFileSync(path.join(ZIKR_DIR, uid), `${JSON.stringify(doc, null, 2)}\n`, 'utf8');
  }

  console.log(`\n${DRY_RUN ? '[dry-run] ' : ''}${changed} restored, ${same} already identical`);
}

main();
