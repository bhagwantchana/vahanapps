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
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_cubit.dart';
import 'package:fleet_monitor/screens/assigned_vehicle_maintenance_screen.dart';
import 'package:fleet_monitor/screens/dashboard.dart';
import 'package:fleet_monitor/screens/document_vault_screen.dart';
import 'package:fleet_monitor/screens/student_map_screen.dart';
import 'package:fleet_monitor/widgets/single_vehicle_track.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Only create channels and basic setup in background, don't setup listeners
  await CustomNotificationSoundService().setupChannels();
  if (message.notification == null) {
    await CustomNotificationSoundService().showNotification(message);
  }
}

class CustomNotificationSoundService {
  static const String _channelId = 'fleet_monitor_alert_channel_v3';
  static const String _channelName = 'VahanConnect Alerts';
  static const String _defaultAndroidSoundName = 'default_sound';
  static const String _defaultIosSoundFile = 'default_sound.wav';
  static const RawResourceAndroidNotificationSound _androidSound =
      RawResourceAndroidNotificationSound(_defaultAndroidSoundName);
  // Channels bumped to _v4 on 2026-05-23: Android notification channels are
  // IMMUTABLE after creation. If a device once cached one of these channels
  // with a wrong/silent sound (which appears to be what was happening for
  // some Motorcycle vehicles), the only fix is a new channel ID — Android
  // will then call setupChannels() and register a fresh channel with the
  // current sound. The matching FCM payloads on the server (fcm.js
  // VEHICLE_SOUND_CHANNELS) were bumped to _v4 at the same time so the
  // channel IDs stay in lockstep.
  static const Map<String, _NotificationChannelConfig> _vehicleSoundChannels = {
    'generic_ignition_on': _NotificationChannelConfig(
      id: 'fleet_monitor_ignition_generic_v4',
      name: 'VahanConnect Ignition Generic',
      soundName: 'generic_ignition_on',
      iosSoundFile: 'generic_ignition_on.wav',
    ),
    'activa_ignition_on': _NotificationChannelConfig(
      id: 'fleet_monitor_ignition_activa_v4',
      name: 'VahanConnect Ignition Activa',
      soundName: 'activa_ignition_on',
      iosSoundFile: 'activa_ignition_on.wav',
    ),
    'bike_ignition_on': _NotificationChannelConfig(
      id: 'fleet_monitor_ignition_bike_v4',
      name: 'VahanConnect Ignition Bike',
      soundName: 'bike_ignition_on',
      iosSoundFile: 'bike_ignition_on.wav',
    ),
    'car_ignition_on': _NotificationChannelConfig(
      // Bumped v4 → v5 on 2026-06-01: the car_ignition_on.wav sound file was
      // replaced. Android channels are immutable, so the sound only changes
      // if the channel ID is new — otherwise the device keeps the old cached
      // sound forever. Server fcm.js android_channel_id bumped to match.
      id: 'fleet_monitor_ignition_car_v5',
      name: 'VahanConnect Ignition Car',
      soundName: 'car_ignition_on',
      iosSoundFile: 'car_ignition_on.wav',
    ),
    'car_ignition_off': _NotificationChannelConfig(
      id: 'fleet_monitor_ignition_car_off_v4',
      name: 'VahanConnect Ignition Car Off',
      soundName: 'car_ignition_off',
      iosSoundFile: 'car_ignition_off.wav',
    ),
    'bus_ignition_on': _NotificationChannelConfig(
      id: 'fleet_monitor_ignition_bus_v4',
      name: 'VahanConnect Ignition Bus',
      soundName: 'bus_ignition_on',
      iosSoundFile: 'bus_ignition_on.wav',
    ),
    'truck_ignition_on': _NotificationChannelConfig(
      id: 'fleet_monitor_ignition_truck_v4',
      name: 'VahanConnect Ignition Truck',
      soundName: 'truck_ignition_on',
      iosSoundFile: 'truck_ignition_on.wav',
    ),
    // Alert channels — IDs must match the server's VEHICLE_SOUND_CHANNELS
    // in tracking/includes/fcm.js. They currently use the default sound
    // because no per-alert WAV ships in res/raw/ yet; bump to _v4 here
    // and in the server when you record real ones. Having the channels
    // exist (even with default sound) lets Android users mute / un-mute
    // each alert type independently from system Settings.
    'overspeed': _NotificationChannelConfig(
      id: 'fleet_monitor_alert_overspeed_v3',
      name: 'VahanConnect Overspeed Alerts',
      soundName: _defaultAndroidSoundName,
      iosSoundFile: _defaultIosSoundFile,
    ),
    'geofence': _NotificationChannelConfig(
      id: 'fleet_monitor_alert_geofence_v3',
      name: 'VahanConnect Geofence Alerts',
      soundName: _defaultAndroidSoundName,
      iosSoundFile: _defaultIosSoundFile,
    ),
    'sos': _NotificationChannelConfig(
      id: 'fleet_monitor_alert_sos_v3',
      name: 'VahanConnect SOS Alerts',
      soundName: _defaultAndroidSoundName,
      iosSoundFile: _defaultIosSoundFile,
    ),
    'tampering': _NotificationChannelConfig(
      id: 'fleet_monitor_alert_tampering_v3',
      name: 'VahanConnect Tampering Alerts',
      soundName: _defaultAndroidSoundName,
      iosSoundFile: _defaultIosSoundFile,
    ),
    'low_battery': _NotificationChannelConfig(
      id: 'fleet_monitor_alert_low_battery_v3',
      name: 'VahanConnect Low Battery Alerts',
      soundName: _defaultAndroidSoundName,
      iosSoundFile: _defaultIosSoundFile,
    ),
    'power_cut': _NotificationChannelConfig(
      id: 'fleet_monitor_alert_power_cut_v3',
      name: 'VahanConnect Power Cut Alerts',
      soundName: _defaultAndroidSoundName,
      iosSoundFile: _defaultIosSoundFile,
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

  // Student-mode lock: a "student" sub-user lives only on the locked single-map
  // screen, so a notification tap must NOT drop them into the full dashboard /
  // alerts / vehicle-detail flow. Set at login + session restore, cleared on
  // logout. When true, every deep link routes to the student map instead.
  bool _isStudentMode = false;
  void setStudentMode(bool value) => _isStudentMode = value;

  // Launch gate: a terminated-state notification tap can navigate BEFORE the
  // splash screen's biometric prompt has run, landing anyone holding the
  // phone inside the app with the lock silently skipped. Deep links stash
  // until the gate opens (Dashboard mount = user passed splash biometric or
  // logged in), then flush through the normal pending-payload path. Plain
  // per-process bool: a fresh process always starts locked; foreground taps
  // while the app is running are unaffected (gate already open).
  bool _launchGateOpen = false;

  /// Called when the user is legitimately inside the app (DashboardScreen
  /// mount). Opens the deep-link gate and flushes any stashed payload.
  void markLaunchGateOpen() {
    _launchGateOpen = true;
    flushPendingNavigation();
  }

  /// Drop any stashed deep link (splash routed to Login — the tap must not
  /// survive into another user's fresh session).
  void clearPendingNavigation() {
    _pendingNavigationPayload = null;
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // Register the background handler as early as possible (this runs inside
    // the awaited initialize() in main(), i.e. BEFORE runApp). The handler is
    // a top-level @pragma('vm:entry-point') function; FCM can drop background
    // messages if this is registered late (it used to live in the
    // fire-and-forget _backgroundSetup, which could run after runApp).
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    // Disable foreground alerts from FCM to prevent duplicates with our local notifications
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
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

    // Terminated-state tap on a LOCALLY-shown notification (foreground
    // re-shows, care reminders): the plugin delivers that launch payload only
    // via getNotificationAppLaunchDetails — onDidReceiveNotificationResponse
    // never fires for a dead process. Without this the tap cold-started the
    // app to the plain home screen and the deep link was silently lost.
    // (FCM-rendered notifications are covered by getInitialMessage; the two
    // paths are mutually exclusive per launch.)
    try {
      final launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        final launchPayload = launchDetails!.notificationResponse?.payload;
        if (launchPayload != null && launchPayload.trim().isNotEmpty) {
          _pendingNavigationPayload = launchPayload;
        }
      }
    } catch (_) {
      // Best-effort — worst case the tap lands on the home screen as before.
    }

    // Run non-critical setup in the background to avoid blocking app start
    _backgroundSetup();

    _isInitialized = true;
  }

  Future<void> _backgroundSetup() async {
    try {
      await setupChannels();

      // (onBackgroundMessage is now registered earlier, in initialize().)
      FirebaseMessaging.onMessage.listen((message) {
        showNotification(message);
        // NOTE (2026-07-08): removed the push-triggered cubit refresh here.
        // It called HomeCubit.fetchHomeData() on every vehicle alert, which
        // rebuilt the HOME MAP — so a burst of alerts made the map visibly
        // reload again and again (owner reported this). The live maps already
        // stay current via SSE + the normal poll, so the push nudge was
        // redundant. Notifications still show; screens refresh on their own.
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
    } catch (_) {
      // Silent failure for background setup
    }
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

  Future<void> setupChannels() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Vehicle tracking notifications',
      importance: Importance.high,
      playSound: true,
      sound: _androidSound,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(channel);

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

      final notificationId = payload.hashCode;

      await _localNotifications.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: payload,
      );
      return;
    }

    final notificationId = payload.hashCode;

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: _defaultIosSoundFile,
    );

    await _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(iOS: iosDetails),
      payload: payload,
    );
  }

  static Future<void> _showNotificationStatic(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString() ?? 'VahanConnect';
    final body =
        message.notification?.body ?? message.data['body']?.toString() ?? 'You have a new vehicle alert';
    final payload = jsonEncode(message.data);
    final soundConfig = _resolveSoundConfig(
      message.data,
      title: title,
      body: body,
    );

    // Build a per-vehicle group key so multiple alerts for the same vehicle
    // collapse into a single Android notification stack instead of spamming
    // the shade. Falls back to a flat 'vahanconnect_alerts' group when the
    // payload has no vehicle association. iOS uses `threadIdentifier` for
    // the same effect.
    final vehicleId = (message.data['vehicle_id'] ?? '').toString().trim();
    final imei = (message.data['imei'] ?? '').toString().trim();
    final groupKey = vehicleId.isNotEmpty
        ? 'vahanconnect.vehicle.$vehicleId'
        : (imei.isNotEmpty
            ? 'vahanconnect.imei.$imei'
            : 'vahanconnect.alerts');

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
        groupKey: groupKey,
        // setAsGroupSummary=false on the child notifications; Android will
        // auto-collapse 4+ alerts with the same groupKey into a stack with
        // a system-generated summary.
        setAsGroupSummary: false,
      );

      final notificationId = message.messageId?.hashCode ??
          (DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await _localNotifications.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: payload,
      );
      return;
    }

    final notificationId = message.messageId?.hashCode ??
        (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: soundConfig.iosSoundFile,
      // iOS groups notifications that share a thread-identifier under the
      // same expandable stack on the lock screen and Notification Centre.
      threadIdentifier: groupKey,
    );

    await _localNotifications.show(
      id: notificationId,
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

    // Hold deep links until the splash biometric/auth gate has passed —
    // markLaunchGateOpen() re-flushes this payload once the user is in.
    if (!_launchGateOpen) {
      _pendingNavigationPayload = payload;
      return;
    }

    // Student sub-user is locked to the single-map screen: every notification
    // tap just brings them (back) to their map — never the dashboard/alerts.
    if (_isStudentMode) {
      navigator.pushNamedAndRemoveUntil(
        StudentMapScreen.routeName,
        (route) => false,
      );
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

    // Deep link: if the FCM payload identifies a specific vehicle (via IMEI
    // or vehicle_id), open the single-vehicle detail screen instead of
    // just the Alerts tab. Falls back to Alerts when the payload is missing
    // the identifiers — that's better than dropping the tap.
    final imei = (data['imei'] ?? '').toString().trim();
    final alertType = (data['alert_type'] ?? '').toString().trim().toLowerCase();
    final isVehicleAlert = _isVehicleAlertType(alertType);

    if (isVehicleAlert && imei.isNotEmpty) {
      _openVehicleDetail(imei: imei);
      return;
    }

    _openAlertsTab();
  }

  /// Alert types that mark a vehicle-state change. Used by the
  /// notification-tap deep link (_openFromPayload) to route to the vehicle.
  static bool _isVehicleAlertType(String alertType) {
    return alertType == 'overspeed' ||
        alertType == 'ignition_on' ||
        alertType == 'ignition_off' ||
        alertType.startsWith('geofence_') ||
        alertType.startsWith('harsh_') ||
        alertType == 'tampering' ||
        alertType == 'parking_guard' ||
        alertType == 'towing' ||
        alertType == 'speed_camera' ||
        alertType == 'idle' ||
        alertType == 'low_battery' ||
        alertType == 'power_cut';
  }


  /// Land the user directly on the vehicle's detail / live-track screen
  /// when they tap a per-vehicle notification.
  void _openVehicleDetail({required String imei}) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) {
      _openAlertsTab();
      return;
    }
    try {
      // Pre-fetch the vehicle's latest track so the detail screen has data
      // by the time it builds. Same path the alerts screen uses on tap.
      final trackCubit = BlocProvider.of<SingleTrackCubit>(ctx);
      trackCubit.fetchVehicleTrack(imei);
    } catch (_) {
      // Cubit not provided in this context — detail screen will fetch
      // itself when it lands.
    }
    // Dashboard-first, then push the detail on a settled stack (same pattern
    // as the maintenance_due/insurance_due handlers above). A bare push()
    // left the splash screen mounted underneath on a terminated-state tap,
    // and its delayed pushReplacement then REPLACED the just-pushed detail
    // screen with Dashboard ~2s later (deep link visibly yanked away).
    // pushNamedAndRemoveUntil disposes the splash, so its mounted-check
    // aborts that navigation — and back from the detail lands on Dashboard.
    navigator.pushNamedAndRemoveUntil(
      DashboardScreen.routeName,
      (route) => false,
      arguments: 0,
    );
    Future<void>.delayed(Duration.zero, () {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const VehicleDetailScreen()),
      );
    });
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
    final alertType = (data['alert_type'] ?? '').toString().trim().toLowerCase();
    final notificationKind =
        (data['notification_kind'] ?? '').toString().trim().toLowerCase();

    // Route non-ignition alert types to their own channels FIRST — before
    // we look at sound_name. The server sends sound_name='default_sound'
    // for these alert types (because no per-alert WAV exists yet), but we
    // still want each category to have its own *channel* so users can
    // mute / unmute them independently from Android system settings.
    const alertTypeChannelKeys = <String, String>{
      'overspeed': 'overspeed',
      'sos': 'sos',
      'tampering': 'tampering',
      'parking_guard': 'tampering',
      'geofence_enter': 'geofence',
      'geofence_exit': 'geofence',
      'low_battery': 'low_battery',
      'power_cut': 'power_cut',
      'harsh_brake': 'tampering',
      'harsh_accel': 'tampering',
      'harsh_corner': 'tampering',
      'offline': 'tampering',
      // Lockstep with tracking/includes/fcm.js resolveNotificationConfig:
      // towing = security-style (tampering), speed camera = speed-related.
      'towing': 'tampering',
      'speed_camera': 'overspeed',
    };
    final mappedAlertKey = alertTypeChannelKeys[alertType];
    if (mappedAlertKey != null) {
      return _resolvedFromKey(mappedAlertKey);
    }

    // Billing / account reminders (plan_expiry from the web cron), admin
    // broadcast messages (admin_message / announcement) and wallet/account
    // events (sent with notification_type='account') must NEVER pick up a
    // vehicle engine cue just because the body mentions a vehicle label —
    // "Swift Car", a broadcast body containing "bus", or a customer named
    // "Cargo" would otherwise match the car-keyword scan below. Route them
    // straight to the default channel.
    const accountAlertTypes = <String>{
      'wallet_credit', 'wallet_debit', 'wallet_recharge', 'recharge_request',
      'low_balance', 'new_device_added', 'account_created', 'customer_assigned',
    };
    final notificationType =
        (data['notification_type'] ?? '').toString().trim().toLowerCase();
    if (alertType == 'plan_expiry' ||
        alertType == 'admin_message' ||
        alertType == 'announcement' ||
        // Informational "vehicle reachable again" push — its body names the
        // vehicle, which would otherwise trip the engine-keyword scan below
        // and play an ignition cue for a connectivity event.
        alertType == 'device_back_online' ||
        notificationType == 'account' ||
        notificationKind == 'account' ||
        accountAlertTypes.contains(alertType)) {
      return _defaultResolvedSound();
    }

    // Ignition / vehicle-specific sounds: server sends an explicit
    // sound_name like 'car_ignition_on' or 'truck_ignition_on'. Honour
    // it when present and it maps to a known vehicle channel.
    final explicitSound = (data['sound_name'] ?? data['sound'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final normalizedExplicitSound = _normalizeSoundKey(explicitSound);
    if (normalizedExplicitSound.isNotEmpty &&
        _vehicleSoundChannels.containsKey(normalizedExplicitSound)) {
      return _resolvedFromKey(normalizedExplicitSound);
    }

    // Broaden the search by looking at all values in the data map, title, and body.
    final allValues = data.values.map((v) => v.toString().toLowerCase()).join(' ');
    final vehicleHint = '$allValues $title $body'.toLowerCase();

    // engine_start / engine_stop / engine_restore are the manual relay
    // commands; treat them as ignition for sound-resolution purposes so
    // they pick up the same per-vehicle engine cue instead of falling to
    // the default alert bell.
    final isEngineCommand = alertType.startsWith('engine_') ||
        notificationKind.startsWith('engine_');

    final looksLikeIgnition = alertType == 'ignition_on' ||
        alertType == 'ignition_off' ||
        notificationKind.contains('ignition') ||
        vehicleHint.contains('ignition') ||
        isEngineCommand;

    final looksLikeActiva = vehicleHint.contains('activa') ||
        vehicleHint.contains('scooty') ||
        vehicleHint.contains('scooter');

    if (looksLikeActiva && looksLikeIgnition) {
      return _resolvedFromKey('activa_ignition_on');
    }

    final looksLikeCar = vehicleHint.contains('car') ||
        vehicleHint.contains('sedan') ||
        vehicleHint.contains('suv');
    final looksLikeBike =
        vehicleHint.contains('bike') || vehicleHint.contains('motorcycle');
    final looksLikeTruck =
        vehicleHint.contains('truck') || vehicleHint.contains('lorry');
    final looksLikeBus = vehicleHint.contains('bus');

    final isOffEvent = alertType == 'ignition_off' ||
        alertType == 'engine_stop' ||
        vehicleHint.contains('engine_stop') ||
        vehicleHint.contains('immobilize');

    if (isOffEvent) {
      if (looksLikeCar) {
        return _resolvedFromKey('car_ignition_off');
      }
      if (looksLikeActiva) {
        return _resolvedFromKey('activa_ignition_on');
      }
      if (looksLikeBike) {
        return _resolvedFromKey('bike_ignition_on');
      }
      if (looksLikeTruck) {
        return _resolvedFromKey('truck_ignition_on');
      }
      if (looksLikeBus) {
        return _resolvedFromKey('bus_ignition_on');
      }
      return _resolvedFromKey('generic_ignition_on');
    }

    if (looksLikeBike) {
      return _resolvedFromKey('bike_ignition_on');
    }
    if (looksLikeTruck) {
      return _resolvedFromKey('truck_ignition_on');
    }
    if (looksLikeBus) {
      return _resolvedFromKey('bus_ignition_on');
    }
    if (looksLikeCar) {
      return _resolvedFromKey('car_ignition_on');
    }

    // Anything else ignition / engine related falls back to the generic
    // engine-on cue so the user still hears an audible engine sound rather
    // than the default alert bell. The default channel only kicks in for
    // truly unmatched alert types (handled by `_defaultResolvedSound`).
    if (looksLikeIgnition) {
      return _resolvedFromKey('generic_ignition_on');
    }

    return _defaultResolvedSound();
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
