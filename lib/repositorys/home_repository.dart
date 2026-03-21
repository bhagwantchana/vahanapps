import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/dashboard_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class HomeRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<DashboardModel> vehicleListFetch() async {
    final String token = await LocalStorage.readValue(PreferencesKey.token);
    try {
      // FormData formData = FormData.fromMap({'email': email, 'password': pass});
      final headers = {'X-Auth-Token': token};
      Response response = await _networkApi.sendRequest.post(
        AppUrl.dashboard,
        options: Options(method: 'POST', headers: headers),
      );
      ApiResponse apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw apiResponse.message.toString();
      }
      return DashboardModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }
}
