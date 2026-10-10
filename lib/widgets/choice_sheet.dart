import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/shia_colors.dart';
import 'outline_icon.dart';
import 'page_chrome.dart';
import 'responsive_content.dart';

/// Opens a picker or an editor where a phone and a bigger screen each
/// expect one (docs/DESIGN_SPEC.md, "Responsive behaviour"): a bottom sheet
/// on a phone, a centred dialog [maxWidth] wide from tablet width up, where
/// a sheet stretched along the bottom of a wide window reads as a banner
/// rather than something to answer.
///
/// [builder]'s content sizes itself to fit, scrolling when it is long, as
/// in a sheet; [SheetPresentation.inDialog] tells it to leave out the drag
/// handle.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 560,
  Color? backgroundColor,
  bool showDragHandle = false,
}) {
  final colors = ShiaColors.of(context);
  final background = backgroundColor ?? colors.ground;
  if (ScreenClass.of(context).atLeastTablet) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: math.min(760, MediaQuery.sizeOf(context).height * 0.88),
          ),
          child: SheetPresentation(
              inDialog: true, child: Builder(builder: builder)),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: showDragHandle,
    backgroundColor: background,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) =>
        SheetPresentation(inDialog: false, child: Builder(builder: builder)),
  );
}

/// Whether what [showAdaptiveSheet] opened is a dialog or a bottom sheet.
class SheetPresentation extends InheritedWidget {
  const SheetPresentation({
    super.key,
    required this.inDialog,
    required super.child,
  });

  final bool inDialog;

  /// False outside [showAdaptiveSheet]: a sheet opened some other way.
  static bool inDialogOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SheetPresentation>()
          ?.inDialog ??
      false;

  @override
  bool updateShouldNotify(SheetPresentation oldWidget) =>
      inDialog != oldWidget.inDialog;
}

/// Opens a sheet in the revamp's style (the reader's Text sheet): the
/// ground colour, a drag handle, a section title with Done, then
/// [builder]'s content, scrolling when it is long. [closeLabel] renames
/// Done. A centred dialog from tablet width up ([showAdaptiveSheet]).
Future<T?> showRevampSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  String? closeLabel,
}) {
  return showAdaptiveSheet<T>(
    context,
    builder: (context) => SheetFrame(
        title: title, closeLabel: closeLabel, child: builder(context)),
  );
}

/// What [showRevampSheet] draws around its content.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.closeLabel,
  });

  final String title;
  final Widget child;

  /// What the button beside the title says; Done when null. "Cancel" on a
  /// form, where closing sends nothing.
  final String? closeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final inDialog = SheetPresentation.inDialogOf(context);
    return SingleChildScrollView(
      // Clear of the keyboard while a field in the sheet has it up.
      padding: inDialog
          ? const EdgeInsetsDirectional.fromSTEB(20, 14, 16, 20)
          : EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 +
                  MediaQuery.paddingOf(context).bottom +
                  MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!inDialog) ...[
            const SheetDragHandle(),
            const SizedBox(height: 6),
          ],
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
                label: closeLabel ?? context.l10n.commonDone,
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

/// The 40 × 5 bar at the top of a bottom sheet; nothing in a dialog
/// ([SheetPresentation]), which is not dragged.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    if (SheetPresentation.inDialogOf(context)) return const SizedBox.shrink();
    return Center(
      child: Container(
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: ShiaColors.of(context).line,
          borderRadius: BorderRadius.circular(3),
        ),
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
