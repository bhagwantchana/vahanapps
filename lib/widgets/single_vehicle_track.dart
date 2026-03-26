import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_cubit.dart';
import 'package:fleet_monitor/cubits/single_track_cubit/single_track_state.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({super.key});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  WebViewController? _controller;
  bool isLoading = true;
  bool isEngineStart = false;
  bool isGaurdModeActive = false;

  Map<String, int> calculateStats(List data) {
    int running = 0;
    int idle = 0;
    int stopped = 0;

    for (var v in data) {
      int tripId = int.tryParse(v.lastTripId ?? "0") ?? 0;
      int finished = int.tryParse(v.lastTripFinished ?? "0") ?? 0;
      int speed = int.tryParse(v.lastSpeed ?? "0") ?? 0;

      if (tripId == 0 || finished == 1) {
        stopped++;
      } else if (tripId > 0 && finished == 0) {
        if (speed > 0) {
          running++;
        } else {
          idle++;
        }
      }
    }

    return {
      "running": running,
      "idle": idle,
      "stopped": stopped,
      "total": data.length,
    };
  }

  void _initWebView(String url) {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => isLoading = true),
          onPageFinished: (_) => setState(() => isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const CustomText(text: "Vehicle Detail")),

      body: BlocBuilder<SingleTrackCubit, SingleTrackState>(
        builder: (context, state) {
          if (state is SingleTrackLoadingState) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = state.singleTrackModel?.data;

          if (data == null) {
            return const Center(child: CustomText(text: 'No Data'));
          }

          final trackingUrl = data.trackingUrl ?? "";
          bool engineOn = (int.tryParse(data.lastSpeed ?? "0") ?? 0) > 0;

          if (_controller == null && trackingUrl.isNotEmpty) {
            _initWebView(trackingUrl);
          }

          return Column(
            children: [
              /// 🔥 MAP WEBVIEW
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 10),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _controller == null
                          ? const Center(child: CircularProgressIndicator())
                          : WebViewWidget(controller: _controller!),
                    ),

                    if (isLoading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),

              /// 🔻 BOTTOM PANEL
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
                    boxShadow: [
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
                      children: [
                        // Driver and Basic Info
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppTheme.primaryBlue.withOpacity(
                                0.1,
                              ),
                              child: const Icon(
                                LucideIcons.user,
                                size: 28,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.vRegistrationNo ?? "Unknown",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "+91 9803171511",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (engineOn
                                            ? AppTheme.primaryGreen
                                            : Colors.red)
                                        .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                engineOn
                                    ? "Running"
                                    : "Stopped", // FIXED: Removed "data.status" hardcoded string
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: engineOn
                                      ? AppTheme.primaryGreen
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Grid of Stats
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    'Speed',
                                    '${data.lastSpeed ?? 0} km/h',
                                  ),
                                  _buildStatDivider(),
                                  _buildStatItem('Fuel', '47 %'),
                                  _buildStatDivider(),
                                  _buildStatItem(
                                    'Engine',
                                    engineOn ? 'ON' : 'OFF',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem('Signal', 'Good'),
                                  _buildStatDivider(),
                                  _buildStatItem('Updated', "13:55"),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                icon: isEngineStart
                                    ? LucideIcons.powerOff
                                    : LucideIcons.power,
                                label: isEngineStart
                                    ? 'Stop Engine'
                                    : 'Start Engine',
                                color: isEngineStart
                                    ? Colors.red
                                    : AppTheme.primaryGreen,
                                onTap: () {
                                  _confirmEngineToggle(context);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                icon: LucideIcons.shieldAlert,
                                label: isGaurdModeActive
                                    ? 'Guard Active'
                                    : 'Guard Off',
                                color: isGaurdModeActive
                                    ? Colors.red
                                    : AppTheme.primaryBlue,
                                onTap: () {
                                  // FIXED: Updated state locally. If you have a Cubit method, call: context.read<SingleTrackCubit>().toggleGuardMode()
                                  setState(() {
                                    isGaurdModeActive = !isGaurdModeActive;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isGaurdModeActive
                                            ? 'Guard Mode Active'
                                            : 'Guard mode disabled',
                                      ),
                                      backgroundColor: AppTheme.primaryBlue,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                icon: LucideIcons.settings,
                                label: 'Config',
                                color: Colors.grey.shade700,
                                onTap: () => _showConfigModal(context),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
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
          style: const TextStyle(
            fontSize: 16,
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmEngineToggle(BuildContext context) {
    // FIXED: Uses local state instead of undefined `vehicle` object
    String action = isEngineStart ? "stop" : "start";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${action == 'stop' ? 'Stop' : 'Start'} Engine?'),
        content: Text('Are you sure you want to $action the engine?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isEngineStart
                  ? Colors.red
                  : AppTheme.primaryGreen,
              elevation: 0,
            ),
            onPressed: () {
              // FIXED: Uses setState. If communicating with API, use: context.read<SingleTrackCubit>().toggleEngine()
              setState(() {
                isEngineStart = !isEngineStart;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Engine ${action == 'stop' ? 'stopped' : 'started'} successfully.',
                  ),
                  backgroundColor: AppTheme.primaryBlue,
                ),
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _showConfigModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 24,
          right: 24,
          top: 24,
        ),
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
          children: [
            const Text(
              'Vehicle Configuration',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              initialValue: '80',
              decoration: const InputDecoration(
                labelText: 'Overspeed Limit (km/h)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: '200',
              decoration: const InputDecoration(
                labelText: 'Geofence Radius (meters)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Configuration saved!'),
                      backgroundColor: AppTheme.primaryGreen,
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
  }
}
