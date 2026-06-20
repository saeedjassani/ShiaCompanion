const fs = require('fs');
const path = require('path');
const {Readable} = require('stream');
const csv = require('csv-parser');

const REPO_ROOT = path.join(__dirname, '..');
const SOURCE_PATH = path.join(REPO_ROOT, 'assets', 'hadith.csv');
const OUTPUT_DIR = path.join(REPO_ROOT, 'assets', 'hadith');
const SHARD_SIZE = 128;
const MUHARRAM_START = 2341;

function readQuotes() {
  return new Promise((resolve, reject) => {
    const quotes = [];
    const source = fs.readFileSync(SOURCE_PATH, 'utf8').replace(/^\uFEFF/, '');

    Readable.from([source])
      .pipe(csv({headers: ['quote'], strict: true}))
      .on('data', (row) => {
        const quote = `${row.quote ?? ''}`.replace(/\r/g, '').trim();
        if (quote) quotes.push(quote);
      })
      .on('error', reject)
      .on('end', () => resolve(quotes));
  });
}

function resetGeneratedFiles() {
  fs.mkdirSync(OUTPUT_DIR, {recursive: true});
  for (const entry of fs.readdirSync(OUTPUT_DIR)) {
    if (entry === 'manifest.json' || /^\d{3}\.json$/.test(entry)) {
      fs.unlinkSync(path.join(OUTPUT_DIR, entry));
    }
  }
}

async function main() {
  const quotes = await readQuotes();
  if (quotes.length <= MUHARRAM_START) {
    throw new Error(
      `Expected more than ${MUHARRAM_START} hadiths, found ${quotes.length}`,
    );
  }

  resetGeneratedFiles();
  const shardCount = Math.ceil(quotes.length / SHARD_SIZE);
  for (let index = 0; index < shardCount; index += 1) {
    const shard = quotes.slice(index * SHARD_SIZE, (index + 1) * SHARD_SIZE);
    const fileName = `${index}`.padStart(3, '0') + '.json';
    fs.writeFileSync(
      path.join(OUTPUT_DIR, fileName),
      `${JSON.stringify(shard)}\n`,
      'utf8',
    );
  }

  const manifest = {
    version: 1,
    shardSize: SHARD_SIZE,
    totalQuotes: quotes.length,
    muharramStart: MUHARRAM_START,
  };
  fs.writeFileSync(
    path.join(OUTPUT_DIR, 'manifest.json'),
    `${JSON.stringify(manifest, null, 2)}\n`,
    'utf8',
  );

  console.log(
    `Generated ${quotes.length} hadiths across ${shardCount} shards in ${OUTPUT_DIR}`,
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
