import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_result.dart';

/// Distributes [targetTotal] questions across topics proportionally using the
/// pure Largest Remainder (Hamilton) method with exact integer arithmetic.
final class LargestRemainderAllocator {
  const LargestRemainderAllocator();

  ExamResult<Map<String, int>> allocate({
    required List<Topic> topics,
    required int targetTotal,
  }) {
    if (targetTotal < 0) {
      return const ExamError(
        InsufficientQuestionsFailure('Số lượng câu hỏi mục tiêu không hợp lệ.'),
      );
    }
    if (topics.isEmpty) {
      return const ExamError(
        InsufficientQuestionsFailure('Danh sách chuyên đề đang trống.'),
      );
    }

    final totalAvailable = topics.fold<int>(0, (sum, t) => sum + t.questionCount);
    if (totalAvailable < targetTotal) {
      return ExamError(
        InsufficientQuestionsFailure(
          'Ngân hàng hiện có $totalAvailable câu, không đủ $targetTotal câu để tạo đề.',
        ),
      );
    }
    if (targetTotal == 0) {
      return ExamSuccess({for (final t in topics) t.id: 0});
    }

    final quotas = <String, int>{};
    final remainders = <String, int>{};
    var allocatedSum = 0;

    for (final topic in topics) {
      final numerator = topic.questionCount * targetTotal;
      final base = numerator ~/ totalAvailable;
      final rem = numerator % totalAvailable;
      quotas[topic.id] = base;
      remainders[topic.id] = rem;
      allocatedSum += base;
    }

    var remaining = targetTotal - allocatedSum;
    final capacityMap = {for (final t in topics) t.id: t.questionCount};

    while (remaining > 0) {
      final eligible = topics
          .where((t) => quotas[t.id]! < capacityMap[t.id]!)
          .toList()
        ..sort((a, b) {
          final remCmp = remainders[b.id]!.compareTo(remainders[a.id]!);
          if (remCmp != 0) return remCmp;
          final countCmp = b.questionCount.compareTo(a.questionCount);
          if (countCmp != 0) return countCmp;
          return a.order.compareTo(b.order);
        });

      if (eligible.isEmpty) break;
      for (final topic in eligible) {
        if (remaining == 0) break;
        quotas[topic.id] = quotas[topic.id]! + 1;
        remaining--;
      }
    }

    return ExamSuccess(Map<String, int>.unmodifiable(quotas));
  }
}

