import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/position_certificate_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class PositionCertificateRepository {
  final NetworkApi _networkApi = NetworkApi();

  /// [when] is sent as IST wall-clock, matching how every timestamp in this
  /// platform is stored — converting to UTC here would silently shift every
  /// lookup by 5.5 hours.
  Future<PositionCertificate> fetch({
    required int vehicleId,
    required DateTime when,
  }) async {
    final token = await LocalStorage.readValue(PreferencesKey.token) ?? '';

    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${when.year}-${two(when.month)}-${two(when.day)} '
        '${two(when.hour)}:${two(when.minute)}:00';

    final response = await _networkApi.sendRequest.post(
      AppUrl.positionAt,
      data: FormData.fromMap(<String, dynamic>{
        'vehicle_id': vehicleId,
        'timestamp': stamp,
      }),
      options: NetworkApi.buildOptions(authToken: token),
    );

    final apiResponse = ApiResponse.fromResponse(response);
    if (apiResponse.flag == 0) {
      throw Exception(apiResponse.message);
    }

    return PositionCertificate.fromJson(response.data as Map<String, dynamic>);
  }
}
