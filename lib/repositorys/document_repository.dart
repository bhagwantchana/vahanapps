import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/models/document_item_model.dart';
import 'package:fleet_monitor/networks/network_api.dart';

class DocumentRepository {
  final NetworkApi _networkApi = NetworkApi();

  Future<String> _getToken() async {
    return await LocalStorage.readValue(PreferencesKey.token) ?? '';
  }

  Future<List<DocumentItemModel>> fetchDocuments({
    int? vehicleId,
    String ownerType = '',
    String aiStatus = '',
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _networkApi.sendRequest.get(
        AppUrl.documents,
        queryParameters: <String, dynamic>{
          if (vehicleId != null && vehicleId > 0) 'vehicle_id': vehicleId,
          if (ownerType.trim().isNotEmpty) 'owner_type': ownerType.trim(),
          if (aiStatus.trim().isNotEmpty) 'ai_status': aiStatus.trim(),
          'limit': limit,
          'offset': offset,
        },
        options: NetworkApi.buildOptions(method: 'GET', authToken: await _getToken()),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      final rawList = response.data is Map<String, dynamic>
          ? (response.data['data'] as List? ?? const <dynamic>[])
          : const <dynamic>[];

      return rawList
          .whereType<Map<String, dynamic>>()
          .map(DocumentItemModel.fromJson)
          .toList();
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }

  Future<DocumentItemModel> uploadDocument({
    required int vehicleId,
    required String filePath,
    required String fileName,
    String ownerType = 'vehicle',
    String categoryKey = 'insurance',
    String title = '',
    String documentNumber = '',
    String issuingAuthority = '',
    String issuedOn = '',
    String expiryDate = '',
    String notes = '',
  }) async {
    try {
      final response = await _networkApi.sendRequest.post(
        AppUrl.documents,
        data: FormData.fromMap(<String, dynamic>{
          'vehicle_id': vehicleId,
          'owner_type': ownerType,
          'category_key': categoryKey,
          'title': title.trim(),
          'document_number': documentNumber.trim(),
          'issuing_authority': issuingAuthority.trim(),
          if (issuedOn.trim().isNotEmpty) 'issued_on': issuedOn.trim(),
          if (expiryDate.trim().isNotEmpty) 'expiry_date': expiryDate.trim(),
          if (notes.trim().isNotEmpty) 'notes': notes.trim(),
          'document_file': await MultipartFile.fromFile(
            filePath,
            filename: fileName,
          ),
        }),
        options: NetworkApi.buildOptions(authToken: await _getToken()),
      );

      final apiResponse = ApiResponse.fromResponse(response);
      if (apiResponse.flag == 0) {
        throw Exception(apiResponse.message);
      }

      final payload = response.data is Map<String, dynamic>
          ? response.data['data']
          : null;
      if (payload is Map<String, dynamic>) {
        return DocumentItemModel.fromJson(payload);
      }
      return const DocumentItemModel();
    } catch (error) {
      throw Exception(NetworkApi.parseError(error));
    }
  }
}
