import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/auth_models.dart';
import '../services/auth_manager.dart';
import '../services/auth_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_direct_auth_service.dart';
import '../services/google_token_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/common_widgets.dart';
import '../widgets/mock_google_picker.dart';
import 'forgot_password_screen.dart';
import 'otp_verify_screen.dart';

/// Màn đăng nhập/đăng ký. Đăng nhập thành công thì AuthManager báo trạng thái
/// mới và main.dart tự chuyển màn, nên màn này không tự điều hướng.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLogin = true;
  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;

  AuthManager get _auth => AuthManager.instance;
  bool get _allowUsername => AppConfig.authMode == AuthMode.dummyJson;

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 56,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BrandMark(),
                    const SizedBox(height: 38),
                    _AuthHero(isLogin: _isLogin),
                    const SizedBox(height: 28),
                    Form(
                      key: _formKey,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Column(
                          key: ValueKey(_isLogin),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_isLogin) ...[
                              TextFormField(
                                key: const Key('auth-name-field'),
                                controller: _nameController,
                                enabled: !_loading,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                validator: Validators.fullName,
                                decoration: const InputDecoration(
                                  labelText: 'Họ và tên',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              key: const Key('auth-identifier-field'),
                              controller: _identifierController,
                              enabled: !_loading,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              validator: _isLogin
                                  ? (value) => Validators.identifier(
                                      value,
                                      allowUsername: _allowUsername,
                                    )
                                  : Validators.email,
                              decoration: InputDecoration(
                                labelText: _isLogin
                                    ? (_allowUsername
                                          ? 'Tên đăng nhập, email hoặc SĐT'
                                          : 'Email hoặc số điện thoại')
                                    : 'Email',
                                prefixIcon: const Icon(
                                  Icons.mail_outline_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (!_isLogin) ...[
                              TextFormField(
                                key: const Key('auth-phone-field'),
                                controller: _phoneController,
                                enabled: !_loading,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                validator: Validators.optionalPhone,
                                decoration: const InputDecoration(
                                  labelText: 'Số điện thoại (không bắt buộc)',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              key: const Key('auth-password-field'),
                              controller: _passwordController,
                              enabled: !_loading,
                              obscureText: _obscure,
                              textInputAction: _isLogin
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              onFieldSubmitted: (_) {
                                if (_isLogin) _submit();
                              },
                              validator: _isLogin
                                  ? Validators.loginPassword
                                  : Validators.signupPassword,
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            if (!_isLogin) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('auth-confirm-field'),
                                controller: _confirmController,
                                enabled: !_loading,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                validator: (value) =>
                                    Validators.confirmPassword(
                                      value,
                                      _passwordController.text,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Xác nhận mật khẩu',
                                  prefixIcon: Icon(Icons.lock_reset_rounded),
                                ),
                              ),
                            ],
                            if (_isLogin)
                              Row(
                                children: [
                                  Checkbox(
                                    value: _remember,
                                    activeColor: AppColors.navy,
                                    onChanged: _loading
                                        ? null
                                        : (value) => setState(
                                            () => _remember = value ?? false,
                                          ),
                                  ),
                                  const Text(
                                    'Ghi nhớ đăng nhập',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    key: const Key('forgot-password-button'),
                                    onPressed: _loading
                                        ? null
                                        : _openForgotPassword,
                                    child: const Text('Quên mật khẩu?'),
                                  ),
                                ],
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text(
                                  'Bằng việc đăng ký, bạn đồng ý với Điều khoản sử dụng và Chính sách bảo mật.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            FilledButton(
                              key: const Key('auth-primary-button'),
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppColors.navy,
                                      ),
                                    )
                                  : Text(
                                      _isLogin
                                          ? 'Đăng nhập'
                                          : (_auth.requiresSignupOtp
                                                ? 'Gửi mã xác minh'
                                                : 'Tạo tài khoản'),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'hoặc',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      key: const Key('google-login-button'),
                      onPressed: _loading ? null : _loginWithGoogle,
                      icon: const Text(
                        'G',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.blue,
                        ),
                      ),
                      label: const Text('Đăng nhập với Google'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('demo-login-button'),
                      onPressed: _loading
                          ? null
                          : () => _run(
                              () => _auth.loginDemo(remember: _remember),
                            ),
                      icon: const Icon(Icons.travel_explore_rounded),
                      label: const Text('Khám phá với tài khoản demo'),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isLogin ? 'Chưa có tài khoản?' : 'Đã có tài khoản?',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: _loading ? null : _toggleMode,
                          child: Text(_isLogin ? 'Đăng ký ngay' : 'Đăng nhập'),
                        ),
                      ],
                    ),
                    // Chỉ chế độ mock có sẵn tài khoản quản trị: bấm để điền sẵn form.
                    if (AppConfig.authMode == AuthMode.mock)
                      TextButton.icon(
                        key: const Key('admin-login-button'),
                        onPressed: _loading ? null : _fillAdminAccount,
                        icon: const Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 19,
                        ),
                        label: const Text(
                          'Quản trị viên demo: ${MockAuthService.adminEmail}',
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _toggleMode() {
    _formKey.currentState?.reset();
    _passwordController.clear();
    _confirmController.clear();
    setState(() => _isLogin = !_isLogin);
  }

  void _fillAdminAccount() {
    _identifierController.text = MockAuthService.adminEmail;
    _passwordController.text = MockAuthService.adminPassword;
    if (!_isLogin) setState(() => _isLogin = true);
  }

  Future<void> _submit() async {
    if (_loading || !(_formKey.currentState?.validate() ?? false)) return;
    final identifier = _identifierController.text.trim();
    if (_isLogin) {
      await _run(
        () => _auth.login(
          identifier.contains('@') || _allowUsername
              ? identifier
              : Validators.normalizePhone(identifier),
          _passwordController.text,
          remember: _remember,
        ),
      );
    } else {
      final phone = _phoneController.text.trim();
      final request = SignupRequest(
        fullName: _nameController.text.trim(),
        email: identifier,
        phone: phone.isEmpty ? null : Validators.normalizePhone(phone),
        password: _passwordController.text,
      );
      if (_auth.requiresSignupOtp) {
        await _startOtpFlow(request);
      } else {
        await _run(() => _auth.signup(request));
      }
    }
  }

  /// Đăng ký bước 1: gửi OTP tới email rồi mở màn nhập mã. Tài khoản chỉ được
  /// tạo ở bước 2 (OtpVerifyScreen) khi mã đúng.
  Future<void> _startOtpFlow(SignupRequest request) async {
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    OtpSent? sent;
    try {
      sent = await _auth.sendRegisterOtp(request.email);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Đã có lỗi xảy ra, vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (sent == null || !mounted) return;
    // Đăng ký thành công thì main.dart tự đóng màn OTP và chuyển sang Home.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OtpVerifyScreen(request: request, initialOtp: sent!),
      ),
    );
  }

  /// Mở màn quên mật khẩu. Thành công thì màn đó trả về email vừa đặt lại
  /// để điền sẵn vào ô đăng nhập.
  Future<void> _openForgotPassword() async {
    if (AppConfig.authMode == AuthMode.firebase) {
      await _sendFirebaseResetLink(_identifierController.text.trim());
      return;
    }
    if (!_auth.supportsPasswordReset) {
      _showMessage('Chế độ này không hỗ trợ đặt lại mật khẩu');
      return;
    }
    final typed = _identifierController.text.trim();
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: Validators.email(typed) == null ? typed : null,
        ),
      ),
    );
    if (email == null || !mounted) return;
    _identifierController.text = email;
    _passwordController.clear();
    _showMessage('Đặt lại mật khẩu thành công, hãy đăng nhập lại');
  }

  /// AUTH_MODE=firebase: Firebase gửi LIÊN KẾT đặt lại mật khẩu qua email
  /// (không có OTP 6 số như chế độ spring).
  Future<void> _sendFirebaseResetLink(String typed) async {
    final controller = TextEditingController(
      text: Validators.email(typed) == null ? typed : '',
    );
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quên mật khẩu'),
        content: TextField(
          key: const Key('firebase-reset-email'),
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Email đã đăng ký'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Gửi liên kết'),
          ),
        ],
      ),
    );
    if (email == null || !mounted) return;
    final problem = Validators.email(email);
    if (problem != null) {
      _showMessage(problem);
      return;
    }
    try {
      await FirebaseDirectAuthService().sendPasswordResetLink(email);
      _showMessage(
        'Nếu email đã đăng ký, Firebase đã gửi liên kết đặt lại mật khẩu. '
        'Hãy kiểm tra hộp thư (cả mục Spam).',
      );
    } on AuthException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _loginWithGoogle() async {
    switch (AppConfig.googleMode) {
      case GoogleMode.off:
        _showMessage('Đăng nhập Google chưa được bật');
      case GoogleMode.firebase:
        if (!FirebaseAuthService.instance.isAvailable) {
          _showMessage('Đăng nhập Google chưa được cấu hình');
          return;
        }
        await _run(() => _auth.loginWithGoogle(remember: _remember));
      case GoogleMode.mock:
        // Không cần Firebase: chọn tài khoản giả rồi đi tiếp đúng luồng Google.
        final account = await showMockGooglePicker(context);
        if (account == null || !mounted) return;
        await _run(
          () => _auth.loginWithGoogle(
            remember: _remember,
            provider: MockGoogleTokenProvider(account),
          ),
        );
    }
  }

  /// Chạy một thao tác xác thực: bật loading, báo lỗi bằng SnackBar.
  Future<void> _run(Future<AppUser> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final user = await action();
      // Thông báo nằm ngoài AuthService/AuthManager; lỗi thông báo không ảnh hưởng đăng nhập.
      unawaited(NotificationService.instance.showLoginSuccess(user.fullName));
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Đã có lỗi xảy ra, vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({required this.isLogin});
  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.navyDeep,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: .15),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -30,
            child: Icon(
              Icons.sports_tennis_rounded,
              size: 128,
              color: Colors.white.withValues(alpha: .07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusPill(
                label: 'CHƠI HAY HƠN MỖI NGÀY',
                color: AppColors.lime,
              ),
              const SizedBox(height: 16),
              Text(
                isLogin
                    ? 'Sân xịn đang\nchờ bạn.'
                    : 'Bắt đầu một\ntrận đấu mới.',
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                isLogin
                    ? 'Đặt sân nhanh, vào trận đúng giờ.'
                    : 'Tạo tài khoản trong chưa đầy một phút.',
                style: const TextStyle(color: Color(0xFFB9C7D2), fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
