import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/document_item_model.dart';
import 'package:fleet_monitor/models/maintenance_log.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/repositorys/document_repository.dart';
import 'package:fleet_monitor/repositorys/maintenance_repository.dart';
import 'package:fleet_monitor/repositorys/vehicle_repository.dart';

class AssignedVehicleReminderService {
  final VehicleRepository _vehicleRepository = VehicleRepository();
  final MaintenanceRepository _maintenanceRepository = MaintenanceRepository();
  final DocumentRepository _documentRepository = DocumentRepository();

  Future<List<VehicleCareSnapshot>> loadAssignedVehicleCare() async {
    final vehicleList = await _vehicleRepository.fetchVehicles();
    final snapshots = <VehicleCareSnapshot>[];

    for (final vehicle in vehicleList.data) {
      List<MaintenanceLog> maintenanceLogs = <MaintenanceLog>[];
      List<DocumentItemModel> documents = <DocumentItemModel>[];

      try {
        maintenanceLogs = await _maintenanceRepository.fetchMaintenanceLogs(
          vehicle.id,
        );
      } catch (_) {
        maintenanceLogs = <MaintenanceLog>[];
      }

      try {
        documents = await _documentRepository.fetchDocuments(
          vehicleId: vehicle.id,
          ownerType: 'vehicle',
        );
      } catch (_) {
        documents = <DocumentItemModel>[];
      }

      snapshots.add(
        VehicleCareSnapshot(
          vehicle: vehicle,
          maintenanceLogs: maintenanceLogs,
          documents: documents,
          maintenanceStatus: VehicleMaintenanceStatus.fromVehicle(
            vehicle,
            maintenanceLogs,
          ),
          insuranceStatus: VehicleInsuranceStatus.fromDocuments(documents),
        ),
      );
    }

    return snapshots;
  }

  Future<List<VehicleCareReminder>> collectDueReminders() async {
    final snapshots = await loadAssignedVehicleCare();
    final reminders = <VehicleCareReminder>[];
    final todayKey = _todayKey();

    for (final snapshot in snapshots) {
      if (snapshot.maintenanceStatus.isDue) {
        final reminder = VehicleCareReminder(
          key:
              '${PreferencesKey.vehicleCareReminderPrefix}_maintenance_${snapshot.vehicle.id}',
          type: VehicleCareReminderType.maintenance,
          vehicleId: snapshot.vehicle.id,
          title: 'Maintenance due for ${snapshot.vehicle.displayName}',
          body: snapshot.maintenanceStatus.notificationBody,
          todayKey: todayKey,
        );
        if (!await _alreadySent(reminder)) {
          reminders.add(reminder);
        }
      }

      if (snapshot.insuranceStatus.needsAttention) {
        final reminder = VehicleCareReminder(
          key:
              '${PreferencesKey.vehicleCareReminderPrefix}_insurance_${snapshot.vehicle.id}',
          type: VehicleCareReminderType.insurance,
          vehicleId: snapshot.vehicle.id,
          title: 'Insurance update for ${snapshot.vehicle.displayName}',
          body: snapshot.insuranceStatus.notificationBody,
          todayKey: todayKey,
        );
        if (!await _alreadySent(reminder)) {
          reminders.add(reminder);
        }
      }
    }

    return reminders;
  }

  Future<void> markReminderSent(VehicleCareReminder reminder) async {
    await LocalStorage.setValue(reminder.key, reminder.todayKey);
  }

  Future<bool> _alreadySent(VehicleCareReminder reminder) async {
    final existing = await LocalStorage.readValue(reminder.key);
    return existing == reminder.todayKey;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

class VehicleCareSnapshot {
  final VehicleRecord vehicle;
  final List<MaintenanceLog> maintenanceLogs;
  final List<DocumentItemModel> documents;
  final VehicleMaintenanceStatus maintenanceStatus;
  final VehicleInsuranceStatus insuranceStatus;

  const VehicleCareSnapshot({
    required this.vehicle,
    required this.maintenanceLogs,
    required this.documents,
    required this.maintenanceStatus,
    required this.insuranceStatus,
  });

  MaintenanceLog? get latestMaintenanceLog =>
      maintenanceLogs.isEmpty ? null : maintenanceLogs.first;
}

class VehicleMaintenanceStatus {
  final bool dueByKm;
  final bool dueByDays;
  final int intervalKm;
  final int intervalDays;
  final double currentOdometer;
  final double baselineOdometer;
  final int remainingKm;
  final int remainingDays;
  final DateTime? nextServiceDate;

  const VehicleMaintenanceStatus({
    required this.dueByKm,
    required this.dueByDays,
    required this.intervalKm,
    required this.intervalDays,
    required this.currentOdometer,
    required this.baselineOdometer,
    required this.remainingKm,
    required this.remainingDays,
    required this.nextServiceDate,
  });

  factory VehicleMaintenanceStatus.fromVehicle(
    VehicleRecord vehicle,
    List<MaintenanceLog> logs,
  ) {
    final latestLog = logs.isEmpty ? null : logs.first;
    final today = _dateOnly(DateTime.now());

    final baselineOdometer = latestLog != null && latestLog.odometerReading > 0
        ? latestLog.odometerReading
        : vehicle.vOdometer;
    final intervalKm = vehicle.maintenanceIntervalKm;
    final currentOdometer = vehicle.currentOdometer;
    final dueAtOdometer = baselineOdometer + intervalKm;
    final remainingKm = intervalKm > 0
        ? (dueAtOdometer - currentOdometer).round()
        : 0;
    final dueByKm = intervalKm > 0 && currentOdometer >= dueAtOdometer;

    final intervalDays = vehicle.maintenanceIntervalDays;
    final baseDate =
        latestLog?.serviceDateValue ?? DateTime.tryParse(vehicle.createdAt);
    DateTime? nextServiceDate;
    int remainingDays = 0;
    bool dueByDays = false;
    if (intervalDays > 0 && baseDate != null) {
      nextServiceDate = _dateOnly(baseDate).add(Duration(days: intervalDays));
      remainingDays = nextServiceDate.difference(today).inDays;
      dueByDays = !today.isBefore(nextServiceDate);
    }

    return VehicleMaintenanceStatus(
      dueByKm: dueByKm,
      dueByDays: dueByDays,
      intervalKm: intervalKm,
      intervalDays: intervalDays,
      currentOdometer: currentOdometer,
      baselineOdometer: baselineOdometer,
      remainingKm: remainingKm,
      remainingDays: remainingDays,
      nextServiceDate: nextServiceDate,
    );
  }

  bool get isDue => dueByKm || dueByDays;

  String get summary {
    if (isDue) {
      if (dueByKm && dueByDays) {
        return 'Maintenance overdue by odometer and service date.';
      }
      if (dueByKm) {
        return remainingKm == 0
            ? 'Maintenance is due now by odometer.'
            : 'Maintenance overdue by ${remainingKm.abs()} km.';
      }
      return remainingDays == 0
          ? 'Maintenance is due today.'
          : 'Maintenance overdue by ${remainingDays.abs()} day(s).';
    }

    if (intervalKm > 0) {
      return 'Next maintenance in ${remainingKm < 0 ? 0 : remainingKm} km.';
    }
    if (intervalDays > 0 && nextServiceDate != null) {
      return 'Next maintenance in ${remainingDays < 0 ? 0 : remainingDays} day(s).';
    }
    return 'No maintenance interval configured.';
  }

  String get notificationBody {
    if (dueByKm && dueByDays) {
      return 'Service interval is overdue by km and date. Open Vehicle Care to update the service record.';
    }
    if (dueByKm) {
      return remainingKm == 0
          ? 'Service is due now based on odometer. Open Vehicle Care to add the maintenance log.'
          : 'Service is overdue by ${remainingKm.abs()} km. Open Vehicle Care to add the maintenance log.';
    }
    if (dueByDays) {
      return remainingDays == 0
          ? 'Service is due today. Open Vehicle Care to add the maintenance log.'
          : 'Service is overdue by ${remainingDays.abs()} day(s). Open Vehicle Care to add the maintenance log.';
    }
    return 'Vehicle maintenance is up to date.';
  }
}

class VehicleInsuranceStatus {
  final DocumentItemModel? document;
  final bool isExpired;
  final bool isDueSoon;
  final int daysRemaining;

  const VehicleInsuranceStatus({
    required this.document,
    required this.isExpired,
    required this.isDueSoon,
    required this.daysRemaining,
  });

  factory VehicleInsuranceStatus.fromDocuments(List<DocumentItemModel> docs) {
    final insuranceDocs = docs.where(_isInsuranceDocument).toList();
    if (insuranceDocs.isEmpty) {
      return const VehicleInsuranceStatus(
        document: null,
        isExpired: false,
        isDueSoon: false,
        daysRemaining: 0,
      );
    }

    insuranceDocs.sort((a, b) {
      final aDate = _dateOnly(a.expiryDateValue ?? DateTime(1970));
      final bDate = _dateOnly(b.expiryDateValue ?? DateTime(1970));
      return aDate.compareTo(bDate);
    });

    final today = _dateOnly(DateTime.now());
    final upcoming = insuranceDocs.firstWhere(
      (doc) {
        final expiry = doc.expiryDateValue;
        if (expiry == null) {
          return false;
        }
        return !_dateOnly(expiry).isBefore(today);
      },
      orElse: () => insuranceDocs.last,
    );

    final expiry = upcoming.expiryDateValue;
    if (expiry == null) {
      return VehicleInsuranceStatus(
        document: upcoming,
        isExpired: false,
        isDueSoon: false,
        daysRemaining: 0,
      );
    }

    final expiryDate = _dateOnly(expiry);
    final daysRemaining = expiryDate.difference(today).inDays;
    final isExpired = expiryDate.isBefore(today);
    final isDueSoon = !isExpired && daysRemaining <= 7;

    return VehicleInsuranceStatus(
      document: upcoming,
      isExpired: isExpired,
      isDueSoon: isDueSoon,
      daysRemaining: daysRemaining,
    );
  }

  bool get needsAttention => isExpired || isDueSoon;

  String get summary {
    if (document == null) {
      return 'No insurance document uploaded.';
    }
    if (isExpired) {
      return 'Insurance expired ${daysRemaining.abs()} day(s) ago.';
    }
    if (isDueSoon) {
      return daysRemaining == 0
          ? 'Insurance expires today.'
          : 'Insurance expires in $daysRemaining day(s).';
    }
    return 'Insurance is active.';
  }

  String get notificationBody {
    if (document == null) {
      return 'No insurance document is linked to this vehicle.';
    }
    if (isExpired) {
      return 'Insurance has expired. Open the document vault to review or replace the insurance document.';
    }
    if (isDueSoon) {
      return daysRemaining == 0
          ? 'Insurance expires today. Open the document vault to review the document.'
          : 'Insurance expires in $daysRemaining day(s). Open the document vault to review the document.';
    }
    return 'Insurance is active.';
  }
}

enum VehicleCareReminderType { maintenance, insurance }

class VehicleCareReminder {
  final String key;
  final VehicleCareReminderType type;
  final int vehicleId;
  final String title;
  final String body;
  final String todayKey;

  const VehicleCareReminder({
    required this.key,
    required this.type,
    required this.vehicleId,
    required this.title,
    required this.body,
    required this.todayKey,
  });
}

extension on DocumentItemModel {
  DateTime? get expiryDateValue {
    if (expiryDate.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(expiryDate);
  }
}

bool _isInsuranceDocument(DocumentItemModel document) {
  final haystack =
      '${document.categoryKey} ${document.title} ${document.notes}'.toLowerCase();
  return haystack.contains('insurance');
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}
