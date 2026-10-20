# Sprint 1 — biên bản kiểm thử

Ngày kiểm tra: 20/10/2026.

**Trạng thái: đã triển khai và kiểm thử cục bộ; chưa nghiệm thu tích hợp dịch vụ thật.**

## Kết quả

| Kiểm tra | Kết quả / bằng chứng |
|---|---|
| Flutter unit/widget tests | 105 test pass với `flutter test --no-pub` |
| Static analysis | `flutter analyze --no-pub`: No issues found |
| Firestore Rules | 5 test pass trên Firestore Emulator, project `demo-courtly-sprint1` |
| Android thật | `adb devices` không có thiết bị kết nối |
| Backend tại URL mặc định | Không lấy được health response từ `http://localhost:8080/actuator/health`; chưa xác nhận API OTP |
| Email OTP / Google / reset link thật | Chưa kiểm chứng; không sử dụng kết quả mock để thay thế |
| Rules production | Chưa triển khai |

S1-01 đến S1-07 có mã/tài liệu hoặc hợp đồng trong phạm vi Flutter.
S1-08 còn phần kiểm tra thực tế bên dưới. Không đánh dấu toàn bộ sprint Done.

## Chạy lại kiểm thử

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
cd tools/rules-tests
npm ci
# Dùng JDK hỗ trợ emulator, ví dụ JBR đi kèm Android Studio:
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
npm test
```

Rules test dùng project demo và cổng 8085; không cần Firebase production credentials.
Lần đầu cần mạng tải emulator. Log PERMISSION_DENIED là kết quả dự kiến của
các trường hợp bị từ chối. `package-lock.json` khóa phiên bản công cụ.

Các test mới bao phủ hợp đồng OTP, sai JSON/schema, timeout/mất mạng, không retry
tạo tài khoản, phiên cũ/sai mode, UID không khớp, hồ sơ thiếu/sai định dạng,
admin offline, refresh, logout lỗi, không ghi nhớ, thứ tự Spring → Firebase và reset link.
Mock SDK chỉ chứng minh xử lý phía Flutter, không chứng minh cấu hình Firebase thật.

## Checklist nghiệm thu Android

Người chạy cần ghi ngày, thiết bị/Android, commit, cấu hình AUTH_MODE, URL backend
và kết quả vào bản sao biên bản; không ghi password, OTP hoặc token.

| Kịch bản | Kỳ vọng | Hiện tại |
|---|---|---|
| Đăng ký mới, OTP sai, gửi lại, OTP đúng | Báo sai mã; sau mã đúng có Auth user và users/{uid} cùng UID | Chưa chạy |
| Email đã tồn tại / mật khẩu sai | Lỗi có kiểm soát, không vào ứng dụng | Chưa chạy |
| Google và hủy bộ chọn | Đăng nhập đúng người; hủy giữ màn đăng nhập, không báo lỗi | Chưa chạy |
| Quên mật khẩu | Nhận link, đổi mật khẩu và đăng nhập lại được | Chưa chạy |
| Ghi nhớ bật/tắt rồi force-stop/mở lại | Bật khôi phục; tắt yêu cầu đăng nhập dù SDK còn user | Chưa chạy |
| Customer / admin online / admin offline | Customer không vào admin; admin chỉ vào khi role được kiểm chứng | Chưa chạy |
| Đăng xuất rồi mở lại | Không tự trở lại phiên cũ | Chưa chạy |
| Backend tạo tài khoản nhưng mất phản hồi | Không tự gửi lại; hướng dẫn đăng nhập/reset | Chưa chạy |

## Điều kiện bàn giao backend/Firebase

- Backend đáp ứng [hợp đồng OTP](SPRINT1_OTP_CONTRACT.md), có mail và Admin SDK.
- Firebase bật Email/Password, Google; Android có SHA-1/SHA-256 phù hợp.
- Có tài khoản customer/admin thử riêng và địa chỉ backend truy cập được từ thiết bị.
- Rà soát hồ sơ cũ có đủ schema trước khi triển khai Rules.
- Sau khi có các điều kiện này, chạy checklist và cập nhật bằng chứng; không suy
  luận backend ngừng hoạt động chỉ từ một URL health chưa truy cập được.
