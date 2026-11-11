import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// BottomSheet displaying all questions sharing the same `pointGroupKey`
/// so learners can compare subtle legal/threshold variations side by side.
Future<void> showPointGroupSheet({
  required BuildContext context,
  required QuestionBank bank,
  required String pointGroupKey,
  required String currentQuestionCode,
  String? groupLabel,
}) {
  final peers = bank.questionsByPointGroup[pointGroupKey] ?? const [];
  final displayLabel =
      (groupLabel == null || groupLabel.trim().isEmpty) ? pointGroupKey : groupLabel;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSky,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.layers,
                        size: 20,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cùng điểm kiến thức (${peers.length} câu)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              displayLabel,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 12.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(LucideIcons.x),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: peers.isEmpty
                      ? const Center(
                          child: Text('Không tìm thấy câu cùng điểm trong kho hiện tại.'),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: peers.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final q = peers[index];
                            final isCurrent = q.code == currentQuestionCode;
                            final correctOpt = q.correctOption;
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? AppColors.surfaceTint
                                    : AppColors.scaffoldBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isCurrent
                                      ? AppColors.primary
                                      : AppColors.borderSky,
                                  width: isCurrent ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        q.code,
                                        style: const TextStyle(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: const Text(
                                            'Câu đang xem',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    q.stem,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Đáp án đúng: ${correctOpt.originalLabel}. ${correctOpt.text}',
                                    style: const TextStyle(
                                      color: AppColors.masteredFg,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  if (q.explanation.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      q.explanation,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

