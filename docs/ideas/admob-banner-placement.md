# Vị trí & Kích thước 1 Block Google AdMob trong App CC Đấu Thầu

> Trạng thái: **Đã chốt phương án (Hướng B — Top-Anchored + Safe Reveal Gate)** qua quy trình `/idea-refine`.

## Problem Statement
**How Might We** tích hợp **duy nhất 1 block quảng cáo Google AdMob** nhằm tạo nguồn thu nhẹ duy trì ứng dụng trên **Android & iOS**, đặt cố định ở mép trên trong vùng nghỉ `HomeShell` ngay dưới `AppBar`, **thu gọn về `0dp` khi offline**, **tuyệt đối không xuất hiện trong lúc thi/học**, và **không bao giờ đẩy tụt các nút hành động chính xuống dưới ngón tay người dùng** khi quảng cáo tải trễ?

---

## Recommended Direction (Hướng B: Top-Anchored + Safe Reveal Gate)

### 1. Vị trí & Phân cấp Widget
Đặt duy nhất 1 slot banner cố định ở mép trên bên trong `HomeShell` (`lib/features/mobile_ui/screens/home_shell.dart`), bọc `body: SafeArea(child: body)` thành cột dọc ngay dưới `AppBar` và phía trên nội dung 4 tab (`Trang chủ`, `Ôn thi`, `Lịch sử`, `Cài đặt`):

```text
Scaffold (HomeShell)
├── AppBar
├── body: SafeArea
│   └── Column
│       ├── MobileAdBannerSlot   <-- Duy nhất 1 slot (0dp khi offline / dynamic height khi hiện)
│       │     ├── Container nền trung tính + SizedBox đúng width/height SDK trả về
│       │     └── Vạch ngăn mảnh 1dp + khoảng đệm dưới 8dp (ngăn tách với ListView)
│       └── Expanded
│           └── body (HomeTab | StudyTab | HistoryTab | SettingsTab)
└── bottomNavigationBar: NavigationBar (giữ nguyên sạch 100%, không bị che hay chạm nhầm)
```

* **Cách ly 100% phòng thi & ôn luyện:** `MockExamScreen`, `StudySessionScreen`, và `ExamResultScreen` sử dụng `Scaffold` độc lập ngoài `HomeShell` → không hiển thị quảng cáo khi làm bài thi thử, học chuyên đề hay xem kết quả xếp hạng.
* **Cách ly macOS Desktop:** Chỉ khởi tạo và render trên `!kIsWeb && (Platform.isAndroid || Platform.isIOS)`; trên macOS trả về `SizedBox.shrink()` (`0dp`) và không gọi native AdMob SDK để giữ nguyên bản build `.dmg`.

### 2. Loại Banner & Kích thước Chuẩn
* **Định dạng:** **Anchored Adaptive Banner** — gọi động `AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width)` theo bề rộng màn hình (tính bằng `dp` nguyên).
* **Chiều cao & Bề rộng:**
  * **Không hardcode `height: 50`**; luôn lấy chính xác `bannerAd.size.height.toDouble()` từ SDK sau `onAdLoaded`.
  * Theo chuẩn Google Mobile Ads SDK, chiều cao tự tối ưu theo bề rộng thiết bị và bị giới hạn tối đa **15% chiều cao màn hình hoặc trần `90dp`** (thực tế phổ biến khoảng `~50–60dp` trên điện thoại dọc).
  * **Bề rộng khuyến nghị:** Toàn chiều ngang (`full-width`) ngay dưới `AppBar` để trông như dải thông tin hệ thống gọn mắt, không phá lưới card bo góc bên trong `HomeTab` hay `StudyTab`.
* **Vùng đệm chống chạm nhầm (Accidental Clicks):** Bên dưới banner đặt **vạch chia `1dp` + đệm `8dp`**. Kết hợp với `padding` đỉnh `12dp` sẵn có của `ListView` trong các tab (như `HomeTab`, `HistoryTab`, `SettingsTab`), khoảng cách thị giác và vùng đệm chạm giữa banner và `_ReadinessCard` / card đầu tiên đạt **`~20dp`**.
* **Xoay màn hình:** Lắng nghe thay đổi chiều rộng / `Orientation` để yêu cầu lại kích thước adaptive tương ứng.

### 3. Cơ chế "Pre-load & Safe Reveal Gate" (Chống tụt nút khi tải trễ)
Do slot đặt ở **phía trên** nội dung chính, nếu bung chiều cao `0dp -> ~55dp` ngay lúc người dùng đang nhìn `HomeTab`, `_ReadinessCard` và các nút hành động sẽ tụt xuống đúng lúc tay sắp bấm. Slot phải tuân thủ **3 trạng thái khóa nhịp**:

| Trạng thái mạng / Ad | Chiều cao slot (`HomeShell`) | Quy tắc hiển thị an toàn |
| :--- | :--- | :--- |
| **Offline / Lỗi tải / Chưa tải** | `0dp` (thu gọn hoàn toàn) | Không giữ khoảng trống chết; không retry liên tục gây hao pin khi offline. |
| **Tải xong muộn khi người dùng ĐÃ ở trong tab** | Tạm giữ `0dp` (giữ banner sẵn trong bộ nhớ) | **Tuyệt đối không đẩy UI đang xem xuống.** Chỉ mở slot ở "ranh giới điều hướng" kế tiếp: khi đổi tab (`_selectedIndex`) hoặc quay về `HomeShell` từ bài thi/ôn. |
| **Đã tải sẵn trước lúc tab dựng lên** | Hiện đúng `bannerHeight` + đệm | Hiển thị mượt ngay từ frame đầu và **giữ ổn định xuyên suốt 4 tab**, không nhấp nháy tải lại khi chuyển tab. |

---

## Key Assumptions to Validate
- [ ] **An toàn vùng chạm (Accidental Clicks):** Khoảng đệm `~20dp` giữa mép dưới banner và card đầu tiên giữ tỷ lệ chạm nhầm ở mức thấp và không làm giảm tỷ lệ bấm vào *Thi thử 70 câu* / *Ôn chuyên đề* — *Kiểm chứng:* theo dõi chỉ số CTR / Policy Center trên Google AdMob và hành vi bấm nút thực tế trên bản test nội bộ.
- [ ] **Hiệu quả của Safe Reveal Gate:** Việc hoãn bung banner đến ranh giới đổi tab/quay lại khi mạng chậm ở giây đầu giúp triệt tiêu 100% lỗi nhảy nút mà không làm hụt đáng kể số lượt hiển thị hữu ích.
- [ ] **Tỷ lệ phiên có mạng đủ bù chi phí duy trì:** Dù phần lớn lúc thi thử người dùng có thể dùng offline, tỷ lệ mở app có kết nối mạng lúc ở nhà/cơ quan đủ tạo nguồn thu nhẹ ổn định theo mục tiêu đề ra.

---

## MVP Scope (Phạm vi triển khai khi code)
- **Tầng trừu tượng & Testability:** Tạo interface/controller quản lý banner (kèm triển khai no-op cho macOS & widget tests để toàn bộ bộ test hiện tại chạy độc lập với native SDK).
- **Tích hợp `google_mobile_ads` (Android & iOS):** Dùng 1 slot `BannerAd` Anchored Adaptive trong `HomeShell`, gắn **Safe Reveal Gate**, tự thu `0dp` khi offline/lỗi, xử lý đổi kích thước khi xoay ngang/dọc.
- **Cấu hình Native tối thiểu:**
  - **Android:** `android/app/build.gradle.kts` đã đặt `minSdk = maxOf(flutter.minSdkVersion, 26)` (đạt ngưỡng SDK); bổ sung quyền `INTERNET` và meta-data `com.google.android.gms.ads.APPLICATION_ID` vào `android/app/src/main/AndroidManifest.xml`.
  - **iOS:** Bổ sung `GADApplicationIdentifier` và `SKAdNetworkItems` vào `ios/Runner/Info.plist` (kèm `NSUserTrackingUsageDescription` nếu dùng quảng cáo cá nhân hóa).
- **Tách ID Test / Production:** Mặc định dùng Google Test Ad Unit ID ở build debug/dev; truyền ID thật qua `--dart-define` hoặc cấu hình release để tránh vi phạm chính sách tự click lúc phát triển.
- **Cập nhật khai báo Store:** Cập nhật Play Store Data Safety và App Store Privacy Nutrition Label cho quyền mạng & SDK quảng cáo.

---

## Not Doing (and Why)
- **Interstitial (toàn màn hình), App Open Ads, hay Rewarded Ads** — Gây gián đoạn luồng ôn thi nhanh và phá vỡ trải nghiệm sạch ưu tiên số 1.
- **Quảng cáo trong `MockExamScreen`, `StudySessionScreen`, `ExamResultScreen`** — Bảo vệ sự tập trung tuyệt đối khi làm bài 60 phút và sự chỉn chu lúc xem điểm/xếp hạng.
- **Hiển thị quảng cáo trên macOS Desktop** — Plugin `google_mobile_ads` không hỗ trợ macOS; giữ bản `.dmg` sạch và không lỗi build.
- **Bung chiều cao live `0dp -> ~55dp` giữa lúc người dùng đang thao tác trên `HomeTab`** — Tránh đẩy nút bấm chính xuống dưới ngón tay gây chạm nhầm.
- **Mediation đa mạng quảng cáo ở giai đoạn đầu** — Tăng độ phức tạp SDK và dung lượng app không cần thiết so với mục tiêu thu nhẹ duy trì.

---

## Open Questions (Chốt trước khi bắt tay code)
1. **Chế độ quyền riêng tư & ATT trên iOS:** Dùng **Non-personalized Ads** (không theo dõi hành vi, ưu điểm: **không phải bật popup ATT xin quyền theo dõi**) hay bật **Personalized Ads** (kèm ATT / UMP consent để tối ưu eCPM)?
2. **AdMob App ID & Ad Unit ID:** Bạn đã tạo sẵn App ID và Banner Ad Unit ID cho Android/iOS trên Google AdMob chưa, hay sẽ code tích hợp trước bằng **Google Test Ad Unit ID** rồi gắn ID thật lúc release?

