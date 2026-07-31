import 'dart:async';

import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/vechile_list_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';
import 'package:fleet_monitor/services/offline_cache.dart';

/// A fleet list served from the last-good cache rather than the network.
class CachedFleetException implements Exception {
  CachedFleetException(this.model, this.age);
  final VehicleListModel model;

  /// How old the cached response is, for the banner the screen shows.
  final Duration? age;
}

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

      final body = response.data as Map<String, dynamic>;
      // Cache the RAW body, so the fallback replays this same parser.
      unawaited(OfflineCache.saveVehicleList(body));
      return VehicleListModel.fromJson(body);
    } catch (error) {
      // A dropped link is routine here — these are watched from moving buses
      // on rural mobile data. Answering with an error page reads as "tracking
      // is broken" rather than "signal went for a moment", so serve the last
      // known fleet and let the screen say how old it is.
      final cached = await OfflineCache.readVehicleList();
      if (cached != null) {
        throw CachedFleetException(
          VehicleListModel.fromJson(cached),
          await OfflineCache.vehicleListAge(),
        );
      }
      throw Exception(NetworkApi.parseError(error));
    }
  }
}
