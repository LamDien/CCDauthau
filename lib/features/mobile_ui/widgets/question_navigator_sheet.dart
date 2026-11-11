import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// BottomSheet grid showing all question numbers (`1..70`) and answer/flag states.
Future<void> showQuestionNavigatorSheet({
  required BuildContext context,
  required List<ExamQuestion> items,
  required Map<int, int> selectedByPosition,
  required Set<int> flaggedPositions,
  required int currentIndex,
  required ValueChanged<int> onJumpToIndex,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final answeredCount = selectedByPosition.length;
      final unansweredCount = items.length - answeredCount;

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Danh sách ${items.length} câu hỏi',
                              style: Theme.of(sheetContext).textTheme.titleMedium,
                            ),
                            Text(
                              'Đã làm: $answeredCount • Chưa làm: $unansweredCount',
                              style: Theme.of(sheetContext).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(LucideIcons.x),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: const [
                      _LegendItem(
                        color: AppColors.surfaceTint,
                        borderColor: AppColors.primary,
                        label: 'Đã làm',
                      ),
                      _LegendItem(
                        color: AppColors.surfaceCard,
                        borderColor: AppColors.unassessedBorder,
                        label: 'Chưa làm',
                      ),
                      _LegendItem(
                        color: AppColors.developingBg,
                        borderColor: AppColors.developingBorder,
                        label: 'Xem lại',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 56,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final isAnswered =
                          selectedByPosition.containsKey(item.position);
                      final isFlagged =
                          flaggedPositions.contains(item.position);
                      final isCurrent = index == currentIndex;

                      final Color bgColor;
                      final Color borderColor;
                      final Color fgColor;

                      if (isFlagged) {
                        bgColor = AppColors.developingBg;
                        borderColor = isCurrent
                            ? AppColors.primary
                            : AppColors.developingBorder;
                        fgColor = AppColors.developingFg;
                      } else if (isAnswered) {
                        bgColor = AppColors.surfaceTint;
                        borderColor = isCurrent
                            ? AppColors.primaryDark
                            : AppColors.primary;
                        fgColor = AppColors.primaryDark;
                      } else {
                        bgColor = AppColors.surfaceCard;
                        borderColor = isCurrent
                            ? AppColors.primary
                            : AppColors.unassessedBorder;
                        fgColor = AppColors.textPrimary;
                      }

                      return Material(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            onJumpToIndex(index);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: borderColor,
                                width: isCurrent ? 2.2 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: fgColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
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

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.borderColor,
    required this.label,
  });

  final Color color;
  final Color borderColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

