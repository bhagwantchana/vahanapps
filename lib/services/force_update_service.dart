import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// What the server says about the build that is currently running.
class AppUpdateRequirement {
  const AppUpdateRequirement({
    required this.storeUrl,
    required this.message,
    required this.currentVersion,
    required this.minVersion,
  });

  final String storeUrl;
  final String message;
  final String currentVersion;
  final String minVersion;
}

/// Checks the Play Store for a pending update and triggers an **immediate**
/// (full-screen, blocking) update flow when one is available.
///
/// Call [checkAndForceUpdate] once during the splash / bootstrap sequence.
/// On iOS or debug builds the check is silently skipped — Play Core APIs
/// are Android-only and in-app-update always returns "not available" on
/// emulators or side-loaded builds.
class ForceUpdateService {
  /// Returns `true` if an immediate update was started (the app will
  /// restart automatically after the update installs). Returns `false`
  /// if no update is available or the check was skipped.
  static Future<bool> checkAndForceUpdate() async {
    // Only runs on Android release builds. The Play Core library
    // throws on iOS / debug / side-loaded APKs.
    if (defaultTargetPlatform != TargetPlatform.android || kDebugMode) {
      return false;
    }

    try {
      final info = await InAppUpdate.checkForUpdate();

      // updateAvailability values:
      //   1 = UPDATE_NOT_AVAILABLE
      //   2 = UPDATE_AVAILABLE
      //   3 = DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // immediateAllowed = true  → we can show a full-screen blocking UI
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          return true;
        }

        // If immediate isn't allowed, try flexible (background download)
        if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
          return true;
        }
      }
    } catch (_) {
      // Play Core unavailable (emulator, side-load, iOS, etc.)
      // Silently continue — the app works fine without the update check.
    }

    return false;
  }

  /// The app's own version name, e.g. "1.1.0".
  static Future<String> currentVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version.trim();
    } catch (_) {
      return '';
    }
  }

  /// Server-driven gate. Android gets Play's immediate update above, but that
  /// API does not exist on iOS — this is what forces iOS users (and anyone on
  /// a side-loaded APK) onto a newer build.
  ///
  /// Returns null when the running build is fine, the server is unreachable,
  /// or no minimum is configured. Never blocks on a network failure: a
  /// customer with flaky signal must still be able to open the app.
  static Future<AppUpdateRequirement?> checkServerRequirement() async {
    try {
      final version = await currentVersion();
      final platform =
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

      final response = await Dio().get<dynamic>(
        AppUrl.appVersion,
        queryParameters: <String, dynamic>{
          'platform': platform,
          'app_version': version,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );

      final body = response.data;
      if (body is! Map) return null;
      final data = body['data'];
      if (data is! Map) return null;
      final required = data['update_required'];
      final isRequired = required == 1 || required == '1' || required == true;
      if (!isRequired) return null;

      return AppUpdateRequirement(
        storeUrl: (data['store_url'] ?? '').toString(),
        message: (data['message'] ?? '').toString(),
        currentVersion: version,
        minVersion: (data['min_version'] ?? '').toString(),
      );
    } catch (_) {
      // Offline / server down / endpoint missing → let the app through.
      return null;
    }
  }
}
