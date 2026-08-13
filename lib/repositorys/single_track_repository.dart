import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/route_stop_model.dart';
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
          // "YYYY-MM-DD HH:mm:ss" (no T / microseconds) to match the server's
          // DATETIME column and avoid STRICT sql_mode rejection.
          'from_date': from.toIso8601String().split('.').first.replaceFirst('T', ' '),
          'to_date': to.toIso8601String().split('.').first.replaceFirst('T', ' '),
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

  // ── "Mera Stop" / ETA-to-stop ─────────────────────────────────────────────

  Future<List<RouteStop>> fetchRouteStops(String imei) async {
    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.routeStops,
        data: FormData.fromMap(<String, dynamic>{'imei': imei}),
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );
      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }
      final data = response.data as Map<String, dynamic>;
      final stops = <RouteStop>[];
      if (data['data'] is List) {
        for (final item in data['data'] as List) {
          if (item is Map<String, dynamic>) {
            stops.add(RouteStop.fromJson(item));
          }
        }
      }
      return stops;
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  Future<StopEta> fetchStopEta(String imei, int stopId) async {
    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.stopEta,
        data: FormData.fromMap(<String, dynamic>{
          'imei': imei,
          'stop_id': stopId,
        }),
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );
      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }
      final data = response.data as Map<String, dynamic>;
      return StopEta.fromJson(
        Map<String, dynamic>.from((data['data'] as Map?) ?? const {}),
      );
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  /// Subscribe/unsubscribe THIS PHONE to "bus is near" pushes for a stop.
  /// Keyed by the phone's FCM token because parents share one login — the
  /// token is the only per-parent identity that exists.
  Future<void> setStopAlert({
    required String imei,
    required int stopId,
    required bool enable,
  }) async {
    final fcmToken = await LocalStorage.readValue(PreferencesKey.fcmToken) ?? '';
    if (fcmToken.isEmpty) {
      throw Exception('Notification token not ready yet');
    }
    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.setStopAlert,
        data: FormData.fromMap(<String, dynamic>{
          'imei': imei,
          'stop_id': stopId,
          'fcm_token': fcmToken,
          'enable': enable ? 1 : 0,
          'platform': 'android',
        }),
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );
      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }
}
