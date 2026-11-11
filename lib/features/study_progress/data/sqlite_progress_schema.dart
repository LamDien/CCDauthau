/// SQLite schema definitions (v1) for personal study progress and exam history snapshots.
abstract final class SqliteProgressSchema {
  static const int version = 1;
  static const String databaseFileName = 'study_progress.db';

  static const String tableUserSettings = 'user_settings';
  static const String tableQuestionProgress = 'question_progress';
  static const String tableExamAttempts = 'exam_attempts';
  static const String tableExamAttemptItems = 'exam_attempt_items';

  static const String keyPassScoreThreshold = 'pass_score_threshold';
  static const String keyRevengeRequiredStreak = 'revenge_required_streak';
  static const String keyExamDurationMinutes = 'exam_duration_minutes';
  static const String keyDiagnosticPerTopic = 'diagnostic_per_topic';

  static const List<String> createStatements = [
    '''
    CREATE TABLE IF NOT EXISTS $tableUserSettings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableQuestionProgress (
      question_code TEXT PRIMARY KEY,
      times_seen INTEGER NOT NULL,
      times_correct INTEGER NOT NULL,
      times_wrong INTEGER NOT NULL,
      latest_is_correct INTEGER,
      revenge_streak INTEGER NOT NULL,
      is_weak_flagged INTEGER NOT NULL,
      is_bookmarked INTEGER NOT NULL,
      last_answered_at TEXT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableExamAttempts (
      attempt_id TEXT PRIMARY KEY,
      mode TEXT NOT NULL,
      submitted_at TEXT NOT NULL,
      elapsed_seconds INTEGER NOT NULL,
      auto_submitted INTEGER NOT NULL,
      total_questions INTEGER NOT NULL,
      correct_count INTEGER NOT NULL,
      score_on_100 REAL NOT NULL,
      pass_threshold_used REAL NOT NULL,
      is_passed INTEGER NOT NULL,
      topic_breakdowns_json TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableExamAttemptItems (
      attempt_id TEXT NOT NULL,
      position INTEGER NOT NULL,
      question_code TEXT NOT NULL,
      topic_id TEXT NOT NULL,
      topic_name TEXT NOT NULL,
      stem TEXT NOT NULL,
      options_json TEXT NOT NULL,
      selected_display_index INTEGER,
      correct_display_index INTEGER NOT NULL,
      explanation TEXT NOT NULL,
      legal_reference TEXT,
      point_group_label TEXT,
      PRIMARY KEY (attempt_id, position)
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_question_progress_weak ON $tableQuestionProgress(is_weak_flagged)',
    'CREATE INDEX IF NOT EXISTS idx_question_progress_bookmark ON $tableQuestionProgress(is_bookmarked)',
    'CREATE INDEX IF NOT EXISTS idx_exam_attempts_submitted_at ON $tableExamAttempts(submitted_at DESC)',
  ];
}

