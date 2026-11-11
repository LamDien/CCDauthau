# Spec: `mobile-ui` — Giao Diện Flutter, Luồng Ôn Thi, Thi Thử & Đóng Gói APK

> **Module ID:** `mobile-ui` (theo [CAPABILITY_MAP.md](CAPABILITY_MAP.md))  
> **Phụ thuộc:** [`data-vault`](SPEC-data-vault.md), [`exam-engine`](SPEC-exam-engine.md), [`study-progress`](SPEC-study-progress.md)

---

## Assumptions
1. Ứng dụng nhắm mục tiêu ưu tiên **Android APK** (Android 8.0 / API 26 trở lên), nhưng code giao diện viết bằng Flutter Material 3 thuần để sau này có thể build cho iOS nếu cần.
2. Không có màn hình đăng nhập/đăng ký; mở app là nạp `QuestionBank` và vào thẳng **Trang chủ (`HomeScreen`)** trong `< 1.5s`.
3. Toàn bộ logic nghiệp vụ (mã hoá, xếp đề, tính màu chuyên đề, lưu lịch sử) nằm trong 3 module dưới; `mobile-ui` chỉ điều phối state (ví dụ `ChangeNotifier` / `Provider` hoặc `Riverpod` nhẹ — ưu tiên `ChangeNotifier` / `ValueNotifier` chuẩn hoặc `provider` ít boilerplate) và render giao diện.
4. Tone chủ đạo là **Xanh dương nhạt hiện đại (Light Sky Blue)** trên nền sáng sạch sẽ, chữ tương phản cao dễ đọc văn bản pháp quy dài, kết hợp bộ icon hiện đại (`lucide_icons_flutter` hoặc Material Symbols Rounded).

---

## Objective
Xây dựng toàn bộ giao diện người dùng và luồng điều hướng mượt mà cho kỳ thi Chứng chỉ Đấu thầu Bộ Tài chính:
- **Trang chủ (`HomeTab`):** Nút vào thẳng **Thi thử 70 câu**, **Ôn 13 chuyên đề**, **Phục thù câu sai**, **Mini-test chẩn đoán**, cùng **Chỉ số sẵn sàng** & **Bản đồ năng lực 13 chuyên đề**.
- **Luồng Ôn thi (`StudyTab` & `StudySessionScreen`):** Chọn chuyên đề, làm từng câu hoặc danh sách nhiều câu, chọn từ danh sách câu hỏi / câu đánh dấu / câu sai, xem đáp án + căn cứ pháp lý + **cụm các câu cùng điểm kiến thức**.
- **Luồng Thi thử (`MockExamScreen` & `ExamResultScreen`):** Đồng hồ đếm ngược tự nộp bài, 2 chế độ xem (*Từng câu* & *Toàn bộ đề*), bảng nhảy 70 câu, nhắc câu chưa trả lời trước khi nộp, chấm thang 100, xem đáp án + giải thích sau nộp, và luyện lại ngay riêng các câu vừa sai.
- **Luồng Lịch sử (`HistoryTab`) & Cài đặt/Cập nhật (`SettingsTab`):** Xem lại toàn bộ bài thi cũ, chỉnh ngưỡng cá nhân (điểm Đạt, số lần phục thù, thời gian thi, mini-test), upload file `.bex`/`.xlsx` cập nhật ngân hàng câu hỏi, khôi phục dữ liệu gốc hoặc đặt lại tiến độ.

### User Stories & Acceptance Criteria
1. **Hệ thống màu sắc & giao diện xanh nhạt hiện đại:**
   - Nền tổng thể `#F0F9FF`, thẻ câu hỏi `#FFFFFF` bo góc `16px` viền mảnh `#BAE6FD`, màu nhấn chính `#0284C7`, bề mặt phụ `#E0F2FE`, chữ chính `#0F172A`, chữ phụ `#475569`.
   - Mọi nút lựa chọn phương án A/B/C/D có chiều cao chạm tối thiểu `48dp`, giãn cách rõ ràng, đọc thoải mái trên màn hình điện thoại 5.5"–6.7".
2. **Trang chủ mở thẳng không rào cản:**
   - Hiển thị **Chỉ số sẵn sàng** (số câu đã nắm / tổng câu ngân hàng hiện tại, điểm thi thử gần nhất), 2 nút hành động lớn (**Thi thử 70 câu**, **Ôn 13 chuyên đề**), thẻ **Phục thù câu sai (`N` câu)**, nút tùy chọn **Mini-test chẩn đoán (`26` câu)**, và **Bản đồ 13 chuyên đề** tô màu Xám / Đỏ / Vàng / Xanh (bấm vào từng chuyên đề nhảy thẳng vào ôn chuyên đề đó).
3. **Chế độ Ôn thi đa dạng:**
   - Lựa chọn nguồn bài ôn:
     - **Theo chuyên đề:** Chọn 1 chuyên đề (hoặc gộp nhiều chuyên đề).
     - **Phục thù câu sai:** Ôn các câu đang mang cờ yếu.
     - **Danh sách tự chọn (Bookmarks):** Ôn các câu đã gắn dấu sao.
     - **Chọn thủ công từ danh sách:** Tìm kiếm theo từ khóa/mã câu hoặc tích chọn nhiều câu bất kỳ để tạo bài ôn.
   - Trong phiên ôn tập: chuyển đổi tức thì giữa **Từng câu** và **Nhiều câu (Danh sách cuộn)**; bật/tắt tùy chọn **Đảo thứ tự câu & đáp án**; bấm chọn đáp án hiện ngay Đúng/Sai kèm **Giải thích / Căn cứ pháp lý**; nếu câu thuộc một `Nhom_Cung_Diem`, hiện nút **"Xem các câu cùng điểm kiến thức (X câu)"** mở BottomSheet đối chiếu trực tiếp ngay tại chỗ.
4. **Chế độ Thi thử chuẩn (70 câu / 60 phút hoặc theo Setting):**
   - Top bar cố định: Đồng hồ đếm ngược (`MM:SS`, đổi cam khi còn `< 5 phút`, đỏ nhấp nháy nhẹ khi `< 1 phút`), nút chuyển đổi **Từng câu ↔ Toàn bộ đề**, nút **Danh sách câu (`X/70`)**, nút **Nộp bài**.
   - **Tự động nộp bài** khi đồng hồ về `00:00` (`autoSubmittedByTimeout = true`), thông báo nhẹ và chuyển ngay sang màn hình Kết quả.
   - **Bảng danh sách câu (`QuestionNavigatorSheet`):** Hiển thị 70 ô đánh số trạng thái (*Đã làm* / *Chưa làm* / *Đánh dấu xem lại* / *Đang đứng*), chạm nhảy thẳng tới câu đó (cuộn tới đúng vị trí khi ở chế độ *Toàn bộ đề*).
   - **Cảnh báo trước khi nộp thủ công:** Nếu còn câu chưa trả lời (hoặc câu đánh dấu xem lại), hiện hộp thoại nhắc số lượng cụ thể kèm nút *"Kiểm tra câu chưa làm đầu tiên"* và *"Nộp bài ngay"*.
   - **Chặn thoát nhầm (`PopScope`):** Hỏi xác nhận nếu bấm nút Back khi đang thi.
5. **Màn hình Kết quả & Lịch sử:**
   - Hiển thị điểm thang **100** (ví dụ `78.57 / 100 điểm`), huy hiệu xếp loại 5 mức (**Xuất sắc** >= 90%, **Giỏi** 80%–<90%, **Khá** 60%–<80%, **Trung bình** 50%–<60%, **Không đạt yêu cầu** < 50%) cùng bảng quy đổi xếp loại cho **Thi thử** và **Mini-test** (chế độ *Luyện lại câu sai* chỉ hiện điểm & số câu đúng/sai), số câu đúng / sai / bỏ trống, bảng phân tích từng chuyên đề trong 13 chuyên đề.
   - Nút nổi bật **"Luyện lại riêng các câu vừa sai (`M` câu)"** (chỉ hiện nếu `M > 0`).
   - Danh sách xem lại từng câu kèm lọc (*Tất cả* / *Chỉ câu sai* / *Chỉ câu đúng*), hiện đáp án bạn chọn vs đáp án đúng + căn cứ pháp lý + nút xem cụm cùng điểm (nếu có trong kho hiện tại).
6. **Cài đặt & Upload file cập nhật ngân hàng câu hỏi:**
   - Điều chỉnh: Mục tiêu nắm vững chuyên đề (`50%..95%`, bước `5%`), Số lần đúng gỡ cờ yếu (`1..5`), Thời gian thi thử (`30 / 45 / 60 / 90 phút`), Số câu/chuyên đề Mini-test (`1` hoặc `2`).
   - Phần **Ngân hàng câu hỏi**: Xem phiên bản & số câu hiện tại, nút **"Cập nhật từ file (.bex / .xlsx)"** mở trình chọn file hệ thống -> validate -> hiển thị hộp thoại xác nhận số câu/chuyên đề mới trước khi thay thế an toàn, hoặc liệt kê rõ lỗi dòng nếu file Excel sai; nút **"Khôi phục bộ câu hỏi mặc định"**.

---

## Navigation & Screen Map
```text
HomeShell (BottomNavigationBar: Trang chủ | Ôn thi | Lịch sử | Cài đặt)
 ├── HomeTab
 │    ├── -> MockExamScreen (Thi thử 70 câu) -> ExamResultScreen -> StudySessionScreen (Luyện lại câu sai)
 │    ├── -> MockExamScreen (Mini-test 26 câu) -> ExamResultScreen
 │    └── -> StudySessionScreen (Chạm chuyên đề từ Bản đồ năng lực / Thẻ Phục thù)
 ├── StudyTab (Chọn chuyên đề / Phục thù / Bookmarks / Chọn thủ công từ danh sách)
 │    └── -> StudySessionScreen (Từng câu <-> Nhiều câu + BottomSheet "Cùng điểm kiến thức")
 ├── HistoryTab (Danh sách lịch sử không giới hạn)
 │    └── -> ExamResultScreen (Xem lại bài thi cũ từ snapshot)
 └── SettingsTab (Ngưỡng điểm Đạt, Streak phục thù, Thời gian thi, Upload .bex/.xlsx, Reset)
```

---

## Tech Stack
- **Framework:** Flutter `3.47.7` / Dart `3.13.5` (Material 3)
- **Icons:** `lucide_icons_flutter` (hoặc Material Symbols)
- **File Picker (Upload `.bex`/`.xlsx`):** `file_picker`
- **Build & Bảo vệ APK Release:**
  - Ký bằng release keystore cố định (`android/key.properties` không commit lên git) để cài đè bản cập nhật giữ nguyên SQLite & `active_bank.bex`.
  - ProGuard/R8 (`isMinifyEnabled = true`, `isShrinkResources = true`) + Flutter `--obfuscate --split-debug-info`.

---

## Commands
```bash
# Chạy toàn bộ widget tests của module mobile-ui
flutter test test/features/mobile_ui/

# Chạy toàn bộ test suite toàn dự án
flutter test

# Kiểm tra phân tích tĩnh toàn bộ codebase
flutter analyze

# Build Android APK release (khi có Android SDK và release keystore)
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

---

## Project Structure
```text
lib/
  main.dart
  app/
    theme/                # AppTheme (bảng màu xanh nhạt, typography, card/button styles)
    di/                   # Khởi tạo & tiêm 3 repository/service (Vault, ExamEngine, StudyProgress)
  features/
    mobile_ui/
      controllers/        # HomeController, StudySessionController, MockExamController, SettingsController
      screens/
        home_shell.dart
        home_tab.dart
        study_tab.dart
        manual_picker_screen.dart
        study_session_screen.dart
        mock_exam_screen.dart
        exam_result_screen.dart
        history_tab.dart
        settings_tab.dart
      widgets/
        question_card.dart
        question_navigator_sheet.dart
        point_group_sheet.dart
        topic_mastery_grid.dart
        countdown_badge.dart
test/
  features/
    mobile_ui/            # Widget tests cho Home, Study (xem cụm cùng điểm), MockExam (đếm ngược tự nộp, 2 chế độ xem, nhắc câu chưa làm), Settings/Upload
```

---

## Code Style
Tách logic điều phối màn hình vào `ChangeNotifier` controller để test được cả widget lẫn luồng trạng thái mà không nhét nghiệp vụ vào `build()`:

```dart
class MockExamController extends ChangeNotifier {
  MockExamController({
    required this.exam,
    required ExamEngine engine,
    required StudyProgressRepository progressRepo,
    required double passScoreThreshold,
  })  : _engine = engine,
        _progressRepo = progressRepo,
        _passScoreThreshold = passScoreThreshold,
        remainingSeconds = exam.durationSeconds;

  final GeneratedExam exam;
  final ExamEngine _engine;
  final StudyProgressRepository _progressRepo;
  final double _passScoreThreshold;

  int remainingSeconds;
  bool isSingleQuestionView = true;
  int currentIndex = 0;
  final Map<int, int> selectedByPosition = {};
  final Set<int> flaggedPositions = {};

  int get unansweredCount => exam.items.length - selectedByPosition.length;
}
```

---

## Testing Strategy
- **Widget & Controller tests (`flutter test test/features/mobile_ui/`):**
  1. `mock_exam_controller_test.dart`: Đồng hồ đếm ngược chạm `0` kích hoạt tự động nộp bài đúng 1 lần (`autoSubmittedByTimeout == true`) và gọi `recordExamEvaluation`; chuyển qua lại 2 chế độ xem vẫn giữ nguyên đáp án đã chọn; đếm chính xác `unansweredCount`.
  2. `mock_exam_screen_test.dart`: Kiểm tra bấm **Nộp bài** khi còn câu chưa trả lời hiện hộp thoại nhắc chính xác số câu chưa làm; kiểm tra mở bảng nhảy 70 câu chuyển đúng tới câu được bấm.
  3. `study_session_screen_test.dart`: Kiểm tra chuyển chế độ *Từng câu* ↔ *Danh sách nhiều câu*; hiện giải thích + nút *"Xem các câu cùng điểm kiến thức"* khi `pointGroupKey != null` và ẩn nút đó khi câu độc lập.
  4. `settings_tab_test.dart`: Kiểm tra chỉnh điểm Đạt / streak phục thù lưu qua `StudyProgressRepository`; hiển thị danh sách lỗi dòng rõ ràng khi mock `VaultRepository.importFromBytes` trả về `ExcelValidationFailure`.

---

## Boundaries
- **Always:**
  - Dùng `SafeArea`, cuộn mượt cho text câu hỏi/giải thích dài để không bao giờ bị lỗi tràn màn hình (`RenderFlex overflow`).
  - Vô hiệu hoá tương tác đáp án sau khi hết giờ và không bao giờ gọi nộp bài 2 lần (idempotent submit guard).
  - Kiểm tra `mounted` trước mọi `Navigator` / `showDialog` sau lệnh `await`.
- **Ask first:**
  - Thêm package UI bên thứ ba nặng hoặc quyền Android mới ngoài trình chọn file chuẩn (Storage Access Framework qua `file_picker` không cần xin quyền đọc toàn bộ bộ nhớ kiểu cũ).
  - Thay đổi tên `applicationId` Android sau khi đã chia sẻ APK (sẽ làm mất dữ liệu khi cài đè).
- **Never:**
  - Đặt thuật toán chia tỷ lệ, tách nhóm cùng điểm hoặc logic mã hoá AES trực tiếp vào trong widget UI.
  - Bắt buộc người dùng đăng nhập hoặc làm bài test chẩn đoán mới cho vào app.
  - Gọi internet/analytics ngầm — app phải 100% offline, không xin quyền `INTERNET` trừ khi có lý do được duyệt.

---

## Success Criteria
1. `flutter test` và `flutter analyze` đạt 100% pass, 0 error/warning trên toàn bộ 4 module (`data-vault`, `exam-engine`, `study-progress`, `mobile-ui`).
2. Toàn bộ luồng chính (Mở app không login -> Ôn chuyên đề / Phục thù / Danh sách tự chọn / Xem cụm cùng điểm -> Thi thử 70 câu 2 chế độ xem, nhảy câu, nhắc câu chưa làm, tự nộp khi hết giờ -> Xem lại kết quả & lịch sử -> Setting & Upload file cập nhật) hoạt động trơn tru trên giao diện xanh nhạt hiện đại.
3. Build được Android APK release có bật R8/ProGuard + `--obfuscate` (khi Android SDK & keystore sẵn sàng).

---

## Open Questions
- Đã chốt toàn bộ:
  - **Tên ứng dụng:** `CC Đấu Thầu`
  - **Android `applicationId`:** `vn.ccdauthau.luyenthi`
  - **Dữ liệu kiểm thử & đóng gói:** Người dùng sẽ chép file Excel 430 câu thật vào thư mục dự án ở bước tiếp theo để kiểm chứng thực tế & đóng gói `assets/vault/default_bank.bex`.
