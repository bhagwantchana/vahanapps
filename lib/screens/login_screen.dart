import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_state.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_cubit.dart';
import 'package:fleet_monitor/gen/assets.gen.dart';
import 'package:fleet_monitor/providers/login_provider.dart';
import 'package:fleet_monitor/screens/dashboard.dart';
import 'package:fleet_monitor/services/biometric_auth_service.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const String routeName = 'login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showBiometricButton = false;

  @override
  void initState() {
    super.initState();
    _prepareBiometricState();
  }

  Future<void> _prepareBiometricState() async {
    final token = await LocalStorage.readValue(PreferencesKey.token) ?? '';
    final enabled = await BiometricAuthService.isEnabled();
    final supported = await BiometricAuthService.isSupported();
    if (!mounted) {
      return;
    }
    setState(() {
      _showBiometricButton =
          token.trim().isNotEmpty && enabled && supported;
    });
  }

  Future<void> _promptBiometricEnrollment() async {
    final alreadyEnabled = await BiometricAuthService.isEnabled();
    if (alreadyEnabled) {
      setState(() => _showBiometricButton = true);
      return;
    }

    final supported = await BiometricAuthService.isSupported();
    if (!mounted || !supported) {
      return;
    }

    final enable = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enable biometric login?'),
          content: const Text(
            'Use your phone\'s Face ID / fingerprint to unlock Fleet Monitor next time.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );

    if (enable != true || !mounted) {
      return;
    }

    final authenticated = await BiometricAuthService.authenticate(
      reason: 'Confirm your identity to enable biometric login',
    );
    if (!mounted) {
      return;
    }

    if (authenticated) {
      await BiometricAuthService.setEnabled(true);
      setState(() => _showBiometricButton = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric login enabled')),
      );
    }
  }

  Future<void> _unlockWithBiometrics() async {
    final authenticated = await BiometricAuthService.authenticate(
      reason: 'Unlock Fleet Monitor with system biometrics',
    );
    if (!mounted || !authenticated) {
      return;
    }

    await context.read<ProfileCubit>().fetchProfile();
    if (!mounted) {
      return;
    }
    Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.pushReplacementNamed(context, DashboardScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LoginProvider>(context);

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) async {
        if (state is AuthLoggedInState) {
          await _promptBiometricEnrollment();
          await context.read<ProfileCubit>().fetchProfile();
          if (!context.mounted) {
            return;
          }
          Navigator.popUntil(context, (route) => route.isFirst);
          Navigator.pushReplacementNamed(context, DashboardScreen.routeName);
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(Assets.images.loginBackground.path),
              fit: BoxFit.cover,
            ),
          ),
          child: Scaffold(
            backgroundColor: AppTheme.background.withValues(alpha: 0.9),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth > 420
                        ? 420.0
                        : constraints.maxWidth;

                    return SizedBox(
                      width: cardWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Image.asset(
                            Assets.images.mylogo.path,
                            height: 46,
                            width: 46,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Stay connected to every vehicle',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Form(
                            key: provider.formKey,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 6,
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    TextFormField(
                                      controller: provider.emailController,
                                      validator: provider.validateEmail,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: 'Username, Email or Mobile',
                                        prefixIcon: Icon(
                                          LucideIcons.user,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: provider.passwordController,
                                      validator: provider.validatePassword,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: Icon(
                                          LucideIcons.lock,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    if (provider.error.isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.redLight,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: <Widget>[
                                            const Icon(
                                              Icons.error_outline,
                                              color: AppColors.red,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                provider.error,
                                                style: const TextStyle(
                                                  color: AppColors.red,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 28),
                                    Container(
                                      height: 54,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(
                                            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                        gradient: const LinearGradient(
                                          colors: <Color>[
                                            AppTheme.primaryGreen,
                                            Color(0xFF67A836),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: ElevatedButton(
                                        onPressed: provider.isLoading
                                            ? null
                                            : provider.logIn,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          disabledBackgroundColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: provider.isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                                ),
                                              )
                                            : const CustomText(
                                                text: 'Login ->',
                                                color: AppColors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_showBiometricButton) ...<Widget>[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _unlockWithBiometrics,
                              icon: const Icon(LucideIcons.scanLine),
                              label: const Text('Unlock with biometrics'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
