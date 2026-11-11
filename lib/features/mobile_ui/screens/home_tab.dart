import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/mobile_ui/controllers/app_state_controller.dart';
import 'package:cc_dau_thau/features/mobile_ui/widgets/topic_mastery_grid.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Zero-login landing screen showing readiness summary, quick launches, and 13-topic mastery map.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.controller,
    required this.onStartMockExam,
    required this.onOpenStudyTab,
    required this.onStartRevengeStudy,
    required this.onStartDiagnosticMiniTest,
    required this.onStartTopicStudy,
  });

  final AppStateController controller;
  final VoidCallback onStartMockExam;
  final VoidCallback onOpenStudyTab;
  final VoidCallback onStartRevengeStudy;
  final VoidCallback onStartDiagnosticMiniTest;
  final ValueChanged<TopicMasteryStatus> onStartTopicStudy;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final bank = controller.bank;
    if (summary == null || bank == null) {
      return const Center(child: Text('Đang nạp ngân hàng câu hỏi...'));
    }

    final masteredRatio = summary.totalBankQuestions == 0
        ? 0.0
        : summary.masteredQuestionsCount / summary.totalBankQuestions;
    final diagnosticCount = controller.settings.diagnosticPerTopic * 13;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _ReadinessCard(
          summary: summary,
          masteredRatio: masteredRatio,
          passThreshold: controller.settings.passScoreThreshold,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onStartMockExam,
                icon: const Icon(LucideIcons.clock, size: 19),
                label: Text(
                  'Thi thử 70 câu\n(${controller.settings.examDurationMinutes} phút)',
                  textAlign: TextAlign.center,
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOpenStudyTab,
                icon: const Icon(LucideIcons.bookOpen, size: 19),
                label: Text(
                  'Ôn ${bank.topics.length} chuyên đề\n(${bank.questions.length} câu)',
                  textAlign: TextAlign.center,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (summary.weakQueueCount > 0) ...[
          _QuickActionBanner(
            icon: LucideIcons.triangleAlert,
            accentColor: AppColors.weakFg,
            backgroundColor: AppColors.weakBg,
            borderColor: AppColors.weakBorder,
            title: 'Phục thù câu sai (${summary.weakQueueCount} câu)',
            subtitle:
                'Trả lời đúng ${controller.settings.revengeRequiredStreak} lần liên tiếp để gỡ khỏi danh sách yếu',
            actionLabel: 'Ôn ngay',
            onTap: onStartRevengeStudy,
          ),
          const SizedBox(height: 12),
        ],
        _QuickActionBanner(
          icon: LucideIcons.sparkles,
          accentColor: AppColors.primaryDark,
          backgroundColor: AppColors.surfaceTint,
          borderColor: AppColors.borderSky,
          title: 'Mini-test chẩn đoán nhanh ($diagnosticCount câu)',
          subtitle:
              'Mỗi chuyên đề ${controller.settings.diagnosticPerTopic} câu để khoanh vùng lỗ hổng nhanh',
          actionLabel: 'Làm thử',
          onTap: onStartDiagnosticMiniTest,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(
              LucideIcons.layers,
              size: 18,
              color: AppColors.primaryDark,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bản đồ năng lực ${summary.topicMasteries.length} chuyên đề',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Chạm vào chuyên đề bất kỳ để luyện tập ngay câu hỏi thuộc chuyên đề đó.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        TopicMasteryGrid(
          topics: summary.topicMasteries,
          onTopicTap: onStartTopicStudy,
        ),
      ],
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.summary,
    required this.masteredRatio,
    required this.passThreshold,
  });

  final ReadinessSummary summary;
  final double masteredRatio;
  final double passThreshold;

  @override
  Widget build(BuildContext context) {
    final lastScoreText = summary.latestMockScore == null
        ? '--'
        : '${summary.latestMockScore!.toStringAsFixed(1)}/100';
    final bestScoreText = summary.bestMockScore == null
        ? '--'
        : '${summary.bestMockScore!.toStringAsFixed(1)}/100';

    return Card(
      color: AppColors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.shieldCheck,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chỉ số sẵn sàng đi thi',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Ngưỡng đạt mục tiêu: ${passThreshold.toStringAsFixed(0)}/100',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 12.5,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(masteredRatio * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: masteredRatio.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: AppColors.surfaceTint,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _StatPill(
                  label: 'Đã nắm vững',
                  value:
                      '${summary.masteredQuestionsCount}/${summary.totalBankQuestions}',
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: 'Thi gần nhất',
                  value: lastScoreText,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: 'Cao nhất',
                  value: bestScoreText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.scaffoldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSky, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionBanner extends StatelessWidget {
  const _QuickActionBanner({
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.4),
          ),
          child: Row(
            children: [
              Icon(icon, color: accentColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

