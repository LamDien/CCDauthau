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
    test('grades on 100-point scale and classifies all 5 official ranking tiers with >= 50 passing mark', () {
      final bank = buildSampleQuestionBank();
      final examRes = engine.generateMockExam(bank, random: Random(7));
      final exam = (examRes as ExamSuccess<GeneratedExam>).data;
      expect(exam.items.length, 70);

      ExamEvaluationResult gradeCorrectCount(int correctCount) {
        final answers = <int, int>{};
        for (var i = 0; i < correctCount; i++) {
          answers[exam.items[i].position] = exam.items[i].correctDisplayIndex;
        }
        if (correctCount < exam.items.length) {
          answers[exam.items[correctCount].position] =
              (exam.items[correctCount].correctDisplayIndex + 1) % 4;
        }
        return grader.grade(
          ExamSubmission(
            exam: exam,
            selectedOptionByPosition: answers,
            elapsedSeconds: 1200,
            submittedAt: DateTime.utc(2026, 11, 11),
            autoSubmittedByTimeout: false,
          ),
        );
      }

      // 63/70 = 90.00 -> Xuất sắc
      final excellentEval = gradeCorrectCount(63);
      expect(excellentEval.scoreOn100, 90.0);
      expect(excellentEval.rank, ExamRank.excellent);
      expect(excellentEval.rank.label, 'Xuất sắc');
      expect(excellentEval.isPassed, isTrue);
      expect(excellentEval.passScoreThreshold, 50.0);
      expect(
        excellentEval.topicBreakdowns.fold<int>(0, (s, b) => s + b.totalInExam),
        70,
      );

      // 56/70 = 80.00 -> Giỏi, 62/70 = 88.57 -> Giỏi
      expect(gradeCorrectCount(62).rank, ExamRank.good);
      final goodEval = gradeCorrectCount(56);
      expect(goodEval.scoreOn100, 80.0);
      expect(goodEval.rank, ExamRank.good);
      expect(goodEval.rank.label, 'Giỏi');
      expect(goodEval.isPassed, isTrue);

      // 42/70 = 60.00 -> Khá, 55/70 = 78.57 -> Khá
      expect(gradeCorrectCount(55).rank, ExamRank.fair);
      final fairEval = gradeCorrectCount(42);
      expect(fairEval.scoreOn100, 60.0);
      expect(fairEval.rank, ExamRank.fair);
      expect(fairEval.rank.label, 'Khá');
      expect(fairEval.isPassed, isTrue);

      // 35/70 = 50.00 -> Trung bình (passing boundary), 41/70 = 58.57 -> Trung bình
      expect(gradeCorrectCount(41).rank, ExamRank.average);
      final averageEval = gradeCorrectCount(35);
      expect(averageEval.correctCount, 35);
      expect(averageEval.unansweredCount, 34);
      expect(averageEval.scoreOn100, 50.0);
      expect(averageEval.rank, ExamRank.average);
      expect(averageEval.rank.label, 'Trung bình');
      expect(averageEval.isPassed, isTrue);
      expect(averageEval.wrongQuestionCodes.length, 35);

      // 34/70 = 48.57 -> Không đạt yêu cầu (< 50%)
      final failEval = gradeCorrectCount(34);
      expect(failEval.correctCount, 34);
      expect(failEval.scoreOn100, closeTo(48.57, 0.01));
      expect(failEval.rank, ExamRank.fail);
      expect(failEval.rank.label, 'Không đạt yêu cầu');
      expect(failEval.isPassed, isFalse);

      expect(ExamMode.mockExam.supportsRanking, isTrue);
      expect(ExamMode.diagnosticMiniTest.supportsRanking, isTrue);
      expect(ExamMode.retryWrong.supportsRanking, isFalse);
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

