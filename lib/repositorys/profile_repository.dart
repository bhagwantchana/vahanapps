import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/user_profile_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class ProfileRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<UserProfileModel> vehicleListFetch() async {
    final String token = await LocalStorage.readValue(PreferencesKey.authData);
    try {
      final headers = {'X-Auth-Token': token};
      Response response = await _networkApi.sendRequest.post(
        AppUrl.myProfile,
        options: Options(method: 'POST', headers: headers),
      );
      ApiResponse apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw apiResponse.message.toString();
      }
      return UserProfileModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserProfileModel> updateProfileData() async {
    final String token = await LocalStorage.readValue(PreferencesKey.authData);
    try {
      final headers = {'X-Auth-Token': token};
      Response response = await _networkApi.sendRequest.post(
        AppUrl.myProfile,
        options: Options(method: 'POST', headers: headers),
      );
      ApiResponse apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw apiResponse.message.toString();
      }
      return UserProfileModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }
}
