import 'package:flutter/material.dart';
import '../services/auth.dart';
import '../widgets/common.dart';
import 'auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _PState();
}

class _PState extends State<ProfileScreen> {
  Map u = {};
  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    u = await AuthService.user();
    if (mounted) setState(() {});
  }

  Future logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  const CircleAvatar(radius: 60, backgroundColor: Colors.indigo, child: Icon(Icons.person, size: 70, color: Colors.white)),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.amber,
                      child: IconButton(icon: const Icon(Icons.edit, size: 16, color: Colors.white), onPressed: () {}),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(u['name'] ?? 'Admin', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(u['email'] ?? 'admin@autocare.com', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            StatusBadge(text: u['role'] ?? 'ADMIN', color: Colors.indigo),
            const SizedBox(height: 40),
            AppCard(
              child: Column(
                children: [
                  ListTile(leading: const Icon(Icons.dns_outlined), title: const Text('Server settings'), trailing: const Icon(Icons.chevron_right), onTap: () => showServerSettings(context)),
                  const Divider(),
                  ListTile(leading: const Icon(Icons.business_center_outlined), title: const Text('Workshop Details'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
                  const Divider(),
                  ListTile(leading: const Icon(Icons.security_outlined), title: const Text('Privacy & Security'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
                  const Divider(),
                  ListTile(leading: const Icon(Icons.help_outline), title: const Text('Support & Help'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: logout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Log Out', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text('AutoCare v1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
