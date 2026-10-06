import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../services/auth_manager.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/otp_widgets.dart';

/// Bước 2 của đăng ký: nhập mã OTP 6 số đã gửi qua email.
///
/// Tài khoản chỉ được tạo khi mã đúng. Đăng ký thành công thì AuthManager báo
/// trạng thái mới và main.dart tự đóng màn này rồi chuyển sang Home, nên màn
/// này không tự điều hướng.
class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.request,
    required this.initialOtp,
  });

  /// Thông tin đăng ký đã nhập ở màn trước (chưa có `otp`).
  final SignupRequest request;

  /// Kết quả của lần gửi OTP đầu tiên (thời hạn, thời gian chờ gửi lại).
  final OtpSent initialOtp;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> with OtpCountdown {
  final _codeController = TextEditingController();

  bool _verifying = false;
  bool _resending = false;
  String? _error;

  AuthManager get _auth => AuthManager.instance;

  @override
  void initState() {
    super.initState();
    applyOtpSent(widget.initialOtp);
    startOtpCountdown();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    final code = _codeController.text.trim();
    final problem = Validators.otp(code);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final user = await _auth.signup(widget.request.copyWith(otp: code));
      unawaited(NotificationService.instance.showLoginSuccess(user.fullName));
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Đã có lỗi xảy ra, vui lòng thử lại.');
      }
    } finally {
      // Sau khi đăng ký thành công màn này đã bị đóng, nên phải kiểm tra mounted.
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || resendIn > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final sent = await _auth.sendRegisterOtp(widget.request.email);
      if (!mounted) return;
      setState(() {
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
      if (mounted) setState(() => _resending = false);
    }
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
                  key: const Key('otp-back-button'),
                  tooltip: 'Quay lại sửa thông tin',
                  onPressed: _verifying ? null : () => Navigator.pop(context),
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
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 34,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Xác minh email',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                otpMessage,
                key: const Key('otp-message'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              OtpCodeField(
                key: const Key('otp-code-field'),
                controller: _codeController,
                enabled: !_verifying,
                autofocus: true,
                errorText: _error,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 12),
              OtpExpiryText(key: const Key('otp-expiry'), expiresIn: expiresIn),
              const SizedBox(height: 22),
              FilledButton(
                key: const Key('otp-confirm-button'),
                onPressed: _verifying || otpExpired ? null : _verify,
                child: _verifying
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.navy,
                        ),
                      )
                    : const Text('Xác nhận và tạo tài khoản'),
              ),
              const SizedBox(height: 8),
              OtpResendButton(
                key: const Key('otp-resend-button'),
                resendIn: resendIn,
                onPressed: (_resending || _verifying) ? null : _resend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
