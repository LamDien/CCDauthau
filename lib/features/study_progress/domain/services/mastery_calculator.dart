import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';

/// Pure domain policy governing weak-question flagging and streak clearance across all modes.
class WeakQueuePolicy {
  const WeakQueuePolicy();

  /// Applies an answered outcome in any mode (study, mock, diagnostic, retry, or revenge).
  QuestionProgress applyAnswer({
    required QuestionProgress current,
    required bool isCorrect,
    required int requiredStreak,
    required DateTime answeredAt,
  }) {
    if (!isCorrect) {
      return current.copyWith(
        timesSeen: current.timesSeen + 1,
        timesWrong: current.timesWrong + 1,
        latestIsCorrect: false,
        revengeStreak: 0,
        isWeakFlagged: true,
        lastAnsweredAt: answeredAt,
      );
    }

    final nextStreak =
        current.isWeakFlagged ? current.revengeStreak + 1 : current.revengeStreak;
    final stillWeak = current.isWeakFlagged && nextStreak < requiredStreak;

    return current.copyWith(
      timesSeen: current.timesSeen + 1,
      timesCorrect: current.timesCorrect + 1,
      latestIsCorrect: true,
      revengeStreak: nextStreak,
      isWeakFlagged: stillWeak,
      lastAnsweredAt: answeredAt,
    );
  }

  /// Re-evaluates weak status when the user changes [requiredStreak] in Settings.
  QuestionProgress reconcileThreshold(
    QuestionProgress current, {
    required int requiredStreak,
  }) {
    if (current.isWeakFlagged && current.revengeStreak >= requiredStreak) {
      return current.copyWith(isWeakFlagged: false);
    }
    return current;
  }

  /// Returns true if a question belongs in the active weak queue under [requiredStreak].
  bool isEffectivelyWeak(
    QuestionProgress? progress, {
    required int requiredStreak,
  }) {
    if (progress == null) return false;
    return progress.isWeakFlagged && progress.revengeStreak < requiredStreak;
  }
}

/// Pure calculator for the 13-topic competency map and readiness counters.
class MasteryCalculator {
  const MasteryCalculator({
    this.weakPolicy = const WeakQueuePolicy(),
  });

  final WeakQueuePolicy weakPolicy;

  static const double weakThresholdPercent = 60.0;

  /// Classifies a topic into unassessed, weak, developing, or mastered.
  MasteryLevel classifyTopicMastery({
    required int totalInTopic,
    required int assessedCount,
    required int latestCorrectCount,
    required double passThresholdPercent,
  }) {
    if (assessedCount == 0) return MasteryLevel.unassessed;
    final accuracy = (latestCorrectCount / assessedCount) * 100.0;
    if (accuracy < weakThresholdPercent) return MasteryLevel.weak;

    final minAssessedForMastery = totalInTopic < 5 ? totalInTopic : 5;
    if (accuracy >= passThresholdPercent &&
        assessedCount >= minAssessedForMastery) {
      return MasteryLevel.mastered;
    }
    return MasteryLevel.developing;
  }

  /// Aggregates active bank questions, user progress, and mock exam history.
  ReadinessSummary buildReadinessSummary({
    required QuestionBank bank,
    required Map<String, QuestionProgress> progressByCode,
    required UserSettings settings,
    required List<ExamHistorySummary> historySummaries,
  }) {
    final sortedTopics = List<Topic>.from(bank.topics)
      ..sort((a, b) => a.order.compareTo(b.order));

    final topicMasteries = <TopicMasteryStatus>[];
    for (final topic in sortedTopics) {
      final topicQuestions = bank.questionsByTopicId[topic.id] ?? const [];
      var assessedCount = 0;
      var latestCorrectCount = 0;
      var weakCount = 0;

      for (final q in topicQuestions) {
        final p = progressByCode[q.code];
        if (p == null) continue;
        if (p.latestIsCorrect != null) {
          assessedCount++;
          if (p.latestIsCorrect!) {
            latestCorrectCount++;
          }
        }
        if (weakPolicy.isEffectivelyWeak(
          p,
          requiredStreak: settings.revengeRequiredStreak,
        )) {
          weakCount++;
        }
      }

      final double? accuracy = assessedCount == 0
          ? null
          : (latestCorrectCount / assessedCount) * 100.0;

      topicMasteries.add(
        TopicMasteryStatus(
          topicId: topic.id,
          topicOrder: topic.order,
          topicName: topic.name,
          totalQuestions: topicQuestions.length,
          assessedQuestions: assessedCount,
          latestCorrectQuestions: latestCorrectCount,
          accuracyPercent: accuracy,
          weakCount: weakCount,
          level: classifyTopicMastery(
            totalInTopic: topicQuestions.length,
            assessedCount: assessedCount,
            latestCorrectCount: latestCorrectCount,
            passThresholdPercent: settings.passScoreThreshold,
          ),
        ),
      );
    }

    var masteredQuestionsCount = 0;
    var weakQueueCount = 0;
    var bookmarkedCount = 0;

    for (final q in bank.questions) {
      final p = progressByCode[q.code];
      if (p == null) continue;
      if (p.latestIsCorrect == true) {
        masteredQuestionsCount++;
      }
      if (weakPolicy.isEffectivelyWeak(
        p,
        requiredStreak: settings.revengeRequiredStreak,
      )) {
        weakQueueCount++;
      }
      if (p.isBookmarked) {
        bookmarkedCount++;
      }
    }

    final mockAttempts = historySummaries
        .where((h) => h.mode == ExamMode.mockExam)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    double? latestMockScore;
    double? bestMockScore;
    if (mockAttempts.isNotEmpty) {
      latestMockScore = mockAttempts.first.scoreOn100;
      bestMockScore = mockAttempts
          .map((e) => e.scoreOn100)
          .reduce((a, b) => a > b ? a : b);
    }

    return ReadinessSummary(
      totalBankQuestions: bank.questions.length,
      masteredQuestionsCount: masteredQuestionsCount,
      weakQueueCount: weakQueueCount,
      bookmarkedCount: bookmarkedCount,
      mockAttemptCount: mockAttempts.length,
      latestMockScore: latestMockScore,
      bestMockScore: bestMockScore,
      topicMasteries: topicMasteries,
    );
  }
}

