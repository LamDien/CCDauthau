# Spec: `exam-engine` — Thuật Toán Sinh Đề 70 Câu, Đảo Đáp Án & Chấm Điểm

> **Module ID:** `exam-engine` (theo [CAPABILITY_MAP.md](CAPABILITY_MAP.md))  
> **Phụ thuộc:** [`data-vault`](SPEC-data-vault.md)  
> **Module tiêu thụ hợp đồng dữ liệu:** `study-progress`, `mobile-ui`

---

## Assumptions
1. Đề thi thử chuẩn gồm **70 câu**, thời gian làm bài **60 phút (3.600 giây)**, chấm trên **thang điểm 100** (`điểm = (số câu đúng / tổng số câu) * 100`, câu chưa trả lời tính sai).
2. `data-vault` luôn cung cấp `QuestionBank` gồm **13 chuyên đề** và tổng số câu $N \ge 70$ (ngân hàng mặc định $N = 430$), mỗi câu có 4 phương án và 1 đáp án đúng.
3. Khi chia theo **thuật toán làm tròn phần dư lớn nhất (Largest Remainder / Hamilton)** trên $N$ câu thực tế và $T = 70$:
   - Tổng số câu phân bổ qua 13 chuyên đề luôn bằng **chính xác 70**.
   - Giữ **thuần thuật toán phần dư lớn nhất** (đúng 100% tỷ lệ toán học: nếu sau này có bộ cập nhật mà một chuyên đề quá ít câu khiến phần dư làm tròn ra `0`, chuyên đề đó có thể nhận `0` câu).
4. Mỗi lần tạo đề thi thử mới, **cả thứ tự 70 câu lẫn vị trí 4 phương án A/B/C/D của từng câu** đều được xáo trộn ngẫu nhiên bằng bộ sinh số ngẫu nhiên an toàn (hỗ trợ truyền `Random` seed khi unit test để tái lập kết quả).
5. Bài **Mini-test chẩn đoán nhanh** (tùy chọn ở Trang chủ) mặc định lấy **26 câu (2 câu/chuyên đề phủ đều 13 chuyên đề)**.
6. `exam-engine` chỉ gồm **logic Dart thuần (stateless, zero Flutter UI / zero file I/O)**, nhận `QuestionBank` và trả về đề thi / kết quả chấm điểm.

---

## Objective
Xây dựng lõi thuật toán ra đề, trộn câu hỏi/đáp án và chấm điểm cho cả **Thi thử chuẩn 70 câu**, **Mini-test chẩn đoán nhanh**, và **Luyện lại riêng các câu sai**:
- Bảo đảm tỷ lệ số câu theo 13 chuyên đề chuẩn xác trên mọi bộ ngân hàng câu hỏi (430 câu gốc hoặc bộ mới sau khi user upload file cập nhật).
- Bảo đảm **không có 2 câu nào cùng một điểm kiến thức** (`pointGroupKey != null` giống nhau) xuất hiện chung trong cùng một đề thi — kể cả khi nhóm kiến thức đó nằm rải ở nhiều chuyên đề khác nhau.
- Trộn vị trí các câu thuộc 13 chuyên đề và đảo 4 phương án A/B/C/D độc lập mỗi lượt thi, giữ chính xác ánh xạ đáp án đúng & giải thích để chấm điểm và xem lại bài.

### User Stories & Acceptance Criteria
1. **Phân bổ quota 13 chuyên đề bằng Largest Remainder:** Với bộ 430 câu qua 13 chuyên đề, tổng quota trả về luôn bằng `70`, mỗi chuyên đề nhận $\lfloor q_i \rfloor$ hoặc $\lceil q_i \rceil$ câu ($q_i = \frac{c_i \times 70}{N}$), không vượt quá số câu hiện có của chuyên đề đó.
2. **Tách tuyệt đối câu "cùng một điểm" trên toàn đề:** Trong bất kỳ `GeneratedExam` nào được sinh ra, với mọi câu có `pointGroupKey != null`, mỗi `pointGroupKey` xuất hiện **tối đa 1 lần** trên toàn bộ 70 câu (không chỉ trong phạm vi 1 chuyên đề).
3. **Không bị kẹt bởi thứ tự chọn ngây thơ (Constraint Satisfaction + Backtracking):** Nếu một nhóm `pointGroupKey` xuất hiện ở cả Chuyên đề A (dồi dào câu) và Chuyên đề B (ít câu độc lập), thuật toán xử lý được ràng buộc chéo để không chọn nhầm ở Chuyên đề A làm Chuyên đề B hết câu hợp lệ. Nếu bộ dữ liệu đầu vào thực sự bất khả thi về mặt toán học (số nhóm phân biệt < quota), trả về lỗi tường minh `ExamGenerationFailure` thay vì vòng lặp vô tận hay làm sập app.
4. **Xáo trộn câu & đảo đáp án mỗi lượt thi:**
   - 70 câu được xáo trộn lẫn lộn giữa 13 chuyên đề (không xếp thành từng cụm Chuyên đề 1 -> Chuyên đề 13).
   - 4 đáp án của mỗi câu được xáo trộn bằng `Fisher-Yates`, gán nhãn hiển thị mới (`A`, `B`, `C`, `D`) tương ứng vị trí `0..3` và cập nhật chính xác `correctDisplayIndex`.
5. **Chấm điểm thang 100, xếp loại 5 mức & trích xuất câu sai:** Khi nộp bài (thủ công hoặc hết 60 phút tự nộp), chấm điểm tự động thang 100 (`(correct / total) * 100`), gán xếp loại 5 mức (`Xuất sắc` >= 90%, `Giỏi` 80%–<90%, `Khá` 60%–<80%, `Trung bình` 50%–<60%, `Không đạt yêu cầu` < 50%; `isPassed` mặc định từ `50.0` cho **Thi thử** và **Mini-test**), phân tích điểm từng chuyên đề (`TopicBreakdown`), và trả danh sách `wrongQuestionCodes` để chuyển sang chế độ **Làm lại câu sai**.
6. **Tạo phiên làm lại câu sai & Mini-test chẩn đoán:**
   - Từ danh sách `wrongQuestionCodes`, tạo phiên luyện lại gồm đúng các câu đó với thứ tự và 4 đáp án được đảo mới hoàn toàn.
   - Tạo **Mini-test chẩn đoán** (mặc định 26 câu = 2 câu/chuyên đề, hoặc số câu có sẵn nếu chuyên đề ít hơn) vẫn giữ nguyên quy tắc tách `pointGroupKey` và đảo đáp án.

---

## Core Algorithms & Contract

### 1. Thuật toán Largest Remainder (`LargestRemainderAllocator`)
Đầu vào: `List<Topic>` ($c_1 \dots c_{13}$), `targetTotal = 70`.
1. Tổng $N = \sum c_i$. Kiểm tra điều kiện tiên quyết $N \ge targetTotal$ và $c_i \ge 0$.
2. Với mỗi chuyên đề $i$:
   - $q_i = (c_i \times targetTotal) / N$
   - $base_i = \lfloor q_i \rfloor$
   - $rem_i = q_i - base_i$
3. Phần dư cần bù: $k = targetTotal - \sum base_i$.
4. Sắp xếp các chuyên đề thoả `base_i < c_i` theo `rem_i` giảm dần (phá hoà: `c_i` giảm dần, rồi `topic.order` tăng dần). Cộng `+1` cho $k$ chuyên đề đầu tiên (nếu vẫn còn dư sau vòng đầu do chạm trần `c_i`, lặp lại với chuyên đề còn dư capacity).
5. Đầu ra: `Map<TopicId, int> quotas` có tổng đúng bằng `targetTotal`.

### 2. Thuật toán chọn câu tách nhóm `Nhom_Cung_Diem` (`ConstrainedQuestionSelector`)
1. Với mỗi chuyên đề $i$ cần `quota[i]` câu:
   - Tính tập các **lựa chọn phân biệt** (distinct selection buckets): mỗi `pointGroupKey` khác `null` là 1 bucket (chứa các câu có cùng key đó trong chuyên đề $i$), mỗi câu độc lập (`pointGroupKey == null`) là 1 bucket riêng.
   - Nếu số bucket phân biệt $< quota[i]$, fail sớm ngay với `InsufficientDistinctGroupsFailure`.
2. **Sắp xếp chuyên đề theo độ căng thẳng (MRV):** Chuyên đề có độ dư `(số bucket - quota[i])` nhỏ nhất được chọn trước.
3. Trong mỗi chuyên đề, tách bước chọn thành hàm quay lui có xáo ngẫu nhiên:
   - Ở trạng thái hiện tại, lọc các câu thuộc chuyên đề $i$ có `pointGroupKey == null` hoặc `pointGroupKey` chưa nằm trong `usedPointGroups`.
   - Ưu tiên chọn các bucket không va chạm xuyên chuyên đề (hoặc xáo ngẫu nhiên ứng viên khả dụng, thử tối đa `maxBacktrackSteps = 2000` bước để tránh trường hợp xấu nhất bị treo).
4. Sau khi thu đủ 70 `Question`, chạy `Fisher-Yates` xáo trộn toàn bộ danh sách 70 câu, rồi đảo 4 đáp án từng câu để dựng `GeneratedExam`.

### 3. Hợp đồng Dart xuất cho `study-progress` và `mobile-ui`
- `ExamConfig`: `totalQuestions` (mặc định `70`), `durationSeconds` (mặc định `3600`), `passScoreThreshold` (mặc định `50.0` theo chuẩn đạt yêu cầu từ mức *Trung bình*).
- `ExamRank`: `excellent` (`Xuất sắc`, `>= 90%`), `good` (`Giỏi`, `80%..<90%`), `fair` (`Khá`, `60%..<80%`), `average` (`Trung bình`, `50%..<60%`), `fail` (`Không đạt yêu cầu`, `< 50%`).
- `GeneratedExam`: `examId`, `mode` (`mockExam` | `diagnosticMiniTest` | `retryWrong`), `durationSeconds`, `createdAt`, `items` (`List<ExamQuestion>`).
- `ExamQuestion`: `position` (`1..N`), `questionCode`, `topicId`, `topicName`, `stem`, `shuffledOptions` (`List<ShuffledOption>` gồm `displayLabel` `'A'..'D'`, `text`, `originalIndex`), `correctDisplayIndex`, `explanation`, `legalReference`, `pointGroupKey`, `pointGroupLabel`.
- `ExamSubmission`: `exam`, `selectedOptionByPosition` (`Map<int, int>`), `elapsedSeconds`, `submittedAt`, `autoSubmittedByTimeout` (`bool`).
- `ExamEvaluationResult`: `examId`, `totalQuestions`, `correctCount`, `unansweredCount`, `scoreOn100` (`double`), `rank` (`ExamRank`), `isPassed` (`bool`), `passScoreThreshold` (`double`), `topicBreakdowns` (`List<TopicBreakdown>`), `wrongQuestionCodes` (`List<String>`), `itemOutcomes` (`List<QuestionOutcome>`).
- `ExamEngine` (service interface):
  - `ExamResult<GeneratedExam> generateMockExam(QuestionBank bank, {ExamConfig config, Random? random})`
  - `ExamResult<GeneratedExam> generateDiagnosticTest(QuestionBank bank, {int perTopic = 2, Random? random})`
  - `ExamResult<GeneratedExam> generateRetrySession(QuestionBank bank, List<String> questionCodes, {Random? random})`
  - `ExamEvaluationResult gradeExam(ExamSubmission submission, {double passScoreThreshold = 50.0})`

---

## Tech Stack
- **Ngôn ngữ & SDK:** Dart `3.13.5` (thuộc Flutter `3.47.7`), **không phụ thuộc Flutter SDK (`dart:ui` / widgets)** để chạy siêu nhanh bằng `dart test` hoặc `flutter test`.
- **Thư viện:** Chỉ dùng thư viện chuẩn `dart:math`, `dart:collection` (zero external dependencies!).

---

## Commands
```bash
# Chạy toàn bộ unit test của module exam-engine
flutter test test/features/exam_engine/

# Phân tích tĩnh
flutter analyze lib/features/exam_engine test/features/exam_engine
```

---

## Project Structure
```text
lib/
  features/
    exam_engine/
      domain/
        models/           # ExamConfig, GeneratedExam, ExamQuestion, ExamEvaluationResult, ExamFailure
        services/         # ExamEngine, LargestRemainderAllocator, ConstrainedQuestionSelector, AnswerShuffler, ExamGrader
test/
  features/
    exam_engine/          # Unit tests phân bổ 70 câu, ràng buộc nhóm cùng điểm, đảo đáp án, chấm điểm & Monte Carlo 10.000 lượt
```

---

## Code Style
Tách biệt thuật toán thuần, không giữ mutable global state, trả về sealed `ExamResult<T>`:

```dart
sealed class ExamResult<T> {
  const ExamResult();
}

final class ExamSuccess<T> extends ExamResult<T> {
  const ExamSuccess(this.data);
  final T data;
}

final class ExamError<T> extends ExamResult<T> {
  const ExamError(this.failure);
  final ExamFailure failure;
}

Map<String, int> allocateByLargestRemainder({
  required List<Topic> topics,
  required int targetTotal,
}) {
  final totalQuestions = topics.fold<int>(0, (sum, t) => sum + t.questionCount);
  if (totalQuestions < targetTotal) {
    throw ArgumentError('Total questions ($totalQuestions) < target ($targetTotal)');
  }
  // Tính phần nguyên + phần dư và bù từng slot theo phần dư lớn nhất...
  return {};
}
```

---

## Testing Strategy
- **Unit tests (bắt buộc 100% pass, không mock che lấp logic thật):**
  1. `largest_remainder_allocator_test.dart`: Kiểm tra tổng 13 chuyên đề luôn bằng 70 trên phân phối 430 câu thực tế lẫn phân phối lệch; kiểm tra tie-breaker tất định; kiểm tra trường hợp chuyên đề chạm trần `c_i`.
  2. `constrained_question_selector_test.dart`:
     - Trường hợp bẫy cross-topic: chuyên đề ít câu dùng chung `Nhom_Cung_Diem` với chuyên đề nhiều câu (kiểm tra backtracking cứu được lời giải mà chọn tham lam ngây thơ bị kẹt).
     - Kiểm tra bất biến: trong 1 đề 70 câu không bao giờ có 2 câu cùng `pointGroupKey` khác `null`.
     - Trường hợp bất khả thi: 1 chuyên đề có quota = 3 nhưng chỉ có 2 nhóm `pointGroupKey` phân biệt -> trả về `ExamError<GeneratedExam>` rõ lỗi, không loop vô hạn.
  3. `answer_shuffler_test.dart`: Đảm bảo sau khi đảo 4 đáp án A/B/C/D với 500 lượt random, text tại `shuffledOptions[correctDisplayIndex]` luôn bằng chính xác text đáp án đúng ban đầu; thứ tự các phương án thực sự thay đổi qua các lượt.
  4. `exam_grader_test.dart`: Test thang điểm 100 (0 đúng = 0.0, 49/70 = 70.0 Đạt ở ngưỡng 70, 48/70 = 68.57 Trượt ở ngưỡng 70, bỏ trống tính sai); kiểm tra `topicBreakdowns` và `wrongQuestionCodes`.
  5. `exam_engine_monte_carlo_test.dart`: Sinh **10.000 đề ngẫu nhiên** trên bộ ngân hàng giả lập 430 câu (13 chuyên đề + nhiều cụm `Nhom_Cung_Diem` dày đặc) -> verify 10.000/10.000 đề hợp lệ, tổng thời gian chạy nhanh và thứ tự câu/đáp án phân bố đều.

---

## Boundaries
- **Always:**
  - Truyền `Random` có thể tiêm (injectable) vào mọi hàm sinh đề/đảo đáp án để unit test tái lập được 100%.
  - Đặt giới hạn vòng lặp/bước quay lui rõ ràng để không bao giờ treo UI thread.
  - Kiểm tra bất biến: `items.length == targetTotal`, mọi `questionCode` duy nhất, mọi `pointGroupKey != null` duy nhất.
- **Ask first:**
  - Thay đổi công thức thang điểm 100 (ví dụ chấm theo trọng số câu thay vì chia đều `100 / 70`).
  - Thay đổi quy tắc xử lý chuyên đề có quota = 0 trong thuật toán Hamilton.
- **Never:**
  - Phụ thuộc vào `flutter/material.dart`, `dart:io`, hay widget UI bên trong `exam-engine`.
  - Làm rò rỉ thứ tự chuyên đề gốc vào thứ tự xuất câu của đề thi thử (phải luôn xáo trộn lẫn 13 chuyên đề).

---

## Success Criteria
1. `flutter test test/features/exam_engine/` pass 100%, bao gồm test Monte Carlo 10.000 lượt sinh đề liên tiếp với 0 vi phạm ràng buộc `Nhom_Cung_Diem`.
2. Trên bộ 430 câu giả lập, thời gian trung bình sinh 1 đề 70 câu hoàn chỉnh (chọn câu + xáo câu + đảo đáp án) dưới `10ms`.
3. Chấm điểm thang 100, breakdown 13 chuyên đề và danh sách câu sai khớp 100% với đáp án đã đảo trong `GeneratedExam`.

---

## Open Questions
- Đã chốt toàn bộ (giữ thuần thuật toán phần dư lớn nhất; Mini-test chẩn đoán mặc định 26 câu = 2 câu/chuyên đề).
