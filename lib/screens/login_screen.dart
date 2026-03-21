import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_state.dart';
import 'package:fleet_monitor/gen/assets.gen.dart';
import 'package:fleet_monitor/providers/login_provider.dart';
import 'package:fleet_monitor/screens/dashboard.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
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
            backgroundColor: AppTheme.background,
            body: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.05,
                    child: Image.network(
                      'https://www.transparenttextures.com/patterns/cubes.png',
                      repeat: ImageRepeat.repeat,
                    ),
                  ),
                ),

                Center(
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
                              Icon(
                                LucideIcons.compass,
                                size: 64,
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(height: 16),

                              Text(
                                'FleetMonitor360',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryBlue,
                                  letterSpacing: -0.5,
                                ),
                              ),

                              Text(
                                'Global Fleet Intelligence',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 1.0,
                                ),
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
                                        TextField(
                                          controller: provider.emailController,
                                          decoration: InputDecoration(
                                            labelText:
                                                'Username or Mobile Number',
                                            prefixIcon: Icon(
                                              LucideIcons.user,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        TextField(
                                          controller:
                                              provider.passwordController,
                                          obscureText: true,
                                          decoration: InputDecoration(
                                            labelText: 'Password',
                                            prefixIcon: Icon(
                                              LucideIcons.lock,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () {},
                                            child: Text(
                                              'Forgot Password?',
                                              style: TextStyle(
                                                color: AppTheme.primaryBlue,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // Gradient Button
                                        Container(
                                          height: 54,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.primaryGreen
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.primaryGreen,
                                                Color(0xFF67A836),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: ElevatedButton(
                                            onPressed: provider.logIn,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: CustomText(
                                              text: (provider.isLoading)
                                                  ? "Login..."
                                                  : "Login ->",
                                              color: AppColors.white,
                                              fontSize: 16.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
