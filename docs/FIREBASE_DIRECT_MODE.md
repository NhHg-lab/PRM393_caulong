# Firebase + Spring OTP (chế độ tích hợp chính)

Firebase Authentication quản lý email/mật khẩu và Google. Firestore lưu hồ sơ
`users/{uid}`. **Đăng ký cần backend Spring** gửi/xác minh OTP 6 số và tạo tài khoản
Firebase qua Admin SDK; không dùng SQL identity hoặc JWT Spring trong chế độ này.
Quên mật khẩu dùng liên kết email Firebase.

## Chuẩn bị

1. Bật Email/Password và Google trong Firebase Authentication.
2. Tạo Firestore; đối chiếu hồ sơ cũ với schema trước khi triển khai `firestore.rules`.
3. Thêm SHA-1/SHA-256 của máy phát triển; dùng cấu hình Android đúng package.
4. Backend triển khai [hợp đồng OTP](SPRINT1_OTP_CONTRACT.md), cấu hình mail và Admin SDK.
5. Chuẩn bị tài khoản customer/admin riêng. Gán ADMIN từ Console/backend tin cậy.
   Tài khoản demo mock không tự tồn tại trên Firebase.

## Chạy

```powershell
flutter pub get
flutter run --dart-define=AUTH_MODE=firebase --dart-define=GOOGLE_MODE=firebase --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Máy thật thay địa chỉ bằng host backend truy cập được. Thay dart-define phải chạy
lại app. `GOOGLE_MODE=mock` không dùng được với Firebase. Bỏ dart-define AUTH_MODE
vẫn chạy mock để phục vụ lab.

## Kiểm tra

Đăng ký → nhận OTP → xác minh → kiểm tra Auth user và Firestore cùng UID → đăng
xuất/đăng nhập → thử Google → reset mật khẩu → thử ghi nhớ phiên và phân quyền.
Xem [biên bản nghiệm thu](SPRINT1_ACCEPTANCE.md) để phân biệt kiểm thử tự động và thật.

Phiên cũ không có auth_mode bị xóa một lần. Role admin chỉ được mở khi đã kiểm tra
hồ sơ từ server. Khi mất mạng, role đã lưu không đủ để mở dashboard.
Các dữ liệu sân, vé và ghép kèo vẫn là demo trong phiên.
