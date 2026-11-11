/// Origin of the currently active question bank.
enum BankSourceType {
  bundled,
  importedBex,
  importedExcel,
}

/// Supported file formats for in-app question bank updates.
enum ImportFileType {
  bex,
  excel,
}

/// Topic classification metadata (1..13) derived from the question bank.
final class Topic {
  Topic({
    required this.id,
    required this.order,
    required this.name,
    required this.questionCount,
  });

  final String id;
  final int order;
  final String name;
  final int questionCount;

  Map<String, Object?> toJson() => {
    'id': id,
    'order': order,
    'name': name,
    'questionCount': questionCount,
  };

  factory Topic.fromJson(Map<String, Object?> json) => Topic(
    id: json['id'] as String,
    order: (json['order'] as num).toInt(),
    name: json['name'] as String,
    questionCount: (json['questionCount'] as num).toInt(),
  );
}

/// Single answer option (A, B, C, or D) in canonical original order.
final class AnswerOption {
  const AnswerOption({
    required this.originalLabel,
    required this.text,
    required this.originalIndex,
  });

  final String originalLabel;
  final String text;
  final int originalIndex;

  Map<String, Object?> toJson() => {
    'originalLabel': originalLabel,
    'text': text,
    'originalIndex': originalIndex,
  };

  factory AnswerOption.fromJson(Map<String, Object?> json) => AnswerOption(
    originalLabel: json['originalLabel'] as String,
    text: json['text'] as String,
    originalIndex: (json['originalIndex'] as num).toInt(),
  );
}

/// Immutable bidding exam question with optional knowledge-point group.
final class Question {
  Question({
    required this.code,
    this.originalOrder,
    required this.topicId,
    required this.topicName,
    required this.stem,
    required List<AnswerOption> options,
    required this.correctOriginalIndex,
    required this.explanation,
    this.legalReference,
    this.pointGroupKey,
    this.pointGroupLabel,
  }) : options = List<AnswerOption>.unmodifiable(options) {
    if (this.options.length != 4) {
      throw ArgumentError.value(options.length, 'options', 'Must have 4 options');
    }
    if (correctOriginalIndex < 0 || correctOriginalIndex >= 4) {
      throw RangeError.range(correctOriginalIndex, 0, 3, 'correctOriginalIndex');
    }
  }

  final String code;
  final int? originalOrder;
  final String topicId;
  final String topicName;
  final String stem;
  final List<AnswerOption> options;
  final int correctOriginalIndex;
  final String explanation;
  final String? legalReference;
  final String? pointGroupKey;
  final String? pointGroupLabel;

  AnswerOption get correctOption => options[correctOriginalIndex];

  Map<String, Object?> toJson() => {
    'code': code,
    'originalOrder': originalOrder,
    'topicId': topicId,
    'topicName': topicName,
    'stem': stem,
    'options': options.map((o) => o.toJson()).toList(growable: false),
    'correctOriginalIndex': correctOriginalIndex,
    'explanation': explanation,
    'legalReference': legalReference,
    'pointGroupKey': pointGroupKey,
    'pointGroupLabel': pointGroupLabel,
  };

  factory Question.fromJson(Map<String, Object?> json) => Question(
    code: json['code'] as String,
    originalOrder: (json['originalOrder'] as num?)?.toInt(),
    topicId: json['topicId'] as String,
    topicName: json['topicName'] as String,
    stem: json['stem'] as String,
    options: (json['options'] as List<Object?>)
        .map((e) => AnswerOption.fromJson(Map<String, Object?>.from(e as Map)))
        .toList(growable: false),
    correctOriginalIndex: (json['correctOriginalIndex'] as num).toInt(),
    explanation: json['explanation'] as String,
    legalReference: json['legalReference'] as String?,
    pointGroupKey: json['pointGroupKey'] as String?,
    pointGroupLabel: json['pointGroupLabel'] as String?,
  );
}

/// Complete, validated question bank with precomputed read-only indices.
final class QuestionBank {
  QuestionBank({
    required this.bankVersion,
    required this.importedAt,
    required this.sourceType,
    required List<Topic> topics,
    required List<Question> questions,
  })  : topics = List<Topic>.unmodifiable(
          [...topics]..sort((a, b) => a.order.compareTo(b.order)),
        ),
        questions = List<Question>.unmodifiable(questions),
        questionsByCode = Map<String, Question>.unmodifiable({
          for (final q in questions) q.code: q,
        }),
        questionsByTopicId = _groupQuestionsByTopic(questions),
        questionsByPointGroup = _groupQuestionsByPoint(questions);

  final String bankVersion;
  final DateTime importedAt;
  final BankSourceType sourceType;
  final List<Topic> topics;
  final List<Question> questions;
  final Map<String, Question> questionsByCode;
  final Map<String, List<Question>> questionsByTopicId;
  final Map<String, List<Question>> questionsByPointGroup;

  QuestionBank copyWith({
    String? bankVersion,
    DateTime? importedAt,
    BankSourceType? sourceType,
  }) =>
      QuestionBank(
        bankVersion: bankVersion ?? this.bankVersion,
        importedAt: importedAt ?? this.importedAt,
        sourceType: sourceType ?? this.sourceType,
        topics: topics,
        questions: questions,
      );

  ImportSummary toSummary() {
    var groupedQuestions = 0;
    for (final q in questions) {
      if (q.pointGroupKey != null) groupedQuestions++;
    }
    return ImportSummary(
      bankVersion: bankVersion,
      totalQuestions: questions.length,
      topicCount: topics.length,
      pointGroupCount: questionsByPointGroup.length,
      groupedQuestionCount: groupedQuestions,
      sourceType: sourceType,
      importedAt: importedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'bankVersion': bankVersion,
    'importedAtIso': importedAt.toUtc().toIso8601String(),
    'topics': topics.map((t) => t.toJson()).toList(growable: false),
    'questions': questions.map((q) => q.toJson()).toList(growable: false),
  };

  factory QuestionBank.fromJson(
    Map<String, Object?> json, {
    required BankSourceType sourceType,
  }) {
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt();
    if (schemaVersion != 1) {
      throw FormatException('Unsupported schemaVersion: $schemaVersion');
    }
    return QuestionBank(
      bankVersion: json['bankVersion'] as String,
      importedAt: DateTime.parse(json['importedAtIso'] as String),
      sourceType: sourceType,
      topics: (json['topics'] as List<Object?>)
          .map((e) => Topic.fromJson(Map<String, Object?>.from(e as Map)))
          .toList(growable: false),
      questions: (json['questions'] as List<Object?>)
          .map((e) => Question.fromJson(Map<String, Object?>.from(e as Map)))
          .toList(growable: false),
    );
  }

  static Map<String, List<Question>> _groupQuestionsByTopic(
    List<Question> questions,
  ) {
    final map = <String, List<Question>>{};
    for (final q in questions) {
      map.putIfAbsent(q.topicId, () => <Question>[]).add(q);
    }
    return Map<String, List<Question>>.unmodifiable({
      for (final entry in map.entries)
        entry.key: List<Question>.unmodifiable(entry.value),
    });
  }

  static Map<String, List<Question>> _groupQuestionsByPoint(
    List<Question> questions,
  ) {
    final map = <String, List<Question>>{};
    for (final q in questions) {
      final key = q.pointGroupKey;
      if (key != null) {
        map.putIfAbsent(key, () => <Question>[]).add(q);
      }
    }
    return Map<String, List<Question>>.unmodifiable({
      for (final entry in map.entries)
        entry.key: List<Question>.unmodifiable(entry.value),
    });
  }
}

/// Summary returned after loading or updating a question bank.
final class ImportSummary {
  const ImportSummary({
    required this.bankVersion,
    required this.totalQuestions,
    required this.topicCount,
    required this.pointGroupCount,
    required this.groupedQuestionCount,
    required this.sourceType,
    required this.importedAt,
  });

  final String bankVersion;
  final int totalQuestions;
  final int topicCount;
  final int pointGroupCount;
  final int groupedQuestionCount;
  final BankSourceType sourceType;
  final DateTime importedAt;
}

