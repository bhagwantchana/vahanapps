import 'package:fleet_monitor/cubits/auth_cubit/auth_state.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/auth_model.dart';
import 'package:fleet_monitor/repositorys/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitialState()) {
    _initialize();
  }
  final AuthRepository _authRepository = AuthRepository();

  Future<void> _initialize() async {
    emit(AuthLoadingState());
    String? isLogin = await LocalStorage.readValue(PreferencesKey.isLogin);
    if (isLogin == null || isLogin != "islogin") {
      emit(AuthLoggedOutState());
    } else {
      emit(AuthLoggedInState(isLogin));
    }
  }

  void _emitLoggedInState({
    required String isLogin,
    required AuthModel authModel,
  }) async {
    await LocalStorage.setValue(PreferencesKey.isLogin, isLogin);
    await LocalStorage.setValue(PreferencesKey.authData, authModel.toString());
    await LocalStorage.setValue(
      PreferencesKey.authData,
      authModel.data!.xAuthToken!,
    );
    emit(AuthLoggedInState(isLogin));
  }

  void signIn({required String email, required String pass}) async {
    emit(AuthLoadingState());
    try {
      final result = await _authRepository.loginRepo(email: email, pass: pass);
      _emitLoggedInState(isLogin: "islogin", authModel: result);
    } catch (ex) {
      emit(AuthErrorState(ex.toString()));
    }
  }

  void signOut() async {
    await LocalStorage.clearAll();
    emit(AuthLoggedOutState());
  }
}
