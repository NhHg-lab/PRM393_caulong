import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';

import '../config/app_config.dart';
import '../models/auth_models.dart';
import 'auth_service.dart';
import 'google_token_provider.dart';

/// Chế độ `AUTH_MODE=firebase`: Flutter nói chuyện thẳng với Firebase,
/// KHÔNG qua backend Spring Boot và KHÔNG dùng SQL Server.
///
/// - Tài khoản/mật khẩu/Google: Firebase Authentication.
/// - Hồ sơ (họ tên, SĐT, vai trò): Firestore, collection `users/{uid}`.
/// - Xác minh email: Firebase gửi email xác minh khi đăng ký và email đặt lại
///   mật khẩu (liên kết, không phải OTP 6 số).
///
/// Vai trò `ADMIN` chỉ gán được thủ công trong Firebase Console; Security Rules
/// (firestore.rules) không cho người dùng tự đổi vai trò.
class FirebaseDirectAuthService implements AuthService {
  FirebaseDirectAuthService({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _authOverride = auth,
       _firestoreOverride = firestore;

  final fb.FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  fb.FirebaseAuth get _auth => _authOverride ?? fb.FirebaseAuth.instance;
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  static const usersCollection = 'users';
  static const demoEmail = 'demo@courtly.vn';
  static const demoPassword = '123456';

  /// ID token của Firebase sống 1 giờ; coi như hết hạn sau 55 phút để làm mới sớm.
  static const _tokenLifetime = Duration(minutes: 55);

  @override
  LoginRequest get demoAccount =>
      const LoginRequest(identifier: demoEmail, password: demoPassword);

  // ---- Đăng nhập / đăng ký -------------------------------------------------

  @override
  Future<AuthSession> login(LoginRequest request) => _guard(() async {
    final email = request.identifier.trim();
    if (!email.contains('@')) {
      throw const AuthException(
        'Chế độ Firebase chỉ hỗ trợ đăng nhập bằng email.',
        statusCode: 400,
      );
    }
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: request.password,
    );
    return _sessionFor(_requireUser(credential), authProvider: 'LOCAL');
  });

  /// Firebase không dùng OTP 6 số khi đăng ký (nó gửi email xác minh sau khi tạo).
  @override
  bool get requiresSignupOtp => false;

  @override
  Future<OtpSent> sendRegisterOtp(String email) async {
    throw const AuthException('Chế độ Firebase không dùng OTP khi đăng ký.');
  }

  @override
  Future<AuthSession> signup(SignupRequest request) => _guard(() async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: request.email.trim(),
      password: request.password,
    );
    final user = _requireUser(credential);
    try {
      await user.updateDisplayName(request.fullName.trim());
      await _createProfile(
        user,
        fullName: request.fullName.trim(),
        phone: request.phone,
        authProvider: 'LOCAL',
      );
    } catch (_) {
      // Chưa có hồ sơ thì đăng xuất để không kẹt ở trạng thái nửa vời.
      // Lần đăng nhập sau sẽ tự tạo hồ sơ còn thiếu.
      await _auth.signOut();
      rethrow;
    }
    try {
      await user.sendEmailVerification();
    } catch (_) {
      // Gửi email xác minh là phần phụ, không làm hỏng đăng ký.
    }
    return _sessionFor(user, authProvider: 'LOCAL');
  });

  // ---- Quên mật khẩu -------------------------------------------------------

  /// Firebase gửi LIÊN KẾT đặt lại mật khẩu qua email, không dùng OTP 6 số,
  /// nên màn quên mật khẩu 2 bước không áp dụng. AuthScreen dùng
  /// [sendPasswordResetLink] ở chế độ này.
  @override
  bool get supportsPasswordReset => false;

  @override
  Future<OtpSent> sendPasswordResetOtp(String email) async {
    throw const AuthException('Chế độ Firebase đặt lại mật khẩu bằng liên kết email.');
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    throw const AuthException('Chế độ Firebase đặt lại mật khẩu bằng liên kết email.');
  }

  /// Gửi email chứa liên kết đặt lại mật khẩu. Firebase trả thành công kể cả khi
  /// email chưa đăng ký (bảo vệ chống dò email), nên không lộ email nào tồn tại.
  Future<void> sendPasswordResetLink(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  // ---- Google --------------------------------------------------------------

  /// Google Sign-In đã đăng nhập Firebase trước khi tới đây (xem
  /// FirebaseAuthService.signInWithGoogle), nên chỉ cần lấy người dùng hiện tại.
  /// [idToken] không cần gửi đi đâu vì không có backend.
  @override
  Future<AuthSession> loginWithGoogleIdToken(String idToken) => _guard(() async {
    if (MockGoogleAccount.parse(idToken) != null) {
      throw const AuthException(
        'Chế độ Firebase cần GOOGLE_MODE=firebase, không dùng được Google giả.',
        statusCode: 400,
      );
    }
    final user = await _currentUser();
    if (user == null) throw AuthException.sessionExpired;
    return _sessionFor(user, authProvider: 'GOOGLE');
  });

  // ---- Phiên ---------------------------------------------------------------

  @override
  Future<AuthSession> refresh(AuthSession current) async {
    try {
      final user = await _currentUser();
      if (user == null) throw AuthException.sessionExpired;
      final token = await user.getIdToken(true);
      if (token == null) throw AuthException.sessionExpired;
      return current.copyWith(
        accessToken: token,
        expiresAt: DateTime.now().add(_tokenLifetime),
      );
    } catch (_) {
      throw AuthException.sessionExpired;
    }
  }

  /// Đọc hồ sơ mới nhất (vai trò, tên) từ Firestore. 401 nếu Firebase không còn
  /// người dùng; lỗi mạng ném [AuthException.network] để giữ phiên đã lưu.
  @override
  Future<AppUser?> fetchProfile(AuthSession session) => _guard(() async {
    final user = await _currentUser();
    if (user == null) throw AuthException.sessionExpired;
    final snapshot = await _db.collection(usersCollection).doc(user.uid).get();
    if (!snapshot.exists) return null;
    return _userFromData(user, snapshot.data() ?? const {});
  });

  @override
  Future<void> logout(AuthSession session) async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Đăng xuất phía máy khách vẫn tiếp tục.
    }
  }

  // ---- Hỗ trợ --------------------------------------------------------------

  fb.User _requireUser(fb.UserCredential credential) {
    final user = credential.user;
    if (user == null) {
      throw const AuthException('Firebase không trả về người dùng.');
    }
    return user;
  }

  /// Firebase khôi phục người dùng đã lưu bất đồng bộ lúc khởi động, nên có lúc
  /// currentUser còn null dù đã đăng nhập từ lần trước.
  Future<fb.User?> _currentUser() async {
    final current = _auth.currentUser;
    if (current != null) return current;
    return _auth
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 3), onTimeout: () => null);
  }

  Future<AuthSession> _sessionFor(
    fb.User user, {
    required String authProvider,
  }) async {
    final profile = await _loadOrCreateProfile(user, authProvider);
    final token = await user.getIdToken();
    if (token == null) {
      throw const AuthException('Không lấy được ID token từ Firebase.');
    }
    return AuthSession(
      accessToken: token,
      refreshToken: null,
      expiresAt: DateTime.now().add(_tokenLifetime),
      user: profile,
    );
  }

  Future<AppUser> _loadOrCreateProfile(fb.User user, String authProvider) async {
    final reference = _db.collection(usersCollection).doc(user.uid);
    final snapshot = await reference.get();
    if (snapshot.exists) {
      return _userFromData(user, snapshot.data() ?? const {});
    }
    // Tài khoản Google lần đầu, hoặc đăng ký từng bị dở dang: tạo hồ sơ còn thiếu.
    return _createProfile(
      user,
      fullName: user.displayName,
      phone: user.phoneNumber,
      authProvider: authProvider,
    );
  }

  Future<AppUser> _createProfile(
    fb.User user, {
    required String? fullName,
    required String? phone,
    required String authProvider,
  }) async {
    final email = (user.email ?? '').toLowerCase();
    final name = (fullName == null || fullName.trim().isEmpty)
        ? (email.contains('@') ? email.split('@').first : 'Người dùng')
        : fullName.trim();
    await _db.collection(usersCollection).doc(user.uid).set({
      'fullName': name,
      'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      // Vai trò luôn là CUSTOMER khi tự tạo; Security Rules chặn giá trị khác.
      'role': 'CUSTOMER',
      'authProvider': authProvider,
      if (user.photoURL != null) 'avatarUrl': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return AppUser(
      id: user.uid,
      fullName: name,
      email: email,
      phone: phone,
      avatarUrl: user.photoURL,
      authProvider: authProvider,
    );
  }

  AppUser _userFromData(fb.User user, Map<String, dynamic> data) => AppUser(
    id: user.uid,
    fullName: (data['fullName'] as String?) ?? user.displayName ?? '',
    email: (data['email'] as String?) ?? user.email ?? '',
    phone: data['phone'] as String?,
    role: UserRole.fromApi(data['role']),
    avatarUrl: (data['avatarUrl'] as String?) ?? user.photoURL,
    authProvider: (data['authProvider'] as String?) ?? 'LOCAL',
  );

  Future<T> _guard<T>(Future<T> Function() body) async {
    if (Firebase.apps.isEmpty) {
      throw const AuthException(
        'Firebase chưa được cấu hình (thiếu google-services.json hoặc chưa khởi tạo).',
      );
    }
    try {
      return await body().timeout(AppConfig.requestTimeout);
    } on AuthException {
      rethrow;
    } on fb.FirebaseAuthException catch (error) {
      throw mapFirebaseAuthError(error.code);
    } on FirebaseException catch (error) {
      throw mapFirestoreError(error.code);
    } on TimeoutException {
      throw AuthException.timeout;
    }
  }
}

/// Đổi mã lỗi của Firebase Authentication thành thông báo tiếng Việt.
AuthException mapFirebaseAuthError(String code) => switch (code) {
  'invalid-credential' ||
  'invalid-login-credentials' ||
  'wrong-password' ||
  'user-not-found' => const AuthException(
    'Email hoặc mật khẩu không đúng.',
    statusCode: 401,
  ),
  'invalid-email' => const AuthException(
    'Email không hợp lệ.',
    statusCode: 400,
  ),
  'email-already-in-use' => const AuthException(
    'Email này đã được đăng ký.',
    statusCode: 409,
  ),
  'weak-password' => const AuthException(
    'Mật khẩu quá yếu (tối thiểu 6 ký tự).',
    statusCode: 400,
  ),
  'user-disabled' => const AuthException(
    'Tài khoản đã bị khoá.',
    statusCode: 403,
  ),
  'too-many-requests' => const AuthException(
    'Bạn thao tác quá nhanh, vui lòng thử lại sau.',
    statusCode: 429,
  ),
  'network-request-failed' => AuthException.network,
  'operation-not-allowed' => const AuthException(
    'Chưa bật đăng nhập Email/Password trong Firebase Console.',
    statusCode: 503,
  ),
  _ => AuthException('Firebase báo lỗi ($code).'),
};

/// Đổi mã lỗi của Cloud Firestore thành thông báo tiếng Việt.
AuthException mapFirestoreError(String code) => switch (code) {
  'permission-denied' => const AuthException(
    'Firestore từ chối quyền truy cập. Hãy kiểm tra Security Rules (firestore.rules).',
    statusCode: 403,
  ),
  'unavailable' || 'deadline-exceeded' => AuthException.network,
  'not-found' || 'failed-precondition' => const AuthException(
    'Chưa tạo Firestore Database trong Firebase Console.',
    statusCode: 503,
  ),
  _ => AuthException('Firestore báo lỗi ($code).'),
};
