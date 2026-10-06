# Courtly

Prototype Flutter cho nền tảng đặt và quản lý sân cầu lông.

## Chức năng đã dựng

- Đăng nhập bằng email/username + mật khẩu, tuỳ chọn ghi nhớ đăng nhập
- Đăng ký có xác minh email bằng mã OTP 6 số
- Đăng nhập với Google qua Firebase
- Màn Splash tự khôi phục phiên đã lưu, tự refresh token khi hết hạn
- Thông báo cục bộ sau khi đăng nhập thành công
- Phân quyền: chỉ tài khoản admin mới vào được dashboard quản trị
- Trang chủ, tìm sân, yêu thích và hồ sơ
- Chọn sân, ngày, khung giờ và phương thức thanh toán
- Xác nhận đặt sân, xem lịch sử và hủy sân
- Dashboard quản trị với tổng quan doanh thu
- Quản lý lịch đặt/khung giờ, sân và tài khoản

## Chế độ xác thực

Nguồn xác thực chọn bằng `--dart-define=AUTH_MODE=...` (xem `lib/config/app_config.dart`):

| `AUTH_MODE`      | Nguồn                                  | OTP đăng ký             | Google Sign-In |
| ---------------- | -------------------------------------- | ----------------------- | -------------- |
| _(bỏ trống)_     | Mock trên máy, không cần mạng          | Luôn là `123456`        | Có (*)         |
| `dummyjson`      | API công khai https://dummyjson.com    | Không                   | Không          |
| `spring`         | Backend Spring Boot của nhóm           | Gửi qua email thật      | Có             |

(*) Vẫn đăng nhập Google/Firebase thật, nhưng bước đổi token sang phiên của hệ thống được giả lập trên máy.

Tài khoản có sẵn:

| Chế độ      | Khách hàng                        | Quản trị                     |
| ----------- | --------------------------------- | ---------------------------- |
| mock        | `demo@courtly.vn` / `123456`      | `admin@courtly.vn` / `Admin@123` |
| dummyjson   | `emilys` / `emilyspass`           | —                            |
| spring      | `customer@courtly.vn` / `123456`  | `admin@courtly.vn` / `123456` |

Nút "Khám phá với tài khoản demo" đăng nhập bằng tài khoản khách hàng của chế độ đang chạy.

Phiên đăng nhập được lưu bằng `flutter_secure_storage` (Keystore/Keychain).

## Đăng nhập Google

```
Google -> Firebase Auth -> Firebase ID token
       -> POST /api/auth/google { idToken }   (backend xác minh bằng Firebase Admin SDK)
       <- access token + refresh token của hệ thống
```

Firebase đã được bật (`AppConfig.enableGoogleSignIn = true`) với cấu hình trong
`android/app/google-services.json` (package `vn.courtly.courtly`). Mỗi thành viên
cần thêm SHA-1 và SHA-256 của debug keystore trên máy mình vào Firebase Console,
nếu không Google Sign-In trên Android sẽ lỗi. Chi tiết xem
[docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md).

Ứng dụng Flutter không cần file service-account của Firebase Admin; file đó chỉ
đặt ở backend.

## Chạy ứng dụng

```bash
flutter pub get
flutter run                                    # chế độ mock
flutter run --dart-define=AUTH_MODE=spring     # dùng backend Spring
```

Android emulator gọi backend ở `http://10.0.2.2:8080`, các nền tảng khác dùng
`http://localhost:8080`. Chạy trên máy thật thì ghi đè địa chỉ:

```bash
flutter run --dart-define=AUTH_MODE=spring --dart-define=API_BASE_URL=http://192.168.1.10:8080
```

Các luồng đặt sân, thanh toán và quản trị hiện vẫn dùng dữ liệu mẫu trong bộ nhớ.
Chức năng "Quên mật khẩu" chưa được làm.

## Kiểm thử

```bash
flutter test
```
