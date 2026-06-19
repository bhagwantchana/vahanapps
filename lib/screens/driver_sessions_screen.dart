import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_cubit.dart';
import 'package:fleet_monitor/models/driver_session_model.dart';
import 'package:fleet_monitor/repositorys/driver_repository.dart';
import 'package:fleet_monitor/widgets/single_vehicle_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

class DriverSessionsScreen extends StatefulWidget {
  const DriverSessionsScreen({
    super.key,
    this.vehicleId = 0,
    this.title = 'Driver Sessions',
  });

  final int vehicleId;
  final String title;

  @override
  State<DriverSessionsScreen> createState() => _DriverSessionsScreenState();
}

class _DriverSessionsScreenState extends State<DriverSessionsScreen> {
  final DriverRepository _driverRepository = DriverRepository();
  final List<DriverSessionModel> _sessions = <DriverSessionModel>[];

  bool _isLoading = true;
  int _workingSessionId = 0;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final sessions = await _driverRepository.fetchDriverSessions(
        vehicleId: widget.vehicleId > 0 ? widget.vehicleId : null,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _sessions
          ..clear()
          ..addAll(sessions);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _endSession(DriverSessionModel session) async {
    setState(() => _workingSessionId = session.id);
    try {
      final message = await _driverRepository.endDriverSession(sessionId: session.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _loadSessions();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _workingSessionId = 0);
      }
    }
  }

  Future<void> _openVehicle(DriverSessionModel session) async {
    if (session.imei.isEmpty) {
      return;
    }

    await context.read<SingleTrackCubit>().fetchVehicleTrack(session.imei);
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const VehicleDetailScreen(),
      ),
    );
    await _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(widget.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(_error, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadSessions,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _sessions.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadSessions,
              child: ListView(
                children: const <Widget>[
                  SizedBox(
                    height: 320,
                    child: Center(child: Text('No active driver sessions')),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSessions,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.badge_outlined,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      session.displayDriver.isNotEmpty
                                          ? session.displayDriver
                                          : 'Driver Session',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      session.displayVehicle.isNotEmpty
                                          ? session.displayVehicle
                                          : session.imei,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: AppColors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _sessionChip(
                                icon: LucideIcons.scanLine,
                                label: session.identificationMethod.isNotEmpty
                                    ? session.identificationMethod.toUpperCase()
                                    : 'MANUAL',
                              ),
                              _sessionChip(
                                icon: LucideIcons.clock3,
                                label: _formatDateTime(session.startedAt),
                              ),
                              if (session.sessionCode.isNotEmpty)
                                _sessionChip(
                                  icon: LucideIcons.hash,
                                  label: session.sessionCode,
                                ),
                            ],
                          ),
                          if (session.notes.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 10),
                            Text(
                              session.notes,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: session.imei.isNotEmpty
                                      ? () => _openVehicle(session)
                                      : null,
                                  icon: Icon(LucideIcons.map),
                                  label: const Text('Open Vehicle'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _workingSessionId == session.id
                                      ? null
                                      : () => _endSession(session),
                                  icon: _workingSessionId == session.id
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(LucideIcons.logOut),
                                  label: Text(
                                    _workingSessionId == session.id
                                        ? 'Ending...'
                                        : 'End Session',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _sessionChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppTheme.primaryBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.primaryBlue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value.isEmpty ? '--' : value;
    }
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }
}
