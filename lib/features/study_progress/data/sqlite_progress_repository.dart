import 'dart:convert';
import 'dart:io';

import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/study_progress/data/sqlite_progress_schema.dart';
import 'package:cc_dau_thau/features/study_progress/domain/models/progress_models.dart';
import 'package:cc_dau_thau/features/study_progress/domain/repositories/study_progress_repository.dart';
import 'package:cc_dau_thau/features/study_progress/domain/services/mastery_calculator.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite implementation of [StudyProgressRepository] storing personal progress
/// separately from the encrypted question bank.
class SqliteProgressRepository implements StudyProgressRepository {
  SqliteProgressRepository({
    required this._dbPathProvider,
    DatabaseFactory? dbFactory,
    WeakQueuePolicy? weakPolicy,
    MasteryCalculator? masteryCalculator,
    DateTime Function()? clock,
  })  : _dbFactory = dbFactory ?? databaseFactory,
        _weakPolicy = weakPolicy ?? const WeakQueuePolicy(),
        _masteryCalculator = masteryCalculator ??
            MasteryCalculator(
              weakPolicy: weakPolicy ?? const WeakQueuePolicy(),
            ),
        _clock = clock ?? _defaultClock;

  static DateTime _defaultClock() => DateTime.now().toUtc();

  final Future<String> Function() _dbPathProvider;
  final DatabaseFactory _dbFactory;
  final WeakQueuePolicy _weakPolicy;
  final MasteryCalculator _masteryCalculator;
  final DateTime Function() _clock;

  Database? _database;
  Future<Database>? _openingFuture;

  Future<Database> _getDb() async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    final inFlight = _openingFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _openDatabase();
    _openingFuture = future;
    try {
      final db = await future;
      _database = db;
      return db;
    } finally {
      _openingFuture = null;
    }
  }

  Future<Database> _openDatabase() async {
    final dbPath = await _dbPathProvider();
    if (dbPath != inMemoryDatabasePath) {
      await Directory(p.dirname(dbPath)).create(recursive: true);
    }
    return _dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: SqliteProgressSchema.version,
        onCreate: (db, version) async {
          for (final stmt in SqliteProgressSchema.createStatements) {
            await db.execute(stmt);
          }
        },
      ),
    );
  }

  /// Closes the underlying SQLite connection if open.
  Future<void> close() async {
    final inFlight = _openingFuture;
    if (inFlight != null) {
      await inFlight;
    }
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  @override
  Future<UserSettings> getSettings() async {
    final db = await _getDb();
    return _readSettings(db);
  }

  Future<UserSettings> _readSettings(DatabaseExecutor executor) async {
    final rows = await executor.query(SqliteProgressSchema.tableUserSettings);
    if (rows.isEmpty) {
      return const UserSettings();
    }

    final map = <String, String>{
      for (final row in rows) row['key'] as String: row['value'] as String,
    };

    return UserSettings(
      passScoreThreshold: double.tryParse(
            map[SqliteProgressSchema.keyPassScoreThreshold] ?? '',
          ) ??
          70.0,
      revengeRequiredStreak: int.tryParse(
            map[SqliteProgressSchema.keyRevengeRequiredStreak] ?? '',
          ) ??
          2,
      examDurationMinutes: int.tryParse(
            map[SqliteProgressSchema.keyExamDurationMinutes] ?? '',
          ) ??
          60,
      diagnosticPerTopic: int.tryParse(
            map[SqliteProgressSchema.keyDiagnosticPerTopic] ?? '',
          ) ??
          2,
    );
  }

  @override
  Future<UserSettings> updateSettings(UserSettings next) async {
    next.validate();
    final db = await _getDb();

    await db.transaction((txn) async {
      final batch = txn.batch();
      final entries = <String, String>{
        SqliteProgressSchema.keyPassScoreThreshold:
            next.passScoreThreshold.toString(),
        SqliteProgressSchema.keyRevengeRequiredStreak:
            next.revengeRequiredStreak.toString(),
        SqliteProgressSchema.keyExamDurationMinutes:
            next.examDurationMinutes.toString(),
        SqliteProgressSchema.keyDiagnosticPerTopic:
            next.diagnosticPerTopic.toString(),
      };
      for (final entry in entries.entries) {
        batch.insert(
          SqliteProgressSchema.tableUserSettings,
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Reconcile any previously flagged items that already meet the new streak threshold.
      batch.rawUpdate(
        '''
        UPDATE ${SqliteProgressSchema.tableQuestionProgress}
        SET is_weak_flagged = 0
        WHERE is_weak_flagged = 1 AND revenge_streak >= ?
        ''',
        [next.revengeRequiredStreak],
      );
      await batch.commit(noResult: true);
    });

    return next;
  }

  @override
  Future<QuestionProgress?> getQuestionProgress(String questionCode) async {
    final db = await _getDb();
    final rows = await db.query(
      SqliteProgressSchema.tableQuestionProgress,
      where: 'question_code = ?',
      whereArgs: [questionCode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _progressFromRow(rows.first);
  }

  @override
  Future<void> recordStudyAnswer({
    required String questionCode,
    required bool isCorrect,
    bool isRevengeMode = false,
  }) async {
    final db = await _getDb();
    final now = _clock().toUtc();

    await db.transaction((txn) async {
      final settings = await _readSettings(txn);
      final existingRows = await txn.query(
        SqliteProgressSchema.tableQuestionProgress,
        where: 'question_code = ?',
        whereArgs: [questionCode],
        limit: 1,
      );
      final current = existingRows.isEmpty
          ? QuestionProgress.initial(questionCode)
          : _progressFromRow(existingRows.first);

      final updated = _weakPolicy.applyAnswer(
        current: current,
        isCorrect: isCorrect,
        requiredStreak: settings.revengeRequiredStreak,
        answeredAt: now,
      );

      await txn.insert(
        SqliteProgressSchema.tableQuestionProgress,
        _progressToRow(updated),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<ExamHistoryEntry> recordExamEvaluation(
    ExamSubmission submission,
    ExamEvaluationResult result,
  ) async {
    final db = await _getDb();
    final submittedAtUtc = submission.submittedAt.toUtc();

    final summary = ExamHistorySummary(
      attemptId: result.examId,
      mode: submission.exam.mode,
      submittedAt: submittedAtUtc,
      elapsedSeconds: submission.elapsedSeconds,
      autoSubmittedByTimeout: submission.autoSubmittedByTimeout,
      totalQuestions: result.totalQuestions,
      correctCount: result.correctCount,
      scoreOn100: result.scoreOn100,
      passThresholdUsed: result.passScoreThreshold,
      isPassed: result.isPassed,
      topicBreakdowns: result.topicBreakdowns,
    );

    final historyItems = <ExamHistoryItem>[
      for (final outcome in result.itemOutcomes)
        ExamHistoryItem(
          position: outcome.question.position,
          questionCode: outcome.question.questionCode,
          topicId: outcome.question.topicId,
          topicName: outcome.question.topicName,
          stem: outcome.question.stem,
          options: outcome.question.shuffledOptions,
          selectedDisplayIndex: outcome.selectedDisplayIndex,
          correctDisplayIndex: outcome.question.correctDisplayIndex,
          explanation: outcome.question.explanation,
          legalReference: outcome.question.legalReference,
          pointGroupLabel: outcome.question.pointGroupLabel,
        ),
    ];

    await db.transaction((txn) async {
      final settings = await _readSettings(txn);

      await txn.insert(
        SqliteProgressSchema.tableExamAttempts,
        {
          'attempt_id': summary.attemptId,
          'mode': summary.mode.name,
          'submitted_at': summary.submittedAt.toIso8601String(),
          'elapsed_seconds': summary.elapsedSeconds,
          'auto_submitted': summary.autoSubmittedByTimeout ? 1 : 0,
          'total_questions': summary.totalQuestions,
          'correct_count': summary.correctCount,
          'score_on_100': summary.scoreOn100,
          'pass_threshold_used': summary.passThresholdUsed,
          'is_passed': summary.isPassed ? 1 : 0,
          'topic_breakdowns_json': jsonEncode(
            summary.topicBreakdowns.map((b) => b.toJson()).toList(),
          ),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final answeredOutcomes = result.itemOutcomes
          .where((o) => o.selectedDisplayIndex != null)
          .toList();
      final existingByCode = await _loadProgressForCodes(
        txn,
        answeredOutcomes.map((o) => o.question.questionCode).toSet(),
      );

      final batch = txn.batch();
      for (final item in historyItems) {
        batch.insert(
          SqliteProgressSchema.tableExamAttemptItems,
          {
            'attempt_id': summary.attemptId,
            'position': item.position,
            'question_code': item.questionCode,
            'topic_id': item.topicId,
            'topic_name': item.topicName,
            'stem': item.stem,
            'options_json': jsonEncode(
              item.options.map((o) => o.toJson()).toList(),
            ),
            'selected_display_index': item.selectedDisplayIndex,
            'correct_display_index': item.correctDisplayIndex,
            'explanation': item.explanation,
            'legal_reference': item.legalReference,
            'point_group_label': item.pointGroupLabel,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final outcome in answeredOutcomes) {
        final code = outcome.question.questionCode;
        final current = existingByCode[code] ?? QuestionProgress.initial(code);
        final updated = _weakPolicy.applyAnswer(
          current: current,
          isCorrect: outcome.isCorrect,
          requiredStreak: settings.revengeRequiredStreak,
          answeredAt: submittedAtUtc,
        );
        existingByCode[code] = updated;
        batch.insert(
          SqliteProgressSchema.tableQuestionProgress,
          _progressToRow(updated),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });

    return ExamHistoryEntry(summary: summary, items: historyItems);
  }

  Future<Map<String, QuestionProgress>> _loadProgressForCodes(
    DatabaseExecutor executor,
    Set<String> codes,
  ) async {
    if (codes.isEmpty) return {};
    final placeholders = List.filled(codes.length, '?').join(', ');
    final rows = await executor.query(
      SqliteProgressSchema.tableQuestionProgress,
      where: 'question_code IN ($placeholders)',
      whereArgs: codes.toList(),
    );
    return {
      for (final row in rows)
        row['question_code'] as String: _progressFromRow(row),
    };
  }

  Future<Map<String, QuestionProgress>> _loadAllProgress(
    DatabaseExecutor executor,
  ) async {
    final rows = await executor.query(SqliteProgressSchema.tableQuestionProgress);
    return {
      for (final row in rows)
        row['question_code'] as String: _progressFromRow(row),
    };
  }

  @override
  Future<ReadinessSummary> getReadinessSummary(QuestionBank bank) async {
    final db = await _getDb();
    final settings = await _readSettings(db);
    final progressByCode = await _loadAllProgress(db);
    final historySummaries = await getExamHistory();

    return _masteryCalculator.buildReadinessSummary(
      bank: bank,
      progressByCode: progressByCode,
      settings: settings,
      historySummaries: historySummaries,
    );
  }

  @override
  Future<List<Question>> getWeakQueueQuestions(QuestionBank bank) async {
    final db = await _getDb();
    final settings = await _readSettings(db);
    final rows = await db.query(
      SqliteProgressSchema.tableQuestionProgress,
      where: 'is_weak_flagged = 1',
      orderBy: 'last_answered_at DESC, question_code ASC',
    );

    final result = <Question>[];
    for (final row in rows) {
      final progress = _progressFromRow(row);
      if (!_weakPolicy.isEffectivelyWeak(
        progress,
        requiredStreak: settings.revengeRequiredStreak,
      )) {
        continue;
      }
      final question = bank.questionsByCode[progress.questionCode];
      if (question != null) {
        result.add(question);
      }
    }
    return result;
  }

  @override
  Future<List<Question>> getBookmarkedQuestions(QuestionBank bank) async {
    final codes = await getBookmarkedCodes();
    return bank.questions.where((q) => codes.contains(q.code)).toList();
  }

  @override
  Future<Set<String>> getBookmarkedCodes() async {
    final db = await _getDb();
    final rows = await db.query(
      SqliteProgressSchema.tableQuestionProgress,
      columns: ['question_code'],
      where: 'is_bookmarked = 1',
    );
    return {for (final row in rows) row['question_code'] as String};
  }

  @override
  Future<bool> toggleBookmark(String questionCode) async {
    final db = await _getDb();
    return db.transaction((txn) async {
      final rows = await txn.query(
        SqliteProgressSchema.tableQuestionProgress,
        where: 'question_code = ?',
        whereArgs: [questionCode],
        limit: 1,
      );
      final current = rows.isEmpty
          ? QuestionProgress.initial(questionCode)
          : _progressFromRow(rows.first);
      final updated = current.copyWith(isBookmarked: !current.isBookmarked);

      await txn.insert(
        SqliteProgressSchema.tableQuestionProgress,
        _progressToRow(updated),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return updated.isBookmarked;
    });
  }

  @override
  Future<List<ExamHistorySummary>> getExamHistory() async {
    final db = await _getDb();
    final rows = await db.query(
      SqliteProgressSchema.tableExamAttempts,
      orderBy: 'submitted_at DESC, rowid DESC',
    );
    return rows.map(_historySummaryFromRow).toList();
  }

  @override
  Future<ExamHistoryEntry?> getExamHistoryDetail(String attemptId) async {
    final db = await _getDb();
    final attemptRows = await db.query(
      SqliteProgressSchema.tableExamAttempts,
      where: 'attempt_id = ?',
      whereArgs: [attemptId],
      limit: 1,
    );
    if (attemptRows.isEmpty) return null;

    final itemRows = await db.query(
      SqliteProgressSchema.tableExamAttemptItems,
      where: 'attempt_id = ?',
      whereArgs: [attemptId],
      orderBy: 'position ASC',
    );

    return ExamHistoryEntry(
      summary: _historySummaryFromRow(attemptRows.first),
      items: itemRows.map(_historyItemFromRow).toList(),
    );
  }

  @override
  Future<void> resetAllProgress() async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete(SqliteProgressSchema.tableExamAttemptItems);
      await txn.delete(SqliteProgressSchema.tableExamAttempts);
      await txn.delete(SqliteProgressSchema.tableQuestionProgress);
    });
  }

  Map<String, Object?> _progressToRow(QuestionProgress p) {
    return {
      'question_code': p.questionCode,
      'times_seen': p.timesSeen,
      'times_correct': p.timesCorrect,
      'times_wrong': p.timesWrong,
      'latest_is_correct': p.latestIsCorrect == null
          ? null
          : (p.latestIsCorrect! ? 1 : 0),
      'revenge_streak': p.revengeStreak,
      'is_weak_flagged': p.isWeakFlagged ? 1 : 0,
      'is_bookmarked': p.isBookmarked ? 1 : 0,
      'last_answered_at': p.lastAnsweredAt?.toUtc().toIso8601String(),
    };
  }

  QuestionProgress _progressFromRow(Map<String, Object?> row) {
    final rawLatest = row['latest_is_correct'] as int?;
    final rawLastAnswered = row['last_answered_at'] as String?;
    return QuestionProgress(
      questionCode: row['question_code'] as String,
      timesSeen: row['times_seen'] as int,
      timesCorrect: row['times_correct'] as int,
      timesWrong: row['times_wrong'] as int,
      latestIsCorrect: rawLatest == null ? null : rawLatest == 1,
      revengeStreak: row['revenge_streak'] as int,
      isWeakFlagged: (row['is_weak_flagged'] as int) == 1,
      isBookmarked: (row['is_bookmarked'] as int) == 1,
      lastAnsweredAt:
          rawLastAnswered == null ? null : DateTime.parse(rawLastAnswered),
    );
  }

  ExamHistorySummary _historySummaryFromRow(Map<String, Object?> row) {
    final rawBreakdowns =
        jsonDecode(row['topic_breakdowns_json'] as String) as List<dynamic>;
    return ExamHistorySummary(
      attemptId: row['attempt_id'] as String,
      mode: ExamMode.values.byName(row['mode'] as String),
      submittedAt: DateTime.parse(row['submitted_at'] as String),
      elapsedSeconds: row['elapsed_seconds'] as int,
      autoSubmittedByTimeout: (row['auto_submitted'] as int) == 1,
      totalQuestions: row['total_questions'] as int,
      correctCount: row['correct_count'] as int,
      scoreOn100: (row['score_on_100'] as num).toDouble(),
      passThresholdUsed: (row['pass_threshold_used'] as num).toDouble(),
      isPassed: (row['is_passed'] as int) == 1,
      topicBreakdowns: [
        for (final item in rawBreakdowns)
          TopicBreakdown.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  ExamHistoryItem _historyItemFromRow(Map<String, Object?> row) {
    final rawOptions =
        jsonDecode(row['options_json'] as String) as List<dynamic>;
    return ExamHistoryItem(
      position: row['position'] as int,
      questionCode: row['question_code'] as String,
      topicId: row['topic_id'] as String,
      topicName: row['topic_name'] as String,
      stem: row['stem'] as String,
      options: [
        for (final opt in rawOptions)
          ShuffledOption.fromJson(opt as Map<String, dynamic>),
      ],
      selectedDisplayIndex: row['selected_display_index'] as int?,
      correctDisplayIndex: row['correct_display_index'] as int,
      explanation: row['explanation'] as String,
      legalReference: row['legal_reference'] as String?,
      pointGroupLabel: row['point_group_label'] as String?,
    );
  }
}
