import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Countdown pill changing color in `< 5m` (amber) and `< 1m` (red) phases.
class CountdownBadge extends StatelessWidget {
  const CountdownBadge({
    super.key,
    required this.remainingSeconds,
    required this.isTimed,
  });

  final int remainingSeconds;
  final bool isTimed;

  @override
  Widget build(BuildContext context) {
    if (!isTimed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceTint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSky),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.timer, size: 15, color: AppColors.primaryDark),
            SizedBox(width: 5),
            Text(
              'Tự do',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final clamped = remainingSeconds < 0 ? 0 : remainingSeconds;
    final mins = (clamped ~/ 60).toString().padLeft(2, '0');
    final secs = (clamped % 60).toString().padLeft(2, '0');

    final Color bgColor;
    final Color borderColor;
    final Color fgColor;

    if (clamped < 60) {
      bgColor = AppColors.weakBg;
      borderColor = AppColors.weakBorder;
      fgColor = AppColors.weakFg;
    } else if (clamped < 300) {
      bgColor = AppColors.developingBg;
      borderColor = AppColors.developingBorder;
      fgColor = AppColors.developingFg;
    } else {
      bgColor = AppColors.surfaceTint;
      borderColor = AppColors.borderSky;
      fgColor = AppColors.primaryDark;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.timer, size: 15, color: fgColor),
          const SizedBox(width: 5),
          Text(
            '$mins:$secs',
            style: TextStyle(
              color: fgColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

