# Sprint 2 — Biên bản bàn giao & nghiệm thu: Danh mục sân bãi & Động cơ đặt sân

Ngày thực hiện: 24/10/2026.

**Trạng thái: Hoàn tất triển khai mã nguồn, cấu hình Security Rules và kiểm thử tự động đạt 100%.**

---

## 1. Các Task triển khai trong Sprint 2

| Task ID | Hạng mục | Triển khai | Trạng thái |
|---|---|---|---|
| **S2-01** | Venue & Court Catalog | Mô hình [`VenueModel`](../lib/models/venue_model.dart), [`CourtModel`](../lib/models/venue_model.dart), [`VenueRepository`](../lib/services/venue_repository.dart) hỗ trợ Firestore và Fallback dữ liệu seed. | Đạt |
| **S2-02** | User Favorites Subcollection | Quản lý `users/{uid}/favorites/{venueId}`, hỗ trợ toggleFavorite, isFavorite, watchFavorites qua Firestore Stream / Memory fallback. | Đạt |
| **S2-03** | Operating Schedule & Dynamic Pricing | Triển khai [`PricingEngine`](../lib/services/pricing_engine.dart) tính giá giờ thường vs giờ cao điểm (17:00 - 22:00, +30.000đ/h), tính phụ phí dụng cụ và cọc 50%. | Đạt |
| **S2-04** | Slot Availability & 15-minute Hold Engine | [`BookingRepository`](../lib/services/booking_repository.dart): Tạo booking trạng thái `HOLD` với `expiresAt = now + 15m`. Chống đặt trùng (double-booking) khi slot đang được giữ bởi người khác. | Đạt |
| **S2-05** | Ticket Management & 4-Hour Cancellation Policy | [`BookingModel`](../lib/models/booking_model.dart): Quy tắc `canCancel` kiểm tra `startsAt - now >= 4h`. Hủy vé thành công cập nhật trạng thái `CANCELLED` và giải phóng slot. | Đạt |
| **S2-06** | Firestore Security Rules & Tests | Siết [`firestore.rules`](../firestore.rules): `users/{uid}/favorites` chỉ owner được CRUD; `venues` & `courts` chỉ cho phép đọc; `bookings` chỉ cho phép tạo `HOLD` và hủy vé của chính mình. | Đạt |

---

## 2. Kết quả kiểm thử tự động

### A. Flutter Unit & Widget Tests
```powershell
flutter test
```
- **Kết quả:** **114/114 tests passed** (Bổ sung toàn diện test cho `PricingEngine`, `VenueRepository`, `BookingRepository`, va chạm slot và chính sách hủy vé trong [`sprint2_booking_test.dart`](../test/sprint2_booking_test.dart)).

### B. Static Code Analysis
```powershell
flutter analyze
```
- **Kết quả:** **No issues found!** (Clean 100%, tuân thủ linter của dự án).

### C. Firestore Security Rules Emulator Tests
```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
cd tools/rules-tests
npm test
```
- **Kết quả:** **8/8 tests passed**:
  - `owner can create, read and edit allowed fields` (Profile)
  - `anonymous and other users cannot read or write profile`
  - `cannot create admin, extra fields, wrong email or forged time`
  - `cannot change protected fields, delete or add unknown fields`
  - `payments and matches collections closed even to a client with an admin claim`
  - `Sprint 2: user can read/write own favorites; other users cannot`
  - `Sprint 2: authenticated user can read venues and courts; cannot write`
  - `Sprint 2: bookings lifecycle - create HOLD, view own, cancel; cannot forge confirmed or view others`

---

## 3. Sẵn sàng cho Sprint 3 (Thanh toán & Thông báo)
Sprint 2 đã cung cấp đầy đủ thực thể `BookingModel` với `id`, `total`, `paid`, `pin` và trạng thái `HOLD` (15 phút). Sprint 3 sẽ kế thừa để:
- Tạo mã VietQR động theo `bookingId` và số tiền cọc/toàn phần.
- Xử lý xác nhận thanh toán chuyển trạng thái booking sang `CONFIRMED`.
