import 'package:fleet_monitor/cubits/home_cubit/home_state.dart';
import 'package:fleet_monitor/repositorys/home_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(HomeInitialState());

  final HomeRepository _homeRepository = HomeRepository();

  Future<void> fetchHomeData() async {
    emit(HomeLoadingState(dashboardModel: state.dashboardModel));
    try {
      final result = await _homeRepository.fetchDashboard();
      emit(HomeLoggedInState(dashboardModel: result));
    } catch (error) {
      emit(
        HomeErrorState(
          error.toString().replaceFirst('Exception: ', ''),
          dashboardModel: state.dashboardModel,
        ),
      );
    }
  }
}
