import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.onCustomerLogin,
    required this.onAdminLogin,
  });
  final VoidCallback onCustomerLogin;
  final VoidCallback onAdminLogin;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _obscure = true;
  bool _remember = true;

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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Column(
                        key: ValueKey(_isLogin),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_isLogin) ...[
                            const TextField(
                              decoration: InputDecoration(
                                labelText: 'Họ và tên',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          const TextField(
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email hoặc số điện thoại',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            obscureText: _obscure,
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
                          if (_isLogin)
                            Row(
                              children: [
                                Checkbox(
                                  value: _remember,
                                  activeColor: AppColors.navy,
                                  onChanged: (value) => setState(
                                    () => _remember = value ?? false,
                                  ),
                                ),
                                const Text(
                                  'Ghi nhớ đăng nhập',
                                  style: TextStyle(fontSize: 13),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => _showMessage(
                                    'Liên kết đặt lại mật khẩu đã được gửi.',
                                  ),
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
                            onPressed: widget.onCustomerLogin,
                            child: Text(
                              _isLogin ? 'Đăng nhập' : 'Tạo tài khoản',
                            ),
                          ),
                        ],
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
                      onPressed: widget.onCustomerLogin,
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
                          onPressed: () => setState(() => _isLogin = !_isLogin),
                          child: Text(_isLogin ? 'Đăng ký ngay' : 'Đăng nhập'),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      key: const Key('admin-login-button'),
                      onPressed: widget.onAdminLogin,
                      icon: const Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 19,
                      ),
                      label: const Text('Vào trang quản trị'),
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

  void _showMessage(String message) {
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
