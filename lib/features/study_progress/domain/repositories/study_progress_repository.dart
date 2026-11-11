import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';

/// Persistence contract for personal study progress, weak queue, bookmarks, and exam history.
abstract class StudyProgressRepository {
  Future<UserSettings> getSettings();

  Future<UserSettings> updateSettings(UserSettings next);

  Future<QuestionProgress?> getQuestionProgress(String questionCode);

  Future<void> recordStudyAnswer({
    required String questionCode,
    required bool isCorrect,
    bool isRevengeMode = false,
  });

  Future<ExamHistoryEntry> recordExamEvaluation(
    ExamSubmission submission,
    ExamEvaluationResult result,
  );

  Future<ReadinessSummary> getReadinessSummary(QuestionBank bank);

  Future<List<Question>> getWeakQueueQuestions(QuestionBank bank);

  Future<List<Question>> getBookmarkedQuestions(QuestionBank bank);

  Future<Set<String>> getBookmarkedCodes();

  Future<bool> toggleBookmark(String questionCode);

  Future<List<ExamHistorySummary>> getExamHistory();

  Future<ExamHistoryEntry?> getExamHistoryDetail(String attemptId);

  Future<void> resetAllProgress();
}

