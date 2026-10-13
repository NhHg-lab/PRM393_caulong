# Đăng ký OTP email, lưu account trên Firebase

Chạy app với:

```powershell
flutter run --dart-define=AUTH_MODE=firebaseOtp
```

Luồng đăng ký:

```text
Flutter -> POST /api/auth/firebase/register/send-otp -> Gmail gửi OTP 6 số
Flutter -> POST /api/auth/firebase/register          -> backend kiểm tra OTP
Backend -> Firebase Admin tạo Email/Password user đã xác minh
Backend -> trả Firebase custom token
Flutter -> signInWithCustomToken -> Firebase Authentication
Flutter -> tạo hồ sơ users/{uid} trên Firestore
```

Account và mật khẩu thuộc Firebase Authentication. Backend không lưu mật khẩu;
SQL Server chỉ lưu hash OTP tạm thời, thời hạn và số lần thử.

## Backend cần cấu hình

Trong `courtly-backend/.env`:

```env
DB_PASSWORD=mat_khau_sql_server
MAIL_USERNAME=courtly.noreply@gmail.com
MAIL_PASSWORD=google_app_password_16_ky_tu
FIREBASE_ENABLED=true
FIREBASE_PROJECT_ID=caulong-9b67e
FIREBASE_SERVICE_ACCOUNT_PATH=D:/duong-dan/service-account.json
```

`MAIL_PASSWORD` là Google App Password, không phải mật khẩu Gmail thường.
Service-account JSON chỉ đặt ở backend và phải nằm ngoài Git.

Android emulator dùng backend tại `http://10.0.2.2:8080`. Khi chạy máy thật,
truyền thêm `--dart-define=API_BASE_URL=http://IP_MAY_TINH:8080`.

Chế độ này vẫn dùng Firebase trực tiếp cho đăng nhập email/password, Google,
khôi phục phiên và đặt lại mật khẩu bằng liên kết Firebase.
