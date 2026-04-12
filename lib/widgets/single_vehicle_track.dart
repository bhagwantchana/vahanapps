import 'dart:async';

import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_cubit.dart';
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_state.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_cubit.dart';
import 'package:fleet_monitor/models/driver_record_model.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/models/vehicle_settings_model.dart';
import 'package:fleet_monitor/repositorys/driver_repository.dart';
import 'package:fleet_monitor/repositorys/single_track_repository.dart';
import 'package:fleet_monitor/screens/document_vault_screen.dart';
import 'package:fleet_monitor/screens/driver_sessions_screen.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:fleet_monitor/widgets/native_vehicle_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({super.key});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  static const Duration _liveRefreshInterval = Duration(seconds: 3);
  final DriverRepository _driverRepository = DriverRepository();
  final SingleTrackRepository _trackRepository = SingleTrackRepository();

  WebViewController? _controller;
  bool isLoading = true;
  bool _isSessionBusy = false;
  bool _isRefreshingLiveTrack = false;
  String _loadedUrl = '';
  List<DriverRecordModel> _availableDrivers = <DriverRecordModel>[];
  Future<List<LatLng>>? _routeTrailFuture;
  Timer? _liveRefreshTimer;
  int _routeTrailVehicleId = 0;
  int _routeTrailMinutes = 0;
  int _routeTrailPoints = 0;
  String _routeTrailImei = '';

  void _loadWebLink(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null) {
      return;
    }

    _loadedUrl = url;
    _controller ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => isLoading = true),
          onPageFinished: (_) => setState(() => isLoading = false),
        ),
      );
    _controller!.loadRequest(parsed);
  }

  VehicleSettingsModel _resolveSettings(VehicleRecord vehicle) {
    return vehicle.settings ??
        VehicleSettingsModel(
          vehicleId: vehicle.id,
          deviceId: vehicle.deviceId,
          imei: vehicle.imei,
          notificationEnabled: vehicle.notificationEnabled,
          overspeedLimit: vehicle.overspeedLimit,
          geofenceLat: vehicle.geofenceLat,
          geofenceLng: vehicle.geofenceLng,
          geofenceRadius: vehicle.geofenceRadius,
          guardActive: vehicle.guardActive,
          guardLat: vehicle.guardLat,
          guardLng: vehicle.guardLng,
          mapSelection: vehicle.mapSelection,
          engineCutoff: vehicle.engineCutoff,
          radiusConfig: vehicle.radiusConfig,
          parkingGuard: vehicle.parkingGuard,
          trackingUrl: vehicle.trackingUrl,
          singleMapUrl: vehicle.singleMapUrl,
          googleTrackingUrl: vehicle.googleTrackingUrl,
          historyUrl: vehicle.historyUrl,
          mobileMapMode: 'native',
        );
  }

  Future<List<DriverRecordModel>> _getVehicleDrivers(VehicleRecord vehicle) async {
    if (_availableDrivers.isEmpty) {
      _availableDrivers = await _driverRepository.fetchDrivers();
    }

    if (vehicle.vendorId <= 0) {
      return _availableDrivers;
    }

    final scopedDrivers = _availableDrivers
        .where((driver) => driver.vendorId == 0 || driver.vendorId == vehicle.vendorId)
        .toList();

    return scopedDrivers.isNotEmpty ? scopedDrivers : _availableDrivers;
  }

  Future<void> _refreshVehicleState(VehicleRecord vehicle) async {
    await context.read<SingleTrackCubit>().fetchVehicleTrack(vehicle.imei);
    await context.read<VehicleCubit>().fetchVehicles();
    _routeTrailFuture = null;
  }

  Future<void> _refreshLiveTrack(VehicleRecord vehicle) async {
    if (_isRefreshingLiveTrack) {
      return;
    }

    _isRefreshingLiveTrack = true;
    try {
      await context.read<SingleTrackCubit>().fetchVehicleTrack(vehicle.imei);
      _routeTrailFuture = null;
    } finally {
      _isRefreshingLiveTrack = false;
    }
  }

  void _startLiveRefresh() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer.periodic(_liveRefreshInterval, (_) {
      if (!mounted) {
        return;
      }

      final vehicle = context.read<SingleTrackCubit>().state.singleTrackModel?.data;
      if (vehicle == null) {
        return;
      }

      unawaited(_refreshLiveTrack(vehicle));
    });
  }

  int _trailWindowMinutes(VehicleSettingsModel settings) {
    return settings.mobileMapTrailMinutes > 0 ? settings.mobileMapTrailMinutes : 120;
  }

  int _trailPointLimit(VehicleSettingsModel settings) {
    return settings.mobileMapTrailPoints > 0 ? settings.mobileMapTrailPoints : 25;
  }

  Future<List<LatLng>> _loadRouteTrail(
    VehicleRecord vehicle,
    VehicleSettingsModel settings,
  ) async {
    try {
      final now = DateTime.now();
      final minutes = _trailWindowMinutes(settings);
      final from = now.subtract(Duration(minutes: minutes));
      final points = await _trackRepository.fetchTripHistoryTrail(
        imei: vehicle.imei,
        from: from,
        to: now,
      );
      final limit = _trailPointLimit(settings);
      final trail = points
          .map((item) => item.toLatLng())
          .where((point) => point.latitude != 0 || point.longitude != 0)
          .toList();
      if (trail.length <= limit) {
        return trail;
      }
      return trail.sublist(trail.length - limit);
    } catch (_) {
      return <LatLng>[];
    }
  }

  Future<List<LatLng>> _resolveRouteTrail(
    VehicleRecord vehicle,
    VehicleSettingsModel settings,
  ) {
    final minutes = _trailWindowMinutes(settings);
    final points = _trailPointLimit(settings);

    if (_routeTrailFuture == null ||
        _routeTrailVehicleId != vehicle.id ||
        _routeTrailMinutes != minutes ||
        _routeTrailPoints != points ||
        _routeTrailImei != vehicle.imei) {
      _routeTrailVehicleId = vehicle.id;
      _routeTrailMinutes = minutes;
      _routeTrailPoints = points;
      _routeTrailImei = vehicle.imei;
      _routeTrailFuture = _loadRouteTrail(vehicle, settings);
    }

    return _routeTrailFuture!;
  }

  @override
  void initState() {
    super.initState();
    _startLiveRefresh();
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleNotifications(VehicleRecord vehicle) async {
    final settings = _resolveSettings(vehicle).copyWith(
      notificationEnabled:
          _resolveSettings(vehicle).notificationEnabled == 1 ? 0 : 1,
    );
    final saved = await context.read<SingleTrackCubit>().updateVehicleSettings(
      vehicle: vehicle,
      settings: settings,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? settings.notificationEnabled == 1
                    ? 'Notifications enabled'
                    : 'Notifications disabled'
              : 'Unable to update notifications',
        ),
      ),
    );
  }

  Future<void> _toggleGuardMode(VehicleRecord vehicle) async {
    final current = _resolveSettings(vehicle);
    final nextGuardState = current.guardActive == 1 ? 0 : 1;
    final settings = current.copyWith(
      guardActive: nextGuardState,
      parkingGuard: nextGuardState,
    );
    final saved = await context.read<SingleTrackCubit>().updateVehicleSettings(
      vehicle: vehicle,
      settings: settings,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? nextGuardState == 1
                    ? 'Parking guard enabled'
                    : 'Parking guard disabled'
              : 'Unable to update parking guard',
        ),
      ),
    );
  }

  Future<void> _sendEngineCommand(VehicleRecord vehicle, String action) async {
    final commandLabel = action == 'immobilize' ? 'Engine Stop' : 'Engine Start';
    final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(commandLabel),
            content: Text(
              action == 'immobilize'
                  ? 'This will prevent the vehicle from being started again until restore is sent. It only works below 10 km/h. Continue?'
                  : 'This will restore engine start permission for the vehicle. Continue?',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldProceed) {
      return;
    }

    final saved = await context.read<SingleTrackCubit>().sendEngineCommand(
          vehicle: vehicle,
          action: action,
        );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? '$commandLabel request queued successfully'
              : 'Unable to process $commandLabel request',
        ),
        backgroundColor: saved ? AppTheme.primaryGreen : AppColors.red,
      ),
    );
    if (saved) {
      await _refreshVehicleState(vehicle);
    }
  }

  Future<void> _launchHistory(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openLiveMap(VehicleRecord vehicle) async {
    final liveUrl = vehicle.primaryMapUrl.isNotEmpty
        ? vehicle.primaryMapUrl
        : vehicle.googleTrackingUrl;
    final parsed = Uri.tryParse(liveUrl);

    if (parsed == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live map is not available for this vehicle')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => VehicleLiveMapScreen(
          title: vehicle.displayName,
          url: liveUrl,
        ),
      ),
    );
  }

  Future<void> _showConfigModal(VehicleRecord vehicle) async {
    final settings = _resolveSettings(vehicle);
    final overspeedController = TextEditingController(
      text: settings.overspeedLimit.toString(),
    );
    final radiusController = TextEditingController(
      text: settings.geofenceRadius.toString(),
    );
    var notificationsEnabled = settings.notificationEnabled == 1;
    var guardEnabled = settings.guardActive == 1;
    var nightLockEnabled = settings.nightLockEnabled == 1;
    final nightLockStartController = TextEditingController(
      text: settings.nightLockStart.substring(0, 5),
    );
    final nightLockEndController = TextEditingController(
      text: settings.nightLockEnd.substring(0, 5),
    );
    final nightLockTimezoneController = TextEditingController(
      text: settings.nightLockTimezone,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Vehicle Configuration',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      value: notificationsEnabled,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Push Notifications'),
                      subtitle: const Text('Receive ignition, overspeed, and radius alerts'),
                      onChanged: (value) {
                        setModalState(() => notificationsEnabled = value);
                      },
                    ),
                    SwitchListTile(
                      value: guardEnabled,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Parking Guard'),
                      subtitle: const Text('Alert when the parked vehicle moves away'),
                      onChanged: (value) {
                        setModalState(() => guardEnabled = value);
                      },
                    ),
                    SwitchListTile(
                      value: nightLockEnabled,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Night Lock'),
                      subtitle: const Text('Auto queue engine stop in the configured night window'),
                      onChanged: (value) {
                        setModalState(() => nightLockEnabled = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: overspeedController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Overspeed Limit (km/h)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: radiusController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Radius Alert (meters)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nightLockStartController,
                      decoration: const InputDecoration(
                        labelText: 'Night Lock Start (HH:MM)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nightLockEndController,
                      decoration: const InputDecoration(
                        labelText: 'Night Lock End (HH:MM)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nightLockTimezoneController,
                      decoration: const InputDecoration(
                        labelText: 'Night Lock Timezone',
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final updated = settings.copyWith(
                            notificationEnabled: notificationsEnabled ? 1 : 0,
                            guardActive: guardEnabled ? 1 : 0,
                            parkingGuard: guardEnabled ? 1 : 0,
                            overspeedLimit:
                                int.tryParse(overspeedController.text.trim()) ?? 0,
                            geofenceRadius:
                                int.tryParse(radiusController.text.trim()) ?? 0,
                            nightLockEnabled: nightLockEnabled ? 1 : 0,
                            nightLockStart: nightLockStartController.text.trim().isEmpty
                                ? settings.nightLockStart
                                : nightLockStartController.text.trim(),
                            nightLockEnd: nightLockEndController.text.trim().isEmpty
                                ? settings.nightLockEnd
                                : nightLockEndController.text.trim(),
                            nightLockTimezone: nightLockTimezoneController.text.trim().isEmpty
                                ? settings.nightLockTimezone
                                : nightLockTimezoneController.text.trim(),
                          );
                          final saved = await context
                              .read<SingleTrackCubit>()
                              .updateVehicleSettings(
                                vehicle: vehicle,
                                settings: updated,
                              );
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                saved
                                    ? 'Vehicle settings updated'
                                    : 'Unable to update vehicle settings',
                              ),
                              backgroundColor:
                                  saved ? AppTheme.primaryGreen : AppColors.red,
                            ),
                          );
                        },
                        child: const Text(
                          'Save Settings',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openDocuments(VehicleRecord vehicle) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DocumentVaultScreen(
          vehicleId: vehicle.id,
          title: '${vehicle.displayName} Documents',
        ),
      ),
    );
  }

  Future<void> _openDriverSessions(VehicleRecord vehicle) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DriverSessionsScreen(
          vehicleId: vehicle.id,
          title: '${vehicle.displayName} Sessions',
        ),
      ),
    );
    await _refreshVehicleState(vehicle);
  }

  Future<void> _endActiveDriverSession(VehicleRecord vehicle) async {
    final activeDriver = vehicle.activeDriver;
    if (activeDriver == null || !activeDriver.isActive || _isSessionBusy) {
      return;
    }

    setState(() => _isSessionBusy = true);
    try {
      final message = await _driverRepository.endDriverSession(
        sessionId: activeDriver.sessionId > 0 ? activeDriver.sessionId : null,
        vehicleId: vehicle.id,
        imei: vehicle.imei,
      );
      if (!mounted) {
        return;
      }
      await _refreshVehicleState(vehicle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
        setState(() => _isSessionBusy = false);
      }
    }
  }

  Future<void> _showDriverSessionSheet(VehicleRecord vehicle) async {
    List<DriverRecordModel> drivers = <DriverRecordModel>[];

    try {
      drivers = await _getVehicleDrivers(vehicle);
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
      return;
    }

    if (!mounted) {
      return;
    }

    final identifierController = TextEditingController();
    final pinController = TextEditingController();
    final sessionCodeController = TextEditingController();
    final notesController = TextEditingController();
    final rootContext = context;
    int? selectedDriverId = drivers.isNotEmpty ? drivers.first.id : null;
    String identificationMethod = 'manual';
    bool assignToVehicle = false;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final hasSelection = (selectedDriverId != null && selectedDriverId! > 0) ||
                identifierController.text.trim().isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Start Driver Session',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        vehicle.displayName,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (drivers.isNotEmpty)
                        DropdownButtonFormField<int>(
                          value: selectedDriverId,
                          decoration: const InputDecoration(
                            labelText: 'Select Driver',
                          ),
                          items: drivers
                              .map(
                                (driver) => DropdownMenuItem<int>(
                                  value: driver.id,
                                  child: Text(driver.displayLabel),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setModalState(() => selectedDriverId = value);
                          },
                        ),
                      if (drivers.isNotEmpty) const SizedBox(height: 14),
                      TextFormField(
                        controller: identifierController,
                        decoration: const InputDecoration(
                          labelText: 'Driver Code / Phone (optional)',
                          helperText: 'Use this if you want to start by identifier instead',
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: pinController,
                        decoration: const InputDecoration(
                          labelText: 'Driver PIN (if required)',
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: identificationMethod,
                        decoration: const InputDecoration(
                          labelText: 'Identification Method',
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'manual', child: Text('Manual')),
                          DropdownMenuItem(value: 'pin', child: Text('PIN')),
                          DropdownMenuItem(value: 'qr', child: Text('QR')),
                          DropdownMenuItem(value: 'nfc', child: Text('NFC / RFID')),
                          DropdownMenuItem(value: 'api', child: Text('API')),
                        ],
                        onChanged: (value) {
                          setModalState(() => identificationMethod = value ?? 'manual');
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: sessionCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Session Code (optional)',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        value: assignToVehicle,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Assign selected driver to this vehicle'),
                        subtitle: const Text('Updates the default driver mapping too'),
                        onChanged: selectedDriverId != null
                            ? (value) => setModalState(() => assignToVehicle = value)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: !hasSelection || isSubmitting
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final message = await _driverRepository.startDriverSession(
                                      vehicleId: vehicle.id,
                                      driverId: selectedDriverId,
                                      driverIdentifier: identifierController.text.trim(),
                                      driverPin: pinController.text.trim(),
                                      identificationMethod: identificationMethod,
                                      sessionCode: sessionCodeController.text.trim(),
                                      notes: notesController.text.trim(),
                                    );

                                    if (assignToVehicle && selectedDriverId != null) {
                                      await _driverRepository.assignDriver(
                                        driverId: selectedDriverId!,
                                        vehicleId: vehicle.id,
                                      );
                                    }

                                    if (!mounted) {
                                      return;
                                    }

                                    Navigator.pop(modalContext);
                                    await _refreshVehicleState(vehicle);
                                    ScaffoldMessenger.of(rootContext).showSnackBar(
                                      SnackBar(content: Text(message)),
                                    );
                                  } catch (error) {
                                    if (!context.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(rootContext).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          error.toString().replaceFirst('Exception: ', ''),
                                        ),
                                        backgroundColor: AppColors.red,
                                      ),
                                    );
                                  } finally {
                                    if (context.mounted) {
                                      setModalState(() => isSubmitting = false);
                                    }
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(LucideIcons.playCircle),
                          label: Text(isSubmitting ? 'Starting...' : 'Start Session'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const CustomText(text: 'Vehicle Detail')),
      body: BlocBuilder<SingleTrackCubit, SingleTrackState>(
        builder: (context, state) {
          final vehicle = state.singleTrackModel?.data;

          if (state is SingleTrackLoadingState && vehicle == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SingleTrackErrorState && vehicle == null) {
            return Center(child: Text(state.message));
          }

          if (vehicle == null) {
            return const Center(child: CustomText(text: 'No data'));
          }

          final settings = _resolveSettings(vehicle);
          final trackingUrl = vehicle.primaryMapUrl;
          final liveMapUrl = trackingUrl.isNotEmpty
              ? trackingUrl
              : vehicle.googleTrackingUrl;
          final useNativeMap = settings.mobileMapMode.toLowerCase() == 'native';
          final routeTrailFuture = _resolveRouteTrail(vehicle, settings);
          if (!useNativeMap && trackingUrl.isNotEmpty && trackingUrl != _loadedUrl) {
            _loadWebLink(trackingUrl);
          }

          return Column(
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Stack(
                  children: <Widget>[
                    Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(color: Colors.black12, blurRadius: 10),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: useNativeMap
                          ? FutureBuilder<List<LatLng>>(
                              future: routeTrailFuture,
                              builder: (context, snapshot) {
                                final trailPoints = snapshot.data ?? <LatLng>[];
                                return Stack(
                                  children: <Widget>[
                                    NativeVehicleMap(
                                      vehicles: <VehicleRecord>[vehicle],
                                      focusVehicle: vehicle,
                                      trailPoints: trailPoints,
                                      emptyTitle: vehicle.hasLiveLocation
                                          ? 'Map data not available'
                                          : 'No live location yet',
                                      emptySubtitle:
                                          'Native map is enabled from superadmin settings',
                                      followFocusedVehicle: true,
                                    ),
                                    if (snapshot.connectionState == ConnectionState.waiting)
                                      Positioned(
                                        right: 12,
                                        bottom: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.92),
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: const <BoxShadow>[
                                              BoxShadow(color: Colors.black12, blurRadius: 8),
                                            ],
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Loading trail',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            )
                          : (_controller == null
                              ? const Center(child: Text('Map link not available'))
                              : WebViewWidget(controller: _controller!)),
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: liveMapUrl.isNotEmpty
                              ? () => _openLiveMap(vehicle)
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 22,
                      right: 22,
                      child: _buildMapOverlayButton(
                        icon: Icons.open_in_full_rounded,
                        label: useNativeMap ? 'Open URL map' : 'Open map',
                        onTap: liveMapUrl.isNotEmpty
                            ? () => _openLiveMap(vehicle)
                            : null,
                      ),
                    ),
                    Positioned(
                      left: 22,
                      bottom: 22,
                      child: _buildMapInfoChip(
                        icon: LucideIcons.clock3,
                        label: _formatUpdatedAt(vehicle.createdAt),
                      ),
                    ),
                    if (isLoading && _controller != null)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 15,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                              child: const Icon(
                                LucideIcons.car,
                                size: 28,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    vehicle.displayName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    vehicle.imei.isNotEmpty
                                        ? 'IMEI: ${vehicle.imei}'
                                        : 'Device details unavailable',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(vehicle).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                vehicle.statusLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _statusColor(vehicle),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: <Widget>[
                                  _buildStatItem('Speed', '${vehicle.speed.round()} km/h'),
                                  _buildStatDivider(),
                                  _buildStatItem('Battery', '${vehicle.battery}%'),
                                  _buildStatDivider(),
                                  _buildStatItem('Engine', vehicle.engineOn ? 'ON' : 'OFF'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: <Widget>[
                                  _buildStatItem(
                                    'Alerts',
                                    settings.notificationEnabled == 1 ? 'ON' : 'OFF',
                                  ),
                                  _buildStatDivider(),
                                  _buildStatItem(
                                    'Guard',
                                    settings.guardActive == 1 ? 'ON' : 'OFF',
                                  ),
                                  _buildStatDivider(),
                                  _buildStatItem(
                                    'GPS',
                                    vehicle.hasLiveLocation ? 'LIVE' : 'NO FIX',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildVehicleMetaCard(vehicle),
                        const SizedBox(height: 16),
                        _buildDriverCard(vehicle),
                        const SizedBox(height: 16),
                        if (vehicle.hasLiveLocation)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(LucideIcons.mapPin, color: AppTheme.primaryBlue),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${vehicle.latitude.toStringAsFixed(5)}, ${vehicle.longitude.toStringAsFixed(5)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        if (settings.allowNotifications == 1 || settings.allowParkingGuard == 1)
                          Row(
                            children: <Widget>[
                              if (settings.allowNotifications == 1)
                                Expanded(
                                  child: _buildActionButton(
                                    icon: settings.notificationEnabled == 1
                                        ? LucideIcons.bell
                                        : LucideIcons.bellOff,
                                    label: settings.notificationEnabled == 1
                                        ? 'Alerts On'
                                        : 'Alerts Off',
                                    color: settings.notificationEnabled == 1
                                        ? AppTheme.primaryGreen
                                        : Colors.red,
                                    onTap: () => _toggleNotifications(vehicle),
                                  ),
                                ),
                              if (settings.allowNotifications == 1 && settings.allowParkingGuard == 1)
                                const SizedBox(width: 12),
                              if (settings.allowParkingGuard == 1)
                                Expanded(
                                  child: _buildActionButton(
                                    icon: settings.guardActive == 1
                                        ? LucideIcons.shieldAlert
                                        : LucideIcons.shield,
                                    label: settings.guardActive == 1
                                        ? 'Guard On'
                                        : 'Guard Off',
                                    color: settings.guardActive == 1
                                        ? Colors.orange
                                        : AppTheme.primaryBlue,
                                    onTap: () => _toggleGuardMode(vehicle),
                                  ),
                                ),
                            ],
                          ),
                        if (settings.allowNotifications == 1 || settings.allowParkingGuard == 1)
                          const SizedBox(height: 12),
                        if (settings.allowEngineControl == 1 && settings.engineCutoff == 1)
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _buildActionButton(
                                  icon: vehicle.isImmobilized
                                      ? LucideIcons.unlock
                                      : LucideIcons.lock,
                                  label: vehicle.isImmobilized
                                      ? 'Engine Start'
                                      : 'Engine Stop',
                                  color: vehicle.isImmobilized
                                      ? AppTheme.primaryGreen
                                      : Colors.red,
                                  onTap: vehicle.isImmobilizerBusy
                                      ? null
                                      : () => _sendEngineCommand(
                                            vehicle,
                                            vehicle.isImmobilized
                                                ? 'restore'
                                                : 'immobilize',
                                          ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionButton(
                                  icon: LucideIcons.lock,
                                  label: vehicle.isImmobilizerBusy
                                      ? 'Pending'
                                      : vehicle.immobilizerState
                                          .replaceAll('_', ' ')
                                          .toUpperCase(),
                                  color: vehicle.isImmobilizerBusy
                                      ? Colors.orange
                                      : AppTheme.primaryBlue,
                                  onTap: null,
                                ),
                              ),
                            ],
                          ),
                        if (settings.allowEngineControl == 1 && settings.engineCutoff == 1)
                          const SizedBox(height: 12),
                        if (settings.allowHistory == 1 || settings.allowConfig == 1)
                          Row(
                            children: <Widget>[
                              if (settings.allowHistory == 1)
                                Expanded(
                                  child: _buildActionButton(
                                    icon: LucideIcons.history,
                                    label: 'History',
                                    color: AppTheme.primaryBlue,
                                    onTap: settings.historyUrl.isNotEmpty
                                        ? () => _launchHistory(settings.historyUrl)
                                        : null,
                                  ),
                                ),
                              if (settings.allowHistory == 1 && settings.allowConfig == 1)
                                const SizedBox(width: 12),
                              if (settings.allowConfig == 1)
                                Expanded(
                                  child: _buildActionButton(
                                    icon: LucideIcons.settings,
                                    label: 'Config',
                                    color: Colors.grey.shade700,
                                    onTap: () => _showConfigModal(vehicle),
                                  ),
                                ),
                            ],
                          ),
                        if (settings.allowHistory == 1 || settings.allowConfig == 1)
                          const SizedBox(height: 12),
                        if (settings.allowDriverSessions == 1 || settings.allowDocuments == 1)
                          Row(
                            children: <Widget>[
                              if (settings.allowDriverSessions == 1)
                                Expanded(
                                  child: _buildActionButton(
                                    icon: LucideIcons.badgeCheck,
                                    label: 'Driver',
                                    color: AppTheme.primaryBlue,
                                    onTap: _isSessionBusy
                                        ? null
                                        : () => _showDriverSessionSheet(vehicle),
                                  ),
                                ),
                              if (settings.allowDriverSessions == 1 && settings.allowDocuments == 1)
                                const SizedBox(width: 12),
                              if (settings.allowDocuments == 1)
                                Expanded(
                                  child: _buildActionButton(
                                    icon: LucideIcons.folderOpen,
                                    label: 'Documents',
                                    color: Colors.deepPurple,
                                    onTap: () => _openDocuments(vehicle),
                                  ),
                                ),
                            ],
                          ),
                        if (state is SingleTrackErrorState) ...<Widget>[
                          const SizedBox(height: 14),
                          Text(
                            state.message,
                            style: const TextStyle(
                              color: AppColors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDriverCard(VehicleRecord vehicle) {
    final activeDriver = vehicle.activeDriver;
    final hasActiveDriver = activeDriver?.isActive == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
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
                    const Text(
                      'Driver ID',
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasActiveDriver
                          ? activeDriver!.displayName
                          : 'No active driver session for this vehicle',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (hasActiveDriver ? AppColors.green : AppColors.orange)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  hasActiveDriver ? 'ACTIVE' : 'PENDING',
                  style: TextStyle(
                    color: hasActiveDriver ? AppColors.green : AppColors.orange,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (hasActiveDriver) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _driverChip(
                  icon: LucideIcons.scanLine,
                  label: activeDriver!.identificationMethod.isNotEmpty
                      ? activeDriver!.identificationMethod.toUpperCase()
                      : 'MANUAL',
                ),
                _driverChip(
                  icon: LucideIcons.hash,
                  label: activeDriver!.driverCode.isNotEmpty
                      ? activeDriver!.driverCode
                      : 'No code',
                ),
                _driverChip(
                  icon: LucideIcons.clock3,
                  label: _formatUpdatedAt(activeDriver!.identifiedAt),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _openDriverSessions(vehicle),
                  icon: const Icon(LucideIcons.list),
                  label: const Text(
                    'Sessions',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _isSessionBusy
                      ? null
                      : hasActiveDriver
                      ? () => _endActiveDriverSession(vehicle)
                      : () => _showDriverSessionSheet(vehicle),
                  icon: _isSessionBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          hasActiveDriver ? LucideIcons.logOut : LucideIcons.playCircle,
                        ),
                  label: Text(
                    hasActiveDriver ? 'End Session' : 'Start Session',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _driverChip({required IconData icon, required String label}) {
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

  Color _statusColor(VehicleRecord vehicle) {
    if (vehicle.isMoving) {
      return AppColors.green;
    }
    if (vehicle.isIdle) {
      return AppColors.orange;
    }
    return AppColors.red;
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 30, width: 1, color: Colors.grey.shade300);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.shade200
              : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.shade300
                : color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              color: isDisabled ? Colors.grey.shade500 : color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isDisabled ? Colors.grey.shade600 : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleMetaCard(VehicleRecord vehicle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Vehicle Details',
            style: TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12) / 2;
              final tiles = <Widget>[
                SizedBox(
                  width: itemWidth,
                  child: _buildDetailTile(
                    icon: Icons.pin_outlined,
                    label: 'Registration',
                    value: vehicle.registrationNumber,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildDetailTile(
                    icon: Icons.directions_car_outlined,
                    label: 'Vehicle Name',
                    value: vehicle.name,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildDetailTile(
                    icon: Icons.category_outlined,
                    label: 'Vehicle Type',
                    value: vehicle.typeName,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildDetailTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Model',
                    value: vehicle.model,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildDetailTile(
                    icon: Icons.memory_rounded,
                    label: 'Device',
                    value: vehicle.deviceModel.isNotEmpty
                        ? vehicle.deviceModel
                        : 'Not available',
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildDetailTile(
                    icon: Icons.settings_ethernet_rounded,
                    label: 'Protocol / Port',
                    value: _formatProtocol(vehicle),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildDetailTile(
                    icon: LucideIcons.gauge,
                    label: 'Overspeed Limit',
                    value: '${vehicle.overspeedLimit} km/h',
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildDetailTile(
                    icon: Icons.center_focus_weak_rounded,
                    label: 'Radius Alert',
                    value: '${vehicle.geofenceRadius} m',
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildDetailTile(
                    icon: vehicle.isImmobilized ? LucideIcons.lock : LucideIcons.unlock,
                    label: 'Immobilizer',
                    value: vehicle.immobilizerState.replaceAll('_', ' ').toUpperCase(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildDetailTile(
                    icon: Icons.nightlight_round,
                    label: 'Night Lock',
                    value: vehicle.nightLockEnabled == 1
                        ? '${vehicle.nightLockStart.substring(0, 5)} - ${vehicle.nightLockEnd.substring(0, 5)} (${vehicle.nightLockTimezone})'
                        : 'Disabled',
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildDetailTile(
                    icon: Icons.place_outlined,
                    label: 'Coordinates',
                    value: vehicle.hasLiveLocation
                        ? '${vehicle.latitude.toStringAsFixed(5)}, ${vehicle.longitude.toStringAsFixed(5)}'
                        : 'No live location',
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildDetailTile(
                    icon: Icons.access_time_rounded,
                    label: 'Last Update',
                    value: _formatUpdatedAt(vehicle.createdAt),
                  ),
                ),
              ];

              if (vehicle.showEngineRpm == 1 && vehicle.engineRpm > 0) {
                tiles.add(
                  SizedBox(
                    width: itemWidth,
                    child: _buildDetailTile(
                      icon: LucideIcons.gauge,
                      label: 'Engine RPM',
                      value: vehicle.engineRpm.toStringAsFixed(0),
                    ),
                  ),
                );
              }
              if (vehicle.showBatteryVoltage == 1 && vehicle.batteryVoltage > 0) {
                tiles.add(
                  SizedBox(
                    width: itemWidth,
                    child: _buildDetailTile(
                      icon: LucideIcons.batteryCharging,
                      label: 'Battery Voltage',
                      value: '${vehicle.batteryVoltage.toStringAsFixed(1)} V',
                    ),
                  ),
                );
              }
              if (vehicle.showDtcCodes == 1 && vehicle.dtcCodes.trim().isNotEmpty) {
                tiles.add(
                  SizedBox(
                    width: itemWidth,
                    child: _buildDetailTile(
                      icon: LucideIcons.alertTriangle,
                      label: 'DTC Codes',
                      value: vehicle.dtcCodes,
                    ),
                  ),
                );
              }
              if (vehicle.showEcuMileage == 1 && vehicle.ecuMileage > 0) {
                tiles.add(
                  SizedBox(
                    width: itemWidth,
                    child: _buildDetailTile(
                      icon: Icons.alt_route,
                      label: 'ECU Mileage',
                      value: '${vehicle.ecuMileage.toStringAsFixed(0)} km',
                    ),
                  ),
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: tiles,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final displayValue = value.trim().isEmpty ? '--' : value.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            displayValue,
            style: const TextStyle(
              color: AppTheme.primaryBlue,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapOverlayButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 15,
                color: AppTheme.primaryBlue,
              ),
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
        ),
      ),
    );
  }

  Widget _buildMapInfoChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatProtocol(VehicleRecord vehicle) {
    final protocol = vehicle.protocol.trim();
    final port = vehicle.port.trim();

    if (protocol.isEmpty && port.isEmpty) {
      return 'Not available';
    }
    if (protocol.isNotEmpty && port.isNotEmpty) {
      return '$protocol / $port';
    }

    return protocol.isNotEmpty ? protocol : port;
  }

  String _formatUpdatedAt(String createdAt) {
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) {
      return '--';
    }
    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final minute = local.minute.toString().padLeft(2, '0');
    final meridiem = local.hour >= 12 ? 'PM' : 'AM';
    final hour = (local.hour % 12 == 0 ? 12 : local.hour % 12)
        .toString()
        .padLeft(2, '0');

    return '$day-$month-$year $hour:$minute $meridiem';
  }
}

class VehicleLiveMapScreen extends StatefulWidget {
  const VehicleLiveMapScreen({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<VehicleLiveMapScreen> createState() => _VehicleLiveMapScreenState();
}

class _VehicleLiveMapScreenState extends State<VehicleLiveMapScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final parsed = Uri.parse(widget.url);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: <Widget>[
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
