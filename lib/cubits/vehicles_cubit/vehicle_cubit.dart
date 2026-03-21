import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_state.dart';
import 'package:fleet_monitor/repositorys/vehicle_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VehicleCubit extends Cubit<VehicleState> {
  VehicleCubit() : super(VehicleInitialState()) {
    _initialize();
  }
  final VehicleRepository _vehicleRepository = VehicleRepository();
  Future<void> _initialize() async {
    emit(VehicleLoadingState());
    try {
      final result = await _vehicleRepository.vehicleListFetch();
      emit(VehicleLoggedInState(vechileListModel: result));
    } catch (e) {
      emit(VehicleErrorState(e.toString()));
    }
  }
}
