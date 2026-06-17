import 'package:fleet_monitor/models/model_helpers.dart';

/// One sub-user under a primary customer. Returned by /api/listSubUsers
/// and used by the management screen.
class SubUser {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String username;
  final String phone;
  final int status;
  final int assignedCount;
  final String createdAt;

  const SubUser({
    this.id = 0,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.username = '',
    this.phone = '',
    this.status = 1,
    this.assignedCount = 0,
    this.createdAt = '',
  });

  String get fullName => '$firstName $lastName'.trim();
  String get displayName => fullName.isEmpty ? username : fullName;
  bool get hasRealEmail =>
      email.isNotEmpty && !email.endsWith('@subuser.local');

  factory SubUser.fromJson(Map<String, dynamic> json) => SubUser(
        id: toInt(json['id']),
        firstName: toStringValue(json['first_name']),
        lastName: toStringValue(json['last_name']),
        email: toStringValue(json['email']),
        username: toStringValue(json['username']),
        phone: toStringValue(json['phone']),
        status: toInt(json['status']),
        assignedCount: toInt(json['assigned_count']),
        createdAt: toStringValue(json['created_at']),
      );
}

/// Vehicle row returned by /api/subUserAssignments — what a sub-user can
/// currently see.
class SubUserAssignedVehicle {
  final int vehicleId;
  final String vName;
  final String vRegistrationNo;
  final String assignedAt;

  const SubUserAssignedVehicle({
    this.vehicleId = 0,
    this.vName = '',
    this.vRegistrationNo = '',
    this.assignedAt = '',
  });

  factory SubUserAssignedVehicle.fromJson(Map<String, dynamic> json) =>
      SubUserAssignedVehicle(
        vehicleId: toInt(json['vehicle_id']),
        vName: toStringValue(json['v_name']),
        vRegistrationNo: toStringValue(json['v_registration_no']),
        assignedAt: toStringValue(json['assigned_at']),
      );
}
