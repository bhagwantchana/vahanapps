import 'package:fleet_monitor/cubits/home_cubit/home_state.dart';
import 'package:fleet_monitor/repositorys/home_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(HomeInitialState());

  final HomeRepository _homeRepository = HomeRepository();

  /// The date the Performance Overview is anchored to (null = today).
  /// Kept here so background/pull refreshes reuse the chosen date instead of
  /// silently snapping back to today.
  DateTime? _selectedDate;
  DateTime? get selectedDate => _selectedDate;

  String? _fmt(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Pass [date] to change the anchor (e.g. from the date picker). Calls with
  /// no argument (auto/pull refresh) reuse the last selected date.
  Future<void> fetchHomeData({DateTime? date}) async {
    if (date != null) _selectedDate = date;
    emit(HomeLoadingState(dashboardModel: state.dashboardModel));
    try {
      final result = await _homeRepository.fetchDashboard(date: _fmt(_selectedDate));
      if (isClosed) return;
      emit(HomeLoggedInState(dashboardModel: result));
    } catch (error) {
      if (isClosed) return;
      emit(
        HomeErrorState(
          error.toString().replaceFirst('Exception: ', ''),
          dashboardModel: state.dashboardModel,
        ),
      );
    }
  }

  /// Clear state on logout so the next user doesn't see the prior dashboard.
  void reset() {
    _selectedDate = null;
    emit(HomeInitialState());
  }
}
