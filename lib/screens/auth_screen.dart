import 'package:flutter/material.dart';

import '../services/auth_gateway.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authGateway,
    required this.onAuthenticated,
    required this.onDemoCustomer,
    required this.onDemoAdmin,
  });

  final AuthGateway authGateway;
  final ValueChanged<AuthSession> onAuthenticated;
  final VoidCallback onDemoCustomer;
  final VoidCallback onDemoAdmin;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BrandMark(),
                      const SizedBox(height: 38),
                      _AuthHero(isLogin: _isLogin),
                      const SizedBox(height: 28),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Column(
                          key: ValueKey(_isLogin),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_isLogin) ...[
                              TextFormField(
                                controller: _fullNameController,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                decoration: const InputDecoration(
                                  labelText: 'Họ và tên',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Vui lòng nhập họ tên'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              key: const Key('auth-email-field'),
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('auth-password-field'),
                              controller: _passwordController,
                              obscureText: _obscure,
                              autofillHints: [
                                _isLogin
                                    ? AutofillHints.password
                                    : AutofillHints.newPassword,
                              ],
                              onFieldSubmitted: (_) => _submit(),
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
                              validator: (value) =>
                                  value == null || value.length < 6
                                  ? 'Mật khẩu cần ít nhất 6 ký tự'
                                  : null,
                            ),
                            if (_isLogin)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _loading
                                      ? null
                                      : _sendPasswordReset,
                                  child: const Text('Quên mật khẩu?'),
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text(
                                  'Firebase sẽ gửi liên kết xác minh tới email trước khi đăng nhập.',
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
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isLogin ? 'Đăng nhập' : 'Tạo tài khoản',
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'hoặc',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        key: const Key('google-login-button'),
                        onPressed: _loading ? null : _signInWithGoogle,
                        icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                        label: const Text('Tiếp tục với Google'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        key: const Key('demo-customer-button'),
                        onPressed: _loading ? null : widget.onDemoCustomer,
                        icon: const Icon(Icons.travel_explore_rounded),
                        label: const Text('Khám phá giao diện demo'),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLogin
                                ? 'Chưa có tài khoản?'
                                : 'Đã có tài khoản?',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: _loading ? null : _toggleMode,
                            child: Text(
                              _isLogin ? 'Đăng ký ngay' : 'Đăng nhập',
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        key: const Key('admin-login-button'),
                        onPressed: _loading ? null : widget.onDemoAdmin,
                        icon: const Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 19,
                        ),
                        label: const Text('Xem demo quản trị'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Vui lòng nhập email';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Email không đúng định dạng';
    }
    return null;
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        final session = await widget.authGateway.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (mounted) {
          widget.onAuthenticated(session);
        }
      } else {
        await widget.authGateway.register(
          fullName: _fullNameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (mounted) {
          setState(() => _isLogin = true);
          _showMessage(
            'Đã tạo tài khoản. Kiểm tra email, bấm liên kết xác minh rồi đăng nhập.',
          );
        }
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Có lỗi xảy ra, vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final session = await widget.authGateway.signInWithGoogle();
      if (mounted) {
        widget.onAuthenticated(session);
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Không thể đăng nhập Google lúc này.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_validateEmail(_emailController.text) != null) {
      _showMessage('Nhập email hợp lệ trước khi đặt lại mật khẩu.');
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.authGateway.sendPasswordReset(_emailController.text);
      _showMessage('Firebase đã gửi liên kết đặt lại mật khẩu.');
    } on AuthException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
                    : 'Tạo tài khoản an toàn với Firebase.',
                style: const TextStyle(color: Color(0xFFB9C7D2), fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
