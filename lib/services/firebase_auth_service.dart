import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';
import '../models/auth_models.dart';

/// Khởi tạo Firebase khi (và chỉ khi) đã bật Google Sign-In.
/// Không bao giờ ném lỗi: thiếu google-services.json thì app vẫn chạy bình thường.
Future<void> initFirebaseIfEnabled() async {
  if (!AppConfig.enableGoogleSignIn) return;
  try {
    // TODO(FIREBASE): nếu dùng FlutterFire CLI, đổi thành
    // Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase chưa được cấu hình: $error');
  }
}

/// Luồng Google Sign-In:
/// Google -> credential -> FirebaseAuth.signInWithCredential -> Firebase ID token.
/// Token này được AuthManager gửi tới AuthService.loginWithGoogleIdToken
/// để backend Spring xác minh và đổi sang JWT của hệ thống.
class FirebaseAuthService {
  FirebaseAuthService._();

  static final FirebaseAuthService instance = FirebaseAuthService._();

  bool _googleInitialized = false;

  bool get isAvailable =>
      AppConfig.enableGoogleSignIn && Firebase.apps.isNotEmpty;

  /// Trả về Firebase ID token của người dùng vừa đăng nhập Google.
  Future<String> signInWithGoogle() async {
    if (!isAvailable) {
      throw const AuthException('Đăng nhập Google chưa được cấu hình.');
    }
    try {
      final UserCredential result;
      if (kIsWeb) {
        // Web không hỗ trợ GoogleSignIn.authenticate(), dùng popup của Firebase.
        result = await FirebaseAuth.instance.signInWithPopup(
          GoogleAuthProvider(),
        );
      } else {
        await _ensureGoogleInitialized();
        final account = await GoogleSignIn.instance.authenticate();
        final googleIdToken = account.authentication.idToken;
        if (googleIdToken == null) {
          // TODO(FIREBASE): thường do thiếu AppConfig.googleServerClientId
          // hoặc chưa thêm SHA-1 vào Firebase Console.
          throw const AuthException('Không lấy được thông tin từ Google.');
        }
        result = await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(idToken: googleIdToken),
        );
      }
      final firebaseIdToken = await result.user?.getIdToken();
      if (firebaseIdToken == null) {
        throw const AuthException('Không lấy được Firebase ID token.');
      }
      return firebaseIdToken;
    } on GoogleSignInException catch (error) {
      throw AuthException(
        error.code == GoogleSignInExceptionCode.canceled
            ? 'Bạn đã huỷ đăng nhập Google.'
            : 'Đăng nhập Google thất bại (${error.code.name}).',
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(
        error.message ?? 'Đăng nhập Firebase thất bại (${error.code}).',
      );
    }
  }

  /// Đăng xuất cả Firebase lẫn Google để lần sau được chọn lại tài khoản.
  Future<void> signOut() async {
    if (!isAvailable) return;
    try {
      await FirebaseAuth.instance.signOut();
      if (!kIsWeb && _googleInitialized) await GoogleSignIn.instance.signOut();
    } catch (error) {
      debugPrint('FirebaseAuthService.signOut: $error');
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    // TODO(FIREBASE): điền AppConfig.googleServerClientId (Web client ID)
    // để Android trả về idToken.
    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleServerClientId,
    );
    _googleInitialized = true;
  }
}
