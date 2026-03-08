class AuthModel {
  int? flag;
  Data? data;
  String? message;

  AuthModel({this.flag, this.data, this.message});

  AuthModel.fromJson(Map<String, dynamic> json) {
    flag = json['flag'];
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
    message = json['message'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['flag'] = this.flag;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    data['message'] = this.message;
    return data;
  }
}

class Data {
  String? xAuthToken;

  Data({this.xAuthToken});

  Data.fromJson(Map<String, dynamic> json) {
    xAuthToken = json['X-Auth-Token'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['X-Auth-Token'] = this.xAuthToken;
    return data;
  }
}
