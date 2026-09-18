// Regenerates scripts/favorited_missing_zikrs.json: which zikr UIDs that no
// longer exist in assets/zikr.json are actually favorited by real users, and
// by how many. Needs Firestore admin access (scripts/serviceAccountKey.json)
// — run this locally and commit the resulting JSON so remote/cloud sessions
// without that key can still see the list. See scripts/RESTORING_MISSING_ZIKRS.md
// for how this feeds the restoration priority order.
//
// Usage: node scripts/query_favorited_missing_zikrs.js
//
// Method:
//   1. Union every historical assets/zikr.json version's keys (git log
//      --follow over all commits touching that file), minus the current
//      file's keys, to get the full "missing" uid list.
//   2. Collection-group query over every users/{uid}/favorites/index doc
//      (one query, all users - see favorites-firestore-path project memory).
//   3. Canonicalize each type:0 (zikr) favorite's uid (alias uids are
//      "aliasUid|targetUid" - split on the trailing "|") and count how many
//      distinct users / favorite-entries land on each missing uid.
//   4. Annotate uids already covered by lib/data/retired_zikr_redirects.dart
//      - those should NOT get a standalone assets/zikr/<uid> restoration.

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const admin = require('firebase-admin');

const REPO_ROOT = path.join(__dirname, '..');

function getServiceAccountPath() {
  const envPath = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
  if (envPath && fs.existsSync(envPath)) return envPath;
  const candidates = [
    path.join(__dirname, 'serviceAccountKey.json'),
    path.join(REPO_ROOT, 'serviceAccountKey.json'),
  ];
  return candidates.find((c) => fs.existsSync(c));
}

function canonicalizeFavoriteUid(uid) {
  return uid.includes('|') ? uid.split('|').pop().trim() : uid;
}

function regenerateMissingUidList() {
  const commits = execSync('git log --follow --format=%H -- assets/zikr.json', {
    cwd: REPO_ROOT,
    encoding: 'utf8',
  }).trim().split('\n').filter(Boolean);

  const titleByUid = {};
  const unionKeys = new Set();
  for (const commit of commits) {
    let content;
    try {
      content = execSync(`git show ${commit}:assets/zikr.json`, {
        cwd: REPO_ROOT,
        encoding: 'utf8',
        maxBuffer: 1024 * 1024 * 50,
      });
    } catch {
      continue; // path didn't exist at this point in history (rename, etc.)
    }
    let obj;
    try {
      obj = JSON.parse(content);
    } catch {
      continue;
    }
    for (const [uid, val] of Object.entries(obj)) {
      unionKeys.add(uid);
      if (titleByUid[uid]) continue;
      if (val && typeof val === 'object' && val.title) titleByUid[uid] = val.title;
      else if (typeof val === 'string') titleByUid[uid] = val;
    }
  }

  const current = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'assets/zikr.json'), 'utf8'));
  const currentKeys = new Set(Object.keys(current));
  const missing = [...unionKeys].filter((k) => !currentKeys.has(k));
  return { missing, titleByUid };
}

function loadRetiredRedirects() {
  // Parsed out of the Dart source rather than duplicated by hand, so this
  // stays in sync with lib/data/retired_zikr_redirects.dart automatically.
  const src = fs.readFileSync(
    path.join(REPO_ROOT, 'lib/data/retired_zikr_redirects.dart'),
    'utf8'
  );
  const redirects = {};
  const re = /'([^']+)':\s*RetiredZikrRedirect\('([^']+)'(?:,\s*tabIndex:\s*(\d+))?\)/g;
  let m;
  while ((m = re.exec(src))) {
    const [, uid, targetUid, tabIndex] = m;
    redirects[uid] = tabIndex !== undefined ? `${targetUid}[${tabIndex}]` : targetUid;
  }
  return redirects;
}

async function main() {
  const serviceAccountPath = getServiceAccountPath();
  if (!serviceAccountPath) {
    throw new Error('Could not find serviceAccountKey.json (checked scripts/ and repo root).');
  }
  const serviceAccount = require(path.resolve(serviceAccountPath));
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const db = admin.firestore();

  const { missing, titleByUid } = regenerateMissingUidList();
  const missingSet = new Set(missing);
  console.log(`Missing-uid list regenerated: ${missing.length} uids.`);

  const snap = await db.collectionGroup('favorites').get();
  console.log(`Scanned ${snap.size} favorites docs.`);

  const counts = {};
  let totalUsersWithAnyFavorites = 0;
  let totalFavoriteEntriesOnMissingUids = 0;
  const usersHittingBug = new Set();

  snap.forEach((doc) => {
    if (doc.id !== 'index') return;
    const entries = Array.isArray(doc.data().entries) ? doc.data().entries : [];
    if (entries.length === 0) return;
    totalUsersWithAnyFavorites++;
    const userId = doc.ref.parent.parent.id;
    for (const e of entries) {
      if (!e || e.type !== 0 || !e.uid) continue;
      const canon = canonicalizeFavoriteUid(String(e.uid));
      if (!missingSet.has(canon)) continue;
      totalFavoriteEntriesOnMissingUids++;
      usersHittingBug.add(userId);
      if (!counts[canon]) counts[canon] = { entries: 0, users: new Set() };
      counts[canon].entries++;
      counts[canon].users.add(userId);
    }
  });

  const redirects = loadRetiredRedirects();
  const results = Object.entries(counts)
    .map(([uid, v]) => ({
      uid,
      title: titleByUid[uid] || null,
      favoriteEntries: v.entries,
      distinctUsers: v.users.size,
      note: redirects[uid]
        ? `already retired to ${redirects[uid]} via retiredZikrRedirects — skip standalone restore`
        : '',
    }))
    .sort(
      (a, b) =>
        b.distinctUsers - a.distinctUsers ||
        b.favoriteEntries - a.favoriteEntries ||
        a.uid.localeCompare(b.uid)
    );

  const out = {
    generatedAt: new Date().toISOString(),
    method:
      "collectionGroup('favorites') over every users/{uid}/favorites/index doc, filtered to type:0 (zikr) entries whose canonicalized uid (alias split on trailing '|') is in the missing-uid list (git history union of every historical assets/zikr.json version's keys, minus the current file's keys). Regenerate with scripts/query_favorited_missing_zikrs.js.",
    totalUsersWithAnyFavorites,
    totalUsersHittingMissingZikrBug: usersHittingBug.size,
    totalFavoriteEntriesOnMissingUids,
    distinctMissingUidsFavorited: results.length,
    totalMissingUidsChecked: missing.length,
    alreadyRetiredSkipStandaloneRestore: redirects,
    results,
  };

  const outPath = path.join(__dirname, 'favorited_missing_zikrs.json');
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
  console.log(`Wrote ${outPath}`);
  console.log(
    `${results.length} missing uids favorited by >=1 user, ${totalFavoriteEntriesOnMissingUids} favorite-entries, ${usersHittingBug.size}/${totalUsersWithAnyFavorites} users affected.`
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
