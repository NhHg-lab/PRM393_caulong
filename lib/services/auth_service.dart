import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth_models.dart';

/// Hợp đồng chung cho mọi nguồn xác thực. UI không gọi trực tiếp lớp này,
/// mà đi qua AuthManager.
abstract class AuthService {
  Future<AuthSession> login(LoginRequest request);

  Future<AuthSession> signup(SignupRequest request);

  /// Đổi Firebase ID token lấy phiên đăng nhập của hệ thống.
  Future<AuthSession> loginWithGoogleIdToken(String idToken);

  /// Lấy access token mới. Ném [AuthException] nếu refresh token không còn hợp lệ.
  Future<AuthSession> refresh(AuthSession current);

  /// Thu hồi phiên phía server (nếu có). Không ném lỗi.
  Future<void> logout(AuthSession session);

  /// Tài khoản dùng cho nút "Khám phá với tài khoản demo".
  LoginRequest get demoAccount;

  factory AuthService.fromConfig({http.Client? client}) =>
      switch (AppConfig.authMode) {
        AuthMode.mock => MockAuthService(),
        AuthMode.dummyJson => DummyJsonAuthService(client: client),
        AuthMode.spring => SpringAuthService(client: client),
      };
}

// ---------------------------------------------------------------------------
// Mock: chạy offline, dữ liệu nằm trong bộ nhớ.
// ---------------------------------------------------------------------------

class MockAuthService implements AuthService {
  MockAuthService({this.latency = AppConfig.mockLatency});

  final Duration latency;

  static const demoEmail = 'demo@courtly.vn';
  static const demoPassword = '123456';
  static const adminEmail = 'admin@courtly.vn';
  static const adminPassword = 'Admin@123';

  static const _tokenLifetime = Duration(hours: 1);

  // email -> (mật khẩu, user). Tài khoản đăng ký mới chỉ sống trong phiên chạy app.
  final Map<String, (String, AppUser)> _accounts = {
    demoEmail: (
      demoPassword,
      const AppUser(
        id: 'U001',
        fullName: 'Hoàng Nam',
        email: demoEmail,
        phone: '0912345678',
      ),
    ),
    adminEmail: (
      adminPassword,
      const AppUser(
        id: 'A001',
        fullName: 'Quản trị Courtly',
        email: adminEmail,
        phone: '0987654321',
        role: UserRole.admin,
      ),
    ),
  };

  @override
  LoginRequest get demoAccount =>
      const LoginRequest(identifier: demoEmail, password: demoPassword);

  @override
  Future<AuthSession> login(LoginRequest request) async {
    await Future<void>.delayed(latency);
    final identifier = request.identifier.trim().toLowerCase();
    final match = _accounts.values.where(
      (entry) =>
          entry.$2.email.toLowerCase() == identifier ||
          entry.$2.phone == identifier,
    );
    if (match.isEmpty || match.first.$1 != request.password) {
      throw const AuthException(
        'Email/số điện thoại hoặc mật khẩu không đúng.',
        statusCode: 401,
      );
    }
    return _issue(match.first.$2);
  }

  @override
  Future<AuthSession> signup(SignupRequest request) async {
    await Future<void>.delayed(latency);
    final email = request.email.trim().toLowerCase();
    if (_accounts.containsKey(email)) {
      throw const AuthException('Email này đã được đăng ký.', statusCode: 409);
    }
    final user = AppUser(
      id: 'U${DateTime.now().millisecondsSinceEpoch}',
      fullName: request.fullName.trim(),
      email: email,
      phone: request.phone,
    );
    _accounts[email] = (request.password, user);
    return _issue(user);
  }

  @override
  Future<AuthSession> loginWithGoogleIdToken(String idToken) async {
    await Future<void>.delayed(latency);
    return _issue(
      const AppUser(
        id: 'G001',
        fullName: 'Người dùng Google',
        email: 'google.user@gmail.com',
        authProvider: 'GOOGLE',
      ),
    );
  }

  @override
  Future<AuthSession> refresh(AuthSession current) async {
    if (current.refreshToken?.startsWith('mock-refresh.') != true) {
      throw AuthException.sessionExpired;
    }
    return _issue(current.user);
  }

  @override
  Future<void> logout(AuthSession session) async {}

  AuthSession _issue(AppUser user) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return AuthSession(
      accessToken: 'mock-access.${user.id}.$stamp',
      refreshToken: 'mock-refresh.${user.id}.$stamp',
      expiresAt: DateTime.now().add(_tokenLifetime),
      user: user,
    );
  }
}

// ---------------------------------------------------------------------------
// Dùng chung cho hai service gọi HTTP.
// ---------------------------------------------------------------------------

mixin _HttpJson {
  http.Client get client;

  Future<http.Response> postJson(
    Uri uri,
    Map<String, dynamic> body, {
    String? bearer,
  }) async {
    try {
      return await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (bearer != null) 'Authorization': 'Bearer $bearer',
            },
            body: jsonEncode(body),
          )
          .timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw AuthException.timeout;
    } on http.ClientException {
      throw AuthException.network;
    }
  }

  Map<String, dynamic> decodeOrThrow(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException.fromHttp(response.statusCode, response.body);
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}

// ---------------------------------------------------------------------------
// DummyJSON: https://dummyjson.com/docs/auth — tài khoản emilys / emilyspass.
// ---------------------------------------------------------------------------

class DummyJsonAuthService with _HttpJson implements AuthService {
  DummyJsonAuthService({http.Client? client})
    : client = client ?? http.Client();

  @override
  final http.Client client;

  static const _expiresInMins = 30;

  Uri _uri(String path) => Uri.parse('${AppConfig.dummyJsonBaseUrl}$path');

  @override
  LoginRequest get demoAccount =>
      const LoginRequest(identifier: 'emilys', password: 'emilyspass');

  @override
  Future<AuthSession> login(LoginRequest request) async {
    final response = await postJson(_uri('/auth/login'), {
      'username': request.identifier.trim(),
      'password': request.password,
      'expiresInMins': _expiresInMins,
    });
    if (response.statusCode == 400 || response.statusCode == 401) {
      // DummyJSON trả "Invalid credentials" bằng tiếng Anh, đổi sang tiếng Việt.
      throw AuthException(
        'Tên đăng nhập hoặc mật khẩu không đúng.',
        statusCode: response.statusCode,
      );
    }
    final json = decodeOrThrow(response);
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: DateTime.now().add(const Duration(minutes: _expiresInMins)),
      user: AppUser(
        id: json['id'].toString(),
        fullName: '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim(),
        email: (json['email'] as String?) ?? '',
        avatarUrl: json['image'] as String?,
      ),
    );
  }

  /// DummyJSON không lưu user mới: /users/add chỉ trả về bản giả lập,
  /// nên ta tạo phiên cục bộ (không có refresh token) để demo luồng đăng ký.
  @override
  Future<AuthSession> signup(SignupRequest request) async {
    final response = await postJson(_uri('/users/add'), {
      'firstName': request.fullName.trim(),
      'email': request.email.trim(),
      'phone': request.phone,
      'password': request.password,
    });
    final json = decodeOrThrow(response);
    return AuthSession(
      accessToken: 'dummyjson-local.${json['id']}',
      refreshToken: null,
      expiresAt: DateTime.now().add(const Duration(minutes: _expiresInMins)),
      user: AppUser(
        id: json['id'].toString(),
        fullName: request.fullName.trim(),
        email: request.email.trim(),
        phone: request.phone,
      ),
    );
  }

  @override
  Future<AuthSession> loginWithGoogleIdToken(String idToken) async =>
      throw const AuthException(
        'Chế độ DummyJSON không hỗ trợ đăng nhập Google.',
      );

  @override
  Future<AuthSession> refresh(AuthSession current) async {
    final refreshToken = current.refreshToken;
    if (refreshToken == null) throw AuthException.sessionExpired;
    final response = await postJson(_uri('/auth/refresh'), {
      'refreshToken': refreshToken,
      'expiresInMins': _expiresInMins,
    });
    if (response.statusCode != 200) throw AuthException.sessionExpired;
    final json = decodeOrThrow(response);
    return current.copyWith(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: DateTime.now().add(const Duration(minutes: _expiresInMins)),
    );
  }

  @override
  Future<void> logout(AuthSession session) async {}
}

// ---------------------------------------------------------------------------
// Spring Boot: bám hợp đồng API trong docs/AUTH_MODULE.md.
// ---------------------------------------------------------------------------

class SpringAuthService with _HttpJson implements AuthService {
  SpringAuthService({http.Client? client, String? apiBaseUrl})
    : client = client ?? http.Client(),
      _apiBaseUrl = apiBaseUrl ?? AppConfig.apiBaseUrl;

  @override
  final http.Client client;
  final String _apiBaseUrl;

  Uri _uri(String path) => Uri.parse('$_apiBaseUrl$path');

  /// Cần backend seed sẵn tài khoản này.
  @override
  LoginRequest get demoAccount => const LoginRequest(
    identifier: MockAuthService.demoEmail,
    password: MockAuthService.demoPassword,
  );

  @override
  Future<AuthSession> login(LoginRequest request) async {
    final response = await postJson(_uri('/auth/login'), {
      'identifier': request.identifier.trim(),
      'password': request.password,
    });
    return AuthSession.fromAuthResponse(decodeOrThrow(response));
  }

  @override
  Future<AuthSession> signup(SignupRequest request) async {
    final response = await postJson(_uri('/auth/register'), request.toJson());
    return AuthSession.fromAuthResponse(decodeOrThrow(response));
  }

  @override
  Future<AuthSession> loginWithGoogleIdToken(String idToken) async {
    final response = await postJson(_uri('/auth/google'), {'idToken': idToken});
    return AuthSession.fromAuthResponse(decodeOrThrow(response));
  }

  @override
  Future<AuthSession> refresh(AuthSession current) async {
    final refreshToken = current.refreshToken;
    if (refreshToken == null) throw AuthException.sessionExpired;
    final response = await postJson(_uri('/auth/refresh'), {
      'refreshToken': refreshToken,
    });
    return AuthSession.fromAuthResponse(decodeOrThrow(response));
  }

  @override
  Future<void> logout(AuthSession session) async {
    final refreshToken = session.refreshToken;
    if (refreshToken == null) return;
    try {
      await postJson(_uri('/auth/logout'), {
        'refreshToken': refreshToken,
      }, bearer: session.accessToken);
    } on AuthException {
      // Đăng xuất phía máy khách vẫn tiếp tục dù server không phản hồi.
    }
  }
}
