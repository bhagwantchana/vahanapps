import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_state.dart';
import 'package:fleet_monitor/repositorys/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitialState()) {
    initialize();
  }

  final AuthRepository _authRepository = AuthRepository();

  Future<void> initialize() async {
    emit(AuthLoadingState());
    final token = await LocalStorage.readValue(PreferencesKey.token);
    final isLogin = await LocalStorage.readValue(PreferencesKey.isLogin);

    if (token != null &&
        token.trim().isNotEmpty &&
        isLogin != null &&
        isLogin == 'islogin') {
      emit(AuthLoggedInState(token));
      return;
    }

    emit(AuthLoggedOutState());
  }

  Future<void> signIn({
    required String email,
    required String pass,
  }) async {
    emit(AuthLoadingState());
    try {
      final result = await _authRepository.loginRepo(email: email, pass: pass);
      final token = result.data?.xAuthToken ?? '';
      if (token.isEmpty) {
        throw Exception('Login token is missing from response');
      }

      await LocalStorage.setValue(PreferencesKey.isLogin, 'islogin');
      await LocalStorage.setValue(PreferencesKey.token, token);
      // Persist the sub-user flag so engine/edit/settings UI can be hidden
      // without re-hitting the network. Primary users save '0' (no-op).
      final isSub = result.data?.isSubUser == true;
      await LocalStorage.setValue(
        PreferencesKey.isSubUser, isSub ? '1' : '0');
      await LocalStorage.setValue(
        PreferencesKey.username, result.data?.username ?? '');
      emit(AuthLoggedInState(token));
    } catch (error) {
      emit(AuthErrorState(error.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> signOut() async {
    final token = await LocalStorage.readValue(PreferencesKey.token) ?? '';
    await _authRepository.logoutRepo(token);
    await LocalStorage.clearSession();
    emit(AuthLoggedOutState());
  }
}
