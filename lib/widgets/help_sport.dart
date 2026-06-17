import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/networks/network_api.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Help & Support — pulls live email / phone contacts from the server so
/// the admin can change them via superadmin → Settings → Help & Support
/// Contacts WITHOUT shipping a new app build. Falls back to a hard-coded
/// default if the network request fails (so the screen is never empty).
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  // Fallback values — only used if the API call fails AND the cache is
  // empty (first install + offline). Once the API loads, the live list
  // replaces these.
  static const _fallbackEmail = 'globynixsolutions@gmail.com';
  static const _fallbackPhone = '9803171511';

  bool _loading = true;
  List<_Contact> _emails = const [];
  List<_Contact> _phones = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await LocalStorage.readValue(PreferencesKey.token) ?? '';
      final res = await NetworkApi().sendRequest.post(
        AppUrl.supportContacts,
        options: NetworkApi.buildOptions(authToken: token),
      );
      final raw = res.data;
      if (raw is Map &&
          raw['flag'] == 1 &&
          raw['data'] is Map) {
        final data = Map<String, dynamic>.from(raw['data']);
        final emails = (data['emails'] is List ? data['emails'] as List : [])
            .whereType<Map>()
            .map((e) => _Contact.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        final phones = (data['phones'] is List ? data['phones'] as List : [])
            .whereType<Map>()
            .map((e) => _Contact.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (mounted) {
          setState(() {
            _emails = emails;
            _phones = phones;
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {/* fall through to fallback below */}
    if (mounted) {
      setState(() {
        _emails = const [_Contact(value: _fallbackEmail, label: '')];
        _phones = const [_Contact(value: _fallbackPhone, label: '')];
        _loading = false;
      });
    }
  }

  Future<void> _launch(String scheme, String value) async {
    final uri = Uri.parse('$scheme:$value');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.support_agent, color: Colors.white, size: 40),
                        SizedBox(height: 10),
                        Text(
                          'How can we help you?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text('Contact us anytime for assistance',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final e in _emails)
                    _contactCard(
                      icon: Icons.email_outlined,
                      title: e.label.isEmpty ? 'Email Support' : e.label,
                      subtitle: e.value,
                      onTap: () => _launch('mailto', e.value),
                    ),
                  for (final p in _phones)
                    _contactCard(
                      icon: Icons.phone_outlined,
                      title: p.label.isEmpty ? 'Call Us' : p.label,
                      subtitle: p.value,
                      onTap: () => _launch('tel', p.value),
                    ),
                  const SizedBox(height: 20),
                  _sectionTitle('Frequently Asked Questions'),
                  _faqItem('How to track vehicle?',
                      'Go to dashboard and select your vehicle to track live location.'),
                  _faqItem('Why location not updating?',
                      'Check device internet connection and GPS status.'),
                  _faqItem('How to reset password?',
                      'Use \'Forgot Password\' option on login screen.'),
                  const SizedBox(height: 20),
                  Text('We’re here to help you 24/7 🚀',
                      style: TextStyle(color: AppColors.grey.withValues(alpha: 0.7))),
                ],
              ),
            ),
    );
  }

  Widget _contactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: Colors.white,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  Widget _faqItem(String question, String answer) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 10),
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600)),
      children: [Text(answer, style: TextStyle(color: Colors.grey.shade600))],
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primary)),
      ),
    );
  }
}

class _Contact {
  final String value;
  final String label;
  const _Contact({required this.value, this.label = ''});

  factory _Contact.fromJson(Map<String, dynamic> json) =>
      _Contact(value: '${json['value'] ?? ''}', label: '${json['label'] ?? ''}');
}
