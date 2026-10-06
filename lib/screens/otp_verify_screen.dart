import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/auth_models.dart';
import '../services/auth_manager.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

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

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _codeController = TextEditingController();
  Timer? _timer;

  late String _message;
  late int _expiresIn;
  late int _resendIn;

  bool _verifying = false;
  bool _resending = false;
  String? _error;

  AuthManager get _auth => AuthManager.instance;

  @override
  void initState() {
    super.initState();
    _applySent(widget.initialOtp);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _applySent(OtpSent sent) {
    _message = sent.message;
    _expiresIn = sent.expiresIn;
    _resendIn = sent.resendAfter;
  }

  /// Đếm ngược mỗi giây; tự dừng khi cả hai bộ đếm về 0.
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_expiresIn == 0 && _resendIn == 0) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_expiresIn > 0) _expiresIn--;
        if (_resendIn > 0) _resendIn--;
      });
    });
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
    if (_resending || _resendIn > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final sent = await _auth.sendRegisterOtp(widget.request.email);
      if (!mounted) return;
      setState(() {
        _applySent(sent);
        _codeController.clear();
      });
      _startTimer();
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

  static String _mmss(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expired = _expiresIn == 0;
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
                _message,
                key: const Key('otp-message'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              TextField(
                key: const Key('otp-code-field'),
                controller: _codeController,
                enabled: !_verifying,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _verify(),
                decoration: InputDecoration(
                  hintText: '000000',
                  errorText: _error,
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                expired
                    ? 'Mã đã hết hạn, hãy gửi lại mã mới.'
                    : 'Mã còn hiệu lực trong ${_mmss(_expiresIn)}',
                key: const Key('otp-expiry'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: expired ? AppColors.danger : AppColors.muted,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                key: const Key('otp-confirm-button'),
                onPressed: _verifying || expired ? null : _verify,
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
              TextButton(
                key: const Key('otp-resend-button'),
                onPressed: (_resendIn > 0 || _resending || _verifying)
                    ? null
                    : _resend,
                child: Text(
                  _resendIn > 0
                      ? 'Gửi lại mã sau ${_resendIn}s'
                      : 'Gửi lại mã',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
