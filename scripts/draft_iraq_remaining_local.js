const fs = require('fs');
const path = require('path');
const { extractFromHtml, blocksToText } = require('./extract_ziyarat_sections');

// Continues the local-only draft pass (see draft_najaf_karbala_local.js) for
// the rest of Iraq: Kazimayn, Samarra, Kufa/Sehla, Madaeen, Balad. Same
// rules: numbered "forms" fold into one Zikr doc with tabs, items.json's
// existing uid is the anchor, nothing is written to Firestore.

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

function loadPage(filename, url) {
  const html = fs.readFileSync(path.join(SCRATCH, filename), 'utf8');
  return extractFromHtml(html, url);
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

function buildKazimayn() {
  const kazim = loadPage('kazim.html', 'https://duas.org/mobile/imam-musa-kazim-as.html').sections;
  const jawad = loadPage('jawad.html', 'https://www.duas.org/mobile/imam-taqi-jawad-as.html').sections;

  const kFirst = findSection(kazim, 'two', 'first form');
  const kSecond = findSection(kazim, 'two', 'second form');
  const kSalwaat = findSection(kazim, 'three');
  const commonIntro = findSection(kazim, 'five', null); // Izn Dukhool + Farewell etiquette
  const commonForm = findSection(kazim, 'five', 'common form');

  const jFirst = findSection(jawad, 'two', 'first form');
  const jFourth = findSection(jawad, 'two', 'fourth form');
  const jSalwaat = findSection(jawad, 'three');
  const jDua = findSection(jawad, 'four');

  if (kFirst && kSecond) {
    writeLocalZikr('AH2', {
      title: 'Ziyarah of Imam Musa al-Kazim (a.s.) — Kazimayn',
      code: '012',
      slug: normalizeSlug('ziyarah-imam-musa-kazim'),
      data: blocksToText(kFirst.blocks, 'First Ziyarah (by Shaykh al-Mufid)'),
      tabs: [blocksToText(kSecond.blocks, 'Second Ziyarah')],
    });
  }
  if (kSalwaat) {
    writeLocalZikr('AH4', {
      title: 'Salawat Upon Imam Musa al-Kazim (a.s.) — Kazimayn',
      code: '012',
      slug: normalizeSlug('salawat-imam-musa-kazim'),
      data: blocksToText(kSalwaat.blocks, null),
    });
  }
  if (jFirst) {
    const tabs = [];
    if (jFourth) tabs.push(blocksToText(jFourth.blocks, 'Another Ziyarah (from Baqiyat al-Salihat)'));
    if (jDua) tabs.push(blocksToText(jDua.blocks, 'Dua After Ziyarah'));
    writeLocalZikr('AH5', {
      title: 'Ziyarah of Imam Muhammad al-Jawad (a.s.) — Kazimayn',
      code: '012',
      slug: normalizeSlug('ziyarah-imam-muhammad-jawad'),
      data: blocksToText(jFirst.blocks, 'First Ziyarah'),
      tabs,
    });
  }
  if (jSalwaat) {
    writeLocalZikr('AH7', {
      title: 'Invocation of Blessings Upon Imam al-Jawad (a.s.) — Kazimayn',
      code: '012',
      slug: normalizeSlug('salawat-imam-jawad'),
      data: blocksToText(jSalwaat.blocks, null),
    });
  }
  if (commonForm) {
    writeLocalZikr('AH9', {
      title: 'Ziyarah Common to Imam al-Kazim & Imam al-Jawad (a.s.) — Kazimayn',
      code: '012',
      slug: normalizeSlug('ziyarah-common-kazim-jawad'),
      data: blocksToText(commonForm.blocks, null),
    });
  }
  if (commonIntro) {
    writeLocalZikr('AH10', {
      title: 'Entrance Permission & Farewell — Kazimayn (Imam al-Kazim & Imam al-Jawad)',
      code: '012',
      slug: normalizeSlug('entrance-farewell-kazimayn'),
      data: blocksToText(commonIntro.blocks, null),
    });
  }
}

function buildSamarra() {
  const naqi = loadPage('naqi.html', 'https://duas.org/mobile/imam-ali-naqi-hadi-as.html').sections;
  const askari = loadPage('askari.html', 'https://www.duas.org/mobile/imam-hassan-askari-as.html').sections;
  const sirdab = loadPage('sirdab.html', 'https://www.duas.org/mobile/ziyarat-imam-mahdi-sirdab.html').sections;

  const naqiZiyarat = findSection(naqi, 'two');
  const naqiFarewell = findSection(naqi, 'three');
  const naqiSalwat = findSection(naqi, 'four');
  const combined = findSection(naqi, 'six');

  const askariZiyarat = findSection(askari, 'two');
  const askariDua = findSection(askari, 'three');
  const askariSalwat = findSection(askari, 'four');

  const rabialAnam = findSection(sirdab, 'onea');
  const secondSirdab = findSection(sirdab, 'two');
  const syedTawus = findSection(sirdab, 'twoa');
  const sirdabSalwaat = findSection(sirdab, 'three');

  if (combined) {
    writeLocalZikr('AL1', {
      title: 'Combined Ziyarah of Imam Ali al-Naqi & Imam al-Hasan al-Askari — Samarra',
      code: '012',
      slug: normalizeSlug('combined-ziyarah-naqi-askari'),
      data: blocksToText(combined.blocks, null),
    });
  }
  if (naqiZiyarat) {
    writeLocalZikr('AL5', {
      title: 'Ziyarah of Imam Ali al-Naqi al-Hadi (a.s.) — Samarra',
      code: '012',
      slug: normalizeSlug('ziyarah-imam-ali-naqi'),
      data: blocksToText(naqiZiyarat.blocks, null),
      tabs: naqiSalwat ? [blocksToText(naqiSalwat.blocks, 'Salawat Upon Imam al-Naqi')] : [],
    });
  }
  if (askariZiyarat) {
    const tabs = [];
    if (askariDua) tabs.push(blocksToText(askariDua.blocks, 'Dua After Ziyarah'));
    if (askariSalwat) tabs.push(blocksToText(askariSalwat.blocks, 'Salawat Upon Imam al-Askari'));
    writeLocalZikr('AL6', {
      title: 'Ziyarah of Imam al-Hasan al-Askari (a.s.) — Samarra',
      code: '012',
      slug: normalizeSlug('ziyarah-imam-hasan-askari'),
      data: blocksToText(askariZiyarat.blocks, null),
      tabs,
    });
  }
  if (naqiFarewell) {
    writeLocalZikr('AL7', {
      title: 'Bidding Farewell to the Two Imams (Naqi & Askari) — Samarra',
      code: '012',
      slug: normalizeSlug('farewell-two-imams-samarra'),
      data: blocksToText(naqiFarewell.blocks, null),
    });
  }
  if (rabialAnam) {
    const tabs = [];
    if (secondSirdab) tabs.push(blocksToText(secondSirdab.blocks, 'Second Ziyarah at the Sardaab'));
    if (syedTawus) tabs.push(blocksToText(syedTawus.blocks, 'Ziyarah by Sayyid Ibn Tawus'));
    writeLocalZikr('AL11', {
      title: 'Ziyarat at the Holy Sardaab (Occultation Cellar) — Samarra',
      code: '012',
      slug: normalizeSlug('ziyarat-holy-sardaab'),
      data: blocksToText(rabialAnam.blocks, 'Ziyarat Rabi al-Anam'),
      tabs,
    });
  }
  if (sirdabSalwaat) {
    writeLocalZikr('AL15', {
      title: 'Salawat Upon Imam al-Mahdi (a.t.f.s.) — Sardaab, Samarra',
      code: '012',
      slug: normalizeSlug('salawat-imam-mahdi-sardaab'),
      data: blocksToText(sirdabSalwaat.blocks, null),
    });
  }
}

function buildKufa() {
  const kufa = loadPage('kufa.html', 'https://www.duas.org/mobile/kufa.html').sections;
  const sehla = loadPage('sehla.html', 'https://www.duas.org/mobile/sehla.html').sections;

  const entrance = findSection(kufa, 'one');
  const ibrahimKhizr = findSection(kufa, 'onea');
  const dikkatQadha = findSection(kufa, 'two');
  const centre = findSection(kufa, 'three');
  const adam = findSection(kufa, 'four');
  const gabriel = findSection(kufa, 'five');
  const zainulAbideen = findSection(kufa, 'six');
  const courtyard = findSection(kufa, 'seven');
  const noah = findSection(kufa, 'eight');
  const mehrab = findSection(kufa, 'nine');
  const imamSadiq = findSection(kufa, 'ten');

  if (entrance) {
    const tabs = [];
    if (ibrahimKhizr) tabs.push(blocksToText(ibrahimKhizr.blocks, 'Station of Ibrahim (a) & Khizr (a)'));
    if (adam) tabs.push(blocksToText(adam.blocks, 'Station of Adam (a)'));
    if (gabriel) tabs.push(blocksToText(gabriel.blocks, 'Station of the Angel Gabriel'));
    if (zainulAbideen) tabs.push(blocksToText(zainulAbideen.blocks, 'Station of Imam Zayn al-Abidin (a)'));
    if (courtyard) tabs.push(blocksToText(courtyard.blocks, 'Acts in the Courtyard'));
    if (noah) tabs.push(blocksToText(noah.blocks, 'Station of Prophet Noah (a)'));
    if (mehrab) tabs.push(blocksToText(mehrab.blocks, 'Acts at the Mehrab'));
    writeLocalZikr('AI3', {
      title: "Recommended Acts (A'amal) of Masjid al-Kufah",
      code: '012',
      slug: normalizeSlug('aamal-masjid-kufah'),
      data: blocksToText(entrance.blocks, 'Entering the Mosque'),
      tabs,
    });
  }
  if (dikkatQadha) {
    writeLocalZikr('AI4', {
      title: 'Acts at the Seat of Judgement (Dikkat al-Qadha) & Place of the Wash-Tub — Masjid al-Kufah',
      code: '012',
      slug: normalizeSlug('dikkat-qadha-bayt-tasht-kufah'),
      data: blocksToText(dikkatQadha.blocks, null),
    });
  }
  if (centre) {
    writeLocalZikr('AI5', {
      title: 'Prayers & Supplications at the Centre of Masjid al-Kufah',
      code: '012',
      slug: normalizeSlug('centre-masjid-kufah'),
      data: blocksToText(centre.blocks, null),
    });
  }
  if (imamSadiq) {
    writeLocalZikr('AI11', {
      title: "Devotional Acts at Imam al-Sadiq's Bench — Masjid al-Kufah",
      code: '012',
      slug: normalizeSlug('imam-sadiq-bench-kufah'),
      data: blocksToText(imamSadiq.blocks, null),
    });
  }

  const sEntrance = findSection(sehla, 'one');
  const sCentre = findSection(sehla, 'two');
  const sIbrahim = findSection(sehla, 'three');
  const sIdris = findSection(sehla, 'four');
  const sKhizr = findSection(sehla, 'five');
  const sAmbiya = findSection(sehla, 'six');
  const sSajjad = findSection(sehla, 'seven');
  const sZayd = findSection(sehla, 'nine');

  if (sEntrance) {
    const tabs = [];
    if (sCentre) tabs.push(blocksToText(sCentre.blocks, 'Centre of the Mosque'));
    if (sIbrahim) tabs.push(blocksToText(sIbrahim.blocks, 'Station of Ibrahim (a)'));
    if (sIdris) tabs.push(blocksToText(sIdris.blocks, 'Station of Idris (a)'));
    if (sKhizr) tabs.push(blocksToText(sKhizr.blocks, 'Station of Khizr (a)'));
    if (sAmbiya) tabs.push(blocksToText(sAmbiya.blocks, 'Station of the Prophets & Righteous'));
    if (sSajjad) tabs.push(blocksToText(sSajjad.blocks, 'Maqam of Imam Sajjad (a)'));
    writeLocalZikr('AI15', {
      title: "Recommended Acts (A'amal) of Masjid al-Sahla",
      code: '012',
      slug: normalizeSlug('aamal-masjid-sahla'),
      data: blocksToText(sEntrance.blocks, 'Entering the Mosque'),
      tabs,
    });
  }
  if (sZayd) {
    writeLocalZikr('AI16', {
      title: "Recommended Acts (A'amal) of Masjid Zayd",
      code: '012',
      slug: normalizeSlug('aamal-masjid-zayd'),
      data: blocksToText(sZayd.blocks, null),
    });
  }
}

function buildMadaenAndBalad() {
  const salman = loadPage('salman.html', 'https://www.duas.org/madayen-salman.html').sections;
  const ziyarat = findSection(salman, 'two');
  if (ziyarat) {
    writeLocalZikr('AJ2', {
      title:
        'Ziyarah at Madaen — Salman al-Farsi, Hudhayfah al-Yamani, Tahir ibn Imam al-Baqir & Abdullah ibn Jabir (r.a.)',
      code: '012',
      slug: normalizeSlug('ziyarah-madaen-salman-hudhayfah'),
      data: blocksToText(ziyarat.blocks, null),
    });
  }

  const sayed = loadPage('sayed_mohammed.html', 'https://www.duas.org/mobile/ziyarat-sayed-mohammed.html').sections;
  const sayedZiyarah = findSection(sayed, 'one');
  if (sayedZiyarah) {
    writeLocalZikr('AN1', {
      title: 'Ziyarah of Sayyid Muhammad, Son of Imam Ali al-Hadi (a.s.) — Balad',
      code: '012',
      slug: normalizeSlug('ziyarah-sayed-mohammed-balad'),
      data: blocksToText(sayedZiyarah.blocks, null),
    });
  }
}

buildKazimayn();
buildSamarra();
buildKufa();
buildMadaenAndBalad();

console.log('\nDone. Local-only draft written to assets/zikr.json + assets/zikr/<uid>.');
console.log('Nothing was written to Firestore.');
console.log('\nKNOWN GAPS (no usable source found — flagged, not written):');
console.log('  Kazimayn: AH1 (merits/method, prose), AH3/AH6/AH8 (folded as tabs under AH2/AH5 instead of separate)');
console.log('  Samarra: AL2/AL3/AL4/AL8/AL9/AL10/AL13/AL16/AL17 — no distinct duas.org section found; likely folded into AL1/AL11 or absent from this page');
console.log("  Kufa: AI1/AI2 (merits, prose), AI6/AI7/AI8/AI9/AI12 (pillar-numbered — duas.org organizes by prophet name instead, folded into AI3 as tabs rather than guessing pillar numbers), AI13/AI14 (Muslim ibn Aqeel / Hani ibn Urwah — page 301-redirects to duas.org's new JS site and 404s there, not fetched)");
console.log('  Baghdad (AM1-AM4): Masjid Buratha page has NO ziyarah text (info/photos only), Deputies page has only 3 scattered/incomplete triplets — genuine gap, needs another source');
