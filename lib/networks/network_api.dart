import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

const Map<String, dynamic> defaultHeader = {"Content-Type": "application/json"};

class NetworkApi {
  final Dio _dio = Dio();

  NetworkApi() {
    _dio.options.headers = defaultHeader;
    _dio.interceptors.add(
      PrettyDioLogger(
        requestBody: true,
        requestHeader: true,
        responseBody: true,
        responseHeader: true,
      ),
    );
  }

  Dio get sendRequest => _dio;
}

class ApiResponse {
  int? flag;
  String? message;

  ApiResponse({required this.flag, this.message});
  factory ApiResponse.fromResponse(Response response) {
    final data = response.data as Map<String, dynamic>;
    return ApiResponse(
      flag: data["flag"],
      message: data["message"] ?? "Unexpected error",
    );
  }
}
