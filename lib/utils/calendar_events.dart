import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';

/// The Islamic calendar's events: assets/events.json, keyed "MM-DD" by
/// hijri month and day, with the app language's translation laid over it.
///
/// A language's translations live in `assets/events_i18n/<code>.json`, keyed
/// like events.json:
///
/// ```json
/// {"02-07": {"content": "...", "title": "..."}}
/// ```
///
/// `content` replaces the English `content` (the Calendar page shows it in
/// full); `title` is the day's event as one short line, for the places that
/// have room for a single line - Home's Coming up row, the calendar's
/// screen-reader labels and the home screen widgets - which otherwise cut it
/// out of the English `content` (see `widgetEventText`). A day the language
/// has not translated stays English. `color` always comes from events.json.
class CalendarEvents {
  CalendarEvents._();

  static final Map<String, Future<Map<String, dynamic>>> _cache = {};

  /// The events in [languageCode] (the app language when omitted). Loaded
  /// once per language for the life of the app: the files never change
  /// under a running build.
  static Future<Map<String, dynamic>> load({
    String? languageCode,
    AssetBundle? bundle,
  }) {
    final code = languageCode ?? L10n.current.localeName;
    if (bundle != null) return _load(code, bundle);
    return _cache[code] ??= _load(code, rootBundle);
  }

  static Future<Map<String, dynamic>> _load(
    String code,
    AssetBundle bundle,
  ) async {
    Map<String, dynamic> events;
    try {
      final decoded =
          json.decode(await bundle.loadString('assets/events.json'));
      if (decoded is! Map<String, dynamic>) return const {};
      events = decoded;
    } catch (e) {
      debugPrint('Unable to load calendar events: $e');
      return const {};
    }
    if (code == 'en') return events;
    Map<String, dynamic> translations;
    try {
      final decoded =
          json.decode(await bundle.loadString('assets/events_i18n/$code.json'));
      if (decoded is! Map<String, dynamic>) return events;
      translations = decoded;
    } catch (_) {
      // No translation for this language: English, as before.
      return events;
    }
    return translateEvents(events, translations);
  }

  /// [events] with each day [translations] covers given its translated
  /// `content` and `title`.
  @visibleForTesting
  static Map<String, dynamic> translateEvents(
    Map<String, dynamic> events,
    Map<String, dynamic> translations,
  ) {
    return {
      for (final entry in events.entries)
        entry.key: _translated(entry.value, translations[entry.key]),
    };
  }

  static Object? _translated(Object? event, Object? translation) {
    if (event is! Map || translation is! Map) return event;
    final content = translation['content'];
    final title = translation['title'];
    if (content is! String || content.trim().isEmpty) return event;
    return <String, dynamic>{
      ...event.cast<String, dynamic>(),
      'content': content,
      if (title is String && title.trim().isNotEmpty) 'title': title.trim(),
    };
  }
}
