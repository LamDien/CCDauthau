import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';

/// Grades an [ExamSubmission] on a 100-point scale and extracts topic
/// breakdowns plus wrong question codes for follow-up review.
final class ExamGrader {
  const ExamGrader();

  ExamEvaluationResult grade(
    ExamSubmission submission, {
    double passScoreThreshold = 70.0,
  }) {
    final items = submission.exam.items;
    var correctCount = 0;
    var unansweredCount = 0;
    final wrongCodes = <String>[];
    final outcomes = <QuestionOutcome>[];

    final topicNames = <String, String>{};
    final topicTotals = <String, int>{};
    final topicCorrect = <String, int>{};

    for (final q in items) {
      final selected = submission.selectedOptionByPosition[q.position];
      final isUnanswered = selected == null;
      final isCorrect = !isUnanswered && selected == q.correctDisplayIndex;

      if (isUnanswered) {
        unansweredCount++;
      }
      if (isCorrect) {
        correctCount++;
      } else {
        wrongCodes.add(q.questionCode);
      }

      outcomes.add(
        QuestionOutcome(
          question: q,
          selectedDisplayIndex: selected,
          isCorrect: isCorrect,
        ),
      );

      topicNames[q.topicId] = q.topicName;
      topicTotals[q.topicId] = (topicTotals[q.topicId] ?? 0) + 1;
      if (isCorrect) {
        topicCorrect[q.topicId] = (topicCorrect[q.topicId] ?? 0) + 1;
      }
    }

    final sortedTopicIds = topicTotals.keys.toList()..sort();
    final breakdowns = [
      for (final topicId in sortedTopicIds)
        TopicBreakdown(
          topicId: topicId,
          topicName: topicNames[topicId]!,
          totalInExam: topicTotals[topicId]!,
          correctCount: topicCorrect[topicId] ?? 0,
        ),
    ];

    final total = items.length;
    final scoreOn100 = total == 0 ? 0.0 : (correctCount * 100.0) / total;
    final isPassed = scoreOn100 >= passScoreThreshold - 1e-9;

    return ExamEvaluationResult(
      examId: submission.exam.examId,
      totalQuestions: total,
      correctCount: correctCount,
      unansweredCount: unansweredCount,
      scoreOn100: scoreOn100,
      isPassed: isPassed,
      passScoreThreshold: passScoreThreshold,
      topicBreakdowns: breakdowns,
      wrongQuestionCodes: wrongCodes,
      itemOutcomes: outcomes,
    );
  }
}

