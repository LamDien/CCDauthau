import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';
import 'package:cc_dau_thau/features/study_progress/domain/services/mastery_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/sample_bank_builder.dart';

void main() {
  const policy = WeakQueuePolicy();
  const calculator = MasteryCalculator();

  group('UserSettings validation', () {
    test('accepts valid defaults and boundary configurations', () {
      const defaults = UserSettings();
      expect(defaults.passScoreThreshold, 70.0);
      expect(defaults.revengeRequiredStreak, 2);
      expect(defaults.examDurationMinutes, 60);
      expect(defaults.diagnosticPerTopic, 2);
      expect(() => defaults.validate(), returnsNormally);

      const minEdge = UserSettings(
        passScoreThreshold: 50.0,
        revengeRequiredStreak: 1,
        examDurationMinutes: 30,
        diagnosticPerTopic: 1,
      );
      const maxEdge = UserSettings(
        passScoreThreshold: 95.0,
        revengeRequiredStreak: 5,
        examDurationMinutes: 90,
        diagnosticPerTopic: 2,
      );
      expect(() => minEdge.validate(), returnsNormally);
      expect(() => maxEdge.validate(), returnsNormally);
    });

    test('rejects out-of-range pass thresholds, streaks, durations, and diagnostic counts', () {
      expect(
        () => const UserSettings(passScoreThreshold: -1).validate(),
        throwsArgumentError,
      );
      expect(
        () => const UserSettings(passScoreThreshold: 49.9).validate(),
        throwsArgumentError,
      );
      expect(
        () => const UserSettings(passScoreThreshold: 95.1).validate(),
        throwsArgumentError,
      );
      expect(
        () => const UserSettings(passScoreThreshold: 105).validate(),
        throwsArgumentError,
      );
      expect(
        () => const UserSettings(revengeRequiredStreak: 0).validate(),
        throwsArgumentError,
      );
      expect(
        () => const UserSettings(revengeRequiredStreak: 6).validate(),
        throwsArgumentError,
      );
      expect(
        () => const UserSettings(examDurationMinutes: 25).validate(),
        throwsArgumentError,
      );
      expect(
        () => const UserSettings(diagnosticPerTopic: 3).validate(),
        throwsArgumentError,
      );
    });
  });

  group('WeakQueuePolicy', () {
    final t1 = DateTime.utc(2026, 11, 11, 8, 0);
    final t2 = DateTime.utc(2026, 11, 11, 8, 5);
    final t3 = DateTime.utc(2026, 11, 11, 8, 10);

    test('wrong answer flags question weak and resets streak to 0', () {
      final afterWrong = policy.applyAnswer(
        current: QuestionProgress.initial('Q001'),
        isCorrect: false,
        requiredStreak: 2,
        answeredAt: t1,
      );

      expect(afterWrong.timesSeen, 1);
      expect(afterWrong.timesWrong, 1);
      expect(afterWrong.timesCorrect, 0);
      expect(afterWrong.latestIsCorrect, isFalse);
      expect(afterWrong.revengeStreak, 0);
      expect(afterWrong.isWeakFlagged, isTrue);
    });

    test('clears weak flag only after consecutive correct answers reach requiredStreak', () {
      var progress = policy.applyAnswer(
        current: QuestionProgress.initial('Q001'),
        isCorrect: false,
        requiredStreak: 2,
        answeredAt: t1,
      );

      // 1st correct answer (e.g. in study or mock exam): still weak
      progress = policy.applyAnswer(
        current: progress,
        isCorrect: true,
        requiredStreak: 2,
        answeredAt: t2,
      );
      expect(progress.revengeStreak, 1);
      expect(progress.isWeakFlagged, isTrue);
      expect(progress.latestIsCorrect, isTrue);

      // Wrong again in between -> resets streak to 0
      progress = policy.applyAnswer(
        current: progress,
        isCorrect: false,
        requiredStreak: 2,
        answeredAt: t2,
      );
      expect(progress.revengeStreak, 0);
      expect(progress.isWeakFlagged, isTrue);

      // Two consecutive correct answers clear the flag
      progress = policy.applyAnswer(
        current: progress,
        isCorrect: true,
        requiredStreak: 2,
        answeredAt: t3,
      );
      expect(progress.revengeStreak, 1);
      expect(progress.isWeakFlagged, isTrue);

      progress = policy.applyAnswer(
        current: progress,
        isCorrect: true,
        requiredStreak: 2,
        answeredAt: t3,
      );
      expect(progress.revengeStreak, 2);
      expect(progress.isWeakFlagged, isFalse);
    });

    test('changing requiredStreak 2 -> 1 clears streak=1 items and 2 -> 3 retains them', () {
      var progress = policy.applyAnswer(
        current: QuestionProgress.initial('Q001'),
        isCorrect: false,
        requiredStreak: 2,
        answeredAt: t1,
      );
      progress = policy.applyAnswer(
        current: progress,
        isCorrect: true,
        requiredStreak: 2,
        answeredAt: t2,
      );
      expect(progress.revengeStreak, 1);
      expect(policy.isEffectivelyWeak(progress, requiredStreak: 2), isTrue);

      // Threshold lowered from 2 to 1 -> cleared immediately
      final reconciledDown = policy.reconcileThreshold(progress, requiredStreak: 1);
      expect(reconciledDown.isWeakFlagged, isFalse);
      expect(policy.isEffectivelyWeak(progress, requiredStreak: 1), isFalse);

      // Threshold raised from 2 to 3 -> 2nd right answer is still < 3
      final secondCorrectAt3 = policy.applyAnswer(
        current: progress,
        isCorrect: true,
        requiredStreak: 3,
        answeredAt: t3,
      );
      expect(secondCorrectAt3.revengeStreak, 2);
      expect(secondCorrectAt3.isWeakFlagged, isTrue);

      final thirdCorrectAt3 = policy.applyAnswer(
        current: secondCorrectAt3,
        isCorrect: true,
        requiredStreak: 3,
        answeredAt: t3,
      );
      expect(thirdCorrectAt3.revengeStreak, 3);
      expect(thirdCorrectAt3.isWeakFlagged, isFalse);
    });
  });

  group('MasteryCalculator', () {
    test('classifies unassessed, weak, developing (with minAssessed guard), and mastered', () {
      expect(
        calculator.classifyTopicMastery(
          totalInTopic: 30,
          assessedCount: 0,
          latestCorrectCount: 0,
          passThresholdPercent: 70.0,
        ),
        MasteryLevel.unassessed,
      );

      // < 60% -> weak
      expect(
        calculator.classifyTopicMastery(
          totalInTopic: 30,
          assessedCount: 10,
          latestCorrectCount: 5,
          passThresholdPercent: 70.0,
        ),
        MasteryLevel.weak,
      );

      // 60% <= acc < 70% -> developing
      expect(
        calculator.classifyTopicMastery(
          totalInTopic: 30,
          assessedCount: 10,
          latestCorrectCount: 6,
          passThresholdPercent: 70.0,
        ),
        MasteryLevel.developing,
      );

      // 100% accuracy on only 1 question in 30-question topic -> developing (minAssessedForMastery = 5)
      expect(
        calculator.classifyTopicMastery(
          totalInTopic: 30,
          assessedCount: 1,
          latestCorrectCount: 1,
          passThresholdPercent: 70.0,
        ),
        MasteryLevel.developing,
      );

      // 5 questions answered with >= 70% -> mastered
      expect(
        calculator.classifyTopicMastery(
          totalInTopic: 30,
          assessedCount: 5,
          latestCorrectCount: 4,
          passThresholdPercent: 70.0,
        ),
        MasteryLevel.mastered,
      );

      // Small topic with 3 questions total -> minAssessedForMastery = 3
      expect(
        calculator.classifyTopicMastery(
          totalInTopic: 3,
          assessedCount: 3,
          latestCorrectCount: 3,
          passThresholdPercent: 70.0,
        ),
        MasteryLevel.mastered,
      );
    });

    test('computes ReadinessSummary using latestIsCorrect, filtering removed codes, and mock-only scores', () {
      final bank = buildSampleQuestionBank();
      final firstTopic = bank.topics.first;
      final topic1Questions = bank.questionsByTopicId[firstTopic.id]!;
      final progress = <String, QuestionProgress>{};

      // Answer first 5 questions of Topic 1 wrong, then fix 4 of them -> 4/5 = 80% -> mastered!
      for (var i = 0; i < 5; i++) {
        final code = topic1Questions[i].code;
        progress[code] = QuestionProgress(
          questionCode: code,
          timesSeen: 2,
          timesCorrect: i < 4 ? 1 : 0,
          timesWrong: 1,
          latestIsCorrect: i < 4,
          revengeStreak: i < 4 ? 1 : 0,
          isWeakFlagged: true,
          isBookmarked: i == 0,
          lastAnsweredAt: DateTime.utc(2026, 11, 11),
        );
      }
      // Also include an obsolete code from an old bank version -> must be ignored in summary
      progress['REMOVED_Q999'] = QuestionProgress(
        questionCode: 'REMOVED_Q999',
        timesSeen: 1,
        timesCorrect: 0,
        timesWrong: 1,
        latestIsCorrect: false,
        revengeStreak: 0,
        isWeakFlagged: true,
        isBookmarked: true,
        lastAnsweredAt: DateTime.utc(2026, 11, 10),
      );

      final history = [
        ExamHistorySummary(
          attemptId: 'diag-1',
          mode: ExamMode.diagnosticMiniTest,
          submittedAt: DateTime.utc(2026, 11, 11, 10),
          elapsedSeconds: 300,
          autoSubmittedByTimeout: false,
          totalQuestions: 26,
          correctCount: 25,
          scoreOn100: 96.15,
          passThresholdUsed: 70.0,
          isPassed: true,
          topicBreakdowns: const [],
        ),
        ExamHistorySummary(
          attemptId: 'mock-2',
          mode: ExamMode.mockExam,
          submittedAt: DateTime.utc(2026, 11, 11, 9),
          elapsedSeconds: 2000,
          autoSubmittedByTimeout: false,
          totalQuestions: 70,
          correctCount: 52,
          scoreOn100: 74.29,
          passThresholdUsed: 70.0,
          isPassed: true,
          topicBreakdowns: const [],
        ),
        ExamHistorySummary(
          attemptId: 'mock-1',
          mode: ExamMode.mockExam,
          submittedAt: DateTime.utc(2026, 11, 11, 8),
          elapsedSeconds: 2500,
          autoSubmittedByTimeout: false,
          totalQuestions: 70,
          correctCount: 56,
          scoreOn100: 80.0,
          passThresholdUsed: 70.0,
          isPassed: true,
          topicBreakdowns: const [],
        ),
      ];

      final summary = calculator.buildReadinessSummary(
        bank: bank,
        progressByCode: progress,
        settings: const UserSettings(),
        historySummaries: history,
      );

      expect(summary.totalBankQuestions, 430);
      expect(summary.masteredQuestionsCount, 4);
      expect(summary.weakQueueCount, 5);
      expect(summary.bookmarkedCount, 1);
      expect(summary.mockAttemptCount, 2);
      expect(summary.latestMockScore, 74.29);
      expect(summary.bestMockScore, 80.0);

      final topic1Mastery = summary.topicMasteries.first;
      expect(topic1Mastery.topicId, firstTopic.id);
      expect(topic1Mastery.assessedQuestions, 5);
      expect(topic1Mastery.latestCorrectQuestions, 4);
      expect(topic1Mastery.accuracyPercent, 80.0);
      expect(topic1Mastery.weakCount, 5);
      expect(topic1Mastery.level, MasteryLevel.mastered);

      // Re-evaluating with passScoreThreshold = 85 turns 80% into developing
      final stricterSummary = calculator.buildReadinessSummary(
        bank: bank,
        progressByCode: progress,
        settings: const UserSettings(passScoreThreshold: 85.0),
        historySummaries: history,
      );
      expect(stricterSummary.topicMasteries.first.level, MasteryLevel.developing);
    });
  });
}
