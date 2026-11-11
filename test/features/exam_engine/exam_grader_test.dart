import 'dart:math';

import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_result.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/exam_engine.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/exam_grader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/sample_bank_builder.dart';

void main() {
  const grader = ExamGrader();
  final engine = ExamEngine();

  group('ExamGrader & ExamEngine', () {
    test('grades 49/70 as exact 70.0 and passing at threshold 70, 48/70 as failing', () {
      final bank = buildSampleQuestionBank();
      final examRes = engine.generateMockExam(bank, random: Random(7));
      final exam = (examRes as ExamSuccess<GeneratedExam>).data;
      expect(exam.items.length, 70);

      final passAnswers = <int, int>{};
      for (var i = 0; i < 49; i++) {
        passAnswers[exam.items[i].position] = exam.items[i].correctDisplayIndex;
      }
      // Leave positions 50..70 partially wrong and unanswered
      passAnswers[exam.items[49].position] =
          (exam.items[49].correctDisplayIndex + 1) % 4;

      final passEval = grader.grade(
        ExamSubmission(
          exam: exam,
          selectedOptionByPosition: passAnswers,
          elapsedSeconds: 1200,
          submittedAt: DateTime.utc(2026, 11, 11),
          autoSubmittedByTimeout: false,
        ),
        passScoreThreshold: 70.0,
      );

      expect(passEval.correctCount, 49);
      expect(passEval.unansweredCount, 20);
      expect(passEval.scoreOn100, 70.0);
      expect(passEval.isPassed, isTrue);
      expect(passEval.wrongQuestionCodes.length, 21);
      expect(
        passEval.topicBreakdowns.fold<int>(0, (s, b) => s + b.totalInExam),
        70,
      );

      final failAnswers = Map<int, int>.from(passAnswers)
        ..remove(exam.items[48].position);
      final failEval = grader.grade(
        ExamSubmission(
          exam: exam,
          selectedOptionByPosition: failAnswers,
          elapsedSeconds: 3600,
          submittedAt: DateTime.utc(2026, 11, 11),
          autoSubmittedByTimeout: true,
        ),
        passScoreThreshold: 70.0,
      );

      expect(failEval.correctCount, 48);
      expect(failEval.scoreOn100, closeTo(68.57, 0.01));
      expect(failEval.isPassed, isFalse);
    });

    test('generates 26-question diagnostic test and shuffled retry session for wrong codes', () {
      final bank = buildSampleQuestionBank();
      final diagRes = engine.generateDiagnosticTest(bank, perTopic: 2, random: Random(3));
      expect(diagRes, isA<ExamSuccess<GeneratedExam>>());
      final diag = (diagRes as ExamSuccess<GeneratedExam>).data;
      expect(diag.mode, ExamMode.diagnosticMiniTest);
      expect(diag.items.length, 26);

      final wrongCodes = diag.items.take(5).map((e) => e.questionCode).toList();
      final retryRes = engine.generateRetrySession(bank, wrongCodes, random: Random(9));
      expect(retryRes, isA<ExamSuccess<GeneratedExam>>());
      final retry = (retryRes as ExamSuccess<GeneratedExam>).data;
      expect(retry.mode, ExamMode.retryWrong);
      expect(retry.items.length, 5);
      expect(retry.items.map((e) => e.questionCode).toSet(), wrongCodes.toSet());
    });
  });
}

