import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/functions.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/auth_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<AuthModel> loginRepo({
    required String email,
    required String pass,
  }) async {
    try {
      final cachedFcmToken =
          fcmTokenGet?.trim().isNotEmpty == true
              ? fcmTokenGet!.trim()
              : (await LocalStorage.readValue(PreferencesKey.fcmToken) ?? '');

      final formData = FormData.fromMap(<String, dynamic>{
        'email': email,
        'password': pass,
        'fcm_token': cachedFcmToken,
        'platform': _platformName,
        'device_type': _platformName,
      });

      final response = await _networkApi.sendRequest.post(
        AppUrl.login,
        data: formData,
        options: NetworkApi.buildOptions(),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      final authModel = AuthModel.fromJson(response.data as Map<String, dynamic>);
      if (authModel.data?.xAuthToken.isNotEmpty == true &&
          cachedFcmToken.isNotEmpty) {
        try {
          await saveFcmToken(
            authToken: authModel.data!.xAuthToken,
            fcmToken: cachedFcmToken,
            platform: _platformName,
          );
        } catch (_) {
          // Login should succeed even if token sync has to retry later.
        }
      }
      return authModel;
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  Future<void> logoutRepo(String authToken) async {
    if (authToken.trim().isEmpty) {
      return;
    }

    try {
      await _networkApi.sendRequest.post(
        AppUrl.logout,
        options: NetworkApi.buildOptions(authToken: authToken),
      );
    } catch (_) {
      // Local logout should still succeed even if the API call fails.
    }
  }

  Future<void> saveFcmToken({
    required String authToken,
    required String fcmToken,
    String platform = 'android',
  }) async {
    if (authToken.trim().isEmpty || fcmToken.trim().isEmpty) {
      return;
    }

    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.saveFcmToken,
        data: FormData.fromMap(<String, dynamic>{
          'fcm_token': fcmToken.trim(),
          'platform': platform,
          'device_type': platform,
        }),
        options: NetworkApi.buildOptions(authToken: authToken),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  String get _platformName {
    if (kIsWeb) {
      return 'web';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    }
    return 'android';
  }
}
