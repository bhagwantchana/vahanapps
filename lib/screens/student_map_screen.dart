import 'package:fleet_monitor/cubits/alerts_cubit/alerts_cubit.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_cubit.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_cubit.dart';
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_cubit.dart';
import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_cubit.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
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

  VehicleRecord? _vehicle;
  WebViewController? _webController;
  bool _loading = true;
  bool _webLoading = true;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _load();
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final String title = _vehicle?.displayName ?? 'Live Location';
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: _buildMap()),
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
