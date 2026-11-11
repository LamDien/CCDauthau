# Changelog

Tất cả các thay đổi đáng chú ý của dự án **CC Đấu Thầu** đều được ghi nhận tại đây.

## [1.1.0] - 2026-11-11

### Added
- Xếp loại kết quả bài **Thi thử 70 câu** và **Mini-test chẩn đoán** theo thang điểm 100 với 5 mức chuẩn: **Xuất sắc** (`>= 90%`), **Giỏi** (`80%` đến `< 90%`), **Khá** (`60%` đến `< 80%`), **Trung bình** (`50%` đến `< 60%`) và **Không đạt yêu cầu** (`< 50%`).
- Bảng quy đổi xếp loại mở rộng ngay trên màn hình Kết quả bài thi (`ExamRankLegendCard`) và hiển thị xếp loại tương ứng cho điểm gần nhất/cao nhất trên Trang chủ.
- Tự động xuất thêm bản sao file APK release mang số hiệu phiên bản (`CCDauthau-v<version>.apk`) trong quá trình build Android.

### Changed
- Chuẩn hoá ngưỡng đạt của bài thi về `50/100` (từ mức *Trung bình* trở lên); tách tuỳ chọn trong Cài đặt (`50%..95%`, mặc định `70%`) thành **Mục tiêu nắm vững chuyên đề** cho Bản đồ 13 chuyên đề.
- Cập nhật màn hình Kết quả và tab Lịch sử hiển thị huy hiệu xếp loại cho **Thi thử 70 câu** & **Mini-test chẩn đoán**, đồng thời giữ chế độ **Luyện lại câu sai** chỉ hiển thị điểm và số câu đúng/sai.

## [1.0.0] - 2026-11-11

### Added
- Kho dữ liệu mã hoá ngoại tuyến (`assets/vault/default_bank.bex`) với 430 câu hỏi thuộc 13 chuyên đề đấu thầu, kèm tính năng nhập và kiểm tra tính hợp lệ cho file `.xlsx` / `.bex` trong màn hình Cài đặt.
- Bộ tạo đề thi thử 70 câu phân bổ tỷ lệ theo thuật toán phần dư lớn nhất (Largest Remainder / Hamilton), tách câu cùng nhóm điểm (`Nhom_Cung_Diem`), đảo thứ tự câu và đảo vị trí 4 đáp án A/B/C/D.
- Màn hình Thi thử hỗ trợ đồng hồ đếm ngược (`30/45/60/90` phút), tự động nộp bài khi hết giờ, 2 chế độ hiển thị (*Từng câu* và *Toàn bộ đề*), bảng nhảy nhanh 70 câu, cảnh báo câu chưa làm và chấm điểm thang 100.
- Hệ thống lưu tiến độ cục bộ SQLite (không cần đăng nhập) gồm bản đồ năng lực 13 chuyên đề, hàng đợi Phục thù câu sai, đánh dấu câu hỏi, Mini-test chẩn đoán nhanh và lịch sử các lần thi.
- Giao diện Flutter Material 3 tông xanh nhạt với icon ứng dụng hình Búa đấu thầu, tiêu đề Trang chủ `ÔN LUYỆN CCĐT`, các nút chọn 1 dòng với nền nổi bật trong Cài đặt, viền thẻ rõ nét và mục Giới thiệu ứng dụng (`Lam Điền @ 2026`).
