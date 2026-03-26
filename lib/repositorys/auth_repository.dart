import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/functions.dart';
import 'package:fleet_monitor/models/auth_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class AuthRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<AuthModel> loginRepo({
    required String email,
    required String pass,
  }) async {
    try {
      FormData formData = FormData.fromMap({
        'email': email,
        'password': pass,
        'fcm_token': fcmTokenGet,
      });

      Response response = await _networkApi.sendRequest.post(
        AppUrl.login,
        data: formData,
      );

      ApiResponse apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw apiResponse.message.toString();
      }

      return AuthModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }
}
