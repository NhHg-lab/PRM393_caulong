import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthSession {
  const AuthSession({required this.email});

  final String email;

  // Quản trị hiện chỉ là màn hình demo. Tài khoản Firebase là người dùng app.
  bool get isAdmin => false;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AuthGateway {
  Future<AuthSession?> restoreSession();

  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  });

  Future<AuthSession> signInWithGoogle();

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

/// Fallback an toàn cho widget test và preview, không truy cập Firebase.
class DemoAuthGateway implements AuthGateway {
  const DemoAuthGateway();

  Never _unavailable() =>
      throw const AuthException('Firebase chưa được khởi tạo.');

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async => _unavailable();

  @override
  Future<void> sendPasswordReset(String email) async => _unavailable();

  @override
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async => _unavailable();

  @override
  Future<AuthSession> signInWithGoogle() async => _unavailable();

  @override
  Future<void> signOut() async {}
}

class FirebaseCourtlyAuthGateway implements AuthGateway {
  FirebaseCourtlyAuthGateway({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;
  bool _googleInitialized = false;

  @override
  Future<AuthSession?> restoreSession() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return null;
      }

      await user.reload();
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null || !currentUser.emailVerified) {
        await _firebaseAuth.signOut();
        return null;
      }
      return _sessionFrom(currentUser);
    } on FirebaseAuthException {
      await _firebaseAuth.signOut();
      return null;
    }
  }

  @override
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.reload();
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw const AuthException('Không đọc được tài khoản Firebase.');
      }
      if (!user.emailVerified) {
        await user.sendEmailVerification();
        await _firebaseAuth.signOut();
        throw const AuthException(
          'Email chưa được xác minh. Courtly vừa gửi lại liên kết xác minh.',
        );
      }
      return _sessionFrom(user);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseMessage(error));
    }
  }

  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('Không tạo được tài khoản Firebase.');
      }
      await user.updateDisplayName(fullName.trim());
      await user.sendEmailVerification();
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseMessage(error));
    }
  }

  @override
  Future<AuthSession> signInWithGoogle() async {
    try {
      await _initializeGoogle();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = await _firebaseAuth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: googleAuth.idToken),
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('Không đọc được tài khoản Google.');
      }
      return _sessionFrom(user);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException('Đã hủy đăng nhập Google.');
      }
      throw AuthException(
        error.description ?? 'Không thể đăng nhập Google lúc này.',
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseMessage(error));
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (email.trim().isEmpty) {
      throw const AuthException('Vui lòng nhập email trước.');
    }
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseMessage(error));
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    try {
      await _initializeGoogle();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Firebase sign-out ở trên đã đủ để kết thúc phiên trong ứng dụng.
    }
  }

  Future<void> _initializeGoogle() async {
    if (_googleInitialized) {
      return;
    }
    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }

  static AuthSession _sessionFrom(User user) {
    final email = user.email?.trim() ?? '';
    if (email.isEmpty) {
      throw const AuthException('Tài khoản Firebase không có email.');
    }
    return AuthSession(email: email);
  }

  static String _firebaseMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Email không đúng định dạng.',
      'email-already-in-use' => 'Email này đã được đăng ký.',
      'weak-password' => 'Mật khẩu cần ít nhất 6 ký tự.',
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' => 'Email hoặc mật khẩu không đúng.',
      'user-disabled' => 'Tài khoản đã bị vô hiệu hóa.',
      'too-many-requests' => 'Thử quá nhiều lần, vui lòng đợi rồi thử lại.',
      'network-request-failed' => 'Không có kết nối tới Firebase.',
      _ => error.message ?? 'Xác thực Firebase thất bại.',
    };
  }
}
