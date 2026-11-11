import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';

/// Mastery status of a topic for the 13-topic competency map.
enum MasteryLevel { unassessed, weak, developing, mastered }

/// Configurable topic-mastery target, revenge streak, and exam timing preferences stored locally.
class UserSettings {
  const UserSettings({
    this.passScoreThreshold = 70.0,
    this.revengeRequiredStreak = 2,
    this.examDurationMinutes = 60,
    this.diagnosticPerTopic = 2,
  });

  static const double minPassScoreThreshold = 50.0;
  static const double maxPassScoreThreshold = 95.0;
  static const int minRevengeStreak = 1;
  static const int maxRevengeStreak = 5;
  static const List<int> allowedExamDurations = [30, 45, 60, 90];
  static const List<int> allowedDiagnosticPerTopic = [1, 2];

  /// Target accuracy percentage (50..95%) used to turn a topic green on the 13-topic map.
  final double passScoreThreshold;
  final int revengeRequiredStreak;
  final int examDurationMinutes;
  final int diagnosticPerTopic;

  /// Validates all fields at the storage boundary, throwing [ArgumentError] if invalid.
  void validate() {
    if (!passScoreThreshold.isFinite ||
        passScoreThreshold < minPassScoreThreshold ||
        passScoreThreshold > maxPassScoreThreshold) {
      throw ArgumentError.value(
        passScoreThreshold,
        'passScoreThreshold',
        'Mục tiêu nắm vững chuyên đề phải nằm trong khoảng $minPassScoreThreshold..$maxPassScoreThreshold.',
      );
    }
    if (revengeRequiredStreak < minRevengeStreak ||
        revengeRequiredStreak > maxRevengeStreak) {
      throw ArgumentError.value(
        revengeRequiredStreak,
        'revengeRequiredStreak',
        'Số lần đúng liên tiếp phải nằm trong khoảng $minRevengeStreak..$maxRevengeStreak.',
      );
    }
    if (!allowedExamDurations.contains(examDurationMinutes)) {
      throw ArgumentError.value(
        examDurationMinutes,
        'examDurationMinutes',
        'Thời gian thi thử chỉ chấp nhận ${allowedExamDurations.join(', ')} phút.',
      );
    }
    if (!allowedDiagnosticPerTopic.contains(diagnosticPerTopic)) {
      throw ArgumentError.value(
        diagnosticPerTopic,
        'diagnosticPerTopic',
        'Số câu mỗi chuyên đề mini-test chỉ chấp nhận ${allowedDiagnosticPerTopic.join(' hoặc ')}.',
      );
    }
  }

  UserSettings copyWith({
    double? passScoreThreshold,
    int? revengeRequiredStreak,
    int? examDurationMinutes,
    int? diagnosticPerTopic,
  }) {
    return UserSettings(
      passScoreThreshold: passScoreThreshold ?? this.passScoreThreshold,
      revengeRequiredStreak:
          revengeRequiredStreak ?? this.revengeRequiredStreak,
      examDurationMinutes: examDurationMinutes ?? this.examDurationMinutes,
      diagnosticPerTopic: diagnosticPerTopic ?? this.diagnosticPerTopic,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UserSettings &&
            passScoreThreshold == other.passScoreThreshold &&
            revengeRequiredStreak == other.revengeRequiredStreak &&
            examDurationMinutes == other.examDurationMinutes &&
            diagnosticPerTopic == other.diagnosticPerTopic;
  }

  @override
  int get hashCode => Object.hash(
        passScoreThreshold,
        revengeRequiredStreak,
        examDurationMinutes,
        diagnosticPerTopic,
      );
}

/// Persistent personal learning record for one question code.
class QuestionProgress {
  const QuestionProgress({
    required this.questionCode,
    required this.timesSeen,
    required this.timesCorrect,
    required this.timesWrong,
    required this.latestIsCorrect,
    required this.revengeStreak,
    required this.isWeakFlagged,
    required this.isBookmarked,
    required this.lastAnsweredAt,
  });

  factory QuestionProgress.initial(String questionCode) {
    return QuestionProgress(
      questionCode: questionCode,
      timesSeen: 0,
      timesCorrect: 0,
      timesWrong: 0,
      latestIsCorrect: null,
      revengeStreak: 0,
      isWeakFlagged: false,
      isBookmarked: false,
      lastAnsweredAt: null,
    );
  }

  final String questionCode;
  final int timesSeen;
  final int timesCorrect;
  final int timesWrong;
  final bool? latestIsCorrect;
  final int revengeStreak;
  final bool isWeakFlagged;
  final bool isBookmarked;
  final DateTime? lastAnsweredAt;

  QuestionProgress copyWith({
    int? timesSeen,
    int? timesCorrect,
    int? timesWrong,
    bool? latestIsCorrect,
    int? revengeStreak,
    bool? isWeakFlagged,
    bool? isBookmarked,
    DateTime? lastAnsweredAt,
  }) {
    return QuestionProgress(
      questionCode: questionCode,
      timesSeen: timesSeen ?? this.timesSeen,
      timesCorrect: timesCorrect ?? this.timesCorrect,
      timesWrong: timesWrong ?? this.timesWrong,
      latestIsCorrect: latestIsCorrect ?? this.latestIsCorrect,
      revengeStreak: revengeStreak ?? this.revengeStreak,
      isWeakFlagged: isWeakFlagged ?? this.isWeakFlagged,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      lastAnsweredAt: lastAnsweredAt ?? this.lastAnsweredAt,
    );
  }
}

/// Competency snapshot for one topic across all questions in the active bank.
class TopicMasteryStatus {
  const TopicMasteryStatus({
    required this.topicId,
    required this.topicOrder,
    required this.topicName,
    required this.totalQuestions,
    required this.assessedQuestions,
    required this.latestCorrectQuestions,
    required this.accuracyPercent,
    required this.weakCount,
    required this.level,
  });

  final String topicId;
  final int topicOrder;
  final String topicName;
  final int totalQuestions;
  final int assessedQuestions;
  final int latestCorrectQuestions;
  final double? accuracyPercent;
  final int weakCount;
  final MasteryLevel level;
}

/// Overall exam readiness and aggregated counters displayed on the Home tab.
class ReadinessSummary {
  const ReadinessSummary({
    required this.totalBankQuestions,
    required this.masteredQuestionsCount,
    required this.weakQueueCount,
    required this.bookmarkedCount,
    required this.mockAttemptCount,
    required this.latestMockScore,
    required this.bestMockScore,
    required this.topicMasteries,
  });

  final int totalBankQuestions;
  final int masteredQuestionsCount;
  final int weakQueueCount;
  final int bookmarkedCount;
  final int mockAttemptCount;
  final double? latestMockScore;
  final double? bestMockScore;
  final List<TopicMasteryStatus> topicMasteries;
}

/// Lightweight summary of a completed exam attempt shown in History list.
class ExamHistorySummary {
  const ExamHistorySummary({
    required this.attemptId,
    required this.mode,
    required this.submittedAt,
    required this.elapsedSeconds,
    required this.autoSubmittedByTimeout,
    required this.totalQuestions,
    required this.correctCount,
    required this.scoreOn100,
    required this.passThresholdUsed,
    required this.isPassed,
    required this.topicBreakdowns,
  });

  final String attemptId;
  final ExamMode mode;
  final DateTime submittedAt;
  final int elapsedSeconds;
  final bool autoSubmittedByTimeout;
  final int totalQuestions;
  final int correctCount;
  final double scoreOn100;
  final double passThresholdUsed;
  final bool isPassed;
  final List<TopicBreakdown> topicBreakdowns;

  /// 5-tier exam classification computed from [scoreOn100].
  ExamRank get rank => ExamRank.fromScore(scoreOn100);

  /// Whether this attempt displays the 5-tier classification badge.
  bool get supportsRanking => mode.supportsRanking;
}

/// Immutable snapshot of one exam question and the user's selected choice.
class ExamHistoryItem {
  const ExamHistoryItem({
    required this.position,
    required this.questionCode,
    required this.topicId,
    required this.topicName,
    required this.stem,
    required this.options,
    required this.selectedDisplayIndex,
    required this.correctDisplayIndex,
    required this.explanation,
    required this.legalReference,
    required this.pointGroupLabel,
  });

  final int position;
  final String questionCode;
  final String topicId;
  final String topicName;
  final String stem;
  final List<ShuffledOption> options;
  final int? selectedDisplayIndex;
  final int correctDisplayIndex;
  final String explanation;
  final String? legalReference;
  final String? pointGroupLabel;

  bool get isCorrect => selectedDisplayIndex == correctDisplayIndex;
  bool get isUnanswered => selectedDisplayIndex == null;
}

/// Full historical exam attempt including all snapshot question items.
class ExamHistoryEntry {
  const ExamHistoryEntry({
    required this.summary,
    required this.items,
  });

  final ExamHistorySummary summary;
  final List<ExamHistoryItem> items;
}

