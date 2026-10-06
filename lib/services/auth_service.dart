import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth_models.dart';
import 'google_token_provider.dart';

/// Hợp đồng chung cho mọi nguồn xác thực. UI không gọi trực tiếp lớp này,
/// mà đi qua AuthManager.
abstract class AuthService {
  Future<AuthSession> login(LoginRequest request);

  Future<AuthSession> signup(SignupRequest request);

  /// true nếu đăng ký phải xác minh email bằng OTP (gọi [sendRegisterOtp] trước,
  /// rồi truyền mã vào [SignupRequest.otp]).
  bool get requiresSignupOtp;

  /// Bước 1 của đăng ký: gửi mã OTP 6 số tới [email].
  Future<OtpSent> sendRegisterOtp(String email);

  /// true nếu chế độ này hỗ trợ quên mật khẩu bằng OTP email.
  bool get supportsPasswordReset;

  /// Quên mật khẩu bước 1: gửi OTP tới [email]. Phản hồi luôn giống nhau dù
  /// email có tồn tại hay không, để không lộ email nào đã đăng ký.
  Future<OtpSent> sendPasswordResetOtp(String email);

  /// Quên mật khẩu bước 2: đổi mật khẩu bằng mã OTP. Không trả về phiên,
  /// người dùng phải đăng nhập lại bằng mật khẩu mới.
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  });

  /// Đổi Firebase ID token lấy phiên đăng nhập của hệ thống.
  Future<AuthSession> loginWithGoogleIdToken(String idToken);

  /// Lấy access token mới. Ném [AuthException] nếu refresh token không còn hợp lệ.
  Future<AuthSession> refresh(AuthSession current);

  /// Hồ sơ mới nhất của người dùng (GET /users/me). Trả về null nếu chế độ
  /// này không có API hồ sơ. 401/403 ném [AuthException] có statusCode,
  /// lỗi mạng ném [AuthException.network] / [AuthException.timeout].
  Future<AppUser?> fetchProfile(AuthSession session);

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

  /// Chế độ mock không gửi email thật: mã OTP luôn là 123456.
  static const otpCode = '123456';

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
  bool get requiresSignupOtp => true;

  @override
  Future<OtpSent> sendRegisterOtp(String email) async {
    await Future<void>.delayed(latency);
    final normalized = email.trim().toLowerCase();
    if (_accounts.containsKey(normalized)) {
      throw const AuthException('Email này đã được đăng ký.', statusCode: 409);
    }
    return const OtpSent(
      message: 'Chế độ demo: không gửi email thật, mã OTP là $otpCode',
      expiresIn: 300,
      resendAfter: 30,
    );
  }

  @override
  Future<AuthSession> signup(SignupRequest request) async {
    await Future<void>.delayed(latency);
    final email = request.email.trim().toLowerCase();
    if (_accounts.containsKey(email)) {
      throw const AuthException('Email này đã được đăng ký.', statusCode: 409);
    }
    if (request.otp != otpCode) {
      throw const AuthException(
        'Mã OTP không đúng, vui lòng kiểm tra lại.',
        statusCode: 400,
      );
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
  bool get supportsPasswordReset => true;

  @override
  Future<OtpSent> sendPasswordResetOtp(String email) async {
    await Future<void>.delayed(latency);
    // Cố ý không kiểm tra email có tồn tại: phản hồi giống hệt nhau.
    return const OtpSent(
      message:
          'Nếu email đã được đăng ký, mã OTP sẽ được gửi tới email đó. '
          'Chế độ demo: mã OTP là $otpCode',
      expiresIn: 300,
      resendAfter: 30,
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await Future<void>.delayed(latency);
    final normalized = email.trim().toLowerCase();
    final account = _accounts[normalized];
    // Mã sai và email lạ dùng chung một thông báo để không lộ email tồn tại.
    if (account == null || otp != otpCode) {
      throw const AuthException(
        'Mã OTP không hợp lệ hoặc đã hết hạn.',
        statusCode: 400,
      );
    }
    _accounts[normalized] = (newPassword, account.$2);
  }

  /// Token giả `mock:<email>:<tên>` (GoogleMode.mock) cho ra đúng user đó;
  /// token khác (ví dụ Firebase thật) cho ra một tài khoản Google cố định.
  @override
  Future<AuthSession> loginWithGoogleIdToken(String idToken) async {
    await Future<void>.delayed(latency);
    final mock = MockGoogleAccount.parse(idToken);
    if (mock != null) {
      final email = mock.email.toLowerCase();
      return _issue(
        AppUser(
          id: 'G-$email',
          fullName: mock.displayName,
          email: email,
          authProvider: 'GOOGLE',
        ),
      );
    }
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
  Future<AppUser?> fetchProfile(AuthSession session) async => null;

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

  Future<http.Response> getJson(Uri uri, {String? bearer}) async {
    try {
      return await client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (bearer != null) 'Authorization': 'Bearer $bearer',
            },
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

  @override
  bool get requiresSignupOtp => false;

  @override
  Future<OtpSent> sendRegisterOtp(String email) async =>
      throw const AuthException('Chế độ DummyJSON không hỗ trợ xác minh OTP.');

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
  bool get supportsPasswordReset => false;

  @override
  Future<OtpSent> sendPasswordResetOtp(String email) async =>
      throw const AuthException(
        'Chế độ DummyJSON không hỗ trợ đặt lại mật khẩu.',
      );

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async => throw const AuthException(
    'Chế độ DummyJSON không hỗ trợ đặt lại mật khẩu.',
  );

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
  Future<AppUser?> fetchProfile(AuthSession session) async => null;

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

  /// Tài khoản khách do DevDataSeeder của backend tạo sẵn (badminton_backend).
  /// Quản trị viên seed sẵn: admin@courtly.vn / 123456.
  @override
  LoginRequest get demoAccount =>
      const LoginRequest(identifier: 'customer@courtly.vn', password: '123456');

  @override
  Future<AuthSession> login(LoginRequest request) async {
    final response = await postJson(_uri('/auth/login'), {
      'identifier': request.identifier.trim(),
      'password': request.password,
    });
    return AuthSession.fromAuthResponse(decodeOrThrow(response));
  }

  @override
  bool get requiresSignupOtp => true;

  /// Bước 1: backend gửi mã 6 số qua Gmail. 409 nếu email đã dùng,
  /// 429 nếu gửi quá nhanh/quá nhiều, 503 nếu backend chưa cấu hình mail.
  @override
  Future<OtpSent> sendRegisterOtp(String email) async {
    final response = await postJson(_uri('/auth/register/send-otp'), {
      'email': email.trim(),
    });
    return OtpSent.fromJson(decodeOrThrow(response));
  }

  /// Bước 2: body gồm cả `otp` (xem [SignupRequest.toJson]).
  @override
  Future<AuthSession> signup(SignupRequest request) async {
    final response = await postJson(_uri('/auth/register'), request.toJson());
    return AuthSession.fromAuthResponse(decodeOrThrow(response));
  }

  @override
  bool get supportsPasswordReset => true;

  /// Luôn 200 dù email có tồn tại hay không. 429 nếu gửi quá nhanh/quá nhiều,
  /// 503 nếu backend chưa cấu hình mail.
  @override
  Future<OtpSent> sendPasswordResetOtp(String email) async {
    final response = await postJson(_uri('/auth/password/forgot'), {
      'email': email.trim(),
    });
    return OtpSent.fromJson(decodeOrThrow(response));
  }

  /// 400 nếu OTP sai/hết hạn hoặc mật khẩu mới quá yếu.
  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await postJson(_uri('/auth/password/reset'), {
      'email': email.trim(),
      'otp': otp.trim(),
      'newPassword': newPassword,
    });
    decodeOrThrow(response);
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

  /// GET /api/users/me -> UserDto { id, fullName, email, phone, role, avatarUrl, authProvider }.
  @override
  Future<AppUser?> fetchProfile(AuthSession session) async {
    final response = await getJson(
      _uri('/users/me'),
      bearer: session.accessToken,
    );
    return AppUser.fromJson(decodeOrThrow(response));
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
