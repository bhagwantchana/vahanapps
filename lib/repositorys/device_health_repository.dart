import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/device_health_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class DeviceHealthRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<DeviceHealthReport> fetchHealth() async {
    final token = await LocalStorage.readValue(PreferencesKey.token) ?? '';

    final response = await _networkApi.sendRequest.post(
      AppUrl.deviceHealth,
      options: NetworkApi.buildOptions(authToken: token),
    );

    final apiResponse = ApiResponse.fromResponse(response);
    if (apiResponse.flag == 0) {
      throw Exception(apiResponse.message);
    }

    return DeviceHealthReport.fromJson(response.data as Map<String, dynamic>);
  }
}
