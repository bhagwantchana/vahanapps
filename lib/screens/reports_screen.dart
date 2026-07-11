import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/models/report_model.dart';
import 'package:fleet_monitor/models/model_helpers.dart';
import 'package:fleet_monitor/repositorys/report_repository.dart';
import 'package:fleet_monitor/widgets/app_logo.dart';
import 'package:fleet_monitor/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.initialReportKey, this.onSelectTab});

  final String? initialReportKey;

  /// Lets the shared drawer switch dashboard tabs from this screen.
  final ValueChanged<int>? onSelectTab;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportRepository _reportRepository = ReportRepository();
  ReportData? _reportData;
  String _reportKey = 'daily_running';
  String _period = 'daily';
  final String _groupBy = 'vehicle';
  final String _dueStatus = 'all';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: AppDrawer(onSelectTab: widget.onSelectTab),
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(LucideIcons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const AppLogo(),
        actions: <Widget>[
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue),
                  )
                : Icon(LucideIcons.download, color: Theme.of(context).colorScheme.onSurface, size: 20),
            onPressed: _isExporting ? null : () => _fetchReport(includeExport: true),
          ),
        ],
      ),
      body: _isLoading && report == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                _buildModernFilterHub(meta),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(LucideIcons.alertCircle, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchReport,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: <Widget>[
                        _buildPremiumSummary(report?.summaryCards ?? const <ReportSummaryCard>[]),
                        const SizedBox(height: 24),
                        _buildPremiumChart(report?.chart ?? const ReportChart()),
                        const SizedBox(height: 24),
                        _buildModernTable(report?.rows ?? const <Map<String, dynamic>>[]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildModernFilterHub(ReportMeta meta) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _filterBubble('Report', _reportKey, meta.reportOptions, (val) {
              setState(() => _reportKey = val);
              _fetchReport();
            }),
            const SizedBox(width: 10),
            _filterBubble('Period', _period, meta.periodOptions, (val) {
              setState(() => _period = val);
              _fetchReport();
            }),
            const SizedBox(width: 10),
            _filterBubble('Vehicle', _vehicleId.toString(), [
              const ReportOption(key: '0', label: 'All Vehicles'),
              ...meta.vehicleOptions.map((v) => ReportOption(key: v.id.toString(), label: v.label)),
            ], (val) {
              setState(() => _vehicleId = int.parse(val));
              _fetchReport();
            }),
          ],
        ),
      ),
    );
  }

  Widget _filterBubble(String label, String current, List<ReportOption> options, Function(String) onSelect) {
    final selectedLabel = options.firstWhere((o) => o.key == current, orElse: () => options.first).label;
    return GestureDetector(
      onTap: () => _showFilterPicker(label, options, current, onSelect),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Text('$label: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            Text(selectedLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showFilterPicker(String title, List<ReportOption> options, String current, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select $title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final opt = options[i];
                  final isSelected = opt.key == current;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(opt.label, style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500, color: isSelected ? AppTheme.primaryBlue : Theme.of(context).colorScheme.onSurface)),
                    trailing: isSelected ? Icon(LucideIcons.check, color: AppTheme.primaryBlue, size: 20) : null,
                    onTap: () {
                      onSelect(opt.key);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildPremiumSummary(List<ReportSummaryCard> cards) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        final colors = [AppColors.primary, Colors.green, Colors.orange, Colors.purple, Colors.blue];
        final color = colors[index % colors.length];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(_getIconForLabel(card.label), color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(card.label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                    Text(card.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getIconForLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('distance') || lower.contains('km')) return LucideIcons.mapPin;
    if (lower.contains('fuel')) return LucideIcons.fuel;
    if (lower.contains('speed')) return LucideIcons.gauge;
    if (lower.contains('time') || lower.contains('idle')) return LucideIcons.clock;
    if (lower.contains('cost')) return LucideIcons.indianRupee;
    return LucideIcons.barChart;
  }

  Widget _buildPremiumChart(ReportChart chart) {
    final hasData = chart.series.any((series) => series.data.isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Visual Analytics', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.primaryBlue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                child: Text(chart.type.toUpperCase(), style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: hasData ? _chartWidget(chart) : const Center(child: Text('No chart data available')),
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

  Widget _buildModernTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final columns = rows.first.keys.toList(growable: false);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Detailed Report Data', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
              horizontalMargin: 20,
              columnSpacing: 30,
              headingRowHeight: 48,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade100, width: 1)),
              columns: columns
                  .map((column) => DataColumn(
                        label: Text(humanizeSnakeCase(column), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.accent)),
                      ))
                  .toList(),
              rows: rows
                  .take(30)
                  .map((row) => DataRow(
                        cells: columns.map((column) => DataCell(Text((row[column] ?? '').toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)))).toList(),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
