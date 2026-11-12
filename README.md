# CC Đấu Thầu (ÔN LUYỆN CCĐT)

Ứng dụng Flutter (Android, iOS, macOS) hỗ trợ ôn tập và thi thử ngoại tuyến cho kỳ thi sát hạch Chứng chỉ nghiệp vụ chuyên môn về Đấu thầu (Bộ Tài chính).

## Tính năng chính (v1.2.0)

- **Hoạt động 100% offline, không cần đăng nhập:** Toàn bộ ngân hàng 430 câu hỏi thuộc 13 chuyên đề được đóng gói và mã hoá cục bộ tại [assets/vault/default_bank.bex](assets/vault/default_bank.bex); lịch sử thi và tiến độ cá nhân được lưu bằng SQLite trên thiết bị.
- **Thi thử chuẩn đề (70 câu / 60 phút):**
  - Phân bổ tỷ lệ câu hỏi theo 13 chuyên đề bằng thuật toán phần dư lớn nhất (Largest Remainder / Hamilton).
  - Tách các câu hỏi thuộc cùng một nhóm điểm (`Nhom_Cung_Diem`) để tránh gợi ý đáp án chéo.
  - Xáo trộn thứ tự câu hỏi và đảo vị trí các đáp án A/B/C/D ở mỗi lượt thi.
  - Đồng hồ đếm ngược (tuỳ chỉnh 30/45/60/90 phút), tự nộp bài khi hết giờ, 2 chế độ xem (*Từng câu* / *Toàn bộ đề*), bảng điều hướng 70 câu, cảnh báo câu chưa trả lời, chấm điểm tự động thang 100 kèm xếp loại 5 mức (`Xuất sắc`, `Giỏi`, `Khá`, `Trung bình`, `Không đạt yêu cầu`) và xem giải thích chi tiết sau khi nộp.
- **Ôn thi thông minh:**
  - Ôn theo từng chuyên đề trong 13 chuyên đề.
  - Mini-test chẩn đoán nhanh (1 hoặc 2 câu mỗi chuyên đề).
  - Hàng đợi **Phục thù câu sai** (tự động gỡ khỏi danh sách yếu sau khi trả lời đúng liên tiếp theo ngưỡng cài đặt).
  - Tự chọn danh sách câu hỏi và đánh dấu sao để ôn tập lại.
- **Cập nhật ngân hàng câu hỏi:** Hỗ trợ nhập file Excel (`.xlsx`) hoặc gói `.bex` mới trực tiếp trong mục **Cài đặt & Dữ liệu** với kiểm tra lỗi từng dòng trước khi thay thế an toàn.

## Cấu trúc mô-đun

Xem chi tiết tại [CAPABILITY_MAP.md](CAPABILITY_MAP.md) và các tài liệu thiết kế `SPEC-*.md`:

- `lib/features/data_vault/` — Phân tích Excel, chuẩn hoá nhóm cùng điểm và mã hoá/giải mã `.bex`.
- `lib/features/exam_engine/` — Bộ phân bổ Hamilton, bộ chọn câu hỏi ràng buộc, xáo trộn đáp án và chấm điểm.
- `lib/features/study_progress/` — Lưu trữ SQLite tiến độ học, bản đồ năng lực 13 chuyên đề, hàng đợi câu yếu và lịch sử thi.
- `lib/features/mobile_ui/` — Giao diện Flutter Material 3 tông xanh nhạt.
- `tool/pack_bex.dart` — Công cụ CLI đóng gói file `.xlsx` thành gói mã hoá `.bex`.

## Phát triển & Kiểm thử

```bash
dart analyze
flutter test -r expanded --concurrency=1
```

Đóng gói lại gói câu hỏi mặc định (nếu có file nguồn `.xlsx`):

```bash
dart run tool/pack_bex.dart --input ngan_hang_cau_hoi_dau_thau.xlsx --output assets/vault/default_bank.bex
```

Build Android release APK:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

## Đóng gói cài đặt iOS & macOS

Build thủ công trên máy Mac có cài đầy đủ **Xcode** và **CocoaPods**:

```bash
# macOS (.dmg)
flutter build macos --release --obfuscate --split-debug-info=build/macos/symbols
./tool/package_macos_dmg.sh

# iOS (.ipa chưa ký để sideload / ký lại bằng Xcode)
flutter build ios --release --no-codesign --obfuscate --split-debug-info=build/ios/symbols
./tool/package_ios_unsigned_ipa.sh
```

Nếu máy cục bộ chưa cài Xcode, workflow GitHub Actions [`build-apple.yml`](.github/workflows/build-apple.yml) tự động chạy trên `macos-latest` khi push lên `main`, tạo tag `v*`, hoặc kích hoạt thủ công (**Run workflow**) để xuất tải về 2 file `CCDauthau-v<version>.dmg` và `CCDauthau-v<version>-unsigned.ipa`.

### Ghi chú cài đặt & Rollback
- **macOS (`.dmg`):** Mở file `.dmg` và kéo `CC Đấu Thầu.app` vào `Applications`. Vì bản build dùng ad-hoc signing (chưa qua Apple Notarization), ở lần mở đầu tiên có thể cần nhấn chuột phải → **Open** (hoặc **System Settings → Privacy & Security → Open Anyway**).
- **iOS (`-unsigned.ipa`):** Cài đặt bằng cách ký lại với tài khoản Apple ID qua AltStore / SideStore / Sideloadly / Impactor hoặc archive ký trong Xcode.
- **Rollback phát hành:** Dữ liệu tiến độ SQLite được lưu hoàn toàn cục bộ trên thiết bị và giữ nguyên khi gỡ/cài lại từ tag trước đó (ví dụ quay về bản Android `v1.1.0` hoặc bản artifact ổn định trước trên GitHub Actions).
