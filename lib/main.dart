import 'dart:async';

import 'package:cc_dau_thau/app/di/app_dependencies.dart';
import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_result.dart';
import 'package:cc_dau_thau/features/mobile_ui/controllers/mock_exam_controller.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/exam_result_screen.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/history_tab.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/home_shell.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/manual_picker_screen.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/mock_exam_screen.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/settings_tab.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/study_session_screen.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/study_tab.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = AppDependencies.createProduction();
  unawaited(dependencies.appState.initialize());
  unawaited(dependencies.adBannerService.initialize());
  runApp(CcDauThauApp(dependencies: dependencies));
}

/// Root Flutter widget for the offline bidding certificate prep app.
class CcDauThauApp extends StatefulWidget {
  const CcDauThauApp({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<CcDauThauApp> createState() => _CcDauThauAppState();
}

class _CcDauThauAppState extends State<CcDauThauApp> {
  final RouteObserver<ModalRoute<void>> _routeObserver =
      RouteObserver<ModalRoute<void>>();

  @override
  Widget build(BuildContext context) {
    final dependencies = widget.dependencies;
    final appState = dependencies.appState;

    void startStudySession(
      BuildContext navContext,
      String title,
      List<Question> questions, {
      bool isRevengeMode = false,
    }) {
      final bank = appState.bank;
      if (bank == null) return;
      Navigator.of(navContext).push(
        MaterialPageRoute<void>(
          builder: (_) => StudySessionScreen(
            title: title,
            questions: questions,
            bank: bank,
            initialBookmarkedCodes: appState.bookmarkedCodes,
            isRevengeMode: isRevengeMode,
            onAnswerRecorded: (code, isCorrect, revenge) =>
                appState.recordStudyAnswer(
              questionCode: code,
              isCorrect: isCorrect,
              isRevengeMode: revenge,
            ),
            onToggleBookmark: appState.toggleBookmark,
          ),
        ),
      );
    }

    void startGeneratedExam(BuildContext navContext, GeneratedExam exam) {
      final examController = MockExamController(
        exam: exam,
        engine: dependencies.examEngine,
        progressRepo: dependencies.progressRepository,
        passScoreThreshold: ExamRank.passingScore,
      );
      Navigator.of(navContext).push(
        MaterialPageRoute<void>(
          builder: (_) => MockExamScreen(
            controller: examController,
            currentBank: appState.bank,
            initialBookmarkedCodes: appState.bookmarkedCodes,
            onToggleBookmark: appState.toggleBookmark,
            onExamCompleted: (_) => appState.refreshProgress(),
            onRetryWrongQuestions: (wrongCodes) {
              final retryRes = appState.createRetryWrongExam(wrongCodes);
              if (retryRes is ExamSuccess<GeneratedExam>) {
                startGeneratedExam(navContext, retryRes.data);
              }
            },
          ),
        ),
      ).whenComplete(examController.dispose);
    }

    Future<void> openAttemptDetail(
      BuildContext navContext,
      String attemptId,
    ) async {
      final entry = await appState.loadHistoryDetail(attemptId);
      if (!navContext.mounted || entry == null) return;
      await Navigator.of(navContext).push(
        MaterialPageRoute<void>(
          builder: (_) => ExamResultScreen(
            entry: entry,
            currentBank: appState.bank,
            bookmarkedCodes: appState.bookmarkedCodes,
            onToggleBookmark: appState.toggleBookmark,
            onRetryWrongQuestions: (wrongCodes) {
              final retryRes = appState.createRetryWrongExam(wrongCodes);
              if (retryRes is ExamSuccess<GeneratedExam>) {
                startGeneratedExam(navContext, retryRes.data);
              }
            },
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'CC Đấu Thầu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildLightTheme(),
      navigatorObservers: [_routeObserver],
      home: HomeShell(
        controller: appState,
        adBannerService: dependencies.adBannerService,
        routeObserver: _routeObserver,
        onStartExamRequested: startGeneratedExam,
        onStartStudyQuestionsRequested: startStudySession,
        studyTabBuilder: (tabContext) => StudyTab(
          controller: appState,
          onStartQuestions: (title, qs, {isRevengeMode = false}) {
            startStudySession(
              tabContext,
              title,
              qs,
              isRevengeMode: isRevengeMode,
            );
          },
          onOpenManualPicker: () {
            final bank = appState.bank;
            if (bank == null) return;
            Navigator.of(tabContext).push(
              MaterialPageRoute<void>(
                builder: (pickerContext) => ManualPickerScreen(
                  bank: bank,
                  onStartSelectedStudy: (selectedQuestions) {
                    Navigator.of(pickerContext).pop();
                    startStudySession(
                      tabContext,
                      'Tự chọn (${selectedQuestions.length} câu)',
                      selectedQuestions,
                    );
                  },
                ),
              ),
            );
          },
        ),
        historyTabBuilder: (tabContext) => HistoryTab(
          controller: appState,
          onOpenAttemptDetail: (attemptId) =>
              openAttemptDetail(tabContext, attemptId),
        ),
        settingsTabBuilder: (_) => SettingsTab(controller: appState),
      ),
    );
  }
}
