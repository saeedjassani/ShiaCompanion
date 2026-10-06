import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/shia_colors.dart';
import 'glass_surface.dart';
import 'outline_icon.dart';

/// The glass field that floats at the bottom of a list, the Library and the
/// search page (docs/DESIGN_SPEC.md, "Lists" and "Search"): 62 px tall,
/// fully rounded, a search glyph, the text, and a clear button once there is
/// some. An accent border shows while it has focus.
///
/// Place it with [LargeTitlePage.bottom], which keeps it 26 px off the
/// bottom, or just above the keyboard while that is up.
class FindField extends StatefulWidget {
  const FindField({
    super.key,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.autofocus = false,
    this.onSubmitted,
    this.textInputAction = TextInputAction.search,
  });

  static const double height = 62;

  final TextEditingController controller;

  /// What to type: "Find a dua", "Dua, surah or book". Also its label.
  final String hint;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;

  @override
  State<FindField> createState() => _FindFieldState();
}

class _FindFieldState extends State<FindField> {
  FocusNode? _ownFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(FindField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocusNode)?.removeListener(_rebuild);
      _focusNode.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focusNode.removeListener(_rebuild);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final radius = BorderRadius.circular(FindField.height / 2);
    final hasText = widget.controller.text.isNotEmpty;

    return SizedBox(
      height: FindField.height,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: _focusNode.hasFocus
              ? Border.all(color: colors.accent, width: 2)
              : null,
        ),
        child: GlassSurface(
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 18, end: 8),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: OutlineIcon(OutlineGlyph.search,
                      size: 22, color: colors.accent, strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  // A fixed-height field can only take so much: past 1.5x
                  // the text would no longer fit inside it.
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.5,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      autofocus: widget.autofocus,
                      textInputAction: widget.textInputAction,
                      onSubmitted: widget.onSubmitted,
                      cursorColor: colors.accent,
                      style: ShiaText.body.copyWith(color: colors.text),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: widget.hint,
                        hintStyle:
                            ShiaText.body.copyWith(color: colors.textMuted),
                      ),
                    ),
                  ),
                ),
                if (hasText)
                  _ClearButton(onPressed: () {
                    widget.controller.clear();
                    _focusNode.requestFocus();
                  })
                else
                  const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The filled round × that empties the field.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Semantics(
      button: true,
      label: context.l10n.findClear,
      excludeSemantics: true,
      onTap: onPressed,
      child: InkResponse(
        onTap: onPressed,
        radius: 22,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.textMuted,
                shape: BoxShape.circle,
              ),
              child: OutlineIcon(OutlineGlyph.close,
                  size: 14, color: colors.surface, strokeWidth: 2.6),
            ),
          ),
        ),
      ),
    );
  }
}
