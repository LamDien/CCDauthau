import 'dart:math';

import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_result.dart';

final class _QuestionBucket {
  _QuestionBucket({
    required this.pointGroupKey,
    required this.questions,
  });

  final String? pointGroupKey;
  final List<Question> questions;
}

/// Selects questions per topic quota while enforcing that no two selected
/// questions anywhere in the exam share the same non-null `pointGroupKey`.
final class ConstrainedQuestionSelector {
  const ConstrainedQuestionSelector({this.maxBacktrackSteps = 4000});

  final int maxBacktrackSteps;

  ExamResult<List<Question>> select({
    required QuestionBank bank,
    required Map<String, int> quotas,
    Random? random,
  }) {
    final rng = random ?? Random.secure();
    final bucketsByTopic = <String, List<_QuestionBucket>>{};
    final groupTopicCount = <String, int>{};

    for (final entry in quotas.entries) {
      final topicId = entry.key;
      final quota = entry.value;
      if (quota <= 0) continue;

      final topicQuestions = bank.questionsByTopicId[topicId] ?? const [];
      final grouped = <String, List<Question>>{};
      final buckets = <_QuestionBucket>[];

      for (final q in topicQuestions) {
        final key = q.pointGroupKey;
        if (key == null) {
          buckets.add(_QuestionBucket(pointGroupKey: null, questions: [q]));
        } else {
          grouped.putIfAbsent(key, () => <Question>[]).add(q);
        }
      }

      for (final gEntry in grouped.entries) {
        buckets.add(
          _QuestionBucket(
            pointGroupKey: gEntry.key,
            questions: gEntry.value,
          ),
        );
        groupTopicCount[gEntry.key] = (groupTopicCount[gEntry.key] ?? 0) + 1;
      }

      if (buckets.length < quota) {
        return ExamError(
          InsufficientDistinctGroupsFailure(
            'Chuyên đề $topicId chỉ có ${buckets.length} nhóm kiến thức phân biệt, '
            'không đủ chọn $quota câu không trùng điểm kiến thức.',
          ),
        );
      }
      buckets.shuffle(rng);
      bucketsByTopic[topicId] = buckets;
    }

    if (bucketsByTopic.isEmpty) {
      return const ExamSuccess([]);
    }

    final remainingQuota = <String, int>{
      for (final e in quotas.entries)
        if (e.value > 0) e.key: e.value,
    };
    final usedBucketIdxByTopic = <String, Set<int>>{
      for (final t in bucketsByTopic.keys) t: <int>{},
    };
    final usedPointGroups = <String>{};
    final chosenBuckets = <_QuestionBucket>[];
    var steps = 0;

    bool solve() {
      if (remainingQuota.values.every((q) => q == 0)) {
        return true;
      }
      if (steps >= maxBacktrackSteps) {
        return false;
      }
      steps++;

      // MRV + Forward Checking: choose the active topic with minimum slack.
      String? nextTopicId;
      var bestSlack = 1 << 30;
      List<int>? bestCandidates;

      for (final topicId in remainingQuota.keys) {
        final need = remainingQuota[topicId]!;
        if (need == 0) continue;

        final topicBuckets = bucketsByTopic[topicId]!;
        final usedIdx = usedBucketIdxByTopic[topicId]!;
        final candidates = <int>[];
        for (var i = 0; i < topicBuckets.length; i++) {
          if (usedIdx.contains(i)) continue;
          final key = topicBuckets[i].pointGroupKey;
          if (key != null && usedPointGroups.contains(key)) continue;
          candidates.add(i);
        }

        if (candidates.length < need) {
          return false; // Prune immediately.
        }
        final slack = candidates.length - need;
        if (slack < bestSlack) {
          bestSlack = slack;
          nextTopicId = topicId;
          bestCandidates = candidates;
        }
      }

      if (nextTopicId == null || bestCandidates == null) {
        return false;
      }

      final topicBuckets = bucketsByTopic[nextTopicId]!;
      final usedIdx = usedBucketIdxByTopic[nextTopicId]!;
      var triedConflictFreeBranch = false;

      for (final bucketIdx in bestCandidates) {
        final bucket = topicBuckets[bucketIdx];
        final key = bucket.pointGroupKey;
        final isCrossTopic = key != null && (groupTopicCount[key] ?? 0) > 1;
        if (!isCrossTopic) {
          if (triedConflictFreeBranch) continue;
          triedConflictFreeBranch = true;
        }

        usedIdx.add(bucketIdx);
        if (key != null) usedPointGroups.add(key);
        remainingQuota[nextTopicId] = remainingQuota[nextTopicId]! - 1;
        chosenBuckets.add(bucket);

        if (solve()) {
          return true;
        }

        chosenBuckets.removeLast();
        remainingQuota[nextTopicId] = remainingQuota[nextTopicId]! + 1;
        if (key != null) usedPointGroups.remove(key);
        usedIdx.remove(bucketIdx);
      }

      return false;
    }

    if (!solve()) {
      return const ExamError(
        InsufficientDistinctGroupsFailure(
          'Không thể chọn đủ câu hỏi thoả mãn ràng buộc tách các câu cùng một điểm trên toàn đề.',
        ),
      );
    }

    final selected = <Question>[
      for (final b in chosenBuckets)
        b.questions[rng.nextInt(b.questions.length)],
    ];
    return ExamSuccess(selected);
  }
}

