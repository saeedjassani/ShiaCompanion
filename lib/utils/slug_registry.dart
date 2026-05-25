Map<String, String> itemSlugs = {};
Map<String, List<String>> itemSlugAliases = {};
Map<String, String> slugToItemUid = {};

String normalizeSlug(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s-]'), ' ')
      .replaceAll(RegExp(r'[_\s]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

String slugifyTitle(String title) => normalizeSlug(title);

String slugifyUid(String uid) {
  return uid
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

String buildSlugSeed({
  required String uid,
  required String title,
  String? rawSlug,
}) {
  final preferredSlug = normalizeSlug(rawSlug ?? '');
  if (preferredSlug.isNotEmpty) return preferredSlug;

  final titleSlug = slugifyTitle(title);
  if (titleSlug.isNotEmpty) return titleSlug;

  return slugifyUid(uid);
}

bool isSlugAvailable(String slug, {String? currentUid}) {
  final owner = slugToItemUid[slug];
  return owner == null || owner == currentUid;
}

String makeUniqueSlug(String baseSlug, {String? currentUid}) {
  final normalizedBase = normalizeSlug(baseSlug);
  final fallbackBase = normalizedBase.isNotEmpty
      ? normalizedBase
      : (currentUid == null ? 'zikr' : slugifyUid(currentUid));
  if (isSlugAvailable(fallbackBase, currentUid: currentUid)) {
    return fallbackBase;
  }

  var suffix = 2;
  while (true) {
    final candidate = '$fallbackBase-$suffix';
    if (isSlugAvailable(candidate, currentUid: currentUid)) {
      return candidate;
    }
    suffix++;
  }
}

List<String> normalizeSlugAliases(
  Iterable<dynamic>? values, {
  String? exclude,
}) {
  final normalizedExclude = normalizeSlug(exclude ?? '');
  final aliases = <String>[];
  final seen = <String>{};

  for (final value in values ?? const []) {
    final alias = normalizeSlug(value?.toString() ?? '');
    if (alias.isEmpty || alias == normalizedExclude || !seen.add(alias)) {
      continue;
    }
    aliases.add(alias);
  }

  return aliases;
}

void clearLocalSlugMaps() {
  itemSlugs = {};
  itemSlugAliases = {};
  slugToItemUid = {};
}

void removeLocalSlugData(String uid) {
  final previousSlug = itemSlugs.remove(uid);
  if (previousSlug != null && slugToItemUid[previousSlug] == uid) {
    slugToItemUid.remove(previousSlug);
  }

  final previousAliases = itemSlugAliases.remove(uid) ?? const <String>[];
  for (final alias in previousAliases) {
    if (slugToItemUid[alias] == uid) {
      slugToItemUid.remove(alias);
    }
  }
}

void setLocalSlugData(
  String uid, {
  String? slug,
  Iterable<dynamic>? aliases,
}) {
  removeLocalSlugData(uid);

  final normalizedSlug = normalizeSlug(slug ?? '');
  final normalizedAliases =
      normalizeSlugAliases(aliases, exclude: normalizedSlug);

  if (normalizedSlug.isNotEmpty) {
    itemSlugs[uid] = normalizedSlug;
    slugToItemUid[normalizedSlug] = uid;
  }
  if (normalizedAliases.isNotEmpty) {
    itemSlugAliases[uid] = normalizedAliases;
    for (final alias in normalizedAliases) {
      slugToItemUid[alias] = uid;
    }
  }
}

void applySlugLookupMap(
  Map<dynamic, dynamic>? rawLookup,
  Set<String> allowedUids,
) {
  if (rawLookup == null) return;

  rawLookup.forEach((rawSlug, rawUid) {
    final slug = normalizeSlug(rawSlug?.toString() ?? '');
    final uid = rawUid?.toString() ?? '';
    if (slug.isEmpty || uid.isEmpty || !allowedUids.contains(uid)) {
      return;
    }
    slugToItemUid[slug] = uid;
  });
}
