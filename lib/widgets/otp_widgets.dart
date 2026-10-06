import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/auth_models.dart';
import '../theme/app_theme.dart';

/// Bộ đếm ngược dùng chung cho các màn nhập OTP (đăng ký, quên mật khẩu):
/// thời hạn của mã và thời gian chờ trước khi được gửi lại.
/// Timer tự huỷ trong [dispose].
mixin OtpCountdown<T extends StatefulWidget> on State<T> {
  Timer? _otpTimer;

  /// Thông điệp server trả về khi gửi mã.
  String otpMessage = '';

  /// Số giây mã còn hiệu lực.
  int expiresIn = 0;

  /// Số giây còn phải chờ trước khi được gửi lại mã.
  int resendIn = 0;

  bool get otpExpired => expiresIn == 0;

  void applyOtpSent(OtpSent sent) {
    otpMessage = sent.message;
    expiresIn = sent.expiresIn;
    resendIn = sent.resendAfter;
  }

  /// Đếm ngược mỗi giây; tự dừng khi cả hai bộ đếm về 0.
  void startOtpCountdown() {
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (expiresIn == 0 && resendIn == 0) {
        timer.cancel();
        return;
      }
      setState(() {
        if (expiresIn > 0) expiresIn--;
        if (resendIn > 0) resendIn--;
      });
    });
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    super.dispose();
  }
}

/// Ô nhập mã OTP 6 số, chữ to và giãn cách.
class OtpCodeField extends StatelessWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.autofocus = false,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool autofocus;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
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
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: '000000',
        errorText: errorText,
        errorMaxLines: 3,
      ),
    );
  }
}

/// Dòng "Mã còn hiệu lực trong mm:ss" / "Mã đã hết hạn...".
class OtpExpiryText extends StatelessWidget {
  const OtpExpiryText({super.key, required this.expiresIn});

  final int expiresIn;

  static String mmss(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  @override
  Widget build(BuildContext context) {
    final expired = expiresIn == 0;
    return Text(
      expired
          ? 'Mã đã hết hạn, hãy gửi lại mã mới.'
          : 'Mã còn hiệu lực trong ${mmss(expiresIn)}',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        color: expired ? AppColors.danger : AppColors.muted,
      ),
    );
  }
}

/// Nút "Gửi lại mã" bị khoá trong thời gian chờ.
class OtpResendButton extends StatelessWidget {
  const OtpResendButton({
    super.key,
    required this.resendIn,
    required this.onPressed,
  });

  final int resendIn;

  /// null khi đang bận (gửi/xác nhận) để khoá nút.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: resendIn > 0 ? null : onPressed,
      child: Text(resendIn > 0 ? 'Gửi lại mã sau ${resendIn}s' : 'Gửi lại mã'),
    );
  }
}
