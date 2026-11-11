# Task Checklist: CC Đấu Thầu (`vn.ccdauthau.luyenthi`)

Theo kế hoạch tại [tasks/plan.md](plan.md) và các đặc tả `SPEC-*.md`.

---

## Task 1: Khởi tạo dự án Flutter & Cấu hình Android (`vn.ccdauthau.luyenthi`)

**Description:** Tạo khung dự án Flutter chuẩn trong workspace, khai báo đầy đủ dependencies đã chốt (`cryptography`, `spreadsheet_decoder`, `sqflite`, `sqflite_common_ffi`, `path_provider`, `file_picker`, `lucide_icons_flutter`) và cấu hình tên app `"CC Đấu Thầu"`, `applicationId = "vn.ccdauthau.luyenthi"`, bật R8/ProGuard và loại bỏ quyền `INTERNET`.

**Acceptance criteria:**
- [x] `flutter pub get` thành công với toàn bộ dependencies sạch warning phiên bản.
- [x] Cấu hình Android dùng tên app `"CC Đấu Thầu"`, `applicationId "vn.ccdauthau.luyenthi"`, `minSdk >= 26`, bật `isMinifyEnabled` & `isShrinkResources` cho release.
- [x] `AndroidManifest.xml` không khai báo quyền `INTERNET`.

**Verification:**
- [x] Tests pass: `flutter test` (test mặc định khởi tạo sạch)
- [x] Build succeeds: `flutter analyze`
- [x] Manual check: Kiểm tra `pubspec.yaml`, `build.gradle.kts` và `AndroidManifest.xml` khớp spec

**Dependencies:** None

**Files likely touched:**
- `pubspec.yaml`
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `lib/main.dart`

**Estimated scope:** Medium (4 files)

---

## Task 2: Domain Models, `VaultResult` & `PointGroupNormalizer` (`data-vault`)

**Description:** Định nghĩa các immutable models xuất sang các module khác (`Question`, `AnswerOption`, `Topic`, `QuestionBank`, `ImportSummary`, `VaultResult`, `VaultFailure`, `VaultRepository`) và viết `PointGroupNormalizer` chuẩn hoá chuỗi nhóm "cùng một điểm" (trim, gộp khoảng trắng, lowercase).

**Acceptance criteria:**
- [x] Toàn bộ models bất biến (`final` fields, `List.unmodifiable`), có `copyWith`/serialization canonical JSON sạch sẽ.
- [x] `PointGroupNormalizer` gom đúng `"Ưu đãi nhà thầu"` và `"  ưu  đãi nhà thầu "` về cùng `pointGroupKey`, trả `null` nếu rỗng.
- [x] Hợp đồng `VaultRepository` hỗ trợ `loadActiveBank`, `importFromBytes`, `resetToBundledBank`.

**Verification:**
- [x] Tests pass: `flutter test test/features/data_vault/point_group_normalizer_test.dart`
- [x] Build succeeds: `flutter analyze lib/features/data_vault test/features/data_vault`
- [x] Manual check: Đối chiếu chữ ký kiểu với `SPEC-data-vault.md`

**Dependencies:** Task 1

**Files likely touched:**
- `lib/features/data_vault/domain/models/question_bank.dart`
- `lib/features/data_vault/domain/models/vault_result.dart`
- `lib/features/data_vault/domain/repositories/vault_repository.dart`
- `lib/features/data_vault/domain/services/point_group_normalizer.dart`
- `test/features/data_vault/point_group_normalizer_test.dart`

**Estimated scope:** Medium (5 files)

---

## Task 3: `ExcelQuestionParser` cho cấu trúc 9 cột thực tế (`data-vault`)

**Description:** Cài đặt bộ phân tích file `.xlsx` hỗ trợ tên cột tiếng Việt thực tế (`STT`, `Phân loại chuyên đề`, `Câu hỏi`, `Phương án A–D`, `Đáp án đúng`, `Căn cứ pháp lý`) cùng các cột mở rộng tùy chọn (`Mã câu hỏi`, `Giải thích`, `Nhóm cùng điểm`). Validate từng dòng và ràng buộc toàn cục đủ 13 chuyên đề và >= 70 câu.

**Acceptance criteria:**
- [x] Parse chính xác file `.xlsx` có 9 cột chuẩn (tự tạo `Ma_Cau_Hoi` từ chuyên đề + `STT` nếu thiếu cột `Mã câu hỏi`, dùng `Căn cứ pháp lý` làm giải thích nếu thiếu cột `Giải thích`).
- [x] Từ chối file có < 13 chuyên đề hoặc < 70 câu, thiếu phương án A–D, trùng mã câu hỏi, hoặc `Đáp án đúng` ngoài `A..D`, trả về lỗi rõ số dòng (`ExcelRowError`).
- [x] Sắp xếp thứ tự 13 chuyên đề nhất quán theo số thứ tự đầu tên (nếu có) hoặc thứ tự xuất hiện.

**Verification:**
- [x] Tests pass: `flutter test test/features/data_vault/excel_question_parser_test.dart`
- [x] Build succeeds: `flutter analyze lib/features/data_vault test/features/data_vault`
- [x] Manual check: Kiểm tra thông báo lỗi dòng thân thiện tiếng Việt

**Dependencies:** Task 2

**Files likely touched:**
- `lib/features/data_vault/domain/services/excel_question_parser.dart`
- `test/features/data_vault/excel_question_parser_test.dart`
- `test/fixtures/sample_bank_builder.dart`

**Estimated scope:** Medium (3 files)

---

## Task 4: `BexCodec` (AES-256-GCM) & `FileVaultRepository` Atomic Swap (`data-vault`)

**Description:** Xây dựng lớp mã hoá/giải mã gói `.bex` (header `BEX1`, version, nonce 12B, Gzip + AES-256-GCM với key tách mảnh obfuscated) và `FileVaultRepository` đọc từ `active_bank.bex` hoặc asset mặc định, ghi atomic swap khi upload `.bex`/`.xlsx` và khôi phục về mặc định.

**Acceptance criteria:**
- [x] Round-trip mã hoá/giải mã `.bex` bảo toàn 100% tiếng Việt Unicode; sai magic hoặc lật 1 bit ciphertext trả về `VaultError` an toàn.
- [x] Import file lỗi không làm mất hoặc hỏng `active_bank.bex` hiện hành (Fail-Closed & Atomic Swap).
- [x] `resetToBundledBank()` xoá `active_bank.bex` và nạp lại bản đóng gói gốc trong asset.

**Verification:**
- [x] Tests pass: `flutter test test/features/data_vault/`
- [x] Build succeeds: `flutter analyze lib/features/data_vault test/features/data_vault`
- [x] Manual check: Kiểm tra không có file JSON/Excel thô nào được ghi ra disk

**Dependencies:** Task 3

**Files likely touched:**
- `lib/features/data_vault/domain/services/bex_codec.dart`
- `lib/features/data_vault/data/file_vault_repository.dart`
- `test/features/data_vault/bex_codec_test.dart`
- `test/features/data_vault/file_vault_repository_test.dart`

**Estimated scope:** Medium (4 files)

---

## Task 5: CLI Packer `tool/pack_bex.dart` & Dữ liệu đóng gói ban đầu (`data-vault`)

**Description:** Tạo công cụ dòng lệnh `tool/pack_bex.dart` đọc file Excel chuẩn, chạy validation đầy đủ, in thống kê 13 chuyên đề & nhóm cùng điểm, và xuất ra `assets/vault/default_bank.bex`. Tạo sẵn `assets/vault/default_bank.bex` ban đầu từ fixture chuẩn để app chạy được ngay (sẽ thay bằng file 430 câu thật khi được cung cấp).

**Acceptance criteria:**
- [x] `dart run tool/pack_bex.dart --input ... --output ...` chạy thành công và báo rõ thống kê 13 chuyên đề.
- [x] Báo exit code khác 0 và liệt kê dòng lỗi nếu file Excel đầu vào không đạt chuẩn.
- [x] `assets/vault/default_bank.bex` giải mã thành công bởi `FileVaultRepository`.

**Verification:**
- [x] Tests pass: `flutter test test/features/data_vault/`
- [x] Build succeeds: `dart run tool/pack_bex.dart --help`
- [x] Manual check: Chạy đóng gói thử với file Excel giả lập 430 câu / 13 chuyên đề

**Dependencies:** Task 4

**Files likely touched:**
- `tool/pack_bex.dart`
- `assets/vault/default_bank.bex`

**Estimated scope:** Small (2 files)

---

## Checkpoint: After Tasks 1-5 (`data-vault`)
- [x] `flutter test test/features/data_vault/` pass 100%
- [x] `flutter analyze` sạch lỗi
- [x] `tool/pack_bex.dart` đóng gói được `.bex` < 500KB

---

## Task 6: Models & `LargestRemainderAllocator` (`exam-engine`)

**Description:** Tạo domain models cho đề thi & kết quả (`ExamConfig`, `GeneratedExam`, `ExamQuestion`, `ShuffledOption`, `ExamSubmission`, `ExamEvaluationResult`, `ExamResult`, `ExamFailure`) và cài đặt `LargestRemainderAllocator` phân bổ động 70 câu theo tỷ lệ 13 chuyên đề bằng thuật toán làm tròn phần dư lớn nhất (Hamilton thuần).

**Acceptance criteria:**
- [x] Tổng quota 13 chuyên đề luôn bằng `targetTotal` (`70`) trên mọi phân phối $N \ge 70$.
- [x] Không bao giờ phân bổ vượt quá số câu hiện có của chuyên đề (`quota[i] <= c_i`); xử lý tie-break tất định.
- [x] Trả về `ExamError` rõ ràng nếu ngân hàng câu hỏi < `targetTotal`.

**Verification:**
- [x] Tests pass: `flutter test test/features/exam_engine/largest_remainder_allocator_test.dart`
- [x] Build succeeds: `flutter analyze lib/features/exam_engine test/features/exam_engine`
- [x] Manual check: Đối chiếu kết quả chia thử trên phân phối 430 câu

**Dependencies:** Task 2

**Files likely touched:**
- `lib/features/exam_engine/domain/models/exam_models.dart`
- `lib/features/exam_engine/domain/models/exam_result.dart`
- `lib/features/exam_engine/domain/services/largest_remainder_allocator.dart`
- `test/features/exam_engine/largest_remainder_allocator_test.dart`

**Estimated scope:** Medium (4 files)

---

## Task 7: `ConstrainedQuestionSelector` & `AnswerShuffler` (`exam-engine`)

**Description:** Triển khai thuật toán chọn câu tách tuyệt đối các câu cùng `pointGroupKey` xuyên suốt cả 13 chuyên đề bằng heuristic MRV + Randomized Backtracking có giới hạn bước, kèm `AnswerShuffler` dùng `Fisher-Yates` trộn 70 câu và đảo 4 phương án A–D giữ chính xác đáp án đúng.

**Acceptance criteria:**
- [x] Giải được trường hợp `pointGroupKey` vắt chéo chuyên đề ít câu và chuyên đề nhiều câu mà chọn tham lam bị kẹt.
- [x] Đảm bảo bất biến: mỗi `pointGroupKey != null` xuất hiện tối đa 1 lần trong đề; thất bại có kiểm soát nếu dữ liệu đầu vào bất khả thi.
- [x] Sau khi đảo 4 đáp án, `shuffledOptions[correctDisplayIndex].text` luôn khớp 100% đáp án đúng gốc.

**Verification:**
- [x] Tests pass: `flutter test test/features/exam_engine/constrained_question_selector_test.dart test/features/exam_engine/answer_shuffler_test.dart`
- [x] Build succeeds: `flutter analyze lib/features/exam_engine test/features/exam_engine`
- [x] Manual check: Kiểm tra hỗ trợ truyền `Random` seed để tái lập test

**Dependencies:** Task 6

**Files likely touched:**
- `lib/features/exam_engine/domain/services/constrained_question_selector.dart`
- `lib/features/exam_engine/domain/services/answer_shuffler.dart`
- `test/features/exam_engine/constrained_question_selector_test.dart`
- `test/features/exam_engine/answer_shuffler_test.dart`

**Estimated scope:** Medium (4 files)

---

## Task 8: `ExamGrader`, `ExamEngine` & Kiểm thử Monte Carlo 10.000 lượt (`exam-engine`)

**Description:** Hoàn thiện `ExamGrader` (chấm thang 100, kiểm tra Đạt/Chưa đạt theo `passScoreThreshold`, breakdown 13 chuyên đề, xuất `wrongQuestionCodes`) và `ExamEngine` (sinh đề 70 câu, Mini-test 26 câu, phiên làm lại câu sai). Viết test Monte Carlo chạy 10.000 lượt sinh đề liên tiếp trên 430 câu giả lập.

**Acceptance criteria:**
- [x] Chấm thang 100 chính xác, câu bỏ trống tính sai, tách được đúng danh sách `wrongQuestionCodes` và breakdown 13 chuyên đề.
- [x] `generateDiagnosticTest` tạo 26 câu (2 câu/chuyên đề) tách `pointGroupKey`; `generateRetrySession` đảo mới cả câu & đáp án.
- [x] Test Monte Carlo 10.000 lượt sinh đề pass 100% với 0 trùng `pointGroupKey` và thời gian trung bình < 10ms/đề.

**Verification:**
- [x] Tests pass: `flutter test test/features/exam_engine/`
- [x] Build succeeds: `flutter analyze lib/features/exam_engine test/features/exam_engine`
- [x] Manual check: Xác nhận `exam-engine` không import `flutter/material.dart` hay `dart:io`

**Dependencies:** Task 7

**Files likely touched:**
- `lib/features/exam_engine/domain/services/exam_grader.dart`
- `lib/features/exam_engine/domain/services/exam_engine.dart`
- `test/features/exam_engine/exam_grader_test.dart`
- `test/features/exam_engine/exam_engine_monte_carlo_test.dart`

**Estimated scope:** Medium (4 files)

---

## Checkpoint: After Tasks 6-8 (`exam-engine`)
- [x] `flutter test test/features/exam_engine/` pass 100% (kể cả 10.000 lượt Monte Carlo)
- [x] `flutter analyze` sạch lỗi

---

## Task 9: Domain Models, `MasteryCalculator` & `WeakQueuePolicy` (`study-progress`)

**Description:** Xây dựng models (`UserSettings`, `QuestionProgress`, `TopicMasteryStatus`, `ReadinessSummary`, `ExamHistoryEntry`), hợp đồng `StudyProgressRepository`, và logic thuần tính Bản đồ năng lực 13 chuyên đề (Đỏ/Vàng/Xanh) cùng chính sách "Phục thù câu sai" (trả lời đúng ở mọi chế độ đều cộng chuỗi `revengeStreak`).

**Acceptance criteria:**
- [x] Phân loại đúng 4 mức `unassessed`, `weak`, `developing`, `mastered` kèm guard `minAssessedForMastery`.
- [x] Câu sai đặt `revengeStreak = 0`, `isWeakFlagged = true`; trả lời đúng ở mọi chế độ tăng streak và gỡ cờ khi đạt ngưỡng `revengeRequiredStreak`.
- [x] `UserSettings` validate miền giá trị hợp lệ (điểm Đạt `50..95`, streak `1..5`, thời gian `30/45/60/90`, mini-test `1/2`).

**Verification:**
- [x] Tests pass: `flutter test test/features/study_progress/mastery_and_weak_policy_test.dart`
- [x] Build succeeds: `flutter analyze lib/features/study_progress test/features/study_progress`
- [x] Manual check: Kiểm tra edge case đổi streak từ 2 xuống 1

**Dependencies:** Task 2, Task 8

**Files likely touched:**
- `lib/features/study_progress/domain/models/progress_models.dart`
- `lib/features/study_progress/domain/repositories/study_progress_repository.dart`
- `lib/features/study_progress/domain/services/mastery_calculator.dart`
- `test/features/study_progress/mastery_and_weak_policy_test.dart`

**Estimated scope:** Medium (4 files)

---

## Task 10: `SqliteProgressRepository` & Snapshot Lịch Sử (`study-progress`)

**Description:** Cài đặt schema SQLite 4 bảng (`user_settings`, `question_progress`, `exam_attempts`, `exam_attempt_items`) và `SqliteProgressRepository` dùng transaction, lưu snapshot bài thi, quản lý bookmarks, và tương thích khi ngân hàng câu hỏi cập nhật.

**Acceptance criteria:**
- [x] Lưu và đọc lại đầy đủ lịch sử thi thử kèm 70 câu snapshot (sắp xếp mới nhất trước).
- [x] Khi thay `QuestionBank` mới xoá vài câu cũ và thêm câu mới, bài thi lịch sử cũ vẫn xem lại nguyên vẹn, hàng đợi câu yếu lọc an toàn câu đã xoá, câu trùng mã giữ nguyên tiến độ.
- [x] `resetAllProgress()` xoá sạch dữ liệu tiến độ trong 1 transaction mà không chạm tới `active_bank.bex`.

**Verification:**
- [x] Tests pass: `flutter test test/features/study_progress/`
- [x] Build succeeds: `flutter analyze lib/features/study_progress test/features/study_progress`
- [x] Manual check: Chạy test qua `sqflite_common_ffi` ngay trên macOS

**Dependencies:** Task 9

**Files likely touched:**
- `lib/features/study_progress/data/sqlite_progress_schema.dart`
- `lib/features/study_progress/data/sqlite_progress_repository.dart`
- `test/features/study_progress/sqlite_progress_repository_test.dart`

**Estimated scope:** Medium (3 files)

---

## Checkpoint: After Tasks 9-10 (Core Modules Complete)
- [x] `flutter test test/features/data_vault test/features/exam_engine test/features/study_progress` pass 100%
- [x] Toàn bộ logic nghiệp vụ chạy không cần giao diện đã xác minh xong

---

## Task 11: Theme Xanh Nhạt, DI & Trang Chủ (`mobile-ui`)

**Description:** Xây dựng `AppTheme` (tone xanh dương nhạt `#F0F9FF`, `#E0F2FE`, `#0284C7`, chữ `#0F172A`, icon hiện đại), `AppDependencies`, `HomeShell` (4 tab), `HomeTab` (vào thẳng không login: Chỉ số sẵn sàng, nút Thi thử, Ôn 13 chuyên đề, Phục thù câu sai, Mini-test 26 câu) và `TopicMasteryGrid`.

**Acceptance criteria:**
- [x] Mở app vào thẳng `HomeTab` không có bước đăng nhập hay wizard ép buộc.
- [x] Tone màu xanh nhạt & icon hiện đại đồng nhất; vùng chạm các thẻ/nút >= `48dp`, không overflow.
- [x] Chạm vào chuyên đề trên `TopicMasteryGrid` điều hướng thẳng tới luồng ôn chuyên đề đó.

**Verification:**
- [x] Tests pass: `flutter analyze lib/app lib/features/mobile_ui`
- [x] Build succeeds: `flutter test`
- [x] Manual check: Soát màu hex và cấu trúc 4 tab theo `SPEC-mobile-ui.md`

**Dependencies:** Task 4, Task 8, Task 10

**Files likely touched:**
- `lib/app/theme/app_theme.dart`
- `lib/app/di/app_dependencies.dart`
- `lib/features/mobile_ui/screens/home_shell.dart`
- `lib/features/mobile_ui/screens/home_tab.dart`
- `lib/features/mobile_ui/widgets/topic_mastery_grid.dart`

**Estimated scope:** Medium (5 files)

---

## Task 12: Luồng Ôn Thi, Chọn Danh Sách & Đối Chiếu Cụm Cùng Điểm (`mobile-ui`)

**Description:** Xây dựng màn hình `StudyTab` (chọn 1/nhiều chuyên đề, Phục thù câu sai, Bookmarks, Chọn thủ công), `ManualPickerScreen` (tìm kiếm + tích chọn từ danh sách), `StudySessionScreen` (chuyển đổi *Từng câu* ↔ *Nhiều câu*, bật/tắt đảo câu/đáp án, mở giải thích), `PointGroupSheet` ("Xem các câu cùng điểm kiến thức"), và `QuestionCard`.

**Acceptance criteria:**
- [x] Hỗ trợ đầy đủ cả ôn theo chuyên đề (1 hoặc nhiều), câu yếu, câu đánh dấu sao, và danh sách tích chọn thủ công.
- [x] Chuyển qua lại giữa chế độ xem *Từng câu* và *Danh sách nhiều câu* giữ nguyên tiến độ trả lời hiện tại.
- [x] Khi `pointGroupKey != null`, nút *"Xem các câu cùng điểm kiến thức"* mở BottomSheet hiển thị các câu cùng nhóm để đối chiếu ngay.

**Verification:**
- [x] Tests pass: `flutter analyze lib/features/mobile_ui`
- [x] Build succeeds: `flutter test`
- [x] Manual check: Kiểm tra ẩn nút "cùng điểm kiến thức" khi câu không thuộc nhóm nào

**Dependencies:** Task 11

**Files likely touched:**
- `lib/features/mobile_ui/screens/study_tab.dart`
- `lib/features/mobile_ui/screens/manual_picker_screen.dart`
- `lib/features/mobile_ui/screens/study_session_screen.dart`
- `lib/features/mobile_ui/widgets/point_group_sheet.dart`
- `lib/features/mobile_ui/widgets/question_card.dart`

**Estimated scope:** Medium (5 files)

---

## Task 13: Luồng Thi Thử Đếm Ngược & Màn Hình Kết Quả (`mobile-ui`)

**Description:** Xây dựng `MockExamController` (đồng hồ đếm ngược, auto-submit idempotent khi về 0, quản lý lựa chọn & gắn cờ xem lại), `MockExamScreen` (2 chế độ *Từng câu* ↔ *Toàn bộ đề*, chặn Back thoát nhầm, nhắc số câu chưa trả lời trước khi nộp), `QuestionNavigatorSheet` (lưới 70 câu), `CountdownBadge`, và `ExamResultScreen` (thang 100, breakdown 13 chuyên đề, xem lại giải thích từng câu, nút Luyện lại riêng các câu vừa sai).

**Acceptance criteria:**
- [x] Hết giờ tự động nộp bài đúng 1 lần và chuyển sang `ExamResultScreen`.
- [x] Bấm Nộp thủ công khi còn câu chưa trả lời hiện cảnh báo chính xác số câu chưa làm + nhảy tới câu bỏ trống đầu tiên.
- [x] `ExamResultScreen` chấm thang 100, lọc *Tất cả / Câu sai / Câu đúng*, và có nút *Luyện lại riêng các câu vừa sai*.

**Verification:**
- [x] Tests pass: `flutter analyze lib/features/mobile_ui`
- [x] Build succeeds: `flutter test`
- [x] Manual check: Kiểm tra đồng hồ đổi màu cảnh báo khi còn < 5 phút và < 1 phút

**Dependencies:** Task 12

**Files likely touched:**
- `lib/features/mobile_ui/controllers/mock_exam_controller.dart`
- `lib/features/mobile_ui/screens/mock_exam_screen.dart`
- `lib/features/mobile_ui/widgets/question_navigator_sheet.dart`
- `lib/features/mobile_ui/screens/exam_result_screen.dart`
- `lib/features/mobile_ui/widgets/countdown_badge.dart`

**Estimated scope:** Medium (5 files)

---

## Task 14: Luồng Lịch Sử, Cài Đặt Ngưỡng & Upload File Cập Nhật (`mobile-ui`)

**Description:** Hoàn thiện `AppStateController` điều phối tải kho câu hỏi + tiến độ toàn app, `HistoryTab` (danh sách thi không giới hạn, chạm để mở `ExamResultScreen` từ snapshot), `SettingsTab` (tùy chỉnh điểm Đạt, streak phục thù, thời gian thi, mini-test, upload `.bex`/`.xlsx` qua `file_picker` + hiển thị lỗi dòng chi tiết nếu file sai, khôi phục gốc, đặt lại tiến độ), và `main.dart`.

**Acceptance criteria:**
- [x] `HistoryTab` hiển thị mọi lượt thi thử/mini-test và xem lại được chi tiết từng câu từ snapshot.
- [x] `SettingsTab` lưu ngay các ngưỡng mới vào SQLite và cập nhật lại Bản đồ năng lực / Hàng đợi yếu trên Trang chủ.
- [x] Upload file `.xlsx`/`.bex` hợp lệ cập nhật ngay kho câu hỏi hiện hành; file sai định dạng hiện bảng lỗi dòng rõ ràng và giữ nguyên dữ liệu cũ.

**Verification:**
- [x] Tests pass: `flutter analyze`
- [x] Build succeeds: `flutter test`
- [x] Manual check: Kiểm tra `main.dart` khởi tạo an toàn và xử lý lỗi khởi động sạch sẽ

**Dependencies:** Task 13

**Files likely touched:**
- `lib/features/mobile_ui/controllers/app_state_controller.dart`
- `lib/features/mobile_ui/screens/history_tab.dart`
- `lib/features/mobile_ui/screens/settings_tab.dart`
- `lib/main.dart`

**Estimated scope:** Medium (4 files)

---

## Task 15: Widget & Controller Tests cho `mobile-ui`

**Description:** Viết bộ widget & controller tests bao phủ các kịch bản giao diện trọng yếu: `MockExamController` (auto-submit hết giờ, đổi chế độ xem, đếm câu chưa làm), `MockExamScreen` (cảnh báo câu chưa làm, nhảy câu), `StudySessionScreen` (xem cụm cùng điểm, giải thích), và `SettingsTab` (chỉnh ngưỡng, hiện lỗi import Excel).

**Acceptance criteria:**
- [x] Toàn bộ 4 file widget/controller test pass 100%.
- [x] Kiểm tra được hành vi tự nộp bài hết giờ, nhắc câu chưa trả lời, hiển thị BottomSheet cùng điểm kiến thức, và hiển thị lỗi dòng Excel.

**Verification:**
- [x] Tests pass: `flutter test test/features/mobile_ui/`
- [x] Build succeeds: `flutter analyze`
- [x] Manual check: Không có test nào bị skip hoặc tắt assertion

**Dependencies:** Task 14

**Files likely touched:**
- `test/features/mobile_ui/mock_exam_controller_test.dart`
- `test/features/mobile_ui/mock_exam_screen_test.dart`
- `test/features/mobile_ui/study_session_screen_test.dart`
- `test/features/mobile_ui/settings_tab_test.dart`

**Estimated scope:** Medium (4 files)

---

## Checkpoint: After Tasks 11-15 (Final Verification & APK Release)
- [x] Nạp file Excel 430 câu thật bằng `dart run tool/pack_bex.dart` -> kiểm tra 0 lỗi dòng, 0 xung đột nhóm cùng điểm, cập nhật `assets/vault/default_bank.bex`
- [x] `flutter test` toàn dự án pass 100%
- [x] `flutter analyze` sạch warning/error
- [x] Build Android APK release: `flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols`
- [x] Giải nén file `.apk` thành phẩm kiểm tra xác nhận không tồn tại file `.xlsx`/`.json` thô trong `assets/`
