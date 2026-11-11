import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/vault_result.dart';
import 'package:cc_dau_thau/features/data_vault/domain/repositories/vault_repository.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_result.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/exam_engine.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';
import 'package:cc_dau_thau/features/study_progress/domain/repositories/study_progress_repository.dart';
import 'package:flutter/foundation.dart';

/// App-wide state coordinator connecting Data Vault, Exam Engine, and Study Progress.
class AppStateController extends ChangeNotifier {
  AppStateController({
    required this.vaultRepository,
    required this.examEngine,
    required this.progressRepository,
  });

  final VaultRepository vaultRepository;
  final ExamEngine examEngine;
  final StudyProgressRepository progressRepository;

  bool isLoading = true;
  String? startupError;
  QuestionBank? bank;
  UserSettings settings = const UserSettings();
  ReadinessSummary? summary;
  List<ExamHistorySummary> history = const [];
  Set<String> bookmarkedCodes = const {};

  Future<void> initialize() async {
    isLoading = true;
    startupError = null;
    notifyListeners();

    try {
      final vaultRes = await vaultRepository.loadActiveBank();
      switch (vaultRes) {
        case VaultError<QuestionBank>(:final failure):
          startupError = _describeVaultFailure(failure);
          bank = null;
        case VaultSuccess<QuestionBank>(:final data):
          bank = data;
          await _loadProgressLocked(data);
      }
    } catch (error) {
      startupError = 'Không thể khởi tạo dữ liệu cục bộ: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadProgressLocked(QuestionBank activeBank) async {
    final results = await Future.wait<Object>([
      progressRepository.getSettings(),
      progressRepository.getReadinessSummary(activeBank),
      progressRepository.getExamHistory(),
      progressRepository.getBookmarkedCodes(),
    ]);
    settings = results[0] as UserSettings;
    summary = results[1] as ReadinessSummary;
    history = results[2] as List<ExamHistorySummary>;
    bookmarkedCodes = results[3] as Set<String>;
  }

  Future<void> refreshProgress() async {
    final activeBank = bank;
    if (activeBank == null) return;
    await _loadProgressLocked(activeBank);
    notifyListeners();
  }

  ExamResult<GeneratedExam> createMockExam() {
    final activeBank = bank;
    if (activeBank == null) {
      return const ExamError(
        InsufficientQuestionsFailure('Ngân hàng câu hỏi chưa sẵn sàng.'),
      );
    }
    return examEngine.generateMockExam(
      activeBank,
      config: ExamConfig(
        totalQuestions: 70,
        durationSeconds: settings.examDurationMinutes * 60,
        passScoreThreshold: settings.passScoreThreshold,
      ),
    );
  }

  ExamResult<GeneratedExam> createDiagnosticMiniTest() {
    final activeBank = bank;
    if (activeBank == null) {
      return const ExamError(
        InsufficientQuestionsFailure('Ngân hàng câu hỏi chưa sẵn sàng.'),
      );
    }
    return examEngine.generateDiagnosticTest(
      activeBank,
      perTopic: settings.diagnosticPerTopic,
      durationSeconds: settings.diagnosticPerTopic * 13 * 45,
    );
  }

  ExamResult<GeneratedExam> createRetryWrongExam(List<String> wrongCodes) {
    final activeBank = bank;
    if (activeBank == null) {
      return const ExamError(
        InsufficientQuestionsFailure('Ngân hàng câu hỏi chưa sẵn sàng.'),
      );
    }
    return examEngine.generateRetrySession(activeBank, wrongCodes);
  }

  Future<void> recordStudyAnswer({
    required String questionCode,
    required bool isCorrect,
    bool isRevengeMode = false,
  }) async {
    await progressRepository.recordStudyAnswer(
      questionCode: questionCode,
      isCorrect: isCorrect,
      isRevengeMode: isRevengeMode,
    );
    await refreshProgress();
  }

  Future<bool> toggleBookmark(String questionCode) async {
    final isNowBookmarked = await progressRepository.toggleBookmark(questionCode);
    await refreshProgress();
    return isNowBookmarked;
  }

  Future<List<Question>> loadWeakQueue() {
    final activeBank = bank;
    if (activeBank == null) return Future.value(const []);
    return progressRepository.getWeakQueueQuestions(activeBank);
  }

  Future<List<Question>> loadBookmarkedQuestions() {
    final activeBank = bank;
    if (activeBank == null) return Future.value(const []);
    return progressRepository.getBookmarkedQuestions(activeBank);
  }

  Future<ExamHistoryEntry?> loadHistoryDetail(String attemptId) {
    return progressRepository.getExamHistoryDetail(attemptId);
  }

  Future<void> updateSettings(UserSettings next) async {
    settings = await progressRepository.updateSettings(next);
    await refreshProgress();
  }

  Future<VaultResult<ImportSummary>> importBankBytes(
    Uint8List bytes, {
    required ImportFileType type,
  }) async {
    final res = await vaultRepository.importFromBytes(bytes, type: type);
    if (res is VaultSuccess<ImportSummary>) {
      final loaded = await vaultRepository.loadActiveBank();
      if (loaded is VaultSuccess<QuestionBank>) {
        bank = loaded.data;
        startupError = null;
        await _loadProgressLocked(loaded.data);
        notifyListeners();
      }
    }
    return res;
  }

  Future<VaultResult<QuestionBank>> resetToBundledBank() async {
    final res = await vaultRepository.resetToBundledBank();
    if (res is VaultSuccess<QuestionBank>) {
      bank = res.data;
      startupError = null;
      await _loadProgressLocked(res.data);
      notifyListeners();
    }
    return res;
  }

  Future<void> resetAllProgress() async {
    await progressRepository.resetAllProgress();
    await refreshProgress();
  }

  String _describeVaultFailure(VaultFailure failure) {
    return switch (failure) {
      ExcelValidationFailure(:final rowErrors) =>
        'File Excel có ${rowErrors.length} lỗi dữ liệu.',
      InsufficientBankFailure(:final message) => message,
      CorruptedVaultFailure(:final message) => message,
      StorageFailure(:final message) => message,
    };
  }
}
