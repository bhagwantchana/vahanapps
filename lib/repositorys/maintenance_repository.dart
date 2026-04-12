import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/maintenance_log.dart';
import 'package:fleet_monitor/models/model_helpers.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class MaintenanceRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<String> _getToken() async {
    return await LocalStorage.readValue(PreferencesKey.token) ?? '';
  }

  Future<List<MaintenanceLog>> fetchMaintenanceLogs(int vehicleId) async {
    try {
      final response = await _networkApi.sendRequest.get(
        AppUrl.maintenance,
        queryParameters: <String, dynamic>{'vehicle_id': vehicleId},
        options: NetworkApi.buildOptions(
          method: 'GET',
          authToken: await _getToken(),
        ),
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
          .map(MaintenanceLog.fromJson)
          .toList();
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  Future<void> addMaintenanceLog({
    required int vehicleId,
    required String serviceType,
    required String serviceDate,
    required double odometer,
    required double cost,
    String status = 'completed',
    String description = '',
    String nextServiceDate = '',
    int? nextServiceOdometer,
  }) async {
    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.maintenance,
        data: FormData.fromMap(<String, dynamic>{
          'vehicle_id': vehicleId,
          'service_type_key': serviceType.trim(),
          'service_date': serviceDate.trim(),
          'odometer': odometer,
          'cost': cost,
          'status': status,
          'description': description.trim(),
          if (nextServiceDate.trim().isNotEmpty)
            'next_service_date': nextServiceDate.trim(),
          if (nextServiceOdometer != null && nextServiceOdometer > 0)
            'next_service_odometer': nextServiceOdometer,
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

  Future<VehicleCareMeta> fetchVehicleCareMeta() async {
    try {
      final response = await _networkApi.sendRequest.get(
        AppUrl.vehicleCareMeta,
        options: NetworkApi.buildOptions(
          method: 'GET',
          authToken: await _getToken(),
        ),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      final data = response.data is Map<String, dynamic>
          ? response.data['data']
          : null;
      if (data is Map<String, dynamic>) {
        return VehicleCareMeta.fromJson(data);
      }
      return const VehicleCareMeta();
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }
}

class VehicleCareMeta {
  final List<VehicleCareOption> documentCategories;
  final List<VehicleCareOption> serviceTypes;
  final List<VehicleCareOption> maintenanceStatuses;
  final Map<String, dynamic> uploadSettings;

  const VehicleCareMeta({
    this.documentCategories = const <VehicleCareOption>[],
    this.serviceTypes = const <VehicleCareOption>[],
    this.maintenanceStatuses = const <VehicleCareOption>[],
    this.uploadSettings = const <String, dynamic>{},
  });

  factory VehicleCareMeta.fromJson(Map<String, dynamic> json) {
    return VehicleCareMeta(
      documentCategories: _parseOptions(json['document_categories']),
      serviceTypes: _parseOptions(json['service_types']),
      maintenanceStatuses: _parseOptions(json['maintenance_statuses']),
      uploadSettings: json['upload'] is Map<String, dynamic>
          ? json['upload'] as Map<String, dynamic>
          : const <String, dynamic>{},
    );
  }

  static List<VehicleCareOption> _parseOptions(dynamic raw) {
    final items = <VehicleCareOption>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          items.add(VehicleCareOption.fromJson(item));
        }
      }
    }
    return items;
  }
}

class VehicleCareOption {
  final String key;
  final String label;

  const VehicleCareOption({
    this.key = '',
    this.label = '',
  });

  factory VehicleCareOption.fromJson(Map<String, dynamic> json) {
    return VehicleCareOption(
      key: toStringValue(json['key']),
      label: toStringValue(json['label']),
    );
  }
}
