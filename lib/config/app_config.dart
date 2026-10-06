import 'package:flutter/foundation.dart';

/// Nguồn xác thực mà app sử dụng.
enum AuthMode {
  /// Giả lập hoàn toàn trên máy, không cần mạng.
  mock,

  /// Gọi API công khai https://dummyjson.com (phục vụ bài lab).
  dummyJson,

  /// Gọi backend Spring Boot của nhóm.
  spring,
}

/// Nơi lưu phiên đăng nhập.
enum SessionStorageType {
  /// flutter_secure_storage (Keystore/Keychain) — dùng cho app chính.
  secure,

  /// shared_preferences với key `auth_token` — đúng như đề Lab 10.3.
  prefs,
}

/// Cấu hình tập trung. Đổi giá trị ở đây rồi hot restart để áp dụng.
abstract final class AppConfig {
  /// Mặc định là mock. Đổi chế độ không cần sửa code:
  /// `flutter run --dart-define=AUTH_MODE=spring` (hoặc `dummyjson`).
  static const String _authModeName = String.fromEnvironment('AUTH_MODE');

  static const AuthMode authMode = _authModeName == 'spring'
      ? AuthMode.spring
      : _authModeName == 'dummyjson'
      ? AuthMode.dummyJson
      : AuthMode.mock;

  static const SessionStorageType sessionStorage = SessionStorageType.secure;

  /// Chỉ bật khi đã cấu hình Firebase (xem docs/FIREBASE_SETUP.md).
  static const bool enableGoogleSignIn = true;

  // Web client ID (client_type 3 trong google-services.json), cần để
  // Google Sign-In trên Android trả về idToken.
  static const String googleServerClientId =
      '813885294318-71q2upnh1pp814amjlsc6ok48k8mao52.apps.googleusercontent.com';

  static const Duration requestTimeout = Duration(seconds: 15);

  /// Thời gian giả lập độ trễ mạng của MockAuthService.
  static const Duration mockLatency = Duration(seconds: 2);

  static const String dummyJsonBaseUrl = 'https://dummyjson.com';

  /// Ghi đè địa chỉ backend khi chạy máy thật hoặc deploy:
  /// `--dart-define=API_BASE_URL=http://192.168.1.10:8080` (không có dấu / ở cuối).
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Android emulator truy cập máy host qua 10.0.2.2; các nền tảng khác dùng localhost.
  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static String get apiBaseUrl => '$baseUrl/api';
}
