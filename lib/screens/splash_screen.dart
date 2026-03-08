import 'dart:async';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_state.dart';
import 'package:fleet_monitor/screens/home_screen.dart';
import 'package:fleet_monitor/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const String routeName = "splash";

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  void goToNextScreen() {
    if (!mounted) return;
    AuthState userState = BlocProvider.of<AuthCubit>(context).state;

    if (userState is AuthLoggedInState) {
      Navigator.popUntil(context, (route) => route.isFirst);
      Navigator.pushReplacementNamed(context, HomeScreen.routeName);
    } else if (userState is AuthLoggedOutState) {
      Navigator.popUntil(context, (route) => route.isFirst);
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
    } else if (userState is AuthErrorState) {
      Navigator.popUntil(context, (route) => route.isFirst);
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), goToNextScreen);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        goToNextScreen();
      },
      child: Scaffold(
        body: Center(
          child: CircularProgressIndicator(backgroundColor: AppColors.white),
        ),
      ),
    );
  }
}
