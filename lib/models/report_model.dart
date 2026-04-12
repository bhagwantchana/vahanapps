import 'dart:convert';

import 'package:fleet_monitor/models/model_helpers.dart';

class ReportResponseModel {
  final int flag;
  final String message;
  final ReportData? data;

  const ReportResponseModel({
    this.flag = 0,
    this.message = '',
    this.data,
  });

  factory ReportResponseModel.fromJson(Map<String, dynamic> json) {
    return ReportResponseModel(
      flag: toInt(json['flag']),
      message: toStringValue(json['message']),
      data: json['data'] is Map<String, dynamic>
          ? ReportData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ReportData {
  final String reportKey;
  final String title;
  final ReportChart chart;
  final List<ReportSummaryCard> summaryCards;
  final List<Map<String, dynamic>> rows;
  final ReportExport? exportData;
  final ReportMeta meta;

  const ReportData({
    this.reportKey = 'trip',
    this.title = '',
    this.chart = const ReportChart(),
    this.summaryCards = const <ReportSummaryCard>[],
    this.rows = const <Map<String, dynamic>>[],
    this.exportData,
    this.meta = const ReportMeta(),
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    final summaries = <ReportSummaryCard>[];
    if (json['summary_cards'] is List) {
      for (final item in json['summary_cards'] as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          summaries.add(ReportSummaryCard.fromJson(item));
        }
      }
    }

    final tableRows = <Map<String, dynamic>>[];
    if (json['rows'] is List) {
      for (final item in json['rows'] as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          tableRows.add(item);
        } else if (item is Map) {
          tableRows.add(
            item.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      }
    }

    return ReportData(
      reportKey: toStringValue(json['report_key'], fallback: 'trip'),
      title: toStringValue(json['title']),
      chart: json['chart'] is Map<String, dynamic>
          ? ReportChart.fromJson(json['chart'] as Map<String, dynamic>)
          : const ReportChart(),
      summaryCards: summaries,
      rows: tableRows,
      exportData: json['export'] is Map<String, dynamic>
          ? ReportExport.fromJson(json['export'] as Map<String, dynamic>)
          : null,
      meta: json['meta'] is Map<String, dynamic>
          ? ReportMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : const ReportMeta(),
    );
  }
}

class ReportSummaryCard {
  final String label;
  final String value;

  const ReportSummaryCard({
    this.label = '',
    this.value = '',
  });

  factory ReportSummaryCard.fromJson(Map<String, dynamic> json) {
    return ReportSummaryCard(
      label: toStringValue(json['label']),
      value: toStringValue(json['value']),
    );
  }
}

class ReportChart {
  final String type;
  final List<String> categories;
  final List<ReportSeries> series;

  const ReportChart({
    this.type = 'bar',
    this.categories = const <String>[],
    this.series = const <ReportSeries>[],
  });

  factory ReportChart.fromJson(Map<String, dynamic> json) {
    final categoryItems = <String>[];
    if (json['categories'] is List) {
      for (final item in json['categories'] as List<dynamic>) {
        categoryItems.add(toStringValue(item));
      }
    }

    final seriesItems = <ReportSeries>[];
    if (json['series'] is List) {
      for (final item in json['series'] as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          seriesItems.add(ReportSeries.fromJson(item));
        }
      }
    }

    return ReportChart(
      type: toStringValue(json['type'], fallback: 'bar'),
      categories: categoryItems,
      series: seriesItems,
    );
  }
}

class ReportSeries {
  final String name;
  final List<double> data;

  const ReportSeries({
    this.name = '',
    this.data = const <double>[],
  });

  factory ReportSeries.fromJson(Map<String, dynamic> json) {
    final points = <double>[];
    if (json['data'] is List) {
      for (final item in json['data'] as List<dynamic>) {
        points.add(toDouble(item));
      }
    }

    return ReportSeries(
      name: toStringValue(json['name']),
      data: points,
    );
  }
}

class ReportExport {
  final String fileName;
  final String mimeType;
  final String contentBase64;

  const ReportExport({
    this.fileName = 'report.csv',
    this.mimeType = 'text/csv',
    this.contentBase64 = '',
  });

  factory ReportExport.fromJson(Map<String, dynamic> json) {
    return ReportExport(
      fileName: toStringValue(json['filename'], fallback: 'report.csv'),
      mimeType: toStringValue(json['mime_type'], fallback: 'text/csv'),
      contentBase64: toStringValue(json['content_base64']),
    );
  }

  List<int> decodeBytes() {
    if (contentBase64.isEmpty) {
      return const <int>[];
    }
    try {
      return base64Decode(contentBase64);
    } catch (_) {
      return const <int>[];
    }
  }
}

class ReportMeta {
  final List<ReportOption> reportOptions;
  final List<ReportOption> periodOptions;
  final List<ReportOption> groupOptions;
  final List<ReportOption> dueStatusOptions;
  final List<ReportVehicleOption> vehicleOptions;

  const ReportMeta({
    this.reportOptions = const <ReportOption>[],
    this.periodOptions = const <ReportOption>[],
    this.groupOptions = const <ReportOption>[],
    this.dueStatusOptions = const <ReportOption>[],
    this.vehicleOptions = const <ReportVehicleOption>[],
  });

  factory ReportMeta.fromJson(Map<String, dynamic> json) {
    return ReportMeta(
      reportOptions: _parseOptions(json['report_options']),
      periodOptions: _parseOptions(json['period_options']),
      groupOptions: _parseOptions(json['group_options']),
      dueStatusOptions: _parseOptions(json['due_status_options']),
      vehicleOptions: _parseVehicleOptions(json['vehicle_options']),
    );
  }

  static List<ReportOption> _parseOptions(dynamic raw) {
    final items = <ReportOption>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          items.add(ReportOption.fromJson(item));
        }
      }
    }
    return items;
  }

  static List<ReportVehicleOption> _parseVehicleOptions(dynamic raw) {
    final items = <ReportVehicleOption>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          items.add(ReportVehicleOption.fromJson(item));
        }
      }
    }
    return items;
  }
}

class ReportOption {
  final String key;
  final String label;

  const ReportOption({
    this.key = '',
    this.label = '',
  });

  factory ReportOption.fromJson(Map<String, dynamic> json) {
    return ReportOption(
      key: toStringValue(json['key']),
      label: toStringValue(json['label']),
    );
  }
}

class ReportVehicleOption {
  final int id;
  final String label;

  const ReportVehicleOption({
    this.id = 0,
    this.label = '',
  });

  factory ReportVehicleOption.fromJson(Map<String, dynamic> json) {
    return ReportVehicleOption(
      id: toInt(json['id']),
      label: toStringValue(json['label']),
    );
  }
}
