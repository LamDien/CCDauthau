# Spec: `data-vault` — Kho Dữ Liệu Mã Hoá, Chuẩn Excel & Cập Nhật Ngân Hàng Câu Hỏi

> **Module ID:** `data-vault` (theo [CAPABILITY_MAP.md](CAPABILITY_MAP.md))  
> **Phụ thuộc:** Không (`—`)  
> **Module tiêu thụ hợp đồng dữ liệu:** `exam-engine`, `study-progress`, `mobile-ui`

---

## Assumptions
1. Toàn bộ 430 câu hỏi (và các bản cập nhật sau này) đều là câu hỏi trắc nghiệm **4 phương án A, B, C, D** với **1 đáp án đúng** duy nhất, chỉ chứa văn bản Unicode tiếng Việt trong V1.
2. File Excel hiện tại đang có sẵn 9 cột tiếng Việt: `STT`, `Phân loại chuyên đề`, `Câu hỏi`, `Phương án A`, `Phương án B`, `Phương án C`, `Phương án D`, `Đáp án đúng`, `Căn cứ pháp lý`. Trong đó:
   - Nếu chưa có cột `Mã câu hỏi`, hệ thống/CLI tool sẽ tự sinh `Ma_Cau_Hoi` ổn định (theo thứ tự hoặc hash chuẩn hoá từ chuyên đề + `STT`) và khuyến khích giữ cột `Mã câu hỏi` riêng nếu về sau muốn chèn/xóa dòng mà không lệch lịch sử.
   - Cột `Nhóm cùng điểm` là cột tùy chọn (có thể bổ sung vào Excel bất cứ lúc nào); nếu chưa có cột này, hệ thống coi các câu độc lập với nhau; nếu có, mọi câu có cùng chuỗi giá trị sau chuẩn hoá ở cột này là **cùng một điểm kiến thức**.
   - Cột `Giải thích` là tùy chọn bổ sung; nếu không có riêng cột `Giải thích`, nội dung từ `Căn cứ pháp lý` sẽ được hiển thị làm phần căn cứ/giải thích đáp án.
3. Mọi file ngân hàng câu hỏi nạp mới (`.xlsx` hoặc `.bex`) đều **bắt buộc phải có đủ 13 chuyên đề và tối thiểu 70 câu hợp lệ**; nếu thiếu sẽ từ chối nạp và giữ nguyên kho dữ liệu cũ.
4. Gói dữ liệu phân phối mặc định trong APK (`default_bank.bex`) và gói cập nhật (`.bex`) sử dụng định dạng nhị phân mã hoá **AES-256-GCM** thống nhất, cho phép đọc/kiểm thử hoàn toàn bằng Dart thuần trên macOS mà không cần giả lập Android.
5. Dữ liệu tiến độ học & lịch sử của người dùng thuộc trách nhiệm của `study-progress`, lưu tách biệt khỏi file kho câu hỏi (`active_bank.bex`) để việc cập nhật ngân hàng câu hỏi không bao giờ ghi đè mất lịch sử.

---

## Objective
Xây dựng lớp lưu trữ, giải mã và nạp/cập nhật ngân hàng câu hỏi hoạt động 100% offline trên thiết bị di động:
- Bảo vệ ngân hàng câu hỏi khỏi việc giải nén file `.apk` để sao chép thô JSON/CSV/Excel.
- Chuẩn hoá cấu trúc file Excel (`.xlsx`) gồm 13 chuyên đề, đáp án, giải thích và nhóm `"cùng một điểm"`.
- Cho phép cập nhật dữ liệu mới ngay trong app bằng cách upload file `.bex` (khuyên dùng khi phát hành rộng rãi) hoặc file `.xlsx` theo đúng định dạng chuẩn, theo nguyên tắc **Fail-Closed & Atomic Swap** (lỗi định dạng thì từ chối an toàn, không làm hỏng dữ liệu đang dùng).
- Cung cấp hợp đồng dữ liệu bất biến (immutable models + typed errors) cho `exam-engine`, `study-progress`, và `mobile-ui`.

### User Stories & Acceptance Criteria
1. **Khởi động nạp kho câu hỏi mặc định:** Khi mở app lần đầu chưa từng cập nhật thủ công, `data-vault` giải mã `assets/vault/default_bank.bex` (hoặc bản đã nạp trong thư mục riêng tư của app nếu có) và trả về đối tượng `QuestionBank` hợp lệ trong `< 150ms` trên thiết bị Android tầm trung.
2. **Import/Upload file Excel (`.xlsx`) hợp lệ:** Khi người dùng chọn file `.xlsx` đúng mẫu, `data-vault` kiểm tra toàn bộ dòng dữ liệu ở biên, chuẩn hoá cột `Nhom_Cung_Diem`, mã hoá thành `.bex` và ghi nguyên tử vào `active_bank.bex` trong bộ nhớ riêng tư của app, sau đó trả về thống kê bản cập nhật (tổng số câu, số chuyên đề, tổng số nhóm cùng điểm).
3. **Import/Upload file gói mã hoá (`.bex`):** Khi người dùng chọn file `.bex` do CLI tool tạo ra, `data-vault` xác thực header (`BEX1`), thẻ xác thực AES-GCM và schema trước khi thay thế `active_bank.bex`.
4. **Từ chối file sai định dạng / bị chỉnh sửa:** Nếu file thiếu cột bắt buộc, trùng `Ma_Cau_Hoi`, đáp án đúng không hợp lệ, hoặc file `.bex` bị sửa byte/sai chữ ký, hệ thống trả về danh sách lỗi rõ số dòng (`ImportValidationException`) và giữ nguyên kho dữ liệu cũ 100%.
5. **Khôi phục về bộ câu hỏi gốc:** Cho phép người dùng đặt lại kho dữ liệu về bản mặc định đóng gói trong APK (`default_bank.bex`) nếu muốn hoàn tác sau khi upload nhầm file cá nhân.

---

## Data Contract & Schema

### 1. Quy chuẩn File Excel (`.xlsx`)
Đọc sheet đầu tiên (hoặc sheet tên `Questions` nếu có). Hàng 1 là tiêu đề cột (không phân biệt hoa/thường, hỗ trợ cả tên cột tiếng Việt có dấu như file gốc của bạn lẫn tên không dấu):

| Cột (tên trong Excel) | Bắt buộc | Quy tắc | Mô tả |
|---|---|---|---|
| `STT` | Có (hoặc `Mã câu hỏi`) | Số/chuỗi không rỗng, duy nhất | Số thứ tự gốc; nếu chưa có cột `Mã câu hỏi`, dùng làm cơ sở định danh câu hỏi |
| `Mã câu hỏi` | Không (khuyến khích) | Chuỗi không rỗng, duy nhất toàn file | Định danh ổn định xuyên suốt các lần update (nếu không có, tự tạo theo quy tắc `CD<topicOrder>_<STT>`) |
| `Phân loại chuyên đề` | Có | Chuỗi không rỗng, đúng **13 chuyên đề** phân biệt trong file | Tên chuyên đề (tự động sắp xếp thứ tự 1..13 theo số đầu dòng nếu có hoặc theo thứ tự xuất hiện) |
| `Câu hỏi` | Có | Chuỗi không rỗng | Nội dung câu hỏi |
| `Phương án A` | Có | Chuỗi không rỗng | Phương án A |
| `Phương án B` | Có | Chuỗi không rỗng | Phương án B |
| `Phương án C` | Có | Chuỗi không rỗng | Phương án C |
| `Phương án D` | Có | Chuỗi không rỗng | Phương án D |
| `Đáp án đúng` | Có | Một ký tự trong `A`, `B`, `C`, `D` (không phân biệt hoa/thường) | Đáp án đúng trước khi đảo |
| `Căn cứ pháp lý` | Không | Chuỗi | Trích dẫn Luật/Nghị định/Thông tư |
| `Giải thích` | Không | Chuỗi | Diễn giải chi tiết (nếu để trống và có `Căn cứ pháp lý`, hiển thị `Căn cứ pháp lý` làm giải thích) |
| `Nhóm cùng điểm` | Không | Chuỗi tự do | Các câu có cùng chuỗi sau chuẩn hoá (`trim`, gộp khoảng trắng, lowercase) được xem là **cùng một điểm kiến thức**; để trống = độc lập |

**Ràng buộc toàn cục khi validate file nạp mới (`.xlsx` hoặc `.bex`):**
- File phải có **đúng 13 chuyên đề** (`topics.length == 13`) và **tổng số câu hợp lệ $\ge 70$**. Nếu không đạt, từ chối nạp với mã lỗi rõ ràng (`INSUFFICIENT_TOPICS_OR_QUESTIONS`).

### 2. Định dạng gói mã hoá `.bex` (Binary Encrypted Exam Vault)
```text
+------------------+------------+--------------+-----------------------------+
| Magic (4 bytes)  | Ver (2 B)  | Nonce (12 B) | AES-256-GCM Ciphertext+Tag  |
| "BEX1"           | uint16 BE  | random 96bit | Gzip(Canonical JSON) + 16B  |
+------------------+------------+--------------+-----------------------------+
```
- **Payload bên trong (sau giải mã & giải nén gzip):** Canonical JSON UTF-8 gồm `schemaVersion`, `bankVersion`, `createdAtIso`, `topics[]`, `questions[]`.
- **Bảo vệ khoá trên APK:** Khoá AES-256 được tách mảnh/biến đổi qua nhiều hàm và hằng số trong mã nguồn Dart biên dịch AOT với `--obfuscate --split-debug-info` (không xuất hiện chuỗi khoá nguyên vẹn trong binary/assets), kết hợp ProGuard/R8 cho lớp Android.
- **Lưu ý ranh giới bảo mật:** Cơ chế này chặn việc giải nén `.apk` lấy file data sạch và chặn sửa đổi trái phép tệp `.bex` (nhờ GCM tag), nhưng không chống lại phân tích bộ nhớ tiến trình trên thiết bị đã root (đúng với phạm vi bảo mật đã chốt).

### 3. Hợp đồng Dart xuất cho `exam-engine`, `study-progress`, `mobile-ui`
- `QuestionBank`: `bankVersion`, `importedAt`, `sourceType` (`bundled` | `importedBex` | `importedExcel`), `topics` (`List<Topic>`), `questions` (`List<Question>`), `questionsById`, `questionsByPointGroup`.
- `Topic`: `id` (`int` hoặc `String`), `order` (`int`), `name` (`String`), `questionCount` (`int`).
- `Question`: `code` (`Ma_Cau_Hoi`), `topicId`, `stem`, `options` (`List<AnswerOption>` gồm nhãn gốc + text), `correctOriginalIndex` (`int`), `explanation` (`String`), `pointGroupKey` (`String?` — đã chuẩn hoá để so khớp), `pointGroupLabel` (`String?` — giữ nguyên chữ gốc để hiển thị), `legalReference` (`String?`).
- `VaultRepository` (abstract interface):
  - `Future<VaultResult<QuestionBank>> loadActiveBank()`
  - `Future<VaultResult<ImportSummary>> importFromBytes(Uint8List bytes, {required ImportFileType type})`
  - `Future<VaultResult<QuestionBank>> resetToBundledBank()`

---

## Tech Stack
- **Ngôn ngữ & SDK (đã kiểm tra trên máy):** Flutter `3.47.7` (stable) / Dart `3.13.5`
- **Mã hoá & Nén:** `cryptography` (AES-256-GCM thuần Dart + hỗ trợ tăng tốc nền tảng) hoặc `pointycastle`, `dart:io` `gzip`
- **Đọc Excel trong app & CLI:** `spreadsheet_decoder` hoặc `excel` (chỉ chọn thư viện hỗ trợ `.xlsx` thuần Dart chạy được cả trong `dart test` không phụ thuộc Flutter Engine nếu dùng cho CLI tool)
- **Lưu trữ file cục bộ (khi chạy trong Flutter app):** `path_provider` (`getApplicationSupportDirectory()` — thư mục nội bộ riêng tư của ứng dụng)
- **Kiểm thử:** `flutter_test` / `test`

---

## Commands
```bash
# Chạy toàn bộ unit test của module data-vault (trên máy phát triển)
flutter test test/features/data_vault/

# Kiểm tra phân tích tĩnh
flutter analyze lib/features/data_vault test/features/data_vault

# Đóng gói file Excel chuẩn thành gói .bex (tool CLI chạy bằng Dart)
dart run tool/pack_bex.dart --input path/to/ngan_hang.xlsx --output assets/vault/default_bank.bex --version 2026.1
```

---

## Project Structure
```text
lib/
  features/
    data_vault/
      domain/
        models/           # Question, Topic, QuestionBank, ImportSummary, VaultFailure
        repositories/     # VaultRepository interface
        services/         # ExcelQuestionParser, BexCodec, PointGroupNormalizer
      data/
        file_vault_repository.dart  # Atomic swap + lưu active_bank.bex / bundled asset fallback
tool/
  pack_bex.dart           # CLI tool chuyển Excel -> .bex (kèm kiểm tra lỗi dòng & thống kê 13 chuyên đề)
assets/
  vault/
    default_bank.bex      # Ngân hàng câu hỏi mặc định đóng gói trong APK
test/
  features/
    data_vault/           # Unit tests parser Excel, validation, BexCodec AES-GCM, atomic swap
```

---

## Code Style
Dùng immutable value objects, sealed `VaultResult<T>` thay cho throw exception không kiểm soát qua ranh giới module, và chỉ validate ở ranh giới nhập file:

```dart
sealed class VaultResult<T> {
  const VaultResult();
}

final class VaultSuccess<T> extends VaultResult<T> {
  const VaultSuccess(this.data);
  final T data;
}

final class VaultError<T> extends VaultResult<T> {
  const VaultError(this.failure);
  final VaultFailure failure;
}

sealed class VaultFailure {
  const VaultFailure(this.code, this.message);
  final String code;
  final String message;
}

final class ExcelValidationFailure extends VaultFailure {
  const ExcelValidationFailure(this.rowErrors)
      : super('EXCEL_VALIDATION_ERROR', 'File Excel có lỗi dữ liệu cần chỉnh sửa.');
  final List<ExcelRowError> rowErrors;
}
```

- Đặt tên file `snake_case.dart`, lớp `PascalCase`, biến/hàm `camelCase`.
- Mọi hàm parse/codec phải là hàm thuần (pure functions) nhận bytes/stream để test được 100% không cần thiết bị thật.

---

## Testing Strategy
- **Unit tests (bắt buộc ≥ 90% branch coverage cho parser, normalizer & codec):**
  1. `excel_question_parser_test.dart`: Parse file `.xlsx` mẫu hợp lệ (430 câu giả lập), hỗ trợ tên cột có dấu/không dấu/khoảng trắng thừa; báo đúng số dòng + cột khi thiếu `Ma_Cau_Hoi`, trùng `Ma_Cau_Hoi`, `Dap_An_Dung` chỉ vào phương án rỗng, hoặc 1 `Ma_Chuyen_De` có 2 `Ten_Chuyen_De` mâu thuẫn.
  2. `point_group_normalizer_test.dart`: Kiểm tra `"Ưu đãi nhà thầu"` và `"  ưu  đãi nhà thầu "` gộp chung cùng 1 `pointGroupKey`; chuỗi rỗng/chỉ khoảng trắng trả về `null`.
  3. `bex_codec_test.dart`: Mã hoá -> giải mã khép kín (round-trip) giữ nguyên Unicode tiếng Việt; từ chối nếu sai magic bytes, file bị cắt cụt, hoặc lật 1 bit trong ciphertext (GCM auth failure).
  4. `file_vault_repository_test.dart`: Fallback về `bundled` khi chưa có `active_bank.bex`; khi import file lỗi, `active_bank.bex` cũ không bị thay đổi hoặc xoá; khi import thành công, `loadActiveBank()` trả ngay bộ câu hỏi mới; `resetToBundledBank()` khôi phục sạch về bản gốc.

---

## Boundaries
- **Always:**
  - Validate toàn bộ các dòng Excel/payload `.bex` trước khi ghi vào `active_bank.bex` (không bao giờ ghi dở dang).
  - Chuẩn hoá `Nhom_Cung_Diem` đồng nhất ở cả CLI tool và app importer.
  - Giữ các model trong `domain/models/` bất biến (`final` fields, `List.unmodifiable`).
- **Ask first:**
  - Thay đổi cấu trúc cột bắt buộc của file Excel mẫu hoặc đổi phiên bản format `BEX1` -> `BEX2`.
  - Thêm native C++/NDK plugin mới (nếu muốn nâng cấp bảo mật key từ Dart obfuscation sang JNI).
- **Never:**
  - Đóng gói file `.xlsx` hoặc `.json` thô chưa mã hoá vào trong `assets/` của APK phát hành.
  - Ghi file tạm giải mã dạng văn bản thuần ra bộ nhớ ngoài (`/sdcard` / Downloads).
  - Cho phép chức năng cập nhật câu hỏi xoá hoặc làm hỏng file lưu lịch sử của `study-progress`.

---

## Success Criteria
1. `dart run tool/pack_bex.dart` đóng gói được file Excel mẫu 430 câu (13 chuyên đề) thành `default_bank.bex` dung lượng nhỏ gọn (< 500 KB) và phát hiện chính xác 100% lỗi cố tình chèn vào file test.
2. `flutter test test/features/data_vault/` pass 100% các test case parser, normalizer, AES-GCM codec và atomic import/rollback trên máy dev.
3. Khi đổi một byte bất kỳ trong file `.bex`, giải mã thất bại rõ ràng với `VaultFailure` (không crash app, không giữ dữ liệu hỏng).
4. Không có file JSON/Excel văn bản thuần nào xuất hiện trong `assets/vault/`.

---

## Open Questions
- Đã giải quyết toàn bộ (xem phần **Assumptions** và **Quy chuẩn File Excel** đã cập nhật). Chỉ lưu ý thêm: khi có file Excel 430 câu thật, nên chạy thử `pack_bex.dart` ngay ở bước đầu triển khai để kiểm tra tên tiêu đề cột thực tế.
