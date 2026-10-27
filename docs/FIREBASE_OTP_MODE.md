# Firebase OTP + Courtly API

Chạy app trên Android emulator:

```powershell
flutter run --dart-define=AUTH_MODE=firebaseOtp
```

Luồng đăng ký và đăng nhập:

```text
Flutter -> POST /api/auth/firebase/register/send-otp -> Gmail gửi OTP 6 số
Flutter -> POST /api/auth/firebase/register          -> backend kiểm tra OTP
Backend -> Firebase Admin tạo Email/Password user và trả custom token
Flutter -> signInWithCustomToken -> Firebase ID token
Flutter -> POST /api/auth/firebase -> JWT + refresh token Courtly
Flutter -> JWT Courtly -> API sân, booking, hồ sơ và admin
```

Firebase Authentication giữ email và mật khẩu. Backend không lưu mật khẩu
Firebase; SQL Server lưu hồ sơ Courtly tương ứng, refresh token, OTP đã băm và
dữ liệu nghiệp vụ. Flutter không chứa service-account JSON.

Backend cần cấu hình trong `.env`:

```env
DB_PASSWORD=mat_khau_sql_server
MAIL_USERNAME=courtly.noreply@gmail.com
MAIL_PASSWORD=google_app_password_16_ky_tu
FIREBASE_ENABLED=true
FIREBASE_PROJECT_ID=caulong-9b67e
FIREBASE_SERVICE_ACCOUNT_PATH=D:/duong-dan/service-account.json
```

`MAIL_PASSWORD` là Google App Password. Service-account chỉ đặt ở backend,
nằm ngoài Git. Android emulator gọi host qua `http://10.0.2.2:8080`; máy thật
phải truyền `API_BASE_URL` bằng IP LAN của máy chạy backend.
