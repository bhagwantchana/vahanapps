import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_cubit.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_state.dart';
import 'package:fleet_monitor/gen/assets.gen.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:fleet_monitor/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WebViewController? _controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    final homeCubit = context.read<HomeCubit>();
    if (homeCubit.state is! HomeLoggedInState) {
      homeCubit.fetchHomeData();
    }
  }

  /// ================== STATS ==================
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

  /// ================== INIT ==================
  void _initWebView(String url) {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() => isLoading = true);
          },
          onPageFinished: (_) {
            setState(() => isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Image.asset(Assets.images.mylogo.path, height: 30),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                Icon(LucideIcons.bell),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {},
          ),
        ],
      ),
      drawer: AppDrawer(),
      body: BlocConsumer<HomeCubit, HomeState>(
        listener: (context, state) {},
        builder: (context, state) {
          if (state is HomeLoadingState) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is HomeErrorState) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.alertTriangle, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  CustomText(text: state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<HomeCubit>().fetchHomeData(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final vehicleArray = state.dashboardModel?.data?.vehicleList ?? [];
          final dashBoardMap =
              state.dashboardModel?.data?.mapsUrl ??
              "https://fleetmonitor360.cloud/";

          if (vehicleArray.isEmpty) {
            return const Center(child: CustomText(text: 'No vehicles found'));
          }

          /// Load first vehicle tracking URL
          // final trackingUrl = vehicleArray.first.trackingUrl ?? "";
          final trackingUrl = dashBoardMap;

          /// Init WebView once
          if (_controller == null) {
            _initWebView(trackingUrl);
          }

          final stats = calculateStats(vehicleArray);

          return Column(
            children: [
              /// ================== WEBVIEW MAP ==================
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
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

              /// ================== STATS ==================
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.8,
                    physics: const NeverScrollableScrollPhysics(),

                    children: [
                      _buildStatCard(
                        'Total Vehicles',
                        stats["total"]!,
                        AppTheme.primaryBlue,
                        LucideIcons.truck,
                      ),

                      _buildStatCard(
                        'Active Devices',
                        stats["running"]! + stats["idle"]!,
                        AppTheme.primaryGreen,
                        LucideIcons.radioReceiver,
                      ),

                      _buildStatCard(
                        'Running',
                        stats["running"]!,
                        const Color(0xFF67A836),
                        LucideIcons.playCircle,
                      ),

                      _buildStatCard(
                        'Idle',
                        stats["idle"]!,
                        Colors.orange,
                        LucideIcons.pauseCircle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// ================== STAT CARD ==================
  Widget _buildStatCard(String title, int value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
