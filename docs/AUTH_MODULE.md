# Module xác thực Courtly

Tài liệu cho nhóm và cho buổi trình bày "Bảo mật tài khoản". Mô tả phía app Flutter; phía server xem repo `badminton_backend` (README và `docs/AUTH_BACKEND.md`).

## 1. Kiến trúc

```
   UI (AuthScreen, OtpVerifyScreen, ForgotPasswordScreen, SplashScreen)
        │  chỉ gọi AuthManager, không gọi HTTP trực tiếp
        ▼
   AuthManager  (ChangeNotifier, singleton)
   - giữ trạng thái: unknown (Splash) / authenticated / unauthenticated
   - restoreSession, login, signup, loginWithGoogle, resetPassword, logout
   - refreshSession dùng chung, nhiều request 401 cùng lúc chỉ refresh 1 lần
        │                         │                          │
        ▼                         ▼                          ▼
   AuthService               SessionStorage            GoogleTokenProvider
   (chọn theo AUTH_MODE)     (Secure / Prefs / Memory)  (Firebase thật / Mock)
   ├─ MockAuthService        lưu access + refresh       lấy Google/Firebase ID token
   ├─ DummyJsonAuthService   token, hạn, hồ sơ
   └─ SpringAuthService ───► backend /api/auth/*, /api/users/me

   ApiClient: dùng cho các API cần đăng nhập. Tự gắn Bearer, gặp 401 thì
   refresh 1 lần rồi gửi lại; refresh hỏng thì logout -> main.dart về Login.
```

| Thành phần | File | Vai trò |
|---|---|---|
| `AppConfig` | `lib/config/app_config.dart` | Chọn chế độ (`AUTH_MODE`, `GOOGLE_MODE`, `API_BASE_URL`), timeout |
| `AuthManager` | `lib/services/auth_manager.dart` | Nguồn sự thật duy nhất về đăng nhập; UI chỉ nói chuyện với lớp này |
| `AuthService` | `lib/services/auth_service.dart` | Hợp đồng chung + 3 cài đặt (mock, DummyJSON, Spring) |
| `SessionStorage` | `lib/services/session_storage.dart` | `SecureSessionStorage` (Keystore/Keychain, mặc định), `PrefsSessionStorage` (Lab 10.3, không mã hoá), `MemorySessionStorage` (test) |
| `ApiClient` | `lib/services/api_client.dart` | HTTP có Bearer + tự refresh |
| `GoogleTokenProvider` | `lib/services/google_token_provider.dart` | `FirebaseGoogleTokenProvider` (bọc `FirebaseAuthService`), `MockGoogleTokenProvider` |
| `FirebaseAuthService` | `lib/services/firebase_auth_service.dart` | Google Sign-In + Firebase Auth thật |
| Widget OTP dùng chung | `lib/widgets/otp_widgets.dart` | Mixin đếm ngược, ô nhập mã, dòng hạn mã, nút gửi lại |

### Chức năng theo chế độ

| | mock | dummyjson | spring |
|---|---|---|---|
| Đăng nhập | Có | Có (username) | Có |
| Đăng ký có OTP email | Có (OTP luôn `123456`) | Không OTP | Có (gửi Gmail thật) |
| Quên mật khẩu bằng OTP | Có (OTP luôn `123456`) | Không | Có |
| Đăng nhập Google | Có | Không | Có |
| Đồng bộ `/users/me` khi mở app | Không cần | Không | Có |
| Refresh token | Giả lập | Có | Có, xoay vòng |

## 2. Chế độ chạy

| Biến (`--dart-define`) | Giá trị | Mặc định | Ý nghĩa |
|---|---|---|---|
| `AUTH_MODE` | `spring`, `dummyjson`, bỏ trống | mock | Nguồn xác thực |
| `GOOGLE_MODE` | `firebase`, `mock`, `off` | `firebase` (vì `enableGoogleSignIn = true`) | Cách lấy Google ID token |
| `API_BASE_URL` | ví dụ `http://192.168.1.10:8080` | emulator `http://10.0.2.2:8080`, còn lại `http://localhost:8080` | Địa chỉ backend (không có `/` cuối, không có `/api`) |

Bản release (`flutter run --release`, `flutter build`) **không bao giờ** dùng `GOOGLE_MODE=mock`: nếu được truyền vào, app tự rơi về giá trị mặc định (Firebase thật).

### Lệnh theo kịch bản

```bash
# 1. Offline hoàn toàn: không cần backend, không cần Firebase (dùng cho lab/dự phòng)
flutter run --dart-define=GOOGLE_MODE=mock

# 2. Như (1) nhưng Google qua Firebase thật (cần SHA-1 của máy đã thêm vào Firebase)
flutter run

# 3. Backend thật trên emulator, Google giả (backend bật GOOGLE_MOCK_ENABLED=true)
flutter run --dart-define=AUTH_MODE=spring --dart-define=GOOGLE_MODE=mock

# 4. Backend thật, Google + Firebase thật (backend bật FIREBASE_ENABLED=true)
flutter run --dart-define=AUTH_MODE=spring

# 5. Máy thật cắm USB / cùng Wi-Fi với máy chạy backend
flutter run --dart-define=AUTH_MODE=spring --dart-define=API_BASE_URL=http://192.168.1.10:8080

# 6. API công khai DummyJSON (Lab 10)
flutter run --dart-define=AUTH_MODE=dummyjson --dart-define=GOOGLE_MODE=off
```

Đổi `--dart-define` thì phải dừng app và chạy lại (hot reload không áp dụng).

### Tài khoản test

| Chế độ | Khách hàng | Quản trị | OTP |
|---|---|---|---|
| mock | `demo@courtly.vn` / `123456` | `admin@courtly.vn` / `Admin@123` | luôn `123456` |
| spring | `customer@courtly.vn` / `123456` | `admin@courtly.vn` / `123456` | gửi qua email thật |
| dummyjson | `emilys` / `emilyspass` | không có | không dùng |

Google giả (`GOOGLE_MODE=mock`): Trần Minh `minh.tran@gmail.com`, Nguyễn Lan `lan.nguyen@gmail.com`, Phạm Khoa `khoa.pham@gmail.com`.

Ở chế độ mock, tài khoản đăng ký mới và mật khẩu đã đặt lại chỉ sống tới khi tắt app.

## 3. Hợp đồng API (SpringAuthService)

| Phương thức | Đường dẫn | Body | Phản hồi |
|---|---|---|---|
| POST | `/api/auth/register/send-otp` | `{ email }` | `{ message, expiresIn, resendAfter }` |
| POST | `/api/auth/register` | `{ fullName, email, phone?, password, otp }` | AuthResponse |
| POST | `/api/auth/login` | `{ identifier, password }` | AuthResponse |
| POST | `/api/auth/google` | `{ idToken }` | AuthResponse |
| POST | `/api/auth/refresh` | `{ refreshToken }` | AuthResponse (refresh token mới) |
| POST | `/api/auth/logout` | `{ refreshToken }` + Bearer | 2xx |
| POST | `/api/auth/password/forgot` | `{ email }` | luôn 200 `{ message, expiresIn, resendAfter }` |
| POST | `/api/auth/password/reset` | `{ email, otp, newPassword }` | 200 `{ message }`, không có token |
| GET | `/api/users/me` | Bearer | `UserDto { id, fullName, email, phone, role, avatarUrl, authProvider }` |

AuthResponse: `{ accessToken, refreshToken, tokenType, expiresIn, user: UserDto }`.

Lỗi: `{ timestamp, status, error, message, path, fieldErrors? }`. App hiển thị thẳng `message` của server (`AuthException.fromHttp`). Mã thường gặp: 400 (OTP sai/hết hạn, mật khẩu yếu), 401 (sai thông tin, token hết hạn), 403 (không đủ quyền, tài khoản bị khoá), 409 (email đã dùng), 429 (gửi quá nhanh/quá nhiều), 503 (backend chưa cấu hình mail).

## 4. Các luồng

### 4.1 Đăng ký có OTP email

```
AuthScreen (form đăng ký, validate phía app)
  └─ POST /auth/register/send-otp { email }
       ├─ 409 email đã dùng / 429 gửi quá nhanh / 503 chưa cấu hình mail -> SnackBar
       └─ 200 { expiresIn, resendAfter }
            └─ OtpVerifyScreen: đếm ngược hạn mã + thời gian chờ gửi lại
                 └─ POST /auth/register { ..., otp }
                      ├─ 400 mã sai/hết hạn -> báo lỗi ngay dưới ô mã
                      └─ 201 AuthResponse -> lưu phiên -> Home
```

Tài khoản chỉ được tạo khi mã đúng, nên không ai đăng ký được bằng email của người khác.

### 4.2 Quên mật khẩu

```
AuthScreen "Quên mật khẩu?" -> ForgotPasswordScreen
  Bước 1: nhập email
    └─ POST /auth/password/forgot { email }
         └─ luôn 200 với cùng một thông điệp (email có tồn tại hay không)
  Bước 2: nhập OTP + mật khẩu mới + xác nhận (đếm ngược, "Gửi lại mã")
    └─ POST /auth/password/reset { email, otp, newPassword }
         ├─ 400 "Mã OTP không hợp lệ hoặc đã hết hạn." / mật khẩu yếu -> báo lỗi
         └─ 200 -> về màn đăng nhập, điền sẵn email,
                   SnackBar "Đặt lại mật khẩu thành công, hãy đăng nhập lại"
```

Reset không trả token: người dùng phải đăng nhập lại. Backend đồng thời thu hồi mọi refresh token cũ của tài khoản, nên các máy đang đăng nhập bằng mật khẩu cũ sẽ bị đăng xuất khi access token hết hạn.

### 4.3 Đăng nhập Google

```
GOOGLE_MODE=firebase (thật)
  GoogleSignIn.authenticate() -> Google idToken
  -> FirebaseAuth.signInWithCredential -> Firebase ID token (JWT do Google ký)
  -> POST /auth/google { idToken }
  -> backend xác minh chữ ký bằng Firebase Admin SDK -> AuthResponse

GOOGLE_MODE=mock (demo/lab)
  Bottom sheet "Chọn tài khoản Google (DEMO)" -> chọn 1 trong 3 tài khoản giả
  -> token "mock:<email>:<tên>"
  -> POST /auth/google { idToken }   (cùng đường với bản thật)
     - AUTH_MODE mock: MockAuthService đọc token, trả đúng user đó
     - AUTH_MODE spring: backend chỉ nhận khi bật GOOGLE_MOCK_ENABLED=true

GOOGLE_MODE=off
  -> SnackBar "Đăng nhập Google chưa được bật"
```

Đăng xuất tài khoản Google giả không gọi Firebase. Backend ở chế độ mock không cho token giả đăng nhập vào tài khoản đã có sẵn (LOCAL, ADMIN, Google thật).

### 4.4 Giữ phiên và refresh token xoay vòng

```
Mở app -> SplashScreen (AuthStatus.unknown)
  └─ AuthManager.restoreSession()
       ├─ storage trống -> Login
       ├─ access token hết hạn -> POST /auth/refresh
       │     ├─ hỏng -> xoá phiên -> Login
       │     └─ ok -> lưu cặp token MỚI (token cũ bị thu hồi)
       └─ GET /users/me (tối đa 5 giây)
             ├─ 200 -> cập nhật hồ sơ/role vào bộ nhớ và storage -> Home/Admin
             ├─ 401/403 (bị khoá/xoá) -> xoá phiên -> Login
             └─ lỗi mạng / timeout / 5xx -> giữ phiên đã lưu -> Home (dùng offline được)

Trong lúc dùng app (ApiClient)
  request -> 401 -> refreshSession() một lần -> gửi lại
                    └─ vẫn hỏng -> logout -> Login

Đăng xuất: xoá storage -> POST /auth/logout (thu hồi refresh token) -> Login
```

Xoay vòng: mỗi lần refresh, server cấp refresh token mới và đánh dấu token cũ là đã thay thế. Nếu một token cũ bị dùng lại (dấu hiệu token bị đánh cắp), server thu hồi **toàn bộ** phiên của tài khoản đó.

"Ghi nhớ đăng nhập" bỏ chọn: phiên chỉ nằm trong RAM, tắt app là phải đăng nhập lại.

## 5. Biện pháp bảo mật và nó chống lại điều gì

| Biện pháp | Ở đâu | Chống lại |
|---|---|---|
| Mật khẩu băm BCrypt, so sánh thời gian đều kể cả khi email không tồn tại | Backend | Lộ database vẫn không đọc được mật khẩu; đoán email qua thời gian phản hồi |
| Access token JWT ngắn hạn (30 phút) | Backend | Token bị lộ chỉ dùng được trong thời gian ngắn |
| Refresh token ngẫu nhiên 256-bit, DB chỉ lưu SHA-256, hạn 7 ngày | Backend | Lộ database không dùng được refresh token |
| Refresh token xoay vòng + phát hiện dùng lại | Backend + `AuthManager` lưu cặp mới | Kẻ trộm token cũ: dùng lại là toàn bộ phiên bị thu hồi |
| OTP 6 số, DB chỉ lưu BCrypt của mã, hạn 5 phút | Backend | Lộ database không lộ mã; mã cũ hết tác dụng |
| Giới hạn 5 lần nhập sai mỗi mã | Backend | Dò mã 6 số (1.000.000 khả năng) |
| Chờ 60 giây giữa 2 lần gửi, tối đa 5 lần/giờ (429) | Backend + nút "Gửi lại mã" bị khoá | Spam email, dò mã bằng cách xin mã liên tục |
| Quên mật khẩu luôn trả cùng một phản hồi; reset sai email hay sai mã cùng một lỗi | Backend + `MockAuthService` | Dò xem email nào đã đăng ký (user enumeration) |
| Reset mật khẩu thu hồi mọi refresh token | Backend | Kẻ đã đăng nhập bằng mật khẩu cũ vẫn ở lại |
| Token lưu trong `flutter_secure_storage` (Keystore/Keychain) | `SecureSessionStorage` | App khác hoặc người lấy được file dữ liệu đọc token |
| Phân quyền ở server (`@PreAuthorize("hasRole('ADMIN')")`), app chỉ ẩn/hiện nút | Backend + `main.dart` | Sửa app để vào trang admin: API vẫn trả 403 |
| Đồng bộ `/users/me` khi mở app | `AuthManager.restoreSession` | Tài khoản bị khoá/hạ quyền vẫn dùng hồ sơ cũ trong máy |
| Google: backend tự xác minh Firebase ID token bằng Admin SDK | Backend | App giả mạo gửi email tuỳ ý để đăng nhập |
| Google giả chỉ có ở debug (`kReleaseMode`) và backend từ chối khởi động nếu bật mock ở `prod` | `AppConfig.googleMode` + backend | Quên tắt chế độ demo khi phát hành |
| Không in token/OTP ra log | Toàn bộ | Lộ bí mật qua logcat/crash report |

## 6. Khắc phục sự cố

| Hiện tượng | Nguyên nhân | Cách xử lý |
|---|---|---|
| "Không thể kết nối máy chủ" trên emulator | Gọi `localhost` thay vì máy host | Emulator dùng `10.0.2.2` (mặc định đã đúng). Đừng truyền `API_BASE_URL=http://localhost:8080` cho emulator |
| Máy thật không gọi được backend | Khác mạng, sai IP, hoặc Windows Firewall chặn cổng 8080 | Cùng Wi-Fi, `ipconfig` lấy IPv4, truyền `API_BASE_URL=http://<IP>:8080`, mở cổng 8080 (Inbound Rule) cho mạng Private |
| Lỗi `Insecure HTTP is not allowed by platform` / `Cleartext HTTP traffic not permitted` | Android 9+ chặn HTTP thường (không phải HTTPS) theo mặc định, kể cả bản debug. Repo hiện **chưa** cấu hình cho phép | Thêm `<application android:usesCleartextTraffic="true" />` vào `android/app/src/debug/AndroidManifest.xml` (chỉ bản debug; hiện file này chưa có thẻ `<application>`), hoặc dùng HTTPS. Không bật trong manifest `main` |
| 503 khi gửi OTP | Backend chưa cấu hình mail | Đặt `MAIL_USERNAME` + `MAIL_PASSWORD` trong `.env` của backend |
| Gmail báo `535 Username and Password not accepted` (log backend) | Dùng mật khẩu Gmail thường | Bật xác minh 2 bước, tạo **App Password** 16 ký tự, dán vào `MAIL_PASSWORD` |
| Không thấy email OTP | Mail vào Spam/Promotions, hoặc gửi quá 5 lần/giờ | Kiểm tra Spam; đợi hết giới hạn; demo thì chuyển sang mock |
| 429 "Vui lòng đợi..." | Gửi lại mã quá nhanh | Đợi hết thời gian trên nút "Gửi lại mã" |
| `DEVELOPER_ERROR` / `ApiException: 10` khi đăng nhập Google | SHA-1 của máy chưa thêm vào Firebase, hoặc `google-services.json` cũ | `cd android && .\gradlew signingReport`, thêm SHA-1 + SHA-256 vào Firebase Console, tải lại `google-services.json`, `flutter clean`. Xem [FIREBASE_SETUP.md](FIREBASE_SETUP.md) |
| "Đăng nhập Google chưa được cấu hình" | `Firebase.initializeApp()` thất bại | Xem log `Firebase chưa được cấu hình`; demo thì chạy `GOOGLE_MODE=mock` |
| Backend trả 401 ở `/auth/google` với token giả | Backend chưa bật `GOOGLE_MOCK_ENABLED=true` | Bật trên backend (và `FIREBASE_ENABLED=false`), hoặc dùng `AUTH_MODE` mock |
| Mở app bị đá về Login dù đã "ghi nhớ" | Refresh token hết hạn (7 ngày), bị thu hồi (đổi mật khẩu, phát hiện dùng lại) hoặc tài khoản bị khoá | Đăng nhập lại; đây là hành vi đúng |
