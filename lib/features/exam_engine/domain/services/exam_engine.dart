import 'dart:math';

import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_result.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/answer_shuffler.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/constrained_question_selector.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/exam_grader.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/largest_remainder_allocator.dart';

/// Pure Dart engine coordinating quota allocation, constrained selection,
/// question/option shuffling, diagnostic/retry generation, and grading.
final class ExamEngine {
  ExamEngine({
    LargestRemainderAllocator? allocator,
    ConstrainedQuestionSelector? selector,
    AnswerShuffler? shuffler,
    ExamGrader? grader,
  })  : _allocator = allocator ?? const LargestRemainderAllocator(),
        _selector = selector ?? const ConstrainedQuestionSelector(),
        _shuffler = shuffler ?? const AnswerShuffler(),
        _grader = grader ?? const ExamGrader();

  final LargestRemainderAllocator _allocator;
  final ConstrainedQuestionSelector _selector;
  final AnswerShuffler _shuffler;
  final ExamGrader _grader;

  /// Generates a standard 70-question mock exam proportional to the 13 topics.
  ExamResult<GeneratedExam> generateMockExam(
    QuestionBank bank, {
    ExamConfig config = const ExamConfig(),
    Random? random,
  }) {
    final quotaResult = _allocator.allocate(
      topics: bank.topics,
      targetTotal: config.totalQuestions,
    );
    switch (quotaResult) {
      case ExamError<Map<String, int>>(:final failure):
        return ExamError(failure);
      case ExamSuccess<Map<String, int>>(:final data):
        return _generateFromQuotas(
          bank: bank,
          quotas: data,
          mode: ExamMode.mockExam,
          durationSeconds: config.durationSeconds,
          random: random,
        );
    }
  }

  /// Generates an optional diagnostic mini-test covering all topics equally.
  ExamResult<GeneratedExam> generateDiagnosticTest(
    QuestionBank bank, {
    int perTopic = 2,
    int durationSeconds = 1200,
    Random? random,
  }) {
    final quotas = <String, int>{
      for (final t in bank.topics) t.id: min(perTopic, t.questionCount),
    };
    final total = quotas.values.fold<int>(0, (s, v) => s + v);
    if (total == 0) {
      return const ExamError(
        InsufficientQuestionsFailure('Ngân hàng câu hỏi không có dữ liệu để tạo bài chẩn đoán.'),
      );
    }
    return _generateFromQuotas(
      bank: bank,
      quotas: quotas,
      mode: ExamMode.diagnosticMiniTest,
      durationSeconds: durationSeconds,
      random: random,
    );
  }

  /// Generates a freshly shuffled practice session containing the given question codes.
  ExamResult<GeneratedExam> generateRetrySession(
    QuestionBank bank,
    List<String> questionCodes, {
    int durationSeconds = 0,
    Random? random,
  }) {
    final seen = <String>{};
    final resolved = <Question>[];
    for (final code in questionCodes) {
      if (!seen.add(code)) continue;
      final q = bank.questionsByCode[code];
      if (q != null) resolved.add(q);
    }

    if (resolved.isEmpty) {
      return const ExamError(
        InsufficientQuestionsFailure('Không tìm thấy câu hỏi phù hợp để luyện lại.'),
      );
    }

    final rng = random ?? Random.secure();
    final items = _shuffler.buildShuffledQuestions(resolved, random: rng);
    return ExamSuccess(
      GeneratedExam(
        examId: _createExamId(rng),
        mode: ExamMode.retryWrong,
        durationSeconds: durationSeconds,
        createdAt: DateTime.now().toUtc(),
        items: items,
      ),
    );
  }

  /// Grades [submission] on a 100-point scale against [passScoreThreshold].
  ExamEvaluationResult gradeExam(
    ExamSubmission submission, {
    double passScoreThreshold = 70.0,
  }) {
    return _grader.grade(
      submission,
      passScoreThreshold: passScoreThreshold,
    );
  }

  ExamResult<GeneratedExam> _generateFromQuotas({
    required QuestionBank bank,
    required Map<String, int> quotas,
    required ExamMode mode,
    required int durationSeconds,
    Random? random,
  }) {
    final rng = random ?? Random.secure();
    final selection = _selector.select(
      bank: bank,
      quotas: quotas,
      random: rng,
    );
    switch (selection) {
      case ExamError<List<Question>>(:final failure):
        return ExamError(failure);
      case ExamSuccess<List<Question>>(:final data):
        final items = _shuffler.buildShuffledQuestions(data, random: rng);
        return ExamSuccess(
          GeneratedExam(
            examId: _createExamId(rng),
            mode: mode,
            durationSeconds: durationSeconds,
            createdAt: DateTime.now().toUtc(),
            items: items,
          ),
        );
    }
  }

  String _createExamId(Random rng) {
    final nowMicros = DateTime.now().toUtc().microsecondsSinceEpoch;
    final salt = rng.nextInt(1 << 20).toRadixString(36).padLeft(4, '0');
    return 'EX_${nowMicros}_$salt';
  }
}

