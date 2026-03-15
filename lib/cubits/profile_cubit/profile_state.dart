import 'package:fleet_monitor/models/user_profile_model.dart';
import 'package:fleet_monitor/models/user_update_model.dart';

abstract class ProfileState {
  final UserProfileModel? userProfileModel;
  final UserUpdateModel? userUpdateModel;
  ProfileState({this.userProfileModel, this.userUpdateModel});
}

class ProfileInitialState extends ProfileState {}

class ProfileLoadingState extends ProfileState {
  ProfileLoadingState({super.userProfileModel, super.userUpdateModel});
}

class ProfileLoggedInState extends ProfileState {
  ProfileLoggedInState({super.userProfileModel, super.userUpdateModel});
}

class ProfileLoggedOutState extends ProfileState {}

class ProfileErrorState extends ProfileState {
  final String message;
  ProfileErrorState(this.message);
}
