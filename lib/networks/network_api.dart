import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/services/connectivity_service.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// True when a DioException is a loss-of-connectivity failure (no route to
/// host / DNS / socket / connect timeout) rather than a server-side error.
bool _isConnectionError(DioException e) =>
    e.type == DioExceptionType.connectionError ||
    e.type == DioExceptionType.connectionTimeout ||
    e.error is SocketException;

const Map<String, dynamic> defaultHeader = <String, dynamic>{
  'Accept': 'application/json',
};

class NetworkApi {
  final Dio _dio = Dio(
    BaseOptions(
      headers: defaultHeader,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
    ),
  );

  NetworkApi() {
    // On a 401 (expired/invalid session token from MY_Controller) clear the
    // stored session so the next app launch routes to login instead of
    // retrying with a dead token. The error still propagates so the caller
    // surfaces "Session Expired! Please Login.".
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) {
          if (e.response?.statusCode == 401) {
            unawaited(LocalStorage.clearSession());
          }
          // A connection-type failure means the device may be offline. Ask the
          // connectivity service to verify (a real probe) so the global
          // "No internet" screen can take over if reachability is actually lost.
          if (_isConnectionError(e)) {
            ConnectivityService.instance.reportPossibleConnectionError();
          }
          handler.next(e);
        },
      ),
    );
    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestBody: true,
          requestHeader: true,
          responseBody: true,
          responseHeader: false,
        ),
      );
    }
  }

  Dio get sendRequest => _dio;

  static Options buildOptions({
    String method = 'POST',
    String? authToken,
    Map<String, dynamic>? headers,
  }) {
    final requestHeaders = <String, dynamic>{...defaultHeader};
    if (authToken != null && authToken.trim().isNotEmpty) {
      requestHeaders['X-Auth-Token'] = authToken.trim();
    }
    if (headers != null) {
      requestHeaders.addAll(headers);
    }
    return Options(method: method, headers: requestHeaders);
  }

  static String parseError(Object error) {
    if (error is DioException) {
      if (_isConnectionError(error)) {
        return 'No internet connection';
      }
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final apiMessage = responseData['message']?.toString();
        if (apiMessage != null && apiMessage.trim().isNotEmpty) {
          return apiMessage;
        }
      }
      return error.message ?? 'Network request failed';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}

class ApiResponse {
  final int flag;
  final String message;

  const ApiResponse({required this.flag, required this.message});

  factory ApiResponse.fromResponse(Response response) {
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    return ApiResponse(
      flag: data['flag'] is int ? data['flag'] as int : 0,
      message: data['message']?.toString() ?? 'Unexpected error',
    );
  }
}
