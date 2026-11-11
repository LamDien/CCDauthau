import 'dart:async';

import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/exam_engine.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';
import 'package:cc_dau_thau/features/study_progress/domain/repositories/study_progress_repository.dart';
import 'package:flutter/foundation.dart';

/// State controller for an active mock exam, diagnostic test, or retry session.
class MockExamController extends ChangeNotifier {
  MockExamController({
    required this.exam,
    required this._engine,
    required this._progressRepo,
    required this._passScoreThreshold,
    DateTime Function()? clock,
  })  : _clock = clock ?? _defaultClock,
        remainingSeconds = exam.durationSeconds;

  static DateTime _defaultClock() => DateTime.now().toUtc();

  final GeneratedExam exam;
  final ExamEngine _engine;
  final StudyProgressRepository _progressRepo;
  final double _passScoreThreshold;
  final DateTime Function() _clock;

  int remainingSeconds;
  int _elapsedSeconds = 0;
  bool isSingleQuestionView = true;
  int currentIndex = 0;
  final Map<int, int> selectedByPosition = {};
  final Set<int> flaggedPositions = {};

  bool isSubmitting = false;
  bool isSubmitted = false;
  ExamEvaluationResult? evaluationResult;
  ExamHistoryEntry? historyEntry;
  Timer? _timer;

  int get totalQuestions => exam.items.length;
  int get answeredCount => selectedByPosition.length;
  int get unansweredCount => exam.items.length - selectedByPosition.length;
  int get flaggedCount => flaggedPositions.length;

  bool get isTimed => exam.durationSeconds > 0;
  bool get isWarningPhase =>
      isTimed && remainingSeconds < 300 && remainingSeconds >= 60;
  bool get isCriticalPhase => isTimed && remainingSeconds < 60;

  /// Returns 0-based index of the first unanswered question, or `null` if all answered.
  int? get firstUnansweredIndex {
    for (var i = 0; i < exam.items.length; i++) {
      if (!selectedByPosition.containsKey(exam.items[i].position)) {
        return i;
      }
    }
    return null;
  }

  /// Starts the 1-second periodic timer for countdown/elapsed tracking.
  void startTimer() {
    if (_timer != null || isSubmitted) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      tick(1);
    });
  }

  /// Advances timer state by [seconds] (callable synchronously in tests).
  void tick([int seconds = 1]) {
    if (isSubmitted || isSubmitting || seconds <= 0) return;

    _elapsedSeconds += seconds;
    if (!isTimed) {
      notifyListeners();
      return;
    }

    final nextRemaining = remainingSeconds - seconds;
    if (nextRemaining <= 0) {
      remainingSeconds = 0;
      _timer?.cancel();
      _timer = null;
      notifyListeners();
      unawaited(submit(autoSubmittedByTimeout: true));
      return;
    }

    remainingSeconds = nextRemaining;
    notifyListeners();
  }

  void selectOption(int position, int displayIndex) {
    if (isSubmitted || isSubmitting) return;
    if (isTimed && remainingSeconds <= 0) return;
    selectedByPosition[position] = displayIndex;
    notifyListeners();
  }

  void toggleFlag(int position) {
    if (isSubmitted || isSubmitting) return;
    if (!flaggedPositions.add(position)) {
      flaggedPositions.remove(position);
    }
    notifyListeners();
  }

  void setViewMode(bool singleQuestionView) {
    if (isSingleQuestionView == singleQuestionView) return;
    isSingleQuestionView = singleQuestionView;
    notifyListeners();
  }

  void jumpToIndex(int index) {
    if (exam.items.isEmpty) return;
    currentIndex = index.clamp(0, exam.items.length - 1);
    notifyListeners();
  }

  /// Grades and persists the exam atomically; guarded against duplicate submissions.
  Future<ExamHistoryEntry?> submit({bool autoSubmittedByTimeout = false}) async {
    if (isSubmitted) return historyEntry;
    if (isSubmitting) return null;

    isSubmitting = true;
    _timer?.cancel();
    _timer = null;
    notifyListeners();

    final usedElapsed = isTimed
        ? (exam.durationSeconds - remainingSeconds)
            .clamp(0, exam.durationSeconds)
        : _elapsedSeconds;

    final submission = ExamSubmission(
      exam: exam,
      selectedOptionByPosition: Map<int, int>.unmodifiable(selectedByPosition),
      elapsedSeconds: usedElapsed,
      submittedAt: _clock().toUtc(),
      autoSubmittedByTimeout: autoSubmittedByTimeout,
    );

    final evaluation = _engine.gradeExam(
      submission,
      passScoreThreshold: _passScoreThreshold,
    );
    final entry = await _progressRepo.recordExamEvaluation(
      submission,
      evaluation,
    );

    evaluationResult = evaluation;
    historyEntry = entry;
    isSubmitting = false;
    isSubmitted = true;
    notifyListeners();
    return entry;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
