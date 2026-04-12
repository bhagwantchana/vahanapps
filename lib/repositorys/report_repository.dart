import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/report_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class ReportRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<String> _getToken() async {
    return await LocalStorage.readValue(PreferencesKey.token) ?? '';
  }

  Future<ReportResponseModel> fetchReports({
    required String reportKey,
    String period = 'daily',
    int vehicleId = 0,
    String dueStatus = 'all',
    String groupBy = 'vehicle',
    bool includeExport = false,
  }) async {
    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.reports,
        data: FormData.fromMap(<String, dynamic>{
          'report_key': reportKey,
          'period': period,
          'vehicle_id': vehicleId,
          'due_status': dueStatus,
          'group_by': groupBy,
          'include_export': includeExport ? 1 : 0,
        }),
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      return ReportResponseModel.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }
}
