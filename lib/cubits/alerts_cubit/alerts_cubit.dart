import 'package:fleet_monitor/cubits/alerts_cubit/alerts_state.dart';
import 'package:fleet_monitor/models/alert_model.dart';
import 'package:fleet_monitor/repositorys/alerts_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AlertsCubit extends Cubit<AlertsState> {
  AlertsCubit() : super(AlertsInitialState());

  final AlertsRepository _alertsRepository = AlertsRepository();

  Future<void> fetchAlerts({
    bool unreadOnly = false,
  }) async {
    emit(AlertsLoadingState(alertListModel: state.alertListModel));
    try {
      final result = await _alertsRepository.fetchAlerts(
        isRead: unreadOnly ? 0 : null,
      );
      emit(AlertsLoadedState(alertListModel: result));
    } catch (error) {
      emit(
        AlertsErrorState(
          error.toString().replaceFirst('Exception: ', ''),
          alertListModel: state.alertListModel,
        ),
      );
    }
  }

  Future<bool> markAsRead(int alertId) async {
    try {
      await _alertsRepository.markAsRead(alertId);
      final currentAlerts = state.alertListModel;
      if (currentAlerts != null) {
        final updatedAlerts = currentAlerts.data.map((alert) {
          if (alert.id == alertId) {
            return alert.copyWith(isRead: true);
          }
          return alert;
        }).toList();
        emit(
          AlertsLoadedState(
            alertListModel: AlertListModel(
              flag: currentAlerts.flag,
              message: currentAlerts.message,
              data: updatedAlerts,
              meta: AlertMeta(
                limit: currentAlerts.meta.limit,
                offset: currentAlerts.meta.offset,
                unreadCount: currentAlerts.meta.unreadCount > 0
                    ? currentAlerts.meta.unreadCount - 1
                    : 0,
              ),
            ),
          ),
        );
      }
      return true;
    } catch (error) {
      emit(
        AlertsErrorState(
          error.toString().replaceFirst('Exception: ', ''),
          alertListModel: state.alertListModel,
        ),
      );
      return false;
    }
  }
}
