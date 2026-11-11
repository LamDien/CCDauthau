import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/mobile_ui/controllers/mock_exam_controller.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/exam_result_screen.dart';
import 'package:cc_dau_thau/features/mobile_ui/widgets/countdown_badge.dart';
import 'package:cc_dau_thau/features/mobile_ui/widgets/question_card.dart';
import 'package:cc_dau_thau/features/mobile_ui/widgets/question_navigator_sheet.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Full exam runner supporting countdown auto-submit, single vs full-paper view,
/// 70-question navigator sheet, unanswered warning before submit, and Back guard.
class MockExamScreen extends StatefulWidget {
  const MockExamScreen({
    super.key,
    required this.controller,
    this.currentBank,
    this.initialBookmarkedCodes = const {},
    this.onToggleBookmark,
    this.onExamCompleted,
    this.onRetryWrongQuestions,
    this.autoStartTimer = true,
  });

  final MockExamController controller;
  final QuestionBank? currentBank;
  final Set<String> initialBookmarkedCodes;
  final Future<bool> Function(String questionCode)? onToggleBookmark;
  final Future<void> Function(ExamHistoryEntry entry)? onExamCompleted;
  final void Function(List<String> wrongCodes)? onRetryWrongQuestions;
  final bool autoStartTimer;

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  late final List<GlobalKey> _itemKeys;
  bool _hasPushedResult = false;

  @override
  void initState() {
    super.initState();
    _itemKeys = List<GlobalKey>.generate(
      widget.controller.exam.items.length,
      (_) => GlobalKey(),
    );
    widget.controller.addListener(_onControllerChanged);
    if (widget.autoStartTimer) {
      widget.controller.startTimer();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  Future<void> _onControllerChanged() async {
    final entry = widget.controller.historyEntry;
    if (widget.controller.isSubmitted && entry != null && !_hasPushedResult) {
      _hasPushedResult = true;
      await widget.onExamCompleted?.call(entry);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ExamResultScreen(
            entry: entry,
            currentBank: widget.currentBank,
            bookmarkedCodes: widget.initialBookmarkedCodes,
            onToggleBookmark: widget.onToggleBookmark,
            onRetryWrongQuestions: widget.onRetryWrongQuestions,
          ),
        ),
      );
    }
  }

  void _jumpToQuestion(int index) {
    widget.controller.jumpToIndex(index);
    if (!widget.controller.isSingleQuestionView &&
        index >= 0 &&
        index < _itemKeys.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = _itemKeys[index].currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 250),
            alignment: 0.05,
          );
        }
      });
    }
  }

  Future<void> _handleManualSubmitPressed() async {
    final ctrl = widget.controller;
    final unanswered = ctrl.unansweredCount;
    final flagged = ctrl.flaggedCount;

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final hasPending = unanswered > 0 || flagged > 0;
        final parts = <String>[
          if (unanswered > 0) 'Bạn còn $unanswered câu chưa trả lời.',
          if (flagged > 0) 'Có $flagged câu đang đánh dấu xem lại.',
          if (!hasPending)
            'Bạn đã hoàn thành tất cả ${ctrl.totalQuestions} câu hỏi. Xác nhận nộp bài ngay?',
        ];

        return AlertDialog(
          title: Text(hasPending ? 'Kiểm tra trước khi nộp' : 'Xác nhận nộp bài'),
          content: Text(parts.join('\n')),
          actions: [
            if (unanswered > 0 && ctrl.firstUnansweredIndex != null)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                  _jumpToQuestion(ctrl.firstUnansweredIndex!);
                },
                child: const Text('Xem câu chưa làm đầu tiên'),
              )
            else
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Làm tiếp'),
              ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Nộp bài ngay'),
            ),
          ],
        );
      },
    );

    if (shouldSubmit == true && mounted) {
      await ctrl.submit(autoSubmittedByTimeout: false);
    }
  }

  Future<void> _confirmExitMidExam() async {
    if (widget.controller.isSubmitted) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thoát bài thi hiện tại?'),
        content: const Text(
          'Bài làm chưa nộp sẽ không được lưu vào lịch sử thi thử.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Ở lại làm tiếp'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  String _screenTitle(ExamMode mode) {
    return switch (mode) {
      ExamMode.mockExam => 'Thi thử 70 câu',
      ExamMode.diagnosticMiniTest => 'Mini-test chẩn đoán',
      ExamMode.retryWrong => 'Luyện lại câu sai',
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmExitMidExam();
        }
      },
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final ctrl = widget.controller;
          final items = ctrl.exam.items;

          return Scaffold(
            appBar: AppBar(
              title: Text(_screenTitle(ctrl.exam.mode)),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CountdownBadge(
                    remainingSeconds: ctrl.remainingSeconds,
                    isTimed: ctrl.isTimed,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton(
                    onPressed:
                        ctrl.isSubmitting || ctrl.isSubmitted
                            ? null
                            : _handleManualSubmitPressed,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 38),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: const Text('Nộp bài'),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Container(
                    color: AppColors.surfaceCard,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment<bool>(
                                value: true,
                                label: Text('Từng câu'),
                              ),
                              ButtonSegment<bool>(
                                value: false,
                                label: Text('Toàn bộ đề'),
                              ),
                            ],
                            selected: {ctrl.isSingleQuestionView},
                            onSelectionChanged: (sel) =>
                                ctrl.setViewMode(sel.first),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () => showQuestionNavigatorSheet(
                            context: context,
                            items: items,
                            selectedByPosition: ctrl.selectedByPosition,
                            flaggedPositions: ctrl.flaggedPositions,
                            currentIndex: ctrl.currentIndex,
                            onJumpToIndex: _jumpToQuestion,
                          ),
                          child: Text(
                            '${ctrl.answeredCount}/${ctrl.totalQuestions}',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(child: Text('Đề thi chưa có câu hỏi.'))
                        : ctrl.isSingleQuestionView
                            ? SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: _buildExamCard(
                                  ctrl,
                                  items[ctrl.currentIndex],
                                  items.length,
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    for (var i = 0; i < items.length; i++) ...[
                                      Container(
                                        key: _itemKeys[i],
                                        child: _buildExamCard(
                                          ctrl,
                                          items[i],
                                          items.length,
                                        ),
                                      ),
                                      if (i < items.length - 1)
                                        const SizedBox(height: 12),
                                    ],
                                  ],
                                ),
                              ),
                  ),
                  if (ctrl.isSingleQuestionView && items.isNotEmpty)
                    Container(
                      color: AppColors.surfaceCard,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: ctrl.currentIndex > 0
                                  ? () => ctrl.jumpToIndex(ctrl.currentIndex - 1)
                                  : null,
                              icon: const Icon(LucideIcons.chevronLeft, size: 18),
                              label: const Text('Câu trước'),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${ctrl.currentIndex + 1}/${items.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: ctrl.currentIndex < items.length - 1
                                  ? () => ctrl.jumpToIndex(ctrl.currentIndex + 1)
                                  : null,
                              icon: const Icon(LucideIcons.chevronRight, size: 18),
                              label: const Text('Câu tiếp'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExamCard(
    MockExamController ctrl,
    ExamQuestion item,
    int total,
  ) {
    return QuestionCard(
      displayNumber: item.position,
      totalQuestions: total,
      questionCode: item.questionCode,
      topicName: item.topicName,
      stem: item.stem,
      options: item.shuffledOptions,
      selectedDisplayIndex: ctrl.selectedByPosition[item.position],
      correctDisplayIndex: item.correctDisplayIndex,
      explanation: item.explanation,
      legalReference: item.legalReference,
      pointGroupLabel: item.pointGroupLabel,
      showFeedback: false,
      showExplanation: false,
      isFlagged: ctrl.flaggedPositions.contains(item.position),
      onSelectOption: (ctrl.isSubmitted ||
              ctrl.isSubmitting ||
              (ctrl.isTimed && ctrl.remainingSeconds <= 0))
          ? null
          : (optIdx) => ctrl.selectOption(item.position, optIdx),
      onToggleFlag: () => ctrl.toggleFlag(item.position),
    );
  }
}

