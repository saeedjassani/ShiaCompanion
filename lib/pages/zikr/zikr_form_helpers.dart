List<String> buildVisibleZikrTabContents({
  required String primary,
  required Iterable<String> extraTabs,
}) {
  final visibleTabs = <String>[];
  final normalizedExtraTabs = extraTabs.toList();

  if (primary.trim().isNotEmpty ||
      normalizedExtraTabs.every((tab) => tab.trim().isEmpty)) {
    visibleTabs.add(primary);
  }

  visibleTabs.addAll(
    normalizedExtraTabs.where((tab) => tab.trim().isNotEmpty),
  );
  return visibleTabs;
}
