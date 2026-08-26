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

  /// One line per vehicle for TODAY - km driven and trips - straight off
  /// the daily_running report bounded to today's date. Powers the
  /// "Today's Activity" dashboard; errors come back as an empty result so
  /// a dashboard page never shows an error wall.
  Future<TodayActivity> fetchTodayActivity() async {
    try {
      final today = DateTime.now();
      final d = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final response = await _networkApi.sendRequest.post(
        AppUrl.reports,
        data: FormData.fromMap(<String, dynamic>{
          'report_key': 'daily_running',
          'from_date': d,
          'to_date': d,
        }),
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );
      final data = response.data as Map<String, dynamic>;
      if ((data['flag'] ?? 0) != 1) return const TodayActivity.empty();
      final rows = ((data['data'] as Map?)?['rows'] as List?) ?? const [];
      final vehicles = <TodayVehicleRow>[];
      double km = 0;
      int trips = 0;
      for (final r in rows) {
        if (r is! Map) continue;
        final rowKm =
            double.tryParse((r['total_distance_km'] ?? '0').toString()) ?? 0;
        final rowTrips = int.tryParse((r['trip_count'] ?? '0').toString()) ?? 0;
        km += rowKm;
        trips += rowTrips;
        final label = (r['v_registration_no'] ?? r['vehicle_label'] ?? '')
            .toString()
            .trim();
        vehicles.add(TodayVehicleRow(
          label: label.isNotEmpty ? label : (r['v_name'] ?? '').toString(),
          km: rowKm,
          trips: rowTrips,
        ));
      }
      vehicles.sort((a, b) => b.km.compareTo(a.km));
      return TodayActivity(
        totalKm: km,
        totalTrips: trips,
        activeVehicles: vehicles.where((v) => v.km > 0 || v.trips > 0).length,
        vehicles: vehicles,
      );
    } catch (_) {
      return const TodayActivity.empty();
    }
  }

  /// Last-7-days safety picture from /safetySummary. Same soft-fail rule.
  Future<SafetySummary?> fetchSafetySummary() async {
    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.safetySummary,
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );
      final data = response.data as Map<String, dynamic>;
      if ((data['flag'] ?? 0) != 1) return null;
      return SafetySummary.fromJson(
          Map<String, dynamic>.from((data['data'] as Map?) ?? const {}));
    } catch (_) {
      return null;
    }
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

/// "Today's Activity" dashboard payload - built app-side from the
/// daily_running report bounded to today.
class TodayActivity {
  const TodayActivity({
    required this.totalKm,
    required this.totalTrips,
    required this.activeVehicles,
    required this.vehicles,
  });

  const TodayActivity.empty()
      : totalKm = 0,
        totalTrips = 0,
        activeVehicles = 0,
        vehicles = const <TodayVehicleRow>[];

  final double totalKm;
  final int totalTrips;
  final int activeVehicles;
  final List<TodayVehicleRow> vehicles;
}

class TodayVehicleRow {
  const TodayVehicleRow(
      {required this.label, required this.km, required this.trips});
  final String label;
  final double km;
  final int trips;
}

/// /safetySummary payload: last-7-days alert counts and a 0-100 score.
class SafetySummary {
  const SafetySummary({
    required this.score,
    required this.totalEvents,
    required this.fleetSize,
    required this.counts,
    required this.vehicles,
  });

  factory SafetySummary.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    final raw = json['counts'];
    if (raw is Map) {
      raw.forEach((k, v) {
        counts[k.toString()] = int.tryParse(v.toString()) ?? 0;
      });
    }
    final vehicles = <SafetyVehicleRow>[];
    if (json['vehicles'] is List) {
      for (final item in json['vehicles'] as List) {
        if (item is Map) {
          vehicles.add(SafetyVehicleRow(
            label: (item['label'] ?? '').toString(),
            events: int.tryParse((item['events'] ?? '0').toString()) ?? 0,
            overspeed:
                int.tryParse((item['overspeed'] ?? '0').toString()) ?? 0,
            harsh: int.tryParse((item['harsh'] ?? '0').toString()) ?? 0,
          ));
        }
      }
    }
    return SafetySummary(
      score: int.tryParse((json['score'] ?? '0').toString()) ?? 0,
      totalEvents: int.tryParse((json['total_events'] ?? '0').toString()) ?? 0,
      fleetSize: int.tryParse((json['fleet_size'] ?? '0').toString()) ?? 0,
      counts: counts,
      vehicles: vehicles,
    );
  }

  final int score;
  final int totalEvents;
  final int fleetSize;
  final Map<String, int> counts;
  final List<SafetyVehicleRow> vehicles;

  int count(String key) => counts[key] ?? 0;
}

class SafetyVehicleRow {
  const SafetyVehicleRow({
    required this.label,
    required this.events,
    required this.overspeed,
    required this.harsh,
  });
  final String label;
  final int events;
  final int overspeed;
  final int harsh;
}
