import 'dart:math';

import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_result.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/constrained_question_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const selector = ConstrainedQuestionSelector();

  Question makeQuestion({
    required String code,
    required String topicId,
    String? groupKey,
  }) {
    return Question(
      code: code,
      topicId: topicId,
      topicName: 'Topic $topicId',
      stem: 'Stem $code',
      options: const [
        AnswerOption(originalLabel: 'A', text: 'A', originalIndex: 0),
        AnswerOption(originalLabel: 'B', text: 'B', originalIndex: 1),
        AnswerOption(originalLabel: 'C', text: 'C', originalIndex: 2),
        AnswerOption(originalLabel: 'D', text: 'D', originalIndex: 3),
      ],
      correctOriginalIndex: 0,
      explanation: 'Exp',
      pointGroupKey: groupKey,
      pointGroupLabel: groupKey,
    );
  }

  group('ConstrainedQuestionSelector', () {
    test('solves cross-topic point-group trap without getting stuck', () {
      // Topic 1 has 1 shared group + 1 independent question (quota 1)
      // Topic 2 ONLY has the shared group (quota 1) -> Topic 1 must leave G_SHARED for Topic 2
      final questions = [
        makeQuestion(code: 'T1_1', topicId: 'CD01', groupKey: 'g_shared'),
        makeQuestion(code: 'T1_2', topicId: 'CD01', groupKey: null),
        makeQuestion(code: 'T2_1', topicId: 'CD02', groupKey: 'g_shared'),
      ];
      final bank = QuestionBank(
        bankVersion: 'trap',
        importedAt: DateTime.utc(2026),
        sourceType: BankSourceType.bundled,
        topics: [
          Topic(id: 'CD01', order: 1, name: 'Topic CD01', questionCount: 2),
          Topic(id: 'CD02', order: 2, name: 'Topic CD02', questionCount: 1),
        ],
        questions: questions,
      );

      for (var seed = 0; seed < 20; seed++) {
        final result = selector.select(
          bank: bank,
          quotas: const {'CD01': 1, 'CD02': 1},
          random: Random(seed),
        );

        expect(result, isA<ExamSuccess<List<Question>>>());
        final picked = (result as ExamSuccess<List<Question>>).data;
        expect(picked.map((q) => q.code).toSet(), {'T1_2', 'T2_1'});
      }
    });

    test('never selects two questions with the same non-null pointGroupKey', () {
      final questions = [
        makeQuestion(code: 'Q1', topicId: 'CD01', groupKey: 'g1'),
        makeQuestion(code: 'Q2', topicId: 'CD01', groupKey: 'g1'),
        makeQuestion(code: 'Q3', topicId: 'CD01', groupKey: 'g2'),
        makeQuestion(code: 'Q4', topicId: 'CD01', groupKey: null),
      ];
      final bank = QuestionBank(
        bankVersion: 'g',
        importedAt: DateTime.utc(2026),
        sourceType: BankSourceType.bundled,
        topics: [
          Topic(id: 'CD01', order: 1, name: 'Topic CD01', questionCount: 4),
        ],
        questions: questions,
      );

      for (var seed = 0; seed < 30; seed++) {
        final result = selector.select(
          bank: bank,
          quotas: const {'CD01': 3},
          random: Random(seed),
        );
        expect(result, isA<ExamSuccess<List<Question>>>());
        final picked = (result as ExamSuccess<List<Question>>).data;
        expect(picked.length, 3);
        final groups = picked.map((q) => q.pointGroupKey).whereType<String>().toList();
        expect(groups.toSet().length, groups.length);
      }
    });

    test('fails clearly when distinct groups across topics cannot satisfy quotas', () {
      // Total 2 distinct groups (g1, g2) across CD01 and CD02, but total quota = 3
      final questions = [
        makeQuestion(code: 'Q1', topicId: 'CD01', groupKey: 'g1'),
        makeQuestion(code: 'Q2', topicId: 'CD01', groupKey: 'g2'),
        makeQuestion(code: 'Q3', topicId: 'CD02', groupKey: 'g1'),
        makeQuestion(code: 'Q4', topicId: 'CD02', groupKey: 'g2'),
      ];
      final bank = QuestionBank(
        bankVersion: 'impossible',
        importedAt: DateTime.utc(2026),
        sourceType: BankSourceType.bundled,
        topics: [
          Topic(id: 'CD01', order: 1, name: 'Topic CD01', questionCount: 2),
          Topic(id: 'CD02', order: 2, name: 'Topic CD02', questionCount: 2),
        ],
        questions: questions,
      );

      final result = selector.select(
        bank: bank,
        quotas: const {'CD01': 2, 'CD02': 1},
        random: Random(1),
      );

      expect(result, isA<ExamError<List<Question>>>());
      expect(
        (result as ExamError<List<Question>>).failure,
        isA<InsufficientDistinctGroupsFailure>(),
      );
    });
  });
}

