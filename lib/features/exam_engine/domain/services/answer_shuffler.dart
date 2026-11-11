import 'dart:math';

import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';

/// Shuffles both question ordering and the 4 answer positions (A..D)
/// while preserving accurate mapping back to the correct original option.
final class AnswerShuffler {
  const AnswerShuffler();

  static const List<String> _displayLabels = ['A', 'B', 'C', 'D'];

  /// Shuffles [questions] order and randomizes each question's 4 options.
  List<ExamQuestion> buildShuffledQuestions(
    List<Question> questions, {
    Random? random,
  }) {
    final rng = random ?? Random.secure();
    final copy = [...questions];
    _fisherYatesShuffle(copy, rng);

    return List<ExamQuestion>.generate(
      copy.length,
      (index) => shuffleQuestion(
        copy[index],
        position: index + 1,
        random: rng,
      ),
      growable: false,
    );
  }

  /// Shuffles the 4 options of a single [question] at 1-based [position].
  ExamQuestion shuffleQuestion(
    Question question, {
    required int position,
    Random? random,
  }) {
    final rng = random ?? Random.secure();
    final optionsCopy = [...question.options];
    _fisherYatesShuffle(optionsCopy, rng);

    var correctDisplayIndex = -1;
    final shuffledOptions = List<ShuffledOption>.generate(4, (i) {
      final orig = optionsCopy[i];
      if (orig.originalIndex == question.correctOriginalIndex) {
        correctDisplayIndex = i;
      }
      return ShuffledOption(
        displayLabel: _displayLabels[i],
        text: orig.text,
        originalIndex: orig.originalIndex,
      );
    }, growable: false);

    return ExamQuestion(
      position: position,
      questionCode: question.code,
      topicId: question.topicId,
      topicName: question.topicName,
      stem: question.stem,
      shuffledOptions: shuffledOptions,
      correctDisplayIndex: correctDisplayIndex,
      explanation: question.explanation,
      legalReference: question.legalReference,
      pointGroupKey: question.pointGroupKey,
      pointGroupLabel: question.pointGroupLabel,
    );
  }

  void _fisherYatesShuffle<T>(List<T> items, Random rng) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }
}

