import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/alert_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class AlertsRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<String> _getToken() async {
    return await LocalStorage.readValue(PreferencesKey.token) ?? '';
  }

  Future<AlertListModel> fetchAlerts({
    int? vehicleId,
    int? isRead,
    String? alertType,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        if (vehicleId != null && vehicleId > 0) 'vehicle_id': vehicleId,
        if (isRead != null) 'is_read': isRead,
        if (alertType != null && alertType.trim().isNotEmpty)
          'alert_type': alertType,
      };

      final response = await _networkApi.sendRequest.get(
        AppUrl.alerts,
        queryParameters: queryParameters,
        options: NetworkApi.buildOptions(
          method: 'GET',
          authToken: await _getToken(),
        ),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      return AlertListModel.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  Future<void> markAsRead(int alertId) async {
    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.markAlertRead,
        data: FormData.fromMap(<String, dynamic>{'alert_id': alertId}),
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

  Future<String> sendPanicAlert({
    required int vehicleId,
    String note = '',
    double? latitude,
    double? longitude,
  }) async {
    try {
      final payload = <String, dynamic>{
        'vehicle_id': vehicleId,
        if (note.trim().isNotEmpty) 'message': note.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

      final response = await _networkApi.sendRequest.post(
        AppUrl.panicAlert,
        data: FormData.fromMap(payload),
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      return apiResponse.message.isNotEmpty
          ? apiResponse.message
          : 'Panic alert sent successfully';
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }
}
