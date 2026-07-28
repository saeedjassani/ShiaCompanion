const fs = require('fs');
const path = require('path');
const { extractFromHtml, blocksToText } = require('./extract_ziyarat_sections');

// One-off draft builder: turns the cached Najaf/Karbala shrine page scrapes
// into consolidated Zikr docs (numbered "forms" folded into ONE doc with
// tabs, per items.json's existing uid as the anchor) and writes them to the
// LOCAL asset files only (assets/zikr.json + assets/zikr/<uid>) — no
// Firestore writes. This is a review draft; the user confirms before this
// gets pushed via import_dua_from_url.js's storeDocument().

const SCRATCH =
  '/private/tmp/claude-501/-Users-saeedjassani-ShiaCompanion/2215f734-1bf3-4c3c-bdfd-08569f1d6cdc/scratchpad';
const ASSETS_DIR = path.join(__dirname, '..', 'assets');
const ZIKR_INDEX_PATH = path.join(ASSETS_DIR, 'zikr.json');
const ZIKR_DIR = path.join(ASSETS_DIR, 'zikr');

function normalizeSlug(value) {
  return `${value ?? ''}`
    .toLowerCase()
    .replace(/[^\w\s-]/g, ' ')
    .replace(/[_\s]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

function findSection(sections, tabId, subLabelIncludes) {
  return sections.find(
    (s) =>
      s.tabId === tabId &&
      (!subLabelIncludes || (s.subLabel || '').toLowerCase().includes(subLabelIncludes.toLowerCase())),
  );
}

function writeLocalZikr(uid, doc) {
  const indexEntry = { title: doc.title };
  if (doc.slug) indexEntry.slug = doc.slug;

  const index = JSON.parse(fs.readFileSync(ZIKR_INDEX_PATH, 'utf8'));
  index[uid] = indexEntry;
  fs.writeFileSync(ZIKR_INDEX_PATH, JSON.stringify(index, null, 2) + '\n');

  fs.writeFileSync(path.join(ZIKR_DIR, uid), JSON.stringify(doc, null, 2) + '\n');
  console.log(`Wrote local draft: assets/zikr/${uid} ("${doc.title}"), ${doc.tabs?.length ?? 0} extra tabs`);
}

function buildNajaf() {
  const html = fs.readFileSync(path.join(SCRATCH, 'najaf.html'), 'utf8');
  const page = extractFromHtml(html, 'https://www.duas.org/mobile/ziyarat-imam-ali-shrine.html');
  const s = page.sections;

  const first = findSection(s, 'two'); // "Ziarat 1" — First Main Form, 220 triplets
  const third = findSection(s, 'six', 'third');
  const fourth = findSection(s, 'six', 'fourth');
  const fifth = findSection(s, 'six', 'fifth');
  const sixth = findSection(s, 'six', 'sixth');
  const seventh = findSection(s, 'seven'); // Ziyarat7

  const ameenullahPath = path.join(ZIKR_DIR, 'G2');
  const ameenullah = fs.existsSync(ameenullahPath)
    ? JSON.parse(fs.readFileSync(ameenullahPath, 'utf8'))
    : null;

  if (!first || !third || !fourth || !fifth || !sixth || !seventh) {
    console.error('Najaf: missing an expected section — aborting. Found:', s.map((x) => x.subLabel || x.tabLabel));
    return;
  }

  const doc = {
    title: 'Ziyarah of Imam Ali (a.s.) — Najaf (All Forms)',
    code: '012',
    slug: normalizeSlug('ziyarah-imam-ali-najaf-all-forms'),
    data: blocksToText(first.blocks, 'First Ziyarah'),
    tabs: [
      ameenullah
        ? `Second Ziyarah — Ziyarat Ameenullah\n${ameenullah.data}`
        : blocksToText([], 'Second Ziyarah — Ziyarat Ameenullah (source: G2, not found locally)'),
      blocksToText(third.blocks, 'Third Ziyarah (by Imam Ja’far al-Sadiq)'),
      blocksToText(fourth.blocks, 'Fourth Ziyarah (by Imam Ja’far al-Sadiq)'),
      blocksToText(fifth.blocks, 'Fifth Ziyarah (by Imam Ali al-Naqi)'),
      blocksToText(sixth.blocks, 'Sixth Ziyarah (Mashhadi form)'),
      blocksToText(seventh.blocks, 'Seventh Ziyarah'),
    ],
  };

  writeLocalZikr('AK5', doc);

  // AK6: Duas after ziyarah + nafilah (Post Ziarat + Dua tabs)
  const postZiarat = findSection(s, 'four');
  const dua = findSection(s, 'foura');
  if (postZiarat && dua) {
    writeLocalZikr('AK6', {
      title: 'Duas After Ziyarah of Imam Ali (a.s.) & After Nafilah — Najaf',
      code: '012',
      slug: normalizeSlug('duas-after-ziyarah-imam-ali-najaf'),
      data: blocksToText(postZiarat.blocks, 'Post-Ziyarah Prayer & Dua'),
      tabs: [blocksToText(dua.blocks, 'Further Dua')],
    });
  }

  // AK7: Ziyarah of the Head of Imam Husayn (in tomb of Imam Ali)
  const imamHussain = findSection(s, 'five');
  if (imamHussain) {
    writeLocalZikr('AK7', {
      title: 'Ziyarah of the Head of Imam Husayn (a.s.) — At Imam Ali’s Shrine, Najaf',
      code: '012',
      slug: normalizeSlug('ziyarah-imam-hussain-head-najaf'),
      data: blocksToText(imamHussain.blocks, null),
    });
  }

  // AK15: Farewell to Imam Ali
  const farewell = findSection(s, 'sevena');
  if (farewell) {
    writeLocalZikr('AK15', {
      title: 'Bidding Farewell to Imam Ali (a.s.) — Najaf',
      code: '012',
      slug: normalizeSlug('farewell-imam-ali-najaf'),
      data: blocksToText(farewell.blocks, null),
    });
  }
}

function buildKarbala() {
  const html = fs.readFileSync(path.join(SCRATCH, 'karbala.html'), 'utf8');
  const page = extractFromHtml(html, 'https://www.duas.org/mobile/ziyarat-imam-hussain-as-shrine.html');
  const s = page.sections;

  const first = findSection(s, 'one', 'first');
  const second = findSection(s, 'one', 'second');
  const third = findSection(s, 'one', 'third');
  const fourth = findSection(s, 'one', 'fourth');
  const fifth = findSection(s, 'one', 'fifth');
  const sixth = findSection(s, 'one', 'sixth');

  if (!first || !second || !third || !fourth || !fifth || !sixth) {
    console.error('Karbala: missing an expected form — aborting. Found:', s.filter(x=>x.tabId==='one').map((x) => x.subLabel));
    return;
  }

  writeLocalZikr('AG8', {
    title: 'Ziyarah of Imam Husayn (a.s.) — Karbala (All 6 General Forms)',
    code: '012',
    slug: normalizeSlug('ziyarah-imam-hussain-karbala-all-forms'),
    data: blocksToText(first.blocks, 'First Ziyarah'),
    tabs: [
      blocksToText(second.blocks, 'Second Ziyarah (by Imam Ali al-Naqi)'),
      blocksToText(third.blocks, 'Third Ziyarah (by Imam Ja’far al-Sadiq)'),
      blocksToText(fourth.blocks, 'Fourth Ziyarah'),
      blocksToText(fifth.blocks, 'Fifth Ziyarah'),
      blocksToText(sixth.blocks, 'Sixth Ziyarah'),
    ],
  });

  // AG14: Ziyarah Warith / 7th Main
  const seventh = findSection(s, 'two');
  if (seventh) {
    writeLocalZikr('AG14', {
      title: 'Seventh Ziyarah — Ziyarah Warith — Karbala',
      code: '012',
      slug: normalizeSlug('ziyarah-warith-karbala'),
      data: blocksToText(seventh.blocks, null),
    });
  }

  // AG18: Ziyarah of Al Abbas
  const abbas = findSection(s, 'twoa');
  if (abbas) {
    writeLocalZikr('AG18', {
      title: 'Ziyarah of Hazrat Abbas (a.s.) — Karbala',
      code: '012',
      slug: normalizeSlug('ziyarah-hazrat-abbas-karbala'),
      data: blocksToText(abbas.blocks, null),
    });
  }

  // AG5+AG6: Post Ziarat Dua-Salwat -> recommended acts; Farewell
  const postZiarat = findSection(s, 'three');
  if (postZiarat) {
    writeLocalZikr('AG5', {
      title: 'Post-Ziyarah Prayers, Dua & Salawat — Karbala',
      code: '012',
      slug: normalizeSlug('post-ziyarah-dua-salawat-karbala'),
      data: blocksToText(postZiarat.blocks, null),
    });
  }

  const farewell = findSection(s, 'foura');
  if (farewell) {
    writeLocalZikr('AG6', {
      title: 'Bidding Farewell (Wida) to Imam Husayn (a.s.) — Karbala',
      code: '012',
      slug: normalizeSlug('farewell-imam-hussain-karbala'),
      data: blocksToText(farewell.blocks, null),
    });
  }
}

buildNajaf();
buildKarbala();
console.log('\nDone. Local-only draft written to assets/zikr.json + assets/zikr/<uid>.');
console.log('Nothing was written to Firestore. Review in-app, then confirm before we push to Firestore.');
