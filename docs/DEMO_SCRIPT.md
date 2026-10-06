# Kịch bản demo "Bảo mật tài khoản" (5-7 phút)

Bản nháp để nhóm chỉnh. Chi tiết kỹ thuật xem [AUTH_MODULE.md](AUTH_MODULE.md).

## Chuẩn bị (trước giờ trình bày)

- [ ] Emulator có Google Play đã mở sẵn; đã chạy app ít nhất 1 lần (build sẵn, khỏi chờ Gradle).
- [ ] Backend chạy được: `docker compose up -d` (hoặc `./mvnw spring-boot:run`), mở `http://localhost:8080/swagger-ui.html` thấy trang.
- [ ] Backend `.env`: `MAIL_USERNAME` + `MAIL_PASSWORD` (Gmail App Password), `GOOGLE_MOCK_ENABLED=true`, `FIREBASE_ENABLED=false`.
- [ ] Android cho phép HTTP tới backend trong bản debug (xem mục cleartext trong [AUTH_MODULE.md](AUTH_MODULE.md#6-khắc-phục-sự-cố)).
- [ ] Gửi thử 1 OTP đăng ký trước để chắc Gmail chạy. Mở sẵn hộp thư của một email **chưa đăng ký** (ví dụ email phụ của nhóm) trên điện thoại hoặc tab trình duyệt.
- [ ] Email đó có thể đã bị đăng ký ở lần tập trước: dùng email khác hoặc xoá user trong DB.
- [ ] Mở sẵn một terminal thứ hai với lệnh dự phòng (mock) để chỉ cần Enter.

Lệnh chính:

```bash
flutter run --dart-define=AUTH_MODE=spring --dart-define=GOOGLE_MODE=mock
```

Lệnh dự phòng (offline, không cần backend, Gmail hay Firebase):

```bash
flutter run --dart-define=GOOGLE_MODE=mock
```

Ở chế độ dự phòng: OTP luôn là `123456` (app hiện ngay trên màn hình), tài khoản `demo@courtly.vn` / `123456`.

---

## Bước 1. Vấn đề bảo mật (khoảng 1 phút, nói, có thể chiếu slide)

Ý chính:
- App đặt sân lưu thông tin cá nhân và lịch sử thanh toán, nên tài khoản là mục tiêu.
- 4 rủi ro sẽ demo cách xử lý: đăng ký bằng email của người khác, quên mật khẩu bị lợi dụng để dò email, đăng nhập bên thứ 3 bị giả mạo, token bị đánh cắp.
- Nguyên tắc: **app chỉ hiển thị, server mới quyết định** (xác minh OTP, xác minh token Google, phân quyền).

## Bước 2. Đăng ký có OTP email (khoảng 1,5 phút)

| | |
|---|---|
| Thao tác | Màn đăng nhập -> "Đăng ký ngay" -> nhập tên, email chưa đăng ký, mật khẩu `Abcd1234` -> "Gửi mã xác minh" |
| Kết quả | Màn "Xác minh email", đếm ngược hạn mã 05:00, nút "Gửi lại mã sau 60s" bị khoá |
| Thao tác | Mở hộp thư, đọc mã. Cố ý nhập sai 1 lần (`000000`) |
| Kết quả | Báo lỗi ngay dưới ô mã, chưa tạo tài khoản |
| Thao tác | Nhập mã đúng -> "Xác nhận và tạo tài khoản" |
| Kết quả | Vào Home, có thông báo "Đăng nhập thành công" |
| Nói | Mã chỉ lưu dạng băm, hết hạn sau 5 phút, sai 5 lần là huỷ, gửi lại phải chờ 60 giây và tối đa 5 lần/giờ |
| Dự phòng | Mail không tới sau 30 giây: nói "đây là lý do có chế độ mock", chuyển sang lệnh dự phòng, đăng ký lại với OTP `123456` hiện trên màn hình |

## Bước 3. Quên mật khẩu (khoảng 1,5 phút)

| | |
|---|---|
| Thao tác | Đăng xuất (tab "Cá nhân") -> "Quên mật khẩu?" -> nhập một email **không tồn tại** -> "Gửi mã xác minh" |
| Kết quả | Vẫn chuyển sang bước nhập mã với cùng một thông điệp |
| Nói | Server trả lời giống hệt nhau, kẻ gian không dò được email nào đã đăng ký |
| Thao tác | "Đổi email" -> nhập email vừa đăng ký ở Bước 2 -> gửi mã -> nhập mã từ hộp thư + mật khẩu mới `Moi12345` (2 lần) -> "Đặt lại mật khẩu" |
| Kết quả | Về màn đăng nhập, email đã điền sẵn, SnackBar "Đặt lại mật khẩu thành công, hãy đăng nhập lại" |
| Thao tác | Nhập mật khẩu mới -> Đăng nhập |
| Kết quả | Vào Home |
| Nói | Đổi mật khẩu xong server thu hồi mọi phiên cũ trên các máy khác |
| Dự phòng | Chế độ mock: dùng `demo@courtly.vn`, mã `123456`, rồi đăng nhập bằng `Moi12345` |

## Bước 4. Google / Firebase (bản mock) (khoảng 1 phút)

| | |
|---|---|
| Thao tác | Đăng xuất -> "Đăng nhập với Google" |
| Kết quả | Hộp "Chọn tài khoản Google (DEMO)" có nhãn "Chế độ demo, không phải Google thật" |
| Thao tác | Chọn "Nguyễn Lan" |
| Kết quả | Vào Home, tab "Cá nhân" hiện Nguyễn Lan / `lan.nguyen@gmail.com` |
| Nói | Bản thật: Google cấp Firebase ID token (JWT có chữ ký), app gửi lên server, **server** xác minh chữ ký bằng Firebase Admin SDK rồi mới cấp phiên. Bản mock đi đúng đường đó nhưng thay bước Google bằng token giả, và chỉ chạy ở bản debug + server bật cờ dev |
| Dự phòng | Backend chưa bật `GOOGLE_MOCK_ENABLED` (báo 401): chuyển sang lệnh dự phòng, thao tác y hệt |

Nếu có thời gian và đã cấu hình SHA-1: chạy `flutter run --dart-define=AUTH_MODE=spring` (không có `GOOGLE_MODE`) để demo hộp chọn tài khoản Google thật.

## Bước 5. Giữ phiên và đăng xuất (khoảng 1 phút)

| | |
|---|---|
| Thao tác | Đang ở Home, tắt hẳn app (vuốt khỏi danh sách đa nhiệm) rồi mở lại |
| Kết quả | Splash rồi vào thẳng Home, không phải đăng nhập |
| Nói | Token nằm trong Keystore (`flutter_secure_storage`). Lúc mở app, app gọi `/users/me` để lấy role mới nhất: tài khoản bị khoá sẽ bị đá ra ngay |
| Thao tác | Đăng xuất -> tắt và mở lại app |
| Kết quả | Về màn đăng nhập |
| Nói | Đăng xuất xoá token trong máy và thu hồi refresh token trên server. Refresh token xoay vòng: token cũ bị dùng lại thì server huỷ toàn bộ phiên của tài khoản |
| Dự phòng | Chế độ mock cũng giữ phiên y hệt (trừ phần `/users/me`) |

Tuỳ chọn (nếu được hỏi về phân quyền): đăng nhập `customer@courtly.vn`, cho thấy không có nút vào trang quản trị; đăng nhập `admin@courtly.vn` thì vào thẳng dashboard. Nhấn mạnh: dù sửa app, API admin vẫn trả 403.

## Câu hỏi có thể gặp

- **Sao không gửi OTP qua SMS?** Tốn phí, SIM swap; email đủ cho đồ án, cùng một cơ chế.
- **OTP 6 số có dễ đoán không?** 1 triệu khả năng, nhưng chỉ 5 lần thử mỗi mã, mã sống 5 phút, xin mã mới bị giới hạn.
- **Access token bị lộ thì sao?** Chỉ sống 30 phút; refresh token bị lộ thì xoay vòng phát hiện dùng lại.
- **Sao không tin email Google mà app gửi lên?** App có thể bị sửa; server chỉ tin token đã xác minh chữ ký.
