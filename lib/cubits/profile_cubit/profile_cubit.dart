import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_state.dart';
import 'package:fleet_monitor/models/user_profile_model.dart';
import 'package:fleet_monitor/repositorys/profile_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(ProfileInitialState());

  final ProfileRepository _profileRepository = ProfileRepository();

  Future<void> fetchProfile() async {
    emit(ProfileLoadingState(userProfileModel: state.userProfileModel));
    try {
      final result = await _profileRepository.fetchProfile();
      if (isClosed) return;
      emit(ProfileLoggedInState(userProfileModel: result));
    } catch (error) {
      if (isClosed) return;
      emit(
        ProfileErrorState(
          error.toString().replaceFirst('Exception: ', ''),
          userProfileModel: state.userProfileModel,
        ),
      );
    }
  }

  Future<bool> updateProfile({
    required UserProfileData currentProfile,
    String? name,
    String? lastName,
    String? email,
    String? file,
  }) async {
    emit(ProfileLoadingState(userProfileModel: state.userProfileModel));
    try {
      final result = await _profileRepository.updateProfileData(
        currentProfile: currentProfile,
        firstName: name,
        lastName: lastName,
        email: email,
        file: file,
      );

      final token = result.data?.xAuthToken;
      if (token != null && token.trim().isNotEmpty) {
        await LocalStorage.setValue(PreferencesKey.token, token);
      }

      await fetchProfile();
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(
        ProfileErrorState(
          error.toString().replaceFirst('Exception: ', ''),
          userProfileModel: state.userProfileModel,
        ),
      );
      return false;
    }
  }

  /// Clear state on logout so the next user doesn't see the prior profile.
  void reset() => emit(ProfileInitialState());
}
