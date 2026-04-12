import 'package:fleet_monitor/models/model_helpers.dart';
import 'package:fleet_monitor/models/user_profile_model.dart';

class AuthModel {
  final int flag;
  final String message;
  final AuthData? data;

  const AuthModel({
    this.flag = 0,
    this.message = '',
    this.data,
  });

  factory AuthModel.fromJson(Map<String, dynamic> json) {
    return AuthModel(
      flag: toInt(json['flag']),
      message: toStringValue(json['message']),
      data: json['data'] is Map<String, dynamic>
          ? AuthData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AuthData {
  final String xAuthToken;
  final String mapsUrl;
  final String legacyMapsUrl;
  final UserProfileData? profile;

  const AuthData({
    this.xAuthToken = '',
    this.mapsUrl = '',
    this.legacyMapsUrl = '',
    this.profile,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      xAuthToken: toStringValue(json['X-Auth-Token']),
      mapsUrl: toStringValue(json['maps_url']),
      legacyMapsUrl: toStringValue(json['legacy_maps_url']),
      profile: json['profile'] is Map<String, dynamic>
          ? UserProfileData.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
    );
  }
}
