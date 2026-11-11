import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Reusable sky-blue question card shared by Study, Mock Exam, and Exam Result screens.
class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.displayNumber,
    required this.questionCode,
    required this.topicName,
    required this.stem,
    required this.options,
    required this.correctDisplayIndex,
    required this.explanation,
    this.totalQuestions,
    this.selectedDisplayIndex,
    this.legalReference,
    this.pointGroupLabel,
    this.pointGroupPeerCount,
    this.showFeedback = false,
    this.showExplanation = false,
    this.isBookmarked = false,
    this.isFlagged = false,
    this.onSelectOption,
    this.onToggleBookmark,
    this.onToggleFlag,
    this.onRevealAnswer,
    this.onViewPointGroup,
  });

  final int displayNumber;
  final int? totalQuestions;
  final String questionCode;
  final String topicName;
  final String stem;
  final List<ShuffledOption> options;
  final int? selectedDisplayIndex;
  final int correctDisplayIndex;
  final String explanation;
  final String? legalReference;
  final String? pointGroupLabel;
  final int? pointGroupPeerCount;
  final bool showFeedback;
  final bool showExplanation;
  final bool isBookmarked;
  final bool isFlagged;
  final ValueChanged<int>? onSelectOption;
  final VoidCallback? onToggleBookmark;
  final VoidCallback? onToggleFlag;
  final VoidCallback? onRevealAnswer;
  final VoidCallback? onViewPointGroup;

  @override
  Widget build(BuildContext context) {
    final numberLabel = totalQuestions == null
        ? 'Câu $displayNumber'
        : 'Câu $displayNumber/$totalQuestions';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    numberLabel,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$questionCode • $topicName',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onToggleFlag != null)
                  IconButton(
                    tooltip: isFlagged ? 'Bỏ đánh dấu xem lại' : 'Đánh dấu xem lại',
                    onPressed: onToggleFlag,
                    icon: Icon(
                      LucideIcons.flag,
                      size: 20,
                      color: isFlagged
                          ? AppColors.developingFg
                          : AppColors.textSecondary,
                    ),
                  ),
                if (onToggleBookmark != null)
                  IconButton(
                    tooltip: isBookmarked ? 'Bỏ lưu câu hỏi' : 'Lưu vào tự chọn',
                    onPressed: onToggleBookmark,
                    icon: Icon(
                      LucideIcons.bookmark,
                      size: 20,
                      color: isBookmarked
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            if (pointGroupLabel != null && pointGroupLabel!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.borderSky),
                ),
                child: Text(
                  'Nhóm: $pointGroupLabel',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              stem,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < options.length; i++) ...[
              _OptionTile(
                option: options[i],
                isSelected: selectedDisplayIndex == i,
                isCorrectOption: correctDisplayIndex == i,
                showFeedback: showFeedback,
                onTap: onSelectOption == null ? null : () => onSelectOption!(i),
              ),
              if (i < options.length - 1) const SizedBox(height: 10),
            ],
            if (!showExplanation && onRevealAnswer != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRevealAnswer,
                  icon: const Icon(LucideIcons.eye, size: 17),
                  label: const Text('Xem đáp án & giải thích'),
                ),
              ),
            ],
            if (showExplanation) ...[
              const SizedBox(height: 14),
              _ExplanationBox(
                correctOption:
                    correctDisplayIndex >= 0 && correctDisplayIndex < options.length
                        ? options[correctDisplayIndex]
                        : null,
                legalReference: legalReference,
                explanation: explanation,
              ),
            ],
            if (onViewPointGroup != null && (pointGroupPeerCount ?? 0) > 0) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onViewPointGroup,
                icon: const Icon(LucideIcons.layers, size: 17),
                label: Text(
                  'Xem các câu cùng điểm kiến thức ($pointGroupPeerCount câu)',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.isCorrectOption,
    required this.showFeedback,
    required this.onTap,
  });

  final ShuffledOption option;
  final bool isSelected;
  final bool isCorrectOption;
  final bool showFeedback;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    var bgColor = AppColors.surfaceCard;
    var borderColor = AppColors.borderSky;
    var badgeBg = AppColors.scaffoldBg;
    var badgeFg = AppColors.primaryDark;
    IconData? trailingIcon;
    Color? trailingColor;

    if (showFeedback) {
      if (isCorrectOption) {
        bgColor = AppColors.masteredBg;
        borderColor = AppColors.masteredBorder;
        badgeBg = AppColors.masteredFg;
        badgeFg = Colors.white;
        trailingIcon = LucideIcons.circleCheck;
        trailingColor = AppColors.masteredFg;
      } else if (isSelected) {
        bgColor = AppColors.weakBg;
        borderColor = AppColors.weakBorder;
        badgeBg = AppColors.weakFg;
        badgeFg = Colors.white;
        trailingIcon = LucideIcons.circleX;
        trailingColor = AppColors.weakFg;
      }
    } else if (isSelected) {
      bgColor = AppColors.surfaceTint;
      borderColor = AppColors.primary;
      badgeBg = AppColors.primary;
      badgeFg = Colors.white;
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: isSelected || (showFeedback && isCorrectOption) ? 1.8 : 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  option.displayLabel,
                  style: TextStyle(
                    color: badgeFg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    option.text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                        ),
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(trailingIcon, size: 20, color: trailingColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplanationBox extends StatelessWidget {
  const _ExplanationBox({
    required this.correctOption,
    required this.legalReference,
    required this.explanation,
  });

  final ShuffledOption? correctOption;
  final String? legalReference;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSky, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (correctOption != null)
            Text(
              'Đáp án đúng: ${correctOption!.displayLabel}. ${correctOption!.text}',
              style: const TextStyle(
                color: AppColors.masteredFg,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          if (legalReference != null && legalReference!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Căn cứ pháp lý: $legalReference',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ],
          if (explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              explanation,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Chưa có giải thích chi tiết bổ sung trong file ngân hàng.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

