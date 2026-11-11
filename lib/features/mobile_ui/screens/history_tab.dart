import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/mobile_ui/controllers/app_state_controller.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Displays unlimited local exam attempt history sorted newest-first.
class HistoryTab extends StatelessWidget {
  const HistoryTab({
    super.key,
    required this.controller,
    required this.onOpenAttemptDetail,
  });

  final AppStateController controller;
  final ValueChanged<String> onOpenAttemptDetail;

  String _formatDateTime(DateTime utcTime) {
    final local = utcTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} • $hour:$minute';
  }

  String _formatElapsed(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}p ${secs.toString().padLeft(2, '0')}s';
  }

  String _modeLabel(ExamMode mode) {
    return switch (mode) {
      ExamMode.mockExam => 'Thi thử 70 câu',
      ExamMode.diagnosticMiniTest => 'Mini-test chẩn đoán',
      ExamMode.retryWrong => 'Luyện lại câu sai',
    };
  }

  @override
  Widget build(BuildContext context) {
    final history = controller.history;
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.history,
                    size: 36,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Chưa có lịch sử làm bài',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sau khi hoàn thành bài thi thử hoặc mini-test, toàn bộ điểm số và đáp án từng câu sẽ được lưu tại đây.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = history[index];
        final passed = item.isPassed;
        final badgeBg = passed ? AppColors.masteredBg : AppColors.weakBg;
        final badgeFg = passed ? AppColors.masteredFg : AppColors.weakFg;
        final badgeBorder =
            passed ? AppColors.masteredBorder : AppColors.weakBorder;

        return Card(
          child: InkWell(
            onTap: () => onOpenAttemptDetail(item.attemptId),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceTint,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _modeLabel(item.mode),
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              _formatDateTime(item.submittedAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${item.scoreOn100.toStringAsFixed(2)} / 100 điểm',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.correctCount}/${item.totalQuestions} câu đúng • ${_formatElapsed(item.elapsedSeconds)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: badgeBorder),
                        ),
                        child: Text(
                          passed ? 'ĐẠT' : 'CHƯA ĐẠT',
                          style: TextStyle(
                            color: badgeFg,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
