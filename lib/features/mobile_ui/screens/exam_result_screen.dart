import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/mobile_ui/widgets/point_group_sheet.dart';
import 'package:cc_dau_thau/features/mobile_ui/widgets/question_card.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum _ResultFilter { all, wrong, correct }

/// Displays exam score on 100, topic breakdown, wrong-question retry CTA, and full review.
class ExamResultScreen extends StatefulWidget {
  const ExamResultScreen({
    super.key,
    required this.entry,
    this.currentBank,
    this.bookmarkedCodes = const {},
    this.onToggleBookmark,
    this.onRetryWrongQuestions,
  });

  final ExamHistoryEntry entry;
  final QuestionBank? currentBank;
  final Set<String> bookmarkedCodes;
  final Future<bool> Function(String questionCode)? onToggleBookmark;
  final void Function(List<String> wrongCodes)? onRetryWrongQuestions;

  @override
  State<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends State<ExamResultScreen> {
  _ResultFilter _filter = _ResultFilter.all;
  late Set<String> _bookmarkedCodes;

  @override
  void initState() {
    super.initState();
    _bookmarkedCodes = Set<String>.from(widget.bookmarkedCodes);
  }

  Future<void> _handleBookmarkTap(String questionCode) async {
    final cb = widget.onToggleBookmark;
    if (cb == null) return;
    final next = await cb(questionCode);
    if (!mounted) return;
    setState(() {
      if (next) {
        _bookmarkedCodes.add(questionCode);
      } else {
        _bookmarkedCodes.remove(questionCode);
      }
    });
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}p ${secs.toString().padLeft(2, '0')}s';
  }

  String _modeLabel(ExamMode mode) {
    return switch (mode) {
      ExamMode.mockExam => 'Kết quả thi thử',
      ExamMode.diagnosticMiniTest => 'Kết quả Mini-test',
      ExamMode.retryWrong => 'Kết quả luyện lại câu sai',
    };
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.entry.summary;
    final items = widget.entry.items;
    final wrongItems = items.where((item) => !item.isCorrect).toList();
    final wrongCodes = wrongItems.map((e) => e.questionCode).toList();
    final unansweredCount = items.where((e) => e.isUnanswered).length;
    final wrongAnsweredCount = wrongItems.length - unansweredCount;

    final filteredItems = switch (_filter) {
      _ResultFilter.all => items,
      _ResultFilter.wrong => wrongItems,
      _ResultFilter.correct => items.where((item) => item.isCorrect).toList(),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_modeLabel(summary.mode)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _ScoreSummaryCard(
              summary: summary,
              wrongAnsweredCount: wrongAnsweredCount,
              unansweredCount: unansweredCount,
              durationLabel: _formatDuration(summary.elapsedSeconds),
            ),
            if (wrongCodes.isNotEmpty && widget.onRetryWrongQuestions != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => widget.onRetryWrongQuestions!(wrongCodes),
                icon: const Icon(LucideIcons.rotateCcw, size: 18),
                label: Text(
                  'Luyện lại riêng các câu vừa sai (${wrongCodes.length} câu)',
                ),
              ),
            ],
            if (summary.topicBreakdowns.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: ExpansionTile(
                  initiallyExpanded: summary.mode == ExamMode.mockExam,
                  shape: const Border(),
                  title: const Text(
                    'Phân tích theo chuyên đề',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [
                    for (final b in summary.topicBreakdowns) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                b.topicName,
                                style: const TextStyle(fontSize: 13.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${b.correctCount}/${b.totalInExam}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: b.correctCount * 100 >=
                                        b.totalInExam * summary.passThresholdUsed
                                    ? AppColors.masteredFg
                                    : AppColors.weakFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Xem lại chi tiết câu hỏi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            SegmentedButton<_ResultFilter>(
              segments: [
                ButtonSegment<_ResultFilter>(
                  value: _ResultFilter.all,
                  label: Text('Tất cả (${items.length})'),
                ),
                ButtonSegment<_ResultFilter>(
                  value: _ResultFilter.wrong,
                  label: Text('Sai (${wrongItems.length})'),
                ),
                ButtonSegment<_ResultFilter>(
                  value: _ResultFilter.correct,
                  label: Text('Đúng (${summary.correctCount})'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (sel) => setState(() => _filter = sel.first),
            ),
            const SizedBox(height: 12),
            if (filteredItems.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('Không có câu hỏi nào trong mục lọc này.'),
                  ),
                ),
              )
            else
              for (var i = 0; i < filteredItems.length; i++) ...[
                _buildReviewItem(context, filteredItems[i], items.length),
                if (i < filteredItems.length - 1) const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(
    BuildContext context,
    ExamHistoryItem item,
    int total,
  ) {
    final bank = widget.currentBank;
    final liveQuestion = bank?.questionsByCode[item.questionCode];
    final groupKey = liveQuestion?.pointGroupKey;
    final peerCount = (bank != null && groupKey != null)
        ? (bank.questionsByPointGroup[groupKey]?.length ?? 0)
        : 0;

    return QuestionCard(
      displayNumber: item.position,
      totalQuestions: total,
      questionCode: item.questionCode,
      topicName: item.topicName,
      stem: item.stem,
      options: item.options,
      selectedDisplayIndex: item.selectedDisplayIndex,
      correctDisplayIndex: item.correctDisplayIndex,
      explanation: item.explanation,
      legalReference: item.legalReference,
      pointGroupLabel: item.pointGroupLabel,
      pointGroupPeerCount: peerCount,
      showFeedback: true,
      showExplanation: true,
      isBookmarked: _bookmarkedCodes.contains(item.questionCode),
      onToggleBookmark: widget.onToggleBookmark == null
          ? null
          : () => _handleBookmarkTap(item.questionCode),
      onViewPointGroup: (bank != null && groupKey != null && peerCount > 0)
          ? () => showPointGroupSheet(
                context: context,
                bank: bank,
                pointGroupKey: groupKey,
                currentQuestionCode: item.questionCode,
                groupLabel: item.pointGroupLabel,
              )
          : null,
    );
  }
}

class _ScoreSummaryCard extends StatelessWidget {
  const _ScoreSummaryCard({
    required this.summary,
    required this.wrongAnsweredCount,
    required this.unansweredCount,
    required this.durationLabel,
  });

  final ExamHistorySummary summary;
  final int wrongAnsweredCount;
  final int unansweredCount;
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    final passed = summary.isPassed;
    final badgeBg = passed ? AppColors.masteredBg : AppColors.weakBg;
    final badgeFg = passed ? AppColors.masteredFg : AppColors.weakFg;
    final badgeBorder = passed ? AppColors.masteredBorder : AppColors.weakBorder;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.scoreOn100.toStringAsFixed(2)} / 100 điểm',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ngưỡng đạt: ${summary.passThresholdUsed.toStringAsFixed(0)}/100 • Thời gian: $durationLabel',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: badgeBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        passed ? LucideIcons.award : LucideIcons.circleX,
                        size: 16,
                        color: badgeFg,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        passed ? 'ĐẠT' : 'CHƯA ĐẠT',
                        style: TextStyle(
                          color: badgeFg,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (summary.autoSubmittedByTimeout) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.developingBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.developingBorder),
                ),
                child: const Text(
                  'Bài thi đã được hệ thống tự động nộp khi hết giờ.',
                  style: TextStyle(
                    color: AppColors.developingFg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                _ResultStat(
                  label: 'Đúng',
                  value: '${summary.correctCount}',
                  fg: AppColors.masteredFg,
                ),
                const SizedBox(width: 8),
                _ResultStat(
                  label: 'Sai',
                  value: '$wrongAnsweredCount',
                  fg: AppColors.weakFg,
                ),
                const SizedBox(width: 8),
                _ResultStat(
                  label: 'Bỏ trống',
                  value: '$unansweredCount',
                  fg: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
    required this.label,
    required this.value,
    required this.fg,
  });

  final String label;
  final String value;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.scaffoldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSky),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: fg,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

