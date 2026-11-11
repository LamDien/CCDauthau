import 'dart:math';

import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_result.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/exam_engine.dart';
import 'package:cc_dau_thau/features/mobile_ui/controllers/mock_exam_controller.dart';
import 'package:cc_dau_thau/features/study_progress/data/sqlite_progress_repository.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';
import 'package:cc_dau_thau/features/study_progress/domain/repositories/study_progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sample_bank_builder.dart';

class _CountingProgressRepo extends SqliteProgressRepository {
  _CountingProgressRepo()
      : super(
          dbPathProvider: () async => inMemoryDatabasePath,
          dbFactory: databaseFactoryFfiNoIsolate,
        );

  int recordExamCalls = 0;

  @override
  Future<ExamHistoryEntry> recordExamEvaluation(
    ExamSubmission submission,
    ExamEvaluationResult result,
  ) {
    recordExamCalls++;
    return super.recordExamEvaluation(submission, result);
  }
}

void main() {
  sqfliteFfiInit();

  group('MockExamController', () {
    late _CountingProgressRepo repo;
    late ExamEngine engine;
    late GeneratedExam exam;

    setUp(() {
      repo = _CountingProgressRepo();
      engine = ExamEngine();
      final bank = buildSampleQuestionBank();
      exam = (engine.generateMockExam(
        bank,
        config: const ExamConfig(totalQuestions: 70, durationSeconds: 3600),
        random: Random(11),
      ) as ExamSuccess<GeneratedExam>)
          .data;
    });

    tearDown(() async {
      await repo.close();
    });

    test('tracks unansweredCount, view mode toggle, warning phases, and auto-submits idempotently at timeout', () async {
      final ctrl = MockExamController(
        exam: exam,
        engine: engine,
        progressRepo: repo,
        passScoreThreshold: 70.0,
      );
      addTearDown(ctrl.dispose);

      expect(ctrl.totalQuestions, 70);
      expect(ctrl.unansweredCount, 70);
      expect(ctrl.firstUnansweredIndex, 0);

      ctrl.selectOption(1, 0);
      ctrl.toggleFlag(2);
      expect(ctrl.unansweredCount, 69);
      expect(ctrl.firstUnansweredIndex, 1);

      // Switching between Single Question and Full Paper keeps selections
      ctrl.setViewMode(false);
      expect(ctrl.isSingleQuestionView, isFalse);
      expect(ctrl.selectedByPosition[1], 0);
      expect(ctrl.flaggedPositions.contains(2), isTrue);
      ctrl.setViewMode(true);
      expect(ctrl.selectedByPosition[1], 0);

      // Verify < 5m warning and < 1m critical phases
      ctrl.tick(3301); // 299s left
      expect(ctrl.isWarningPhase, isTrue);
      expect(ctrl.isCriticalPhase, isFalse);

      ctrl.tick(240); // 59s left
      expect(ctrl.isWarningPhase, isFalse);
      expect(ctrl.isCriticalPhase, isTrue);

      // Timeout tick triggers single auto-submit
      ctrl.tick(59);
      await pumpEventQueue();
      expect(ctrl.remainingSeconds, 0);
      expect(ctrl.isSubmitted, isTrue);
      expect(ctrl.historyEntry?.summary.autoSubmittedByTimeout, isTrue);
      expect(repo.recordExamCalls, 1);

      // Selection after timeout & duplicate submit calls must be ignored
      ctrl.selectOption(2, 1);
      await ctrl.submit(autoSubmittedByTimeout: false);
      ctrl.tick(10);
      await pumpEventQueue();
      expect(ctrl.selectedByPosition.containsKey(2), isFalse);
      expect(repo.recordExamCalls, 1);
      final StudyProgressRepository asRepo = repo;
      expect((await asRepo.getExamHistory()).length, 1);
    });
  });
}

