import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await CustomNotificationSoundService().initialize();
  debugPrint('Background message received: ${message.messageId}');
}

class CustomNotificationSoundService {
  static final CustomNotificationSoundService _instance =
      CustomNotificationSoundService._internal();
  factory CustomNotificationSoundService() => _instance;
  CustomNotificationSoundService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification tapped: ${details.payload}');
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'notification_id',
      'Custom Notifications',
      description: 'Notifications with custom sound',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('sound'),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message received: ${message.messageId}');
      showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Background notification tapped: ${message.messageId}');
    });

    final RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        'App opened from terminated state by notification: ${initialMessage.messageId}',
      );
    }

    // Get the APNs token (only iOS)
    // String? apnsToken = await _firebaseMessaging.getAPNSToken();
    // print('APNs Token: $apnsToken');

    // final String? token = await _firebaseMessaging.getToken();
    // debugPrint('FCM Token: $token');

    _isInitialized = true;
  }

  Future<void> showNotification(RemoteMessage message) async {
    await _showNotificationStatic(message);
  }

  static Future<void> _showNotificationStatic(RemoteMessage message) async {
    String? title;
    String? body;

    if (message.notification != null) {
      title = message.notification?.title;
      body = message.notification?.body;
    } else {
      title = message.data['title']?.toString();
      body = message.data['body']?.toString();
    }

    if (Platform.isAndroid) {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'notification_id',
            'Custom Notifications',
            channelDescription: 'Notifications with custom sound',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('sound'),
            icon: '@mipmap/ic_launcher',
          );

      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: message.data.toString(),
      );
    } else {
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        sound: 'notification_sound.aiff',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(iOS: iosDetails),
        payload: message.data.toString(),
      );
    }
  }
}
