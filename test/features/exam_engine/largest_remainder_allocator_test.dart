import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_result.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/largest_remainder_allocator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const allocator = LargestRemainderAllocator();

  List<Topic> makeTopics(List<int> counts) {
    return List<Topic>.generate(
      counts.length,
      (i) => Topic(
        id: 'CD${(i + 1).toString().padLeft(2, '0')}',
        order: i + 1,
        name: 'Chuyên đề ${i + 1}',
        questionCount: counts[i],
      ),
    );
  }

  group('LargestRemainderAllocator', () {
    test('allocates exact 70 questions matching the real 430-question topic distribution', () {
      // Exact distribution from ngan_hang_cau_hoi_dau_thau.xlsx (sum = 430)
      final topics = makeTopics([30, 13, 72, 17, 13, 21, 16, 23, 64, 40, 18, 83, 20]);

      final result = allocator.allocate(topics: topics, targetTotal: 70);

      expect(result, isA<ExamSuccess<Map<String, int>>>());
      final quotas = (result as ExamSuccess<Map<String, int>>).data;
      expect(quotas.values.reduce((a, b) => a + b), 70);
      expect(quotas, {
        'CD01': 5,
        'CD02': 2,
        'CD03': 12,
        'CD04': 3,
        'CD05': 2,
        'CD06': 3,
        'CD07': 3,
        'CD08': 4,
        'CD09': 10,
        'CD10': 6,
        'CD11': 3,
        'CD12': 14,
        'CD13': 3,
      });
    });

    test('handles skewed distribution where a small topic receives 0 questions (pure Hamilton)', () {
      final topics = makeTopics([
        1, 1, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50,
      ]);

      final result = allocator.allocate(topics: topics, targetTotal: 70);

      expect(result, isA<ExamSuccess<Map<String, int>>>());
      final quotas = (result as ExamSuccess<Map<String, int>>).data;
      expect(quotas.values.reduce((a, b) => a + b), 70);
      expect(quotas['CD01'], 0);
      expect(quotas['CD02'], 0);
      for (final topic in topics) {
        expect(quotas[topic.id]! <= topic.questionCount, isTrue);
      }
    });

    test('returns ExamError when total questions are fewer than targetTotal', () {
      final topics = makeTopics(List<int>.filled(13, 5)); // 65 < 70

      final result = allocator.allocate(topics: topics, targetTotal: 70);

      expect(result, isA<ExamError<Map<String, int>>>());
      expect(
        (result as ExamError<Map<String, int>>).failure,
        isA<InsufficientQuestionsFailure>(),
      );
    });
  });
}

