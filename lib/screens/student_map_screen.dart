import 'dart:async';

import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/cubits/alerts_cubit/alerts_cubit.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_cubit.dart';
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_cubit.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_cubit.dart';
import 'package:fleet_monitor/models/route_stop_model.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/repositorys/single_track_repository.dart';
import 'package:fleet_monitor/repositorys/vehicle_repository.dart';
import 'package:fleet_monitor/screens/login_screen.dart';
import 'package:fleet_monitor/screens/profile_screen.dart';
import 'package:fleet_monitor/widgets/native_vehicle_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Locked single-map home for a "student" sub-user. Shows ONLY the live map of
/// the vehicle assigned to this sub-user — no drawer, no bottom nav, no
/// details. Profile + Logout are the only affordances (per owner spec).
///
/// Map source mirrors the single-vehicle view exactly: it loads the vehicle's
/// live web-map URL (`primaryMapUrl` = the server's tracking_url) in a WebView,
/// which self-refreshes over its own SSE — the same live map used elsewhere in
/// the app. The URL is built server-side per the superadmin map settings, so
/// any map-change (provider / native-vs-url) is honoured automatically. If no
/// web URL is available it falls back to the in-app native map.
class StudentMapScreen extends StatefulWidget {
  const StudentMapScreen({super.key});

  static const String routeName = '/student-map';

  @override
  State<StudentMapScreen> createState() => _StudentMapScreenState();
}

class _StudentMapScreenState extends State<StudentMapScreen> {
  final VehicleRepository _vehicleRepository = VehicleRepository();
  final SingleTrackRepository _trackRepository = SingleTrackRepository();

  VehicleRecord? _vehicle;
  WebViewController? _webController;
  bool _loading = true;
  bool _webLoading = true;
  bool _loggingOut = false;

  // ── "My Stop" / ETA — floating control on the map edge ────────────────────
  // Same storage keys as the single-vehicle screen (my_stop_<vehicle.id>), so
  // a choice made on either screen is the same choice: it belongs to THIS
  // PHONE, and the bus-is-near subscription is keyed server-side by this
  // phone's FCM token. Nothing per-parent touches the shared account.
  List<RouteStop> _routeStops = <RouteStop>[];
  int? _myStopId;
  bool _myStopAlert = false;
  StopEta? _stopEta;
  Timer? _etaTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _etaTimer?.cancel();
    super.dispose();
  }

  /// One-shot fetch of the sub-user's assigned vehicle, then load its live
  /// web-map once. No polling: the web map keeps itself live via its own SSE
  /// (matching the single-vehicle screen), and the tracking URL's encrypted
  /// IMEI churns every poll — reloading it would restart the map needlessly.
  Future<void> _load() async {
    try {
      final result = await _vehicleRepository.fetchVehicles();
      if (!mounted) return;
      final VehicleRecord? v =
          result.data.isNotEmpty ? result.data.first : null;
      setState(() {
        _vehicle = v;
        _loading = false;
      });
      if (v == null) return;

      // Same URL resolution as the single-vehicle live view: prefer the
      // tracking_url web map, fall back to the Google tracking URL.
      final String url =
          v.primaryMapUrl.isNotEmpty ? v.primaryMapUrl : v.googleTrackingUrl;
      final Uri? parsed = url.isEmpty ? null : Uri.tryParse(url);
      if (parsed == null) return; // no web URL → native fallback in build()

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) setState(() => _webLoading = true);
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _webLoading = false);
            },
          ),
        )
        ..loadRequest(parsed);
      if (!mounted) return;
      setState(() => _webController = controller);
      _ensureMyStopLoaded(v);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Load stops + this phone's saved choice. Failures leave the control
  /// hidden — the map must keep working against a server without route stops.
  Future<void> _ensureMyStopLoaded(VehicleRecord vehicle) async {
    if (vehicle.imei.isEmpty) return;
    try {
      final stops = await _trackRepository.fetchRouteStops(vehicle.imei);
      final savedId = await LocalStorage.readValue('my_stop_${vehicle.id}');
      final savedAlert =
          await LocalStorage.readValue('my_stop_alert_${vehicle.id}');
      if (!mounted) return;
      setState(() {
        _routeStops = stops;
        _myStopId = int.tryParse(savedId ?? '');
        if (_myStopId != null && !stops.any((s) => s.id == _myStopId)) {
          _myStopId = null; // the school deleted that stop
        }
        _myStopAlert = savedAlert == '1' && _myStopId != null;
      });
      _restartEtaPolling();
    } catch (_) {
      // Older server / offline: no stops, no control, no breakage.
    }
  }

  void _restartEtaPolling() {
    _etaTimer?.cancel();
    _etaTimer = null;
    if (_myStopId == null || (_vehicle?.imei.isEmpty ?? true)) {
      if (mounted) setState(() => _stopEta = null);
      return;
    }
    _refreshStopEta();
    // 45 s cadence, same as the tracking screen: the answer is a median over
    // past days — it moves slowly, and the server does real work per call.
    _etaTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _refreshStopEta(),
    );
  }

  Future<void> _refreshStopEta() async {
    final stopId = _myStopId;
    final imei = _vehicle?.imei ?? '';
    if (stopId == null || imei.isEmpty || !mounted) return;
    try {
      final eta = await _trackRepository.fetchStopEta(imei, stopId);
      if (!mounted || _myStopId != stopId) return;
      setState(() => _stopEta = eta);
    } catch (_) {
      // Keep the previous reading; a stale chip beats a spinner storm.
    }
  }

  Future<void> _saveMyStop(
      VehicleRecord vehicle, int? stopId, bool alert) async {
    final previousStop = _myStopId;
    final previousAlert = _myStopAlert;

    setState(() {
      _myStopId = stopId;
      _myStopAlert = stopId != null && alert;
      _stopEta = null;
    });
    await LocalStorage.setValue(
        'my_stop_${vehicle.id}', stopId?.toString() ?? '');
    await LocalStorage.setValue(
        'my_stop_alert_${vehicle.id}', (stopId != null && alert) ? '1' : '0');
    _restartEtaPolling();

    // Server-side subscription follows the choice, best-effort: the ETA chip
    // works without it, and a failed toggle must not lose the stop choice.
    try {
      if (previousStop != null &&
          previousAlert &&
          (stopId != previousStop || !alert)) {
        await _trackRepository.setStopAlert(
            imei: vehicle.imei, stopId: previousStop, enable: false);
      }
      if (stopId != null && alert) {
        await _trackRepository.setStopAlert(
            imei: vehicle.imei, stopId: stopId, enable: true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stop alert: ${error.toString()}')),
      );
    }
  }

  void _showMyStopPicker(VehicleRecord vehicle) {
    final sorted = List<RouteStop>.from(_routeStops)
      ..sort((a, b) =>
          a.seq != b.seq ? a.seq.compareTo(b.seq) : a.id.compareTo(b.id));
    int? pickedId = _myStopId;
    bool alertOn = _myStopAlert;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Choose your stop',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Saved on this phone only — every parent picks their own.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    RadioListTile<int?>(
                      dense: true,
                      value: null,
                      groupValue: pickedId,
                      title: const Text('No stop (hide ETA)'),
                      onChanged: (v) => setSheetState(() {
                        pickedId = null;
                        alertOn = false;
                      }),
                    ),
                    ...sorted.map(
                      (s) => RadioListTile<int?>(
                        dense: true,
                        value: s.id,
                        groupValue: pickedId,
                        title: Text(s.displayName),
                        onChanged: (v) => setSheetState(() => pickedId = v),
                      ),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: alertOn && pickedId != null,
                onChanged: pickedId == null
                    ? null
                    : (v) => setSheetState(() => alertOn = v),
                title: const Text(
                  'Notify me when the bus is near',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Only this phone gets the alert',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _saveMyStop(vehicle, pickedId, alertOn);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProfileScreen(isStudent: true),
      ),
    );
  }

  /// Same teardown as the shared drawer's logout: reset every root-scoped data
  /// cubit + stop streams BEFORE clearing the session, so the next user never
  /// sees stale data on first paint.
  Future<void> _logout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    final vehicleCubit = context.read<VehicleCubit>();
    final trackCubit = context.read<SingleTrackCubit>();
    final homeCubit = context.read<HomeCubit>();
    final alertsCubit = context.read<AlertsCubit>();
    final profileCubit = context.read<ProfileCubit>();
    final authCubit = context.read<AuthCubit>();
    await vehicleCubit.reset();
    await trackCubit.reset();
    homeCubit.reset();
    alertsCubit.reset();
    profileCubit.reset();
    await authCubit.signOut();
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.pushReplacementNamed(context, LoginScreen.routeName);
  }

  Widget _buildMap() {
    // 1) Live web map (preferred — same as the single-vehicle view).
    if (_webController != null) {
      return Stack(
        children: <Widget>[
          Positioned.fill(child: WebViewWidget(controller: _webController!)),
          if (_webLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    // 2) Still loading the vehicle list.
    if (_loading && _vehicle == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // 3) Have a vehicle but no web URL → in-app native map fallback.
    if (_vehicle != null) {
      return NativeVehicleMap(
        vehicles: <VehicleRecord>[_vehicle!],
        focusVehicle: _vehicle,
        followFocusedVehicle: true,
        emptyTitle: 'No live location yet',
        emptySubtitle: 'The tracking map will appear once your vehicle reports.',
        onVehicleTap: (_) {},
      );
    }
    // 4) No vehicle assigned.
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No vehicle assigned yet.\nThe tracking map will appear once your vehicle is linked.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Floating "My Stop" control on the map's right edge — the same visual
  /// language as a web map's side controls (round white card, soft shadow).
  /// Before a stop is chosen it is a compact round button; once chosen it
  /// grows into a pill carrying the live ETA, so the answer a parent opens
  /// the app for sits right on the map.
  Widget _buildMyStopControl(VehicleRecord vehicle) {
    final RouteStop? chosen = _myStopId == null
        ? null
        : _routeStops.where((s) => s.id == _myStopId).firstOrNull;

    if (chosen == null) {
      return Material(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black38,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _showMyStopPicker(vehicle),
          child: const Padding(
            padding: EdgeInsets.all(13),
            child: Icon(
              LucideIcons.mapPin,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
          ),
        ),
      );
    }

    String etaBig;
    String etaSmall;
    if (_stopEta?.hasEta == true) {
      final min = _stopEta!.etaMinutes!;
      etaBig = min <= 1 ? 'Now' : '$min min';
      etaSmall = chosen.displayName;
    } else if (_stopEta != null && _stopEta!.reason == 'no_position') {
      etaBig = '—';
      etaSmall = 'Bus offline';
    } else if (_stopEta != null) {
      etaBig = '—';
      etaSmall = 'ETA soon';
    } else {
      etaBig = '…';
      etaSmall = chosen.displayName;
    }

    return Material(
      color: Theme.of(context).cardTheme.color ?? Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      shadowColor: Colors.black38,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showMyStopPicker(vehicle),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 132),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    LucideIcons.mapPin,
                    color: AppTheme.primaryGreen,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      etaBig,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _stopEta?.hasEta == true
                            ? AppTheme.primaryGreen
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    _myStopAlert ? LucideIcons.bellRing : LucideIcons.bellOff,
                    size: 13,
                    color: _myStopAlert
                        ? AppTheme.primaryGreen
                        : Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                etaSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = _vehicle?.displayName ?? 'Live Location';
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: _buildMap()),
            // "My Stop" / ETA — pinned to the map's right edge like a map
            // side-control, clear of the header above. Hidden until the
            // school has defined stops for this vehicle.
            if (_vehicle != null && _routeStops.isNotEmpty)
              Positioned(
                right: 12,
                top: 96,
                child: _buildMyStopControl(_vehicle!),
              ),
            // Solid top header — taller and flush to the top edge so it covers
            // the web map's own controls (follow / layer buttons) that a
            // student sub-user shouldn't see. Vehicle name + profile + logout.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(LucideIcons.mapPin,
                        size: 20, color: Color(0xFF4A688A)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Profile',
                      icon: const Icon(LucideIcons.user, size: 22),
                      onPressed: _openProfile,
                    ),
                    IconButton(
                      tooltip: 'Logout',
                      icon: const Icon(LucideIcons.logOut, size: 22),
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
