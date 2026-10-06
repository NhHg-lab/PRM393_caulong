import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/auth_models.dart';

/// Nơi lưu phiên đăng nhập bền vững (sống qua lần tắt/mở app).
abstract class SessionStorage {
  Future<void> save(AuthSession session);

  /// Trả về null nếu chưa có phiên hoặc dữ liệu hỏng.
  Future<AuthSession?> read();

  Future<void> clear();

  factory SessionStorage.fromConfig() => switch (AppConfig.sessionStorage) {
    SessionStorageType.secure => SecureSessionStorage(),
    SessionStorageType.prefs => PrefsSessionStorage(),
  };
}

/// Key dùng chung cho hai bản cài đặt.
abstract final class _Keys {
  static const refreshToken = 'refresh_token';
  static const expiresAt = 'expires_at';
  static const user = 'user_profile';
  static const all = [refreshToken, expiresAt, user];
}

AuthSession? _decodeSession({
  required String? accessToken,
  required String? refreshToken,
  required String? expiresAt,
  required String? user,
}) {
  if (accessToken == null || expiresAt == null || user == null) return null;
  return AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: DateTime.parse(expiresAt),
    user: AppUser.fromJson(jsonDecode(user) as Map<String, dynamic>),
  );
}

/// Lưu token vào Keystore (Android) / Keychain (iOS). Dùng cho app chính.
class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessToken = 'access_token';

  @override
  Future<void> save(AuthSession session) async {
    await _storage.write(key: _accessToken, value: session.accessToken);
    await _storage.write(key: _Keys.refreshToken, value: session.refreshToken);
    await _storage.write(
      key: _Keys.expiresAt,
      value: session.expiresAt.toIso8601String(),
    );
    await _storage.write(
      key: _Keys.user,
      value: jsonEncode(session.user.toJson()),
    );
  }

  @override
  Future<AuthSession?> read() async {
    try {
      return _decodeSession(
        accessToken: await _storage.read(key: _accessToken),
        refreshToken: await _storage.read(key: _Keys.refreshToken),
        expiresAt: await _storage.read(key: _Keys.expiresAt),
        user: await _storage.read(key: _Keys.user),
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> clear() async {
    for (final key in [_accessToken, ..._Keys.all]) {
      await _storage.delete(key: key);
    }
  }
}

/// Lưu token bằng SharedPreferences với key `auth_token` (đề Lab 10.3).
/// Lưu ý: SharedPreferences KHÔNG mã hoá, chỉ dùng cho mục đích học tập.
class PrefsSessionStorage implements SessionStorage {
  static const tokenKey = 'auth_token';

  @override
  Future<void> save(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, session.accessToken);
    if (session.refreshToken != null) {
      await prefs.setString(_Keys.refreshToken, session.refreshToken!);
    } else {
      await prefs.remove(_Keys.refreshToken);
    }
    await prefs.setString(_Keys.expiresAt, session.expiresAt.toIso8601String());
    await prefs.setString(_Keys.user, jsonEncode(session.user.toJson()));
  }

  @override
  Future<AuthSession?> read() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return _decodeSession(
        accessToken: prefs.getString(tokenKey),
        refreshToken: prefs.getString(_Keys.refreshToken),
        expiresAt: prefs.getString(_Keys.expiresAt),
        user: prefs.getString(_Keys.user),
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [tokenKey, ..._Keys.all]) {
      await prefs.remove(key);
    }
  }
}

/// Chỉ giữ trong bộ nhớ, mất khi tắt app. Dùng cho kiểm thử.
class MemorySessionStorage implements SessionStorage {
  AuthSession? _session;

  @override
  Future<void> save(AuthSession session) async => _session = session;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> clear() async => _session = null;
}
