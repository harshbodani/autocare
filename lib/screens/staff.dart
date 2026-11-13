import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/common.dart';

/// Admin only: see everyone who has an account and make employees STAFF.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});
  @override
  State<StaffScreen> createState() => _StaffState();
}

class _StaffState extends State<StaffScreen> {
  List users = [];
  bool l = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    try {
      users = await ApiService.get('/users');
      users = List.of(users)..sort((a, b) => '${a['role']}${a['name']}'.compareTo('${b['role']}${b['name']}'));
    } catch (e) {
      snack(e.toString());
    }
    if (mounted) setState(() => l = false);
  }

  void snack(String t) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Color roleColor(String r) => r == 'ADMIN' ? Colors.red : (r == 'STAFF' ? Colors.indigo : Colors.green);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Staff & accounts')),
        body: l
            ? const Loading()
            : RefreshIndicator(
                onRefresh: load,
                child: users.isEmpty
                    ? const EmptyState(icon: Icons.badge_outlined, title: 'No accounts yet')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: users.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text('STAFF can see and manage all workshop data. Customers only see their own cars, bookings and invoices. Make an employee STAFF after they have created an account.',
                                  style: TextStyle(color: Color(0xFF64748B))),
                            );
                          }
                          final x = users[i - 1];
                          final role = '${x['role'] ?? 'CUSTOMER'}';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              child: Row(children: [
                                CircleAvatar(backgroundColor: roleColor(role).withOpacity(0.12), child: Icon(Icons.person, color: roleColor(role))),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${x['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('${x['email'] ?? ''}', style: TextStyle(color: Colors.grey[600], fontSize: 12.5)),
                                  ]),
                                ),
                                StatusBadge(text: role, color: roleColor(role)),
                                if (role != 'ADMIN')
                                  PopupMenuButton<String>(
                                    onSelected: (r) async {
                                      try {
                                        await ApiService.put('/users/${x['uid']}', {'role': r});
                                        load();
                                      } catch (e) {
                                        snack(e.toString());
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (role != 'STAFF') const PopupMenuItem(value: 'STAFF', child: Text('Make staff')),
                                      if (role != 'CUSTOMER') const PopupMenuItem(value: 'CUSTOMER', child: Text('Make customer')),
                                    ],
                                  ),
                              ]),
                            ),
                          );
                        }),
              ),
      );
}
