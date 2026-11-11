import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Semantic colors and icon mapped to an [ExamRank].
final class ExamRankStyle {
  const ExamRankStyle({
    required this.bg,
    required this.border,
    required this.fg,
    required this.icon,
  });

  final Color bg;
  final Color border;
  final Color fg;
  final IconData icon;

  static ExamRankStyle of(ExamRank rank) {
    return switch (rank) {
      ExamRank.excellent => const ExamRankStyle(
          bg: AppColors.excellentBg,
          border: AppColors.excellentBorder,
          fg: AppColors.excellentFg,
          icon: LucideIcons.trophy,
        ),
      ExamRank.good => const ExamRankStyle(
          bg: AppColors.masteredBg,
          border: AppColors.masteredBorder,
          fg: AppColors.masteredFg,
          icon: LucideIcons.award,
        ),
      ExamRank.fair => const ExamRankStyle(
          bg: AppColors.surfaceTint,
          border: AppColors.borderSky,
          fg: AppColors.primaryDark,
          icon: LucideIcons.thumbsUp,
        ),
      ExamRank.average => const ExamRankStyle(
          bg: AppColors.developingBg,
          border: AppColors.developingBorder,
          fg: AppColors.developingFg,
          icon: LucideIcons.check,
        ),
      ExamRank.fail => const ExamRankStyle(
          bg: AppColors.weakBg,
          border: AppColors.weakBorder,
          fg: AppColors.weakFg,
          icon: LucideIcons.circleX,
        ),
    };
  }
}

/// Pill badge displaying the exam classification tier on a 100-point scale.
class ExamRankBadge extends StatelessWidget {
  const ExamRankBadge({
    super.key,
    required this.rank,
    this.compact = false,
  });

  final ExamRank rank;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = ExamRankStyle.of(rank);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style.icon,
            size: compact ? 14 : 16,
            color: style.fg,
          ),
          const SizedBox(width: 5),
          Text(
            rank.label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: style.fg,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Expandable 5-tier grading legend matching the official 100-point scale.
class ExamRankLegendCard extends StatelessWidget {
  const ExamRankLegendCard({
    super.key,
    this.highlightedRank,
  });

  final ExamRank? highlightedRank;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        shape: const Border(),
        title: const Text(
          'Bảng xếp loại (thang điểm 100)',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          for (var i = 0; i < ExamRank.values.length; i++) ...[
            _LegendRow(
              rank: ExamRank.values[i],
              highlighted: ExamRank.values[i] == highlightedRank,
            ),
            if (i < ExamRank.values.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.rank,
    required this.highlighted,
  });

  final ExamRank rank;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final style = ExamRankStyle.of(rank);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? style.bg : AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? style.border : AppColors.borderSky,
          width: highlighted ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rank.rangeLabel,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            rank.label,
            style: TextStyle(
              color: style.fg,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

