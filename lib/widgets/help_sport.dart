import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fleet_monitor/constant/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const String email = "globynixsolutions@gmail.com";
  static const String phone = "9803171511";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help & Support")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// 🔹 HEADER
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
                    "How can we help you?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Contact us anytime for assistance",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// 🔹 CONTACT OPTIONS
            _contactCard(
              icon: Icons.email_outlined,
              title: "Email Support",
              subtitle: email,
              onTap: () => _launchEmail(),
            ),

            _contactCard(
              icon: Icons.phone_outlined,
              title: "Call Us",
              subtitle: phone,
              onTap: () => _launchCall(),
            ),

            const SizedBox(height: 20),

            /// 🔹 FAQ
            _sectionTitle("Frequently Asked Questions"),

            _faqItem(
              "How to track vehicle?",
              "Go to dashboard and select your vehicle to track live location.",
            ),

            _faqItem(
              "Why location not updating?",
              "Check device internet connection and GPS status.",
            ),

            _faqItem(
              "How to reset password?",
              "Use 'Forgot Password' option on login screen.",
            ),

            const SizedBox(height: 20),

            /// 🔹 FOOTER
            Text(
              "We’re here to help you 24/7 🚀",
              style: TextStyle(color: AppColors.grey.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  /// 📞 CALL
  void _launchCall() async {
    final Uri url = Uri.parse("tel:$phone");
    await launchUrl(url);
  }

  /// 📧 EMAIL
  void _launchEmail() async {
    final Uri url = Uri.parse("mailto:$email");
    await launchUrl(url);
  }

  /// 🔹 CONTACT CARD
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

  /// 🔹 FAQ ITEM
  Widget _faqItem(String question, String answer) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 10),
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [Text(answer, style: TextStyle(color: Colors.grey.shade600))],
    );
  }

  /// 🔹 SECTION TITLE
  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
