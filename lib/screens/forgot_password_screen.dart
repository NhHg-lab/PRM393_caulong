import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../services/auth_manager.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/otp_widgets.dart';

/// Quên mật khẩu, 2 bước:
/// 1. Nhập email -> server gửi OTP (phản hồi giống nhau dù email có tồn tại hay không).
/// 2. Nhập OTP + mật khẩu mới -> đổi mật khẩu.
///
/// Thành công thì `pop` về màn đăng nhập và trả về email vừa đặt lại để
/// AuthScreen điền sẵn. Server không cấp phiên mới: người dùng phải đăng nhập lại.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  /// Email đã gõ ở màn đăng nhập (nếu có) để điền sẵn.
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with OtpCountdown {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  /// false: bước 1 (nhập email), true: bước 2 (nhập OTP + mật khẩu mới).
  bool _codeSent = false;
  bool _sending = false;
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  /// Email đã gửi mã ở bước 1, dùng cho bước 2 và khi gửi lại mã.
  String _email = '';

  AuthManager get _auth => AuthManager.instance;
  bool get _busy => _sending || _submitting;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Bước 1, và cả "Gửi lại mã" ở bước 2.
  Future<void> _sendCode() async {
    if (_busy) return;
    if (!_codeSent && !(_emailFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final email = _codeSent ? _email : _emailController.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final sent = await _auth.sendPasswordResetOtp(email);
      if (!mounted) return;
      setState(() {
        _email = email;
        _codeSent = true;
        applyOtpSent(sent);
        _codeController.clear();
      });
      startOtpCountdown();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Đã có lỗi xảy ra, vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Bước 2: đổi mật khẩu bằng OTP.
  Future<void> _submitReset() async {
    if (_busy || otpExpired) return;
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _auth.resetPassword(
        email: _email,
        otp: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (mounted) Navigator.pop(context, _email);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Đã có lỗi xảy ra, vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Quay lại bước 1 để sửa email (không rời màn).
  void _changeEmail() {
    setState(() {
      _codeSent = false;
      _error = null;
      _codeController.clear();
      _passwordController.clear();
      _confirmController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  key: const Key('forgot-back-button'),
                  tooltip: 'Quay lại đăng nhập',
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.limeSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _codeSent
                        ? Icons.mark_email_unread_outlined
                        : Icons.lock_reset_rounded,
                    size: 34,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                _codeSent ? 'Đặt mật khẩu mới' : 'Quên mật khẩu',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                _codeSent ? otpMessage : 'Nhập email đã đăng ký, chúng tôi sẽ gửi mã OTP 6 số để đặt lại mật khẩu.',
                key: const Key('forgot-message'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              if (_codeSent) _buildResetStep() else _buildEmailStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('forgot-email-field'),
            controller: _emailController,
            enabled: !_busy,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            validator: Validators.email,
            onFieldSubmitted: (_) => _sendCode(),
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          if (_error != null) _ErrorText(_error!),
          const SizedBox(height: 22),
          FilledButton(
            key: const Key('forgot-send-button'),
            onPressed: _busy ? null : _sendCode,
            child: _sending
                ? const _ButtonSpinner()
                : const Text('Gửi mã xác minh'),
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dùng FormField để mã OTP cũng được validate cùng form.
          FormField<String>(
            validator: (_) => Validators.otp(_codeController.text),
            builder: (field) => OtpCodeField(
              key: const Key('reset-code-field'),
              controller: _codeController,
              enabled: !_busy,
              autofocus: true,
              errorText: field.errorText,
              onChanged: (_) {
                if (field.hasError) field.validate();
                if (_error != null) setState(() => _error = null);
              },
            ),
          ),
          const SizedBox(height: 12),
          OtpExpiryText(key: const Key('reset-expiry'), expiresIn: expiresIn),
          const SizedBox(height: 18),
          TextFormField(
            key: const Key('reset-password-field'),
            controller: _passwordController,
            enabled: !_busy,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            validator: Validators.signupPassword,
            decoration: InputDecoration(
              labelText: 'Mật khẩu mới',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('reset-confirm-field'),
            controller: _confirmController,
            enabled: !_busy,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitReset(),
            validator: (value) =>
                Validators.confirmPassword(value, _passwordController.text),
            decoration: const InputDecoration(
              labelText: 'Xác nhận mật khẩu mới',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          if (_error != null) _ErrorText(_error!),
          const SizedBox(height: 22),
          FilledButton(
            key: const Key('reset-submit-button'),
            onPressed: _busy || otpExpired ? null : _submitReset,
            child: _submitting
                ? const _ButtonSpinner()
                : const Text('Đặt lại mật khẩu'),
          ),
          const SizedBox(height: 8),
          OtpResendButton(
            key: const Key('reset-resend-button'),
            resendIn: resendIn,
            onPressed: _busy ? null : _sendCode,
          ),
          TextButton(
            key: const Key('reset-change-email-button'),
            onPressed: _busy ? null : _changeEmail,
            child: Text('Đổi email ($_email)'),
          ),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        message,
        key: const Key('forgot-error'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.danger),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.navy),
    );
  }
}
