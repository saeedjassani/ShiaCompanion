import 'package:flutter/material.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import '../theme/shia_colors.dart';
import '../utils/font_preferences.dart';
import 'language_settings.dart';
import 'choice_sheet.dart';
import 'page_chrome.dart';
import 'responsive_content.dart';
import 'zikr_reading_preferences.dart';

/// Opens the reader's one sheet of reading settings (docs/DESIGN_SPEC.md,
/// "Reading" → Text; mockup R2-Reader-text): the Arabic font as cards with a
/// live sample, Arabic and English size, then the switches.
///
/// [onChanged] runs after every change, so the text behind the sheet
/// follows along. Setting a reminder is the reader top bar's bell, not a
/// row here.
Future<void> showReaderTextSheet(
  BuildContext context, {
  required VoidCallback onChanged,
}) {
  final colors = ShiaColors.of(context);
  final sheet = ReaderTextSheet(onChanged: onChanged);
  // On a desktop, a panel down the side rather than a dialog in the middle:
  // the reading column stays in view, following each change.
  if (ScreenClass.of(context).isDesktop) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      pageBuilder: (context, _, __) => SafeArea(
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DecoratedBox(
              // The glass surfaces' shadow (docs/DESIGN_SPEC.md, colour
              // tokens), so the panel lifts off the page without a scrim.
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.45)
                        : const Color(0x242A1E16),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: colors.ground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: colors.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: 400,
                  height: double.infinity,
                  child: SheetPresentation(inDialog: true, child: sheet),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, _, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        final from = Directionality.of(context) == TextDirection.rtl
            ? const Offset(-0.08, 0)
            : const Offset(0.08, 0);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: from, end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: colors.ground,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => sheet,
  );
}

class ReaderTextSheet extends StatefulWidget {
  const ReaderTextSheet({
    super.key,
    required this.onChanged,
  });

  final VoidCallback onChanged;

  @override
  State<ReaderTextSheet> createState() => _ReaderTextSheetState();
}

class _ReaderTextSheetState extends State<ReaderTextSheet> {
  void _changed() {
    widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _toggle(ReadingSwitch setting, bool value) async {
    await setting.save(value);
    // Turning either English aid back on leaves nothing for the paragraph
    // flow to show, so the reader falls back to lines on its own; the
    // switch below just shows as unavailable again.
    _changed();
  }

  void _stepArabic(int direction) {
    final next = (arabicFontSize + 2 * direction)
        .clamp(minArabicFontSize, maxArabicFontSize)
        .toDouble();
    if (next == arabicFontSize) return;
    setArabicFontSizePref(next);
    commitArabicFontSize();
    _changed();
  }

  void _stepEnglish(int direction) {
    final next = (englishFontSize + direction)
        .clamp(minEnglishFontSize, maxEnglishFontSize)
        .toDouble();
    if (next == englishFontSize) return;
    setEnglishFontSizePref(next);
    commitEnglishFontSize();
    _changed();
  }

  Future<void> _chooseFont(String font) async {
    if (font == arabicFont) return;
    await saveArabicFontChoice(font);
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final paragraphAvailable = arabicParagraphAvailable();
    final showLanguage = translationLanguageOffered(context);

    final inPanel = SheetPresentation.inDialogOf(context);

    return SingleChildScrollView(
      padding: inPanel
          ? const EdgeInsets.fromLTRB(20, 14, 16, 20)
          : EdgeInsets.fromLTRB(
              16, 8, 16, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!inPanel) ...[
            const SheetDragHandle(),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.readerTextSheetTitle,
                    style: ShiaText.sectionTitle.copyWith(color: colors.text),
                  ),
                ),
              ),
              PageTextAction(
                label: l10n.commonDone,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (i, font) in FontPreferences.validFonts.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _FontCard(
                    font: font,
                    selected: font == arabicFont,
                    onTap: () => _chooseFont(font),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          CardList(children: [
            _SizeRow(
              label: l10n.readerArabicSize,
              value: arabicFontSize,
              smallerLabel: l10n.readerArabicSmaller,
              biggerLabel: l10n.readerArabicBigger,
              onSmaller: arabicFontSize > minArabicFontSize
                  ? () => _stepArabic(-1)
                  : null,
              onBigger: arabicFontSize < maxArabicFontSize
                  ? () => _stepArabic(1)
                  : null,
            ),
            _SizeRow(
              label: l10n.readerEnglishSize,
              value: englishFontSize,
              smallerLabel: l10n.readerEnglishSmaller,
              biggerLabel: l10n.readerEnglishBigger,
              onSmaller: englishFontSize > minEnglishFontSize
                  ? () => _stepEnglish(-1)
                  : null,
              onBigger: englishFontSize < maxEnglishFontSize
                  ? () => _stepEnglish(1)
                  : null,
              last: true,
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              l10n.readingFineTune,
              style: ShiaText.caption.copyWith(color: colors.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          CardList(children: [
            CardSwitchRow(
              label: l10n.readerTransliteration,
              value: ReadingSwitch.transliteration.value,
              onChanged: (v) => _toggle(ReadingSwitch.transliteration, v),
            ),
            CardSwitchRow(
              label: l10n.readerTranslation,
              value: ReadingSwitch.translation.value,
              onChanged: (v) => _toggle(ReadingSwitch.translation, v),
            ),
            CardSwitchRow(
              label: l10n.readerArabicParagraph,
              hint: l10n.readerArabicParagraphHint,
              value: paragraphAvailable && ReadingSwitch.arabicParagraph.value,
              onChanged: paragraphAvailable
                  ? (v) => _toggle(ReadingSwitch.arabicParagraph, v)
                  : null,
            ),
            CardSwitchRow(
              label: l10n.readerKeepScreenOn,
              value: ReadingSwitch.keepScreenOn.value,
              onChanged: (v) => _toggle(ReadingSwitch.keepScreenOn, v),
            ),
            CardSwitchRow(
              label: l10n.readerFocusMode,
              hint: l10n.readerFocusModeHint,
              value: ReadingSwitch.focusMode.value,
              onChanged: (v) => _toggle(ReadingSwitch.focusMode, v),
            ),
            CardSwitchRow(
              label: l10n.readerShareAsImage,
              value: ReadingSwitch.shareAsImage.value,
              onChanged: (v) => _toggle(ReadingSwitch.shareAsImage, v),
              last: true,
            ),
          ]),
          if (showLanguage) ...[
            const SizedBox(height: 12),
            const CardList(children: [
              TranslationLanguageTile(first: true, last: true),
            ]),
          ],
        ],
      ),
    );
  }
}

/// One Arabic font to choose, with a sample in it; the chosen one outlined
/// in the accent.
class _FontCard extends StatelessWidget {
  const _FontCard({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  final String font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: selected
          ? BorderSide(color: colors.accent, width: 2)
          : BorderSide(color: colors.line),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.readerArabicFontLabel(font),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: colors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  font,
                  style: ShiaText.caption.copyWith(
                    fontSize: 14,
                    height: 18 / 14,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                Text(
                  'بِسْمِ اللّٰهِ',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: font,
                    fontSize: 22,
                    height: 1.8,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Arabic size   A−  32  A+".
class _SizeRow extends StatelessWidget {
  const _SizeRow({
    required this.label,
    required this.value,
    required this.smallerLabel,
    required this.biggerLabel,
    required this.onSmaller,
    required this.onBigger,
    this.last = false,
  });

  final String label;
  final double value;
  final String smallerLabel;
  final String biggerLabel;
  final VoidCallback? onSmaller;
  final VoidCallback? onBigger;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 10, 4),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: ShiaText.body.copyWith(color: colors.text)),
          ),
          _StepButton(
            text: 'A−',
            fontSize: 14,
            label: smallerLabel,
            onPressed: onSmaller,
          ),
          SizedBox(
            width: 36,
            child: Text(
              value.toInt().toString(),
              textAlign: TextAlign.center,
              style: ShiaText.secondary.copyWith(color: colors.textMuted),
            ),
          ),
          _StepButton(
            text: 'A+',
            fontSize: 17,
            label: biggerLabel,
            onPressed: onBigger,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.text,
    required this.fontSize,
    required this.label,
    required this.onPressed,
  });

  final String text;
  final double fontSize;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: SizedBox(
          width: 48,
          height: 44,
          child: Center(
            child: Material(
              color: colors.surface,
              shape: StadiumBorder(side: BorderSide(color: colors.line)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox(
                  width: 46,
                  height: 36,
                  child: Center(
                    child: Text(
                      text,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? colors.text
                            : colors.text.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
