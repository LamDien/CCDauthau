import 'dart:async';
import 'dart:typed_data';

import 'package:cc_dau_thau/features/ads/domain/ad_banner_service.dart';
import 'package:cc_dau_thau/features/ads/widgets/top_anchored_ad_slot.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/vault_result.dart';
import 'package:cc_dau_thau/features/data_vault/domain/repositories/vault_repository.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/exam_engine.dart';
import 'package:cc_dau_thau/features/mobile_ui/controllers/app_state_controller.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/home_shell.dart';
import 'package:cc_dau_thau/features/study_progress/data/sqlite_progress_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sample_bank_builder.dart';

class _InMemoryVaultRepo implements VaultRepository {
  _InMemoryVaultRepo(this._bank);

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

class _DelayedFakeBannerService implements AdBannerService {
  Completer<LoadedAdBannerHandle?>? completer;

  @override
  bool get isSupportedOnCurrentPlatform => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<LoadedAdBannerHandle?> loadTopAnchoredBanner({
    required int widthDp,
    required Orientation orientation,
  }) {
    final c = completer ??= Completer<LoadedAdBannerHandle?>();
    return c.future;
  }
}

void main() {
  sqfliteFfiInit();

  Future<AppStateController> createInitializedAppState(
    WidgetTester tester,
  ) async {
    final vaultRepo = _InMemoryVaultRepo(buildSampleQuestionBank());
    final progressRepo = SqliteProgressRepository(
      dbPathProvider: () async => inMemoryDatabasePath,
      dbFactory: databaseFactoryFfiNoIsolate,
    );
    addTearDown(progressRepo.close);

    final controller = AppStateController(
      vaultRepository: vaultRepo,
      examEngine: ExamEngine(),
      progressRepository: progressRepo,
    );
    await controller.initialize();
    return controller;
  }

  testWidgets(
    'TopAnchoredAdSlot collapses to 0dp when offline/unsupported without layout offset',
    (tester) async {
      final appState = await createInitializedAppState(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeShell(
            controller: appState,
            adBannerService: const NoopAdBannerService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final slotFinder = find.byType(TopAnchoredAdSlot);
      expect(slotFinder, findsOneWidget);
      expect(tester.getSize(slotFinder).height, 0);
    },
  );

  testWidgets(
    'Delayed ad load never shifts HomeTab CTA downward and reveals cleanly on tab switch or route return',
    (tester) async {
      final appState = await createInitializedAppState(tester);
      final adService = _DelayedFakeBannerService();
      final routeObserver = RouteObserver<ModalRoute<void>>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routeObserver],
          home: HomeShell(
            controller: appState,
            adBannerService: adService,
            routeObserver: routeObserver,
            onStartExamRequested: (ctx, _) {
              Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Center(child: Text('Phòng thi giả lập')),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mockButtonFinder = find.textContaining('Thi thử 70 câu');
      final initialButtonTop = tester.getTopLeft(mockButtonFinder).dy;
      expect(tester.getSize(find.byType(TopAnchoredAdSlot)).height, 0);

      // Complete the ad load AFTER HomeTab has settled on screen.
      adService.completer!.complete(
        LoadedAdBannerHandle(
          width: 390,
          height: 54,
          builder: (_) => const SizedBox(
            width: 390,
            height: 54,
            child: ColoredBox(color: Colors.amber, child: Text('AdBanner')),
          ),
          onDispose: () {},
        ),
      );
      await tester.pumpAndSettle();

      // Critical Safe Reveal invariant: CTA must NOT move downward while user looks at HomeTab.
      expect(tester.getSize(find.byType(TopAnchoredAdSlot)).height, 0);
      expect(tester.getTopLeft(mockButtonFinder).dy, initialButtonTop);
      expect(find.text('AdBanner'), findsNothing);

      // Enter exam route -> full screen outside HomeShell has zero ad slots.
      await tester.tap(mockButtonFinder);
      await tester.pumpAndSettle();
      expect(find.text('Phòng thi giả lập'), findsOneWidget);
      expect(find.byType(TopAnchoredAdSlot), findsNothing);

      // Pop back to HomeShell -> RouteAware.didPopNext promotes queued banner cleanly.
      Navigator.of(tester.element(find.text('Phòng thi giả lập'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('AdBanner'), findsOneWidget);
      // 4dp top + 54dp banner + 8dp bottom + 1dp divider = 67dp exact slot height.
      expect(tester.getSize(find.byType(TopAnchoredAdSlot)).height, 67);
    },
  );
}

