import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/repositorys/document_repository.dart';
import 'package:fleet_monitor/repositorys/maintenance_repository.dart';
import 'package:fleet_monitor/screens/document_vault_screen.dart';
import 'package:fleet_monitor/services/assigned_vehicle_reminder_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AssignedVehicleMaintenanceScreen extends StatefulWidget {
  const AssignedVehicleMaintenanceScreen({
    super.key,
    this.initialVehicleId = 0,
  });

  final int initialVehicleId;

  @override
  State<AssignedVehicleMaintenanceScreen> createState() =>
      _AssignedVehicleMaintenanceScreenState();
}

class _AssignedVehicleMaintenanceScreenState
    extends State<AssignedVehicleMaintenanceScreen> {
  final AssignedVehicleReminderService _vehicleCareService =
      AssignedVehicleReminderService();
  final MaintenanceRepository _maintenanceRepository = MaintenanceRepository();
  final DocumentRepository _documentRepository = DocumentRepository();

  List<VehicleCareSnapshot> _snapshots = <VehicleCareSnapshot>[];
  VehicleCareMeta _vehicleCareMeta = const VehicleCareMeta();
  List<VehicleCareOption> _serviceTypes = const <VehicleCareOption>[];
  List<VehicleCareOption> _documentCategories = const <VehicleCareOption>[];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadVehicleCare();
    _loadVehicleCareMeta();
  }

  Future<void> _loadVehicleCare() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final snapshots = await _vehicleCareService.loadAssignedVehicleCare();
      if (!mounted) {
        return;
      }

      if (widget.initialVehicleId > 0) {
        snapshots.sort((a, b) {
          if (a.vehicle.id == widget.initialVehicleId) {
            return -1;
          }
          if (b.vehicle.id == widget.initialVehicleId) {
            return 1;
          }
          return a.vehicle.displayName.compareTo(b.vehicle.displayName);
        });
      }

      setState(() {
        _snapshots = snapshots;
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

  Future<void> _openInsuranceDocs(VehicleCareSnapshot snapshot) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DocumentVaultScreen(
          vehicleId: snapshot.vehicle.id,
          title: '${snapshot.vehicle.displayName} Documents',
        ),
      ),
    );
  }

  Future<void> _loadVehicleCareMeta() async {
    try {
      final meta = await _maintenanceRepository.fetchVehicleCareMeta();
      if (!mounted) {
        return;
      }
      setState(() {
        _vehicleCareMeta = meta;
        _serviceTypes = meta.serviceTypes;
        _documentCategories = meta.documentCategories;
      });
    } catch (_) {
      // Keep UI functional with fallback options.
    }
  }

  Future<void> _showAddMaintenanceSheet(VehicleCareSnapshot snapshot) async {
    final formKey = GlobalKey<FormState>();
    final serviceOptions = _serviceTypes.isNotEmpty
        ? _serviceTypes
        : const <VehicleCareOption>[
            VehicleCareOption(key: 'general_service', label: 'General Service'),
            VehicleCareOption(key: 'oil_change', label: 'Oil Change'),
            VehicleCareOption(key: 'brake_service', label: 'Brake Service'),
            VehicleCareOption(key: 'insurance', label: 'Insurance'),
          ];
    var selectedServiceKey = serviceOptions.first.key;
    final dateController = TextEditingController(text: _todayString());
    final odometerController = TextEditingController(
      text: snapshot.vehicle.currentOdometer > 0
          ? snapshot.vehicle.currentOdometer.toStringAsFixed(0)
          : '',
    );
    final costController = TextEditingController();
    final nextDateController = TextEditingController();
    final nextOdometerController = TextEditingController();
    final descriptionController = TextEditingController();
    var selectedStatus = 'completed';
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetBuildContext, setSheetState) {
            Future<void> pickServiceDate() async {
              final initialDate =
                  DateTime.tryParse(dateController.text) ?? DateTime.now();
              final picked = await showDatePicker(
                context: sheetBuildContext,
                initialDate: initialDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked == null) {
                return;
              }
              dateController.text =
                  '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              setSheetState(() {});
            }

            Future<void> saveLog() async {
              if (!(formKey.currentState?.validate() ?? false) || isSaving) {
                return;
              }

              final options = _vehicleCareMeta.maintenanceStatuses;
              if (options.isNotEmpty &&
                  !options.any((item) => item.key == selectedStatus)) {
                selectedStatus = options.first.key;
              }

              setSheetState(() => isSaving = true);
              try {
                await _maintenanceRepository.addMaintenanceLog(
                  vehicleId: snapshot.vehicle.id,
                  serviceType: selectedServiceKey,
                  serviceDate: dateController.text,
                  odometer:
                      double.tryParse(odometerController.text.trim()) ?? 0,
                  cost: double.tryParse(costController.text.trim()) ?? 0,
                  status: selectedStatus,
                  description: descriptionController.text,
                  nextServiceDate: nextDateController.text,
                  nextServiceOdometer:
                      int.tryParse(nextOdometerController.text.trim()),
                );

                if (!mounted) {
                  return;
                }
                // `sheetContext` is the modal bottom sheet's own context,
                // not this State's. The outer `mounted` only guards the
                // State — the sheet can be dismissed independently while
                // we awaited. Check its own mounted flag before popping.
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Maintenance log added successfully'),
                  ),
                );
                await _loadVehicleCare();
              } catch (error) {
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.toString().replaceFirst('Exception: ', ''),
                    ),
                  ),
                );
                setSheetState(() => isSaving = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(sheetBuildContext).viewInsets.bottom + 16,
                top: 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Add Maintenance',
                          style: Theme.of(sheetBuildContext).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          snapshot.vehicle.displayName,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          initialValue: selectedServiceKey,
                          items: serviceOptions
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item.key,
                                  child: Text(item.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setSheetState(() => selectedServiceKey = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Service Type',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: dateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Service Date',
                            suffixIcon: IconButton(
                              onPressed: pickServiceDate,
                              icon: Icon(LucideIcons.calendarDays),
                            ),
                          ),
                          onTap: pickServiceDate,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: odometerController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Odometer',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: costController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Cost',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          items: (_vehicleCareMeta.maintenanceStatuses.isNotEmpty
                                  ? _vehicleCareMeta.maintenanceStatuses
                                  : const <VehicleCareOption>[
                                      VehicleCareOption(
                                        key: 'completed',
                                        label: 'Completed',
                                      ),
                                      VehicleCareOption(
                                        key: 'pending',
                                        label: 'Pending',
                                      ),
                                    ])
                              .map(
                                (status) => DropdownMenuItem<String>(
                                  value: status.key,
                                  child: Text(status.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setSheetState(() => selectedStatus = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nextDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Next Service Date (optional)',
                            suffixIcon: IconButton(
                              onPressed: () async {
                                final initial = DateTime.tryParse(
                                      nextDateController.text,
                                    ) ??
                                    DateTime.now();
                                final picked = await showDatePicker(
                                  context: sheetBuildContext,
                                  initialDate: initial,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 3650),
                                  ),
                                );
                                if (picked == null) {
                                  return;
                                }
                                nextDateController.text =
                                    '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                setSheetState(() {});
                              },
                              icon: Icon(LucideIcons.calendarDays),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nextOdometerController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Next Service Odometer (optional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isSaving ? null : saveLog,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(LucideIcons.wrench),
                            label: Text(
                              isSaving ? 'Saving...' : 'Save Maintenance',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    dateController.dispose();
    odometerController.dispose();
    costController.dispose();
    nextDateController.dispose();
    nextOdometerController.dispose();
    descriptionController.dispose();
  }

  Future<void> _showDocumentActions(VehicleCareSnapshot snapshot) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: Icon(LucideIcons.folderOpen),
                  title: const Text('Open Documents'),
                  subtitle: const Text('View all linked files'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openInsuranceDocs(snapshot);
                  },
                ),
                ListTile(
                  leading: Icon(LucideIcons.uploadCloud),
                  title: const Text('Upload Insurance Document'),
                  subtitle: const Text('Add new insurance file for this vehicle'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showInsuranceUploadSheet(snapshot);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInsuranceUploadSheet(VehicleCareSnapshot snapshot) async {
    final formKey = GlobalKey<FormState>();
    final numberController = TextEditingController();
    final authorityController = TextEditingController();
    final notesController = TextEditingController();
    final expiryController = TextEditingController();
    String filePath = '';
    String fileName = '';
    bool isUploading = false;

    final insuranceCategory = _resolveInsuranceCategory();
    final allowedExtensions = _resolveAllowedUploadExtensions();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetBuildContext, setSheetState) {
            Future<void> pickExpiryDate() async {
              final initial = DateTime.tryParse(expiryController.text) ??
                  DateTime.now().add(const Duration(days: 365));
              final picked = await showDatePicker(
                context: sheetBuildContext,
                initialDate: initial,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked == null) {
                return;
              }
              expiryController.text =
                  '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              setSheetState(() {});
            }

            Future<void> pickFile() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: allowedExtensions,
              );
              if (result == null || result.files.isEmpty) {
                return;
              }
              final file = result.files.first;
              if (file.path == null || file.path!.trim().isEmpty) {
                return;
              }
              setSheetState(() {
                filePath = file.path!;
                fileName = file.name;
              });
            }

            Future<void> upload() async {
              if (!(formKey.currentState?.validate() ?? false) ||
                  filePath.trim().isEmpty ||
                  isUploading) {
                if (filePath.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a file to upload')),
                  );
                }
                return;
              }

              setSheetState(() => isUploading = true);
              try {
                await _documentRepository.uploadDocument(
                  vehicleId: snapshot.vehicle.id,
                  filePath: filePath,
                  fileName: fileName,
                  categoryKey: insuranceCategory,
                  title: '${snapshot.vehicle.displayName} Insurance',
                  documentNumber: numberController.text,
                  issuingAuthority: authorityController.text,
                  expiryDate: expiryController.text,
                  notes: notesController.text,
                );
                if (!mounted) {
                  return;
                }
                // Same modal-vs-state context check as above.
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Insurance document uploaded')),
                );
                await _loadVehicleCare();
              } catch (error) {
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error.toString().replaceFirst('Exception: ', '')),
                  ),
                );
                setSheetState(() => isUploading = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetBuildContext).viewInsets.bottom + 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Upload Insurance Document',
                          style: Theme.of(sheetBuildContext)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          snapshot.vehicle.displayName,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: pickFile,
                          icon: Icon(LucideIcons.fileUp),
                          label: Text(
                            fileName.isNotEmpty
                                ? fileName
                                : 'Select insurance file',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: numberController,
                          decoration: const InputDecoration(
                            labelText: 'Document Number',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: authorityController,
                          decoration: const InputDecoration(
                            labelText: 'Issuing Authority',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: expiryController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Expiry Date',
                            suffixIcon: IconButton(
                              onPressed: pickExpiryDate,
                              icon: Icon(LucideIcons.calendarDays),
                            ),
                          ),
                          onTap: pickExpiryDate,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isUploading ? null : upload,
                            icon: isUploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(LucideIcons.uploadCloud),
                            label: Text(isUploading ? 'Uploading...' : 'Upload'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    numberController.dispose();
    authorityController.dispose();
    notesController.dispose();
    expiryController.dispose();
  }

  String _resolveInsuranceCategory() {
    final categories = _documentCategories;
    if (categories.isEmpty) {
      return 'insurance';
    }
    final match = categories.firstWhere(
      (option) => option.key.toLowerCase().contains('insurance'),
      orElse: () => categories.first,
    );
    return match.key;
  }

  List<String> _resolveAllowedUploadExtensions() {
    final uploadSettings = _vehicleCareMeta.uploadSettings;
    final raw = uploadSettings['allowed_extensions'] ?? uploadSettings['types'];
    if (raw is List) {
      final values = raw
          .map((item) => item.toString().replaceAll('.', '').toLowerCase())
          .where((item) => item.isNotEmpty)
          .toList();
      if (values.isNotEmpty) {
        return values;
      }
    }
    if (raw is String && raw.trim().isNotEmpty) {
      final values = raw
          .split(',')
          .map((item) => item.trim().replaceAll('.', '').toLowerCase())
          .where((item) => item.isNotEmpty)
          .toList();
      if (values.isNotEmpty) {
        return values;
      }
    }
    return const <String>['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'];
  }

  @override
  Widget build(BuildContext context) {
    final dueMaintenanceCount = _snapshots
        .where((item) => item.maintenanceStatus.isDue)
        .length;
    final dueInsuranceCount = _snapshots
        .where((item) => item.insuranceStatus.needsAttention)
        .length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Vehicle Care')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? _VehicleCareErrorState(message: _error, onRetry: _loadVehicleCare)
          : RefreshIndicator(
              onRefresh: _loadVehicleCare,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _summaryCard(
                          title: 'Maintenance Due',
                          value: dueMaintenanceCount.toString(),
                          color: AppColors.orange,
                          icon: LucideIcons.wrench,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _summaryCard(
                          title: 'Insurance Updates',
                          value: dueInsuranceCount.toString(),
                          color: AppColors.red,
                          icon: LucideIcons.shieldAlert,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_snapshots.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 120),
                      child: Center(
                        child: Text('No assigned vehicles found'),
                      ),
                    ),
                  for (final snapshot in _snapshots) ...<Widget>[
                    _vehicleCard(snapshot),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _vehicleCard(VehicleCareSnapshot snapshot) {
    final maintenanceColor = snapshot.maintenanceStatus.isDue
        ? AppColors.orange
        : AppColors.green;
    final insuranceColor = snapshot.insuranceStatus.needsAttention
        ? AppColors.red
        : AppTheme.primaryBlue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        snapshot.vehicle.displayName,
                        style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          snapshot.vehicle.name,
                          snapshot.vehicle.model,
                          snapshot.vehicle.typeName,
                        ]
                            .where((value) => value.trim().isNotEmpty)
                            .join(' | '),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _statusTile(
              icon: LucideIcons.wrench,
              title: 'Maintenance',
              description: snapshot.maintenanceStatus.summary,
              color: maintenanceColor,
            ),
            const SizedBox(height: 10),
            _statusTile(
              icon: LucideIcons.shieldCheck,
              title: 'Insurance',
              description: snapshot.insuranceStatus.summary,
              color: insuranceColor,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _infoChip(
                  icon: LucideIcons.gauge,
                  label:
                      'Odometer ${snapshot.vehicle.currentOdometer.toStringAsFixed(0)} km',
                ),
                if (snapshot.latestMaintenanceLog != null)
                  _infoChip(
                    icon: LucideIcons.calendarClock,
                    label:
                        'Last service ${_formatDate(snapshot.latestMaintenanceLog!.serviceDate)}',
                  ),
                if (snapshot.insuranceStatus.document?.expiryDate.isNotEmpty ==
                    true)
                  _infoChip(
                    icon: LucideIcons.badgeAlert,
                    label:
                        'Insurance ${_formatDate(snapshot.insuranceStatus.document!.expiryDate)}',
                    color: insuranceColor,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                SizedBox(
                  width: 170,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showAddMaintenanceSheet(snapshot),
                    icon: Icon(LucideIcons.plusCircle, size: 16),
                    label: const Text(
                      'Add Maintenance',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showDocumentActions(snapshot),
                    icon: Icon(LucideIcons.folderOpen, size: 16),
                    label: const Text(
                      'Open Documents',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusTile({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
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

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value.isEmpty ? '--' : value;
    }
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

class _VehicleCareErrorState extends StatelessWidget {
  const _VehicleCareErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(LucideIcons.alertTriangle, color: AppColors.red, size: 44),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}


