# Nhánh `test_OTP` — Flutter

## Đã thực hiện

- Đồng bộ `origin/main` và giải quyết conflict với luồng Firebase OTP.
- Đăng ký bằng OTP email, tạo Firebase Authentication user và đổi Firebase ID
  token sang JWT/refresh token Courtly.
- Nối API thật cho danh sách sân, khung giờ, yêu thích, đặt sân, lịch sử, hủy
  sân và cập nhật hồ sơ.
- Nối dashboard admin: tổng quan, lịch/đóng mở slot, thêm/sửa/đóng sân và
  khóa/mở tài khoản.
- Tự refresh JWT khi API trả 401; phiên được lưu bằng secure storage.
- Ép decode JSON API bằng UTF-8 để tên/địa chỉ tiếng Việt không bị lỗi font.
- Khóa ứng dụng ở chế độ dọc để form xác thực/đặt sân không bị khuất khi
  emulator hoặc thiết bị xoay ngang.
- Giữ giao diện ShuttleZone của `main` cho chế độ mock; `spring` và
  `firebaseOtp` tự dùng màn hình đã nối Courtly API.

## Cách chạy

```powershell
cd D:\PRM393\code\caulong
flutter run --dart-define=AUTH_MODE=firebaseOtp
```

Emulator dùng `http://10.0.2.2:8080`. Máy thật thêm:

```powershell
--dart-define=API_BASE_URL=http://IP_MAY_CHAY_BACKEND:8080
```

## Kiểm tra trước khi push

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug --dart-define=AUTH_MODE=firebaseOtp`
- Cài và mở APK release x86_64 trên Android emulator, kiểm tra process còn
  chạy và không có `FATAL EXCEPTION`/`E/flutter` trong log.

## Chưa phải tích hợp production

- MoMo/VNPay chưa có merchant key và callback xác nhận. Backend giữ trạng thái
  `PENDING`, không giả lập thanh toán thành công.
- Matchmaking và giao diện ShuttleZone ở chế độ mock vẫn là dữ liệu demo trong
  phiên; luồng Courtly API chính chạy ở `spring`/`firebaseOtp`.
- Không commit Firebase service-account, Gmail App Password hay file `.env`.
