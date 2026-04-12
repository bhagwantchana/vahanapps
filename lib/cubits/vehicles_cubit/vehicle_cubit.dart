import 'package:fleet_monitor/cubits/vehicles_cubit/vehicle_state.dart';
import 'package:fleet_monitor/repositorys/vehicle_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VehicleCubit extends Cubit<VehicleState> {
  VehicleCubit() : super(VehicleInitialState());

  final VehicleRepository _vehicleRepository = VehicleRepository();

  Future<void> fetchVehicles() async {
    emit(VehicleLoadingState(vechileListModel: state.vechileListModel));
    try {
      final result = await _vehicleRepository.fetchVehicles();
      emit(VehicleLoggedInState(vechileListModel: result));
    } catch (error) {
      emit(
        VehicleErrorState(
          error.toString().replaceFirst('Exception: ', ''),
          vechileListModel: state.vechileListModel,
        ),
      );
    }
  }
}
