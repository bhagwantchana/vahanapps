import 'package:fleet_monitor/models/model_helpers.dart';

class DocumentItemModel {
  final int id;
  final String ownerType;
  final int ownerId;
  final String categoryKey;
  final String title;
  final String documentNumber;
  final String issuingAuthority;
  final String issuedOn;
  final String expiryDate;
  final String fileName;
  final String fileOriginalName;
  final String fileUrl;
  final String aiStatus;
  final String aiConfidence;
  final String aiExtractedData;
  final String aiSourceText;
  final String status;
  final String notes;

  const DocumentItemModel({
    this.id = 0,
    this.ownerType = '',
    this.ownerId = 0,
    this.categoryKey = '',
    this.title = '',
    this.documentNumber = '',
    this.issuingAuthority = '',
    this.issuedOn = '',
    this.expiryDate = '',
    this.fileName = '',
    this.fileOriginalName = '',
    this.fileUrl = '',
    this.aiStatus = '',
    this.aiConfidence = '',
    this.aiExtractedData = '',
    this.aiSourceText = '',
    this.status = '',
    this.notes = '',
  });

  factory DocumentItemModel.fromJson(Map<String, dynamic> json) {
    return DocumentItemModel(
      id: toInt(json['id']),
      ownerType: toStringValue(json['owner_type']),
      ownerId: toInt(json['owner_id']),
      categoryKey: toStringValue(json['category_key']),
      title: toStringValue(json['title']),
      documentNumber: toStringValue(json['document_number']),
      issuingAuthority: toStringValue(json['issuing_authority']),
      issuedOn: toStringValue(json['issued_on']),
      expiryDate: toStringValue(json['expiry_date']),
      fileName: toStringValue(json['file_name']),
      fileOriginalName: toStringValue(json['file_original_name']),
      fileUrl: toStringValue(json['file_url']),
      aiStatus: toStringValue(json['ai_status']),
      aiConfidence: toStringValue(json['ai_confidence']),
      aiExtractedData: toStringValue(json['ai_extracted_data']),
      aiSourceText: toStringValue(json['ai_source_text']),
      status: toStringValue(json['status']),
      notes: toStringValue(json['notes']),
    );
  }

  bool get isExpired {
    final parsed = DateTime.tryParse(expiryDate);
    if (parsed == null) {
      return false;
    }
    final today = DateTime.now();
    final cutoff = DateTime(today.year, today.month, today.day);
    return parsed.isBefore(cutoff);
  }

  String get ownerTypeLabel {
    switch (ownerType) {
      case 'vehicle':
        return 'Vehicle';
      case 'driver':
        return 'Driver';
      case 'device':
        return 'Device';
      case 'sim':
        return 'SIM';
      case 'vendor':
        return 'Vendor';
      case 'customer':
        return 'Customer';
      default:
        return ownerType.isEmpty ? 'Unknown' : ownerType;
    }
  }

  String get fileLabel => fileOriginalName.isNotEmpty ? fileOriginalName : fileName;
}
