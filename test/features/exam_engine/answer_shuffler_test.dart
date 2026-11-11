import 'dart:math';

import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/answer_shuffler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const shuffler = AnswerShuffler();

  Question makeQuestion(int id, int correctIndex) {
    return Question(
      code: 'Q$id',
      topicId: 'CD01',
      topicName: 'Topic 1',
      stem: 'Question $id',
      options: const [
        AnswerOption(originalLabel: 'A', text: 'Text Alpha', originalIndex: 0),
        AnswerOption(originalLabel: 'B', text: 'Text Beta', originalIndex: 1),
        AnswerOption(originalLabel: 'C', text: 'Text Gamma', originalIndex: 2),
        AnswerOption(originalLabel: 'D', text: 'Text Delta', originalIndex: 3),
      ],
      correctOriginalIndex: correctIndex,
      explanation: 'Exp $id',
    );
  }

  group('AnswerShuffler', () {
    test('preserves exact correct option text across 500 random shuffles', () {
      final q = makeQuestion(1, 2); // Correct text is 'Text Gamma'
      final seenCorrectPositions = <int>{};

      for (var seed = 0; seed < 500; seed++) {
        final examQ = shuffler.shuffleQuestion(
          q,
          position: 1,
          random: Random(seed),
        );
        expect(examQ.shuffledOptions.length, 4);
        expect(
          examQ.shuffledOptions.map((o) => o.displayLabel).toList(),
          ['A', 'B', 'C', 'D'],
        );
        expect(
          examQ.shuffledOptions[examQ.correctDisplayIndex].text,
          'Text Gamma',
        );
        expect(
          examQ.shuffledOptions[examQ.correctDisplayIndex].originalIndex,
          2,
        );
        seenCorrectPositions.add(examQ.correctDisplayIndex);
      }

      // Over 500 runs, the correct answer should appear in all 4 slots A, B, C, D.
      expect(seenCorrectPositions, {0, 1, 2, 3});
    });

    test('shuffles question order so topics are interleaved', () {
      final questions = List<Question>.generate(
        20,
        (i) => makeQuestion(i, 0),
      );
      final firstOrder = shuffler
          .buildShuffledQuestions(questions, random: Random(42))
          .map((e) => e.questionCode)
          .toList();
      final secondOrder = shuffler
          .buildShuffledQuestions(questions, random: Random(99))
          .map((e) => e.questionCode)
          .toList();

      expect(firstOrder.length, 20);
      expect(firstOrder, isNot(equals(questions.map((q) => q.code).toList())));
      expect(firstOrder, isNot(equals(secondOrder)));
    });
  });
}

