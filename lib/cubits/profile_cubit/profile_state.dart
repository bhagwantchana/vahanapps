import 'package:fleet_monitor/models/user_profile_model.dart';

abstract class ProfileState {
  final UserProfileModel? userProfileModel;
  ProfileState({this.userProfileModel});
}

class ProfileInitialState extends ProfileState {}

class ProfileLoadingState extends ProfileState {
  ProfileLoadingState({super.userProfileModel});
}

class ProfileLoggedInState extends ProfileState {
  ProfileLoggedInState({super.userProfileModel});
}

class ProfileLoggedOutState extends ProfileState {}

class ProfileErrorState extends ProfileState {
  final String message;
  ProfileErrorState(this.message);
}
