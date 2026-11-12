import 'dart:typed_data';

import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/vault_result.dart';
import 'package:cc_dau_thau/features/data_vault/domain/repositories/vault_repository.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/exam_engine.dart';
import 'package:cc_dau_thau/features/mobile_ui/controllers/app_state_controller.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/settings_tab.dart';
import 'package:cc_dau_thau/features/study_progress/data/sqlite_progress_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sample_bank_builder.dart';

class _StubVaultRepository implements VaultRepository {
  _StubVaultRepository(this.activeBank);

  QuestionBank activeBank;
  VaultResult<ImportSummary>? nextImportResult;

  @override
  Future<VaultResult<QuestionBank>> loadActiveBank() async =>
      VaultSuccess(activeBank);

  @override
  Future<VaultResult<ImportSummary>> importFromBytes(
    Uint8List bytes, {
    required ImportFileType type,
  }) async {
    return nextImportResult ?? VaultSuccess(activeBank.toSummary());
  }

  @override
  Future<VaultResult<QuestionBank>> resetToBundledBank() async =>
      VaultSuccess(activeBank);
}

void main() {
  sqfliteFfiInit();

  testWidgets('SettingsTab updates pass threshold & revenge streak and displays Excel row validation errors clearly', (tester) async {
    final bank = buildSampleQuestionBank();
    final vaultRepo = _StubVaultRepository(bank);
    final progressRepo = SqliteProgressRepository(
      dbPathProvider: () async => inMemoryDatabasePath,
      dbFactory: databaseFactoryFfiNoIsolate,
    );
    addTearDown(progressRepo.close);

    final appState = AppStateController(
      vaultRepository: vaultRepo,
      examEngine: ExamEngine(),
      progressRepository: progressRepo,
    );
    await appState.initialize();

    vaultRepo.nextImportResult = VaultError(
      ExcelValidationFailure([
        ExcelRowError(
          rowNumber: 12,
          columnName: 'Đáp án đúng',
          message: 'Chỉ chấp nhận A, B, C hoặc D.',
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildLightTheme(),
        home: Scaffold(
          body: AnimatedBuilder(
            animation: appState,
            builder: (context, _) => SettingsTab(
              controller: appState,
              filePickerOverride: () async => PickedBankFile(
                fileName: 'ngan_hang_loi.xlsx',
                bytes: Uint8List.fromList([1, 2, 3]),
              ),
              appVersionLoader: () async => '1.2.0',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Increase topic mastery target from 70% -> 75% and select revenge streak 3 lần
    expect(find.text('Mục tiêu nắm vững chuyên đề'), findsOneWidget);
    await tester.tap(find.byTooltip('Tăng 5%'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 lần'));
    await tester.pumpAndSettle();

    final savedSettings = await progressRepo.getSettings();
    expect(savedSettings.passScoreThreshold, 75.0);
    expect(savedSettings.revengeRequiredStreak, 3);

    final selectedStreakMaterial = tester.widget<Material>(
      find.ancestor(
        of: find.text('3 lần'),
        matching: find.byType(Material),
      ).first,
    );
    expect(selectedStreakMaterial.color, AppColors.primaryDark);

    final unselectedStreakMaterial = tester.widget<Material>(
      find.ancestor(
        of: find.text('2 lần'),
        matching: find.byType(Material),
      ).first,
    );
    expect(unselectedStreakMaterial.color, AppColors.scaffoldBg);

    // All streak options (1..5 lần) must align on a single horizontal line
    final firstStreakY = tester.getCenter(find.text('1 lần')).dy;
    for (final label in ['2 lần', '3 lần', '4 lần', '5 lần']) {
      expect(tester.getCenter(find.text(label)).dy, firstStreakY);
    }

    // All exam duration options (30..90 phút) must align on a single horizontal line
    final firstDurationY = tester.getCenter(find.text('30 phút')).dy;
    for (final label in ['45 phút', '60 phút', '90 phút']) {
      expect(tester.getCenter(find.text(label)).dy, firstDurationY);
    }

    final scorePillContainer = tester.widget<Container>(
      find.ancestor(
        of: find.text('75%'),
        matching: find.byType(Container),
      ).first,
    );
    expect(
      (scorePillContainer.decoration as BoxDecoration?)?.color,
      AppColors.primaryDark,
    );

    // Scroll to upload button and trigger invalid Excel import
    final uploadBtn = find.text('Cập nhật từ file (.bex / .xlsx)');
    await tester.ensureVisible(uploadBtn);
    await tester.tap(uploadBtn);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Dòng 12 (Đáp án đúng): Chỉ chấp nhận A, B, C hoặc D.'),
      findsOneWidget,
    );

    // Now test valid import success state
    vaultRepo.nextImportResult = VaultSuccess(bank.toSummary());
    await tester.tap(uploadBtn);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Cập nhật thành công ${bank.questions.length} câu hỏi'),
      findsOneWidget,
    );

    // Scroll to bottom to verify App Info section below Reset Progress button
    final aboutHeading = find.text('Giới thiệu ứng dụng');
    await tester.scrollUntilVisible(
      find.text('Lam Điền @ 2026'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(aboutHeading, findsOneWidget);
    expect(find.text('v1.2.0'), findsOneWidget);
    expect(
      find.text('Ứng dụng hỗ trợ ôn thi Chứng chỉ Đấu thầu'),
      findsOneWidget,
    );
    expect(
      find.text('Phiên bản Ngân hàng ${bank.questions.length} câu hỏi'),
      findsOneWidget,
    );
    expect(find.text('Lam Điền @ 2026'), findsOneWidget);

    final resetBtnTop =
        tester.getTopLeft(find.text('Xoá toàn bộ lịch sử & tiến độ học')).dy;
    final aboutTop = tester.getTopLeft(aboutHeading).dy;
    expect(aboutTop, greaterThan(resetBtnTop));
  });

  testWidgets('SettingsTab collapses version badge safely when version lookup fails', (tester) async {
    final bank = buildSampleQuestionBank(countsPerTopic: const [60, 60]);
    final vaultRepo = _StubVaultRepository(bank);
    final progressRepo = SqliteProgressRepository(
      dbPathProvider: () async => inMemoryDatabasePath,
      dbFactory: databaseFactoryFfiNoIsolate,
    );
    addTearDown(progressRepo.close);

    final appState = AppStateController(
      vaultRepository: vaultRepo,
      examEngine: ExamEngine(),
      progressRepository: progressRepo,
    );
    await appState.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildLightTheme(),
        home: Scaffold(
          body: SettingsTab(
            controller: appState,
            appVersionLoader: () => Future<String?>.error(StateError('no channel')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Lam Điền @ 2026'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Giới thiệu ứng dụng'), findsOneWidget);
    expect(find.text('Phiên bản Ngân hàng 120 câu hỏi'), findsOneWidget);
    expect(find.textContaining('v1.'), findsNothing);
  });
}
