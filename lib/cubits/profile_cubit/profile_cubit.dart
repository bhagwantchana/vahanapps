import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_state.dart';
import 'package:fleet_monitor/repositorys/profile_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(ProfileInitialState()) {
    _initialize();
  }
  final ProfileRepository _profileRepository = ProfileRepository();
  Future<void> _initialize() async {
    emit(ProfileLoadingState());
    try {
      final result = await _profileRepository.vehicleListFetch();
      emit(ProfileLoggedInState(userProfileModel: result));
    } catch (e) {
      emit(ProfileErrorState(e.toString()));
    }
  }

  void updateProfile({String? name, lastNam, email, file}) async {
    emit(ProfileLoadingState());
    try {
      final result = await _profileRepository.updateProfileData(
        name!,
        lastNam!,
        email!,
        file,
      );
      await LocalStorage.setValue(
        PreferencesKey.token,
        result.data!.xAuthToken!,
      );
      await _initialize();
    } catch (ex) {
      emit(ProfileErrorState(ex.toString()));
    }
  }
}
