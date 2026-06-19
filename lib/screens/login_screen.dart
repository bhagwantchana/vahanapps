import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_state.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_cubit.dart';
import 'package:fleet_monitor/gen/assets.gen.dart';
import 'package:fleet_monitor/l10n/app_strings.dart';
import 'package:fleet_monitor/providers/login_provider.dart';
import 'package:fleet_monitor/screens/dashboard.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static const String routeName = "login";
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LoginProvider>(context);
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthLoggedInState) {
          context.read<HomeCubit>().fetchHomeData();
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
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double cardWidth = constraints.maxWidth > 400
                        ? 400
                        : constraints.maxWidth;
                    return SizedBox(
                      width: cardWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo
                          const SizedBox(height: 16),
                          Image.asset(
                            Assets.images.logo.path,
                            height: 48,
                            width: 48,
                          ),
                          const SizedBox(height: 48),
                          // Login Card
                          Form(
                            key: provider.formKey,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: provider.emailController,
                                      validator: provider.validateEmail,
                                      decoration: InputDecoration(
                                        labelText: 'Email or Username',
                                        helperText: 'Either works — primary or sub-user',
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
                                    // "Forgot Password?" removed: no reset flow
                                    // exists yet, so a tappable link with an
                                    // empty onPressed was dead UI. Re-add this
                                    // (with a real handler) once a password
                                    // reset screen/endpoint lands.
                                    // Inline error banner. The AuthCubit
                                    // pushes an AuthErrorState when the API
                                    // returns "wrong username/password" and
                                    // the provider captures the message into
                                    // `provider.error`. Before this banner
                                    // existed, login silently failed — the
                                    // button just snapped back to its idle
                                    // state with no feedback.
                                    if (provider.error.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.red.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: <Widget>[
                                            Icon(
                                              LucideIcons.alertCircle,
                                              color: Colors.red.shade700,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                provider.error,
                                                style: TextStyle(
                                                  color: Colors.red.shade800,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 24),

                                    // Gradient Button. Radius is shared between
                                    // the gradient container and its inner
                                    // ElevatedButton so they always line up.
                                    Builder(
                                      builder: (context) {
                                        const double btnRadius = 12;
                                        final strings = AppStrings.of(context);
                                        return Container(
                                          height: 54,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(btnRadius),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.primaryGreen
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                            // Subtle gradient derived from the
                                            // brand green — no orphan hardcoded
                                            // hex that drifts from the theme.
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.primaryGreen,
                                                AppTheme.primaryGreen
                                                    .withValues(alpha: 0.85),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: ElevatedButton.icon(
                                            onPressed: provider.logIn,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        btnRadius),
                                              ),
                                            ),
                                            icon: provider.isLoading
                                                ? const SizedBox.shrink()
                                                : const Icon(
                                                    Icons.arrow_forward,
                                                    color: AppColors.white,
                                                    size: 18,
                                                  ),
                                            label: CustomText(
                                              text: provider.isLoading
                                                  ? "${strings.t('login')}..."
                                                  : strings.t('login'),
                                              color: AppColors.white,
                                              fontSize: 16.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
