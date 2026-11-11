import 'dart:io';
import 'dart:math';

import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_result.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/exam_engine.dart';
import 'package:cc_dau_thau/features/study_progress/data/sqlite_progress_repository.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sample_bank_builder.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  late DateTime now;
  late SqliteProgressRepository repo;

  SqliteProgressRepository createRepo() {
    return SqliteProgressRepository(
      dbPathProvider: () async => dbPath,
      dbFactory: databaseFactoryFfi,
      clock: () => now,
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cc_progress_test_');
    dbPath = p.join(tempDir.path, 'study_progress.db');
    now = DateTime.utc(2026, 11, 11, 9, 0);
    repo = createRepo();
  });

  tearDown(() async {
    await repo.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SqliteProgressRepository', () {
    test('persists and validates UserSettings and reconciles weak queue when streak threshold drops', () async {
      final initialSettings = await repo.getSettings();
      expect(initialSettings, const UserSettings());

      await expectLater(
        () => repo.updateSettings(const UserSettings(passScoreThreshold: 99)),
        throwsArgumentError,
      );

      final bank = buildSampleQuestionBank();
      final q1 = bank.questions[0];
      final q2 = bank.questions[1];

      // Answer q1 wrong, then right once (streak = 1, still weak under default threshold 2)
      await repo.recordStudyAnswer(questionCode: q1.code, isCorrect: false);
      now = now.add(const Duration(minutes: 1));
      await repo.recordStudyAnswer(questionCode: q1.code, isCorrect: true);

      // Answer q2 wrong only once (streak = 0)
      await repo.recordStudyAnswer(questionCode: q2.code, isCorrect: false);

      expect(
        (await repo.getWeakQueueQuestions(bank)).map((q) => q.code).toSet(),
        {q1.code, q2.code},
      );

      // Lower revengeRequiredStreak from 2 -> 1 in settings
      final updated = await repo.updateSettings(
        const UserSettings(
          passScoreThreshold: 75.0,
          revengeRequiredStreak: 1,
          examDurationMinutes: 45,
          diagnosticPerTopic: 1,
        ),
      );
      expect(updated.revengeRequiredStreak, 1);

      // Reopen repository to verify SQLite persistence
      await repo.close();
      repo = createRepo();

      expect(await repo.getSettings(), updated);
      // q1 had streak=1 >= 1 so it is cleared; q2 (streak=0) remains weak
      expect(
        (await repo.getWeakQueueQuestions(bank)).map((q) => q.code).toList(),
        [q2.code],
      );
      final q1Progress = await repo.getQuestionProgress(q1.code);
      expect(q1Progress?.isWeakFlagged, isFalse);
    });

    test('records 70-question mock exam snapshot, updates answered progress only, and orders newest first', () async {
      final bank = buildSampleQuestionBank();
      final engine = ExamEngine();
      final exam1 =
          (engine.generateMockExam(bank, random: Random(1)) as ExamSuccess<GeneratedExam>)
              .data;

      // Answer 55 questions (50 right, 5 wrong), leave 15 blank
      final answers1 = <int, int>{};
      final explicitlyWrongCodes = <String>{};
      for (var i = 0; i < 55; i++) {
        final item = exam1.items[i];
        if (i < 50) {
          answers1[item.position] = item.correctDisplayIndex;
        } else {
          answers1[item.position] = (item.correctDisplayIndex + 1) % 4;
          explicitlyWrongCodes.add(item.questionCode);
        }
      }
      final sub1 = ExamSubmission(
        exam: exam1,
        selectedOptionByPosition: answers1,
        elapsedSeconds: 2400,
        submittedAt: now,
        autoSubmittedByTimeout: false,
      );
      final eval1 = engine.gradeExam(sub1, passScoreThreshold: 70.0);
      final entry1 = await repo.recordExamEvaluation(sub1, eval1);
      expect(entry1.items.length, 70);

      // Record a second attempt 10 minutes later
      now = now.add(const Duration(minutes: 10));
      final diag = (engine.generateDiagnosticTest(bank, random: Random(2))
              as ExamSuccess<GeneratedExam>)
          .data;
      final diagAnswers = {
        for (final item in diag.items) item.position: item.correctDisplayIndex,
      };
      final sub2 = ExamSubmission(
        exam: diag,
        selectedOptionByPosition: diagAnswers,
        elapsedSeconds: 300,
        submittedAt: now,
        autoSubmittedByTimeout: false,
      );
      final eval2 = engine.gradeExam(sub2, passScoreThreshold: 70.0);
      await repo.recordExamEvaluation(sub2, eval2);

      // Verify newest-first history ordering
      final history = await repo.getExamHistory();
      expect(history.length, 2);
      expect(history.first.attemptId, diag.examId);
      expect(history.last.attemptId, exam1.examId);
      expect(history.last.correctCount, 50);
      expect(history.last.isPassed, isTrue);

      // Verify full 70-item snapshot round-trip
      final detail1 = await repo.getExamHistoryDetail(exam1.examId);
      expect(detail1, isNotNull);
      expect(detail1!.items.length, 70);
      expect(detail1.summary.topicBreakdowns.length, 13);
      expect(detail1.items.where((e) => e.isUnanswered).length, 15);
      expect(
        detail1.items.first.options.map((o) => o.text).toList(),
        exam1.items.first.shuffledOptions.map((o) => o.text).toList(),
      );

      // Weak queue contains the 5 explicitly wrong questions, NOT unanswered blanks
      final weakCodes =
          (await repo.getWeakQueueQuestions(bank)).map((q) => q.code).toSet();
      expect(weakCodes, explicitlyWrongCodes);
    });

    test('preserves old history snapshots and filters missing codes when QuestionBank is updated', () async {
      final oldBank = buildSampleQuestionBank();
      final engine = ExamEngine();
      final exam =
          (engine.generateMockExam(oldBank, random: Random(5)) as ExamSuccess<GeneratedExam>)
              .data;

      // Pick first two questions from exam: mark 1 wrong & bookmarked, 1 wrong
      final removedCode = exam.items[0].questionCode;
      final keptWrongCode = exam.items[1].questionCode;
      final answers = <int, int>{
        for (var i = 0; i < exam.items.length; i++)
          exam.items[i].position: i < 2
              ? (exam.items[i].correctDisplayIndex + 1) % 4
              : exam.items[i].correctDisplayIndex,
      };
      await repo.toggleBookmark(removedCode);
      await repo.toggleBookmark(keptWrongCode);

      final sub = ExamSubmission(
        exam: exam,
        selectedOptionByPosition: answers,
        elapsedSeconds: 1800,
        submittedAt: now,
        autoSubmittedByTimeout: false,
      );
      await repo.recordExamEvaluation(sub, engine.gradeExam(sub));

      // Create an updated bank that drops `removedCode`
      final survivingQuestions = oldBank.questions
          .where((q) => q.code != removedCode)
          .toList();
      final updatedBank = QuestionBank(
        bankVersion: 'v2-updated',
        importedAt: now.add(const Duration(days: 1)),
        sourceType: BankSourceType.importedExcel,
        topics: oldBank.topics,
        questions: survivingQuestions,
      );

      // Old exam detail still has all 70 snapshot items
      final oldDetail = await repo.getExamHistoryDetail(exam.examId);
      expect(oldDetail, isNotNull);
      expect(oldDetail!.items.length, 70);
      expect(oldDetail.items.first.questionCode, removedCode);

      // Active weak queue & bookmarks filter deleted code cleanly while retaining keptWrongCode
      final weakList = await repo.getWeakQueueQuestions(updatedBank);
      expect(weakList.map((q) => q.code).toList(), [keptWrongCode]);

      final bookmarkedList = await repo.getBookmarkedQuestions(updatedBank);
      expect(bookmarkedList.map((q) => q.code).toList(), [keptWrongCode]);
    });

    test('toggles bookmarks and resetAllProgress wipes progress & history but preserves settings', () async {
      final bank = buildSampleQuestionBank();
      final q = bank.questions.first;

      await repo.updateSettings(const UserSettings(examDurationMinutes: 90));
      expect(await repo.toggleBookmark(q.code), isTrue);
      expect(await repo.getBookmarkedCodes(), {q.code});
      expect(await repo.toggleBookmark(q.code), isFalse);
      expect(await repo.getBookmarkedCodes(), isEmpty);

      await repo.toggleBookmark(q.code);
      await repo.recordStudyAnswer(questionCode: q.code, isCorrect: false);

      await repo.resetAllProgress();

      expect(await repo.getQuestionProgress(q.code), isNull);
      expect(await repo.getWeakQueueQuestions(bank), isEmpty);
      expect(await repo.getBookmarkedCodes(), isEmpty);
      expect(await repo.getExamHistory(), isEmpty);
      expect(
        await repo.getSettings(),
        const UserSettings(examDurationMinutes: 90),
      );
    });
  });
}

