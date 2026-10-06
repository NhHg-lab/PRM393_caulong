# Chế độ Firebase trực tiếp (`AUTH_MODE=firebase`)

Flutter nối thẳng Firebase, **không cần backend Spring Boot, SQL Server hay Docker**. Dùng để demo phần "bên thứ 3 / Firebase".

| Việc | Do ai làm |
|---|---|
| Đăng ký, đăng nhập email + mật khẩu, đăng nhập Google, đặt lại mật khẩu | Firebase Authentication |
| Hồ sơ người dùng (họ tên, SĐT, vai trò, nhà cung cấp đăng nhập) | Cloud Firestore, collection `users/{uid}` |
| Xác minh email | Firebase gửi email xác minh sau khi đăng ký (liên kết, **không** phải OTP 6 số) |
| Quên mật khẩu | Firebase gửi liên kết đặt lại mật khẩu qua email |
| Phân quyền admin | Sửa tay trường `role` thành `ADMIN` trong Firebase Console |

SQL Server và OTP Gmail của backend **không được dùng** ở chế độ này. Muốn quay lại luồng backend thì chạy với `AUTH_MODE=spring`.

## Chuẩn bị một lần (người có quyền trên Firebase Console, project `caulong-9b67e`)

1. **Authentication → Sign-in method:** bật **Email/Password** và **Google**.
2. **Firestore Database → Create database** (chế độ production, chọn khu vực gần Việt Nam).
3. **Firestore Database → Rules:** dán nội dung file [`firestore.rules`](../firestore.rules) ở thư mục gốc repo rồi bấm **Publish**. Rules này chặn người dùng tự đổi `role` thành ADMIN.
4. **Project settings → Your apps → Android:** có SHA-1 của máy bạn (cần cho Google Sign-In), rồi tải lại `google-services.json` vào `android/app/`.

## Chạy app

Lần đầu thêm thư viện Firestore (bước này tự chọn phiên bản tương thích với `firebase_core` hiện tại):

```powershell
flutter pub add cloud_firestore
flutter pub get
```

Rồi chạy:

```powershell
flutter run --dart-define=AUTH_MODE=firebase
```

Không cần `API_BASE_URL`, không cần bật backend. `GOOGLE_MODE` để mặc định (`firebase`). Google giả (`GOOGLE_MODE=mock`) **không dùng được** ở chế độ này.

## Cách kiểm tra khi demo

1. Đăng ký một tài khoản mới: mở Firebase Console → **Authentication → Users** thấy user mới, **Firestore → users** thấy tài liệu cùng `uid`.
2. Đăng xuất rồi đăng nhập lại bằng email vừa tạo.
3. Bấm "Đăng nhập với Google", chọn Gmail thật: user mới xuất hiện với `authProvider = GOOGLE`.
4. Bấm "Quên mật khẩu", nhập email: Firebase gửi liên kết đặt lại mật khẩu (xem cả mục Spam).
5. Biến một tài khoản thành admin: Firestore → `users/<uid>` → sửa `role` thành `ADMIN` (Console có toàn quyền, Rules chỉ chặn ứng dụng). Mở lại app để màn quản trị hiện.

## Lưu ý và hạn chế

- Nút "Khám phá với tài khoản demo" dùng `demo@courtly.vn` / `123456`. Tài khoản này **chưa tồn tại** trong Firebase, hãy đăng ký nó một lần trước.
- Chỉ đăng nhập bằng email (không bằng số điện thoại). SĐT chỉ được lưu trong hồ sơ.
- Mật khẩu tối thiểu 6 ký tự (quy tắc của Firebase), nhẹ hơn quy tắc của backend.
- Đăng ký chưa bắt buộc xác minh email mới được vào app; email xác minh chỉ được gửi đi.
- Phiên: Firebase ID token sống 1 giờ, app tự làm mới. Không có refresh token riêng như backend.
- Hồ sơ mất đồng bộ (đã tạo user Firebase nhưng chưa có tài liệu Firestore) sẽ tự được tạo lại ở lần đăng nhập sau.
