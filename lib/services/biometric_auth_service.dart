import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricAuthService {
  BiometricAuthService._();

  static final LocalAuthentication _localAuth = LocalAuthentication();

  static Future<bool> isEnabled() async {
    return (await LocalStorage.readValue(PreferencesKey.biometricEnabled)) == '1';
  }

  static Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await LocalStorage.setValue(PreferencesKey.biometricEnabled, '1');
    } else {
      await LocalStorage.clearValue(PreferencesKey.biometricEnabled);
    }
  }

  static Future<bool> isSupported() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate({
    String reason = 'Authenticate to access VahanConnect',
  }) async {
    try {
      final supported = await isSupported();
      if (!supported) {
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException catch (error) {
      if (error.code == auth_error.notAvailable ||
          error.code == auth_error.notEnrolled ||
          error.code == auth_error.passcodeNotSet) {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
