# Changelog

Tất cả các thay đổi đáng chú ý của dự án **CC Đấu Thầu** đều được ghi nhận tại đây.

## [1.0.0] - 2026-11-11

### Added
- Kho dữ liệu mã hoá ngoại tuyến (`assets/vault/default_bank.bex`) với 430 câu hỏi thuộc 13 chuyên đề đấu thầu, kèm tính năng nhập và kiểm tra tính hợp lệ cho file `.xlsx` / `.bex` trong màn hình Cài đặt.
- Bộ tạo đề thi thử 70 câu phân bổ tỷ lệ theo thuật toán phần dư lớn nhất (Largest Remainder / Hamilton), tách câu cùng nhóm điểm (`Nhom_Cung_Diem`), đảo thứ tự câu và đảo vị trí 4 đáp án A/B/C/D.
- Màn hình Thi thử hỗ trợ đồng hồ đếm ngược (`30/45/60/90` phút), tự động nộp bài khi hết giờ, 2 chế độ hiển thị (*Từng câu* và *Toàn bộ đề*), bảng nhảy nhanh 70 câu, cảnh báo câu chưa làm và chấm điểm thang 100.
- Hệ thống lưu tiến độ cục bộ SQLite (không cần đăng nhập) gồm bản đồ năng lực 13 chuyên đề, hàng đợi Phục thù câu sai, đánh dấu câu hỏi, Mini-test chẩn đoán nhanh và lịch sử các lần thi.
- Giao diện Flutter Material 3 tông xanh nhạt với icon ứng dụng hình Búa đấu thầu, tiêu đề Trang chủ `ÔN LUYỆN CCĐT`, các nút chọn 1 dòng với nền nổi bật trong Cài đặt, viền thẻ rõ nét và mục Giới thiệu ứng dụng (`Lam Điền @ 2026`).
