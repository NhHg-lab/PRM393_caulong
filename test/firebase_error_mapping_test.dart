import 'package:courtly/models/auth_models.dart';
import 'package:courtly/services/firebase_direct_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapFirebaseAuthError', () {
    test('sai email hoặc mật khẩu dùng chung một thông báo 401', () {
      for (final code in [
        'invalid-credential',
        'wrong-password',
        'user-not-found',
      ]) {
        final error = mapFirebaseAuthError(code);
        expect(error.statusCode, 401, reason: code);
        expect(error.message, 'Email hoặc mật khẩu không đúng.', reason: code);
      }
    });

    test('email đã tồn tại là 409, mật khẩu yếu là 400', () {
      expect(mapFirebaseAuthError('email-already-in-use').statusCode, 409);
      expect(mapFirebaseAuthError('weak-password').statusCode, 400);
      expect(mapFirebaseAuthError('invalid-email').statusCode, 400);
    });

    test('thao tác quá nhanh là 429, tài khoản bị khoá là 403', () {
      expect(mapFirebaseAuthError('too-many-requests').statusCode, 429);
      expect(mapFirebaseAuthError('user-disabled').statusCode, 403);
    });

    test('mất mạng dùng lại AuthException.network', () {
      expect(
        mapFirebaseAuthError('network-request-failed'),
        same(AuthException.network),
      );
    });

    test('mã lạ vẫn có thông báo và kèm mã lỗi', () {
      final error = mapFirebaseAuthError('abc-xyz');
      expect(error.message, contains('abc-xyz'));
    });
  });

  group('mapFirestoreError', () {
    test('permission-denied nhắc kiểm tra Security Rules', () {
      final error = mapFirestoreError('permission-denied');
      expect(error.statusCode, 403);
      expect(error.message, contains('Security Rules'));
    });

    test('unavailable là lỗi mạng, chưa tạo database là 503', () {
      expect(mapFirestoreError('unavailable'), same(AuthException.network));
      expect(mapFirestoreError('failed-precondition').statusCode, 503);
    });
  });
}
