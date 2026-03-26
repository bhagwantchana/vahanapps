import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:flutter/foundation.dart';

String? deviceTokenToSendPushNotification = "";
Map<String, dynamic>? getDeviceInfo;
String? fcmTokenGet = "";

class Functions {
  static Future<void> getDeviceTokenToSendNotification() async {
    // Skip if web
    if (kIsWeb) return;
    final fcm = FirebaseMessaging.instance;
    // ✅ Get FCM Token
    final token = await fcm.getToken();
    if (token != null) {
      fcmTokenGet = token;
      LocalStorage.setValue(PreferencesKey.fcmToken, token);
      if (kDebugMode) {
        print("✅ FCM Token: $fcmTokenGet");
      }
    } else {
      if (kDebugMode) {
        print("🔴 FCM Token is null — check APNs config or permissions.");
      }
    }
  }
}
