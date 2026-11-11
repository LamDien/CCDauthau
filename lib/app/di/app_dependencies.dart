import 'package:cc_dau_thau/features/data_vault/data/file_vault_repository.dart';
import 'package:cc_dau_thau/features/data_vault/domain/repositories/vault_repository.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/exam_engine.dart';
import 'package:cc_dau_thau/features/mobile_ui/controllers/app_state_controller.dart';
import 'package:cc_dau_thau/features/study_progress/data/sqlite_progress_repository.dart';
import 'package:cc_dau_thau/features/study_progress/data/sqlite_progress_schema.dart';
import 'package:cc_dau_thau/features/study_progress/domain/repositories/study_progress_repository.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Top-level dependency container for the offline application.
class AppDependencies {
  AppDependencies({
    required this.vaultRepository,
    required this.examEngine,
    required this.progressRepository,
    required this.appState,
  });

  static const String bundledVaultAssetPath = 'assets/vault/default_bank.bex';

  final VaultRepository vaultRepository;
  final ExamEngine examEngine;
  final StudyProgressRepository progressRepository;
  final AppStateController appState;

  factory AppDependencies.createProduction() {
    final vaultRepo = FileVaultRepository(
      supportDirectoryProvider: getApplicationSupportDirectory,
      bundledAssetLoader: () async {
        final data = await rootBundle.load(bundledVaultAssetPath);
        return data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
      },
    );
    final examEngine = ExamEngine();
    final progressRepo = SqliteProgressRepository(
      dbPathProvider: () async {
        final dir = await getApplicationSupportDirectory();
        return p.join(dir.path, SqliteProgressSchema.databaseFileName);
      },
    );
    final appState = AppStateController(
      vaultRepository: vaultRepo,
      examEngine: examEngine,
      progressRepository: progressRepo,
    );
    return AppDependencies(
      vaultRepository: vaultRepo,
      examEngine: examEngine,
      progressRepository: progressRepo,
      appState: appState,
    );
  }
}

