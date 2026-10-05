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
  static const AuthMode authMode = AuthMode.mock;

  static const SessionStorageType sessionStorage = SessionStorageType.secure;

  /// Chỉ bật khi đã cấu hình Firebase (xem docs/FIREBASE_SETUP.md).
  static const bool enableGoogleSignIn = false;

  // TODO(FIREBASE): điền Web client ID (client_type 3 trong google-services.json)
  // để Google Sign-In trên Android trả về idToken. Để null nếu chưa có.
  static const String? googleServerClientId = null;

  static const Duration requestTimeout = Duration(seconds: 15);

  /// Thời gian giả lập độ trễ mạng của MockAuthService.
  static const Duration mockLatency = Duration(seconds: 2);

  static const String dummyJsonBaseUrl = 'https://dummyjson.com';

  /// Android emulator truy cập máy host qua 10.0.2.2; các nền tảng khác dùng localhost.
  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static String get apiBaseUrl => '$baseUrl/api';
}
