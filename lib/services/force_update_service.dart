import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

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
}
