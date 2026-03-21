import 'package:fleet_monitor/cubits/home_cubit/home_state.dart';
import 'package:fleet_monitor/repositorys/home_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(HomeInitialState()) {
    _initialize();
  }
  final HomeRepository _homeRepository = HomeRepository();
  Future<void> _initialize() async {
    emit(HomeLoadingState());
    try {
      final result = await _homeRepository.vehicleListFetch();
      emit(HomeLoggedInState(dashboardModel: result));
    } catch (e) {
      emit(HomeErrorState(e.toString()));
    }
  }
}
