#!/usr/bin/env node
// Apply a patch produced by scripts/zikr_arabic/*.py to assets/zikr/*.
//
// Patch shape:  { "<uid>": [ { "path": ["data"], "before": "...", "after": "..." } ] }
// `path` is the JSON path inside the document, as emitted by corpus.iter_strings.
//
//   node scripts/zikr_arabic/apply_patch.js patch.json --dry-run
//   node scripts/zikr_arabic/apply_patch.js patch.json
//
// Refuses to run without --dry-run unless a backup exists in .zikr-backups/.
// Every edit is verified against `before`: if the stored text has drifted the
// document is skipped and reported, never overwritten.

const fs = require('fs');
const path = require('path');

const ZIKR_DIR = path.join(__dirname, '..', '..', 'assets', 'zikr');
const DRY_RUN = process.argv.includes('--dry-run');
const patchFile = process.argv[2];

function getIn(obj, keys) {
  return keys.reduce((o, k) => (o == null ? o : o[k]), obj);
}
function setIn(obj, keys, value) {
  const last = keys[keys.length - 1];
  const parent = keys.slice(0, -1).reduce((o, k) => o[k], obj);
  parent[last] = value;
}

function main() {
  if (!patchFile) throw new Error('usage: apply_patch.js <patch.json> [--dry-run]');
  const patch = JSON.parse(fs.readFileSync(patchFile, 'utf8'));

  if (!DRY_RUN) {
    const dir = path.join(__dirname, '..', '..', '.zikr-backups');
    const has = fs.existsSync(dir) && fs.readdirSync(dir).some((f) => f.endsWith('.json'));
    if (!has) throw new Error('No backup in .zikr-backups/. Run scripts/zikr_arabic/backup.js first.');
  }

  let edits = 0, skipped = 0, docs = 0;

  for (const [uid, changes] of Object.entries(patch)) {
    const file = path.join(ZIKR_DIR, uid);
    if (!fs.existsSync(file)) { console.warn(`  ${uid}: no such file, skipped`); skipped++; continue; }

    const data = JSON.parse(fs.readFileSync(file, 'utf8'));
    let ok = true;

    for (const c of changes) {
      const current = getIn(data, c.path);
      if (current !== c.before) {
        console.warn(`  ${uid}: ${c.path.join('.')} has drifted since the patch was built, skipped`);
        ok = false; break;
      }
      setIn(data, c.path, c.after);
      edits++;
    }
    if (!ok) { skipped++; continue; }

    docs++;
    if (DRY_RUN) {
      console.log(`  [dry-run] ${uid}: ${changes.length} edit(s)`);
      continue;
    }
    fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`, 'utf8');
  }

  console.log(`\n${DRY_RUN ? '[dry-run] ' : ''}${edits} edits across ${docs} documents` +
              (skipped ? `, ${skipped} skipped` : ''));
}

main();
