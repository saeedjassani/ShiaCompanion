final RegExp _numericOrderPattern = RegExp(r'^-?\d+(\.\d+)?$');

String formatZikrDayValue(Object? dayValue) {
  if (dayValue is String) {
    return dayValue;
  }
  if (dayValue is Iterable) {
    return dayValue.map((value) => value.toString()).join(', ');
  }
  return '';
}

Object? parseZikrDayInput(String rawDay) {
  final dayPatterns = rawDay
      .split(',')
      .map((pattern) => pattern.trim())
      .where((pattern) => pattern.isNotEmpty)
      .toList();
  if (dayPatterns.isEmpty) {
    return null;
  }
  return dayPatterns.length == 1 ? dayPatterns.first : dayPatterns;
}

bool isValidZikrOrderInput(String rawOrder) {
  final trimmed = rawOrder.trim();
  return trimmed.isEmpty || _numericOrderPattern.hasMatch(trimmed);
}

String formatZikrOrderValue(num? order) {
  if (order == null) {
    return '';
  }
  return order % 1 == 0 ? order.toInt().toString() : order.toString();
}

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
