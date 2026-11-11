# Capability Map: Ứng Dụng Ôn & Thi Thử Chứng Chỉ Đấu Thầu (Offline APK)

Tài liệu ý tưởng gốc: [docs/ideas/bidding-exam-app.md](docs/ideas/bidding-exam-app.md)

| Module id | Responsibility | Depends on | Spec |
|---|---|---|---|
| `data-vault` | Chuẩn định dạng Excel (`.xlsx`) & gói dữ liệu mã hoá (`.bex`), đọc/giải mã kho câu hỏi cục bộ, và luồng Upload file để cập nhật ngân hàng câu hỏi an toàn (atomic swap) | — | [SPEC-data-vault.md](SPEC-data-vault.md) *(đã duyệt & cập nhật theo cột Excel thật)* |
| `exam-engine` | Thuật toán phân bổ 70 câu theo phần dư lớn nhất (Largest Remainder), chọn câu tách nhóm `Nhom_Cung_Diem`, đảo thứ tự câu & đảo vị trí đáp án, chấm điểm thang 100 | `data-vault` | [SPEC-exam-engine.md](SPEC-exam-engine.md) *(đã duyệt)* |
| `study-progress` | Lưu lịch sử thi thử cục bộ, bản đồ năng lực 13 chuyên đề (Đỏ/Vàng/Xanh), hàng đợi "Phục thù câu sai", danh sách tự chọn/đánh dấu, và Cài đặt ngưỡng | `data-vault`, `exam-engine` | [SPEC-study-progress.md](SPEC-study-progress.md) *(đã duyệt)* |
| `mobile-ui` | Giao diện Flutter (tone xanh nhạt, icon hiện đại), trang chủ vào thẳng không login, luồng Ôn thi (xem cụm cùng điểm), luồng Thi thử 60 phút, Cài đặt & Upload file | `data-vault`, `exam-engine`, `study-progress` | [SPEC-mobile-ui.md](SPEC-mobile-ui.md) *(đã duyệt)* |

**Build order:** `data-vault` → `exam-engine` → `study-progress` → `mobile-ui`
