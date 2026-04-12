abstract class AuthState {}

class AuthInitialState extends AuthState {}

class AuthLoadingState extends AuthState {}

class AuthLoggedInState extends AuthState {
  final String token;

  AuthLoggedInState(this.token);
}

class AuthLoggedOutState extends AuthState {}

class AuthErrorState extends AuthState {
  final String message;

  AuthErrorState(this.message);
}
