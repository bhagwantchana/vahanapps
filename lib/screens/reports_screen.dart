import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/models/report_model.dart';
import 'package:fleet_monitor/models/model_helpers.dart';
import 'package:fleet_monitor/repositorys/report_repository.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.initialReportKey});

  final String? initialReportKey;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportRepository _reportRepository = ReportRepository();
  ReportData? _reportData;
  String _reportKey = 'daily_running';
  String _period = 'daily';
  String _groupBy = 'vehicle';
  String _dueStatus = 'all';
  int _vehicleId = 0;
  bool _isLoading = false;
  bool _isExporting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialReportKey != null && widget.initialReportKey!.isNotEmpty) {
      _reportKey = widget.initialReportKey!;
    }
    _fetchReport();
  }

  Future<void> _fetchReport({bool includeExport = false}) async {
    setState(() {
      _isLoading = !includeExport;
      _error = '';
      if (includeExport) {
        _isExporting = true;
      }
    });

    try {
      final result = await _reportRepository.fetchReports(
        reportKey: _reportKey,
        period: _period,
        vehicleId: _vehicleId,
        dueStatus: _dueStatus,
        groupBy: _groupBy,
        includeExport: includeExport,
      );

      if (!mounted) {
        return;
      }

      if (includeExport) {
        await _exportCsv(result.data?.exportData);
      }

      setState(() {
        _reportData = result.data;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _exportCsv(ReportExport? export) async {
    if (export == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export is not available for this report')),
      );
      return;
    }

    final bytes = export.decodeBytes();
    if (bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to prepare export file')),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${export.fileName}');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      <XFile>[XFile(file.path)],
      text: 'Fleet report export',
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _reportData;
    final meta = report?.meta ?? const ReportMeta();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Reports'),
        actions: <Widget>[
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            onPressed: _isExporting ? null : () => _fetchReport(includeExport: true),
          ),
        ],
      ),
      body: _isLoading && report == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                _buildFilters(meta),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error,
                      style: const TextStyle(color: AppColors.red),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchReport,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: <Widget>[
                        _buildSummaryCards(report?.summaryCards ?? const <ReportSummaryCard>[]),
                        const SizedBox(height: 16),
                        _buildChartCard(report?.chart ?? const ReportChart()),
                        const SizedBox(height: 16),
                        _buildRows(report?.rows ?? const <Map<String, dynamic>>[]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilters(ReportMeta meta) {
    final reportOptions = meta.reportOptions.isNotEmpty
        ? meta.reportOptions
        : const <ReportOption>[
            ReportOption(key: 'trip', label: 'Trip Report'),
            ReportOption(key: 'daily_running', label: 'Daily Running'),
            ReportOption(key: 'ignition', label: 'Ignition'),
            ReportOption(key: 'overspeed', label: 'Over Speed'),
            ReportOption(key: 'idle', label: 'Idle Time'),
            ReportOption(key: 'distance', label: 'Distance'),
            ReportOption(key: 'maintenance_due', label: 'Maintenance Due'),
          ];
    final periodOptions = meta.periodOptions.isNotEmpty
        ? meta.periodOptions
        : const <ReportOption>[
            ReportOption(key: 'daily', label: 'Daily'),
            ReportOption(key: 'weekly', label: 'Weekly'),
            ReportOption(key: 'monthly', label: 'Monthly'),
          ];
    final dueStatusOptions = meta.dueStatusOptions.isNotEmpty
        ? meta.dueStatusOptions
        : const <ReportOption>[ReportOption(key: 'all', label: 'All')];
    final groupOptions = meta.groupOptions.isNotEmpty
        ? meta.groupOptions
        : const <ReportOption>[ReportOption(key: 'vehicle', label: 'Vehicle')];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Wrap(
        runSpacing: 10,
        spacing: 10,
        children: <Widget>[
          _dropdownBox(
            label: 'Report',
            value: _reportKey,
            options: reportOptions
                .map((option) => DropdownMenuItem<String>(
                      value: option.key,
                      child: Text(option.label),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _reportKey = value);
              _fetchReport();
            },
          ),
          _dropdownBox(
            label: 'Period',
            value: _period,
            options: periodOptions
                .map((option) => DropdownMenuItem<String>(
                      value: option.key,
                      child: Text(option.label),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _period = value);
              _fetchReport();
            },
          ),
          _dropdownBox(
            label: 'Vehicle',
            value: _vehicleId.toString(),
            options: <DropdownMenuItem<String>>[
              const DropdownMenuItem<String>(value: '0', child: Text('All')),
              ...meta.vehicleOptions.map(
                (vehicle) => DropdownMenuItem<String>(
                  value: vehicle.id.toString(),
                  child: Text(vehicle.label),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => _vehicleId = int.tryParse(value ?? '0') ?? 0);
              _fetchReport();
            },
          ),
          _dropdownBox(
            label: 'Group',
            value: _groupBy,
            options: groupOptions
                .map((option) => DropdownMenuItem<String>(
                      value: option.key,
                      child: Text(option.label),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _groupBy = value);
              _fetchReport();
            },
          ),
          _dropdownBox(
            label: 'Due',
            value: _dueStatus,
            options: dueStatusOptions
                .map((option) => DropdownMenuItem<String>(
                      value: option.key,
                      child: Text(option.label),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _dueStatus = value);
              _fetchReport();
            },
          ),
        ],
      ),
    );
  }

  Widget _dropdownBox({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> options,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        value: options.any((item) => item.value == value) ? value : options.first.value,
        isExpanded: true,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        items: options,
      ),
    );
  }

  Widget _buildSummaryCards(List<ReportSummaryCard> cards) {
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                card.label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                card.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.primaryBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartCard(ReportChart chart) {
    final hasData = chart.series.any((series) => series.data.isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Visual Graph',
            style: TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: hasData ? _chartWidget(chart) : const Center(child: Text('No chart data')),
          ),
        ],
      ),
    );
  }

  Widget _chartWidget(ReportChart chart) {
    if (chart.type == 'line') {
      return _lineChart(chart);
    }
    if (chart.type == 'donut') {
      return _pieChart(chart);
    }
    return _barChart(chart);
  }

  Widget _lineChart(ReportChart chart) {
    final primary = chart.series.isNotEmpty ? chart.series.first : const ReportSeries();
    if (primary.data.isEmpty) {
      return const Center(child: Text('No line chart data'));
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < primary.data.length; i++) {
      spots.add(FlSpot(i.toDouble(), primary.data[i]));
    }

    final maxY = primary.data.reduce((a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY <= 0 ? 10 : maxY * 1.2,
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primaryBlue,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primaryBlue.withValues(alpha: 0.12),
            ),
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }

  Widget _barChart(ReportChart chart) {
    final primary = chart.series.isNotEmpty ? chart.series.first : const ReportSeries();
    if (primary.data.isEmpty) {
      return const Center(child: Text('No bar chart data'));
    }

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < primary.data.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: <BarChartRodData>[
            BarChartRodData(
              toY: primary.data[i],
              color: AppTheme.primaryGreen,
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: groups,
      ),
    );
  }

  Widget _pieChart(ReportChart chart) {
    final primary = chart.series.isNotEmpty ? chart.series.first : const ReportSeries();
    if (primary.data.isEmpty) {
      return const Center(child: Text('No donut data'));
    }

    final colors = <Color>[
      AppTheme.primaryBlue,
      AppTheme.primaryGreen,
      Colors.orange,
      Colors.deepPurple,
      AppColors.red,
    ];

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < primary.data.length; i++) {
      final category = i < chart.categories.length ? chart.categories[i] : 'Item ${i + 1}';
      sections.add(
        PieChartSectionData(
          value: primary.data[i],
          color: colors[i % colors.length],
          title: '${category.split(' ').first}\n${primary.data[i].toStringAsFixed(0)}',
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    return PieChart(PieChartData(sections: sections, centerSpaceRadius: 30));
  }

  Widget _buildRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No report rows'),
      );
    }

    final columns = rows.first.keys.toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Report Data',
            style: TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: columns
                  .map(
                    (column) => DataColumn(
                      label: Text(
                        humanizeSnakeCase(column),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                  .toList(),
              rows: rows
                  .take(20)
                  .map(
                    (row) => DataRow(
                      cells: columns
                          .map(
                            (column) => DataCell(
                              Text((row[column] ?? '').toString()),
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
