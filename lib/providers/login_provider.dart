import 'dart:async';
import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginProvider with ChangeNotifier {
  final BuildContext context;
  LoginProvider(this.context) {
    _listenToUserCubit();
  }

  bool isLoading = false;
  String error = "";

  final emailController = TextEditingController(
    text: 'bhagwant.chana@gmail.com',
  );
  final passwordController = TextEditingController(
    text: 'Admin@fleetmonitor360.com',
  );
  final formKey = GlobalKey<FormState>();
  StreamSubscription? _userSubscription;

  void _listenToUserCubit() {
    _userSubscription = BlocProvider.of<AuthCubit>(context).stream.listen((
      userState,
    ) {
      if (userState is AuthLoadingState) {
        isLoading = true;
        error = "";
        notifyListeners();
      } else if (userState is AuthErrorState) {
        isLoading = false;
        error = userState.message;
        notifyListeners();
      } else {
        isLoading = false;
        error = "";
        notifyListeners();
      }
    });
  }

  void logIn() async {
    if (!formKey.currentState!.validate()) return;
    String name = emailController.text.trim();
    String mobile = passwordController.text.trim();
    BlocProvider.of<AuthCubit>(context).signIn(email: name, pass: mobile);
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
