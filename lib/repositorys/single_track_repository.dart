import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/single_track_model.dart';
import 'package:fleet_monitor/models/vehicle_track_point.dart';
import 'package:fleet_monitor/models/vehicle_settings_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class SingleTrackRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<String> _getToken() async {
    return await LocalStorage.readValue(PreferencesKey.token) ?? '';
  }

  Future<SingleTrackModel> fetchVehicleTrack(String imei) async {
    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.vehicleTrack,
        data: FormData.fromMap(<String, dynamic>{'imei': imei}),
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      return SingleTrackModel.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  Future<List<VehicleTrackPoint>> fetchTripHistoryTrail({
    required String imei,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.tripHistory,
        data: FormData.fromMap(<String, dynamic>{
          'imei': imei,
          'from_date': from.toIso8601String(),
          'to_date': to.toIso8601String(),
        }),
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      final data = response.data as Map<String, dynamic>;
      final points = <VehicleTrackPoint>[];
      final rawData = data['data'];
      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map<String, dynamic>) {
            final point = VehicleTrackPoint.fromJson(item);
            if (point.hasPoint) {
              points.add(point);
            }
          }
        }
      }
      return points;
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  Future<VehicleSettingsModel> updateVehicleSettings(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.updateVehicleSettings,
        data: FormData.fromMap(payload),
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      final data = response.data as Map<String, dynamic>;
      return VehicleSettingsModel.fromJson(
        Map<String, dynamic>.from(
          data['data'] as Map? ?? const <String, dynamic>{},
        ),
      );
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  Future<VehicleSettingsModel> sendEngineCommand({
    required int vehicleId,
    required String imei,
    required String action,
  }) async {
    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.engineCommand,
        data: FormData.fromMap(<String, dynamic>{
          'vehicle_id': vehicleId.toString(),
          'imei': imei,
          'action': action,
        }),
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      final data = response.data as Map<String, dynamic>;
      final payload = Map<String, dynamic>.from(
        ((data['data'] as Map?)?['settings'] as Map?) ?? const <String, dynamic>{},
      );
      return VehicleSettingsModel.fromJson(payload);
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }
}
