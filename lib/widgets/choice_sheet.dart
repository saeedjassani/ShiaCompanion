import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/shia_colors.dart';
import 'outline_icon.dart';
import 'page_chrome.dart';

/// Opens a bottom sheet in the revamp's style (the reader's Text sheet):
/// the ground colour, a drag handle, a section title with Done, then
/// [builder]'s content, scrolling when it is long.
Future<T?> showRevampSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  final colors = ShiaColors.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: colors.ground,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => SheetFrame(title: title, child: builder(context)),
  );
}

/// What [showRevampSheet] draws around its content.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return SingleChildScrollView(
      // Clear of the keyboard while a field in the sheet has it up.
      padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 +
              MediaQuery.paddingOf(context).bottom +
              MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: colors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: ShiaText.sectionTitle.copyWith(color: colors.text),
                  ),
                ),
              ),
              PageTextAction(
                label: context.l10n.commonDone,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// One choice of a [showChoiceSheet].
class Choice<T> {
  const Choice(this.value, this.label, {this.hint, this.sample});

  final T value;
  final String label;

  /// A line under the label ("Light or dark, as your phone is set").
  final String? hint;

  /// Drawn under the label instead of a hint: an Arabic font's sample.
  final Widget? sample;
}

/// Asks for one of [choices] in a [showRevampSheet], the [current] one
/// ticked; choosing closes the sheet. Resolves to the choice, or null when
/// the sheet is dismissed.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  String? body,
  required List<Choice<T>> choices,
  required T current,
}) {
  return showRevampSheet<T>(
    context,
    title: title,
    builder: (context) {
      final colors = ShiaColors.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (body != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                body,
                style: ShiaText.secondary.copyWith(color: colors.textMuted),
              ),
            ),
            const SizedBox(height: 10),
          ],
          CardList(
            children: [
              for (final (i, choice) in choices.indexed)
                MergeSemantics(
                  child: Semantics(
                    selected: choice.value == current,
                    child: CardListRow(
                      first: i == 0,
                      last: i == choices.length - 1,
                      title: Text(choice.label),
                      subtitle: choice.sample ??
                          (choice.hint == null ? null : Text(choice.hint!)),
                      trailing: SizedBox.square(
                        dimension: 44,
                        child: choice.value == current
                            ? Center(
                                child: OutlineIcon(OutlineGlyph.check,
                                    size: 22,
                                    color: colors.accent,
                                    strokeWidth: 2.4),
                              )
                            : null,
                      ),
                      onTap: () => Navigator.of(context).pop(choice.value),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}
