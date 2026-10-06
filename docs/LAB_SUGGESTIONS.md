# Đề xuất bài lab "Bảo mật tài khoản" (bản nháp)

Ba câu ngắn, mỗi câu khoảng 30-45 phút. Tất cả chạy **hoàn toàn ở chế độ mock**: không cần backend, Gmail hay tài khoản Firebase. Có thể phát cho sinh viên bản repo đã xoá phần lời giải (các file ghi ở mục "Tham chiếu"), hoặc một project trống chỉ có `AuthService` mock.

Lệnh chạy chung:

```bash
flutter run --dart-define=GOOGLE_MODE=mock
flutter test
```

Mã OTP ở chế độ mock luôn là `123456`. Tài khoản: `demo@courtly.vn` / `123456`.

---

## Lab 1. Màn nhập OTP email có đếm ngược và gửi lại

**Mục tiêu.** Hiểu vì sao OTP cần thời hạn và thời gian chờ gửi lại; quản lý `Timer` đúng vòng đời widget.

**Mô tả.** Cho sẵn `AuthService.sendRegisterOtp(email)` trả về `OtpSent { message, expiresIn, resendAfter }` và `AuthService.signup(request)` nhận thêm `otp`. Làm màn `OtpVerifyScreen`:
1. Hiện `message`, một ô nhập 6 chữ số (chỉ cho nhập số, tối đa 6 ký tự).
2. Dòng "Mã còn hiệu lực trong mm:ss" đếm ngược từ `expiresIn`; về 0 thì đổi thành "Mã đã hết hạn" màu đỏ và khoá nút xác nhận.
3. Nút "Gửi lại mã sau Ns" bị khoá trong `resendAfter` giây; hết thời gian thì bấm được, gọi lại `sendRegisterOtp` và đặt lại cả hai bộ đếm.
4. Nút "Xác nhận": validate 6 số, gọi `signup`, hiện loading và khoá nút khi đang gửi; mã sai thì hiện lỗi dưới ô nhập.

**Tiêu chí đạt.**
- Nhập `000000` -> báo lỗi, không tạo tài khoản; nhập `123456` -> vào Home.
- Nút gửi lại bị khoá đúng thời gian, bấm lại thì bộ đếm chạy lại từ đầu.
- Rời màn khi đang đếm không có lỗi `setState() called after dispose()` trong console.
- Có ít nhất 1 widget test cho trường hợp mã sai.

**Gợi ý.**
- `Timer.periodic(const Duration(seconds: 1), ...)`, huỷ trong `dispose()`, kiểm tra `mounted` trong callback.
- `FilteringTextInputFormatter.digitsOnly` + `LengthLimitingTextInputFormatter(6)`.
- Trong widget test, **không** dùng `pumpAndSettle()` khi màn có `Timer.periodic` đang chạy (sẽ treo tới timeout); dùng `pump(const Duration(milliseconds: 100))`.
- Câu hỏi thảo luận: vì sao server phải kiểm tra hạn mã và giới hạn gửi lại, dù app đã khoá nút?

**Tham chiếu.** `lib/screens/otp_verify_screen.dart`, `lib/widgets/otp_widgets.dart`, test `register asks for the emailed OTP...` trong `test/widget_test.dart`.

---

## Lab 2. Đăng nhập Google qua Firebase (làm bản mock trước)

**Mục tiêu.** Hiểu luồng đăng nhập bên thứ 3: app chỉ lấy **ID token**, server mới xác minh và cấp phiên. Tách phần phụ thuộc bên ngoài sau một interface để test và demo được khi không có Firebase.

**Mô tả.**
1. Định nghĩa interface:
   ```dart
   abstract interface class GoogleTokenProvider {
     Future<String> obtainIdToken();
     Future<void> signOut();
   }
   ```
2. Làm `MockGoogleTokenProvider` trả về token `mock:<email>:<tên>` của tài khoản được chọn.
3. Bấm "Đăng nhập với Google" -> bottom sheet "Chọn tài khoản Google (DEMO)" với 3 tài khoản giả và nhãn rõ "Chế độ demo, không phải Google thật". Chọn một tài khoản -> gọi `AuthService.loginWithGoogleIdToken(token)` -> vào Home với đúng tên/email đó. Đóng sheet thì không làm gì.
4. Trong `MockAuthService.loginWithGoogleIdToken`, đọc token giả để trả về user có `authProvider = 'GOOGLE'`.
5. (Mở rộng, không bắt buộc) Làm `FirebaseGoogleTokenProvider` bằng `google_sign_in` + `firebase_auth` theo [FIREBASE_SETUP.md](FIREBASE_SETUP.md). Màn hình không phải sửa gì vì chỉ phụ thuộc interface.

**Tiêu chí đạt.**
- Chọn tài khoản giả -> vào Home, tab Cá nhân hiện đúng tên và email đã chọn.
- Đăng xuất tài khoản Google giả không gọi tới Firebase.
- Bản release không thể bật chế độ giả (kiểm tra `kReleaseMode`).
- Unit test cho hàm đọc token giả: đúng dạng, thiếu tên, email sai, tên có dấu `:`.

**Gợi ý.**
- `showModalBottomSheet<T>` trả về giá trị qua `Navigator.pop(context, value)`; nhớ `isScrollControlled: true` nếu nội dung cao.
- Chọn chế độ bằng `--dart-define=GOOGLE_MODE=mock` và `String.fromEnvironment`; vì đó là hằng lúc build, để một biến `@visibleForTesting` cho test ghi đè.
- Câu hỏi thảo luận: nếu server tin luôn email trong token giả thì kẻ gian làm được gì? Vì sao backend thật phải xác minh chữ ký Firebase ID token?

**Tham chiếu.** `lib/services/google_token_provider.dart`, `lib/widgets/mock_google_picker.dart`, `AppConfig.googleMode`, `_loginWithGoogle` trong `lib/screens/auth_screen.dart`.

---

## Lab 3. Giữ phiên an toàn (secure storage, tự đăng nhập, refresh token)

**Mục tiêu.** Lưu token đúng chỗ, tự đăng nhập khi mở lại app, tự làm mới access token khi hết hạn.

**Mô tả.**
1. `SessionStorage` có 2 cài đặt: `SecureSessionStorage` (`flutter_secure_storage`) và `MemorySessionStorage` (cho test). Lưu access token, refresh token, thời điểm hết hạn, hồ sơ user.
2. `AuthManager.restoreSession()` chạy lúc mở app (hiện Splash):
   - không có phiên -> Login;
   - access token còn hạn -> Home;
   - hết hạn -> gọi `refresh`; thành công thì lưu cặp token **mới** rồi vào Home, thất bại thì xoá phiên -> Login.
3. Checkbox "Ghi nhớ đăng nhập": bỏ chọn thì phiên chỉ nằm trong bộ nhớ.
4. Đăng xuất xoá sạch storage.
5. (Mở rộng) `ApiClient` tự gắn `Authorization: Bearer`, gặp 401 thì refresh **một lần** rồi gửi lại; vẫn 401 thì đăng xuất.

**Tiêu chí đạt.**
- Đăng nhập có "Ghi nhớ" -> tắt hẳn app -> mở lại vào thẳng Home. Bỏ "Ghi nhớ" -> mở lại phải đăng nhập.
- Unit test với `MemorySessionStorage`: phiên hết hạn được refresh; refresh token sai -> unauthenticated và storage trống; logout xoá storage.
- (Mở rộng) Test `ApiClient` bằng `MockClient` của package `http`: 401 -> refresh -> gửi lại với token mới.

**Gợi ý.**
- Coi token hết hạn sớm khoảng 30 giây để tránh gửi token sắp chết.
- Nhiều request cùng gặp 401: giữ một `Future` refresh dùng chung để chỉ refresh một lần.
- Không `print` token ra console.
- Câu hỏi thảo luận: so sánh `shared_preferences` và `flutter_secure_storage`; vì sao refresh token cần xoay vòng?

**Tham chiếu.** `lib/services/session_storage.dart`, `lib/services/auth_manager.dart`, `lib/services/api_client.dart`, nhóm test `AuthManager` và `ApiClient` trong `test/auth_service_test.dart`.
