# Spec: `study-progress` — Tiến Độ Cá Nhân, Bản Đồ Năng Lực, Phục Thù Câu Sai & Cài Đặt

> **Module ID:** `study-progress` (theo [CAPABILITY_MAP.md](CAPABILITY_MAP.md))  
> **Phụ thuộc:** [`data-vault`](SPEC-data-vault.md), [`exam-engine`](SPEC-exam-engine.md)  
> **Module tiêu thụ hợp đồng dữ liệu:** `mobile-ui`

---

## Assumptions
1. Ứng dụng phục vụ **1 cá nhân duy nhất trên thiết bị đó** (không tài khoản đăng nhập, không đồng bộ server); mọi dữ liệu lưu cục bộ trong bộ nhớ riêng tư của app.
2. Kho dữ liệu tiến độ (`study_progress.db`) nằm **tách biệt hoàn toàn** với kho câu hỏi (`active_bank.bex`), do đó khi người dùng upload file ngân hàng câu hỏi mới qua `data-vault`, lịch sử các lần thi trước và trạng thái các câu trùng `Ma_Cau_Hoi` vẫn được bảo toàn nguyên vẹn.
3. Để xem lại chi tiết một bài thi cũ trong lịch sử không bị hỏng nếu sau này bộ câu hỏi bị sửa/xoá bớt, mỗi `ExamHistoryEntry` sẽ lưu kèm **ảnh chụp (snapshot) câu hỏi & lựa chọn tại thời điểm thi**.
4. Câu sai ở cả **Thi thử**, **Mini-test chẩn đoán**, lẫn **Ôn tập chuyên đề** đều đi vào hàng đợi **"Phục thù câu sai"**; bất kỳ lần trả lời đúng nào ở mọi chế độ (Ôn chuyên đề, Thi thử, Mini-test, hoặc Phục thù câu sai) đều được cộng vào chuỗi `revengeStreak` để gỡ cờ yếu. Người dùng cũng có thể chủ động đánh dấu sao (Bookmark) các câu cần ôn riêng vào **Danh sách tự chọn**.
5. Thời gian thi thử mặc định là **60 phút**, đồng thời cho phép người dùng tùy chỉnh trong **Cài đặt** (`30`, `45`, `60`, hoặc `90` phút) để tự luyện tốc độ làm bài.
6. Mọi phép tính phân loại màu Đỏ / Vàng / Xanh cho 13 chuyên đề tự động cập nhật ngay sau mỗi lượt trả lời câu hỏi hoặc nộp bài thi, không ép buộc người dùng làm bài kiểm tra đầu vào.

---

## Objective
Quản lý toàn bộ trạng thái học tập cá nhân, lịch sử thi thử, chẩn đoán lỗ hổng 13 chuyên đề, vòng lặp "Phục thù câu sai" và các ngưỡng cấu hình trong Setting:
- Ghi nhận từng lần trả lời ở chế độ Ôn tập và từng lượt Thi thử / Mini-test không giới hạn số lần.
- Tổng hợp **Bản đồ năng lực 13 chuyên đề** (Đỏ / Vàng / Xanh) và **Chỉ số sẵn sàng đi thi** trên Trang chủ.
- Duy trì **Hàng đợi Phục thù câu sai** với ngưỡng số lần làm đúng liên tiếp tùy chỉnh được trong Setting (mặc định `2` lần).
- Quản lý **Danh sách câu tự chọn (Bookmarks)** để làm riêng khi ôn tập.
- Cho phép tùy chỉnh ngưỡng điểm Đạt (mặc định `70/100`) và ngưỡng phục thù trong **Cài đặt (Setting)**.

### User Stories & Acceptance Criteria
1. **Ghi nhận kết quả Thi thử & Lịch sử không giới hạn:** Sau khi nộp đề thi thử (hoặc Mini-test), `study-progress` lưu vĩnh viễn bản ghi lịch sử gồm thời gian, thời lượng làm, điểm thang 100, trạng thái Đạt/Chưa đạt theo ngưỡng tại thời điểm thi, phân tích 13 chuyên đề và snapshot toàn bộ 70 câu đã làm + đáp án người dùng chọn. Xem lại lịch sử trả về danh sách sắp xếp mới nhất lên đầu.
2. **Vòng lặp "Phục thù câu sai":**
   - Bất kỳ câu nào trả lời sai (trong Thi thử, Mini-test hoặc Ôn chuyên đề) lập tức được đặt `isWeakFlagged = true` và `revengeStreak = 0`.
   - Khi trả lời đúng lại câu đang mang cờ yếu ở **bất kỳ chế độ nào** (Ôn chuyên đề, Thi thử, Mini-test, Phục thù câu sai, hoặc Làm lại câu sai từ đề thi), mỗi lần trả lời đúng tăng `revengeStreak += 1`; khi `revengeStreak >= settings.revengeRequiredStreak` (mặc định `2`), tự động đặt `isWeakFlagged = false` (gỡ khỏi danh sách yếu). Nếu trả lời sai lại giữa chừng, `revengeStreak` reset về `0`.
   - Khi người dùng thay đổi `revengeRequiredStreak` trong Setting (ví dụ từ `2` xuống `1`), đánh giá lại trạng thái câu yếu theo ngưỡng mới một cách nhất quán.
3. **Bản đồ năng lực 13 chuyên đề (Đỏ / Vàng / Xanh):**
   - Với mỗi chuyên đề trong `QuestionBank` hiện hành:
     - `unassessed` (Xám/Nhạt): Chưa trả lời câu nào trong chuyên đề.
     - `weak` (Đỏ): Tỷ lệ đúng hiện tại `< 60%`.
     - `developing` (Vàng): `60% <= tỷ lệ đúng < passScoreThreshold` (hoặc dưới ngưỡng Vững).
     - `mastered` (Xanh): Tỷ lệ đúng `>= passScoreThreshold` (mặc định `70%`) **và** đã trả lời tối thiểu `minAssessedForGreen` câu (ví dụ `min(5, topic.questionCount)` hoặc `>= 2` câu để tránh làm đúng 1 câu ngẫu nhiên đã xanh ngay).
   - Tỷ lệ đúng của chuyên đề tính theo **kết quả trả lời gần nhất của từng câu đã chạm tới** (`latestIsCorrect == true` trên tổng số câu đã từng làm trong chuyên đề đó) — phản ánh đúng năng lực hiện tại sau khi đã sửa sai, thay vì bị kéo tụt mãi mãi bởi lỗi sai cũ từ tuần trước!
4. **Danh sách tự chọn (Bookmarks):** Bật/tắt đánh dấu một `questionCode`, lấy danh sách các câu đã đánh dấu đang tồn tại trong `QuestionBank` hiện hành để chuyển sang màn hình làm bài.
5. **Cài đặt ngưỡng (Settings) & Đặt lại tiến độ:** Đọc/cập nhật `UserSettings` (`passScoreThreshold`, `revengeRequiredStreak`, `examDurationMinutes`, `diagnosticPerTopic`) có kiểm tra miền giá trị hợp lệ; hỗ trợ `resetAllProgress()` xoá sạch lịch sử & tiến độ cá nhân mà không ảnh hưởng đến ngân hàng câu hỏi.
6. **Tương thích khi Upload ngân hàng câu hỏi mới:** Khi `QuestionBank` thay đổi:
   - Các câu có `questionCode` vẫn tồn tại tiếp tục giữ nguyên `QuestionProgress` (streak, bookmark, lịch sử đúng/sai).
   - Câu không còn trong bộ mới không xuất hiện ở hàng đợi Phục thù/Bookmarks hiện hành, nhưng **vẫn xem lại được đầy đủ** trong chi tiết các bài thi lịch sử cũ nhờ snapshot.

---

## Domain Models, Persistence & Contract

### 1. Bảng SQLite cục bộ (`study_progress.db`)
- `user_settings`: `key TEXT PRIMARY KEY`, `value TEXT NOT NULL` (lưu `pass_score_threshold`, `revenge_required_streak`, `exam_duration_minutes`, `diagnostic_per_topic`).
- `question_progress`:
  - `question_code TEXT PRIMARY KEY`
  - `times_seen INTEGER NOT NULL`
  - `times_correct INTEGER NOT NULL`
  - `times_wrong INTEGER NOT NULL`
  - `latest_is_correct INTEGER` (`0`/`1`/`NULL`)
  - `revenge_streak INTEGER NOT NULL`
  - `is_weak_flagged INTEGER NOT NULL`
  - `is_bookmarked INTEGER NOT NULL`
  - `last_answered_at TEXT` (ISO 8601)
- `exam_attempts`:
  - `attempt_id TEXT PRIMARY KEY`
  - `mode TEXT NOT NULL` (`mockExam` | `diagnosticMiniTest` | `retryWrong`)
  - `submitted_at TEXT NOT NULL`
  - `elapsed_seconds INTEGER NOT NULL`
  - `auto_submitted INTEGER NOT NULL`
  - `total_questions INTEGER NOT NULL`
  - `correct_count INTEGER NOT NULL`
  - `score_on_100 REAL NOT NULL`
  - `pass_threshold_used REAL NOT NULL`
  - `is_passed INTEGER NOT NULL`
  - `topic_breakdowns_json TEXT NOT NULL`
- `exam_attempt_items`:
  - `attempt_id TEXT NOT NULL`
  - `position INTEGER NOT NULL`
  - `question_code TEXT NOT NULL`
  - `topic_id TEXT NOT NULL`
  - `topic_name TEXT NOT NULL`
  - `stem TEXT NOT NULL`
  - `options_json TEXT NOT NULL` (4 phương án đúng theo thứ tự hiển thị lúc thi)
  - `selected_display_index INTEGER` (`NULL` nếu bỏ trống)
  - `correct_display_index INTEGER NOT NULL`
  - `explanation TEXT NOT NULL`
  - `legal_reference TEXT`
  - `point_group_label TEXT`
  - `PRIMARY KEY (attempt_id, position)`

### 2. Hợp đồng Dart xuất cho `mobile-ui`
- `UserSettings`: `passScoreThreshold` (`double`, mặc định `70.0`, phạm vi `50.0..95.0`), `revengeRequiredStreak` (`int`, mặc định `2`, phạm vi `1..5`), `examDurationMinutes` (`int`, mặc định `60`), `diagnosticPerTopic` (`int`, mặc định `2`).
- `TopicMasteryStatus`: `topicId`, `topicName`, `totalQuestions`, `assessedQuestions`, `latestCorrectQuestions`, `accuracyPercent` (`double?`), `weakCount`, `level` (`MasteryLevel`: `unassessed` | `weak` | `developing` | `mastered`).
- `ReadinessSummary`: `totalBankQuestions`, `masteredQuestionsCount` (số câu có `latestIsCorrect == true`), `weakQueueCount`, `bookmarkedCount`, `mockAttemptCount`, `latestMockScore`, `bestMockScore`, `topicMasteries` (`List<TopicMasteryStatus>`).
- `StudyProgressRepository` (abstract interface):
  - `Future<UserSettings> getSettings()`
  - `Future<UserSettings> updateSettings(UserSettings next)`
  - `Future<void> recordStudyAnswer({required String questionCode, required bool isCorrect, bool isRevengeMode = false})`
  - `Future<ExamHistoryEntry> recordExamEvaluation(ExamSubmission submission, ExamEvaluationResult result)`
  - `Future<ReadinessSummary> getReadinessSummary(QuestionBank bank)`
  - `Future<List<Question>> getWeakQueueQuestions(QuestionBank bank)`
  - `Future<List<Question>> getBookmarkedQuestions(QuestionBank bank)`
  - `Future<Set<String>> getBookmarkedCodes()`
  - `Future<bool> toggleBookmark(String questionCode)`
  - `Future<List<ExamHistorySummary>> getExamHistory()`
  - `Future<ExamHistoryEntry?> getExamHistoryDetail(String attemptId)`
  - `Future<void> resetAllProgress()`

---

## Tech Stack
- **Ngôn ngữ & SDK:** Dart `3.13.5` / Flutter `3.47.7`
- **Cơ sở dữ liệu cục bộ:** `sqlite3` / `sqflite` (tầng domain giao tiếp qua abstract `ProgressDatabase` hoặc `sqflite_common_ffi` để chạy toàn bộ integration test SQLite thật trực tiếp trong `flutter test` trên macOS mà không cần giả lập!).
- **Serialisation:** `dart:convert` (`jsonEncode`/`jsonDecode` cho snapshot items & topic breakdowns).

---

## Commands
```bash
# Chạy toàn bộ unit + SQLite integration tests của module study-progress
flutter test test/features/study_progress/

# Phân tích tĩnh
flutter analyze lib/features/study_progress test/features/study_progress
```

---

## Project Structure
```text
lib/
  features/
    study_progress/
      domain/
        models/           # UserSettings, QuestionProgress, TopicMasteryStatus, ReadinessSummary, ExamHistoryEntry
        repositories/     # StudyProgressRepository interface
        services/         # MasteryCalculator, WeakQueuePolicy
      data/
        sqlite_progress_repository.dart  # Schema migration, transactions, atomic write
test/
  features/
    study_progress/       # Tests SQLite schema, weak queue streak, mastery colors, history snapshot, settings bounds
```

---

## Code Style
Tách riêng quy tắc thuần tính toán năng lực (`MasteryCalculator`) và quy tắc phục thù (`WeakQueuePolicy`) khỏi câu lệnh SQL:

```dart
enum MasteryLevel { unassessed, weak, developing, mastered }

MasteryLevel classifyTopicMastery({
  required int totalInTopic,
  required int assessedCount,
  required int latestCorrectCount,
  required double passThresholdPercent,
}) {
  if (assessedCount == 0) return MasteryLevel.unassessed;
  final accuracy = (latestCorrectCount / assessedCount) * 100.0;
  if (accuracy < 60.0) return MasteryLevel.weak;

  final minAssessedForMastery = totalInTopic < 5 ? totalInTopic : 5;
  if (accuracy >= passThresholdPercent && assessedCount >= minAssessedForMastery) {
    return MasteryLevel.mastered;
  }
  return MasteryLevel.developing;
}
```

---

## Testing Strategy
- **Unit & SQLite tests (dùng DB SQLite tạm trên RAM/temp dir via `sqflite_common_ffi`):**
  1. `weak_queue_policy_test.dart`:
     - Trả lời sai -> vào ngay hàng đợi yếu (`revengeStreak == 0`, `isWeakFlagged == true`).
     - Trả lời đúng 1 lần -> vẫn giữ trong hàng đợi khi ngưỡng = `2`; trả lời đúng lần 2 -> tự động gỡ cờ yếu.
     - Trả lời đúng 1 lần rồi sai lại -> reset `revengeStreak = 0`.
     - Đổi cài đặt ngưỡng từ `2` -> `1` hoặc `3` -> hành vi cập nhật chính xác.
  2. `mastery_calculator_test.dart`: Kiểm tra đủ 4 trạng thái `unassessed`, `weak`, `developing`, `mastered`, bao gồm guard `minAssessedForMastery` (làm đúng 1/1 câu không nhảy Xanh ngay nếu chuyên đề có 30 câu), và kiểm tra sửa câu sai cũ nâng tỷ lệ chuyên đề lên ngay nhờ `latestIsCorrect`.
  3. `sqlite_progress_repository_test.dart`:
     - Lưu & đọc lại trọn vẹn `ExamHistoryEntry` với 70 snapshot items + 13 topic breakdowns.
     - Giả lập upload bộ `QuestionBank` mới xoá mất 2 câu cũ và thêm 5 câu mới: kiểm tra bài thi lịch sử cũ vẫn đọc được đủ 70 câu, hàng đợi câu yếu lọc bỏ câu đã xoá, câu trùng `Ma_Cau_Hoi` vẫn giữ nguyên streak & bookmark.
     - `resetAllProgress()` xoá sạch `question_progress` và `exam_attempts` trong 1 transaction.

---

## Boundaries
- **Always:**
  - Dùng transaction SQLite khi ghi `exam_attempts` + `exam_attempt_items` và cập nhật `question_progress` để không bao giờ ghi nửa vời.
  - Validate miền giá trị của `UserSettings` tại ranh giới `updateSettings` (chặn ngưỡng âm hoặc > 100).
- **Ask first:**
  - Thay đổi schema bảng SQLite sau khi đã phát hành APK (cần viết migration version tăng dần `v1 -> v2`).
  - Thay đổi công thức tính màu Đỏ/Vàng/Xanh của 13 chuyên đề.
- **Never:**
  - Lưu trữ hoặc sửa đổi file `active_bank.bex` từ bên trong `study-progress`.
  - Xoá lịch sử thi thử tự động khi upload file ngân hàng câu hỏi mới.

---

## Success Criteria
1. `flutter test test/features/study_progress/` pass 100% trên SQLite thật (in-memory/temp DB).
2. Cập nhật `QuestionBank` mới không làm mất lịch sử thi thử cũ hay làm crash màn hình xem lại chi tiết bài thi cũ.
3. Thay đổi cài đặt `passScoreThreshold` và `revengeRequiredStreak` phản ánh ngay vào kết quả đánh giá Đạt/Chưa đạt mới, Bản đồ 13 chuyên đề và Hàng đợi Phục thù câu sai.

---

## Open Questions
- Đã chốt toàn bộ (cho phép chỉnh thời gian thi thử `30/45/60/90` phút trong Setting với mặc định `60` phút; trả lời đúng câu yếu ở bất kỳ chế độ nào đều cộng chuỗi gỡ cờ yếu).
