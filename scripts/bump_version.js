const fs = require('fs');
const path = require('path');

const PUBSPEC_PATH = path.join(__dirname, '..', 'pubspec.yaml');

function main() {
  const content = fs.readFileSync(PUBSPEC_PATH, 'utf8');
  const match = content.match(/^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$/m);

  if (!match) {
    console.error('Could not parse version from pubspec.yaml');
    process.exit(1);
  }

  const major = parseInt(match[1], 10);
  const minor = parseInt(match[2], 10);
  const patch = parseInt(match[3], 10);
  const build = parseInt(match[4], 10);

  const newVersion = `${major}.${minor}.${patch + 1}+${build + 1}`;

  const updated = content.replace(
    /^version:\s*\d+\.\d+\.\d+\+\d+\s*$/m,
    `version: ${newVersion}`,
  );

  fs.writeFileSync(PUBSPEC_PATH, updated, 'utf8');
  console.log(`Version bumped: ${match[0].trim()} → version: ${newVersion}`);
}

main();