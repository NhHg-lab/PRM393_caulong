# Hướng dẫn cấu hình Firebase cho Đăng nhập Google (Courtly)

Tài liệu này dành cho thành viên phụ trách tạo Firebase project. Hiện tại app **đã có sẵn khung code** cho Google Sign-In nhưng đang **tắt** (`AppConfig.enableGoogleSignIn = false`), nên app vẫn build và chạy bình thường khi chưa có Firebase. Làm lần lượt các bước dưới đây để bật tính năng.

> Tìm nhanh mọi chỗ cần sửa trong code: tìm chuỗi `TODO(FIREBASE)`.

## Luồng hoạt động

```
Người dùng bấm "Đăng nhập với Google"
  -> GoogleSignIn.instance.authenticate()          (lấy Google idToken)
  -> FirebaseAuth.signInWithCredential(...)        (đăng nhập Firebase)
  -> user.getIdToken()                             (lấy Firebase ID token)
  -> POST /api/auth/google { idToken }             (backend Spring xác minh token bằng Firebase Admin SDK)
  <- AuthResponse { accessToken, refreshToken, ... } (JWT của hệ thống, app lưu như đăng nhập thường)
```

Code liên quan: `lib/services/firebase_auth_service.dart`, `AuthManager.loginWithGoogle()`, `SpringAuthService.loginWithGoogleIdToken()`.

---

## Bước 1. Tạo Firebase project

1. Vào <https://console.firebase.google.com> → **Add project** (Thêm dự án).
2. Đặt tên, ví dụ `courtly-prm393`. Google Analytics: có thể tắt.
3. Chờ tạo xong rồi vào trang tổng quan của project.

## Bước 2. Thêm app Android

1. Trong trang tổng quan, bấm biểu tượng **Android**.
2. **Android package name**: `vn.courtly.courtly` (phải khớp chính xác `applicationId` trong `android/app/build.gradle.kts`).
3. App nickname: tuỳ ý (ví dụ `Courtly Android`).
4. **Debug signing certificate SHA-1**: xem Bước 3 để lấy, dán vào đây (có thể bổ sung sau trong Project settings).
5. Bấm **Register app**.

## Bước 3. Lấy SHA-1 và SHA-256

Mở terminal tại thư mục gốc project:

```bash
cd android
./gradlew signingReport        # Windows PowerShell/CMD: .\gradlew signingReport
```

Trong kết quả, tìm khối `Variant: debug` → `Config: debug`, chép hai dòng `SHA1:` và `SHA-256:`.

Dán cả hai vào **Project settings → Your apps → (app Android) → Add fingerprint**.

> ⚠️ **Rất quan trọng:** SHA-1 phụ thuộc vào **keystore debug của MỖI máy** (`~/.android/debug.keystore`, Windows: `C:\Users\<tên>\.android\debug.keystore`). Máy của bạn A và bạn B có SHA-1 **khác nhau**. Có 2 cách:
>
> - **Cách 1:** Mỗi thành viên tự chạy `signingReport` và thêm SHA-1 + SHA-256 của mình vào Firebase (một app có thể có nhiều fingerprint).
> - **Cách 2:** Cả nhóm dùng chung một file `debug.keystore`: một người gửi file của mình, những người khác chép đè vào thư mục `.android` của họ (backup file cũ trước). Khi đó chỉ cần đăng ký 1 SHA-1.
>
> Bản release ký bằng keystore khác thì cũng phải thêm SHA-1 của keystore release.

## Bước 4. Bật Google trong Authentication

1. Menu trái: **Build → Authentication → Get started**.
2. Tab **Sign-in method** → chọn **Google** → **Enable**.
3. Chọn **Project support email** → **Save**.
4. Mở lại mục Google vừa bật, phần **Web SDK configuration** có **Web client ID** (dạng `xxxx.apps.googleusercontent.com`). Chép lại để dùng ở Bước 6.

## Bước 5. Tải `google-services.json`

1. **Project settings → Your apps → app Android → tải `google-services.json`**.
   (Nếu đã thêm SHA-1 sau khi tải, hãy **tải lại** file này.)
2. Đặt file vào đúng vị trí: `android/app/google-services.json`.
3. Có commit file này không? File không chứa bí mật tuyệt đối nhưng có API key của project. Nếu nhóm **không muốn commit**, mở `.gitignore` và bỏ comment dòng `android/app/google-services.json`, sau đó gửi file cho nhau qua kênh riêng.

## Bước 6. Bỏ comment các dòng `TODO(FIREBASE)`

1. `android/settings.gradle.kts` — trong khối `plugins { ... }`:

   ```kotlin
   id("com.google.gms.google-services") version "4.4.2" apply false
   ```

   (Có thể dùng phiên bản mới hơn mà Firebase Console gợi ý.)

2. `android/app/build.gradle.kts` — trong khối `plugins { ... }`:

   ```kotlin
   id("com.google.gms.google-services")
   ```

3. `lib/config/app_config.dart`:

   ```dart
   static const bool enableGoogleSignIn = true;
   static const String? googleServerClientId = '<Web client ID ở Bước 4>';
   ```

   `googleServerClientId` là **Web client ID** (không phải Android client ID). Thiếu giá trị này thì trên Android, Google thường không trả về `idToken`.

4. (Tuỳ chọn) Nếu dùng FlutterFire CLI (`flutterfire configure`) để sinh `lib/firebase_options.dart`, sửa hàm `initFirebaseIfEnabled()` trong `lib/services/firebase_auth_service.dart` thành `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`. Cách này bắt buộc nếu muốn chạy Google Sign-In trên **web**.

5. Chạy lại từ đầu (không hot reload):

   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## Bước 7. Service account cho backend Spring

Backend cần xác minh Firebase ID token mà app gửi lên `POST /api/auth/google`:

1. **Project settings → Service accounts → Firebase Admin SDK → Generate new private key**.
2. Tải file JSON về, **KHÔNG commit** file này vào bất kỳ repo nào (đây là bí mật thật sự).
3. Cấu hình backend đọc file đó (thường qua biến môi trường, ví dụ `GOOGLE_APPLICATION_CREDENTIALS` hoặc một property trỏ tới đường dẫn file). Làm theo hướng dẫn trong tài liệu của **repo backend** (phần cấu hình Firebase Admin SDK).
4. Backend phải dùng **cùng Firebase project** với app.

## Bước 8. Kiểm tra

1. Đặt `AppConfig.authMode = AuthMode.spring` và chạy backend (hoặc giữ `AuthMode.mock` để chỉ thử phần Google/Firebase phía app: mock chấp nhận mọi ID token).
2. Mở app → **Đăng nhập với Google** → chọn tài khoản.
3. Thành công: vào màn Khám phá, có thông báo "Đăng nhập thành công". Trong Firebase Console → Authentication → Users sẽ thấy tài khoản vừa đăng nhập.

---

## Lỗi thường gặp

| Hiện tượng / mã lỗi | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| SnackBar "Đăng nhập Google chưa được cấu hình" | `enableGoogleSignIn = false` hoặc `Firebase.initializeApp()` thất bại | Kiểm tra Bước 5–6; xem log `Firebase chưa được cấu hình` trong console |
| `DEVELOPER_ERROR` / `ApiException: 10` / lỗi `clientConfigurationError` | SHA-1 của máy đang chạy chưa được thêm, package name sai, hoặc `google-services.json` cũ | Chạy lại `signingReport`, thêm SHA-1 + SHA-256 của **máy này**, tải lại `google-services.json`, `flutter clean` |
| Không lấy được `idToken` ("Không lấy được thông tin từ Google") | Thiếu hoặc sai `googleServerClientId` | Dùng **Web client ID** (Authentication → Google → Web SDK configuration) |
| Build lỗi `File google-services.json is missing` | Đã bỏ comment plugin `google-services` nhưng chưa đặt file | Đặt file vào `android/app/` hoặc comment lại plugin |
| Build lỗi `No matching client found for package name` | Package trong Firebase khác `vn.courtly.courtly` | Thêm lại app Android với đúng package |
| Emulator không hiện hộp chọn tài khoản / lỗi Google Play Services | Emulator dùng system image **không có Google Play** | Tạo AVD mới với image có biểu tượng Play Store (Google Play), đăng nhập tài khoản Google trong emulator |
| Bạn A đăng nhập được, bạn B thì không | Mỗi máy một debug keystore khác SHA-1 | Thêm SHA-1 của bạn B, hoặc dùng chung `debug.keystore` (Bước 3) |
| `canceled` / "Bạn đã huỷ đăng nhập Google" | Người dùng đóng hộp chọn tài khoản, hoặc cấu hình sai khiến hộp thoại tự đóng | Nếu không chủ động huỷ, kiểm tra lại SHA-1 và client ID |
| Backend trả 401 ở `/api/auth/google` | Backend dùng service account của project khác, hoặc token hết hạn | Kiểm tra Bước 7, đồng bộ giờ hệ thống của máy chạy backend |
