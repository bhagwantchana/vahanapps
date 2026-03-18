import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.logout_rounded, color: AppColors.offline)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // User Info Section
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=a042581f4e29026704d'),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Ashok Verma",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Operations Manager",
                    style: TextStyle(color: AppColors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Settings List
            _sectionHeader("Account Settings"),
            _settingsItem(Icons.person_outline_rounded, "Edit Profile", "Change your basic info"),
            _settingsItem(Icons.notifications_none_rounded, "Notifications", "Alerts and message settings"),
            _settingsItem(Icons.lock_outline_rounded, "Change Password", "Secured your account"),
            
            const SizedBox(height: 24),
            _sectionHeader("App Settings"),
            _settingsItem(Icons.dark_mode_outlined, "Dark Mode", "Switch between theme", trailing: Switch(value: false, onChanged: (v){})),
            _settingsItem(Icons.security_rounded, "Privacy Policy", "Read our terms"),
            _settingsItem(Icons.help_outline_rounded, "Help & Support", "Get in touch with us"),
            
            const SizedBox(height: 40),
            Text(
              "App Version 1.0.0",
              style: TextStyle(color: AppColors.grey.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _settingsItem(IconData icon, String title, String subtitle, {Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.grey)),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
        onTap: () {},
      ),
    );
  }
}
