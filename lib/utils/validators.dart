/// Các hàm validate dùng cho `TextFormField.validator`.
/// Trả về null khi hợp lệ, ngược lại trả về thông báo lỗi tiếng Việt.
abstract final class Validators {
  static final _email = RegExp(
    r'^[\w.+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$',
  );
  // Khớp backend: 0xxxxxxxxx hoặc +84xxxxxxxxx (sau normalizePhone luôn là 10 số, đầu 0).
  static final _phone = RegExp(r'^0\d{9}$');
  static final _username = RegExp(r'^[A-Za-z][A-Za-z0-9_.]{2,29}$');

  /// Email hoặc SĐT Việt Nam. [allowUsername] dùng cho chế độ DummyJSON (emilys).
  static String? identifier(String? value, {bool allowUsername = false}) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Vui lòng nhập email hoặc số điện thoại';
    if (input.contains('@')) return email(input);
    if (allowUsername && RegExp('[A-Za-z]').hasMatch(input)) {
      return _username.hasMatch(input) ? null : 'Tên đăng nhập không hợp lệ';
    }
    return _phone.hasMatch(normalizePhone(input))
        ? null
        : 'Số điện thoại gồm 10 chữ số, bắt đầu bằng 0 hoặc +84';
  }

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Vui lòng nhập email';
    return _email.hasMatch(input) ? null : 'Email không đúng định dạng';
  }

  /// SĐT không bắt buộc (form đăng ký).
  static String? optionalPhone(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null;
    return _phone.hasMatch(normalizePhone(input))
        ? null
        : 'Số điện thoại gồm 10 chữ số, bắt đầu bằng 0 hoặc +84';
  }

  /// Bỏ khoảng trắng, dấu chấm, gạch ngang; đổi +84 thành 0.
  static String normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'[\s.\-()]'), '');
    return digits.startsWith('+84') ? '0${digits.substring(3)}' : digits;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
    return null;
  }

  static String? signupPassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.trim() != value) {
      return 'Mật khẩu không được có khoảng trắng ở đầu hoặc cuối';
    }
    if (value.length < 8) return 'Mật khẩu tối thiểu 8 ký tự';
    if (!RegExp('[A-Z]').hasMatch(value)) {
      return 'Mật khẩu cần ít nhất 1 chữ in hoa';
    }
    if (!RegExp(r'\d').hasMatch(value)) return 'Mật khẩu cần ít nhất 1 chữ số';
    return null;
  }

  static String? otp(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Vui lòng nhập mã OTP';
    return RegExp(r'^\d{6}$').hasMatch(input) ? null : 'Mã OTP gồm 6 chữ số';
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập lại mật khẩu';
    return value == original ? null : 'Mật khẩu xác nhận không khớp';
  }

  static String? fullName(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Vui lòng nhập họ và tên';
    if (input.length < 2) return 'Họ và tên quá ngắn';
    if (input.length > 60) return 'Họ và tên tối đa 60 ký tự';
    if (RegExp(r'[\d!@#$%^&*()_+=\[\]{};:"\\|<>/?~`]').hasMatch(input)) {
      return 'Họ và tên chỉ gồm chữ cái và khoảng trắng';
    }
    return null;
  }
}
