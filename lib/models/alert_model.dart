import 'package:fleet_monitor/models/model_helpers.dart';

class AlertListModel {
  final int flag;
  final String message;
  final List<AlertItem> data;
  final AlertMeta meta;

  const AlertListModel({
    this.flag = 0,
    this.message = '',
    this.data = const <AlertItem>[],
    this.meta = const AlertMeta(),
  });

  factory AlertListModel.fromJson(Map<String, dynamic> json) {
    final items = <AlertItem>[];
    if (json['data'] is List) {
      for (final item in json['data'] as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          items.add(AlertItem.fromJson(item));
        }
      }
    }

    return AlertListModel(
      flag: toInt(json['flag']),
      message: toStringValue(json['message']),
      data: items,
      meta: json['meta'] is Map<String, dynamic>
          ? AlertMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : const AlertMeta(),
    );
  }
}

class AlertMeta {
  final int limit;
  final int offset;
  final int unreadCount;

  const AlertMeta({
    this.limit = 20,
    this.offset = 0,
    this.unreadCount = 0,
  });

  factory AlertMeta.fromJson(Map<String, dynamic> json) {
    return AlertMeta(
      limit: toInt(json['limit'], fallback: 20),
      offset: toInt(json['offset']),
      unreadCount: toInt(json['unread_count']),
    );
  }
}

class AlertItem {
  final int id;
  final int deviceId;
  final int vehicleId;
  final String imei;
  final String alertType;
  final String message;
  final String alertValue;
  final double latitude;
  final double longitude;
  final bool isRead;
  final String createdAt;
  final String vehicleName;
  final String registrationNumber;

  const AlertItem({
    this.id = 0,
    this.deviceId = 0,
    this.vehicleId = 0,
    this.imei = '',
    this.alertType = '',
    this.message = '',
    this.alertValue = '',
    this.latitude = 0,
    this.longitude = 0,
    this.isRead = false,
    this.createdAt = '',
    this.vehicleName = '',
    this.registrationNumber = '',
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      id: toInt(json['id']),
      deviceId: toInt(json['device_id']),
      vehicleId: toInt(json['vehicle_id']),
      imei: toStringValue(json['imei']),
      alertType: toStringValue(json['alert_type']),
      message: toStringValue(json['message']),
      alertValue: toStringValue(json['alert_value']),
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
      isRead: toBoolFlag(json['is_read']),
      createdAt: toStringValue(json['created_at']),
      vehicleName: toStringValue(json['v_name']),
      registrationNumber: toStringValue(json['v_registration_no']),
    );
  }

  AlertItem copyWith({
    bool? isRead,
  }) {
    return AlertItem(
      id: id,
      deviceId: deviceId,
      vehicleId: vehicleId,
      imei: imei,
      alertType: alertType,
      message: message,
      alertValue: alertValue,
      latitude: latitude,
      longitude: longitude,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      vehicleName: vehicleName,
      registrationNumber: registrationNumber,
    );
  }

  String get displayVehicle =>
      registrationNumber.isNotEmpty ? registrationNumber : vehicleName;

  String get displayType {
    switch (alertType) {
      case 'ignition_on':
        return 'Ignition On';
      case 'ignition_off':
        return 'Ignition Off';
      case 'geofence_enter':
        return 'Entered Radius';
      case 'geofence_exit':
        return 'Outside Radius';
      case 'parking_guard':
        return 'Parking Guard';
      case 'overspeed':
        return 'Overspeed';
      case 'sos':
        return 'SOS';
      case 'tampering':
        return 'Tampering';
      case 'power_cut':
        return 'Power Cut';
      default:
        return alertType
            .split('_')
            .map((part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }
}
