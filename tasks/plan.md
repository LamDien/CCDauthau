# Implementation Plan: Ứng Dụng CC Đấu Thầu (`vn.ccdauthau.luyenthi`)

## Overview
Xây dựng ứng dụng Android offline (**CC Đấu Thầu**, `applicationId: vn.ccdauthau.luyenthi`) bằng Flutter (`3.47.7`) / Dart (`3.13.5`) giúp ôn tập và thi thử Chứng chỉ Đấu thầu dựa trên ngân hàng 430 câu hỏi qua 13 chuyên đề. Kiến trúc chia thành 4 module tách biệt theo [CAPABILITY_MAP.md](../CAPABILITY_MAP.md): kho dữ liệu mã hoá AES-256-GCM và nhập Excel (`data-vault`), thuật toán xếp đề 70 câu phần dư lớn nhất & tách nhóm cùng một điểm (`exam-engine`), lưu lịch sử/bản đồ năng lực/phục thù câu sai trên SQLite riêng biệt (`study-progress`), và giao diện Flutter tone xanh nhạt hiện đại (`mobile-ui`).

## Architecture Decisions
1. **Kho dữ liệu `.bex` (AES-256-GCM + Gzip Canonical JSON) bằng Dart thuần:**
   - *Lý do:* Bảo vệ ngân hàng câu hỏi khỏi việc giải nén file `.apk` đọc văn bản thuần, hỗ trợ cả đóng gói sẵn (`assets/vault/default_bank.bex`) lẫn upload file `.bex`/`.xlsx` cập nhật ngay trong app theo nguyên tắc Fail-Closed & Atomic Swap, đồng thời chạy được 100% unit test trên macOS không cần emulator Android.
2. **Tách đôi lưu trữ câu hỏi (`active_bank.bex`) và tiến độ học (`study_progress.db`):**
   - *Lý do:* Upload file ngân hàng câu hỏi mới không bao giờ xoá hoặc làm lệch lịch sử thi cũ. Các lượt thi cũ lưu snapshot câu hỏi & phương án hiển thị nên xem lại nguyên vẹn bất kể bộ câu hỏi có thay đổi về sau.
3. **Thuật toán xếp đề MRV + Randomized Backtracking trên nền Largest Remainder:**
   - *Lý do:* Ngăn lỗi kẹt ràng buộc khi một `Nhom_Cung_Diem` nằm vắt ngang nhiều chuyên đề, đảm bảo 100% không trùng điểm kiến thức trong đề 70 câu, xáo trộn toàn đề và đảo 4 phương án A–D mỗi lượt.
4. **Hợp đồng 9 cột Excel gốc + cột tùy chọn mở rộng:**
   - *Lý do:* Tương thích trực tiếp file Excel hiện có của tác giả (`STT`, `Phân loại chuyên đề`, `Câu hỏi`, `Phương án A–D`, `Đáp án đúng`, `Căn cứ pháp lý`), tự sinh `Ma_Cau_Hoi` ổn định nếu chưa có cột `Mã câu hỏi`, và hỗ trợ bổ sung cột `Nhóm cùng điểm` / `Giải thích` bất kỳ lúc nào.
5. **Tắt hoàn toàn quyền mạng & ẩn tên file dữ liệu thô:**
   - *Lý do:* App 100% offline không cần `INTERNET` permission; build APK release bật R8/ProGuard và `--obfuscate --split-debug-info`.

## Dependency Graph & Build Order
```text
data-vault (Tasks 1-5)
    │
    ├──► exam-engine (Tasks 6-8)
    │         │
    └─────────┴──► study-progress (Tasks 9-10)
                        │
                        └──► mobile-ui (Tasks 11-15)
```

## Task List Summary
Chi tiết từng task, acceptance criteria, tệp liên quan và lệnh kiểm chứng nằm tại [tasks/todo.md](todo.md).

### Phase 1: Khởi tạo Flutter & Module `data-vault`
- [x] Task 1: Khởi tạo dự án Flutter (`CC Đấu Thầu`, `vn.ccdauthau.luyenthi`) và cấu hình Android release/dependencies
- [x] Task 2: Định nghĩa Domain Models, `VaultResult` và `PointGroupNormalizer` của `data-vault`
- [x] Task 3: Xây dựng `ExcelQuestionParser` hỗ trợ 9 cột gốc + validation đủ 13 chuyên đề & >= 70 câu
- [x] Task 4: Xây dựng `BexCodec` (AES-256-GCM) và `FileVaultRepository` (Atomic Swap + Reset mặc định)
- [x] Task 5: Xây dựng CLI packer `tool/pack_bex.dart` và tạo bộ dữ liệu đóng gói mẫu ban đầu
- **Checkpoint 1:** `flutter test test/features/data_vault/` & `flutter analyze` pass 100%

### Phase 2: Module `exam-engine`
- [x] Task 6: Định nghĩa Models & `LargestRemainderAllocator` phân bổ động 70 câu trên 13 chuyên đề
- [x] Task 7: Xây dựng `ConstrainedQuestionSelector` (MRV + Backtracking) và `AnswerShuffler`
- [x] Task 8: Xây dựng `ExamGrader`, `ExamEngine` và test Monte Carlo 10.000 lượt sinh đề
- **Checkpoint 2:** `flutter test test/features/exam_engine/` pass 100%, 0 vi phạm `Nhom_Cung_Diem`

### Phase 3: Module `study-progress`
- [x] Task 9: Định nghĩa Models, `MasteryCalculator` (Đỏ/Vàng/Xanh 13 chuyên đề) và chính sách Phục thù câu sai
- [x] Task 10: Triển khai `SqliteProgressRepository` (snapshot lịch sử, streak phục thù, bookmarks, cài đặt ngưỡng)
- **Checkpoint 3:** Toàn bộ unit & SQLite tests (`data_vault`, `exam_engine`, `study_progress`) pass 100%

### Phase 4: Module `mobile-ui` & Đóng gói APK
- [x] Task 11: Thiết lập `AppTheme` (tone xanh nhạt), DI, `HomeShell`, `HomeTab` & `TopicMasteryGrid`
- [x] Task 12: Luồng Ôn thi (`StudyTab`, `ManualPickerScreen`, `StudySessionScreen`, `PointGroupSheet`, `QuestionCard`)
- [x] Task 13: Luồng Thi thử & Kết quả (`MockExamController`, `MockExamScreen`, `QuestionNavigatorSheet`, `ExamResultScreen`)
- [x] Task 14: Luồng Lịch sử, Cài đặt & Upload file cập nhật (`HistoryTab`, `SettingsTab`, `AppStateController`, `main.dart`)
- [x] Task 15: Widget & Controller tests cho `mobile-ui`
- **Checkpoint 4:** Nạp file Excel 430 câu thật qua `tool/pack_bex.dart`, chạy toàn bộ `flutter test`, `flutter analyze`, và build APK release `--obfuscate`

## Risks and Mitigations
| Risk | Impact | Mitigation |
|---|---|---|
| Trong file Excel 430 câu thật, một chuyên đề ít câu lại có nhiều câu trùng `Nhóm cùng điểm` khiến không đủ quota 70 câu | High | Kiểm tra ngay khi chạy `tool/pack_bex.dart` và `ExcelQuestionParser` (báo cụ thể chuyên đề/nhóm xung đột trước khi đóng gói APK) |
| Môi trường sandbox chặn `flutter pub get` / tải Gradle & kiểm tra Android SDK ngoài thư mục workspace | Med | Xin phép chạy các bước tải gói / kiểm tra Android SDK với quyền phù hợp ở bước Task 1 và Checkpoint 4; toàn bộ unit test Dart chạy thuần trong sandbox |
| Người dùng sửa tên chuyên đề hoặc thứ tự dòng ở lần update Excel sau làm mất định danh câu | Med | Cho phép thêm cột `Mã câu hỏi` cố định; nếu chưa có thì sinh mã theo `CD<order>_<STT>` ổn định, và giữ snapshot độc lập cho lịch sử cũ |
| Khối lượng widget màn hình thi thử & ôn thi dễ bị tràn hoặc gọi nộp bài 2 lần khi hết giờ | Med | Tách logic đếm ngược vào `MockExamController` có cờ idempotent `isSubmitted` và viết widget test phủ đủ case |

## Open Questions
- Không còn điểm mở chặn triển khai; chờ bạn xác nhận kế hoạch để bắt đầu từ **Task 1** (và bạn có thể chép file Excel 430 câu thật vào thư mục dự án bất cứ lúc nào từ Task 1 hoặc trước Checkpoint 4).

