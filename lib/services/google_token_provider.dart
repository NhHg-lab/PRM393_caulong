import 'firebase_auth_service.dart';

/// Bước "lấy Google/Firebase ID token" của đăng nhập Google. Token lấy được
/// được AuthManager gửi tới AuthService.loginWithGoogleIdToken như nhau,
/// dù là token thật hay token giả.
abstract interface class GoogleTokenProvider {
  /// Ném AuthException nếu người dùng huỷ hoặc cấu hình sai.
  Future<String> obtainIdToken();

  /// Đăng xuất phía Google/Firebase (nếu có). Không ném lỗi.
  Future<void> signOut();
}

/// Google Sign-In + Firebase Auth thật. Chỉ bọc FirebaseAuthService, không
/// đổi hành vi của nó.
class FirebaseGoogleTokenProvider implements GoogleTokenProvider {
  const FirebaseGoogleTokenProvider();

  @override
  Future<String> obtainIdToken() =>
      FirebaseAuthService.instance.signInWithGoogle();

  @override
  Future<void> signOut() => FirebaseAuthService.instance.signOut();
}

/// Tài khoản Google giả cho chế độ GoogleMode.mock (demo/lab).
class MockGoogleAccount {
  const MockGoogleAccount({required this.email, required this.displayName});

  final String email;
  final String displayName;

  static const prefix = 'mock';

  /// Token giả mà backend ở chế độ mock chấp nhận: `mock:<email>:<tên>`.
  String get idToken => '$prefix:$email:$displayName';

  /// Đọc lại token giả. Trả về null nếu không đúng dạng `mock:<email>:<tên>`.
  /// Tên được phép chứa dấu `:`.
  static MockGoogleAccount? parse(String idToken) {
    if (!idToken.startsWith('$prefix:')) return null;
    final rest = idToken.substring(prefix.length + 1);
    final separator = rest.indexOf(':');
    if (separator <= 0) return null;
    final email = rest.substring(0, separator).trim();
    final name = rest.substring(separator + 1).trim();
    if (!email.contains('@') || name.isEmpty) return null;
    return MockGoogleAccount(email: email, displayName: name);
  }

  /// Danh sách hiện trong hộp "Chọn tài khoản Google (DEMO)".
  static const demoAccounts = [
    MockGoogleAccount(email: 'minh.tran@gmail.com', displayName: 'Trần Minh'),
    MockGoogleAccount(email: 'lan.nguyen@gmail.com', displayName: 'Nguyễn Lan'),
    MockGoogleAccount(email: 'khoa.pham@gmail.com', displayName: 'Phạm Khoa'),
  ];
}

/// Trả về token giả của tài khoản đã chọn. Đăng xuất không gọi Firebase.
class MockGoogleTokenProvider implements GoogleTokenProvider {
  const MockGoogleTokenProvider(this.account);

  final MockGoogleAccount account;

  @override
  Future<String> obtainIdToken() async => account.idToken;

  @override
  Future<void> signOut() async {}
}
