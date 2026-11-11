import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Renders the 13-topic competency grid (Grey / Red / Amber / Green).
class TopicMasteryGrid extends StatelessWidget {
  const TopicMasteryGrid({
    super.key,
    required this.topics,
    required this.onTopicTap,
  });

  final List<TopicMasteryStatus> topics;
  final ValueChanged<TopicMasteryStatus> onTopicTap;

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Chưa có dữ liệu chuyên đề.'),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < topics.length; i++) ...[
          _TopicMasteryTile(
            status: topics[i],
            onTap: () => onTopicTap(topics[i]),
          ),
          if (i < topics.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TopicMasteryTile extends StatelessWidget {
  const _TopicMasteryTile({
    required this.status,
    required this.onTap,
  });

  final TopicMasteryStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _levelStyle(status.level);
    final accuracyText = status.accuracyPercent == null
        ? 'Chưa làm'
        : '${status.accuracyPercent!.toStringAsFixed(0)}%';

    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: style.borderColor, width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: style.bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${status.topicOrder}',
                  style: TextStyle(
                    color: style.fgColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.topicName,
                      style: Theme.of(context).textTheme.labelLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Đã làm ${status.assessedQuestions}/${status.totalQuestions} câu',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 12.5,
                              ),
                        ),
                        if (status.weakCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.weakBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${status.weakCount} câu yếu',
                              style: const TextStyle(
                                color: AppColors.weakFg,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: style.bgColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  accuracyText,
                  style: TextStyle(
                    color: style.fgColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _LevelVisualStyle _levelStyle(MasteryLevel level) {
    return switch (level) {
      MasteryLevel.unassessed => const _LevelVisualStyle(
          bgColor: AppColors.unassessedBg,
          borderColor: AppColors.borderSky,
          fgColor: AppColors.unassessedFg,
        ),
      MasteryLevel.weak => const _LevelVisualStyle(
          bgColor: AppColors.weakBg,
          borderColor: AppColors.weakBorder,
          fgColor: AppColors.weakFg,
        ),
      MasteryLevel.developing => const _LevelVisualStyle(
          bgColor: AppColors.developingBg,
          borderColor: AppColors.developingBorder,
          fgColor: AppColors.developingFg,
        ),
      MasteryLevel.mastered => const _LevelVisualStyle(
          bgColor: AppColors.masteredBg,
          borderColor: AppColors.masteredBorder,
          fgColor: AppColors.masteredFg,
        ),
    };
  }
}

class _LevelVisualStyle {
  const _LevelVisualStyle({
    required this.bgColor,
    required this.borderColor,
    required this.fgColor,
  });

  final Color bgColor;
  final Color borderColor;
  final Color fgColor;
}

