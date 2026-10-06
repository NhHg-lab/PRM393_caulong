import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth_models.dart';
import 'auth_manager.dart';

/// Bọc package http cho các API cần đăng nhập:
/// - tự gắn `Authorization: Bearer <accessToken>`;
/// - gặp 401 thì refresh token đúng 1 lần rồi gửi lại;
/// - refresh thất bại thì logout (main.dart tự đưa về màn đăng nhập).
class ApiClient {
  ApiClient({http.Client? client, AuthManager? auth, String? baseUrl})
    : _client = client ?? http.Client(),
      _auth = auth ?? AuthManager.instance,
      _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final AuthManager _auth;
  final String _baseUrl;

  Future<http.Response> get(String path) => _send('GET', path);

  Future<http.Response> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<http.Response> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<http.Response> delete(String path) => _send('DELETE', path);

  /// Tiện ích: gửi GET và giải mã JSON, ném [AuthException] khi lỗi.
  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await get(path);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException.fromHttp(response.statusCode, response.body);
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    bool canRetry = true,
  }) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers['Accept'] = 'application/json';
    final token = _auth.session?.accessToken;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _client
          .send(request)
          .timeout(AppConfig.requestTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw AuthException.timeout;
    } on http.ClientException {
      throw AuthException.network;
    }

    if (response.statusCode != 401 || token == null) return response;
    if (canRetry && await _auth.refreshSession()) {
      return _send(method, path, body: body, canRetry: false);
    }
    await _auth.logout();
    throw AuthException.sessionExpired;
  }
}
