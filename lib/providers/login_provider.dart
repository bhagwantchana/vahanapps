import 'dart:async';

import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginProvider with ChangeNotifier {
  final BuildContext context;

  LoginProvider(this.context) {
    isLoading = BlocProvider.of<AuthCubit>(context).state is AuthLoadingState;
    _listenToUserCubit();
  }

  bool isLoading = false;
  String error = '';

  final emailController = TextEditingController(
    text: "bhagwant.chana@gmail.com",
  );
  final passwordController = TextEditingController(
    text: "Admin@fleetmonitor360.com",
  );
  final formKey = GlobalKey<FormState>();

  StreamSubscription<AuthState>? _userSubscription;

  void _listenToUserCubit() {
    _userSubscription = BlocProvider.of<AuthCubit>(context).stream.listen((
      userState,
    ) {
      if (userState is AuthLoadingState) {
        isLoading = true;
        error = '';
      } else if (userState is AuthErrorState) {
        isLoading = false;
        error = userState.message;
      } else {
        isLoading = false;
        error = '';
      }
      notifyListeners();
    });
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username, email, or phone is required';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    if (value.trim().length < 6) {
      return 'Password looks too short';
    }
    return null;
  }

  Future<void> logIn() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!formKey.currentState!.validate()) {
      return;
    }

    await BlocProvider.of<AuthCubit>(context).signIn(
      email: emailController.text.trim(),
      pass: passwordController.text.trim(),
    );
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
