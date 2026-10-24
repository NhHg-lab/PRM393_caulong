# Báo Cáo Tổng Hợp Tiến Độ Triển Khai: Sprint 1 & Sprint 2

**Dự án:** Courtly — Nền tảng đặt sân & ghép kèo cầu lông (PRM393)  
**Thời gian cập nhật:** 24/10/2026  
**Nhánh:** `feature/auth-mode`  
**Chất lượng mã nguồn:**  
- `flutter test`: **114/114 tests passed** (100%)  
- `flutter analyze`: **No issues found** (0 warnings, 0 errors)  
- `Firestore Security Rules Emulator`: **8/8 tests passed** (100%)  

---

## I. Chi tiết nội dung đã triển khai

### 1. Sprint 1 — Hoàn thiện xác thực và nền tảng dữ liệu
- **Quyết định kiến trúc ([docs/SPRINT1_ARCHITECTURE.md](docs/SPRINT1_ARCHITECTURE.md)):**
  - Chỉ định **Firebase UID** là định danh duy nhất (canonical ID) cho toàn bộ tài khoản, hồ sơ và giao dịch.
  - Phân định rõ trách nhiệm:
    - **Firebase Authentication:** Quản lý mật khẩu, Google Sign-In, token JWT.
    - **Cloud Firestore (`users/{uid}`):** Quản lý hồ sơ, vai trò (`CUSTOMER`, `ADMIN`).
    - **Spring Boot:** Xác minh mã OTP email và dùng Firebase Admin SDK để tạo tài khoản, không tạo bảng SQL riêng biệt thay thế UID.
  - Chế độ tích hợp chính là `AUTH_MODE=firebase`, giữ chế độ mock mặc định để chạy test và demo offline.

- **Hợp đồng API OTP với Backend ([docs/SPRINT1_OTP_CONTRACT.md](docs/SPRINT1_OTP_CONTRACT.md)):**
  - `POST /api/auth/register/send-otp`: gửi mã OTP 6 số qua email, trả về thời hạn `expiresIn` và thời gian gửi lại `resendAfter`.
  - `POST /api/auth/register/firebase`: xác minh OTP và tạo tài khoản Firebase Auth + Firestore profile `CUSTOMER`.
  - Chuẩn hóa mã lỗi HTTP: `400` (dữ liệu/OTP không hợp lệ), `409` (email đã dùng), `429` (giới hạn tần suất), `503` (lỗi dịch vụ mail).

- **Tách Client OTP & Chuẩn hóa lỗi ([lib/services/registration_otp_client.dart](lib/services/registration_otp_client.dart)):**
  - Tách logic gọi API Spring ra khỏi `FirebaseDirectAuthService`, hỗ trợ inject trong test.
  - Chuẩn hóa timeout, lỗi mạng, lỗi parse JSON thành `AuthException` thân thiện với người dùng.
  - **Không tự ý retry** tạo tài khoản khi phản hồi mạng không rõ ràng để tránh tạo trùng.

- **Củng cố vòng đời phiên & Phân quyền ([lib/services/session_storage.dart](lib/services/session_storage.dart), [lib/services/auth_manager.dart](lib/services/auth_manager.dart)):**
  - Lưu `auth_mode` vào storage; xóa bỏ các phiên cũ không rõ chế độ, yêu cầu đăng nhập lại an toàn.
  - Kiểm tra khớp Firebase UID với session đã lưu khi khôi phục phiên.
  - Gating quyền admin: role admin chỉ được kích hoạt khi đã xác thực online với server, không dùng role lưu offline để mở dashboard quản trị.
  - Đăng xuất độc lập: xóa sạch local storage, Firebase Auth và Google Provider kể cả khi mất mạng.
  - Bỏ chọn "Ghi nhớ đăng nhập": tắt app và mở lại bắt buộc vào màn hình đăng nhập.

- **Siết Security Rules cho hồ sơ ([firestore.rules](firestore.rules)):**
  - Người dùng chỉ được sửa `fullName`, `phone`, `avatarUrl`.
  - Nghiêm cấm client tự ý sửa `role`, `email`, `authProvider`, `createdAt`.
  - Khóa tất cả các collection ngoài schema.

---

### 2. Sprint 2 — Danh mục sân bãi & Động cơ đặt sân (Booking Engine)
- **Mô hình thực thể chuẩn hóa:**
  - [`VenueModel`](lib/models/venue_model.dart): Đại diện cho cơ sở sân (tên, địa chỉ, quận, tiện ích tags, bảng giá, số lượng sân).
  - [`CourtModel`](lib/models/venue_model.dart): Đại diện cho từng sân đấu cụ thể thuộc cơ sở.
  - [`BookingModel`](lib/models/booking_model.dart): Đại diện cho vé đặt sân với đầy đủ thông tin thời gian UTC, khung giờ, tổng tiền, số tiền cọc, trạng thái (`HOLD`, `CONFIRMED`, `COMPLETED`, `EXPIRED`, `CANCELLED`), mã PIN 4 số.

- **Venue & Court Catalog Repository ([lib/services/venue_repository.dart](lib/services/venue_repository.dart)):**
  - Đọc danh sách cơ sở, chi tiết cơ sở và danh sách sân từ Firestore collection `venues` và `courts`.
  - Hỗ trợ graceful fallback sang seed data khi chạy offline/test/demo.

- **Quản lý sân yêu thích (User Favorites):**
  - Lưu trữ tại subcollection `users/{uid}/favorites/{venueId}`.
  - Cung cấp hàm `isFavorite`, `toggleFavorite` và Stream `watchFavorites` theo dõi thời gian thực.

- **Động cơ tính giá & Khung giờ cao điểm ([lib/services/pricing_engine.dart](lib/services/pricing_engine.dart)):**
  - Tự động áp dụng giá giờ cao điểm: khung giờ 17:00 – 22:00 (+30.000đ/giờ).
  - Tính tiền phụ kiện: vợt (30.000đ), ống cầu (220.000đ), nước suối (10.000đ).
  - Áp dụng voucher giảm giá (-30.000đ) và tính tiền cọc 50% (làm tròn lên).
  - Kiểm tra điều kiện: các khung giờ chọn phải liên tiếp và không nằm trong quá khứ.

- **Động cơ giữ chỗ 15 phút & Chống trùng lịch ([lib/services/booking_repository.dart](lib/services/booking_repository.dart)):**
  - Tạo vé đặt ban đầu với trạng thái `HOLD` và thời hạn giữ chỗ 15 phút (`expiresAt = now + 15m`).
  - Kiểm tra xung đột thời gian thực: nếu khung giờ đang được giữ hoặc đã xác nhận bởi người khác, hệ thống từ chối và báo lỗi HTTP 409.
  - Cơ chế tự động dọn dẹp các vé `HOLD` đã quá hạn để giải phóng khung giờ.

- **Chính sách hủy vé trước 4 tiếng:**
  - Vé đặt được hủy hợp lệ nếu thời gian bắt đầu còn cách thời điểm hiện tại ít nhất 4 tiếng (`startsAt.difference(now) >= 4h`).
  - Hủy vé chuyển trạng thái sang `CANCELLED` và giải phóng ngay khung giờ cho người khác đặt.
  - Hủy vé dưới 4 tiếng sẽ bị từ chối với lỗi HTTP 400.

- **Mở rộng Firestore Security Rules cho Sprint 2 ([firestore.rules](firestore.rules)):**
  - `users/{uid}/favorites`: Chỉ chủ tài khoản (`owner(uid)`) được phép đọc/ghi/xóa.
  - `venues` & `courts`: Người dùng đã đăng nhập được phép đọc, cấm mọi quyền ghi từ client.
  - `bookings`:
    - Khách hàng chỉ được đọc vé của chính mình.
    - Khách hàng chỉ được tạo vé với trạng thái khởi tạo là `HOLD`.
    - Khách hàng chỉ được cập nhật trạng thái `CANCELLED` trên vé của mình.
    - Cấm tự ý sửa giá tiền, UID hoặc xóa vé.
  - Tiếp tục khóa kín các collection `payments` và `matches` cho Sprint 3 & 4.

---

## II. Kết quả kiểm thử tự động chi tiết

| Bộ kiểm thử | Số lượng test | Kết quả | Ghi chú |
|---|---|---|---|
| **Flutter Widget & Unit Tests** | 114 tests | **PASS 100%** | Bao gồm auth, session, OTP client, shuttlezone UI, pricing engine, booking repo, cancellation policy |
| **Flutter Static Analysis** | Toàn bộ dự án | **0 issues** | `flutter analyze` sạch hoàn toàn |
| **Firestore Security Rules (Emulator)** | 8 tests | **PASS 100%** | Kiểm tra phân quyền users, favorites, venues, courts, bookings và collections bị khóa |

### Lệnh chạy kiểm thử:
```powershell
# 1. Chạy phân tích mã nguồn
flutter analyze

# 2. Chạy 114 tests Flutter
flutter test

# 3. Chạy 8 test Firestore Rules trên Emulator
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
cd tools/rules-tests
npm test
```

---

## III. Các file tài liệu và mã nguồn chính đã tạo / cập nhật

- **Tài liệu:**
  - [`README.md`](README.md): Hướng dẫn cấu hình, chạy app và mô tả các chế độ.
  - [`SUMMARY.md`](SUMMARY.md): Báo cáo tổng hợp tiến độ Sprint 1 & 2.
  - [`docs/SPRINT1_ARCHITECTURE.md`](docs/SPRINT1_ARCHITECTURE.md): Kiến trúc định danh Firebase UID & Spring OTP.
  - [`docs/SPRINT1_OTP_CONTRACT.md`](docs/SPRINT1_OTP_CONTRACT.md): Hợp đồng API chi tiết cho đội Backend.
  - [`docs/SPRINT1_ACCEPTANCE.md`](docs/SPRINT1_ACCEPTANCE.md): Biên bản nghiệm thu Sprint 1 & checklist thiết bị thật.
  - [`docs/SPRINT2_ACCEPTANCE.md`](docs/SPRINT2_ACCEPTANCE.md): Biên bản nghiệm thu kỹ thuật Sprint 2.
  - [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md): Hợp đồng mô hình dữ liệu cho Sprint 2 đến Sprint 5.

- **Mã nguồn Sprint 2:**
  - [`lib/models/venue_model.dart`](lib/models/venue_model.dart): Model cơ sở sân và sân đấu.
  - [`lib/models/booking_model.dart`](lib/models/booking_model.dart): Model vé đặt sân và trạng thái.
  - [`lib/services/pricing_engine.dart`](lib/services/pricing_engine.dart): Động cơ tính giá, giờ cao điểm, phụ kiện.
  - [`lib/services/venue_repository.dart`](lib/services/venue_repository.dart): Repository danh mục sân và favorites.
  - [`lib/services/booking_repository.dart`](lib/services/booking_repository.dart): Repository giữ chỗ 15p, chống trùng lịch, hủy vé.
  - [`test/sprint2_booking_test.dart`](test/sprint2_booking_test.dart): Toàn bộ unit tests cho Sprint 2.
  - [`firestore.rules`](firestore.rules): Cập nhật Security Rules cho Sprint 2.
  - [`tools/rules-tests/rules.test.mjs`](tools/rules-tests/rules.test.mjs): Bộ test Rules cho Sprint 1 & 2.

---

## IV. Lộ trình tiếp theo (Sprint 3 & 4)

- **Sprint 3 (Thanh toán & Thông báo):**
  - Tích hợp VietQR động theo `bookingId` và số tiền cọc/toàn phần.
  - State machine thanh toán (`payments`) độc lập với `bookings`.
  - Backend payment webhook xác nhận thanh toán chuyển `bookings` sang `CONFIRMED`.
  - Notification nhắc lịch thi đấu trước giờ chơi.
- **Sprint 4 (Ghép kèo & Quản trị):**
  - Ghép kèo cộng đồng (`matches` và `members`), bảo đảm sĩ số atomic bằng transaction.
  - Dashboard Admin: ma trận sân thời gian thực, đặt tại quầy (walk-in), check-in mã PIN/QR vé và thống kê doanh thu.
