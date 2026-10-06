# Courtly

Prototype Flutter cho nền tảng đặt và quản lý sân cầu lông.

## Chức năng đã dựng

- Đăng nhập bằng email/username + mật khẩu, tuỳ chọn ghi nhớ đăng nhập
- Đăng ký có xác minh email bằng mã OTP 6 số
- Quên mật khẩu: đặt lại bằng mã OTP gửi qua email
- Đăng nhập với Google qua Firebase, hoặc tài khoản Google giả để demo/lab
- Màn Splash tự khôi phục phiên đã lưu, tự refresh token khi hết hạn và đồng
  bộ hồ sơ/role từ server (`/users/me`)
- Thông báo cục bộ sau khi đăng nhập thành công
- Phân quyền: chỉ tài khoản admin mới vào được dashboard quản trị
- Trang chủ, tìm sân, yêu thích và hồ sơ
- Chọn sân, ngày, khung giờ và phương thức thanh toán
- Xác nhận đặt sân, xem lịch sử và hủy sân
- Dashboard quản trị với tổng quan doanh thu
- Quản lý lịch đặt/khung giờ, sân và tài khoản

## Chế độ chạy

Chọn bằng `--dart-define` (xem `lib/config/app_config.dart`), phải chạy lại app sau khi đổi:

| `AUTH_MODE`      | Nguồn                                  | OTP đăng ký / quên mật khẩu | Google Sign-In |
| ---------------- | -------------------------------------- | --------------------------- | -------------- |
| _(bỏ trống)_     | Mock trên máy, không cần mạng          | Luôn là `123456`            | Có             |
| `dummyjson`      | API công khai https://dummyjson.com    | Không                       | Không          |
| `spring`         | Backend Spring Boot của nhóm           | Gửi qua email thật          | Có             |
| `firebase`       | Firebase Auth + Firestore, không backend (xem `docs/FIREBASE_DIRECT_MODE.md`) | Liên kết email của Firebase | Có (thật) |

| `GOOGLE_MODE`    | Nút "Đăng nhập với Google"                                             |
| ---------------- | ---------------------------------------------------------------------- |
| _(bỏ trống)_     | Như `firebase` (vì `enableGoogleSignIn = true`)                         |
| `firebase`       | Google Sign-In + Firebase thật                                         |
| `mock`           | Chọn 1 trong 3 tài khoản Google giả, không cần Firebase. Chỉ bản debug |
| `off`            | Tắt                                                                    |

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
flutter run                                                          # mock, Google thật
flutter run --dart-define=GOOGLE_MODE=mock                           # offline hoàn toàn (demo/lab)
flutter run --dart-define=AUTH_MODE=spring                           # backend Spring
flutter run --dart-define=AUTH_MODE=spring --dart-define=GOOGLE_MODE=mock
```

Android emulator gọi backend ở `http://10.0.2.2:8080`, các nền tảng khác dùng
`http://localhost:8080`. Chạy trên máy thật thì ghi đè địa chỉ:

```bash
flutter run --dart-define=AUTH_MODE=spring --dart-define=API_BASE_URL=http://192.168.1.10:8080
```

Các luồng đặt sân, thanh toán và quản trị hiện vẫn dùng dữ liệu mẫu trong bộ nhớ.

## Tài liệu

- [docs/AUTH_MODULE.md](docs/AUTH_MODULE.md): kiến trúc module xác thực, các luồng,
  hợp đồng API, biện pháp bảo mật, khắc phục sự cố
- [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md): cấu hình Firebase / Google Sign-In
- [docs/DEMO_SCRIPT.md](docs/DEMO_SCRIPT.md): kịch bản demo "Bảo mật tài khoản"
- [docs/LAB_SUGGESTIONS.md](docs/LAB_SUGGESTIONS.md): đề xuất 3 bài lab (bản nháp)

## Kiểm thử

```bash
flutter test
```
