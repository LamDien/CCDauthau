import 'dart:typed_data';

import 'package:cc_dau_thau/app/di/app_dependencies.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/vault_result.dart';
import 'package:cc_dau_thau/features/data_vault/domain/repositories/vault_repository.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/exam_engine.dart';
import 'package:cc_dau_thau/features/mobile_ui/controllers/app_state_controller.dart';
import 'package:cc_dau_thau/features/study_progress/data/sqlite_progress_repository.dart';
import 'package:cc_dau_thau/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixtures/sample_bank_builder.dart';

class _InMemoryVaultRepository implements VaultRepository {
  _InMemoryVaultRepository(this._bank);

  final QuestionBank _bank;

  @override
  Future<VaultResult<QuestionBank>> loadActiveBank() async =>
      VaultSuccess(_bank);

  @override
  Future<VaultResult<ImportSummary>> importFromBytes(
    Uint8List bytes, {
    required ImportFileType type,
  }) async =>
      VaultSuccess(_bank.toSummary());

  @override
  Future<VaultResult<QuestionBank>> resetToBundledBank() async =>
      VaultSuccess(_bank);
}

void main() {
  sqfliteFfiInit();

  testWidgets('CcDauThauApp opens straight into HomeTab without login and switches 4 tabs', (tester) async {
    final vaultRepo = _InMemoryVaultRepository(buildSampleQuestionBank());
    final progressRepo = SqliteProgressRepository(
      dbPathProvider: () async => inMemoryDatabasePath,
      dbFactory: databaseFactoryFfiNoIsolate,
    );
    addTearDown(progressRepo.close);

    final examEngine = ExamEngine();
    final appState = AppStateController(
      vaultRepository: vaultRepo,
      examEngine: examEngine,
      progressRepository: progressRepo,
    );
    await appState.initialize();

    final deps = AppDependencies(
      vaultRepository: vaultRepo,
      examEngine: examEngine,
      progressRepository: progressRepo,
      appState: appState,
    );

    await tester.pumpWidget(CcDauThauApp(dependencies: deps));
    await tester.pumpAndSettle();

    expect(find.text('CC Đấu Thầu'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/images/home_goal_emblem.png',
      ),
      findsOneWidget,
    );
    expect(find.text('ÔN LUYỆN CCĐT'), findsOneWidget);
    expect(find.textContaining('Chỉ số sẵn sàng'), findsOneWidget);
    expect(find.textContaining('Thi thử 70 câu'), findsOneWidget);

    await tester.tap(find.text('Ôn thi'));
    await tester.pumpAndSettle();
    expect(find.text('Ôn thi chuyên đề'), findsOneWidget);

    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử thi thử'), findsOneWidget);

    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    expect(find.text('Cài đặt & Dữ liệu'), findsOneWidget);
  });
}
