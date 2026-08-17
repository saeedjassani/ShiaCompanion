const fs = require('fs');
const cheerio = require('cheerio');
const { fetchHtml, extractTitle, cleanTitle, stripHtmlTags } = require('./import_dua_from_url');

// ---------------------------------------------------------------------------
// Section-aware extractor for duas.org's comprehensive shrine pages.
//
// Unlike import_dua_from_url.js (which grabs a single tab-pane, or falls back
// to scanning the whole page), these Iraq ziarat pages have many tabs
// (`<ul class="nav-tabs">` + `<div class="tab-pane" id="...">`), and some
// tabs further nest an accordion (`panel-group` / `panel-title` + `collapseN`)
// with multiple named forms inside (e.g. Najaf's "Ziarats 2-6" tab holds
// Second through Sixth Ziyarah as separate accordion panels).
//
// Pages also interleave narrative text between triplets — isnad chains,
// footnote references, stage directions ("You may then move to the side of
// the feet and say..."). The Zikr viewer (zikr_content_parser.dart) detects
// Arabic lines by content and infers transliteration/translation as the next
// two lines *positionally*, so a plain-text line sitting between two
// triplets renders fine as long as no triplet's own 3 lines get split apart.
// This walks each region in document order and emits a flat list of
// {type:'prose', text} / {type:'triplet', arabic, transliteration,
// translation} blocks, preserving that order, so nothing gets dropped.
// ---------------------------------------------------------------------------

// Many duas.org pages mark ziyarah-form boundaries with a bare line of text
// (no heading tag, no wrapper div) like "First Form of Ziyarah" or "Second
// Ziyarah_Imam Ali Naqi(as)", immediately followed by a <br>. There is no DOM
// marker for these, so they have to be found by scanning the raw HTML text.
const ORDINAL_HEADING_RE =
  /\b(first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth)\b[^<>\n]{0,80}?\b(form|ziyarah|ziyarat|ziarat)\b[^<>\n]{0,40}/i;

const TRIPLET_DIV_SPLIT_RE = /(<div class="(?:Ara|Trl|Tra)"[\s\S]*?<\/[a-zA-Z0-9]+>)/;
const TRIPLET_DIV_CLASS_RE = /^<div class="(Ara|Trl|Tra)"/;

// Two more bits of page chrome that survive tag-stripping as bare text, so
// they can't be caught by stripNonContentElements (a DOM-level pass):
//   - A second <audio> offering an alternate recording is introduced by a
//     bare "Alt:" text node between the two <audio> tags. The <audio>s
//     themselves are removed by stripNonContentElements, but that leaves
//     "Alt:" behind as an orphaned prose line.
//   - Some pages point to a fuller version of a sub-topic with a link like
//     "Seperate Ziarat Page" / "Seperate page" / "seperate pg z" (site's
//     own typo, both spellings seen). The Zikr viewer renders plain text,
//     so a stray link caption like this is meaningless noise, not content.
//     Anchored to the start of the line and requiring "page"/"pg" right
//     after, so it can't swallow real sentences that just happen to use
//     the word "separate"/"separation" (e.g. "...bid you farewell for
//     separation" — seen in real ziyarah text).
const ALT_LABEL_RE = /^alt\s*:?$/i;
const SEPARATE_PAGE_LINK_RE = /^se?p[ae]rat[a-z]*\s+(ziarat\s+)?(page|pg)\b/i;

function extractTabLabels($) {
  const labels = new Map();
  $('a[data-toggle="tab"]').each((_, el) => {
    const href = $(el).attr('href') || '';
    const id = href.replace(/^#/, '');
    if (!id) return;
    const label = stripHtmlTags($(el).html() || '').trim();
    if (id) labels.set(id, label || id);
  });
  return labels;
}

// Parses a raw HTML fragment (a tab-pane's or accordion panel's innerHTML)
// into an ordered list of items: headings, prose paragraphs, and complete
// Arabic/transliteration/translation triplets — in original document order.
function parseHtmlIntoItems(rawHtml) {
  const chunks = rawHtml.split(TRIPLET_DIV_SPLIT_RE);
  const items = [];
  let pending = { arabic: null, transliteration: null, translation: null };

  const flushProseLine = (rawLine) => {
    const text = stripHtmlTags(rawLine).trim();
    if (!text) return;
    if (ALT_LABEL_RE.test(text) || SEPARATE_PAGE_LINK_RE.test(text)) return;
    const headingMatch = text.match(ORDINAL_HEADING_RE);
    if (headingMatch && text.length < 90) {
      items.push({ type: 'heading', text });
    } else {
      items.push({ type: 'prose', text });
    }
  };

  for (const chunk of chunks) {
    const tripletMatch = chunk.match(TRIPLET_DIV_CLASS_RE);
    if (tripletMatch) {
      const cls = tripletMatch[1];
      const text = stripHtmlTags(chunk).trim();
      if (!text) continue;
      if (cls === 'Ara') {
        pending = { arabic: text, transliteration: null, translation: null };
      } else if (cls === 'Trl') {
        pending.transliteration = text;
      } else if (cls === 'Tra') {
        pending.translation = text;
        if (pending.arabic && pending.transliteration && pending.translation) {
          items.push({ type: 'triplet', ...pending });
        }
        pending = { arabic: null, transliteration: null, translation: null };
      }
      continue;
    }
    // Plain content gap: split into lines so headings anywhere within a
    // multi-paragraph gap (not just at the start) are still detected.
    const lines = chunk.split(/<br\s*\/?>|<hr\s*\/?>|<\/h[1-6]>|<\/p>/i);
    for (const line of lines) flushProseLine(line);
  }

  return items;
}

// Splits a flat item list into sections at each 'heading' item. Items before
// the first heading (or all items, if there are none) form a section with
// subLabel = null.
function groupItemsByHeadings(items, tabId, tabLabel) {
  const sections = [];
  let current = { tabId, tabLabel, subLabel: null, blocks: [] };
  for (const item of items) {
    if (item.type === 'heading') {
      if (current.blocks.length > 0) sections.push(current);
      current = { tabId, tabLabel, subLabel: item.text, blocks: [] };
      continue;
    }
    current.blocks.push(item);
  }
  if (current.blocks.length > 0) sections.push(current);
  return sections.filter((s) => s.blocks.some((b) => b.type === 'triplet'));
}

function extractSectionsForTab($, tabPane, tabId, tabLabel) {
  const panelTitles = $(tabPane).find('.panel-title');

  if (panelTitles.length === 0) {
    const items = parseHtmlIntoItems($.html(tabPane));
    return groupItemsByHeadings(items, tabId, tabLabel);
  }

  // Tab has an accordion: one section per panel, PLUS whatever is in the tab
  // outside any panel-group (intro content, itself possibly heading-split).
  const sections = [];

  panelTitles.each((_, titleEl) => {
    const label = stripHtmlTags($(titleEl).html() || '').trim();
    const toggle = $(titleEl).find('a[data-toggle="collapse"]');
    const targetHref = toggle.attr('href') || '';
    const targetId = targetHref.replace(/^#/, '');
    let body = targetId ? $(tabPane).find(`#${targetId}`) : null;
    if (!body || body.length === 0) {
      body = $(titleEl).closest('.panel').find('.panel-collapse, .panel-body');
    }
    const items = parseHtmlIntoItems($.html(body));
    const blocks = items.filter((i) => i.type !== 'heading');
    if (blocks.some((b) => b.type === 'triplet')) {
      sections.push({ tabId, tabLabel, subLabel: label || targetId, blocks });
    }
  });

  const clone = $(tabPane).clone();
  clone.find('.panel-group').remove();
  const introItems = parseHtmlIntoItems($.html(clone));
  const introSections = groupItemsByHeadings(introItems, tabId, tabLabel);
  sections.unshift(...introSections);

  return sections;
}

// UI chrome that isn't real content but leaves stray fallback/link text
// behind once tags are stripped (e.g. an <audio> element's <a> fallback link
// reading "Najaf ziarat", or a "back to top" button's icon span).
function stripNonContentElements($) {
  $('audio, script, style').remove();
  $('a[href="#top"]').remove();
}

function extractFromHtml(html, url) {
  const $ = cheerio.load(html);
  stripNonContentElements($);
  const pageTitle = cleanTitle(extractTitle(html));
  const tabLabels = extractTabLabels($);

  const tabPanes = $('.tab-pane').toArray();
  const allSections = [];

  if (tabPanes.length === 0) {
    const items = parseHtmlIntoItems($.html($.root()));
    allSections.push(...groupItemsByHeadings(items, null, null));
  } else {
    for (const pane of tabPanes) {
      const tabId = $(pane).attr('id') || null;
      const tabLabel = tabId ? tabLabels.get(tabId) || tabId : null;
      allSections.push(...extractSectionsForTab($, pane, tabId, tabLabel));
    }
  }

  return { url, pageTitle, sections: allSections };
}

async function extractPage(url) {
  const html = await fetchHtml(url);
  return extractFromHtml(html, url);
}

function tripletCount(section) {
  return section.blocks.filter((b) => b.type === 'triplet').length;
}

// Renders a section's blocks back into Zikr's flat text format: prose lines
// interspersed with 3-line (Arabic/transliteration/translation) triplets, in
// original order. An optional label is prepended as the first line (used as
// the tab header by the Zikr viewer).
function blocksToText(blocks, label) {
  const lines = [];
  if (label) lines.push(label);
  for (const b of blocks) {
    if (b.type === 'triplet') {
      lines.push(b.arabic, b.transliteration, b.translation);
    } else if (b.type === 'prose') {
      lines.push(b.text);
    }
  }
  return lines.join('\n');
}

function summarize(page) {
  const lines = [];
  lines.push(`URL: ${page.url}`);
  lines.push(`Title: ${page.pageTitle}`);
  lines.push(`Sections: ${page.sections.length}`);
  page.sections.forEach((s, i) => {
    const label = [s.tabLabel, s.subLabel].filter(Boolean).join(' > ') || `(section ${i + 1})`;
    const firstTriplet = s.blocks.find((b) => b.type === 'triplet');
    const proseCount = s.blocks.filter((b) => b.type === 'prose').length;
    const firstLine = firstTriplet?.translation?.slice(0, 60) || '';
    lines.push(
      `  [${i}] tab="${s.tabId ?? '-'}" ${label} — ${tripletCount(s)} triplets, ${proseCount} prose blocks — "${firstLine}${firstLine.length === 60 ? '…' : ''}"`,
    );
  });
  return lines.join('\n');
}

async function main() {
  const args = process.argv.slice(2);
  const url = args[0];
  if (!url) {
    console.error('Usage: node extract_ziyarat_sections.js <url> [--out file.json] [--json]');
    process.exit(1);
  }
  const getArg = (flag) => {
    const idx = args.indexOf(flag);
    return idx === -1 ? null : args[idx + 1];
  };
  const outPath = getArg('--out');
  const asJson = args.includes('--json');

  const page = await extractPage(url);

  if (outPath) {
    fs.writeFileSync(outPath, JSON.stringify(page, null, 2));
    console.log(`Wrote ${page.sections.length} sections to ${outPath}`);
  }
  if (asJson && !outPath) {
    console.log(JSON.stringify(page, null, 2));
  } else if (!outPath) {
    console.log(summarize(page));
  }
}

module.exports = {
  extractPage,
  extractFromHtml,
  parseHtmlIntoItems,
  groupItemsByHeadings,
  extractTabLabels,
  extractSectionsForTab,
  blocksToText,
  tripletCount,
  summarize,
};

if (require.main === module) {
  main().catch((error) => {
    console.error(error?.stack || error);
    process.exit(1);
  });
}
