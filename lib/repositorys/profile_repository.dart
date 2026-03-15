import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/user_profile_model.dart';
import 'package:fleet_monitor/models/user_update_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class ProfileRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<UserProfileModel> vehicleListFetch() async {
    final String token = await LocalStorage.readValue(PreferencesKey.token);
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

  Future<UserUpdateModel> updateProfileData(
    String name,
    String lastName,
    String email,
    String? file,
  ) async {
    final String token = await LocalStorage.readValue(PreferencesKey.token);
    try {
      final headers = {
        'X-Auth-Token': token,
        'Content-Type': 'multipart/form-data',
      };
      FormData formData = FormData.fromMap({
        'first_name': name,
        'last_name': lastName,
        'email': email,
        if (file != null && file.isNotEmpty)
          'image': await MultipartFile.fromFile(
            file,
            filename: file.split('/').last,
          ),
      });
      Response response = await _networkApi.sendRequest.post(
        AppUrl.updateProfile,
        options: Options(headers: headers),
        data: formData,
      );
      ApiResponse apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw apiResponse.message.toString();
      }
      return UserUpdateModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }
}
