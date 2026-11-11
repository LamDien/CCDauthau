/// Exam session modes supported by `exam-engine`.
enum ExamMode {
  mockExam,
  diagnosticMiniTest,
  retryWrong;

  /// Whether completed attempts in this mode receive the 5-tier exam rank.
  bool get supportsRanking => this != ExamMode.retryWrong;
}

/// Official 5-tier exam classification on a 100-point scale.
enum ExamRank {
  excellent(
    label: 'Xuất sắc',
    rangeLabel: 'Từ 90% trở lên',
    isPassed: true,
  ),
  good(
    label: 'Giỏi',
    rangeLabel: 'Từ 80% đến dưới 90%',
    isPassed: true,
  ),
  fair(
    label: 'Khá',
    rangeLabel: 'Từ 60% đến dưới 80%',
    isPassed: true,
  ),
  average(
    label: 'Trung bình',
    rangeLabel: 'Từ 50% đến dưới 60%',
    isPassed: true,
  ),
  fail(
    label: 'Không đạt yêu cầu',
    rangeLabel: 'Dưới 50%',
    isPassed: false,
  );

  const ExamRank({
    required this.label,
    required this.rangeLabel,
    required this.isPassed,
  });

  final String label;
  final String rangeLabel;
  final bool isPassed;

  /// Minimum 100-point score required to achieve a passing classification.
  static const double passingScore = 50.0;

  /// Classifies a 0..100 score into one of the 5 official ranking tiers.
  static ExamRank fromScore(double scoreOn100) {
    const eps = 1e-9;
    if (scoreOn100 >= 90.0 - eps) return ExamRank.excellent;
    if (scoreOn100 >= 80.0 - eps) return ExamRank.good;
    if (scoreOn100 >= 60.0 - eps) return ExamRank.fair;
    if (scoreOn100 >= passingScore - eps) return ExamRank.average;
    return ExamRank.fail;
  }
}

/// Parameters controlling mock exam generation and grading.
final class ExamConfig {
  const ExamConfig({
    this.totalQuestions = 70,
    this.durationSeconds = 3600,
    this.passScoreThreshold = ExamRank.passingScore,
  });

  final int totalQuestions;
  final int durationSeconds;
  final double passScoreThreshold;
}

/// A single answer choice after shuffling into display positions A..D.
final class ShuffledOption {
  const ShuffledOption({
    required this.displayLabel,
    required this.text,
    required this.originalIndex,
  });

  final String displayLabel;
  final String text;
  final int originalIndex;

  Map<String, Object?> toJson() => {
    'displayLabel': displayLabel,
    'text': text,
    'originalIndex': originalIndex,
  };

  factory ShuffledOption.fromJson(Map<String, Object?> json) => ShuffledOption(
    displayLabel: json['displayLabel'] as String,
    text: json['text'] as String,
    originalIndex: (json['originalIndex'] as num).toInt(),
  );
}

/// Question item inside a generated exam with randomized option positions.
final class ExamQuestion {
  ExamQuestion({
    required this.position,
    required this.questionCode,
    required this.topicId,
    required this.topicName,
    required this.stem,
    required List<ShuffledOption> shuffledOptions,
    required this.correctDisplayIndex,
    required this.explanation,
    this.legalReference,
    this.pointGroupKey,
    this.pointGroupLabel,
  }) : shuffledOptions = List<ShuffledOption>.unmodifiable(shuffledOptions);

  final int position;
  final String questionCode;
  final String topicId;
  final String topicName;
  final String stem;
  final List<ShuffledOption> shuffledOptions;
  final int correctDisplayIndex;
  final String explanation;
  final String? legalReference;
  final String? pointGroupKey;
  final String? pointGroupLabel;

  ShuffledOption get correctOption => shuffledOptions[correctDisplayIndex];
}

/// Complete exam paper produced by `ExamEngine`.
final class GeneratedExam {
  GeneratedExam({
    required this.examId,
    required this.mode,
    required this.durationSeconds,
    required this.createdAt,
    required List<ExamQuestion> items,
  }) : items = List<ExamQuestion>.unmodifiable(items);

  final String examId;
  final ExamMode mode;
  final int durationSeconds;
  final DateTime createdAt;
  final List<ExamQuestion> items;
}

/// User answers and timing metadata submitted for grading.
final class ExamSubmission {
  ExamSubmission({
    required this.exam,
    required Map<int, int> selectedOptionByPosition,
    required this.elapsedSeconds,
    required this.submittedAt,
    required this.autoSubmittedByTimeout,
  }) : selectedOptionByPosition =
            Map<int, int>.unmodifiable(selectedOptionByPosition);

  final GeneratedExam exam;
  final Map<int, int> selectedOptionByPosition;
  final int elapsedSeconds;
  final DateTime submittedAt;
  final bool autoSubmittedByTimeout;
}

/// Topic-level breakdown within an evaluated exam attempt.
final class TopicBreakdown {
  const TopicBreakdown({
    required this.topicId,
    required this.topicName,
    required this.totalInExam,
    required this.correctCount,
  });

  final String topicId;
  final String topicName;
  final int totalInExam;
  final int correctCount;

  Map<String, Object?> toJson() => {
    'topicId': topicId,
    'topicName': topicName,
    'totalInExam': totalInExam,
    'correctCount': correctCount,
  };

  factory TopicBreakdown.fromJson(Map<String, Object?> json) => TopicBreakdown(
    topicId: json['topicId'] as String,
    topicName: json['topicName'] as String,
    totalInExam: (json['totalInExam'] as num).toInt(),
    correctCount: (json['correctCount'] as num).toInt(),
  );
}

/// Per-question grading result for review and progress tracking.
final class QuestionOutcome {
  const QuestionOutcome({
    required this.question,
    required this.selectedDisplayIndex,
    required this.isCorrect,
  });

  final ExamQuestion question;
  final int? selectedDisplayIndex;
  final bool isCorrect;
}

/// Complete grading evaluation on a 100-point scale with official ranking.
final class ExamEvaluationResult {
  ExamEvaluationResult({
    required this.examId,
    required this.totalQuestions,
    required this.correctCount,
    required this.unansweredCount,
    required this.scoreOn100,
    required this.rank,
    required this.isPassed,
    required this.passScoreThreshold,
    required List<TopicBreakdown> topicBreakdowns,
    required List<String> wrongQuestionCodes,
    required List<QuestionOutcome> itemOutcomes,
  })  : topicBreakdowns = List<TopicBreakdown>.unmodifiable(topicBreakdowns),
        wrongQuestionCodes = List<String>.unmodifiable(wrongQuestionCodes),
        itemOutcomes = List<QuestionOutcome>.unmodifiable(itemOutcomes);

  final String examId;
  final int totalQuestions;
  final int correctCount;
  final int unansweredCount;
  final double scoreOn100;
  final ExamRank rank;
  final bool isPassed;
  final double passScoreThreshold;
  final List<TopicBreakdown> topicBreakdowns;
  final List<String> wrongQuestionCodes;
  final List<QuestionOutcome> itemOutcomes;
}

