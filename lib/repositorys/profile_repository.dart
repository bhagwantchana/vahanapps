import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/user_profile_model.dart';
import 'package:fleet_monitor/models/user_update_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class ProfileRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<String> _getToken() async {
    return await LocalStorage.readValue(PreferencesKey.token) ?? '';
  }

  Future<UserProfileModel> fetchProfile() async {
    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.myProfile,
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  Future<UserUpdateModel> updateProfileData({
    required UserProfileData currentProfile,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? address,
    String? file,
  }) async {
    try {
      final formData = FormData.fromMap(<String, dynamic>{
        'first_name': firstName ?? currentProfile.firstName,
        'last_name': lastName ?? currentProfile.lastName,
        'email': email ?? currentProfile.email,
        'phone': phone ?? currentProfile.phone,
        'address': address ?? currentProfile.address,
        'country_id': currentProfile.countryId.toString(),
        'state_id': currentProfile.stateId.toString(),
        'city_id': currentProfile.cityId.toString(),
        if (file != null && file.isNotEmpty)
          'image': await MultipartFile.fromFile(
            file,
            filename: file.split('/').last,
          ),
      });

      final response = await _networkApi.sendRequest.post(
        AppUrl.updateProfile,
        data: formData,
        options: NetworkApi.buildOptions(
          authToken: await _getToken(),
          headers: <String, dynamic>{'Content-Type': 'multipart/form-data'},
        ),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      return UserUpdateModel.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  Future<String> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final formData = FormData.fromMap(<String, dynamic>{
        'old_password': oldPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      });

      final response = await _networkApi.sendRequest.post(
        AppUrl.changePassword,
        data: formData,
        options: NetworkApi.buildOptions(
          authToken: await _getToken(),
          headers: <String, dynamic>{
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      return apiResponse.message.isNotEmpty
          ? apiResponse.message
          : 'Password changed successfully';
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }
}
