import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/nearby_poi_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class PoiRepository {
  final NetworkApi _networkApi = NetworkApi();

  /// Nearby world POIs (petrol pumps, EV, tolls, cameras, signals) around a
  /// point — normally the VEHICLE's live position, not the phone's.
  /// POST body MUST be FormData (CodeIgniter reads $_POST only).
  Future<List<NearbyPoi>> fetchNearby({
    required double lat,
    required double lng,
    required List<String> types,
    double radiusKm = 10,
    int limit = 30,
  }) async {
    final token = await LocalStorage.readValue(PreferencesKey.token) ?? '';

    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.nearbyPois,
        data: FormData.fromMap(<String, dynamic>{
          'lat': lat.toString(),
          'lng': lng.toString(),
          'types': types.join(','),
          'radius_km': radiusKm.toString(),
          'limit': limit.toString(),
        }),
        options: NetworkApi.buildOptions(authToken: token),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      final data = (response.data as Map<String, dynamic>)['data'];
      if (data is! List) {
        return <NearbyPoi>[];
      }
      return data
          .whereType<Map<String, dynamic>>()
          .map(NearbyPoi.fromJson)
          .toList();
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }
}
