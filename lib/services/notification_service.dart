import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thông báo cục bộ (LO7). Tách riêng khỏi logic xác thực:
/// UI gọi sau khi đăng nhập thành công.
/// Mọi lỗi đều được nuốt lại vì thông báo không được làm hỏng luồng chính.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'courtly_account',
    'Tài khoản',
    description: 'Thông báo về đăng nhập và bảo mật tài khoản',
    importance: Importance.high,
  );

  Future<bool>? _initializing;
  bool _permissionAsked = false;
  int _nextId = 0;

  /// Chỉ hỗ trợ Android, iOS, macOS; nền tảng khác bỏ qua êm.
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Gọi được nhiều lần, chỉ khởi tạo một lần.
  Future<bool> initialize() => _initializing ??= _initialize();

  Future<bool> _initialize() async {
    if (!_supported) return false;
    try {
      // Xin quyền ở requestPermission(), không xin ngay lúc mở app.
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: darwin,
          macOS: darwin,
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
      return true;
    } catch (error) {
      debugPrint('NotificationService: khởi tạo thất bại ($error)');
      return false;
    }
  }

  /// Xin quyền hiển thị thông báo (POST_NOTIFICATIONS trên Android 13+).
  Future<bool> requestPermission() async {
    if (!await initialize()) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      final macos = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      return await macos?.requestPermissions(alert: true, sound: true) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> show(String title, String body) async {
    if (!await initialize()) return;
    try {
      if (!_permissionAsked) {
        _permissionAsked = true;
        await requestPermission();
      }
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
          macOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (error) {
      debugPrint('NotificationService: không hiển thị được thông báo ($error)');
    }
  }

  Future<void> showLoginSuccess(String userName) =>
      show('Đăng nhập thành công', 'Chào mừng $userName quay lại Courtly!');
}
