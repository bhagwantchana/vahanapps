abstract class AuthState {}

class AuthInitialState extends AuthState {}

class AuthLoadingState extends AuthState {}

class AuthLoggedInState extends AuthState {
  final String token;
  // True when the just-logged-in account is a student-mode sub-user, so the
  // login screen can route straight to the locked single-map home.
  final bool isStudent;

  AuthLoggedInState(this.token, {this.isStudent = false});
}

class AuthLoggedOutState extends AuthState {}

class AuthErrorState extends AuthState {
  final String message;

  AuthErrorState(this.message);
}
