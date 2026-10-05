# Courtly

Prototype Flutter cho nền tảng đặt và quản lý sân cầu lông.

## Chức năng đã dựng

- Firebase Authentication: đăng ký/đăng nhập Email + Password, xác minh email,
  đặt lại mật khẩu và Google Sign-In
- Firebase tự lưu và khôi phục phiên đăng nhập trên thiết bị
- Tài khoản demo để xem nhanh giao diện khách hàng và quản trị
- Trang chủ, tìm sân, yêu thích và hồ sơ
- Chọn sân, ngày, khung giờ và phương thức thanh toán
- Xác nhận đặt sân, xem lịch sử và hủy sân
- Dashboard quản trị với tổng quan doanh thu
- Quản lý lịch đặt/khung giờ, sân và tài khoản

## Cấu hình Android

- Firebase Android app dùng package `vn.courtly.courtly`.
- Đặt file cấu hình tại `android/app/google-services.json`.
- Bật Email/Password và Google trong Firebase Authentication.
- Thêm SHA-1 và SHA-256 của debug keystore vào Firebase Console.

Ứng dụng Flutter không cần Firebase Admin service-account và không cần backend
để đăng ký/đăng nhập. Firebase Admin JSON chỉ dành cho server nếu phát triển
backend ở giai đoạn sau.

## Chạy ứng dụng

```bash
flutter pub get
flutter run
```

Xác thực đã dùng Firebase thật. Các luồng đặt sân, thanh toán và quản trị hiện
vẫn dùng dữ liệu mẫu trong bộ nhớ để trình diễn giao diện.
