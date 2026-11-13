import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/auth.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import 'auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _PState();
}

class _PState extends State<ProfileScreen> {
  Map u = {};
  Map? me; // the customer record (customers only)

  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    u = await AuthService.user();
    if (Session.isCustomer) {
      try {
        final l = await ApiService.get('/customers') as List;
        if (l.isNotEmpty) me = l.first as Map;
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  void snack(String t) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  Future editDetails() async {
    final m = me;
    if (m == null) return;
    final n = TextEditingController(text: '${m['name'] ?? ''}'),
        p = TextEditingController(text: '${m['phone'] ?? ''}'),
        a = TextEditingController(text: '${m['address'] ?? ''}');
    await showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('My details'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Field(controller: n, label: 'Full name', icon: Icons.person_outline),
            Field(controller: p, label: 'Phone', icon: Icons.phone_android_outlined, type: TextInputType.phone),
            Field(controller: a, label: 'Address', icon: Icons.location_on_outlined),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (n.text.trim().isEmpty) {
                snack('Name is required.');
                return;
              }
              try {
                await ApiService.put('/customers/${m['id']}', {'name': n.text.trim(), 'phone': p.text.trim(), 'address': a.text.trim()});
                if (dc.mounted) Navigator.pop(dc);
                load();
              } catch (e) {
                snack(e.toString());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future changePassword() async {
    final pw = TextEditingController();
    await showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Change password'),
        content: Field(controller: pw, label: 'New password (min 6 characters)', icon: Icons.lock_outline, obscure: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await AuthService.changePassword(pw.text);
                if (dc.mounted) Navigator.pop(dc);
                snack('Password changed.');
              } catch (e) {
                snack(e.toString());
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = '${u['name'] ?? ''}';
    final role = Session.isAdmin ? 'ADMIN' : (Session.isStaff ? 'STAFF' : 'CUSTOMER');
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const SizedBox(height: 12),
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.indigo,
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Text(name.isEmpty ? 'AutoCare user' : name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text('${u['email'] ?? ''}', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 8),
          StatusBadge(text: role, color: Colors.indigo),
          const SizedBox(height: 24),
          if (Session.isCustomer && me != null)
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('My details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: editDetails),
                ]),
                const SizedBox(height: 4),
                Text('Phone: ${me!['phone'] ?? ''}'),
                const SizedBox(height: 4),
                Text('Address: ${('${me!['address'] ?? ''}').isEmpty ? 'not set' : me!['address']}'),
              ]),
            ),
          if (Session.isCustomer && me != null) const SizedBox(height: 16),
          AppCard(
            child: Column(children: [
              if (ApiService.useFirebase) ...[
                ListTile(leading: const Icon(Icons.lock_outline), title: const Text('Change password'), trailing: const Icon(Icons.chevron_right), onTap: changePassword),
              ] else
                ListTile(leading: const Icon(Icons.dns_outlined), title: const Text('Server settings'), trailing: const Icon(Icons.chevron_right), onTap: () => showServerSettings(context)),
            ]),
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
          const SizedBox(height: 32),
          const Text('AutoCare v2.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      ),
    );
  }
}
