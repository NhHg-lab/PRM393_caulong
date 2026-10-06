import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/auth_models.dart';
import 'auth_service.dart';
import 'google_token_provider.dart';
import 'session_storage.dart';

enum AuthStatus {
  /// Đang khôi phục phiên lúc khởi động (hiển thị Splash).
  unknown,
  authenticated,
  unauthenticated,
}

/// Nguồn sự thật duy nhất về trạng thái đăng nhập. UI chỉ làm việc với lớp này.
class AuthManager extends ChangeNotifier {
  AuthManager({AuthService? service, SessionStorage? storage})
    : _service = service ?? AuthService.fromConfig(),
      _storage = storage ?? SessionStorage.fromConfig();

  static AuthManager? _instance;
  static AuthManager get instance => _instance ??= AuthManager();

  /// Thay singleton bằng bản có service/storage giả trong test.
  @visibleForTesting
  static set instance(AuthManager manager) => _instance = manager;

  final AuthService _service;
  final SessionStorage _storage;

  AuthStatus _status = AuthStatus.unknown;
  AuthSession? _session;

  /// false khi người dùng bỏ chọn "Ghi nhớ đăng nhập": phiên chỉ nằm trong bộ nhớ.
  bool _persist = true;
  Future<bool>? _refreshing;

  /// Nguồn token Google của lần đăng nhập Google gần nhất (để đăng xuất đúng chỗ).
  GoogleTokenProvider? _googleProvider;

  AuthStatus get status => _status;
  AuthSession? get session => _session;
  AppUser? get currentUser => _session?.user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isAdmin => isAuthenticated && (currentUser?.isAdmin ?? false);
  LoginRequest get demoAccount => _service.demoAccount;

  /// Gọi một lần lúc mở app. Phiên hết hạn sẽ được thử refresh, sau đó hồ sơ
  /// được đồng bộ với server (GET /users/me). Trạng thái chỉ đổi khỏi
  /// `unknown` khi đã xong cả hai bước, nên Splash không nhấp nháy sang Home
  /// rồi lại về Login.
  Future<void> restoreSession() async {
    AuthSession? stored;
    try {
      stored = await _storage.read();
    } catch (_) {
      stored = null;
    }
    if (stored == null) {
      _setSession(null);
      return;
    }
    _persist = true;
    var session = stored;
    if (session.isExpired) {
      final renewed = await _renew(session);
      if (renewed == null) {
        await _storage.clear();
        _setSession(null);
        return;
      }
      session = renewed;
    }
    final synced = await _syncProfile(session);
    if (synced == null) {
      await _storage.clear();
      _setSession(null);
      return;
    }
    _setSession(synced);
  }

  /// Lấy hồ sơ/role mới nhất từ server và lưu lại.
  /// - 401/403 (tài khoản bị khoá/xoá, phiên bị thu hồi): trả về null để đăng xuất.
  /// - Lỗi mạng/timeout: giữ phiên đã lưu, không bắt đăng nhập lại khi offline.
  Future<AuthSession?> _syncProfile(AuthSession session) async {
    try {
      final user = await _service
          .fetchProfile(session)
          .timeout(AppConfig.profileSyncTimeout);
      if (user == null) return session;
      final updated = session.copyWith(user: user);
      await _storage.save(updated);
      return updated;
    } on AuthException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) return null;
      return session;
    } catch (_) {
      return session;
    }
  }

  Future<AppUser> login(
    String identifier,
    String password, {
    bool remember = true,
  }) => _signIn(
    () => _service.login(
      LoginRequest(identifier: identifier, password: password),
    ),
    remember,
  );

  Future<AppUser> loginDemo({bool remember = true}) =>
      _signIn(() => _service.login(_service.demoAccount), remember);

  /// Google -> Firebase ID token -> backend đổi sang phiên của hệ thống.
  /// [provider] mặc định là Firebase thật; chế độ demo truyền
  /// MockGoogleTokenProvider với tài khoản giả đã chọn.
  Future<AppUser> loginWithGoogle({
    bool remember = true,
    GoogleTokenProvider provider = const FirebaseGoogleTokenProvider(),
  }) => _signIn(() async {
    final idToken = await provider.obtainIdToken();
    final session = await _service.loginWithGoogleIdToken(idToken);
    _googleProvider = provider;
    return session;
  }, remember);

  /// Đăng ký có bước xác minh OTP qua email hay không (tuỳ AuthMode).
  bool get requiresSignupOtp => _service.requiresSignupOtp;

  Future<OtpSent> sendRegisterOtp(String email) =>
      _service.sendRegisterOtp(email);

  /// Với [requiresSignupOtp], [request] phải có `otp`.
  Future<AppUser> signup(SignupRequest request) =>
      _signIn(() => _service.signup(request), true);

  /// Chế độ hiện tại có hỗ trợ quên mật khẩu bằng OTP email hay không.
  bool get supportsPasswordReset => _service.supportsPasswordReset;

  Future<OtpSent> sendPasswordResetOtp(String email) =>
      _service.sendPasswordResetOtp(email);

  /// Không đăng nhập sẵn: người dùng phải đăng nhập lại bằng mật khẩu mới.
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) =>
      _service.resetPassword(email: email, otp: otp, newPassword: newPassword);

  /// Dùng bởi ApiClient khi gặp 401. Nhiều request cùng lúc chỉ refresh một lần.
  Future<bool> refreshSession() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final current = _session;
    if (current == null) return false;
    final renewed = await _renew(current);
    if (renewed == null) return false;
    _setSession(renewed);
    return true;
  }

  /// Đổi refresh token lấy phiên mới và lưu lại. Không đổi trạng thái/notify.
  Future<AuthSession?> _renew(AuthSession current) async {
    try {
      final renewed = await _service.refresh(current);
      if (_persist) await _storage.save(renewed);
      return renewed;
    } catch (_) {
      return null;
    }
  }

  /// Xoá phiên ở cả storage lẫn server.
  Future<void> logout() async {
    final current = _session;
    _setSession(null);
    await _storage.clear();
    if (current == null) return;
    await _service.logout(current);
    if (current.user.authProvider == 'GOOGLE') {
      // Phiên khôi phục sau khi mở lại app không biết provider: suy ra từ cấu hình.
      // Tài khoản Google giả không bao giờ gọi Firebase.
      final provider =
          _googleProvider ??
          (AppConfig.googleMode == GoogleMode.firebase
              ? const FirebaseGoogleTokenProvider()
              : null);
      _googleProvider = null;
      await provider?.signOut();
    }
  }

  Future<AppUser> _signIn(
    Future<AuthSession> Function() request,
    bool remember,
  ) async {
    final session = await request();
    _persist = remember;
    if (remember) {
      await _storage.save(session);
    } else {
      // Xoá phiên cũ (nếu có) để lần mở app sau không tự đăng nhập.
      await _storage.clear();
    }
    _setSession(session);
    return session.user;
  }

  void _setSession(AuthSession? session) {
    _session = session;
    _status = session == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
    notifyListeners();
  }
}
