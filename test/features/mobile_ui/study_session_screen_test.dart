import 'package:cc_dau_thau/app/theme/app_theme.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/mobile_ui/screens/study_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

QuestionBank _buildPointGroupBank() {
  final topics = [
    Topic(id: 't1', order: 1, name: 'Chuyên đề 1: Quy định chung', questionCount: 3),
  ];

  final questions = [
    Question(
      code: 'Q_GROUP_1',
      originalOrder: 1,
      topicId: 't1',
      topicName: 'Chuyên đề 1: Quy định chung',
      stem: 'Hạn mức chỉ định thầu đối với gói thầu mua sắm hàng hóa thuộc dự toán mua sắm thường xuyên là bao nhiêu?',
      options: [
        AnswerOption(originalLabel: 'A', text: 'Không quá 100 triệu đồng', originalIndex: 0),
        AnswerOption(originalLabel: 'B', text: 'Không quá 300 triệu đồng', originalIndex: 1),
        AnswerOption(originalLabel: 'C', text: 'Không quá 500 triệu đồng', originalIndex: 2),
        AnswerOption(originalLabel: 'D', text: 'Không quá 1 tỷ đồng', originalIndex: 3),
      ],
      correctOriginalIndex: 0,
      explanation: 'Theo Điều 23 Luật Đấu thầu.',
      legalReference: 'Điều 23 Luật Đấu thầu 2023',
      pointGroupKey: 'han_muc_chi_dinh_thau',
      pointGroupLabel: 'Hạn mức chỉ định thầu',
    ),
    Question(
      code: 'Q_GROUP_2',
      originalOrder: 2,
      topicId: 't1',
      topicName: 'Chuyên đề 1: Quy định chung',
      stem: 'Hạn mức chỉ định thầu đối với gói thầu xây lắp thuộc dự án đầu tư phát triển là bao nhiêu?',
      options: [
        AnswerOption(originalLabel: 'A', text: 'Không quá 500 triệu đồng', originalIndex: 0),
        AnswerOption(originalLabel: 'B', text: 'Không quá 1 tỷ đồng', originalIndex: 1),
        AnswerOption(originalLabel: 'C', text: 'Không quá 2 tỷ đồng', originalIndex: 2),
        AnswerOption(originalLabel: 'D', text: 'Không quá 5 tỷ đồng', originalIndex: 3),
      ],
      correctOriginalIndex: 1,
      explanation: 'Theo Nghị định hướng dẫn Luật Đấu thầu.',
      legalReference: 'Nghị định 24/2024/NĐ-CP',
      pointGroupKey: 'han_muc_chi_dinh_thau',
      pointGroupLabel: 'Hạn mức chỉ định thầu',
    ),
    Question(
      code: 'Q_SOLO',
      originalOrder: 3,
      topicId: 't1',
      topicName: 'Chuyên đề 1: Quy định chung',
      stem: 'Câu hỏi độc lập không thuộc nhóm cùng điểm kiến thức nào?',
      options: [
        AnswerOption(originalLabel: 'A', text: 'Phương án 1', originalIndex: 0),
        AnswerOption(originalLabel: 'B', text: 'Phương án 2', originalIndex: 1),
        AnswerOption(originalLabel: 'C', text: 'Phương án 3', originalIndex: 2),
        AnswerOption(originalLabel: 'D', text: 'Phương án 4', originalIndex: 3),
      ],
      correctOriginalIndex: 0,
      explanation: 'Giải thích câu độc lập.',
      legalReference: null,
      pointGroupKey: null,
      pointGroupLabel: null,
    ),
  ];

  return QuestionBank(
    bankVersion: 'test-v1',
    importedAt: DateTime.utc(2026, 11, 11),
    sourceType: BankSourceType.bundled,
    topics: topics,
    questions: questions,
  );
}

void main() {
  testWidgets('StudySessionScreen toggles view mode, reveals explanation, opens PointGroupSheet, and hides it when pointGroupKey is null', (tester) async {
    final bank = _buildPointGroupBank();
    var recordedCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildLightTheme(),
        home: StudySessionScreen(
          title: 'Chuyên đề 1',
          questions: bank.questions,
          bank: bank,
          initialShuffled: false,
          onAnswerRecorded: (code, isCorrect, isRevenge) async {
            recordedCalls++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // First question belongs to pointGroupKey -> point group button visible
    expect(find.textContaining('Xem các câu cùng điểm kiến thức (2 câu)'), findsOneWidget);

    // Tap option A -> reveals explanation and records answer
    await tester.tap(find.text('Không quá 100 triệu đồng'));
    await tester.pumpAndSettle();
    expect(recordedCalls, 1);
    expect(find.textContaining('Theo Điều 23 Luật Đấu thầu.'), findsOneWidget);

    // Open BottomSheet comparing peer questions with the same pointGroupKey
    final viewGroupBtn = find.textContaining('Xem các câu cùng điểm kiến thức');
    await tester.ensureVisible(viewGroupBtn);
    await tester.pumpAndSettle();
    await tester.tap(viewGroupBtn);
    await tester.pumpAndSettle();
    expect(find.text('Cùng điểm kiến thức (2 câu)'), findsOneWidget);
    expect(find.text('Q_GROUP_2'), findsOneWidget);

    // Close BottomSheet
    Navigator.of(tester.element(find.text('Cùng điểm kiến thức (2 câu)'))).pop();
    await tester.pumpAndSettle();

    // Switch to Multi-question list view and preserve answered progress
    await tester.tap(find.text('Nhiều câu'));
    await tester.pumpAndSettle();
    expect(find.text('1/3 đã làm'), findsOneWidget);
    expect(find.textContaining('Theo Điều 23 Luật Đấu thầu.'), findsOneWidget);

    // Switch back to Single view and move to standalone question #3 (no pointGroupKey)
    await tester.tap(find.text('Từng câu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Câu tiếp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Câu tiếp'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Câu hỏi độc lập'), findsOneWidget);
    expect(find.textContaining('Xem các câu cùng điểm kiến thức'), findsNothing);
  });
}
