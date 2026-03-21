import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/vechile_list_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';
import 'package:dio/dio.dart';

class VehicleRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<VehicleListModel> vehicleListFetch() async {
    final String token = await LocalStorage.readValue(PreferencesKey.token);
    try {
      // FormData formData = FormData.fromMap({'email': email, 'password': pass});
      final headers = {'X-Auth-Token': token};
      Response response = await _networkApi.sendRequest.post(
        AppUrl.vehicleList,
        options: Options(method: 'POST', headers: headers),
      );
      ApiResponse apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw apiResponse.message.toString();
      }
      return VehicleListModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  // Future<BigBannerModel> fetchBigBanner() async {
  //   try {
  //     Response response = await _networkApi.sendRequest.post(
  //       AppUrl.bigBanner,
  //       data: jsonEncode({"device_type": 1, "category_id": "-1"}),
  //     );
  //     ApiResponse apiResponse = ApiResponse.fromResponse(response);
  //     if (apiResponse.success == 0) {
  //       throw apiResponse.message.toString();
  //     }
  //     return BigBannerModel.fromJson(response.data);
  //   } catch (ex) {
  //     rethrow;
  //   }
  // }

  // Future<PrimeCategoryModel> fetchPrimeCategory() async {
  //   try {
  //     Response response = await _networkApi.sendRequest.post(
  //       AppUrl.categoryprime,
  //       data: jsonEncode({"device_type": 1, "page": "1"}),
  //     );
  //     ApiResponse apiResponse = ApiResponse.fromResponse(response);
  //     if (apiResponse.success == 0) {
  //       throw apiResponse.message.toString();
  //     }
  //     return PrimeCategoryModel.fromJson(response.data);
  //   } catch (ex) {
  //     rethrow;
  //   }
  // }

  // Future<CategoryModel> fetchCategory() async {
  //   try {
  //     Response response = await _networkApi.sendRequest.post(
  //       AppUrl.categoryapi,
  //       data: jsonEncode({"device_type": 1, "page": "1"}),
  //     );
  //     ApiResponse apiResponse = ApiResponse.fromResponse(response);
  //     if (apiResponse.success == 0) {
  //       throw apiResponse.message.toString();
  //     }
  //     return CategoryModel.fromJson(response.data);
  //   } catch (ex) {
  //     rethrow;
  //   }
  // }
}
