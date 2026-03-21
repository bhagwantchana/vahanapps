import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/single_track_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class SingleTrackRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<SingleTrackModel> vehicleListFetch(String imei) async {
    final String token = await LocalStorage.readValue(PreferencesKey.token);
    try {
      FormData formData = FormData.fromMap({'imei': imei});
      final headers = {'X-Auth-Token': token};
      Response response = await _networkApi.sendRequest.post(
        AppUrl.singleTrack,
        options: Options(method: 'POST', headers: headers),
        data: formData,
      );
      ApiResponse apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw apiResponse.message.toString();
      }
      return SingleTrackModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }
}
