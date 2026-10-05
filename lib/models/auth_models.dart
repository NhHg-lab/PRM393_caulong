import 'dart:convert';

enum UserRole {
  customer,
  admin;

  /// Backend trả về "CUSTOMER" | "ADMIN".
  static UserRole fromApi(Object? value) =>
      value?.toString().toUpperCase() == 'ADMIN' ? admin : customer;

  String toApi() => name.toUpperCase();
}

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.role = UserRole.customer,
    this.avatarUrl,
    this.authProvider = 'LOCAL',
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final UserRole role;
  final String? avatarUrl;

  /// "LOCAL" hoặc "GOOGLE".
  final String authProvider;

  bool get isAdmin => role == UserRole.admin;

  /// Chữ cái đầu của 2 từ cuối, ví dụ "Hoàng Nam" -> "HN".
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final picked = parts.length == 1
        ? [parts.first]
        : parts.sublist(parts.length - 2);
    return picked
        .map((part) => String.fromCharCode(part.runes.first))
        .join()
        .toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'].toString(),
    fullName: (json['fullName'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    phone: json['phone'] as String?,
    role: UserRole.fromApi(json['role']),
    avatarUrl: json['avatarUrl'] as String?,
    authProvider: (json['authProvider'] as String?) ?? 'LOCAL',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'role': role.toApi(),
    'avatarUrl': avatarUrl,
    'authProvider': authProvider,
  };
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final AppUser user;

  /// Coi như hết hạn sớm 30 giây để tránh gửi token sắp chết.
  bool get isExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));

  /// Dựng từ AuthResponse của backend: { accessToken, refreshToken, expiresIn, user }.
  factory AuthSession.fromAuthResponse(Map<String, dynamic> json) {
    final expiresIn = (json['expiresIn'] as num?)?.toInt() ?? 3600;
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    AppUser? user,
  }) => AuthSession(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    expiresAt: expiresAt ?? this.expiresAt,
    user: user ?? this.user,
  );
}

class LoginRequest {
  const LoginRequest({required this.identifier, required this.password});

  /// Email hoặc số điện thoại (hoặc username ở chế độ DummyJSON).
  final String identifier;
  final String password;

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    'password': password,
  };
}

class SignupRequest {
  const SignupRequest({
    required this.fullName,
    required this.email,
    required this.password,
    this.phone,
    this.otp,
  });

  final String fullName;
  final String email;
  final String? phone;
  final String password;

  /// Mã OTP 6 số gửi qua email (bước 2 của đăng ký). Null ở chế độ không dùng OTP.
  final String? otp;

  SignupRequest copyWith({String? otp}) => SignupRequest(
    fullName: fullName,
    email: email,
    phone: phone,
    password: password,
    otp: otp ?? this.otp,
  );

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'email': email,
    if (phone != null && phone!.isNotEmpty) 'phone': phone,
    'password': password,
    if (otp != null && otp!.isNotEmpty) 'otp': otp,
  };
}

/// Kết quả gửi OTP: `POST /api/auth/register/send-otp`.
class OtpSent {
  const OtpSent({
    required this.message,
    required this.expiresIn,
    required this.resendAfter,
  });

  final String message;

  /// Số giây mã còn hiệu lực.
  final int expiresIn;

  /// Số giây phải chờ trước khi được gửi lại mã.
  final int resendAfter;

  factory OtpSent.fromJson(Map<String, dynamic> json) => OtpSent(
    message: (json['message'] as String?) ?? 'Đã gửi mã OTP tới email của bạn.',
    expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 300,
    resendAfter: (json['resendAfter'] as num?)?.toInt() ?? 60,
  );
}

/// Lỗi xác thực với thông điệp tiếng Việt hiển thị trực tiếp cho người dùng.
class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode, this.fieldErrors});

  final String message;
  final int? statusCode;
  final Map<String, String>? fieldErrors;

  static const network = AuthException(
    'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.',
  );
  static const timeout = AuthException(
    'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
  );
  static const sessionExpired = AuthException(
    'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    statusCode: 401,
  );

  /// Đọc body lỗi chuẩn của backend:
  /// { timestamp, status, error, message, path, fieldErrors? }.
  /// Ưu tiên `message` của server, nếu không có thì dùng câu mặc định theo mã lỗi.
  factory AuthException.fromHttp(int statusCode, String body) {
    String? serverMessage;
    Map<String, String>? fieldErrors;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          serverMessage = message;
        }
        final fields = decoded['fieldErrors'];
        if (fields is Map) {
          fieldErrors = fields.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
        } else if (fields is List) {
          // Một số backend trả về [{ field, message }].
          fieldErrors = {
            for (final item in fields.whereType<Map>())
              item['field'].toString(): item['message'].toString(),
          };
        }
      }
    } on FormatException {
      // Body không phải JSON, dùng câu mặc định bên dưới.
    }
    return AuthException(
      serverMessage ?? defaultMessageFor(statusCode),
      statusCode: statusCode,
      fieldErrors: fieldErrors,
    );
  }

  static String defaultMessageFor(int statusCode) => switch (statusCode) {
    400 => 'Thông tin gửi lên chưa hợp lệ.',
    401 => 'Sai thông tin đăng nhập hoặc mật khẩu.',
    403 => 'Bạn không có quyền thực hiện thao tác này.',
    404 => 'Không tìm thấy dữ liệu yêu cầu.',
    409 => 'Tài khoản đã tồn tại.',
    429 => 'Bạn thao tác quá nhanh, vui lòng thử lại sau.',
    >= 500 => 'Máy chủ đang gặp sự cố, vui lòng thử lại sau.',
    _ => 'Đã có lỗi xảy ra (mã $statusCode).',
  };

  @override
  String toString() => 'AuthException($statusCode): $message';
}
