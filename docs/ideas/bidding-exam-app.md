# App Ôn & Thi Thử Chứng Chỉ Đấu Thầu (Offline APK)

## Problem Statement
**How Might We** giúp người làm đấu thầu trên khắp Việt Nam ôn luyện trúng trọng tâm và thi thử sát quy chế Bộ Tài chính ngay trên điện thoại (hoạt động 100% offline, không tài khoản, không máy chủ), khai thác triệt để bộ 430 câu hỏi kèm nhóm "cùng một điểm" để tránh bẫy số liệu mà vẫn bảo vệ file dữ liệu khỏi bị sao chép thô?

## Recommended Direction
Xây dựng ứng dụng Android đóng gói dạng **file APK độc lập** (bằng **Flutter**, sẵn sàng mở rộng iOS về sau mà không phải viết lại) theo mô hình **"Mở lên là thi, sai đâu vá đó"**. Không có màn hình đăng nhập hay máy chủ; toàn bộ tiến độ cá nhân được lưu ngay trên thiết bị.

Điểm khác biệt cốt lõi so với việc đọc PDF hay dùng app trắc nghiệm thông thường nằm ở việc **khai thác hai chiều dữ liệu phân nhóm "cùng một điểm"**: vừa dùng để tách câu trùng ý trong đề thi thử 70 câu/60 phút đúng quy tắc Cục Đấu thầu, vừa trở thành công cụ đối chiếu cụm kiến thức dễ nhầm ngay lúc ôn thi. Kết hợp cùng bản đồ năng lực 13 chuyên đề tự động tô màu theo lịch sử làm bài và cơ chế "Phục thù câu sai" (làm đúng lại 2 lần mới gỡ cờ yếu), người học chỉ cần tập trung vào đúng phần mình hay sai thay vì cày lại cả 430 câu một cách dàn trải.

Toàn bộ ngân hàng 430 câu, đáp án, giải thích và nhóm câu hỏi được đóng gói thành cơ sở dữ liệu mã hoá cục bộ (SQLCipher/AES) kèm làm rối mã nguồn khi build release, ngăn việc giải nén file `.apk` để lấy dữ liệu JSON/CSV sạch, đồng thời dùng chữ ký APK cố định để người dùng cài đè bản cập nhật sau này mà không mất lịch sử ôn tập.

## Key Assumptions to Validate
- [ ] **Tính khả giải của thuật toán xếp đề 70 câu:** Khi áp dụng tỷ lệ 13 chuyên đề trên 430 câu đồng thời loại các câu cùng nhóm "cùng một điểm", bài toán chọn đề luôn tìm được đủ 70 câu hợp lệ ở mọi lượt random — *Cách kiểm chứng:* Chạy script mô phỏng sinh 10.000 đề thử trên chính file 430 câu thật trước khi dựng giao diện.
- [ ] **Độ gọn của giao diện khi gộp 4 luồng học:** Việc đưa thêm Bản đồ 13 chuyên đề, Hàng đợi "Phục thù câu sai" và nút "Xem cụm cùng điểm kiến thức" không làm người mới bị ngợp — *Cách kiểm chứng:* Đưa bản thử nghiệm sớm cho 3–5 đồng nghiệp sắp thi dùng thực tế trong 2–3 ngày và quan sát xem họ có tự tìm được nút *Thi thử* / *Ôn chuyên đề* trong 5 giây đầu không.
- [ ] **Hiệu năng & tính bảo mật thực tế của DB mã hoá:** Thời gian giải mã để tạo đề 70 câu hoặc lật câu giữ ở mức tức thì trên điện thoại Android phổ thông, và khi giải nén file `.apk` không tìm thấy nội dung câu hỏi/đáp án dạng văn bản thuần — *Cách kiểm chứng:* Dùng công cụ giải nén APK kiểm tra gói build release trên máy Android tầm trung.
- [ ] **Bảo toàn lịch sử khi cập nhật bản vá:** Cài đè file `.apk` phiên bản mới (khi luật/đáp án thay đổi) vẫn giữ nguyên lịch sử thi thử và tiến độ 430 câu của người dùng trên máy.

## MVP Scope (Phiên bản V1 hoàn chỉnh)
- **Giao diện & Nền tảng:** Flutter đóng gói **Android APK**, tone màu xanh nhạt hiện đại, icon hiện đại, tối ưu thao tác một tay. Vào thẳng màn hình chính, không tài khoản.
- **Trang chủ & Bản đồ năng lực (Chẩn đoán tự động):**
  - Hai nút truy cập nhanh nổi bật: **Thi thử 70 câu** và **Ôn theo 13 chuyên đề**.
  - Thước đo mức độ sẵn sàng & **Bản đồ 13 chuyên đề** (tự động tô màu Đỏ / Vàng / Xanh dựa trên lịch sử làm bài) + tùy chọn **Mini-test chẩn đoán nhanh** (ví dụ 26 câu phủ 13 chuyên đề) cho người muốn đánh giá nhanh lúc mới cài.
- **Chế độ Ôn thi thông minh:**
  - Ôn theo từng chuyên đề trong 13 chuyên đề (làm từng câu hoặc hiển thị danh sách nhiều câu).
  - Hiển thị đáp án, giải thích chi tiết và nút **"Xem các câu cùng điểm kiến thức"** để đối chiếu trực tiếp các câu dễ nhầm số liệu/điều kiện.
  - Hàng đợi **"Phục thù câu sai"** (tự động nhận câu sai từ đề thi thử & quá trình ôn; cần trả lời đúng lại **2 lần** mới gỡ cờ yếu) + ôn theo danh sách câu tự chọn/đánh dấu.
- **Chế độ Thi thử chuẩn (70 câu / 60 phút):**
  - Sinh đề ngẫu nhiên 70 câu theo đúng tỷ lệ số câu của 13 chuyên đề trên 430 câu, tách các câu "cùng một điểm", xáo thứ tự câu và đảo vị trí các đáp án A/B/C/D ở mỗi lượt thi.
  - Đồng hồ đếm ngược 60 phút (hết giờ tự nộp bài), 2 chế độ xem (**Từng câu** và **Toàn bộ đề**), bảng nhảy câu + cảnh báo số câu chưa làm trước khi nộp.
  - Chấm tự động thang điểm **100**, xem đáp án & giải thích từng câu sau nộp, nút **luyện lại riêng các câu vừa sai**, thi lại không giới hạn và xem lại toàn bộ **lịch sử bài thi** lưu cục bộ.
- **Bảo vệ dữ liệu cục bộ:** Database câu hỏi mã hoá (SQLCipher/AES) + ProGuard/R8 & làm rối mã nguồn Flutter khi build release.

## Not Doing (and Why)
- **Hệ thống đăng nhập / tạo tài khoản & đồng bộ đám mây** — App chạy 100% không máy chủ để miễn phí, mở dùng ngay và phục vụ tiến độ 1 cá nhân trên thiết bị đó.
- **Chức năng "Báo lỗi câu hỏi"** — Vì không có máy chủ thu nhận phản hồi; loại bỏ để giao diện sạch gọn và tránh nút bấm không có điểm nhận.
- **Ép buộc làm bài test chẩn đoán khi mở app lần đầu** — Người bận rộn cần được bấm thẳng vào chuyên đề hoặc đề thi thử trong 3 giây; bản đồ năng lực sẽ cập nhật thụ động từ mọi bài họ làm.
- **Khoá chụp/quay màn hình (`FLAG_SECURE`)** — DB đã được mã hoá để chống giải nén lấy file data sạch; giữ lại khả năng chụp màn hình bình thường để đồng nghiệp tiện chụp 1 câu khó hỏi/trao đổi với nhau.
- **Phát hành bản iOS (App Store) và đưa lên Google Play ở V1** — Tập trung ra mắt bản Android APK chạy mượt trước; dùng Flutter để giữ đường nâng cấp đa nền tảng về sau mà không tốn công làm lại từ đầu.
- **Tính năng cộng đồng, bảng xếp hạng hay thông báo nhắc học phức tạp** — Không phù hợp với kiến trúc offline-only và làm phân tán sự tập trung khi ôn thi.

## Open Questions (Cần chốt trước khi bắt đầu thiết kế & code)
1. **Định dạng file dữ liệu gốc:** File ngân hàng 430 câu của bạn hiện đang là Excel/CSV, Word hay JSON, và cột đánh dấu các nhóm *"cùng một điểm"* được quy ước theo mã nhóm như thế nào?
2. **Quy tắc làm tròn tỷ lệ 70/430 trên 13 chuyên đề:** Khi nhân tỷ lệ số câu từng chuyên đề với `70 / 430` ra số thập phân, bạn đã có bảng số lượng câu cố định cho 13 chuyên đề (tổng = 70) hay muốn hệ thống tự phân bổ theo thuật toán làm tròn phần dư lớn nhất?
3. **Ngưỡng "Phục thù câu sai" & Đạt chuẩn:** Bạn muốn mặc định câu sai cần làm đúng lại **2 lần** (hay 1 lần / 3 lần) để xoá khỏi danh sách yếu, và mốc điểm Đạt trong màn hình kết quả thi thử là bao nhiêu trên thang 100 (ví dụ >= 70 hoặc >= 80)?

