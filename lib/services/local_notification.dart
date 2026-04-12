import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/firebase_options.dart';
import 'package:fleet_monitor/networks/network_api.dart';
import 'package:fleet_monitor/screens/assigned_vehicle_maintenance_screen.dart';
import 'package:fleet_monitor/screens/dashboard.dart';
import 'package:fleet_monitor/screens/document_vault_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await CustomNotificationSoundService().initialize();
  if (message.notification == null) {
    await CustomNotificationSoundService().showNotification(message);
  }
}

class CustomNotificationSoundService {
  static const String _channelId = 'fleet_monitor_alert_channel_v2';
  static const String _channelName = 'Fleet Monitor Alerts';
  static const String _defaultAndroidSoundName = 'default_sound';
  static const String _defaultIosSoundFile = 'default_sound.wav';
  static const RawResourceAndroidNotificationSound _androidSound =
      RawResourceAndroidNotificationSound(_defaultAndroidSoundName);
  static const Map<String, _NotificationChannelConfig> _vehicleSoundChannels = {
    'generic_ignition_on': _NotificationChannelConfig(
      id: 'fleet_monitor_ignition_generic_v1',
      name: 'Fleet Monitor Ignition Generic',
      soundName: 'generic_ignition_on',
      iosSoundFile: 'generic_ignition_on.wav',
    ),
    'activa_custom_sound': _NotificationChannelConfig(
      id: 'fleet_monitor_ignition_activa_v2',
      name: 'Fleet Monitor Ignition Activa',
      soundName: 'activa_ignition_on',
      iosSoundFile: 'activa_ignition_on.wav',
    ),
    'activa_ignition_on': _NotificationChannelConfig(
      id: 'fleet_monitor_ignition_activa_v2',
      name: 'Fleet Monitor Ignition Activa',
      soundName: 'activa_ignition_on',
      iosSoundFile: 'activa_ignition_on.wav',
    ),
    'bike_ignition_on': _NotificationChannelConfig(
      id: 'fleet_monitor_ignition_bike_v1',
      name: 'Fleet Monitor Ignition Bike',
      soundName: 'bike_ignition_on',
      iosSoundFile: 'bike_ignition_on.wav',
    ),
    'car_ignition_on': _NotificationChannelConfig(
      id: 'fleet_monitor_ignition_car_v1',
      name: 'Fleet Monitor Ignition Car',
      soundName: 'car_ignition_on',
      iosSoundFile: 'car_ignition_on.wav',
    ),
    'car_ignition_off': _NotificationChannelConfig(
      id: 'fleet_monitor_ignition_car_off_v1',
      name: 'Fleet Monitor Ignition Car Off',
      soundName: 'car_ignition_off',
      iosSoundFile: 'car_ignition_off.wav',
    ),
    'bus_ignition_on': _NotificationChannelConfig(
      id: 'fleet_monitor_ignition_bus_v1',
      name: 'Fleet Monitor Ignition Bus',
      soundName: 'bus_ignition_on',
      iosSoundFile: 'bus_ignition_on.wav',
    ),
    'truck_ignition_on': _NotificationChannelConfig(
      id: 'fleet_monitor_ignition_truck_v1',
      name: 'Fleet Monitor Ignition Truck',
      soundName: 'truck_ignition_on',
      iosSoundFile: 'truck_ignition_on.wav',
    ),
  };
  static final CustomNotificationSoundService _instance =
      CustomNotificationSoundService._internal();

  factory CustomNotificationSoundService() => _instance;

  CustomNotificationSoundService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  String? _pendingNavigationPayload;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationTap(details.payload);
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Vehicle tracking notifications',
      importance: Importance.high,
      playSound: true,
      sound: _androidSound,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final config in _vehicleSoundChannels.values) {
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          config.id,
          config.name,
          description: 'Vehicle-specific ignition alerts',
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(config.soundName),
        ),
      );
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((message) {
      showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteNavigation);

    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteNavigation(initialMessage);
    }

    final token = await _firebaseMessaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _storeAndSyncToken(token);
    }

    _firebaseMessaging.onTokenRefresh.listen((token) {
      _storeAndSyncToken(token);
    });

    _isInitialized = true;
  }

  Future<void> _storeAndSyncToken(String token) async {
    await LocalStorage.setValue(PreferencesKey.fcmToken, token);
    await _syncTokenWithBackend(token);
  }

  Future<void> _syncTokenWithBackend(String token) async {
    final authToken = await LocalStorage.readValue(PreferencesKey.token) ?? '';
    if (authToken.isEmpty) {
      return;
    }

    final platform = _platformName;
    final api = NetworkApi();
    try {
      await api.sendRequest.post(
        AppUrl.saveFcmToken,
        data: FormData.fromMap(<String, dynamic>{
          'fcm_token': token,
          'platform': platform,
          'device_type': platform,
        }),
        options: NetworkApi.buildOptions(authToken: authToken),
      );
    } catch (_) {
      // Silent failure: token will be retried on next refresh/login.
    }
  }

  String get _platformName {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return 'android';
  }

  Future<void> showNotification(RemoteMessage message) async {
    await _showNotificationStatic(message);
  }

  Future<void> showVehicleCareReminder({
    required String type,
    required int vehicleId,
    required String title,
    required String body,
  }) async {
    final payload = jsonEncode(<String, dynamic>{
      'notification_kind': type == 'insurance'
          ? 'insurance_due'
          : 'maintenance_due',
      'vehicle_id': vehicleId,
      'title': title,
      'body': body,
    });

    if (Platform.isAndroid) {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Vehicle care reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: _androidSound,
        icon: '@mipmap/ic_launcher',
      );

      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: payload,
      );
      return;
    }

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: _defaultIosSoundFile,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(iOS: iosDetails),
      payload: payload,
    );
  }

  static Future<void> _showNotificationStatic(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString() ?? 'FleetMonitor360';
    final body =
        message.notification?.body ?? message.data['body']?.toString() ?? 'You have a new vehicle alert';
    final payload = jsonEncode(message.data);
    final soundConfig = _resolveSoundConfig(
      message.data,
      title: title,
      body: body,
    );

    if (Platform.isAndroid) {
      final androidDetails = AndroidNotificationDetails(
        soundConfig.channelId,
        soundConfig.channelName,
        channelDescription: 'Vehicle tracking notifications',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundConfig.soundName),
        icon: '@mipmap/ic_launcher',
      );

      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: payload,
      );
      return;
    }

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: soundConfig.iosSoundFile,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(iOS: iosDetails),
      payload: payload,
    );
  }

  void _handleNotificationTap(String? payload) {
    _openFromPayload(payload);
  }

  void _handleRemoteNavigation(RemoteMessage message) {
    _openFromPayload(jsonEncode(message.data));
  }

  void _openAlertsTab() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      _pendingNavigationPayload = jsonEncode(<String, dynamic>{
        'notification_kind': 'alerts',
      });
      return;
    }

    _pendingNavigationPayload = null;
    navigator.pushNamedAndRemoveUntil(
      DashboardScreen.routeName,
      (route) => false,
      arguments: 2,
    );
  }

  void flushPendingNavigation() {
    if (_pendingNavigationPayload != null) {
      final payload = _pendingNavigationPayload;
      _pendingNavigationPayload = null;
      _openFromPayload(payload);
    }
  }

  void _openFromPayload(String? payload) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      _pendingNavigationPayload = payload;
      return;
    }

    final data = _decodePayload(payload);
    final kind = (data['notification_kind'] ?? '').toString();
    final vehicleId =
        int.tryParse((data['vehicle_id'] ?? data['vehicleId'] ?? '0').toString()) ??
        0;

    if (kind == 'maintenance_due') {
      navigator.pushNamedAndRemoveUntil(
        DashboardScreen.routeName,
        (route) => false,
        arguments: 0,
      );
      Future<void>.delayed(Duration.zero, () {
        final currentNavigator = appNavigatorKey.currentState;
        currentNavigator?.push(
          MaterialPageRoute<void>(
            builder: (_) => AssignedVehicleMaintenanceScreen(
              initialVehicleId: vehicleId,
            ),
          ),
        );
      });
      return;
    }

    if (kind == 'insurance_due') {
      navigator.pushNamedAndRemoveUntil(
        DashboardScreen.routeName,
        (route) => false,
        arguments: 0,
      );
      Future<void>.delayed(Duration.zero, () {
        final currentNavigator = appNavigatorKey.currentState;
        currentNavigator?.push(
          MaterialPageRoute<void>(
            builder: (_) => DocumentVaultScreen(
              vehicleId: vehicleId,
              title: 'Insurance Documents',
            ),
          ),
        );
      });
      return;
    }

    if (kind == 'panic_alert' ||
        kind == 'sos' ||
        data['panic_alert']?.toString() == '1') {
      _openAlertsTab();
      return;
    }

    _openAlertsTab();
  }

  Map<String, dynamic> _decodePayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  static _ResolvedNotificationSound _resolveSoundConfig(
    Map<String, dynamic> data, {
    String title = '',
    String body = '',
  }) {
    final explicitSound = (data['sound_name'] ?? data['sound'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final normalizedExplicitSound = _normalizeSoundKey(explicitSound);
    if (normalizedExplicitSound.isNotEmpty) {
      return _resolvedFromKey(normalizedExplicitSound);
    }

    final alertType = (data['alert_type'] ?? '').toString().trim().toLowerCase();
    final notificationKind =
        (data['notification_kind'] ?? '').toString().trim().toLowerCase();

    final vehicleHint = [
      data['vehicle_type'],
      data['vehicle_type_name'],
      data['vehicle_name'],
      data['v_name'],
      data['title'],
      data['message'],
      title,
      body,
    ].map((value) => (value ?? '').toString().toLowerCase()).join(' ');

    final looksLikeIgnition = alertType == 'ignition_on' ||
        alertType == 'ignition_off' ||
        notificationKind.contains('ignition') ||
        vehicleHint.contains('ignition');

    final looksLikeActiva = vehicleHint.contains('activa') ||
        vehicleHint.contains('scooty') ||
        vehicleHint.contains('scooter');

    if (looksLikeActiva && looksLikeIgnition) {
      return _resolvedFromKey('activa_ignition_on');
    }

    if (alertType != 'ignition_on' && alertType != 'ignition_off') {
      return _defaultResolvedSound();
    }

    if (alertType == 'ignition_off') {
      if (vehicleHint.contains('car') ||
          vehicleHint.contains('sedan') ||
          vehicleHint.contains('suv')) {
        return _resolvedFromKey('car_ignition_off');
      }
      return _defaultResolvedSound();
    }

    if (vehicleHint.contains('bike') || vehicleHint.contains('motorcycle')) {
      return _resolvedFromKey('bike_ignition_on');
    }
    if (vehicleHint.contains('truck') || vehicleHint.contains('lorry')) {
      return _resolvedFromKey('truck_ignition_on');
    }
    if (vehicleHint.contains('bus')) {
      return _resolvedFromKey('bus_ignition_on');
    }
    if (vehicleHint.contains('car') ||
        vehicleHint.contains('sedan') ||
        vehicleHint.contains('suv')) {
      return _resolvedFromKey('car_ignition_on');
    }

    return _resolvedFromKey('generic_ignition_on');
  }

  static String _normalizeSoundKey(String value) {
    var key = value.trim().toLowerCase();
    if (key.isEmpty) {
      return key;
    }
    key = key.replaceAll('\\', '/');
    if (key.contains('/')) {
      key = key.split('/').last;
    }
    if (key.endsWith('.wav') || key.endsWith('.mp3') || key.endsWith('.ogg')) {
      key = key.split('.').first;
    }
    return key.replaceAll('-', '_').replaceAll(' ', '_');
  }

  static _ResolvedNotificationSound _resolvedFromKey(String soundKey) {
    final channel = _vehicleSoundChannels[soundKey];
    if (channel == null) {
      return _defaultResolvedSound();
    }

    return _ResolvedNotificationSound(
      channelId: channel.id,
      channelName: channel.name,
      soundName: channel.soundName,
      iosSoundFile: channel.iosSoundFile,
    );
  }

  static _ResolvedNotificationSound _defaultResolvedSound() {
    return const _ResolvedNotificationSound(
      channelId: _channelId,
      channelName: _channelName,
      soundName: _defaultAndroidSoundName,
      iosSoundFile: _defaultIosSoundFile,
    );
  }
}

class _NotificationChannelConfig {
  final String id;
  final String name;
  final String soundName;
  final String iosSoundFile;

  const _NotificationChannelConfig({
    required this.id,
    required this.name,
    required this.soundName,
    required this.iosSoundFile,
  });
}

class _ResolvedNotificationSound {
  final String channelId;
  final String channelName;
  final String soundName;
  final String iosSoundFile;

  const _ResolvedNotificationSound({
    required this.channelId,
    required this.channelName,
    required this.soundName,
    required this.iosSoundFile,
  });
}
