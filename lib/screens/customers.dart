import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import 'vehicles.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersState();
}

class _CustomersState extends State<CustomersScreen> {
  List data = [];
  bool l = true;
  String q = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    try {
      data = await ApiService.get('/customers');
    } catch (e) {
      msg(e);
    }
    if (mounted) setState(() => l = false);
  }

  void msg(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  Future edit([Map? x]) async {
    final n = TextEditingController(text: x?['name'] ?? ''),
        p = TextEditingController(text: x?['phone'] ?? ''),
        e = TextEditingController(text: x?['email'] ?? ''),
        a = TextEditingController(text: x?['address'] ?? '');

    await showDialog(
        context: context,
        builder: (dc) => AlertDialog(
            title: Text(x == null ? 'Add New Customer' : 'Edit Customer Info'),
            content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Field(controller: n, label: 'Full Name', icon: Icons.person_outline),
              Field(controller: p, label: 'Phone Number', icon: Icons.phone_android_outlined, type: TextInputType.phone),
              Field(controller: e, label: 'Email Address', icon: Icons.email_outlined, type: TextInputType.emailAddress),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('When the customer signs up in the app with this email, they get their own login and see their own cars, bookings and invoices.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
              const SizedBox(height: 12),
              Field(controller: a, label: 'Home Address', icon: Icons.location_on_outlined),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')),
              FilledButton(
                  onPressed: () async {
                    if (n.text.trim().isEmpty || p.text.trim().isEmpty) {
                      msg('Name and phone are required.');
                      return;
                    }
                    final body = {'name': n.text.trim(), 'phone': p.text.trim(), 'email': e.text.trim(), 'address': a.text.trim()};
                    try {
                      if (x == null) {
                        await ApiService.post('/customers', body);
                      } else {
                        await ApiService.put('/customers/${x['id']}', body);
                      }
                      if (dc.mounted) Navigator.pop(dc);
                      load();
                    } catch (err) {
                      msg(err);
                    }
                  },
                  child: const Text('Save Customer'))
            ]));
  }

  @override
  Widget build(BuildContext context) {
    final shown = data.where((x) {
      final s = q.toLowerCase();
      return s.isEmpty || '${x['name']} ${x['phone']} ${x['email']}'.toLowerCase().contains(s);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: l
          ? const Loading()
          : Column(children: [
              SearchBox(hint: 'Search name, phone or email', onChanged: (v) => setState(() => q = v)),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: load,
                  child: shown.isEmpty
                      ? const EmptyState(icon: Icons.people_outline, title: 'No customers found', hint: 'Tap + to add one.')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                          itemCount: shown.length,
                          itemBuilder: (context, i) {
                            final x = shown[i];
                            final name = '${x['name'] ?? '?'}';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppCard(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VehiclesScreen(customerFilter: x))),
                                child: Row(children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Colors.indigo.withOpacity(0.1),
                                    child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text('${x['phone'] ?? ''}', style: TextStyle(color: Colors.grey[600])),
                                      ]),
                                      if (x['owner_uid'] != null) ...[
                                        const SizedBox(height: 6),
                                        const StatusBadge(text: 'Has app account', color: Colors.green),
                                      ],
                                    ]),
                                  ),
                                  PopupMenuButton<int>(
                                    icon: const Icon(Icons.more_vert),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 1, child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                                      PopupMenuItem(value: 2, child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)))),
                                    ],
                                    onSelected: (v) async {
                                      if (v == 1) {
                                        edit(x);
                                      } else if (await confirmDialog(context, 'Delete customer?', 'This also deletes ${x['name']}\'s vehicles, bookings, invoices and reminders.')) {
                                        try {
                                          await ApiService.delete('/customers/${x['id']}');
                                        } catch (err) {
                                          msg(err);
                                        }
                                        load();
                                      }
                                    },
                                  ),
                                ]),
                              ),
                            );
                          }),
                ),
              ),
            ]),
      floatingActionButton: FloatingActionButton(onPressed: () => edit(), child: const Icon(Icons.person_add_alt_1)),
    );
  }
}
