import 'dart:async';
import 'dart:ui';

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
import 'package:fleet_monitor/screens/driving_score_screen.dart';
import 'package:fleet_monitor/screens/nearby_pois_screen.dart';
import 'package:fleet_monitor/screens/trip_replay_screen.dart';
import 'package:fleet_monitor/services/lifecycle_refresh.dart';
import 'package:fleet_monitor/widgets/app_logo.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:fleet_monitor/widgets/live_address_text.dart';
import 'package:fleet_monitor/widgets/native_vehicle_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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

  final DriverRepository _driverRepository = DriverRepository();
  final SingleTrackRepository _trackRepository = SingleTrackRepository();

  WebViewController? _controller;
  bool isLoading = true;
  bool _isSessionBusy = false;
  // Vehicle whose map URL is currently loaded in the inline WebView. We key the
  // (re)load on the VEHICLE, not the URL string: the server's tracking_url
  // embeds a random-IV-encrypted IMEI, so it differs on EVERY API/poll response
  // for the same vehicle. Comparing the URL string reloaded the WebView every
  // ~5 s poll (spinner + map re-init = the "map keeps refreshing" report). The
  // webmap stays live on its own internal SSE, so it only needs loading once.
  int _loadedVehicleId = -1;
  List<DriverRecordModel> _availableDrivers = <DriverRecordModel>[];
  Future<List<LatLng>>? _routeTrailFuture;
  int _routeTrailVehicleId = 0;
  int _routeTrailMinutes = 0;
  int _routeTrailPoints = 0;
  String _routeTrailImei = '';

  void _loadWebLink(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null) {
      return;
    }

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

  Future<List<DriverRecordModel>> _getVehicleDrivers(
    VehicleRecord vehicle,
  ) async {
    if (_availableDrivers.isEmpty) {
      _availableDrivers = await _driverRepository.fetchDrivers();
    }

    if (vehicle.vendorId <= 0) {
      return _availableDrivers;
    }

    final scopedDrivers = _availableDrivers
        .where(
          (driver) =>
              driver.vendorId == 0 || driver.vendorId == vehicle.vendorId,
        )
        .toList();

    return scopedDrivers.isNotEmpty ? scopedDrivers : _availableDrivers;
  }

  Future<void> _refreshVehicleState(VehicleRecord vehicle) async {
    // Cache cubits before await so context isn't read after a possible unmount.
    final trackCubit = context.read<SingleTrackCubit>();
    final vehicleCubit = context.read<VehicleCubit>();
    await trackCubit.fetchVehicleTrack(vehicle.imei);
    await vehicleCubit.fetchVehicles();
    _routeTrailFuture = null;
  }

  int _trailWindowMinutes(VehicleSettingsModel settings) {
    return settings.mobileMapTrailMinutes > 0
        ? settings.mobileMapTrailMinutes
        : 120;
  }

  int _trailPointLimit(VehicleSettingsModel settings) {
    return settings.mobileMapTrailPoints > 0
        ? settings.mobileMapTrailPoints
        : 25;
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

  // Native-map liveness: a screen-owned fallback poll (fills SSE gaps with a
  // SILENT re-fetch — no spinner) + a live-growing trail appended from every
  // position update so the blue line extends while the customer watches,
  // matching the web map's accumulating route.
  // Lifecycle-aware: the raw Timer.periodic kept polling (and the SSE
  // reconnect loop spinning) while the app sat in the background — battery +
  // data drain the user never sees. LifecycleRefresh cancels on pause and
  // refreshes immediately on resume (which also revives SSE via kick()).
  late final LifecycleRefresh _nativeRefresh = LifecycleRefresh(
    interval: const Duration(seconds: 5),
    onRefresh: () async {
      if (!mounted) return;
      await context.read<SingleTrackCubit>().silentRefreshIfStale();
    },
  );
  final List<LatLng> _liveTrail = <LatLng>[];
  int _liveTrailVehicleId = 0;
  static const int _liveTrailMax = 300;

  @override
  void initState() {
    super.initState();
    _nativeRefresh.start();
  }

  @override
  void dispose() {
    _nativeRefresh.dispose();
    super.dispose();
  }

  /// Append the latest fix to the on-screen trail (min 5 m step, capped).
  void _growLiveTrail(VehicleRecord vehicle) {
    if (vehicle.latitude == 0 && vehicle.longitude == 0) return;
    if (_liveTrailVehicleId != vehicle.id) {
      _liveTrail.clear();
      _liveTrailVehicleId = vehicle.id;
    }
    final next = LatLng(vehicle.latitude, vehicle.longitude);
    if (_liveTrail.isNotEmpty) {
      final last = _liveTrail.last;
      final meters = const Distance().as(LengthUnit.Meter, last, next);
      if (meters < 5) return;
    }
    _liveTrail.add(next);
    if (_liveTrail.length > _liveTrailMax) {
      _liveTrail.removeAt(0);
    }
  }

  Future<void> _toggleNotifications(VehicleRecord vehicle) async {
    final settings = _resolveSettings(vehicle).copyWith(
      notificationEnabled: _resolveSettings(vehicle).notificationEnabled == 1
          ? 0
          : 1,
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
    final commandLabel = action == 'immobilize'
        ? 'Engine Stop'
        : 'Engine Start';
    // Cache the cubit before awaiting the confirm dialog — context.read
    // after the await can throw if the widget was disposed mid-dialog.
    final trackCubit = context.read<SingleTrackCubit>();
    final shouldProceed =
        await showDialog<bool>(
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

    final saved = await trackCubit.sendEngineCommand(
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

  Future<void> _openHistory(VehicleRecord vehicle) async {
    // In-app trip playback (defaults to TODAY; the screen has its own date /
    // range picker). Replaces the old external-browser history URL.
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TripReplayScreen(initialVehicle: vehicle),
      ),
    );
  }

  /// "Nearby" — petrol pumps / EV / tolls / speed cameras / traffic lights
  /// around the VEHICLE's last known position (not the phone's), so a fleet
  /// owner can direct a distant driver to the closest pump.
  Future<void> _openNearbyPois(VehicleRecord vehicle) async {
    if (vehicle.latitude == 0 || vehicle.longitude == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No live location for this vehicle yet'),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NearbyPoisScreen(
          lat: vehicle.latitude,
          lng: vehicle.longitude,
          vehicleName: vehicle.displayName,
        ),
      ),
    );
  }

  /// "Find my car" — open the phone's maps app with driving directions to the
  /// vehicle's last known location (great after parking in a big lot). Uses the
  /// universal Google Maps URL so it works on Android + iOS.
  Future<void> _findMyCar(VehicleRecord vehicle) async {
    if (vehicle.latitude == 0 || vehicle.longitude == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location available yet for this vehicle')),
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${vehicle.latitude},${vehicle.longitude}'
      '&travelmode=driving',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }

  /// Safely reduce a "HH:mm:ss" (or shorter) time string to "HH:mm" without
  /// throwing RangeError when the server sends a short value like "6:00".
  String _hhmm(String t) => t.length >= 5 ? t.substring(0, 5) : t;

  Future<void> _openLiveMap(VehicleRecord vehicle) async {
    // Native mode gets a native full-screen (map-mode consistent) — the
    // webview full-screen stays for url mode.
    final settings = _resolveSettings(vehicle);
    if (settings.mobileMapMode.toLowerCase() == 'native') {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => NativeLiveMapScreen(title: vehicle.displayName),
        ),
      );
      return;
    }

    final liveUrl = vehicle.primaryMapUrl.isNotEmpty
        ? vehicle.primaryMapUrl
        : vehicle.googleTrackingUrl;
    final parsed = Uri.tryParse(liveUrl);

    if (parsed == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live map is not available for this vehicle'),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => VehicleLiveMapScreen(
          title: vehicle.displayName,
          url: liveUrl,
          vehicle: vehicle,
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
      text: _hhmm(settings.nightLockStart),
    );
    final nightLockEndController = TextEditingController(
      text: _hhmm(settings.nightLockEnd),
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
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
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
                      subtitle: const Text(
                        'Receive ignition, overspeed, and radius alerts',
                      ),
                      onChanged: (value) {
                        setModalState(() => notificationsEnabled = value);
                      },
                    ),
                    SwitchListTile(
                      value: guardEnabled,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Parking Guard'),
                      subtitle: const Text(
                        'Alert when the parked vehicle moves away',
                      ),
                      onChanged: (value) {
                        setModalState(() => guardEnabled = value);
                      },
                    ),
                    SwitchListTile(
                      value: nightLockEnabled,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Night Lock'),
                      subtitle: const Text(
                        'Auto queue engine stop in the configured night window',
                      ),
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
                                int.tryParse(overspeedController.text.trim()) ??
                                0,
                            geofenceRadius:
                                int.tryParse(radiusController.text.trim()) ?? 0,
                            nightLockEnabled: nightLockEnabled ? 1 : 0,
                            nightLockStart:
                                nightLockStartController.text.trim().isEmpty
                                ? settings.nightLockStart
                                : nightLockStartController.text.trim(),
                            nightLockEnd:
                                nightLockEndController.text.trim().isEmpty
                                ? settings.nightLockEnd
                                : nightLockEndController.text.trim(),
                            nightLockTimezone:
                                nightLockTimezoneController.text.trim().isEmpty
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
                              backgroundColor: saved
                                  ? AppTheme.primaryGreen
                                  : AppColors.red,
                            ),
                          );
                        },
                        child: const Text(
                          'Save Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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

    // Ask before ending — this is irreversible from the app side (the driver
    // would have to be re-checked-in afterwards), so we don't want a stray
    // tap to drop an active driver mid-trip.
    final driverName = activeDriver.name.trim().isNotEmpty
        ? activeDriver.name
        : 'this driver';
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'End Driver Session',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'End the active session for $driverName on ${vehicle.name}? '
          'You can start a new session at any time.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'End Session',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldProceed != true || !mounted) {
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
      // _refreshVehicleState is async — re-verify we're still alive
      // before reaching for ScaffoldMessenger via context.
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
            final hasSelection =
                (selectedDriverId != null && selectedDriverId! > 0) ||
                identifierController.text.trim().isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
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
                          initialValue: selectedDriverId,
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
                          helperText:
                              'Use this if you want to start by identifier instead',
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
                        initialValue: identificationMethod,
                        decoration: const InputDecoration(
                          labelText: 'Identification Method',
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'manual',
                            child: Text('Manual'),
                          ),
                          DropdownMenuItem(value: 'pin', child: Text('PIN')),
                          DropdownMenuItem(value: 'qr', child: Text('QR')),
                          DropdownMenuItem(
                            value: 'nfc',
                            child: Text('NFC / RFID'),
                          ),
                          DropdownMenuItem(value: 'api', child: Text('API')),
                        ],
                        onChanged: (value) {
                          setModalState(
                            () => identificationMethod = value ?? 'manual',
                          );
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
                        title: const Text(
                          'Assign selected driver to this vehicle',
                        ),
                        subtitle: const Text(
                          'Updates the default driver mapping too',
                        ),
                        onChanged: selectedDriverId != null
                            ? (value) =>
                                  setModalState(() => assignToVehicle = value)
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
                                    final message = await _driverRepository
                                        .startDriverSession(
                                          vehicleId: vehicle.id,
                                          driverId: selectedDriverId,
                                          driverIdentifier: identifierController
                                              .text
                                              .trim(),
                                          driverPin: pinController.text.trim(),
                                          identificationMethod:
                                              identificationMethod,
                                          sessionCode: sessionCodeController
                                              .text
                                              .trim(),
                                          notes: notesController.text.trim(),
                                        );

                                    if (assignToVehicle &&
                                        selectedDriverId != null) {
                                      await _driverRepository.assignDriver(
                                        driverId: selectedDriverId!,
                                        vehicleId: vehicle.id,
                                      );
                                    }

                                    // Two contexts in play here: the outer
                                    // State's mounted (this), the modal's
                                    // own context, and the parent screen's
                                    // rootContext. The modal can be torn
                                    // down independently of the state if
                                    // the user swipes it away mid-await,
                                    // so each context needs its own check
                                    // before we touch it.
                                    if (!mounted) {
                                      return;
                                    }
                                    if (modalContext.mounted) {
                                      Navigator.pop(modalContext);
                                    }
                                    await _refreshVehicleState(vehicle);
                                    if (!rootContext.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(
                                      rootContext,
                                    ).showSnackBar(
                                      SnackBar(content: Text(message)),
                                    );
                                  } catch (error) {
                                    if (!context.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(
                                      rootContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          error.toString().replaceFirst(
                                            'Exception: ',
                                            '',
                                          ),
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
                              : Icon(LucideIcons.playCircle),
                          label: Text(
                            isSubmitting ? 'Starting...' : 'Start Session',
                          ),
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

  void _showFullAddressModal(VehicleRecord vehicle) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                    LucideIcons.mapPin,
                    color: AppTheme.primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Vehicle Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LiveAddressText(
              latitude: vehicle.latitude,
              longitude: vehicle.longitude,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.5,
              ),
              maxLines: 10,
            ),
            const SizedBox(height: 14),
            Text(
              'Coordinates: ${vehicle.latitude.toStringAsFixed(6)}, ${vehicle.longitude.toStringAsFixed(6)}',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: const AppLogo(),
      ),
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
          // Mirror the home screen's guard: an empty/malformed tracking URL
          // must never strand the user on a dead card — fall back to native.
          final useNativeMap =
              settings.mobileMapMode.toLowerCase() == 'native' ||
                  trackingUrl.isEmpty;
          final routeTrailFuture = _resolveRouteTrail(vehicle, settings);
          // Grow the on-screen live trail from every position update (SSE or
          // silent poll) so the line extends while the customer watches.
          if (useNativeMap) _growLiveTrail(vehicle);
          // Load ONCE per vehicle — NOT on every URL change. tracking_url's
          // encrypted IMEI uses a random IV so its string differs on every poll
          // response; reloading on that churned the WebView every ~5 s. The
          // webmap self-refreshes via its own SSE once loaded.
          if (!useNativeMap &&
              trackingUrl.isNotEmpty &&
              _loadedVehicleId != vehicle.id) {
            _loadedVehicleId = vehicle.id;
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
                                // History snapshot + the live-growing session
                                // trail (SSE/poll-fed) = a route line that
                                // extends as the vehicle drives, like the web map.
                                final trailPoints = <LatLng>[
                                  ...(snapshot.data ?? <LatLng>[]),
                                  ..._liveTrail,
                                ];
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
                                      // Shorter glide than the home overview:
                                      // SSE pushes land every few seconds, so
                                      // 2.5 s keeps the marker close to the
                                      // real position without visible jumps.
                                      moveAnimationDuration:
                                          const Duration(milliseconds: 2500),
                                    ),
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting)
                                      Positioned(
                                        right: 12,
                                        bottom: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.92,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: const <BoxShadow>[
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              SizedBox(
                                                width: 12,
                                                height: 12,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
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
                                ? const Center(
                                    child: Text('Map link not available'),
                                  )
                                : WebViewWidget(
                                    controller: _controller!,
                                    // Same fix as home_screen: claim all
                                    // touch gestures eagerly so the parent
                                    // SingleChildScrollView doesn't steal
                                    // pinch-out and break zoom-out.
                                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                                      Factory<EagerGestureRecognizer>(
                                        () => EagerGestureRecognizer(),
                                      ),
                                    },
                                  )),
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
                        label: 'Open map', // native mode now opens a native full-screen
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
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: const <BoxShadow>[
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
                        // Persistent address card — sits DIRECTLY below the
                        // map (first child of the scroll area) so the user
                        // sees the resolved street address without having
                        // to scroll past metrics. Uses the same
                        // LiveAddressText coord-keyed cache as the list +
                        // map popup so the rendered string is identical
                        // across all three surfaces.
                        if (vehicle.hasLiveLocation) ...<Widget>[
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                                width: 1,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue
                                            .withValues(alpha: 0.10),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        LucideIcons.mapPin,
                                        size: 16,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'CURRENT LOCATION',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.6,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () =>
                                          _showFullAddressModal(vehicle),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          LucideIcons.maximize2,
                                          size: 14,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LiveAddressText(
                                  latitude: vehicle.latitude,
                                  longitude: vehicle.longitude,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: <Widget>[
                                    Icon(
                                      LucideIcons.clock,
                                      size: 13,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        vehicle.createdAt.isNotEmpty
                                            ? 'Last updated: ${vehicle.createdAt}'
                                            : 'Last updated: —',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: vehicle.isMoving
                                            ? AppTheme.primaryGreen
                                                .withValues(alpha: 0.12)
                                            : (vehicle.isIdle
                                                ? Colors.orange
                                                    .withValues(alpha: 0.12)
                                                : Colors.red
                                                    .withValues(alpha: 0.10)),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        vehicle.statusLabel.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                          color: vehicle.isMoving
                                              ? AppTheme.primaryGreen
                                              : (vehicle.isIdle
                                                  ? Colors.orange.shade800
                                                  : Colors.red.shade700),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppTheme.primaryBlue.withValues(
                                alpha: 0.1,
                              ),
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
                                    // Show the plan expiry here (customer-facing)
                                    // instead of the technical device IMEI — red
                                    // once the plan has expired.
                                    'Plan expiry: ${_formatExpiry(vehicle)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: vehicle.isExpired
                                          ? Colors.red.shade600
                                          : Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Status badge removed here — the address card
                            // directly above already shows the live status
                            // pill (MOVING/IDLE/STOPPED). Two badges on
                            // one screen looked unprofessional.
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: _buildMetricBox(LucideIcons.gauge, '${vehicle.speed.round()}', 'km/h', 'Speed', Colors.green)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildMetricBox(LucideIcons.battery, '${vehicle.battery}', '%', 'Battery', Colors.blue)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildMetricBox(LucideIcons.power, vehicle.engineOn ? 'ON' : 'OFF', '', 'Engine', vehicle.engineOn ? Colors.green : Colors.red)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildMetricBox(LucideIcons.bell, settings.notificationEnabled == 1 ? 'ON' : 'OFF', '', 'Alerts', settings.notificationEnabled == 1 ? Colors.green : Colors.grey)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildMetricBox(LucideIcons.shieldCheck, settings.guardActive == 1 ? 'ON' : 'OFF', '', 'Guard', settings.guardActive == 1 ? Colors.orange : Colors.grey)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildMetricBox(LucideIcons.mapPin, vehicle.hasLiveLocation ? 'LIVE' : 'FIX', '', 'GPS', vehicle.hasLiveLocation ? Colors.green : Colors.red)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Protocol-level live data surfaced from the device
                        // heartbeat: GSM signal (0-4), GPS satellites locked
                        // (typically 4-12 at a solid fix), and total
                        // odometer. These were captured in
                        // tbl_device_last_location but invisible in the app
                        // — operators were guessing why "no live update"
                        // was happening (weak cell? no GPS lock?). Now
                        // diagnostic at a glance.
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _buildMetricBox(
                                LucideIcons.wifi,
                                _gsmBarsLabel(vehicle.gsmSignal),
                                '/4',
                                'Signal',
                                _gsmColor(vehicle.gsmSignal),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricBox(
                                LucideIcons.satellite,
                                vehicle.satellites > 0
                                    ? '${vehicle.satellites}'
                                    : '—',
                                'sats',
                                'GPS Lock',
                                vehicle.satellites >= 5
                                    ? Colors.green
                                    : (vehicle.satellites >= 3
                                        ? Colors.orange
                                        : Colors.red),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricBox(
                                LucideIcons.activity,
                                vehicle.currentOdometer > 0
                                    ? vehicle.currentOdometer
                                        .toStringAsFixed(0)
                                    : '0',
                                'km',
                                'Odometer',
                                Colors.purple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildVehicleMetaCard(vehicle),
                        const SizedBox(height: 16),
                        _buildDriverCard(vehicle),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (settings.allowNotifications == 1)
                              _buildFixedActionButton(
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
                            if (settings.allowParkingGuard == 1)
                              _buildFixedActionButton(
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
                            if (settings.allowEngineControl == 1 &&
                                settings.engineCutoff == 1)
                              _buildFixedActionButton(
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
                            if (settings.allowEngineControl == 1 &&
                                settings.engineCutoff == 1)
                              _buildFixedActionButton(
                                icon: LucideIcons.info,
                                label: vehicle.isImmobilizerBusy
                                    ? 'Pending'
                                    : vehicle.immobilizerState
                                          .split('_')[0]
                                          .toUpperCase(),
                                color: vehicle.isImmobilizerBusy
                                    ? Colors.orange
                                    : AppTheme.primaryBlue,
                                onTap: null,
                              ),
                            if (settings.allowHistory == 1)
                              _buildFixedActionButton(
                                icon: LucideIcons.history,
                                label: 'History',
                                color: AppTheme.primaryBlue,
                                onTap: () => _openHistory(vehicle),
                              ),
                            _buildFixedActionButton(
                              icon: LucideIcons.navigation,
                              label: 'Find Car',
                              color: AppTheme.primaryBlue,
                              onTap: () => _findMyCar(vehicle),
                            ),
                            _buildFixedActionButton(
                              icon: LucideIcons.fuel,
                              label: 'Nearby',
                              color: AppTheme.primaryGreen,
                              onTap: () => _openNearbyPois(vehicle),
                            ),
                            _buildFixedActionButton(
                              icon: LucideIcons.gauge,
                              label: 'Score',
                              color: AppTheme.primaryGreen,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DrivingScoreScreen(vehicle: vehicle),
                                ),
                              ),
                            ),
                            if (settings.allowConfig == 1)
                              _buildFixedActionButton(
                                icon: LucideIcons.settings,
                                label: 'Config',
                                color: Colors.grey.shade700,
                                onTap: () => _showConfigModal(vehicle),
                              ),
                            if (settings.allowDriverSessions == 1)
                              _buildFixedActionButton(
                                icon: LucideIcons.badgeCheck,
                                label: 'Driver',
                                color: AppTheme.primaryBlue,
                                onTap: _isSessionBusy
                                    ? null
                                    : () =>
                                          _showDriverSessionSheet(vehicle),
                              ),
                            if (settings.allowDocuments == 1)
                              _buildFixedActionButton(
                                icon: LucideIcons.folderOpen,
                                label: 'Documents',
                                color: Colors.deepPurple,
                                onTap: () => _openDocuments(vehicle),
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
                        const SizedBox(height: 40),
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
        color: Theme.of(context).cardColor,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
                      ? activeDriver.identificationMethod.toUpperCase()
                      : 'MANUAL',
                ),
                _driverChip(
                  icon: LucideIcons.hash,
                  label: activeDriver.driverCode.isNotEmpty
                      ? activeDriver.driverCode
                      : 'No code',
                ),
                _driverChip(
                  icon: LucideIcons.clock3,
                  label: _formatUpdatedAt(activeDriver.identifiedAt),
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
                  icon: Icon(LucideIcons.list),
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
                          hasActiveDriver
                              ? LucideIcons.logOut
                              : LucideIcons.playCircle,
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

  /// GT06/PT06 reports CSQ on a 0-4 scale (0 = no signal, 4 = excellent).
  /// Render as bars for the diagnostic tile.
  String _gsmBarsLabel(int gsm) {
    if (gsm <= 0) return '0';
    if (gsm >= 4) return '4';
    return gsm.toString();
  }

  Color _gsmColor(int gsm) {
    if (gsm >= 3) return Colors.green;
    if (gsm == 2) return Colors.orange;
    return Colors.red;
  }

  Widget _buildMetricBox(IconData icon, String val, String unit, String label, Color color) {
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white10
              : const Color(0xFFF1F4F8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  val,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 1),
                Text(unit, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey)),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 7.5, color: Colors.grey.shade500, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;
    final baseColor = isDisabled ? Colors.grey : color;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate width to fit 3 items per row using the actual available
        // width (LayoutBuilder constraints) rather than the full screen, so
        // the buttons can't overflow the panel. Matches the parent Wrap
        // spacing of 10px (two gaps between three items).
        const spacing = 10.0;
        final itemWidth = (constraints.maxWidth - 2 * spacing) / 3;

        return Container(
          width: itemWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              if (!isDisabled)
                BoxShadow(
                  color: color.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Material(
            color: isDisabled
                ? Theme.of(context).scaffoldBackgroundColor
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(15),
            elevation: isDisabled ? 0 : 0.5,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isDisabled ? Colors.transparent : color.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: baseColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 18, color: baseColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isDisabled
                            ? Colors.grey.shade600
                            : Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleMetaCard(VehicleRecord vehicle) {
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
          Text('Vehicle Overview', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12) / 2;
              final tiles = <Widget>[
                SizedBox(width: itemWidth, child: _buildDetailTile(icon: LucideIcons.badgeCheck, label: 'Reg. Number', value: vehicle.registrationNumber)),
                SizedBox(width: itemWidth, child: _buildDetailTile(icon: LucideIcons.car, label: 'Vehicle Name', value: vehicle.name)),
                SizedBox(width: itemWidth, child: _buildDetailTile(icon: LucideIcons.layers, label: 'Type', value: vehicle.typeName)),
                SizedBox(width: itemWidth, child: _buildDetailTile(icon: LucideIcons.cpu, label: 'Model', value: vehicle.model)),
                SizedBox(width: itemWidth, child: _buildDetailTile(icon: LucideIcons.info, label: 'Device ID', value: vehicle.imei)),
                SizedBox(width: itemWidth, child: _buildDetailTile(icon: LucideIcons.gauge, label: 'Speed Limit', value: '${vehicle.overspeedLimit} km/h')),
                SizedBox(width: itemWidth, child: _buildDetailTile(icon: LucideIcons.shieldAlert, label: 'Radius Alert', value: '${vehicle.geofenceRadius} m')),
                SizedBox(width: itemWidth, child: _buildDetailTile(icon: LucideIcons.history, label: 'Odometer', value: '${(vehicle.currentOdometer > 0 ? vehicle.currentOdometer : 0).toStringAsFixed(0)} km')),
              ];

              if (vehicle.showEngineRpm == 1 && vehicle.engineRpm > 0) {
                tiles.add(
                  SizedBox(width: itemWidth, child: _buildDetailTile(icon: LucideIcons.gauge, label: 'Engine RPM', value: vehicle.engineRpm.toStringAsFixed(0))),
                );
              }
              if (vehicle.showBatteryVoltage == 1 && vehicle.batteryVoltage > 0) {
                tiles.add(
                  SizedBox(width: itemWidth, child: _buildDetailTile(icon: LucideIcons.batteryCharging, label: 'Battery Voltage', value: '${vehicle.batteryVoltage.toStringAsFixed(1)} V')),
                );
              }
              return Wrap(spacing: 12, runSpacing: 12, children: tiles);
            },
          ),
        ],
      ),
    );
  }

  /// Human-readable plan-expiry date for the overview tile, e.g. "06 Jul 2027".
  /// Appends " · Expired" / " · N days left" so the customer sees the status at
  /// a glance; "--" when the device has no expiry set.
  String _formatExpiry(VehicleRecord vehicle) {
    final d = vehicle.expiryDateValue;
    if (d == null) return '--';
    const months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final date = '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
    final label = vehicle.expiryBadgeLabel; // 'Expired' / 'Expires today' / 'N days left' / ''
    return label.isEmpty ? date : '$date · $label';
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w700)),
                Text(value.isEmpty ? '--' : value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 11, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
              ],
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
              Icon(icon, size: 15, color: AppTheme.primaryBlue),
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

  Widget _buildMapInfoChip({required IconData icon, required String label}) {
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
    this.vehicle,
  });

  final String title;
  final String url;

  /// When provided, a compact frosted-glass info bar is overlaid at the
  /// bottom of the map showing the vehicle's live details (reg-no, status,
  /// speed, address, last-updated). Optional so existing call sites that
  /// only pass title + url keep working unchanged.
  final VehicleRecord? vehicle;

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
    final VehicleRecord? vehicle = widget.vehicle;
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
          if (vehicle != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: _GlassVehicleBar(vehicle: vehicle),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact, professional frosted-glass "mirror" bar overlaid at the bottom of
/// the full-screen live map. Shows the vehicle's registration, live status
/// pill + speed, single-line address and last-updated time. Sits at the very
/// bottom so the map stays interactive above it.
/// Full-screen NATIVE live map — the map-mode-consistent counterpart of
/// VehicleLiveMapScreen (which is a WebView). Rides SingleTrackCubit for live
/// positions (SSE + its own silent fallback poll), grows a session trail, and
/// reuses the frosted glass bar with the speed shown (no webmap gauge here).
class NativeLiveMapScreen extends StatefulWidget {
  const NativeLiveMapScreen({super.key, required this.title});

  final String title;

  @override
  State<NativeLiveMapScreen> createState() => _NativeLiveMapScreenState();
}

class _NativeLiveMapScreenState extends State<NativeLiveMapScreen> {
  // Own fallback poll: this screen can be pushed straight from home (no
  // detail screen underneath running its timer). silentRefreshIfStale
  // dedups against SSE, so double-timers never double-fetch.
  // Lifecycle-aware poll (see _VehicleDetailScreenState._nativeRefresh).
  late final LifecycleRefresh _refresh = LifecycleRefresh(
    interval: const Duration(seconds: 5),
    onRefresh: () async {
      if (!mounted) return;
      await context.read<SingleTrackCubit>().silentRefreshIfStale();
    },
  );
  final List<LatLng> _liveTrail = <LatLng>[];
  // Guards the trail against the app-scoped cubit's PREVIOUS vehicle: opening
  // vehicle B after viewing A briefly renders A's model, and without this the
  // trail drew a stray straight line from A's position to B's (same guard as
  // _growLiveTrail on the detail screen).
  int _trailVehicleId = 0;

  @override
  void initState() {
    super.initState();
    _refresh.start();
  }

  @override
  void dispose() {
    _refresh.dispose();
    super.dispose();
  }

  void _growTrail(VehicleRecord vehicle) {
    if (vehicle.latitude == 0 && vehicle.longitude == 0) return;
    if (_trailVehicleId != vehicle.id) {
      _liveTrail.clear();
      _trailVehicleId = vehicle.id;
    }
    final next = LatLng(vehicle.latitude, vehicle.longitude);
    if (_liveTrail.isNotEmpty) {
      final meters = const Distance().as(LengthUnit.Meter, _liveTrail.last, next);
      if (meters < 5) return;
    }
    _liveTrail.add(next);
    if (_liveTrail.length > 300) _liveTrail.removeAt(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: BlocBuilder<SingleTrackCubit, SingleTrackState>(
        builder: (context, state) {
          final vehicle = state.singleTrackModel?.data;
          if (vehicle == null) {
            return const Center(child: CircularProgressIndicator());
          }
          _growTrail(vehicle);
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: NativeVehicleMap(
                  vehicles: <VehicleRecord>[vehicle],
                  focusVehicle: vehicle,
                  trailPoints: _liveTrail,
                  followFocusedVehicle: true,
                  moveAnimationDuration: const Duration(milliseconds: 2500),
                  emptyTitle: vehicle.hasLiveLocation
                      ? 'Map data not available'
                      : 'No live location yet',
                  emptySubtitle: 'Waiting for the vehicle to report',
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _GlassVehicleBar(vehicle: vehicle, showSpeed: true),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlassVehicleBar extends StatelessWidget {
  const _GlassVehicleBar({required this.vehicle, this.showSpeed = false});

  final VehicleRecord vehicle;

  /// True on the NATIVE full-screen map, which has no webmap speed gauge —
  /// the bar carries the live speed there (webview mode keeps it hidden
  /// because the page's own gauge already shows it).
  final bool showSpeed;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color statusColor = vehicle.isMoving
        ? const Color(0xFF22C55E)
        : (vehicle.isIdle ? Colors.orange : Colors.red);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF141A22);
    final Color subtitleColor =
        isDark ? Colors.white60 : Colors.black.withValues(alpha: 0.55);
    final Color bodyColor =
        isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.72);
    final Color fillColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.72);
    final Color hairline = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.85);

    final String reg = vehicle.registrationNumber.isNotEmpty
        ? vehicle.registrationNumber
        : vehicle.name;
    final bool showName =
        vehicle.name.isNotEmpty && vehicle.name != reg;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.28,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: const BorderRadius.all(Radius.circular(22)),
                border: Border.all(color: hairline, width: 0.8),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Drag handle.
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  // Line 1: reg-no + (name) on the left, status pill + speed
                  // aligned right.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              reg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                letterSpacing: 0.2,
                                color: titleColor,
                              ),
                            ),
                            if (showName) ...<Widget>[
                              const SizedBox(height: 1),
                              Text(
                                vehicle.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Webview mode: speed omitted (the page's gauge shows it).
                      // Native full-screen: no gauge exists, so show it here.
                      if (showSpeed) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${vehicle.speed.round()} km/h',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _StatusPill(color: statusColor, label: vehicle.statusLabel),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Line 2: single-line address.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Icon(LucideIcons.mapPin, size: 15, color: statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LiveAddressText(
                          latitude: vehicle.latitude,
                          longitude: vehicle.longitude,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: bodyColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Line 3: last-updated time.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Icon(LucideIcons.clock, size: 13, color: subtitleColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Updated: ${vehicle.createdAt.isNotEmpty ? vehicle.createdAt : '—'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: subtitleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
