import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_state.dart';
import 'package:fleet_monitor/gen/assets.gen.dart';
import 'package:fleet_monitor/providers/login_provider.dart';
import 'package:fleet_monitor/screens/splash_screen.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/widgets/custom_text.dart';
import 'package:fleet_monitor/widgets/gap_widget.dart';
import 'package:fleet_monitor/widgets/primary_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
          Navigator.pushReplacementNamed(context, SplashScreen.routeName);
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
          child: SafeArea(
            child: Form(
              key: provider.formKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisAlignment: .start,
                  children: [
                    GapWidget(size: 20),
                    GapWidget(size: 20),
                    CustomText(
                      text: "FleetMonitor360",
                      color: AppColors.white,
                      fontSize: 40.0,
                      fontWeight: FontWeight.bold,
                    ),
                    CustomText(
                      text: "Riding the Tide of Safe and Comfortable Journeys",
                      color: AppColors.white,
                      fontSize: 16.0,
                    ),
                    GapWidget(size: 20),
                    GapWidget(size: 20),
                    CustomText(
                      text: "Log In",
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      fontSize: 32,
                    ),
                    const GapWidget(size: -10),
                    (provider.error != "")
                        ? CustomText(text: provider.error, color: Colors.red)
                        : const SizedBox(),
                    const GapWidget(size: 5),
                    PrimaryTextField(
                      controller: provider.emailController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "User name is required!";
                        }
                        return null;
                      },
                      style: TextStyle(color: AppColors.white),
                      labelText: "User Name",
                      lableStyle: TextStyle(color: AppColors.white),
                    ),
                    const GapWidget(),
                    PrimaryTextField(
                      controller: provider.passwordController,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Password is required!";
                        }
                        return null;
                      },
                      style: TextStyle(color: AppColors.white),
                      labelText: "Password",
                      lableStyle: TextStyle(color: AppColors.white),
                    ),
                    const GapWidget(),
                    InkWell(
                      onTap: provider.logIn,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        alignment: Alignment.center,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: CustomText(
                          text: (provider.isLoading) ? "Login..." : "Login ->",
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
        ),
      ),
    );
  }
}
