import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/services/force_update_service.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Terminal screen shown when the server reports the running build is below
/// the configured minimum. There is deliberately no way past it — no back
/// button, no "later", no navigation. The only action is to open the store.
///
/// Android normally never reaches here (Play's immediate in-app update runs
/// first); this is the gate for iOS and side-loaded builds.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.requirement});

  static const String routeName = 'update_required_screen';

  final AppUpdateRequirement requirement;

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.tryParse(requirement.storeUrl);
    if (uri == null || requirement.storeUrl.isEmpty) {
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the store')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = requirement.message.isNotEmpty
        ? requirement.message
        : 'A newer version of VahanConnect is required to continue.';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.arrowUpCircle,
                      size: 56,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Update Required',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (requirement.currentVersion.isNotEmpty &&
                      requirement.minVersion.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      'Installed ${requirement.currentVersion}  •  '
                      'Required ${requirement.minVersion}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openStore(context),
                      icon: const Icon(LucideIcons.download, size: 18),
                      label: const Text('Update Now'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
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
