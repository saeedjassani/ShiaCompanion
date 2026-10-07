import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/shia_colors.dart';
import 'outline_icon.dart';
import 'page_chrome.dart';

/// The reader's floating counter, a pocket Tasbeeh (docs/DESIGN_SPEC.md,
/// "Tools"): the whole panel counts one, the count in large type, then −1
/// and Reset, with Reset asking first as Tasbeeh's does. The grip and ×
/// along the top; the page makes the panel draggable.
class ZikrCounter extends StatefulWidget {
  static const double panelWidth = 236;
  static const double panelHeight = 204;

  final int count;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onReset;

  /// Hides the counter; the count is kept for when it comes back.
  final VoidCallback? onClose;

  const ZikrCounter({
    super.key,
    required this.count,
    required this.onIncrement,
    required this.onDecrement,
    required this.onReset,
    this.onClose,
  });

  @override
  State<ZikrCounter> createState() => _ZikrCounterState();
}

class _ZikrCounterState extends State<ZikrCounter> {
  bool _confirmingReset = false;

  void _increment() {
    if (_confirmingReset) setState(() => _confirmingReset = false);
    widget.onIncrement();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final count = widget.count;
    final radius = BorderRadius.circular(24);

    return SizedBox(
      width: ZikrCounter.panelWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: colors.glassShadow,
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: colors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _increment,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(minHeight: ZikrCounter.panelHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 4, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: OutlineIcon(OutlineGlyph.dragHandle,
                              size: 18, color: colors.chevron),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.counterHoldToMove,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ShiaText.caption
                                .copyWith(color: colors.textMuted),
                          ),
                        ),
                        if (widget.onClose != null)
                          _CloseButton(onPressed: widget.onClose!),
                      ],
                    ),
                    Semantics(
                      button: true,
                      label: l10n.tasbeehCountOne,
                      value: '$count',
                      excludeSemantics: true,
                      onTap: _increment,
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$count',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 60,
                                height: 1.05,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.5,
                                color: colors.text,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _confirmingReset
                                ? l10n.tasbeehStartAgainQuestion
                                : l10n.counterTapAnywhere,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ShiaText.caption.copyWith(
                              fontWeight: _confirmingReset
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: _confirmingReset
                                  ? colors.text
                                  : colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: _confirmingReset
                          ? Semantics(
                              liveRegion: true,
                              container: true,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: PillButton(
                                      label: l10n.commonCancel,
                                      height: 44,
                                      onPressed: () => setState(
                                          () => _confirmingReset = false),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: PillButton(
                                      label: l10n.tasbeehReset,
                                      height: 44,
                                      filled: true,
                                      onPressed: () {
                                        setState(
                                            () => _confirmingReset = false);
                                        widget.onReset();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              children: [
                                Semantics(
                                  label: l10n.tasbeehMinusOne,
                                  excludeSemantics: true,
                                  button: true,
                                  enabled: count > 0,
                                  onTap: count > 0 ? widget.onDecrement : null,
                                  child: PillButton(
                                    label: '−1',
                                    height: 44,
                                    onPressed:
                                        count > 0 ? widget.onDecrement : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: PillButton(
                                    label: l10n.tasbeehReset,
                                    glyph: OutlineGlyph.reset,
                                    height: 44,
                                    onPressed: count > 0
                                        ? () => setState(
                                            () => _confirmingReset = true)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The × that hides the counter: a small glyph with a 44 px target.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final label = context.l10n.zikrHideCounter;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: InkResponse(
          onTap: onPressed,
          radius: 22,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.well,
                  shape: BoxShape.circle,
                ),
                child: OutlineIcon(OutlineGlyph.close,
                    size: 14, color: colors.textMuted, strokeWidth: 2.2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
