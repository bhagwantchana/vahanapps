import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/sub_user_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

/// All sub-user feature endpoints. Only callable by a primary customer
/// — the server gates these with _requirePrimaryCustomer so a sub-user
/// token returning here always errors out.
class SubUserRepository {
  final NetworkApi _net = NetworkApi();

  Future<String> _token() async =>
      (await LocalStorage.readValue(PreferencesKey.token)) ?? '';

  Future<Map<String, dynamic>> _post(
      String url, Map<String, dynamic> body) async {
    final token = await _token();
    if (token.isEmpty) throw Exception('Not logged in');
    final res = await _net.sendRequest.post(
      url,
      data: body.isEmpty ? null : FormData.fromMap(body),
      options: NetworkApi.buildOptions(authToken: token),
    );
    final raw = res.data;
    if (raw is! Map) {
      throw Exception('Unexpected response');
    }
    final flag = raw['flag'] is int
        ? raw['flag'] as int
        : int.tryParse('${raw['flag']}') ?? 0;
    if (flag != 1) {
      throw Exception(
          (raw['message']?.toString() ?? 'Request failed').isEmpty
              ? 'Request failed'
              : raw['message'].toString());
    }
    return raw['data'] is Map
        ? Map<String, dynamic>.from(raw['data'])
        : <String, dynamic>{};
  }

  Future<List<SubUser>> list() async {
    final data = await _post(AppUrl.listSubUsers, {});
    final list = data['sub_users'] is List ? (data['sub_users'] as List) : const [];
    return list
        .whereType<Map>()
        .map((e) => SubUser.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SubUser> create({
    required String firstName,
    String lastName = '',
    required String username,
    required String password,
    String email = '',
    String phone = '',
  }) async {
    final data = await _post(AppUrl.createSubUser, {
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
      'password': password,
      'email': email,
      'phone': phone,
    });
    return SubUser(
      id: (data['sub_user_id'] is int)
          ? data['sub_user_id'] as int
          : int.tryParse('${data['sub_user_id']}') ?? 0,
      firstName: firstName,
      lastName: lastName,
      username: '${data['username'] ?? username}',
      email: '${data['email'] ?? ''}',
      phone: phone,
      status: 1,
    );
  }

  Future<void> delete(int subUserId) =>
      _post(AppUrl.deleteSubUser, {'sub_user_id': subUserId});

  Future<void> resetPassword(int subUserId, String newPassword) => _post(
        AppUrl.resetSubUserPassword,
        {'sub_user_id': subUserId, 'new_password': newPassword},
      );

  Future<int> assignVehicles(int subUserId, List<int> vehicleIds) async {
    final data = await _post(AppUrl.assignVehiclesToSubUser, {
      'sub_user_id': subUserId,
      'vehicle_ids': vehicleIds.join(','),
    });
    return data['assigned_count'] is int
        ? data['assigned_count'] as int
        : int.tryParse('${data['assigned_count']}') ?? 0;
  }

  Future<void> unassign(int subUserId, int vehicleId) => _post(
        AppUrl.unassignVehicleFromSubUser,
        {'sub_user_id': subUserId, 'vehicle_id': vehicleId},
      );

  Future<List<SubUserAssignedVehicle>> assignments(int subUserId) async {
    final data =
        await _post(AppUrl.subUserAssignments, {'sub_user_id': subUserId});
    final list = data['vehicles'] is List ? (data['vehicles'] as List) : const [];
    return list
        .whereType<Map>()
        .map((e) =>
            SubUserAssignedVehicle.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// No-login share link (parent map) for a sub-user — to hand to a parent.
  Future<String> shareLink(int subUserId) async {
    final data = await _post(AppUrl.subUserShareLink, {'sub_user_id': subUserId});
    return (data['share_url'] ?? '').toString();
  }
}
