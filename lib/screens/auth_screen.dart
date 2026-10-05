import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/auth_models.dart';
import '../services/auth_manager.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/common_widgets.dart';

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
                                    onPressed: () =>
                                        _showMessage('Tính năng sắp ra mắt'),
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
                                      _isLogin ? 'Đăng nhập' : 'Tạo tài khoản',
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
      await _run(
        () => _auth.signup(
          SignupRequest(
            fullName: _nameController.text.trim(),
            email: identifier,
            phone: phone.isEmpty ? null : Validators.normalizePhone(phone),
            password: _passwordController.text,
          ),
        ),
      );
    }
  }

  void _loginWithGoogle() {
    if (!AppConfig.enableGoogleSignIn) {
      _showMessage('Đăng nhập Google chưa được cấu hình');
      return;
    }
    _run(() => _auth.loginWithGoogle(remember: _remember));
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
