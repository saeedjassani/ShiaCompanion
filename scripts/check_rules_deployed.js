// Fails when the security rules live in production differ from the ones on
// this checkout, i.e. a rules change was merged but never deployed (or the
// console was edited without the change coming back to git).
//
// Run by .github/workflows/rules-deployed.yml. Needs a service-account key in
// GOOGLE_APPLICATION_CREDENTIALS with two read-only roles: Firebase Rules
// Viewer (Firestore) and Firebase Realtime Database Viewer. See "Security
// rules" in docs/CI.md.
//
//   GOOGLE_APPLICATION_CREDENTIALS=key.json node scripts/check_rules_deployed.js
//
// No npm dependencies: the token is minted from the key by hand, so CI needs
// nothing but Node.

const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const PROJECT_ID = 'shia-comapnion';
const DATABASE_URL = 'https://shia-comapnion.firebaseio.com';
const SCOPES = [
  'https://www.googleapis.com/auth/cloud-platform',
  'https://www.googleapis.com/auth/firebase.database',
  'https://www.googleapis.com/auth/userinfo.email',
];

async function accessToken(keyPath) {
  const key = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
  const now = Math.floor(Date.now() / 1000);
  const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
  const unsigned = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64({
    iss: key.client_email,
    scope: SCOPES.join(' '),
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 600,
  })}`;
  const signature = crypto
    .createSign('RSA-SHA256')
    .update(unsigned)
    .sign(key.private_key, 'base64url');
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${signature}`,
    }),
  });
  if (!res.ok) {
    throw new Error(`Token exchange failed: ${res.status} ${await res.text()}`);
  }
  return { token: (await res.json()).access_token, email: key.client_email };
}

async function get(url, token, roleHint) {
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (res.status === 401 || res.status === 403) {
    throw new Error(
      `${res.status} reading ${url}. The service account needs the ` +
        `"${roleHint}" role in Google Cloud IAM (see docs/CI.md).`,
    );
  }
  if (!res.ok) throw new Error(`${res.status} reading ${url}: ${await res.text()}`);
  return res.text();
}

async function liveFirestoreRules(token) {
  const base = 'https://firebaserules.googleapis.com/v1';
  const role = 'Firebase Rules Viewer';
  const release = JSON.parse(
    await get(`${base}/projects/${PROJECT_ID}/releases/cloud.firestore`, token, role),
  );
  const ruleset = JSON.parse(await get(`${base}/${release.rulesetName}`, token, role));
  const files = ruleset.source.files;
  return (files.find((f) => f.name === 'firestore.rules') || files[0]).content;
}

async function liveDatabaseRules(token) {
  try {
    return await get(
      `${DATABASE_URL}/.settings/rules.json`,
      token,
      'Firebase Realtime Database Viewer',
    );
  } catch (e) {
    // Tell "no database access at all" from "can read data, not rules".
    const probe = await fetch(`${DATABASE_URL}/.json?shallow=true`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    throw new Error(
      `${e.message} Probe: reading the database root as this account ` +
        `returned ${probe.status}${probe.ok ? ', so it can read data but not rules' : ''}.`,
    );
  }
}

// The console and the CLI both keep the source as uploaded, so only line
// endings and trailing whitespace are allowed to differ.
function normalize(text) {
  return (
    text
      .replace(/\r\n/g, '\n')
      .split('\n')
      .map((line) => line.trimEnd())
      .join('\n')
      .trimEnd() + '\n'
  );
}

// Prints a unified diff and returns whether the two match.
function compare(label, repoPath, deployTarget, live) {
  const repo = normalize(fs.readFileSync(path.join(ROOT, repoPath), 'utf8'));
  live = normalize(live);
  if (repo === live) {
    console.log(`OK    ${label}: live rules match ${repoPath}`);
    return true;
  }
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rules-'));
  const liveFile = path.join(dir, `live-${path.basename(repoPath)}`);
  const repoFile = path.join(dir, `repo-${path.basename(repoPath)}`);
  fs.writeFileSync(liveFile, live);
  fs.writeFileSync(repoFile, repo);
  const diff = spawnSync('diff', ['-u', liveFile, repoFile], { encoding: 'utf8' });
  fs.rmSync(dir, { recursive: true, force: true });
  console.log(
    `::error file=${repoPath}::${label} rules live in production differ from ` +
      `${repoPath}. Deploy them with: firebase deploy --only ${deployTarget}`,
  );
  console.log(`--- live (production)\n+++ ${repoPath} (this commit)`);
  console.log(diff.stdout.split('\n').slice(2).join('\n'));
  return false;
}

async function main() {
  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!keyPath) {
    console.error('Set GOOGLE_APPLICATION_CREDENTIALS to a service-account key.');
    process.exit(2);
  }
  const config = JSON.parse(fs.readFileSync(path.join(ROOT, 'firebase.json'), 'utf8'));
  const { token, email } = await accessToken(keyPath);
  console.log(`Reading live rules of ${PROJECT_ID} as ${email}\n`);

  const checks = [];
  if (config.firestore && config.firestore.rules) {
    checks.push(['Firestore', config.firestore.rules, 'firestore:rules', () => liveFirestoreRules(token)]);
  }
  if (config.database && config.database.rules) {
    checks.push(['Realtime Database', config.database.rules, 'database', () => liveDatabaseRules(token)]);
  }

  let ok = true;
  for (const [label, repoPath, deployTarget, live] of checks) {
    try {
      ok = compare(label, repoPath, deployTarget, await live()) && ok;
    } catch (e) {
      console.log(`::error::${label}: ${e.message}`);
      ok = false;
    }
  }
  process.exit(ok ? 0 : 1);
}

if (require.main === module) {
  main().catch((e) => {
    console.log(`::error::${e.message}`);
    process.exit(1);
  });
}

module.exports = { normalize, compare };
