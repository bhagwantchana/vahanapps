import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/models/document_item_model.dart';
import 'package:fleet_monitor/repositorys/document_repository.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentVaultScreen extends StatefulWidget {
  const DocumentVaultScreen({
    super.key,
    this.vehicleId = 0,
    this.title = 'Document Vault',
  });

  final int vehicleId;
  final String title;

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  final DocumentRepository _documentRepository = DocumentRepository();
  final List<DocumentItemModel> _documents = <DocumentItemModel>[];

  bool _isLoading = true;
  String _error = '';
  String _ownerType = '';
  String _aiStatus = '';

  static const Map<String, String> _ownerOptions = <String, String>{
    '': 'All Owners',
    'vehicle': 'Vehicle',
    'driver': 'Driver',
    'device': 'Device',
    'sim': 'SIM',
    'vendor': 'Vendor',
    'customer': 'Customer',
  };

  static const Map<String, String> _aiStatusOptions = <String, String>{
    '': 'All AI Statuses',
    'not_requested': 'Not Requested',
    'parsed': 'Parsed',
    'reviewed': 'Reviewed',
    'failed': 'Failed',
  };

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final documents = await _documentRepository.fetchDocuments(
        vehicleId: widget.vehicleId > 0 ? widget.vehicleId : null,
        ownerType: _ownerType,
        aiStatus: _aiStatus,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _documents
          ..clear()
          ..addAll(documents);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openFile(DocumentItemModel document) async {
    if (document.fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file uploaded for this document yet')),
      );
      return;
    }

    final uri = Uri.tryParse(document.fileUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document link is invalid')),
      );
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showDocumentDetails(DocumentItemModel document) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  document.title.isNotEmpty ? document.title : 'Document Details',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow('Category', _humanize(document.categoryKey)),
                _detailRow('Owner', document.ownerTypeLabel),
                _detailRow('Document Number', document.documentNumber),
                _detailRow('Issued On', _formatDate(document.issuedOn)),
                _detailRow('Expiry', _formatDate(document.expiryDate)),
                _detailRow('Status', document.isExpired ? 'Expired' : _humanize(document.status)),
                _detailRow('AI Status', _humanize(document.aiStatus)),
                _detailRow('Confidence', document.aiConfidence),
                _detailRow('Authority', document.issuingAuthority),
                _detailRow('File', document.fileLabel),
                if (document.notes.isNotEmpty) _detailRow('Notes', document.notes),
                if (document.aiExtractedData.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  const Text(
                    'Captured Fields',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      document.aiExtractedData,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openFile(document),
                    icon: Icon(LucideIcons.externalLink),
                    label: const Text('Open Document'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _ownerType,
                  items: _ownerOptions.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _ownerType = value ?? '');
                    _loadDocuments();
                  },
                  decoration: const InputDecoration(labelText: 'Owner Type'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _aiStatus,
                  items: _aiStatusOptions.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _aiStatus = value ?? '');
                    _loadDocuments();
                  },
                  decoration: const InputDecoration(labelText: 'AI Status'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                ? _DocumentErrorState(message: _error, onRetry: _loadDocuments)
                : _documents.isEmpty
                ? RefreshIndicator(
                    onRefresh: _loadDocuments,
                    child: ListView(
                      children: const <Widget>[
                        SizedBox(
                          height: 320,
                          child: Center(child: Text('No documents available')),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadDocuments,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _documents.length,
                      itemBuilder: (context, index) {
                        final document = _documents[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showDocumentDetails(document),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: _statusColor(document).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          LucideIcons.fileText,
                                          color: _statusColor(document),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              document.title.isNotEmpty
                                                  ? document.title
                                                  : 'Untitled document',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.primaryBlue,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${document.ownerTypeLabel} • ${_humanize(document.categoryKey)}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (document.fileUrl.isNotEmpty)
                                        IconButton(
                                          onPressed: () => _openFile(document),
                                          icon: Icon(LucideIcons.externalLink),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: <Widget>[
                                      _infoChip(
                                        icon: LucideIcons.hash,
                                        label: document.documentNumber.isNotEmpty
                                            ? document.documentNumber
                                            : 'No number',
                                      ),
                                      _infoChip(
                                        icon: LucideIcons.sparkles,
                                        label: _humanize(document.aiStatus),
                                      ),
                                      _infoChip(
                                        icon: LucideIcons.calendarClock,
                                        label: document.expiryDate.isNotEmpty
                                            ? _formatDate(document.expiryDate)
                                            : 'No expiry',
                                        color: document.isExpired
                                            ? AppColors.red
                                            : AppTheme.primaryBlue,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.trim().isEmpty || value == '--') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    Color color = AppTheme.primaryBlue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(DocumentItemModel document) {
    if (document.isExpired) {
      return AppColors.red;
    }
    if (document.aiStatus == 'parsed' || document.aiStatus == 'reviewed') {
      return AppColors.green;
    }
    if (document.aiStatus == 'failed') {
      return AppColors.orange;
    }
    return AppTheme.primaryBlue;
  }

  String _humanize(String value) {
    if (value.trim().isEmpty) {
      return '--';
    }
    return value
        .split('_')
        .where((item) => item.isNotEmpty)
        .map((item) => '${item[0].toUpperCase()}${item.substring(1)}')
        .join(' ');
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value.isEmpty ? '--' : value;
    }
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }
}

class _DocumentErrorState extends StatelessWidget {
  const _DocumentErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
