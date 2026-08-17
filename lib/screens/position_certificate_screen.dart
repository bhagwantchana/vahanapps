import 'package:fleet_monitor/models/position_certificate_model.dart';
import 'package:fleet_monitor/repositorys/position_certificate_repository.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Where was it?" — one vehicle, one moment, one shareable answer.
///
/// This is the question owners currently phone support to get: an accident
/// claim, a police query, a school arguing with a parent about pickup time.
/// The data has always been in the trip history; what was missing was any
/// way to ask it without SQL.
class PositionCertificateScreen extends StatefulWidget {
  const PositionCertificateScreen({
    super.key,
    required this.vehicleId,
    required this.vehicleLabel,
  });

  final int vehicleId;
  final String vehicleLabel;

  @override
  State<PositionCertificateScreen> createState() =>
      _PositionCertificateScreenState();
}

class _PositionCertificateScreenState extends State<PositionCertificateScreen> {
  final PositionCertificateRepository _repository =
      PositionCertificateRepository();

  late DateTime _when;
  bool _isLoading = false;
  String _error = '';
  PositionCertificate? _result;

  @override
  void initState() {
    super.initState();
    // An hour ago, rounded to the minute: a sensible default that is always
    // in the past, so the first tap never hits the "future time" error.
    final now = DateTime.now().subtract(const Duration(hours: 1));
    _when = DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _when = DateTime(
          picked.year, picked.month, picked.day, _when.hour, _when.minute);
      _result = null;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _when.hour, minute: _when.minute),
    );
    if (picked == null) return;
    setState(() {
      _when = DateTime(
          _when.year, _when.month, _when.day, picked.hour, picked.minute);
      _result = null;
    });
  }

  Future<void> _lookup() async {
    setState(() {
      _isLoading = true;
      _error = '';
      _result = null;
    });
    try {
      final result = await _repository.fetch(
        vehicleId: widget.vehicleId,
        when: _when,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String get _whenLabel {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(_when.day)}/${two(_when.month)}/${_when.year}  '
        '${two(_when.hour)}:${two(_when.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Where was it?'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Text(
            widget.vehicleLabel,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick a date and time to see exactly where this vehicle was, with a record you can share.',
            style: TextStyle(fontSize: 12.8, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _pickerButton(
                    LucideIcons.calendar, _whenLabel.split('  ').first, _pickDate),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pickerButton(
                    LucideIcons.clock, _whenLabel.split('  ').last, _pickTime),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _lookup,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.search, size: 18),
              label: Text(_isLoading ? 'Looking up…' : 'Find position'),
            ),
          ),
          if (_error.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error,
                style: const TextStyle(fontSize: 13, color: Color(0xFFD32F2F)),
              ),
            ),
          ],
          if (_result != null) ...<Widget>[
            const SizedBox(height: 20),
            _resultCard(_result!),
          ],
        ],
      ),
    );
  }

  Widget _pickerButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 13.5)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _resultCard(PositionCertificate r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                r.wasMoving ? LucideIcons.navigation : LucideIcons.mapPin,
                size: 20,
                color: const Color(0xFF1C3059),
              ),
              const SizedBox(width: 9),
              Text(
                r.wasMoving
                    ? 'Moving at ${r.speedKmh.toStringAsFixed(0)} km/h'
                    : 'Stationary',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _row('Address', r.address.isEmpty ? '—' : r.address),
          _row('Coordinates',
              '${r.latitude.toStringAsFixed(6)}, ${r.longitude.toStringAsFixed(6)}'),
          _row('Requested', r.requestedTime),
          _row('Recorded at', r.fixTime),
          const SizedBox(height: 10),
          // The precision caveat is shown, never buried: a record that
          // overstates its own accuracy is worse than no record.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(LucideIcons.info, size: 14, color: Colors.black45),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.accuracyNote,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(r.mapUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(LucideIcons.map, size: 16),
                  label: const Text('Open map'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Share.share(r.toShareText()),
                  icon: const Icon(LucideIcons.share2, size: 16),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Colors.black45),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
