import 'package:flutter/material.dart';

import '../constants.dart';
import '../data/universal_data.dart';
import '../l10n/l10n.dart';
import '../theme/shia_colors.dart';
import 'favorite_icon.dart';
import 'outline_icon.dart';
import 'page_chrome.dart';

/// Arabic script, as titles use it: letters, harakat and presentation forms.
const String _arabic = r'؀-ۿݐ-ݿࢠ-ࣿ'
    r'ﭐ-﷿ﹰ-﻿';

/// A title ending in a run of Arabic: "Dua al-Hujjah اِلٰهِيْ بِحَقِّ …".
final RegExp _trailingArabic = RegExp(
  '^(.*?[^\\s$_arabic])\\s+([$_arabic][$_arabic\\u200C\\u200D\\s.…]*)\$',
);

/// [title] split into its words and the Arabic it ends with, if it does:
/// `("Dua al-Hujjah", "اِلٰهِيْ بِحَقِّ مَنْ نَاجَاكَ")`. Arabic inside the
/// title ("Ziyarat Rajabiyah (الحمد الله …)") stays where it is.
({String text, String? arabic}) splitTrailingArabic(String title) {
  final match = _trailingArabic.firstMatch(title.trim());
  if (match == null) return (text: title, arabic: null);
  return (text: match.group(1)!, arabic: match.group(2)!.trim());
}

/// A zikr's row in a list (docs/DESIGN_SPEC.md, "Lists"): the title, with
/// the Arabic it ends in on a line of its own, right-aligned in the reader's
/// Arabic font; an optional sub-line (when it is recited, or where it lives)
/// and **Today** pill; the heart on the right.
class ZikrListRow extends StatelessWidget {
  const ZikrListRow({
    super.key,
    required this.item,
    required this.onTap,
    this.title,
    this.subtitle,
    this.today = false,
    this.highlight,
    this.first = false,
    this.last = false,
  });

  /// What the heart keeps.
  final UniversalData item;
  final VoidCallback onTap;

  /// Shown instead of [item]'s title (an admin's uid prefix).
  final String? title;

  /// When it is recited ("On 20 Safar"), or where it lives ("Ziyarats").
  final String? subtitle;

  /// Whether it is one of today's recitations.
  final bool today;

  /// Text to set in bold where the title contains it: a search's query.
  final String? highlight;

  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final parts = splitTrailingArabic(title ?? item.displayTitle);

    return CardListRow(
      first: first,
      last: last,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          highlightedText(parts.text, highlight),
          if (parts.arabic != null)
            Text(
              parts.arabic!,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: arabicFont,
                fontFamilyFallback: const ['Qalam'],
                fontSize: 19,
                height: 32 / 19,
                color: colors.translation,
              ),
            ),
        ],
      ),
      subtitle: subtitle == null && !today
          ? null
          : Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (subtitle != null) Text(subtitle!),
                if (today) const TodayPill(),
              ],
            ),
      trailing: FavoriteHeartButton(favorite: item),
      onTap: onTap,
    );
  }
}

/// [text] with every case-insensitive occurrence of [query] in bold.
Widget highlightedText(String text, String? query) {
  final needle = query?.trim().toLowerCase() ?? '';
  if (needle.isEmpty) return Text(text);

  final lower = text.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  var index = lower.indexOf(needle);
  // Lower-casing can change a string's length (rarely, outside ASCII), and
  // then offsets into [lower] would not line up with [text].
  if (lower.length != text.length) index = -1;
  while (index >= 0) {
    if (index > start) spans.add(TextSpan(text: text.substring(start, index)));
    spans.add(TextSpan(
      text: text.substring(index, index + needle.length),
      style: const TextStyle(fontWeight: FontWeight.w700),
    ));
    start = index + needle.length;
    index = lower.indexOf(needle, start);
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return Text.rich(TextSpan(children: spans), semanticsLabel: text);
}

/// The small **Today** pill beside a recitation that falls today.
class TodayPill extends StatelessWidget {
  const TodayPill({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        context.l10n.commonToday,
        style: ShiaText.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colors.accent,
        ),
      ),
    );
  }
}

/// A row that opens a group of zikr ("Ziyarat of Hijaz, Iran & Iraq", an
/// Aamaal month): a folder tile, the title in bold, what is inside on a
/// sub-line, and a chevron. No heart: a group is not something to keep.
class ZikrGroupRow extends StatelessWidget {
  const ZikrGroupRow({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.first = false,
    this.last = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return CardListRow(
      first: first,
      last: last,
      minHeight: 60,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.well,
          borderRadius: BorderRadius.circular(10),
        ),
        child: OutlineIcon(OutlineGlyph.folder, size: 20, color: colors.accent),
      ),
      title: Text(title),
      titleStyle: ShiaText.body.copyWith(fontWeight: FontWeight.w600),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
        child: OutlineIcon(OutlineGlyph.chevronRight,
            size: 16, color: colors.chevron, strokeWidth: 2.4),
      ),
      onTap: onTap,
    );
  }
}
