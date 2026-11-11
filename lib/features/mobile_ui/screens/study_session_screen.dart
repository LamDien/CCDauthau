import 'dart:math';

import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/answer_shuffler.dart';
import 'package:cc_dau_thau/features/mobile_ui/widgets/point_group_sheet.dart';
import 'package:cc_dau_thau/features/mobile_ui/widgets/question_card.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Interactive study session supporting single-question vs multi-question list view,
/// answer/order shuffling, instant explanation, bookmarks, and point-group comparison.
class StudySessionScreen extends StatefulWidget {
  const StudySessionScreen({
    super.key,
    required this.title,
    required this.questions,
    required this.bank,
    this.initialBookmarkedCodes = const {},
    this.isRevengeMode = false,
    this.initialShuffled = false,
    this.shuffler = const AnswerShuffler(),
    this.onAnswerRecorded,
    this.onToggleBookmark,
  });

  final String title;
  final List<Question> questions;
  final QuestionBank bank;
  final Set<String> initialBookmarkedCodes;
  final bool isRevengeMode;
  final bool initialShuffled;
  final AnswerShuffler shuffler;
  final Future<void> Function(
    String questionCode,
    bool isCorrect,
    bool isRevengeMode,
  )? onAnswerRecorded;
  final Future<bool> Function(String questionCode)? onToggleBookmark;

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  bool _isSingleView = true;
  late bool _isShuffled;
  int _currentIndex = 0;

  late List<ExamQuestion> _sessionItems;
  final Map<String, int> _selectedOriginalIndexByCode = {};
  final Set<String> _revealedCodes = {};
  late Set<String> _bookmarkedCodes;

  @override
  void initState() {
    super.initState();
    _isShuffled = widget.initialShuffled;
    _bookmarkedCodes = Set<String>.from(widget.initialBookmarkedCodes);
    _rebuildItems();
  }

  void _rebuildItems() {
    if (_isShuffled) {
      _sessionItems = widget.shuffler.buildShuffledQuestions(
        widget.questions,
        random: Random(),
      );
      return;
    }

    _sessionItems = [
      for (var i = 0; i < widget.questions.length; i++)
        _toUnshuffledExamQuestion(widget.questions[i], i + 1),
    ];
  }

  ExamQuestion _toUnshuffledExamQuestion(Question q, int position) {
    const labels = ['A', 'B', 'C', 'D'];
    return ExamQuestion(
      position: position,
      questionCode: q.code,
      topicId: q.topicId,
      topicName: q.topicName,
      stem: q.stem,
      shuffledOptions: [
        for (var i = 0; i < q.options.length; i++)
          ShuffledOption(
            displayLabel: i < labels.length ? labels[i] : '${i + 1}',
            text: q.options[i].text,
            originalIndex: q.options[i].originalIndex,
          ),
      ],
      correctDisplayIndex: q.options.indexWhere(
        (opt) => opt.originalIndex == q.correctOriginalIndex,
      ),
      explanation: q.explanation,
      legalReference: q.legalReference,
      pointGroupKey: q.pointGroupKey,
      pointGroupLabel: q.pointGroupLabel,
    );
  }

  int? _selectedDisplayIndexFor(ExamQuestion item) {
    final selectedOrig = _selectedOriginalIndexByCode[item.questionCode];
    if (selectedOrig == null) return null;
    final idx = item.shuffledOptions.indexWhere(
      (o) => o.originalIndex == selectedOrig,
    );
    return idx >= 0 ? idx : null;
  }

  Future<void> _selectOption(ExamQuestion item, int displayIndex) async {
    final chosenOrig = item.shuffledOptions[displayIndex].originalIndex;
    final alreadyAnswered =
        _selectedOriginalIndexByCode.containsKey(item.questionCode);
    final isCorrect = displayIndex == item.correctDisplayIndex;

    setState(() {
      _selectedOriginalIndexByCode[item.questionCode] = chosenOrig;
      _revealedCodes.add(item.questionCode);
    });

    if (!alreadyAnswered && widget.onAnswerRecorded != null) {
      await widget.onAnswerRecorded!(
        item.questionCode,
        isCorrect,
        widget.isRevengeMode,
      );
    }
  }

  Future<void> _handleBookmarkTap(String questionCode) async {
    final callback = widget.onToggleBookmark;
    if (callback == null) {
      setState(() {
        if (!_bookmarkedCodes.add(questionCode)) {
          _bookmarkedCodes.remove(questionCode);
        }
      });
      return;
    }
    final nextState = await callback(questionCode);
    if (!mounted) return;
    setState(() {
      if (nextState) {
        _bookmarkedCodes.add(questionCode);
      } else {
        _bookmarkedCodes.remove(questionCode);
      }
    });
  }

  Widget _buildCard(ExamQuestion item, int index) {
    final selectedDisplay = _selectedDisplayIndexFor(item);
    final isRevealed = _revealedCodes.contains(item.questionCode);
    final groupKey = item.pointGroupKey;
    final peerCount = groupKey == null
        ? 0
        : (widget.bank.questionsByPointGroup[groupKey]?.length ?? 0);

    return QuestionCard(
      displayNumber: index + 1,
      totalQuestions: _sessionItems.length,
      questionCode: item.questionCode,
      topicName: item.topicName,
      stem: item.stem,
      options: item.shuffledOptions,
      selectedDisplayIndex: selectedDisplay,
      correctDisplayIndex: item.correctDisplayIndex,
      explanation: item.explanation,
      legalReference: item.legalReference,
      pointGroupLabel: item.pointGroupLabel,
      pointGroupPeerCount: peerCount,
      showFeedback: isRevealed,
      showExplanation: isRevealed,
      isBookmarked: _bookmarkedCodes.contains(item.questionCode),
      onSelectOption: (optIdx) => _selectOption(item, optIdx),
      onToggleBookmark: () => _handleBookmarkTap(item.questionCode),
      onRevealAnswer: () {
        setState(() {
          _revealedCodes.add(item.questionCode);
        });
      },
      onViewPointGroup: groupKey == null
          ? null
          : () => showPointGroupSheet(
                context: context,
                bank: widget.bank,
                pointGroupKey: groupKey,
                currentQuestionCode: item.questionCode,
                groupLabel: item.pointGroupLabel,
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const SafeArea(
          child: Center(
            child: Text('Không có câu hỏi nào trong phiên ôn tập này.'),
          ),
        ),
      );
    }

    final answeredCount = _selectedOriginalIndexByCode.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: _isShuffled ? 'Đang bật đảo câu/đáp án' : 'Đảo câu & đáp án',
            onPressed: () {
              setState(() {
                _isShuffled = !_isShuffled;
                _currentIndex = 0;
                _rebuildItems();
              });
            },
            icon: Icon(
              LucideIcons.shuffle,
              color: _isShuffled ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.surfaceCard,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                          label: Text('Nhiều câu'),
                        ),
                      ],
                      selected: {_isSingleView},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _isSingleView = selection.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$answeredCount/${_sessionItems.length} đã làm',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isSingleView
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildCard(
                        _sessionItems[_currentIndex],
                        _currentIndex,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessionItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _buildCard(_sessionItems[index], index),
                    ),
            ),
            if (_isSingleView)
              Container(
                color: AppColors.surfaceCard,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _currentIndex > 0
                            ? () => setState(() => _currentIndex--)
                            : null,
                        icon: const Icon(LucideIcons.chevronLeft, size: 18),
                        label: const Text('Câu trước'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${_currentIndex + 1}/${_sessionItems.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _currentIndex < _sessionItems.length - 1
                            ? () => setState(() => _currentIndex++)
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
  }
}
