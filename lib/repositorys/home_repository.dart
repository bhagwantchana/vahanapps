import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/dashboard_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class HomeRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<DashboardModel> fetchDashboard() async {
    final token = await LocalStorage.readValue(PreferencesKey.token) ?? '';

    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.dashboard,
        options: NetworkApi.buildOptions(authToken: token),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      return DashboardModel.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }
}
