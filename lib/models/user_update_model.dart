import 'package:fleet_monitor/models/model_helpers.dart';
import 'package:fleet_monitor/models/user_profile_model.dart';

class UserUpdateModel {
  final int flag;
  final String message;
  final UserUpdateData? data;

  const UserUpdateModel({
    this.flag = 0,
    this.message = '',
    this.data,
  });

  factory UserUpdateModel.fromJson(Map<String, dynamic> json) {
    return UserUpdateModel(
      flag: toInt(json['flag']),
      message: toStringValue(json['message']),
      data: json['data'] is Map<String, dynamic>
          ? UserUpdateData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class UserUpdateData {
  final String rand;
  final String xAuthToken;
  final UserProfileData? profile;

  const UserUpdateData({
    this.rand = '',
    this.xAuthToken = '',
    this.profile,
  });

  factory UserUpdateData.fromJson(Map<String, dynamic> json) {
    return UserUpdateData(
      rand: toStringValue(json['rand']),
      xAuthToken: toStringValue(json['X-Auth-Token']),
      profile: json['profile'] is Map<String, dynamic>
          ? UserProfileData.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
    );
  }
}
