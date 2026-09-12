import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeBridgeService {
  static const MethodChannel _channel = MethodChannel('com.birthday.teacher/native');

  static Future<bool> scheduleDailyWorker({int hour = 8, int minute = 0}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final result = await _channel.invokeMethod('scheduleDailyWorker', {
        'hour': hour,
        'minute': minute,
      });
      debugPrint('NativeBridge: $result');
      return true;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge Error: ${e.message}');
      return false;
    }
  }

  static Future<bool> cancelDailyWorker() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final result = await _channel.invokeMethod('cancelDailyWorker');
      debugPrint('NativeBridge: $result');
      return true;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge Error: ${e.message}');
      return false;
    }
  }

  static Future<bool> triggerTestNotification({String? title, String? message}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final result = await _channel.invokeMethod('triggerTestNotification', {
        'title': title ?? "🎂 Today's Student Birthday Alert!",
        'message': message ?? "Aarav Sharma (BCA - DS) is celebrating their birthday today. Tap to wish them!",
      });
      debugPrint('NativeBridge: $result');
      return true;
    } on PlatformException catch (e) {
      debugPrint('NativeBridge Error: ${e.message}');
      return false;
    }
  }

  static Future<bool> checkNotificationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final bool? isGranted = await _channel.invokeMethod<bool>('checkNotificationPermission');
      return isGranted ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> requestNotificationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final bool? isGranted = await _channel.invokeMethod<bool>('requestNotificationPermission');
      return isGranted ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> notifyBirthdayStudents({
    required List<String> names,
    required List<String> details,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final result = await _channel.invokeMethod('notifyBirthdayStudents', {
        'names': names,
        'details': details,
      });
      debugPrint('NativeBridge: $result');
      return true;
    } on MissingPluginException {
      // Graceful fallback to existing native method without requiring APK restart
      final title = names.length == 1
          ? "🎂 Today is ${names.first}'s Birthday!"
          : "🎂 ${names.length} Students Celebrating Birthday Today!";
      final message = details.join(" • ");
      return await triggerTestNotification(title: title, message: message);
    } catch (e) {
      debugPrint('NativeBridge Error: $e');
      return false;
    }
  }
}
