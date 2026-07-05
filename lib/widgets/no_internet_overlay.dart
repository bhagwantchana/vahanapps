import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';
import 'package:fleet_monitor/services/connectivity_service.dart';
import 'package:flutter/material.dart';

/// Wraps the whole app (via `MaterialApp.builder`) and paints a full-screen
/// "No internet connection" state on top whenever connectivity is lost. It
/// auto-dismisses when the connection is restored. Reuses the app's existing
/// empty-state visual language (centred icon → title → message → action) so it
/// introduces no new design pattern.
class NoInternetOverlay extends StatelessWidget {
  const NoInternetOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnline,
      builder: (context, online, _) {
        return Stack(
          children: <Widget>[
            child,
            if (!online) const Positioned.fill(child: _NoInternetScreen()),
          ],
        );
      },
    );
  }
}

class _NoInternetScreen extends StatelessWidget {
  const _NoInternetScreen();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final AppStrings strings = AppStrings.of(context);
    final Color bg = isDark ? AppTheme.darkBackground : AppTheme.background;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color bodyColor = isDark ? Colors.white70 : Colors.black54;

    // A Material so the overlay is opaque and absorbs taps — a true "screen",
    // not a translucent banner.
    return Material(
      color: bg,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.redLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    size: 44,
                    color: AppColors.red,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  strings.t('no_internet_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  strings.t('no_internet_message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.4, color: bodyColor),
                ),
                const SizedBox(height: 28),
                _RetryButton(label: strings.t('retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.label});

  final String label;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _busy = false;

  Future<void> _onPressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ConnectivityService.instance.retry();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _busy ? null : _onPressed,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.refresh_rounded, size: 18),
      label: Text(widget.label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
