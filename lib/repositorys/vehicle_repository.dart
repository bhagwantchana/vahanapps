import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/vechile_list_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class VehicleRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<VehicleListModel> fetchVehicles() async {
    final token = await LocalStorage.readValue(PreferencesKey.token) ?? '';

    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.vehicleList,
        options: NetworkApi.buildOptions(authToken: token),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      return VehicleListModel.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }
}
