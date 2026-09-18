/**
 * Writes the approved rows of duas_audio_map.json onto assets/zikr/<uid> as
 * an `audio` array. Run import_duas_audio.js first, review the map, flip
 * `"approved": true` on the rows you accept, then run this.
 *
 * assets/zikr/<uid> is the source of truth - see
 * scripts/RESTORING_MISSING_ZIKRS.md - so this writes it directly; there is
 * no separate build/regenerate step afterwards.
 *
 * Usage:
 *   node apply_duas_audio.js                    # dry run, prints the diff
 *   node apply_duas_audio.js --store            # write assets/zikr/<uid>
 *   node apply_duas_audio.js --only G4 --store  # write one zikr only
 *   node apply_duas_audio.js --clear            # remove the audio field
 */

const fs = require('fs');
const path = require('path');

const ZIKR_DIR = path.join(__dirname, '..', 'assets', 'zikr');
const MAP_FILE = path.join(__dirname, 'duas_audio_map.json');

const argv = process.argv.slice(2);
const args = new Set(argv);
const STORE = args.has('--store');
const CLEAR = args.has('--clear');

/** Restricts the write to specific uids, for rolling one zikr out at a time. */
const ONLY = (() => {
  const at = argv.indexOf('--only');
  if (at === -1) return null;
  const uids = argv.slice(at + 1).filter((a) => !a.startsWith('--'));
  if (!uids.length) throw new Error('--only needs at least one uid, e.g. --only G4');
  return new Set(uids);
})();

/** Several approved pages can point at one zikr, so tracks are merged and
 * de-duplicated by URL rather than the last page winning. */
function buildAudioByUid(rows) {
  const byUid = new Map();
  for (const row of rows) {
    if (row.approved !== true || !row.uid) continue;
    if (ONLY && !ONLY.has(row.uid)) continue;
    const list = byUid.get(row.uid) || [];
    for (const track of row.tracks || []) {
      const url = `${track?.url ?? ''}`.trim();
      if (!url.startsWith('https://')) continue;
      if (list.some((t) => t.url === url)) continue;
      const entry = {url};
      const label = `${track?.label ?? ''}`.trim();
      if (label) entry.label = label;
      list.push(entry);
    }
    if (list.length) byUid.set(row.uid, list);
  }
  return byUid;
}

function readLocal(uid) {
  const p = path.join(ZIKR_DIR, uid);
  if (!fs.existsSync(p)) return null;
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function writeLocal(uid, doc) {
  fs.writeFileSync(path.join(ZIKR_DIR, uid), `${JSON.stringify(doc, null, 2)}\n`, 'utf8');
}

function main() {
  if (!fs.existsSync(MAP_FILE)) {
    throw new Error(`${path.basename(MAP_FILE)} not found. Run import_duas_audio.js first.`);
  }
  const map = JSON.parse(fs.readFileSync(MAP_FILE, 'utf8'));
  const rows = map.rows || [];

  if (CLEAR) {
    const targets = fs.readdirSync(ZIKR_DIR).filter((uid) => {
      if (!fs.statSync(path.join(ZIKR_DIR, uid)).isFile()) return false;
      const doc = readLocal(uid);
      return doc?.audio !== undefined;
    });
    console.log(`${targets.length} files carry an audio field`);
    if (!STORE) {
      console.log('Dry run. Re-run with --store --clear to remove.');
      return;
    }
    for (const uid of targets) {
      const doc = readLocal(uid);
      delete doc.audio;
      writeLocal(uid, doc);
    }
    console.log(`Cleared audio from ${targets.length} files`);
    return;
  }

  const byUid = buildAudioByUid(rows);
  const approvedRows = rows.filter((r) => r.approved === true && r.uid);
  console.log(`Approved rows: ${approvedRows.length} -> ${byUid.size} zikrs, `
    + `${[...byUid.values()].reduce((n, l) => n + l.length, 0)} tracks`);

  if (!byUid.size) {
    console.log('Nothing approved. Set "approved": true on rows you accept.');
    return;
  }

  // Verify every target exists before writing, so a stale uid in the map
  // surfaces as an error rather than creating a junk file.
  const missing = [...byUid.keys()].filter((uid) => !fs.existsSync(path.join(ZIKR_DIR, uid)));
  if (missing.length) {
    throw new Error(`These uids have no assets/zikr/<uid> file: ${missing.join(', ')}`);
  }

  for (const [uid, tracks] of byUid) {
    console.log(`  ${uid}: ${tracks.length} track(s)`);
    for (const t of tracks) console.log(`      ${t.label || '(untitled)'} - ${t.url}`);
  }

  if (!STORE) {
    console.log('\nDry run. Re-run with --store to write assets/zikr/<uid>.');
    return;
  }

  let written = 0;
  for (const [uid, tracks] of byUid) {
    const doc = readLocal(uid);
    doc.audio = tracks;
    writeLocal(uid, doc);
    written += 1;
  }
  console.log(`\nWrote audio to ${written} zikr files.`);
}

try {
  main();
} catch (e) {
  console.error(e.message || e);
  process.exit(1);
}
