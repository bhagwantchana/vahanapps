import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/driver_record_model.dart';
import 'package:fleet_monitor/models/driver_session_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class DriverRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<String> _getToken() async {
    return await LocalStorage.readValue(PreferencesKey.token) ?? '';
  }

  Future<List<DriverRecordModel>> fetchDrivers() async {
    try {
      final response = await _networkApi.sendRequest.get(
        AppUrl.drivers,
        options: NetworkApi.buildOptions(method: 'GET', authToken: await _getToken()),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      final rawList = response.data is Map<String, dynamic>
          ? (response.data['data'] as List? ?? const <dynamic>[])
          : const <dynamic>[];

      return rawList
          .whereType<Map<String, dynamic>>()
          .map(DriverRecordModel.fromJson)
          .toList();
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  Future<List<DriverSessionModel>> fetchDriverSessions({int? vehicleId}) async {
    try {
      final response = await _networkApi.sendRequest.get(
        AppUrl.driverSessions,
        queryParameters: <String, dynamic>{
          if (vehicleId != null && vehicleId > 0) 'vehicle_id': vehicleId,
        },
        options: NetworkApi.buildOptions(method: 'GET', authToken: await _getToken()),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      final rawList = response.data is Map<String, dynamic>
          ? (response.data['data'] as List? ?? const <dynamic>[])
          : const <dynamic>[];

      return rawList
          .whereType<Map<String, dynamic>>()
          .map(DriverSessionModel.fromJson)
          .toList();
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  Future<String> startDriverSession({
    required int vehicleId,
    int? driverId,
    String driverIdentifier = '',
    String driverPin = '',
    String identificationMethod = 'manual',
    String sessionCode = '',
    String notes = '',
  }) async {
    try {
      final payload = <String, dynamic>{
        'vehicle_id': vehicleId.toString(),
        'identification_method': identificationMethod,
        if (driverId != null && driverId > 0) 'driver_id': driverId.toString(),
        if (driverIdentifier.trim().isNotEmpty)
          'driver_identifier': driverIdentifier.trim(),
        if (driverPin.trim().isNotEmpty) 'driver_pin': driverPin.trim(),
        if (sessionCode.trim().isNotEmpty) 'session_code': sessionCode.trim(),
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      };

      final response = await _networkApi.sendRequest.post(
        AppUrl.startDriverSession,
        data: FormData.fromMap(payload),
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      return apiResponse.message;
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  Future<String> endDriverSession({
    int? sessionId,
    int? vehicleId,
    String imei = '',
  }) async {
    try {
      final payload = <String, dynamic>{
        if (sessionId != null && sessionId > 0) 'session_id': sessionId.toString(),
        if (vehicleId != null && vehicleId > 0) 'vehicle_id': vehicleId.toString(),
        if (imei.trim().isNotEmpty) 'imei': imei.trim(),
      };

      final response = await _networkApi.sendRequest.post(
        AppUrl.endDriverSession,
        data: FormData.fromMap(payload),
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      return apiResponse.message;
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  Future<String> assignDriver({
    required int driverId,
    required int vehicleId,
  }) async {
    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.assignDriver,
        data: FormData.fromMap(<String, dynamic>{
          'driver_id': driverId.toString(),
          'vehicle_id': vehicleId.toString(),
        }),
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      return apiResponse.message;
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }
}
