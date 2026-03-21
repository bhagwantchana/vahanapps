class DashboardModel {
  int? flag;
  Data? data;

  DashboardModel({this.flag, this.data});

  DashboardModel.fromJson(Map<String, dynamic> json) {
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
  List<VehicleList>? vehicleList;
  String? mapsUrl;

  Data({this.vehicleList, this.mapsUrl});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['vehicleList'] != null) {
      vehicleList = <VehicleList>[];
      json['vehicleList'].forEach((v) {
        vehicleList!.add(new VehicleList.fromJson(v));
      });
    }
    mapsUrl = json['maps_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.vehicleList != null) {
      data['vehicleList'] = this.vehicleList!.map((v) => v.toJson()).toList();
    }
    data['maps_url'] = this.mapsUrl;
    return data;
  }
}

class VehicleList {
  String? vRegistrationNo;
  String? vName;
  String? vModel;
  String? imei;
  String? deviceId;
  String? lastTripFinished;
  String? lastLatitude;
  String? lastLongitude;
  String? lastSpeed;
  String? vehicleTypeId;
  String? vehicleIcon;
  String? deviceSpeed;
  String? lastTripId;
  int? speed;
  String? vehicleIconUrl;
  String? trackingUrl;

  VehicleList({
    this.vRegistrationNo,
    this.vName,
    this.vModel,
    this.imei,
    this.deviceId,
    this.lastTripFinished,
    this.lastLatitude,
    this.lastLongitude,
    this.lastSpeed,
    this.vehicleTypeId,
    this.vehicleIcon,
    this.deviceSpeed,
    this.lastTripId,
    this.speed,
    this.vehicleIconUrl,
    this.trackingUrl,
  });

  VehicleList.fromJson(Map<String, dynamic> json) {
    vRegistrationNo = json['v_registration_no'];
    vName = json['v_name'];
    vModel = json['v_model'];
    imei = json['imei'];
    deviceId = json['device_id'];
    lastTripFinished = json['last_trip_finished'];
    lastLatitude = json['last_latitude'];
    lastLongitude = json['last_longitude'];
    lastSpeed = json['last_speed'];
    vehicleTypeId = json['vehicle_type_id'];
    vehicleIcon = json['vehicle_icon'];
    deviceSpeed = json['device_speed'];
    lastTripId = json['last_trip_id'];
    speed = json['speed'];
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
    data['last_trip_finished'] = this.lastTripFinished;
    data['last_latitude'] = this.lastLatitude;
    data['last_longitude'] = this.lastLongitude;
    data['last_speed'] = this.lastSpeed;
    data['vehicle_type_id'] = this.vehicleTypeId;
    data['vehicle_icon'] = this.vehicleIcon;
    data['device_speed'] = this.deviceSpeed;
    data['last_trip_id'] = this.lastTripId;
    data['speed'] = this.speed;
    data['vehicle_icon_url'] = this.vehicleIconUrl;
    data['tracking_url'] = this.trackingUrl;
    return data;
  }
}
