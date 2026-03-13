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

  void updateProfile({String? email, String? name, String? file}) async {
    emit(ProfileLoadingState());
    try {
      final result = await _profileRepository.updateProfileData();
      emit(ProfileLoggedInState(userProfileModel: result));
    } catch (ex) {
      emit(ProfileErrorState(ex.toString()));
    }
  }
}
