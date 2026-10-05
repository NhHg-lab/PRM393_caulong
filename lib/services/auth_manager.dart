import 'package:flutter/foundation.dart';

import '../models/auth_models.dart';
import 'auth_service.dart';
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

  AuthStatus get status => _status;
  AuthSession? get session => _session;
  AppUser? get currentUser => _session?.user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isAdmin => isAuthenticated && (currentUser?.isAdmin ?? false);
  LoginRequest get demoAccount => _service.demoAccount;

  /// Gọi một lần lúc mở app. Phiên hết hạn sẽ được thử refresh.
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
    if (!stored.isExpired) {
      _setSession(stored);
      return;
    }
    _session = stored;
    if (!await refreshSession()) {
      await _storage.clear();
      _setSession(null);
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

  Future<AppUser> signup(SignupRequest request) =>
      _signIn(() => _service.signup(request), true);

  /// Dùng bởi ApiClient khi gặp 401. Nhiều request cùng lúc chỉ refresh một lần.
  Future<bool> refreshSession() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final current = _session;
    if (current == null) return false;
    try {
      final renewed = await _service.refresh(current);
      if (_persist) await _storage.save(renewed);
      _setSession(renewed);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Xoá phiên ở cả storage lẫn server.
  Future<void> logout() async {
    final current = _session;
    _setSession(null);
    await _storage.clear();
    if (current != null) await _service.logout(current);
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
