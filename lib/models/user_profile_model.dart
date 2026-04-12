import 'package:fleet_monitor/models/model_helpers.dart';

class UserProfileModel {
  final int flag;
  final String message;
  final UserProfileData? data;

  const UserProfileModel({
    this.flag = 0,
    this.message = '',
    this.data,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      flag: toInt(json['flag']),
      message: toStringValue(json['message']),
      data: json['data'] is Map<String, dynamic>
          ? UserProfileData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class UserProfileData {
  int id;
  String firstName;
  String lastName;
  String email;
  String phone;
  String username;
  String address;
  int countryId;
  int stateId;
  int cityId;
  String image;
  String imageUrl;
  String multiMapUrl;

  UserProfileData({
    this.id = 0,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.username = '',
    this.address = '',
    this.countryId = 0,
    this.stateId = 0,
    this.cityId = 0,
    this.image = '',
    this.imageUrl = '',
    this.multiMapUrl = '',
  });

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    return UserProfileData(
      id: toInt(json['id']),
      firstName: toStringValue(json['first_name']),
      lastName: toStringValue(json['last_name']),
      email: toStringValue(json['email']),
      phone: toStringValue(json['phone']),
      username: toStringValue(json['username']),
      address: toStringValue(json['address']),
      countryId: toInt(json['country_id']),
      stateId: toInt(json['state_id']),
      cityId: toInt(json['city_id']),
      image: toStringValue(json['image']),
      imageUrl: toStringValue(json['image_url']),
      multiMapUrl: toStringValue(json['multi_map_url']),
    );
  }

  String get fullName => '${firstName.trim()} ${lastName.trim()}'.trim();

  String get avatarUrl {
    if (imageUrl.isNotEmpty) {
      return imageUrl;
    }
    if (image.startsWith('http')) {
      return image;
    }
    return '';
  }
}
