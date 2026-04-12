import 'package:fleet_monitor/models/alert_model.dart';

abstract class AlertsState {
  final AlertListModel? alertListModel;

  const AlertsState({this.alertListModel});
}

class AlertsInitialState extends AlertsState {}

class AlertsLoadingState extends AlertsState {
  const AlertsLoadingState({super.alertListModel});
}

class AlertsLoadedState extends AlertsState {
  const AlertsLoadedState({super.alertListModel});
}

class AlertsErrorState extends AlertsState {
  final String message;

  const AlertsErrorState(this.message, {super.alertListModel});
}
