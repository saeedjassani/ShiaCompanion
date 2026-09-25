/**
 * Writes the approved rows of duas_audio_map.json into assets/zikr_audio.json,
 * the one place zikr recordings are listed. Run import_duas_audio.js first,
 * review the map, flip `"approved": true` on the rows you accept, then run
 * this.
 *
 * All audio is served from the app's own R2 bucket, never hot-linked, so each
 * track is written as an R2 file name (`<uid>_<source file name>`) and the
 * run prints which duas.org file to upload under which name. Upload them
 * before merging: the app builds every URL from the file name.
 *
 * Usage:
 *   node apply_duas_audio.js                    # dry run, prints the diff
 *   node apply_duas_audio.js --store            # write assets/zikr_audio.json
 *   node apply_duas_audio.js --only G4 --store  # write one zikr only
 *   node apply_duas_audio.js --clear --store    # remove entries (--only's, or all)
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

const AUDIO_FILE = path.join(__dirname, '..', 'assets', 'zikr_audio.json');

function readAudio() {
  return fs.existsSync(AUDIO_FILE) ? JSON.parse(fs.readFileSync(AUDIO_FILE, 'utf8')) : {};
}

function writeAudio(audio) {
  fs.writeFileSync(AUDIO_FILE, `${JSON.stringify(audio, null, 2)}\n`, 'utf8');
}

/** The R2 name for a duas.org track: its own file name, prefixed with the
 * uid and made URL-safe, e.g. `e26_simaatabather.mp3`. */
function r2FileName(uid, url) {
  const base = decodeURIComponent(url.split('/').pop() || 'track.mp3');
  const safe = base.toLowerCase().replace(/[^a-z0-9.]+/g, '-').replace(/^-+|-+$/g, '');
  return `${uid.toLowerCase()}_${safe}`;
}

function main() {
  if (!fs.existsSync(MAP_FILE)) {
    throw new Error(`${path.basename(MAP_FILE)} not found. Run import_duas_audio.js first.`);
  }
  const map = JSON.parse(fs.readFileSync(MAP_FILE, 'utf8'));
  const rows = map.rows || [];

  if (CLEAR) {
    const audio = readAudio();
    const targets = Object.keys(audio).filter((uid) => !ONLY || ONLY.has(uid));
    console.log(`${targets.length} zikrs to clear from assets/zikr_audio.json`);
    if (!STORE) {
      console.log('Dry run. Re-run with --store --clear to remove.');
      return;
    }
    for (const uid of targets) delete audio[uid];
    writeAudio(audio);
    console.log(`Cleared audio for ${targets.length} zikrs`);
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
    for (const t of tracks) {
      console.log(`      ${t.label || '(untitled)'} - ${t.url} -> R2 ${r2FileName(uid, t.url)}`);
    }
  }

  if (!STORE) {
    console.log('\nDry run. Re-run with --store to write assets/zikr_audio.json.');
    return;
  }

  const audio = readAudio();
  for (const [uid, tracks] of byUid) {
    audio[uid] = tracks.map((t) => ({
      file: r2FileName(uid, t.url),
      ...(t.label ? {label: t.label} : {}),
    }));
  }
  writeAudio(audio);
  console.log(`\nWrote audio for ${byUid.size} zikrs. Upload to R2 before merging:`);
  for (const [uid, tracks] of byUid) {
    for (const t of tracks) console.log(`  ${t.url}  ->  ${r2FileName(uid, t.url)}`);
  }
}

try {
  main();
} catch (e) {
  console.error(e.message || e);
  process.exit(1);
}
