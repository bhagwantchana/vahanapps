class SingleTrackModel {
  int? flag;
  Data? data;

  SingleTrackModel({this.flag, this.data});

  SingleTrackModel.fromJson(Map<String, dynamic> json) {
    flag = json['flag'];
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['flag'] = this.flag;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class Data {
  String? vRegistrationNo;
  String? vName;
  String? vModel;
  String? imei;
  String? deviceId;
  String? tripStatus;
  String? lastLatitude;
  String? lastLongitude;
  String? lastSpeed;
  String? vehicleTypeId;
  String? vehicleIcon;
  String? vehicleIconUrl;
  String? trackingUrl;

  Data({
    this.vRegistrationNo,
    this.vName,
    this.vModel,
    this.imei,
    this.deviceId,
    this.tripStatus,
    this.lastLatitude,
    this.lastLongitude,
    this.lastSpeed,
    this.vehicleTypeId,
    this.vehicleIcon,
    this.vehicleIconUrl,
    this.trackingUrl,
  });

  Data.fromJson(Map<String, dynamic> json) {
    vRegistrationNo = json['v_registration_no'];
    vName = json['v_name'];
    vModel = json['v_model'];
    imei = json['imei'];
    deviceId = json['device_id'];
    tripStatus = json['trip_status'];
    lastLatitude = json['last_latitude'];
    lastLongitude = json['last_longitude'];
    lastSpeed = json['last_speed'];
    vehicleTypeId = json['vehicle_type_id'];
    vehicleIcon = json['vehicle_icon'];
    vehicleIconUrl = json['vehicle_icon_url'];
    trackingUrl = json['tracking_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['v_registration_no'] = this.vRegistrationNo;
    data['v_name'] = this.vName;
    data['v_model'] = this.vModel;
    data['imei'] = this.imei;
    data['device_id'] = this.deviceId;
    data['trip_status'] = this.tripStatus;
    data['last_latitude'] = this.lastLatitude;
    data['last_longitude'] = this.lastLongitude;
    data['last_speed'] = this.lastSpeed;
    data['vehicle_type_id'] = this.vehicleTypeId;
    data['vehicle_icon'] = this.vehicleIcon;
    data['vehicle_icon_url'] = this.vehicleIconUrl;
    data['tracking_url'] = this.trackingUrl;
    return data;
  }
}
