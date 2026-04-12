import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:flutter/foundation.dart';

String? deviceTokenToSendPushNotification = '';
Map<String, dynamic>? getDeviceInfo;
String? fcmTokenGet = '';

class Functions {
  static Future<String?> getDeviceTokenToSendNotification() async {
    if (kIsWeb) {
      return null;
    }

    final fcm = FirebaseMessaging.instance;
    final token = await fcm.getToken();
    if (token != null && token.isNotEmpty) {
      fcmTokenGet = token;
      await LocalStorage.setValue(PreferencesKey.fcmToken, token);
      if (kDebugMode) {
        print('FCM Token: $token');
      }
      return token;
    }
    return null;
  }
}
