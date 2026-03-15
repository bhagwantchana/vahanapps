class UserUpdateModel {
  int? flag;
  String? message;
  Data? data;

  UserUpdateModel({this.flag, this.message, this.data});

  UserUpdateModel.fromJson(Map<String, dynamic> json) {
    flag = json['flag'];
    message = json['message'];
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['flag'] = this.flag;
    data['message'] = this.message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class Data {
  String? rand;
  String? xAuthToken;

  Data({this.rand, this.xAuthToken});

  Data.fromJson(Map<String, dynamic> json) {
    rand = json['rand'];
    xAuthToken = json['X-Auth-Token'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['rand'] = this.rand;
    data['X-Auth-Token'] = this.xAuthToken;
    return data;
  }
}
