import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/shia_colors.dart';
import '../../widgets/outline_icon.dart';
import 'home_section.dart';

/// Today's date, the greeting, and the profile button that opens Settings
/// (docs/DESIGN_SPEC.md, Home section 1).
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final wide = isHomeWide(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE d MMMM').format(DateTime.now()),
                style: ShiaText.secondary.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 2),
              Semantics(
                header: true,
                child: Text(
                  'Assalamu alaykum',
                  style: (wide ? ShiaText.greetingWide : ShiaText.greeting)
                      .copyWith(color: colors.text),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Tooltip(
            message: 'Settings and account',
            child: Semantics(
              button: true,
              label: 'Settings and account',
              excludeSemantics: true,
              onTap: onOpenSettings,
              child: Material(
                color: colors.surface,
                shape: CircleBorder(side: BorderSide(color: colors.line)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpenSettings,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: OutlineIcon(
                        OutlineGlyph.profile,
                        size: 22,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
