const CHARACTER_REPLACEMENTS = new Map([
  ['ہ', 'ه'],
  ['ک', 'ك'],
]);

function normalizeZikrText(value) {
  const text = `${value ?? ''}`;
  let normalized = text;

  for (const [from, to] of CHARACTER_REPLACEMENTS.entries()) {
    normalized = normalized.split(from).join(to);
  }

  return normalized;
}

function normalizeZikrTextList(values) {
  if (!Array.isArray(values)) return [];

  return values.map((value) => normalizeZikrText(value));
}

module.exports = {
  CHARACTER_REPLACEMENTS,
  normalizeZikrText,
  normalizeZikrTextList,
};
